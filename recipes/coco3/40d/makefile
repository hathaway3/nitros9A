LEVEL = 2
BOOTMODS = krnp2 ioman init \
	$(RBF) \
	$(SCF) \
	$(PIPE) \
	$(CLOCK) \
	$(BOOTMODS_EXTRA)
DSK_EXTRA_DEPS = $(MODDIR)/sysgo_dd
DSK_POST_COPY = $(MAKE) copy-sysgo-root DSKIMAGE=$@
BASIC09_CMDS = basic09 runb gfx2 gfx inkey syscall
BASIC09_SAMPLES ?= $(wildcard $(3RDPARTY)/packages/basic09/samples/*)
CMDS_EXTRA += $(BASIC09_CMDS)

MAME ?= 0
ifeq ($(MAME),1)
STARTUP = startup.mame
endif

# ACIA=1 swaps the CoCo3 windowed video console (vtio.dr/cowin.io/
# term_win80.dt + the sixteen w*.dw window descriptors, which pull in
# GrfDrv) for an RS-232-Pak-style 6850 ACIA console (sc6850.dr/
# term_sc6850.dt) at $FF68, matching RPI-Nine's emulated hardware (see
# ../../../CLAUDE.md in the RPI-Nine repo). RPI-Nine's GIME video
# emulation is a register bank only -- no framebuffer render, no vsync,
# no video interrupts -- so GrfDrv/CoWin were never going to work here
# regardless of source-level bugs, and RPI-Nine has no use for them at
# all. Mirrors nitros9_repo/recipes/coco3/floppy/recipe.mak's MINIMAL=1
# mode (see that project's BACKLOG.md, "Follow-up 2", for the full trace
# that led here).
ACIA ?= 0
ifeq ($(ACIA),1)
SCF = scf.mn sc6850.dr term_sc6850.dt
endif

include ../coco3.mak

ifeq ($(ACIA),1)
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
