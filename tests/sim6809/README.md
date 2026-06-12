# sim6809 — host-side smoke testing for NitrOS-9 command modules

Runs an assembled OS-9 program module (the output of `lwasm --format=os9`)
in a small 6809 interpreter on your Mac/PC, with the common OS-9 service
requests stubbed out. The point is to catch logic bugs — wild pointers,
bad loop bounds, wrong addressing modes, broken formatting — *before*
copying a command to a real CoCo or emulator.

It earned its keep on day one: running the new `ls` here found a
`ldx [d,x]` that should have been `ldx d,x` (indirect vs. accumulator
indexing — garbage on screen), a clobbered length register that skewed
the column padding, and a decimal converter fed the wrong residue.
Three bugs that several careful source reviews had missed.

## Usage

```
python3 tests/sim6809/sim6809.py level1/coco1/cmds/ls
python3 tests/sim6809/sim6809.py level1/coco1/cmds/ls --params=-l
python3 tests/sim6809/sim6809.py level1/coco1/cmds/ls --width 32
python3 tests/sim6809/sim6809.py level1/coco1/cmds/ls --pipe
python3 tests/sim6809/sim6809.py level1/coco1/cmds/ls --files a,b,Zed.bin
```

(Use the `--params=-l` form when the parameter string starts with a
dash, or argparse will eat it.)

The process environment matches what the kernel provides: U/DP at the
data area, X pointing at the parameter string (`--params` plus a CR),
Y at the top of memory, S below the parameters.

Output is captured and printed between rulers, with a summary line
(exit code, step count, number of writes, byte count). Control bytes
other than CR/LF in the output are flagged — on a real window device
those fly the cursor around. The exit status is nonzero on simulator
errors, control-byte warnings, or a nonzero F$Exit code, so it can be
scripted.

## Stubbed services

| Request | Behavior |
|---|---|
| I$Open / I$Create | succeeds (path 3), consumes the pathname |
| I$Read / I$ReadLn | feeds a synthetic RBF directory: `..`, `.`, one deleted entry, then the `--files` list (or a built-in mixed-case set) |
| I$Write / I$WritLn | captured |
| I$Close, I$SetStt | succeed |
| I$GetStt | SS.Opt (SCF + auto-LF, or untouched with `--pipe`), SS.ScSiz (`--width`, piper-style no-op with `--pipe`), SS.FDInf (canned descriptor: 2026/06/12 15:30, size $1234), SS.EOF |
| F$Exit | ends the run |
| F$Time, F$ID | canned values |

Anything else raises a clean error with a trace of the last ~48
instruction addresses (module-relative, so they line up with the
`lwasm --list` output). Add the stub you need; they are all in
`OS9Env.syscall`.

## Limits — read this before trusting a green run

- **6809 only.** No 6309 instructions (TFM, the W register, etc.).
  The kernel's `IFNE H6309` paths cannot be tested here.
- **Not cycle accurate, no interrupts.** This checks logic, not timing
  or IRQ safety, and it cannot validate kernel/driver code.
- The opcode table covers what command modules typically use. An
  unimplemented opcode stops the run loudly — it never guesses.
- Stubs are deliberately simple. A clean run here means the logic
  holds against a sane kernel; it does not replace a boot test.

## Workflow

1. `make` the command in its port directory (e.g. `level1/coco1/cmds`).
2. Run it here, in the modes it supports (default, options, `--pipe`,
   narrow `--width`). The full directory listing should arrive in as
   few writes as the program's buffering promises.
3. If it dies, the trace PCs index straight into the assembler listing:
   `lwasm ... --list=ls.lst` and look up the offsets.
4. Only then put it on a disk image.
