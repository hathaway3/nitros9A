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

# STARTUP must be set BEFORE include ../coco3_6309.mak: that file's rule for the
# disk image expands $(STARTUP) into its prerequisite list at parse time.
ifeq ($(SERIAL_T1),1)
ifneq ($(MAME),1)
ifneq ($(MINIMAL),1)
STARTUP = startup.t1
endif
endif
endif

MINIMAL ?= 0
ifeq ($(MINIMAL),1)
SCF = scf.mn sc6850.dr term_sc6850.dt
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
# BOOTMODS layering follows docs/OS9Boot order.md's required sequence:
# Kernel -> Init -> IOMan -> File Managers -> Device Drivers -> Device
# Descriptors -> Clock -> Initial Task.
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

include ../coco3_6309.mak

ifeq ($(SERIAL_T1),1)
vpath %.asm $(NITROS9DIR)/level1/modules
$(MODDIR)/t1_sc6850.dt: term_sc6850.asm | $(MODDIR)
	$(AS) $(AFLAGS) $< $(ASOUT)$@ -DHwBASE=0xFF68 -DTNum=1

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
