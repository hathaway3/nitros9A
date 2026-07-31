LEVEL = 2
DSK_EXTRA_DEPS = $(MODDIR)/sysgo_dd
DSK_POST_COPY = $(MAKE) copy-sysgo-root DSKIMAGE=$@
BASIC09_CMDS = basic09 runb gfx2 gfx inkey syscall
BASIC09_SAMPLES ?= $(wildcard $(3RDPARTY)/packages/basic09/samples/*)
CMDS_EXTRA += $(BASIC09_CMDS) ls

MAME ?= 0
ifeq ($(MAME),1)
STARTUP = startup.mame
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
BOOTMODS = krnp2 ioman init \
	$(RBF) \
	$(SCF) \
	$(PIPE) \
	$(CLOCK) \
	$(BOOTMODS_EXTRA)
endif

include ../coco3.mak

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
