LEVEL = 2
DSK_EXTRA_DEPS = $(MODDIR)/sysgo_dd
DSK_POST_COPY = $(MAKE) copy-sysgo-root DSKIMAGE=$@
BASIC09_CMDS = basic09 runb gfx2 gfx inkey syscall
BASIC09_SAMPLES ?= $(filter-out %/unittest,$(wildcard $(3RDPARTY)/packages/basic09/samples/*))
CMDS_EXTRA += $(BASIC09_CMDS) ls memstress

THIS_MAKEFILE := $(lastword $(MAKEFILE_LIST))

MAME ?= 0
ifeq ($(MAME),1)
STARTUP = startup.mame
endif

# SERIAL_T1=1 (default) ADDS a 6850 ACIA serial terminal, /T1, alongside the
# normal console: sc6850.dr in the driver group, the T1 descriptor in the
# descriptor group, and (via STARTUP below) a `shell i=/t1&` line at the end
# of the startup script. The Term descriptor and the vtio/GrfDrv windowed
# console are untouched -- /T1 is purely additional. HwBASE=$FF68 is where
# RPI-Nine emulates the ACIA (include/config.h's ACIA_BASE). Ignored when
# MINIMAL=1, which already makes the 6850 the one and only console.
SERIAL_T1 ?= 1

# STARTUP must be set BEFORE include ../coco3.mak: that file's rule for the
# disk image expands $(STARTUP) into its prerequisite list at parse time.
# (MAME=1 keeps its own startup.mame; MINIMAL=1 has no /T1 to start.)
ifeq ($(SERIAL_T1),1)
ifneq ($(MAME),1)
ifneq ($(MINIMAL),1)
STARTUP = startup.t1
endif
endif
endif

# MINIMAL=1 swaps the CoCo3 windowed video console (vtio.dr/cowin.io/
# term_win80.dt + the sixteen w*.dw window descriptors, which pull in
# GrfDrv) for an RS-232-Pak-style 6850 ACIA console (sc6850.dr/
# term_sc6850.dt) at $FF68, matching RPI-Nine's emulated hardware (see
# ../../../CLAUDE.md in the RPI-Nine repo). RPI-Nine's GIME video
# emulation is a register bank only -- no framebuffer render, no vsync,
# no video interrupts -- so GrfDrv/CoWin were never going to work here
# regardless of source-level bugs, and RPI-Nine has no use for them at
# all. Mirrors nitros9_repo/recipes/coco3/floppy/recipe.mak's MINIMAL=1
# mode (see that project's BACKLOG.md, "Follow-up 2", for the full trace
# that led here). Named MINIMAL to match that recipe's convention, even
# though this variant only trims the console -- CMDS/PIPE/RBF are left
# at this recipe's own full defaults.
MINIMAL ?= 0
ifeq ($(MINIMAL),1)
SCF = scf.mn sc6850.dr term_sc6850.dt
# BOOTMODS layering follows docs/OS9Boot order.md's required sequence
# (checked by scripts/validate_disk_image.py in the RPI-Nine repo):
# Kernel -> Init -> IOMan -> File Managers -> Device Drivers -> Device
# Descriptors -> Clock -> Initial Task. This recipe's own default
# BOOTMODS (below, MINIMAL=0) concatenates RBF/SCF/PIPE whole -- each
# bundles a manager + driver + descriptor(s) together, so with MINIMAL's
# leaner SCF the layers no longer line up; pull them apart and regroup
# by layer here instead, mirroring nitros9_repo/recipes/coco3/floppy/
# recipe.mak's own MINIMAL=1 BOOTFILE_MANAGERS/DRIVERS/DESCS split.
BOOTFILE_MANAGERS = rbf.mn scf.mn pipeman.mn
BOOTFILE_DRIVERS  = rb1773.dr sc6850.dr piper.dr
BOOTFILE_DESCS    = ddd0_40d.dd d0_40d.dd d1_40d.dd d2_40d.dd term_sc6850.dt pipe.dd
BOOTMODS = krnp2 init ioman \
	$(BOOTFILE_MANAGERS) \
	$(BOOTFILE_DRIVERS) \
	$(BOOTFILE_DESCS) \
	$(CLOCK) \
	$(BOOTMODS_EXTRA)
else
# Same docs/OS9Boot order.md #1 layer requirement as MINIMAL=1 above
# (Kernel -> Init -> IOMan -> FileMgrs -> Drivers -> Descriptors ->
# SysGo), and the same reason it needs pulling apart here: concatenating
# $(RBF)/$(SCF)/$(PIPE) whole (coco3.mak) interleaves each bundle's own
# manager+driver+descriptor(s), so RBF's descriptors land before SCF's
# own manager, out of order. Regroup by layer instead -- exact same
# modules $(RBF)/$(SCF)/$(PIPE) provide (coco3.mak), just reordered;
# not editing coco3.mak itself since sierra/dw/other recipes share those
# variables. scripts/validate_disk_image.py's own layer classifier
# (OS9Boot order.md #1) only tracks named Init/IOMan/KrnP2/SysGo plus
# each module's real type/language byte (filemgr/driver/descriptor) --
# snddrv_cc3.sb/joydrv_joy.sb/clock_60hz/clock2_soft aren't any of those,
# so their exact position among the drivers/after the descriptors is a
# functional choice (grouped with the other real drivers below), not
# something the layer check itself constrains.
BOOTFILE_MANAGERS = rbf.mn scf.mn pipeman.mn
BOOTFILE_DRIVERS  = rb1773.dr vtio.dr $(TERM_IO) snddrv_cc3.sb joydrv_joy.sb piper.dr
BOOTFILE_DESCS    = ddd0_40d.dd d0_40d.dd d1_40d.dd d2_40d.dd \
	$(TERM_WIN_DT) w.dw w1.dw w2.dw w3.dw w4.dw w5.dw w6.dw w7.dw \
	w8.dw w9.dw w10.dw w11.dw w12.dw w13.dw w14.dw w15.dw pipe.dd
ifeq ($(SERIAL_T1),1)
BOOTFILE_DRIVERS += sc6850.dr
BOOTFILE_DESCS   += t1_sc6850.dt
endif
BOOTMODS = krnp2 init ioman \
	$(BOOTFILE_MANAGERS) \
	$(BOOTFILE_DRIVERS) \
	$(BOOTFILE_DESCS) \
	$(CLOCK) \
	$(BOOTMODS_EXTRA)
endif

include ../coco3.mak

# /T1: the stock term_sc6850.asm, built with TNum=1 so the descriptor is
# named T1 (not Term) and at the ACIA's address. Same source the MINIMAL=1
# console descriptor uses, so its IT.* options (echo, auto-LF, 80x25, XON/
# XOFF, 9600 8N1 -- baud is cosmetic here) are the tested ones.
ifeq ($(SERIAL_T1),1)
vpath %.asm $(NITROS9DIR)/level1/modules
$(MODDIR)/t1_sc6850.dt: term_sc6850.asm | $(MODDIR)
	$(AS) $(AFLAGS) $< $(ASOUT)$@ -DHwBASE=0xFF68 -DTNum=1

# Startup: the stock script unchanged, plus one line that starts a shell on
# /T1. Generated (like startup.mame below) rather than editing
# level2/coco3/startup, which every other recipe shares. The line goes right
# after `load utilpak1` and BEFORE `setime </1`: setime waits for a keypress
# on the windowed console, and a headless user on /T1 (no browser, no GIME
# keyboard) could never get past it. If the stock script ever loses its
# `load utilpak1` line the shell line is appended at the end instead.
startup.t1: $(NITROS9DIR)/level2/$(PORT)/startup $(THIS_MAKEFILE)
	awk 'BEGIN{d=0} {print} /^load utilpak1/ && !d {print "shell i=/t1&"; d=1} END{if(!d) print "shell i=/t1&"}' $< >$@
endif

ifeq ($(MINIMAL),1)
vpath %.asm $(NITROS9DIR)/level1/modules
$(MODDIR)/term_sc6850.dt: term_sc6850.asm | $(MODDIR)
	$(AS) $(AFLAGS) $< $(ASOUT)$@ -DHwBASE=0xFF68
endif

MAME_BINARY  ?= mame
MAME_MACHINE ?= coco3
MAME_FLAGS   ?= -window -nothrottle -skip_gameinfo -autoboot_delay 5 -autoboot_command "DOS\n" -ext fdc -ext:fdc:wd17xx:0 525qd

run: $(DSKIMAGE)
	$(MAME_BINARY) $(MAME_MACHINE) $(MAME_FLAGS) -flop1 $(DSKIMAGE)

copy-sysgo-root:
	$(OS9COPY) $(MODDIR)/sysgo_dd $(DSKIMAGE),sysgo
	$(OS9ATTR_EXEC) $(DSKIMAGE),sysgo

.PHONY: copy-sysgo-root run

ifeq ($(MAME),1)
startup.mame: $(NITROS9DIR)/level2/$(PORT)/startup
	{ echo "keyrpt 0 0</1"; cat $<; } >$@
endif

$(MODDIR)/basic09: basic09.asm | $(MODDIR)
	$(AS) $(AFLAGS) $< $(ASOUT)$@

$(MODDIR)/runb: runb.asm | $(MODDIR)
	$(AS) $(AFLAGS) $< $(ASOUT)$@
