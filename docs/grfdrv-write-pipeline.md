# CoWin/GRFDRV write & scroll pipeline: performance notes

Research notes from a review of character-write and scrolling performance for
graphics windows (`cogrf.io`, built from `cowin.asm` with `-DCoGrf=1`) on the
CoCo3/GIME. Captures a call chain that spans four files across two levels, plus
a couple of corrected assumptions worth not re-making.

The chain, top to bottom: `level1/modules/scf.asm` (SCF file manager, shared by
all SCF drivers) &rarr; `level2/coco3/modules/vtio.asm` (virtual terminal I/O)
&rarr; `level2/coco3/modules/cowin.asm` (windowing) &rarr;
`level2/cmds/grfdrv.asm` (GIME graphics driver, runs as a separate MMU task)
&rarr; `level2/modules/kernel/ccbkrn.asm` (task-flip primitives).

## 1. Why a single character write to a graphics window is expensive

The video buffer, font buffers, and get/put buffers are **not** mapped into a
process's normal 64K address space ("Task 0"). GRFDRV keeps its own private
GIME MMU mapping ("Task 1") and moves itself there to touch any of that memory
(`cowin.asm:236`: *"Grfdrv will move itself over to task 1 & setup it's own
memory map"*; block registers written directly at `grfdrv.asm:543-561`,
`$FFAC`-`$FFAF`).

`cowin.asm`'s per-character `Write` entry (`cowin.asm:610-723`) reaches this
via `L0101`, which builds a fake-RTI register frame and jumps through
`[D.Flip1]`/`[D.Flip0]` (`defs/os9.d:672-673`: *"Change to Task 0"* / *"Change
to reserved Task 1"*).

**Correction made mid-investigation:** this is not a full OS-9 process
reschedule. `S.Flip1` (`level2/modules/kernel/ccbkrn.asm:942-984`) is a
hardware MMU task-select bit flip plus a register-dump/RTI round trip — no
scheduler involvement. It also has a fast path: `KrnWeGngBack`
(`ccbkrn.asm:959-984`) skips reprogramming all 8 physical MMU block registers
if Task 1's map is already the one requested (`cmpb <D.Task1N`). Since GRFDRV
always requests the same fixed image number (`ldb #2`,
`ccbkrn.asm:944`), that fast path hits on essentially every consecutive
GRFDRV call — the 8-register block copy is not a recurring per-character cost
in steady state. The real recurring cost is the register-dump/RTI + DP switch
+ IRQ mask/unmask machinery itself, roughly 100-200 cycles round trip — real,
but much less than a full context switch. Don't restate the "full process
switch" framing; it's wrong.

## 2. Batching for CoWin windows already exists — at the SCF file manager level

This was the big discovery: batching isn't missing, it's just not where you'd
expect. `level1/modules/scf.asm` (shared by every SCF driver, built into
Level 2 via `-aLevel=2` in `level2/defs/makefile:6`) special-cases CoWin
windows *before* ever calling down into `vtio.dr`/`cowin.io`:

- `get.wptr` (`scf.asm:1479-1507`) checks whether the target path's driver is
  VTIO and GRFDRV has a live entry point.
- `L0523`/`g.fast` (`scf.asm:1043-1083`) scans the caller's **own write
  buffer** for a run of consecutive printable characters (`cmpa #$20`,
  stops at the first control character), up to a 256-byte page boundary.
- If the run is 2+ characters, the whole run is copied to `$0180` and handed
  to GRFDRV's buffered alpha-put entry (`call.grf`, `scf.asm:1509-1539`; call
  code 6 = `fast.chr`, `grfdrv.asm:3499-3551`) in **one** Task-1 flip.
- If the run is ≤1 character (`scf.asm:1073-1074`), it falls through to the
  classic one-character-at-a-time path that reaches `cowin.asm`'s `Write` and
  pays the per-character flip described in §1.

Consequences worth remembering:

- **No new syscall or protocol is needed** for single-char vs. batched
  writes. It's decided per `I$Write()`/`I$WritLn()` call by how many
  printable characters happen to be in the buffer the caller passed —
  transparent to caller, file manager, and driver alike.
- **Interactive input (keyboard echo) is unaffected and shouldn't be
  "fixed."** A single echoed keystroke is a 1-byte write, which naturally
  takes the ≤1-character branch and keeps today's low-latency per-character
  path. That's correct behavior, not a gap.
- **`writln` shares the same fast path as `write`** (`scf.asm:958-960`, both
  fall into `L04E1`/`L04F1`/`L0523`), so `I$WritLn` callers (e.g. `dump.asm`)
  get it too.
- **Batch granularity is set by control-character positions in the data
  (effectively: line endings), not by the size of the buffer the caller
  passed to `I$Write()`.** A `CR` stops the scan. This matters directly for
  buffer-sizing decisions in callers — see §4.

## 3. Scrolling — already well-optimized, not much left

`grfdrv.asm:4439-4531` (`L124F`/`L127B`, entered from cursor-down `L123A`):
full-width windows do the whole window in a single `TFM x+,y+` (6309) or one
`StkBlCpy` call (6809) (`L1267a`, line 4471). Partial-width windows fall back
to one `TFM`/`StkBlCpy` per line — inherent to a strided 2D copy on this ISA,
not a missed optimization. `StkBlCpy` (`grfdrv.asm:2553-2580`) is already a
hand-tuned 46-cycles/8-bytes stack-blast copy with cycle counts documented
inline. Conclusion: leave this alone.

## 4. Per-command findings

### `level1/cmds/ls.asm`

- **Dominant cost is the sort, not I/O.** Insertion sort (`SoLoop`,
  `ls.asm:450-479`) is O(n²) comparisons, and each compared character in
  `NamCmp` (`ls.asm:483-502`) costs ~90 cycles (two `Fold` subroutine calls,
  two `exg a,b`, a stack push/compare). For a full 256-entry directory this
  dominates everything else combined. Two independent fixes: fold via a
  256-byte lookup table instead of a subroutine (~90 cyc &rarr; ~25 cyc/char),
  and binary-search the insertion point instead of a linear backward scan
  (O(n²) &rarr; O(n log n) comparisons).
- The unrolled 32-byte entry copy (`ls.asm:377-409`) could be eliminated by
  reading directory chunks directly into `pool` (which is already sized to
  hold the max sortable directory) instead of `dirbuf` + copy. Saves ~176
  cycles/entry; trade-off is dead/deleted entries then occupy pool slots
  unless compacted on encounter.
- **The 1KB output buffer (`OUTSZ`/`OUTMARG`, `ls.asm:52-53`) should not be
  shrunk**, and this is a direct consequence of §2: the grfdrv-flip cost is
  already minimized per *line* by `scf.asm`'s `g.fast` scan, independent of
  how large the outer `I$Write()` buffer is (a 1KB buffer holding ~15-20
  lines and a 256-byte buffer holding ~4-5 lines produce the *same* number of
  grfdrv flips per line of output — control characters bound the batch, not
  buffer size). Shrinking the buffer would only increase the number of
  `I$Write()` syscall traps (each with its own kernel-entry + SCF-dispatch
  overhead), for zero offsetting benefit. If anything this argues for keeping
  it large, not smaller.

### `level1/cmds/dump.asm`

Already correctly batched, no changes identified. Only two write call sites
in the whole file (`grep -n "I\$Write"` confirms): the help message
(`dump.asm:182`, one `I$Write` for the whole message) and `print`
(`dump.asm:352`), called once per *line* (not per character) from `enlin`
(`dump.asm:337-341`) and the header-printing code. Line content is built in
`Txtbuf` in memory (`onbyt`/`onibl`/`onchr`/`savec`) with no syscalls until
the line is complete. Combined with §2 (each line is one printable run ending
in `CR`), each `I$WritLn` call already collapses to one grfdrv flip at the OS
level regardless of `dump.asm`'s own code.

### `level2/cmds/grfdrv.asm` character-rendering hot path

Fixed-width 8x8 font path (`f1.next`/`Not8Wd`, `grfdrv.asm:3608-3618`) and the
color-plane blit routines (`Font.2`/`Font.4`/`Font.16`, `grfdrv.asm:3932-3996`)
are heavily hand-tuned already, with historical LCB/ATD comments documenting
cycle counts. Two concrete, still-open TODOs left by prior authors, not yet
implemented:

- `grfdrv.asm:3608-3610` — `f1.next`'s per-character `pshs x`/`puls x` around
  the buffer pointer could become `stx ,s`/`ldx ,s`, saving 4 cyc/char (6809)
  or 2 cyc/char (6309).
- `grfdrv.asm:3920-3924` — `Fast.pt`'s per-scanline transparency check
  (`tst`/`bpl`) inside the hot blit loop could be removed by doubling the
  vector table (opaque vs. transparent variants selected once per character
  instead of tested per scanline).

## 5. If picking up further work here

The one genuinely open, moderately-sized opportunity identified but not
pursued: `scf.asm`'s `g.fast` batch currently stops at every control
character, so a multi-line `I$Write()` buffer still costs one grfdrv flip per
line rather than one for the whole buffer. Extending the batch across line
endings would mean teaching `fast.chr`/`f2.next` (`grfdrv.asm:3499-3606`) to
also handle newline/scroll processing mid-batch, which they don't today (they
only handle right-edge wraps within the batch loop). Treat as its own
follow-up, not a quick change — it touches the buffered-write contract
between `scf.asm` and `grfdrv.asm`.
