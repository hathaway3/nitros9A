# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

NitrOS-9 is a community distribution of the OS-9 operating system for the Motorola 6809 (and Hitachi 6309) CPUs, targeting retro systems like the TRS-80 Color Computer, Dragon, Atari w/ Liber809, Corsham SS-50, and Wildbits boards. The codebase is almost entirely 6809/6309 assembly, organized as OS-9 modules (kernel, drivers, device descriptors, file managers, commands).

## Build

Requires [lwtools](http://lwtools.projects.l-w.ca) (`lwasm`/`lwlink`, the 6809 cross-assembler/linker) and [ToolShed](https://github.com/n6il/toolshed) (provides the `os9` CLI for disk image manipulation) on `PATH`.

```sh
export NITROS9DIR=$HOME/nitros9   # defaults to $PWD if unset
make                # build everything: lib, level1, level2, 3rdparty
make dsk            # also build .dsk disk images
make dskcopy         # copy .dsk images into $NITROS9DIR/dsks with an index.html
make clean           # remove build outputs
make dskclean        # remove only disk images
make info            # print build info per component
```

Build a subset of ports (saves a lot of time — the full build compiles every supported machine):

```sh
make PORTS="coco1 coco3"
```

Each level/port has its own `makefile` and can be built directly:

```sh
make -C level1/coco1
make -C level1/coco1/cmds        # just the commands for that port
make -C level2/coco3 dsk
```

Assembled outputs (modules, commands, drivers) have no file extension and are gitignored implicitly by not being tracked — a working tree after `make` will show large numbers of untracked build artifacts under `cmds/`, `bootfiles/`, `modules/`, etc. This is expected; only `*.dsk`, `*.list`, `*.map`, `*.o`, `.mods/`, `.obj/`, `.lib/` are in `.gitignore`.

There is no separate lint/test-suite command in the traditional sense; correctness is verified by assembling cleanly and by the tools in `tests/` (see below).

## Testing changes

- **`tests/sim6809/sim6809.py`** — a host-side 6809 interpreter that runs an assembled OS-9 command module with OS-9 service calls stubbed out, to catch logic bugs (wild pointers, bad loop bounds, wrong addressing modes) before putting a command on a disk image or real hardware.
  ```sh
  python3 tests/sim6809/sim6809.py level1/coco1/cmds/ls
  python3 tests/sim6809/sim6809.py level1/coco1/cmds/ls --params=-l
  python3 tests/sim6809/sim6809.py level2/coco3/cmds/shellplus --stdin "dir CMDS"
  ```
  6309-only paths (`TFM`, the W register, etc.) and interrupt/cycle-accurate behavior are out of scope for this simulator — a clean run checks logic, not timing, and doesn't replace testing on an emulator or real hardware. Build the command first (`make -C <port>/cmds`), then run it here in each mode it supports (default, options, `--pipe`, narrow `--width`) before copying it to a disk image.
- **`tests/pr_reviewer/`** — fixture `.asm` files (`case_pass.asm`, `case_fail_*.asm`) used to validate the automated Gemini-based PR reviewer configured in `.github/workflows/gemini-pr-review.yml` / `.github/scripts/analyze_pr.py`. Not something you run locally as a test suite; it's the acceptance set for that CI reviewer.

## Architecture

### Directory layout

- `lib/` — shared, port-independent code built into static archives (`.a` files via `lwar`) that command/module makefiles link against: `libalib.a` (common subroutines), `libcoco.a`/`libcoco3.a`/`libatari.a`/etc. (per-machine support code), `libnos9<cpu><level>.a` (kernel-level shared code), `libnet.a`.
- `level1/`, `level2/`, `level3/` — the three OS-9 "levels" (roughly: Level 1 = non-banked 64K memory model, Level 2 = banked/MMU memory model with more drivers, Level 3 = experimental). Each contains one subdirectory per hardware **port** (`coco1`, `coco2`, `coco3`, `coco3_6309`, `dragon`-family (`d64`/`dalpha`/`tano`), `atari`, `corsham`, `wildbits`, `mc09`, etc.) plus a shared `cmds/`, `modules/`, `defs/` at the level root.
- Inside a port directory: `cmds/` (user commands, e.g. `ls`, `dir`, `copy`), `modules/` (kernel, drivers, device descriptors, file managers), `sys/` (startup scripts, system config), `bootfiles/`, `bootlists/`, `bootroms/`, `defs/` (port-specific `.d` include files), `port.mak` (per-port make variables consumed by `rules.mak` and the port's `makefile`).
- `defs/` — shared OS-9/RBF/SCF/hardware definition files (`.d`) included by assembly source across all ports via `--includedir`.
- `3rdparty/` — community-contributed drivers, boot loaders, file managers, packages, and work-in-progress code not part of the core distribution.
- `recipes/` — alternate/custom build recipes for specific configurations (e.g. `recipes/coco3_6309`, `recipes/wildbits`).
- `scripts/` — build/dev tooling: `asmprettyprint.py`/`format_code.sh` (source formatting), `pre-commit` (git hook that auto-formats staged `.asm`/`.as`/`.d` files), `mkdskindex`, boot list generators, `os9.gdb`.
- `docs/` — deep-dive research notes on cross-file subsystems that aren't obvious from reading any single source file. Check here before re-deriving architecture that spans multiple modules/levels. Currently: `grfdrv-write-pipeline.md` (CoWin/GRFDRV character-write and scroll performance: the SCF-level write batching in `scf.asm`, the GIME MMU task-flip mechanics in `ccbkrn.asm`, and per-command findings for `ls.asm`/`dump.asm`).

### Build system

- `rules.mak` (included by every `makefile`) defines all tool invocations (`AS`, `ASM`, `LINKER`, `LWAR`, `OS9FORMAT*`, etc.), directory variables (`LEVEL1`, `LEVEL2`, `NOSLIB`, `DSKDIR`, ...), and the suffix rules mapping source extensions to OS-9 module types: `.mn` (file manager), `.dr` (device driver), `.dd` (device descriptor), `.sb` (subroutine module), `.dw`/`.dt` (window/terminal descriptors), `.io` (I/O subroutines), extensionless (general command/module).
- The top-level `makefile` fans out to `lib`, `level1`, `level2`, `3rdparty` (each has its own `makefile` that fans out further to individual ports). `PORTS=` filters which port subdirectories get built at any level.
- The 6809 cross-assembler is invoked as `lwasm --6309 --format=os9 --pragma=... --includedir=$(DEFSDIR)`; `--format=raw`/`--format=decb`/`--format=obj` variants exist for ROM images, DECB binaries, and relocatable object files (for C-compiled code via the `c3` compiler / `lwlink`).
- `NITROS9DIR` is the one environment variable that matters for a build; everything else derives from it via `rules.mak`.

### Assembly source conventions

These are enforced by the pre-commit hook (`scripts/pre-commit` + `scripts/asmprettyprint.py`) and documented in `README.md`'s Contributing section — install the hook via `cp scripts/pre-commit .git/hooks/`:

- Spaces only, no tabs.
- Exactly one space between opcode and operand, and between operand and comment.
- A comment on (almost) every instruction line, written in lowercase without punctuation, explaining *why*/*purpose* rather than restating the mnemonic (e.g. `clra set the path to standard input`, not `clra clear A`).
- Avoid abbreviations in comments — spell words out.
- Every source file ends with a trailing blank line.
- Commit messages: short imperative subject line (≤50 chars), blank line, then a wrapped-at-72 body explaining *why* when the change isn't self-explanatory. Keep unrelated changes (e.g. reformatting vs. optimization) in separate commits, even within the same file.

### Repository-specific assembly rules (`.ai_assembly_rules.md` / `.clauderules` / `.cursorrules`, identical content)

These govern 6809/6309 data-movement (buffer copy) code specifically and are also what the automated Gemini PR reviewer (`.github/workflows/gemini-pr-review.yml`) checks for:

1. On 6309 targets, use `TFM x+,y+` / `TFM x-,y-` instead of software copy loops.
2. On 6809, for buffers ≤16 bytes, use unrolled fixed 5-bit-offset `LDD n,Y`/`STD n,X` instead of auto-increment addressing.
3. Any "stack blast" routine that manipulates `S` directly must bracket the block with `ORCC #$50` / `ANDCC #$AF`.
4. When source and destination overlap with source < destination, copy backward (`,--X` / negative offsets) to avoid clobbering unread source data.

### Skills in this repo

`.claude/skills/annotate-asm` (also mirrored under `.agents/skills` for other tools) is a project skill for annotating disassembled 6809/6309 source: renaming generic disassembler labels (`L0047`, `u0100`) to meaningful names and adding an inline comment to every instruction, with binary-identical verification (assemble before/after and diff, or compare `os9 ident` output) at each checkpoint. Invoke with `/6809-annotate <path/to/file.asm>`.
