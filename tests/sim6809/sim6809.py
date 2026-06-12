#!/usr/bin/env python3
"""
sim6809 - smoke-test NitrOS-9 command modules on the host.

Loads an assembled OS-9 program module (lwasm --format=os9), sets up the
process environment the kernel would provide (U/DP = data area, X = the
command-line parameter area, Y = top of memory, S below the parameters),
and interprets 6809 machine code with the common OS-9 service requests
stubbed out:

    I$Open    succeeds, path 1-3; pathname is consumed up to a delimiter
    I$Read    feeds a synthetic directory (32-byte RBF entries) or file
    I$ReadLn  same data, stops after CR
    I$Write   captured and shown
    I$WritLn  captured up to and including CR
    I$Close   succeeds
    I$GetStt  SS.Opt (terminal: SCF+ALF, or zeroed with --pipe),
              SS.ScSiz (--width), SS.FDInf (canned file descriptor head)
    F$Exit    ends the run, exit code reported

This is NOT a full 6809 (no cycle counting, no interrupts, no 6309 ops).
Unimplemented opcodes stop the run with a module-relative trace of the
last instructions executed, which is usually all you need to find a bug.

Examples:
    sim6809.py level1/coco1/cmds/ls
    sim6809.py level1/coco1/cmds/ls --params "-l /dd/cmds"
    sim6809.py level1/coco1/cmds/ls --pipe --files a,b,c --width 32

It found three real bugs in ls.asm the day it was written; run your
command here before you bother a real CoCo with it.
"""
import argparse
import sys

MEM = bytearray(65536)

class CPU:
    def __init__(self):
        self.a = 0; self.b = 0; self.x = 0; self.y = 0; self.u = 0; self.s = 0
        self.dp = 0; self.pc = 0; self.cc = 0
        self.running = True
    @property
    def d(self): return (self.a << 8) | self.b
    @d.setter
    def d(self, v): self.a = (v >> 8) & 0xFF; self.b = v & 0xFF

cpu = CPU()

# ---------------------------------------------------------------- flags
C, V, Z, N, I, H, F, E = 1, 2, 4, 8, 16, 32, 64, 128
def setf(flag, on):
    if on: cpu.cc |= flag
    else: cpu.cc &= ~flag & 0xFF
def nz8(v): setf(N, v & 0x80); setf(Z, v == 0)
def nz16(v): setf(N, v & 0x8000); setf(Z, v == 0)

# --------------------------------------------------------------- memory
def rd8(a): return MEM[a & 0xFFFF]
def rd16(a): return (MEM[a & 0xFFFF] << 8) | MEM[(a + 1) & 0xFFFF]
def wr8(a, v): MEM[a & 0xFFFF] = v & 0xFF
def wr16(a, v): wr8(a, v >> 8); wr8(a + 1, v)

def fetch8():
    v = rd8(cpu.pc); cpu.pc = (cpu.pc + 1) & 0xFFFF; return v
def fetch16():
    v = rd16(cpu.pc); cpu.pc = (cpu.pc + 2) & 0xFFFF; return v

def push16(v): cpu.s = (cpu.s - 2) & 0xFFFF; wr16(cpu.s, v)
def pull16():
    v = rd16(cpu.s); cpu.s = (cpu.s + 2) & 0xFFFF; return v
def push8(v): cpu.s = (cpu.s - 1) & 0xFFFF; wr8(cpu.s, v)
def pull8():
    v = rd8(cpu.s); cpu.s = (cpu.s + 1) & 0xFFFF; return v

# --------------------------------------------------- register selectors
REG16 = {0: 'd', 1: 'x', 2: 'y', 3: 'u', 4: 's', 5: 'pc'}
def getreg(code):
    if code in REG16: return getattr(cpu, REG16[code]) & 0xFFFF
    return {8: cpu.a, 9: cpu.b, 10: cpu.cc, 11: cpu.dp}[code]
def setreg(code, v):
    if code in REG16: setattr(cpu, REG16[code], v & 0xFFFF); return
    if code == 8: cpu.a = v & 0xFF
    elif code == 9: cpu.b = v & 0xFF
    elif code == 10: cpu.cc = v & 0xFF
    elif code == 11: cpu.dp = v & 0xFF
    else: raise SimError("tfr/exg register %d" % code)

class SimError(Exception):
    pass

# ------------------------------------------------------ addressing modes
def ea_indexed():
    pb = fetch8()
    rname = {0: 'x', 1: 'y', 2: 'u', 3: 's'}[(pb >> 5) & 3]
    r = getattr(cpu, rname)
    if not (pb & 0x80):                                   # 5-bit offset
        off = pb & 0x1F
        if off & 0x10: off -= 32
        return (r + off) & 0xFFFF
    mode = pb & 0x0F
    ind = pb & 0x10
    if   mode == 0x0: ea = r; setattr(cpu, rname, (r + 1) & 0xFFFF)   # ,R+
    elif mode == 0x1: ea = r; setattr(cpu, rname, (r + 2) & 0xFFFF)   # ,R++
    elif mode == 0x2: r = (r - 1) & 0xFFFF; setattr(cpu, rname, r); ea = r
    elif mode == 0x3: r = (r - 2) & 0xFFFF; setattr(cpu, rname, r); ea = r
    elif mode == 0x4: ea = r                                          # ,R
    elif mode == 0x5:                                                 # B,R
        off = cpu.b - (256 if cpu.b & 0x80 else 0); ea = (r + off) & 0xFFFF
    elif mode == 0x6:                                                 # A,R
        off = cpu.a - (256 if cpu.a & 0x80 else 0); ea = (r + off) & 0xFFFF
    elif mode == 0x8:                                                 # n8,R
        off = fetch8(); off -= 256 if off & 0x80 else 0
        ea = (r + off) & 0xFFFF
    elif mode == 0x9:                                                 # n16,R
        off = fetch16(); off -= 65536 if off & 0x8000 else 0
        ea = (r + off) & 0xFFFF
    elif mode == 0xB:                                                 # D,R
        off = cpu.d; off -= 65536 if off & 0x8000 else 0
        ea = (r + off) & 0xFFFF
    elif mode == 0xC:                                                 # n8,PCR
        off = fetch8(); off -= 256 if off & 0x80 else 0
        ea = (cpu.pc + off) & 0xFFFF
    elif mode == 0xD:                                                 # n16,PCR
        off = fetch16(); off -= 65536 if off & 0x8000 else 0
        ea = (cpu.pc + off) & 0xFFFF
    elif mode == 0xF: ea = fetch16()                                  # [n16]
    else:
        raise SimError("indexed postbyte $%02X" % pb)
    if ind: ea = rd16(ea)
    return ea

def ea_direct(): return ((cpu.dp << 8) | fetch8()) & 0xFFFF
def ea_extended(): return fetch16()

# ------------------------------------------------------------ arithmetic
def sub8(x, yv, carry=0):
    r = x - yv - carry
    setf(C, r < 0)
    setf(V, ((x ^ yv) & (x ^ (r & 0xFF)) & 0x80) != 0)
    r &= 0xFF; nz8(r); return r
def add8(x, yv, carry=0):
    r = x + yv + carry
    setf(C, r > 0xFF)
    setf(V, ((~(x ^ yv)) & (x ^ (r & 0xFF)) & 0x80) != 0)
    setf(H, ((x & 0xF) + (yv & 0xF) + carry) > 0xF)
    r &= 0xFF; nz8(r); return r
def sub16(x, yv):
    r = x - yv
    setf(C, r < 0)
    setf(V, ((x ^ yv) & (x ^ (r & 0xFFFF)) & 0x8000) != 0)
    r &= 0xFFFF; nz16(r); return r
def add16(x, yv):
    r = x + yv
    setf(C, r > 0xFFFF)
    setf(V, ((~(x ^ yv)) & (x ^ (r & 0xFFFF)) & 0x8000) != 0)
    r &= 0xFFFF; nz16(r); return r

def log8(v):                       # flags for logical results
    v &= 0xFF; nz8(v); setf(V, 0); return v

def lsr8(v): setf(C, v & 1); v >>= 1; nz8(v); return v
def asr8(v):
    setf(C, v & 1); v = (v >> 1) | (v & 0x80); nz8(v); return v
def lsl8(v):
    setf(C, v & 0x80); setf(V, bool(v & 0x80) != bool(v & 0x40))
    v = (v << 1) & 0xFF; nz8(v); return v
def rol8(v):
    c = 1 if cpu.cc & C else 0
    setf(C, v & 0x80); setf(V, bool(v & 0x80) != bool(v & 0x40))
    v = ((v << 1) | c) & 0xFF; nz8(v); return v
def ror8(v):
    c = 0x80 if cpu.cc & C else 0
    setf(C, v & 1); v = (v >> 1) | c; nz8(v); return v
def com8(v):
    v = (~v) & 0xFF; nz8(v); setf(V, 0); setf(C, 1); return v
def neg8(v):
    return sub8(0, v)
def inc8(v):
    v = (v + 1) & 0xFF; nz8(v); setf(V, v == 0x80); return v
def dec8(v):
    v = (v - 1) & 0xFF; nz8(v); setf(V, v == 0x7F); return v

# ------------------------------------------------------------- branches
def branch(cond_ok):
    off = fetch8()
    if off & 0x80: off -= 256
    if cond_ok: cpu.pc = (cpu.pc + off) & 0xFFFF
def lbranch(cond_ok):
    off = fetch16()
    if off & 0x8000: off -= 65536
    if cond_ok: cpu.pc = (cpu.pc + off) & 0xFFFF
def cond(code):
    cc = cpu.cc
    return {
        0x0: True, 0x1: False,
        0x2: not (cc & C or cc & Z), 0x3: bool(cc & C or cc & Z),
        0x4: not cc & C, 0x5: bool(cc & C),
        0x6: not cc & Z, 0x7: bool(cc & Z),
        0x8: not cc & V, 0x9: bool(cc & V),
        0xA: not cc & N, 0xB: bool(cc & N),
        0xC: bool(cc & N) == bool(cc & V),
        0xD: bool(cc & N) != bool(cc & V),
        0xE: (not cc & Z) and (bool(cc & N) == bool(cc & V)),
        0xF: bool(cc & Z) or (bool(cc & N) != bool(cc & V)),
    }[code]

def pshs_list(mask):
    if mask & 0x80: push16(cpu.pc)
    if mask & 0x40: push16(cpu.u)
    if mask & 0x20: push16(cpu.y)
    if mask & 0x10: push16(cpu.x)
    if mask & 0x08: push8(cpu.dp)
    if mask & 0x04: push8(cpu.b)
    if mask & 0x02: push8(cpu.a)
    if mask & 0x01: push8(cpu.cc)
def puls_list(mask):
    if mask & 0x01: cpu.cc = pull8()
    if mask & 0x02: cpu.a = pull8()
    if mask & 0x04: cpu.b = pull8()
    if mask & 0x08: cpu.dp = pull8()
    if mask & 0x10: cpu.x = pull16()
    if mask & 0x20: cpu.y = pull16()
    if mask & 0x40: cpu.u = pull16()
    if mask & 0x80: cpu.pc = pull16()
def pshu_list(mask):
    def pu16(v): cpu.u = (cpu.u - 2) & 0xFFFF; wr16(cpu.u, v)
    def pu8(v): cpu.u = (cpu.u - 1) & 0xFFFF; wr8(cpu.u, v)
    if mask & 0x80: pu16(cpu.pc)
    if mask & 0x40: pu16(cpu.s)
    if mask & 0x20: pu16(cpu.y)
    if mask & 0x10: pu16(cpu.x)
    if mask & 0x08: pu8(cpu.dp)
    if mask & 0x04: pu8(cpu.b)
    if mask & 0x02: pu8(cpu.a)
    if mask & 0x01: pu8(cpu.cc)
def pulu_list(mask):
    def gu8():
        v = rd8(cpu.u); cpu.u = (cpu.u + 1) & 0xFFFF; return v
    def gu16():
        v = rd16(cpu.u); cpu.u = (cpu.u + 2) & 0xFFFF; return v
    if mask & 0x01: cpu.cc = gu8()
    if mask & 0x02: cpu.a = gu8()
    if mask & 0x04: cpu.b = gu8()
    if mask & 0x08: cpu.dp = gu8()
    if mask & 0x10: cpu.x = gu16()
    if mask & 0x20: cpu.y = gu16()
    if mask & 0x40: cpu.s = gu16()
    if mask & 0x80: cpu.pc = gu16()

# ------------------------------------------------------ OS-9 environment
class OS9Env:
    """Stubbed kernel: synthetic directory, captured output."""
    E_EOF = 0xD3
    def __init__(self, args):
        self.out_chunks = []
        self.exit_code = None
        self.width = args.width
        self.pipe = args.pipe
        names = args.files.split(',') if args.files else [
            "startup", "CMDS", "zebra.txt", "a", "Alphabet", "midfile",
            "OS9Boot", "SYS", "verylongfilename.bin", "b2", "tmp"]
        ents = [self.dirent("..", 1), self.dirent(".", 2), b"\x00" * 32]
        for i, n in enumerate(names):
            ents.append(self.dirent(n, 0x100 + i))
        self.readdata = b"".join(ents)
        self.readpos = 0

    @staticmethod
    def dirent(nm, lsn):
        e = bytearray(32)
        raw = nm.encode()[:29]
        e[:len(raw)] = raw
        e[len(raw) - 1] |= 0x80
        e[29] = (lsn >> 16) & 0xFF; e[30] = (lsn >> 8) & 0xFF; e[31] = lsn & 0xFF
        return bytes(e)

    def syscall(self, code):
        if code in (0x84, 0x83, 0x86):            # I$Open / I$Create / I$ChgDir
            x = cpu.x
            name = bytearray()
            while rd8(x) not in (0x0D, 0x20, 0x2C):
                name.append(rd8(x)); x += 1
            base = bytes(name).split(b"/")[-1]
            # opening in DIR. mode fails for file-looking names so that
            # commands' "not a directory" fallbacks can be exercised
            if code == 0x84 and cpu.a & 0x80 and b"." in base \
                    and base not in (b".", b".."):
                cpu.b = 0xCB                      # E$BMode
                setf(C, True)
                return
            if code != 0x86:
                cpu.a = 3
            cpu.x = x
            setf(C, False)
        elif code == 0x8F:                        # I$Close
            setf(C, False)
        elif code == 0x88:                        # I$Seek (X:U = position)
            self.readpos = min(((cpu.x << 16) | cpu.u), len(self.readdata))
            setf(C, False)
        elif code in (0x89, 0x8B):                # I$Read / I$ReadLn
            n = min(cpu.y, len(self.readdata) - self.readpos)
            if code == 0x8B and n:                # ReadLn stops after CR
                chunk = self.readdata[self.readpos:self.readpos + n]
                cr = chunk.find(b"\r")
                if cr >= 0: n = cr + 1
            if n == 0:
                cpu.b = self.E_EOF
                setf(C, True)
                return
            for i in range(n):
                wr8(cpu.x + i, self.readdata[self.readpos + i])
            self.readpos += n
            cpu.y = n
            setf(C, False)
        elif code == 0x8A:                        # I$Write
            self.out_chunks.append(bytes(MEM[cpu.x:cpu.x + cpu.y]))
            setf(C, False)
        elif code == 0x8C:                        # I$WritLn
            data = bytes(MEM[cpu.x:cpu.x + cpu.y])
            cr = data.find(b"\r")
            if cr >= 0: data = data[:cr + 1]
            self.out_chunks.append(data)
            cpu.y = len(data)
            setf(C, False)
        elif code == 0x8D:                        # I$GetStt
            self.getstt()
        elif code == 0x8E:                        # I$SetStt
            setf(C, False)
        elif code == 0x06:                        # F$Exit
            self.exit_code = cpu.b
            cpu.running = False
        elif code == 0x0C:                        # F$ID
            cpu.a = 5; cpu.y = 0
            setf(C, False)
        elif code == 0x15:                        # F$Time
            for i, v in enumerate((126, 6, 12, 15, 30, 0)):
                wr8(cpu.x + i, v)
            setf(C, False)
        else:
            raise SimError("unimplemented OS9 request $%02X" % code)

    def getstt(self):
        fn = cpu.b
        if fn == 0x00:                            # SS.Opt
            if self.pipe:
                return                            # leave buffer untouched
            wr8(cpu.x + 0, 0)                     # DT.SCF
            wr8(cpu.x + 5, 1)                     # PD.ALF on
            setf(C, False)
        elif fn == 0x26:                          # SS.ScSiz
            if self.pipe:
                setf(C, False)                    # piper-style no-op
                return
            cpu.x = self.width
            setf(C, False)
        elif fn == 0x20:                          # SS.FDInf
            fd = bytes([0x0B, 0, 0, 126, 6, 12, 15, 30, 1, 0, 0, 0x12, 0x34])
            for i, v in enumerate(fd):
                wr8(cpu.x + i, v)
            setf(C, False)
        elif fn == 0x06:                          # SS.EOF
            atend = self.readpos >= len(self.readdata)
            cpu.b = self.E_EOF if atend else 0
            setf(C, atend)
        else:
            cpu.b = 0xD0                          # E$UnkSvc
            setf(C, True)

ENV = None

# ----------------------------------------------------------- interpreter
def step():
    pc0 = cpu.pc
    op = fetch8()

    if op == 0x10:                                 # page 2
        op2 = fetch8()
        if 0x21 <= op2 <= 0x2F: lbranch(cond(op2 & 0xF))
        elif op2 == 0x83: sub16(cpu.d, fetch16())
        elif op2 == 0x93: sub16(cpu.d, rd16(ea_direct()))
        elif op2 == 0xA3: sub16(cpu.d, rd16(ea_indexed()))
        elif op2 == 0xB3: sub16(cpu.d, rd16(ea_extended()))
        elif op2 == 0x8C: sub16(cpu.y, fetch16())
        elif op2 == 0x9C: sub16(cpu.y, rd16(ea_direct()))
        elif op2 == 0xAC: sub16(cpu.y, rd16(ea_indexed()))
        elif op2 == 0x8E: cpu.y = fetch16(); nz16(cpu.y); setf(V, 0)
        elif op2 == 0x9E: cpu.y = rd16(ea_direct()); nz16(cpu.y); setf(V, 0)
        elif op2 == 0xAE: cpu.y = rd16(ea_indexed()); nz16(cpu.y); setf(V, 0)
        elif op2 == 0xBE: cpu.y = rd16(ea_extended()); nz16(cpu.y); setf(V, 0)
        elif op2 == 0x9F: wr16(ea_direct(), cpu.y); nz16(cpu.y); setf(V, 0)
        elif op2 == 0xAF: wr16(ea_indexed(), cpu.y); nz16(cpu.y); setf(V, 0)
        elif op2 == 0xBF: wr16(ea_extended(), cpu.y); nz16(cpu.y); setf(V, 0)
        elif op2 == 0xCE: cpu.s = fetch16()
        elif op2 == 0xDE: cpu.s = rd16(ea_direct())
        elif op2 == 0xEE: cpu.s = rd16(ea_indexed())
        elif op2 == 0xDF: wr16(ea_direct(), cpu.s)
        elif op2 == 0xEF: wr16(ea_indexed(), cpu.s)
        elif op2 == 0x3F: ENV.syscall(fetch8())    # os9 (swi2 + code)
        else: raise SimError("opcode 10 %02X" % op2)
        return
    if op == 0x11:                                 # page 3
        op2 = fetch8()
        if   op2 == 0x83: sub16(cpu.u, fetch16())
        elif op2 == 0x93: sub16(cpu.u, rd16(ea_direct()))
        elif op2 == 0xA3: sub16(cpu.u, rd16(ea_indexed()))
        elif op2 == 0x8C: sub16(cpu.s, fetch16())
        elif op2 == 0x9C: sub16(cpu.s, rd16(ea_direct()))
        elif op2 == 0xAC: sub16(cpu.s, rd16(ea_indexed()))
        else: raise SimError("opcode 11 %02X" % op2)
        return

    # --- columns 0x00-0x0F: direct-page read/modify/write
    if op in (0x00, 0x03, 0x04, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0C, 0x0D, 0x0F):
        a = ea_direct()
        v = rd8(a)
        if   op == 0x00: v = neg8(v)
        elif op == 0x03: v = com8(v)
        elif op == 0x04: v = lsr8(v)
        elif op == 0x06: v = ror8(v)
        elif op == 0x07: v = asr8(v)
        elif op == 0x08: v = lsl8(v)
        elif op == 0x09: v = rol8(v)
        elif op == 0x0A: v = dec8(v)
        elif op == 0x0C: v = inc8(v)
        elif op == 0x0D: nz8(v); setf(V, 0); return
        elif op == 0x0F: v = 0; cpu.cc = (cpu.cc & ~(N | V | C)) | Z
        wr8(a, v); return
    if op in (0x60, 0x63, 0x64, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6C, 0x6D, 0x6F):
        a = ea_indexed()
        v = rd8(a)
        if   op == 0x60: v = neg8(v)
        elif op == 0x63: v = com8(v)
        elif op == 0x64: v = lsr8(v)
        elif op == 0x66: v = ror8(v)
        elif op == 0x67: v = asr8(v)
        elif op == 0x68: v = lsl8(v)
        elif op == 0x69: v = rol8(v)
        elif op == 0x6A: v = dec8(v)
        elif op == 0x6C: v = inc8(v)
        elif op == 0x6D: nz8(v); setf(V, 0); return
        elif op == 0x6F: v = 0; cpu.cc = (cpu.cc & ~(N | V | C)) | Z
        wr8(a, v); return
    if op in (0x70, 0x73, 0x74, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x7C, 0x7D, 0x7F):
        a = ea_extended()
        v = rd8(a)
        if   op == 0x70: v = neg8(v)
        elif op == 0x73: v = com8(v)
        elif op == 0x74: v = lsr8(v)
        elif op == 0x76: v = ror8(v)
        elif op == 0x77: v = asr8(v)
        elif op == 0x78: v = lsl8(v)
        elif op == 0x79: v = rol8(v)
        elif op == 0x7A: v = dec8(v)
        elif op == 0x7C: v = inc8(v)
        elif op == 0x7D: nz8(v); setf(V, 0); return
        elif op == 0x7F: v = 0; cpu.cc = (cpu.cc & ~(N | V | C)) | Z
        wr8(a, v); return

    # --- inherent
    if   op == 0x12: return                                    # nop
    elif op == 0x16: lbranch(True)
    elif op == 0x17:
        off = fetch16(); off -= 65536 if off & 0x8000 else 0
        push16(cpu.pc); cpu.pc = (cpu.pc + off) & 0xFFFF       # lbsr
    elif op == 0x1A: cpu.cc |= fetch8()                        # orcc
    elif op == 0x1C: cpu.cc &= fetch8()                        # andcc
    elif op == 0x1D:                                           # sex
        cpu.a = 0xFF if cpu.b & 0x80 else 0; nz16(cpu.d)
    elif op == 0x1E:                                           # exg
        pb = fetch8(); r1, r2 = (pb >> 4) & 0xF, pb & 0xF
        t = getreg(r1); setreg(r1, getreg(r2)); setreg(r2, t)
    elif op == 0x1F:                                           # tfr
        pb = fetch8(); setreg(pb & 0xF, getreg((pb >> 4) & 0xF))
    elif 0x20 <= op <= 0x2F: branch(cond(op & 0xF))
    elif op == 0x30: cpu.x = ea_indexed(); setf(Z, cpu.x == 0)
    elif op == 0x31: cpu.y = ea_indexed(); setf(Z, cpu.y == 0)
    elif op == 0x32: cpu.s = ea_indexed()
    elif op == 0x33: cpu.u = ea_indexed()
    elif op == 0x34: pshs_list(fetch8())
    elif op == 0x35: puls_list(fetch8())
    elif op == 0x36: pshu_list(fetch8())
    elif op == 0x37: pulu_list(fetch8())
    elif op == 0x39: cpu.pc = pull16()                         # rts
    elif op == 0x3A: cpu.x = (cpu.x + cpu.b) & 0xFFFF          # abx
    elif op == 0x3D:                                           # mul
        r = cpu.a * cpu.b; cpu.d = r; setf(Z, r == 0); setf(C, r & 0x80)
    # --- A inherent
    elif op == 0x40: cpu.a = neg8(cpu.a)
    elif op == 0x43: cpu.a = com8(cpu.a)
    elif op == 0x44: cpu.a = lsr8(cpu.a)
    elif op == 0x46: cpu.a = ror8(cpu.a)
    elif op == 0x47: cpu.a = asr8(cpu.a)
    elif op == 0x48: cpu.a = lsl8(cpu.a)
    elif op == 0x49: cpu.a = rol8(cpu.a)
    elif op == 0x4A: cpu.a = dec8(cpu.a)
    elif op == 0x4C: cpu.a = inc8(cpu.a)
    elif op == 0x4D: nz8(cpu.a); setf(V, 0)
    elif op == 0x4F: cpu.a = 0; cpu.cc = (cpu.cc & ~(N | V | C)) | Z
    # --- B inherent
    elif op == 0x50: cpu.b = neg8(cpu.b)
    elif op == 0x53: cpu.b = com8(cpu.b)
    elif op == 0x54: cpu.b = lsr8(cpu.b)
    elif op == 0x56: cpu.b = ror8(cpu.b)
    elif op == 0x57: cpu.b = asr8(cpu.b)
    elif op == 0x58: cpu.b = lsl8(cpu.b)
    elif op == 0x59: cpu.b = rol8(cpu.b)
    elif op == 0x5A: cpu.b = dec8(cpu.b)
    elif op == 0x5C: cpu.b = inc8(cpu.b)
    elif op == 0x5D: nz8(cpu.b); setf(V, 0)
    elif op == 0x5F: cpu.b = 0; cpu.cc = (cpu.cc & ~(N | V | C)) | Z
    # --- jumps
    elif op == 0x0E: cpu.pc = ea_direct()                      # jmp dir
    elif op == 0x6E: cpu.pc = ea_indexed()                     # jmp idx
    elif op == 0x7E: cpu.pc = ea_extended()                    # jmp ext
    elif op == 0x9D: a = ea_direct(); push16(cpu.pc); cpu.pc = a
    elif op == 0xAD: a = ea_indexed(); push16(cpu.pc); cpu.pc = a
    elif op == 0xBD: a = ea_extended(); push16(cpu.pc); cpu.pc = a
    elif op == 0x8D:                                           # bsr
        off = fetch8(); off -= 256 if off & 0x80 else 0
        push16(cpu.pc); cpu.pc = (cpu.pc + off) & 0xFFFF
    # --- A loads/stores/alu
    elif op == 0x86: cpu.a = log8(fetch8())
    elif op == 0x96: cpu.a = log8(rd8(ea_direct()))
    elif op == 0xA6: cpu.a = log8(rd8(ea_indexed()))
    elif op == 0xB6: cpu.a = log8(rd8(ea_extended()))
    elif op == 0x97: wr8(ea_direct(), cpu.a); log8(cpu.a)
    elif op == 0xA7: wr8(ea_indexed(), cpu.a); log8(cpu.a)
    elif op == 0xB7: wr8(ea_extended(), cpu.a); log8(cpu.a)
    elif op == 0x80: cpu.a = sub8(cpu.a, fetch8())
    elif op == 0x90: cpu.a = sub8(cpu.a, rd8(ea_direct()))
    elif op == 0xA0: cpu.a = sub8(cpu.a, rd8(ea_indexed()))
    elif op == 0x81: sub8(cpu.a, fetch8())
    elif op == 0x91: sub8(cpu.a, rd8(ea_direct()))
    elif op == 0xA1: sub8(cpu.a, rd8(ea_indexed()))
    elif op == 0x82: cpu.a = sub8(cpu.a, fetch8(), 1 if cpu.cc & C else 0)
    elif op == 0x84: cpu.a = log8(cpu.a & fetch8())
    elif op == 0x94: cpu.a = log8(cpu.a & rd8(ea_direct()))
    elif op == 0xA4: cpu.a = log8(cpu.a & rd8(ea_indexed()))
    elif op == 0x85: log8(cpu.a & fetch8())                    # bita
    elif op == 0x95: log8(cpu.a & rd8(ea_direct()))
    elif op == 0xA5: log8(cpu.a & rd8(ea_indexed()))
    elif op == 0x88: cpu.a = log8(cpu.a ^ fetch8())
    elif op == 0x98: cpu.a = log8(cpu.a ^ rd8(ea_direct()))
    elif op == 0xA8: cpu.a = log8(cpu.a ^ rd8(ea_indexed()))
    elif op == 0x89: cpu.a = add8(cpu.a, fetch8(), 1 if cpu.cc & C else 0)
    elif op == 0x8A: cpu.a = log8(cpu.a | fetch8())
    elif op == 0x9A: cpu.a = log8(cpu.a | rd8(ea_direct()))
    elif op == 0xAA: cpu.a = log8(cpu.a | rd8(ea_indexed()))
    elif op == 0x8B: cpu.a = add8(cpu.a, fetch8())
    elif op == 0x9B: cpu.a = add8(cpu.a, rd8(ea_direct()))
    elif op == 0xAB: cpu.a = add8(cpu.a, rd8(ea_indexed()))
    # --- B loads/stores/alu
    elif op == 0xC6: cpu.b = log8(fetch8())
    elif op == 0xD6: cpu.b = log8(rd8(ea_direct()))
    elif op == 0xE6: cpu.b = log8(rd8(ea_indexed()))
    elif op == 0xF6: cpu.b = log8(rd8(ea_extended()))
    elif op == 0xD7: wr8(ea_direct(), cpu.b); log8(cpu.b)
    elif op == 0xE7: wr8(ea_indexed(), cpu.b); log8(cpu.b)
    elif op == 0xF7: wr8(ea_extended(), cpu.b); log8(cpu.b)
    elif op == 0xC0: cpu.b = sub8(cpu.b, fetch8())
    elif op == 0xD0: cpu.b = sub8(cpu.b, rd8(ea_direct()))
    elif op == 0xE0: cpu.b = sub8(cpu.b, rd8(ea_indexed()))
    elif op == 0xC1: sub8(cpu.b, fetch8())
    elif op == 0xD1: sub8(cpu.b, rd8(ea_direct()))
    elif op == 0xE1: sub8(cpu.b, rd8(ea_indexed()))
    elif op == 0xC2: cpu.b = sub8(cpu.b, fetch8(), 1 if cpu.cc & C else 0)
    elif op == 0xC4: cpu.b = log8(cpu.b & fetch8())
    elif op == 0xD4: cpu.b = log8(cpu.b & rd8(ea_direct()))
    elif op == 0xE4: cpu.b = log8(cpu.b & rd8(ea_indexed()))
    elif op == 0xC5: log8(cpu.b & fetch8())                    # bitb
    elif op == 0xD5: log8(cpu.b & rd8(ea_direct()))
    elif op == 0xE5: log8(cpu.b & rd8(ea_indexed()))
    elif op == 0xC8: cpu.b = log8(cpu.b ^ fetch8())
    elif op == 0xD8: cpu.b = log8(cpu.b ^ rd8(ea_direct()))
    elif op == 0xE8: cpu.b = log8(cpu.b ^ rd8(ea_indexed()))
    elif op == 0xC9: cpu.b = add8(cpu.b, fetch8(), 1 if cpu.cc & C else 0)
    elif op == 0xCA: cpu.b = log8(cpu.b | fetch8())
    elif op == 0xDA: cpu.b = log8(cpu.b | rd8(ea_direct()))
    elif op == 0xEA: cpu.b = log8(cpu.b | rd8(ea_indexed()))
    elif op == 0xCB: cpu.b = add8(cpu.b, fetch8())
    elif op == 0xDB: cpu.b = add8(cpu.b, rd8(ea_direct()))
    elif op == 0xEB: cpu.b = add8(cpu.b, rd8(ea_indexed()))
    # --- D
    elif op == 0xCC: cpu.d = fetch16(); nz16(cpu.d); setf(V, 0)
    elif op == 0xDC: cpu.d = rd16(ea_direct()); nz16(cpu.d); setf(V, 0)
    elif op == 0xEC: cpu.d = rd16(ea_indexed()); nz16(cpu.d); setf(V, 0)
    elif op == 0xFC: cpu.d = rd16(ea_extended()); nz16(cpu.d); setf(V, 0)
    elif op == 0xDD: wr16(ea_direct(), cpu.d); nz16(cpu.d); setf(V, 0)
    elif op == 0xED: wr16(ea_indexed(), cpu.d); nz16(cpu.d); setf(V, 0)
    elif op == 0xFD: wr16(ea_extended(), cpu.d); nz16(cpu.d); setf(V, 0)
    elif op == 0x83: cpu.d = sub16(cpu.d, fetch16())
    elif op == 0x93: cpu.d = sub16(cpu.d, rd16(ea_direct()))
    elif op == 0xA3: cpu.d = sub16(cpu.d, rd16(ea_indexed()))
    elif op == 0xC3: cpu.d = add16(cpu.d, fetch16())
    elif op == 0xD3: cpu.d = add16(cpu.d, rd16(ea_direct()))
    elif op == 0xE3: cpu.d = add16(cpu.d, rd16(ea_indexed()))
    # --- X
    elif op == 0x8E: cpu.x = fetch16(); nz16(cpu.x); setf(V, 0)
    elif op == 0x9E: cpu.x = rd16(ea_direct()); nz16(cpu.x); setf(V, 0)
    elif op == 0xAE: cpu.x = rd16(ea_indexed()); nz16(cpu.x); setf(V, 0)
    elif op == 0xBE: cpu.x = rd16(ea_extended()); nz16(cpu.x); setf(V, 0)
    elif op == 0x9F: wr16(ea_direct(), cpu.x); nz16(cpu.x); setf(V, 0)
    elif op == 0xAF: wr16(ea_indexed(), cpu.x); nz16(cpu.x); setf(V, 0)
    elif op == 0xBF: wr16(ea_extended(), cpu.x); nz16(cpu.x); setf(V, 0)
    elif op == 0x8C: sub16(cpu.x, fetch16())
    elif op == 0x9C: sub16(cpu.x, rd16(ea_direct()))
    elif op == 0xAC: sub16(cpu.x, rd16(ea_indexed()))
    # --- U
    elif op == 0xCE: cpu.u = fetch16(); nz16(cpu.u); setf(V, 0)
    elif op == 0xDE: cpu.u = rd16(ea_direct()); nz16(cpu.u); setf(V, 0)
    elif op == 0xEE: cpu.u = rd16(ea_indexed()); nz16(cpu.u); setf(V, 0)
    elif op == 0xFE: cpu.u = rd16(ea_extended()); nz16(cpu.u); setf(V, 0)
    elif op == 0xDF: wr16(ea_direct(), cpu.u); nz16(cpu.u); setf(V, 0)
    elif op == 0xEF: wr16(ea_indexed(), cpu.u); nz16(cpu.u); setf(V, 0)
    elif op == 0xFF: wr16(ea_extended(), cpu.u); nz16(cpu.u); setf(V, 0)
    else:
        raise SimError("opcode $%02X at module offset $%04X" % (op, pc0))

# ------------------------------------------------------------------ main
MODBASE = 0x1000
DATBASE = 0x4000

def main():
    global ENV
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("module", help="assembled OS-9 program module")
    ap.add_argument("--params", default="", help="command line parameters")
    ap.add_argument("--width", type=int, default=80, help="SS.ScSiz width")
    ap.add_argument("--pipe", action="store_true",
                    help="stdout behaves like a pipe (no SS.Opt data, no LF)")
    ap.add_argument("--files", default=None,
                    help="comma-separated fake directory entries")
    ap.add_argument("--max-steps", type=int, default=5_000_000)
    ap.add_argument("--raw", action="store_true",
                    help="dump captured output bytes verbatim")
    args = ap.parse_args()

    mod = open(args.module, "rb").read()
    if mod[:2] != b"\x87\xCD":
        sys.exit("not an OS-9 module (no $87CD sync)")
    ENV = globals()['ENV'] = OS9Env(args)

    MEM[MODBASE:MODBASE + len(mod)] = mod
    datsz = (mod[11] << 8) | mod[12]
    pb = (args.params + "\r").encode()
    parbase = DATBASE + datsz
    MEM[parbase:parbase + len(pb)] = pb
    cpu.u = DATBASE; cpu.dp = DATBASE >> 8
    cpu.x = parbase; cpu.y = parbase + len(pb); cpu.s = parbase
    cpu.pc = MODBASE + ((mod[9] << 8) | mod[10])
    cpu.a = 0; cpu.b = len(pb)

    ring = []
    n = 0
    status = 0
    try:
        while cpu.running and n < args.max_steps:
            ring.append(cpu.pc)
            if len(ring) > 48: ring.pop(0)
            step()
            n += 1
        if cpu.running:
            print("!! still running after %d steps (infinite loop?)" % n)
            status = 2
    except SimError as e:
        print("!! %s" % e)
        print("!! last PCs (module-relative):",
              " ".join("%04X" % ((p - MODBASE) & 0xFFFF) for p in ring))
        status = 1

    out = b"".join(ENV.out_chunks)
    print("exit=%s  steps=%d  writes=%d  bytes=%d"
          % (ENV.exit_code, n, len(ENV.out_chunks), len(out)))
    bad = sorted(set(b for b in out if b < 0x20 and b not in (0x0D, 0x0A)))
    if bad:
        print("!! control bytes in output:", ["$%02X" % b for b in bad])
        status = max(status, 1)
    print("-" * 60)
    if args.raw:
        sys.stdout.buffer.write(out)
    else:
        sys.stdout.write(out.decode("latin1")
                         .replace("\r\n", "\n").replace("\r", "\n"))
    print("-" * 60)
    sys.exit(status if status else (0 if ENV.exit_code == 0 else 3))

if __name__ == "__main__":
    main()
