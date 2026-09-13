
include port.mak

# Level 2 - Specify which shell should be used
#WHICHSHELL	= shellplus
#WHICHSHELL	= shell_21

DISTRO		= $(CPU)L$(LEVEL)
DISTRONAME	= NOS9_$(CPU)_L$(LEVEL)
DISTROVER	= $(DISTRONAME)_$(NITROS9VER)_$(PORT)
BOOTFILE_COCO3FPGA = bootfiles/bootfile_coco3fpga
BOOTFILE_COCO3FPGA_SD = bootfiles/bootfile_coco3fpga_sd
BOOTFILE_COCO3FPGA_SD_RTC = bootfiles/bootfile_coco3fpga_sd_rtc
BOOTFILE_COCO3FPGA_ROM = bootfiles/bootfile_coco3fpga_rom
BOOTFILE_COCO3FPGA_ROM_DW = bootfiles/bootfile_coco3fpga_rom_dw
BOOTFILE_COCO3FPGA_ROM_RTC = bootfiles/bootfile_coco3fpga_rom_rtc
KERNELFILE_BECKER	= bootfiles/kernel_becker
DIRS		= defs cmds modules sys bootfiles wwwroot

CMDS		:= $(shell $(CD) cmds; make --no-print-directory showobjs)
CMDS_D2		:= $(shell $(CD) cmds; make --no-print-directory showobjs_d2)
CMDS_DW		:= $(shell $(CD) cmds; make --no-print-directory showobjs_dw)
BOOTTRACK	:= $(shell $(CD) modules; make --no-print-directory showboottrack)
KERNEL		:= $(shell $(CD) modules; make --no-print-directory showkernel)
SYSMODS		:= $(shell $(CD) modules; make --no-print-directory showsysmods)
CLOCKS		:= $(shell $(CD) modules; make --no-print-directory showclocks)
RBF		:= $(shell $(CD) modules; make --no-print-directory showrbf)
SCF		:= $(shell $(CD) modules; make --no-print-directory showscf)
PIPE		:= $(shell $(CD) modules; make --no-print-directory showpipe)
MODULECMDS	= shell grfdrv del echo format makdir merge os9gen prompt tmode

DEFS		:= $(shell $(CD) defs; make --no-print-directory showobjs)
SYSBIN		:= $(shell $(CD) sys; make --no-print-directory showbinobjs)
SYSTEXT		:= $(shell $(CD) sys; make --no-print-directory showtextobjs)
SYSGOSYSTEXT		:= $(shell $(CD) sys; make --no-print-directory showsysgotextobjs)
STARTUP		= startup
STARTUP_DW	= startup.dw
STARTUP_FPGA	= startup.fpga
STARTUP_FPGADW	= startup.fpgadw
SYSGO		= sysgo_dd
SYSGOBD		= sysgo_bd
CCBKRN		= ccbkrn

DSKCOCO3FPGADW	= $(DISTROVER)_becker.dsk
DSKCOCO3FPGADWSD	= $(DISTROVER)_becker_sd.dsk
DSKCOCO3FPGADWSDRTC	= $(DISTROVER)_becker_sd_rtc.dsk
DSKCOCO3FPGAROM	= $(DISTROVER)_bootrom.img
DSKCOCO3FPGAROMDW	= $(DISTROVER)_bootrom_becker.img
DSKCOCO3FPGAROMRTC	= $(DISTROVER)_bootrom_rtc.img
LDSKCOCO3FPGADW	= $(DISTRONAME)_becker.dsk
LDSKCOCO3FPGADWSD	= $(DISTRONAME)_becker_sd.dsk
LDSKCOCO3FPGADWSDRTC	= $(DISTRONAME)_becker_sd_rtc.dsk
LDSKCOCO3FPGAROM	= $(DISTRONAME)_bootrom.img
LDSKCOCO3FPGAROMDW	= $(DISTRONAME)_bootrom_becker.img
LDSKCOCO3FPGAROMRTC	= $(DISTRONAME)_bootrom_rtc.img

TEMPLATES	= tpl_becker.dsk

DSKS		=  $(DSKCOCO3FPGADW) $(DSKCOCO3FPGADWSD) $(DSKCOCO3FPGADWSDRTC) \
		$(DSKCOCO3FPGAROM) $(DSKCOCO3FPGAROMDW) $(DSKCOCO3FPGAROMRTC)
LDSKS	=  $(LDSKCOCO3FPGADW) $(LDSKCOCO3FPGADWSD) $(LDSKCOCO3FPGADWSDRTC) \
		$(LDSKCOCO3FPGAROM) $(LDSKCOCO3FPGAROMDW) $(LDSKCOCO3FPGAROMRTC)

# Make all components
all:
	@$(ECHO) "************************************************************"
	@$(ECHO) "*"
	@$(ECHO) "*      NitrOS-9/$(CPU) Level $(LEVEL) $(MACHINE) ($(PORT))"
	@$(ECHO) "*"
	@$(ECHO) "************************************************************"
	$(MAKE) -C $(NITROS9DIR)/lib
	$(foreach dir,$(DIRS),$(MAKE) -C $(dir) &&) :

# Clean all components
clean: dskclean
	$(foreach dir,$(DIRS),$(MAKE) -C $(dir) clean &&) :

dskclean:
	$(RM) $(DSKS) $(LDSKS) $(TEMPLATES)

$(DSKS) $(TEMPLATES): | all
dsk: $(DSKS)

dskcopy: $(DSKS)
	$(CP) $(DSKS) $(DSKDIR)

tpl_becker.dsk:
	$(RM) $@
	$(OS9FORMAT_DW) -q $@ -n"NitrOS-9/$(CPU) Level $(LEVEL)"
	$(MAKDIR) $@,CMDS $@,SYS $@,DEFS $@,NITROS9 $@,NITROS9/CMDS $@,NITROS9/MODULES \
		$@,NITROS9/MODULES/BOOTTRACK $@,NITROS9/MODULES/KERNEL $@,NITROS9/MODULES/SYSMODS \
		$@,NITROS9/MODULES/CLOCKS $@,NITROS9/MODULES/RBF $@,NITROS9/MODULES/SCF \
		$@,NITROS9/MODULES/PIPE $@,NITROS9/BOOTLISTS $@,NITROS9/SCRIPTS
	$(OS9COPY) modules/$(SYSGOBD) $@,sysgo
	$(OS9ATTR_EXEC) $@,sysgo
	$(CD) cmds; $(OS9COPY) $(CMDS_DW) ../$@,CMDS
	$(OS9ATTR_EXEC) $(foreach file,$(CMDS_DW),$@,CMDS/$(file))
	$(CD) sys; $(OS9COPY) $(SYSBIN) ../$@,SYS
	$(OS9ATTR_TEXT) $(foreach file,$(SYSBIN),$@,SYS/$(file))
	$(CD) sys; $(CPL) $(SYSTEXT) ../$@,SYS
	$(OS9ATTR_TEXT) $(foreach file,$(notdir $(SYSTEXT)),$@,SYS/$(file))
	$(CD) sys; $(CPL) $(SYSGOSYSTEXT) ../$@,SYS
	$(OS9ATTR_TEXT) $(foreach file,$(notdir $(SYSGOSYSTEXT)),$@,SYS/$(file))
	$(CD) defs; $(CPL) $(DEFS) ../$@,DEFS
	$(OS9ATTR_TEXT) $(foreach file,$(DEFS),$@,DEFS/$(file))
	$(CD) cmds; $(OS9COPY) $(MODULECMDS) ../$@,NITROS9/CMDS
	$(OS9ATTR_EXEC) $(foreach file,$(MODULECMDS),$@,NITROS9/CMDS/$(file))
	$(CD) modules; $(OS9COPY) $(BOOTTRACK) ../$@,NITROS9/MODULES/BOOTTRACK
	$(OS9ATTR_EXEC) $(foreach file,$(BOOTTRACK),$@,NITROS9/MODULES/BOOTTRACK/$(file))
	$(CD) modules; $(OS9COPY) $(KERNEL) ../$@,NITROS9/MODULES/KERNEL
	$(OS9ATTR_EXEC) $(foreach file,$(KERNEL),$@,NITROS9/MODULES/KERNEL/$(file))
	$(CD) modules; $(OS9COPY) $(SYSMODS) ../$@,NITROS9/MODULES/SYSMODS
	$(OS9ATTR_EXEC) $(foreach file,$(SYSMODS),$@,NITROS9/MODULES/SYSMODS/$(file))
	$(CD) modules; $(OS9COPY) $(CLOCKS) ../$@,NITROS9/MODULES/CLOCKS
	$(OS9ATTR_EXEC) $(foreach file,$(CLOCKS),$@,NITROS9/MODULES/CLOCKS/$(file))
	$(CD) modules; $(OS9COPY) $(RBF) ../$@,NITROS9/MODULES/RBF
	$(OS9ATTR_EXEC) $(foreach file,$(RBF),$@,NITROS9/MODULES/RBF/$(file))
	$(CD) modules; $(OS9COPY) $(SCF) ../$@,NITROS9/MODULES/SCF
	$(OS9ATTR_EXEC) $(foreach file,$(SCF),$@,NITROS9/MODULES/SCF/$(file))
	$(CD) modules; $(OS9COPY) $(PIPE) ../$@,NITROS9/MODULES/PIPE
	$(OS9ATTR_EXEC) $(foreach file,$(PIPE),$@,NITROS9/MODULES/PIPE/$(file))
	$(CD) bootlists; $(CPL) *.bl ../$@,NITROS9/BOOTLISTS
	$(CD) scripts; $(CPL) mb* ../$@,NITROS9/SCRIPTS

$(DSKCOCO3FPGADW): tpl_becker.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COCO3FPGA) -t=$(KERNELFILE_BECKER)
	$(CPL) $(STARTUP_FPGADW) $@,startup
	$(OS9ATTR_TEXT) $@,startup
	$(RM) $(LDSKCOCO3FPGADW)
	$(SOFTLINK) $@ $(LDSKCOCO3FPGADW)

$(DSKCOCO3FPGADWSD): tpl_becker.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COCO3FPGA_SD) -t=$(KERNELFILE_BECKER)
	$(CPL) $(STARTUP_FPGADW) $@,startup
	$(OS9ATTR_TEXT) $@,startup
	$(RM) $(LDSKCOCO3FPGADWSD)
	$(SOFTLINK) $@ $(LDSKCOCO3FPGADWSD)

$(DSKCOCO3FPGADWSDRTC): tpl_becker.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COCO3FPGA_SD_RTC) -t=$(KERNELFILE_BECKER)
	$(CPL) $(STARTUP_FPGADW) $@,startup
	$(OS9ATTR_TEXT) $@,startup
	$(RM) $(LDSKCOCO3FPGADWSDRTC)
	$(SOFTLINK) $@ $(LDSKCOCO3FPGADWSDRTC)

$(DSKCOCO3FPGAROM): tpl_becker.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COCO3FPGA_ROM) -t=$(KERNELFILE_BECKER)
	$(OS9COPY) modules/$(CCBKRN) $@,$(CCBKRN)
	$(CPL) $(STARTUP_FPGA) $@,startup
	$(OS9ATTR_TEXT) $@,startup
	$(RM) $(LDSKCOCO3FPGAROM)
	$(SOFTLINK) $@ $(LDSKCOCO3FPGAROM)

$(DSKCOCO3FPGAROMDW): tpl_becker.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COCO3FPGA_ROM_DW) -t=$(KERNELFILE_BECKER)
	$(OS9COPY) modules/$(CCBKRN) $@,$(CCBKRN)
	$(CPL) $(STARTUP_FPGADW) $@,startup
	$(OS9ATTR_TEXT) $@,startup
	$(RM) $(LDSKCOCO3FPGAROMDW)
	$(SOFTLINK) $@ $(LDSKCOCO3FPGAROMDW)

$(DSKCOCO3FPGAROMRTC): tpl_becker.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COCO3FPGA_ROM_RTC) -t=$(KERNELFILE_BECKER)
	$(OS9COPY) modules/$(CCBKRN) $@,$(CCBKRN)
	$(CPL) $(STARTUP_FPGADW) $@,startup
	$(OS9ATTR_TEXT) $@,startup
	$(RM) $(LDSKCOCO3FPGAROMRTC)
	$(SOFTLINK) $@ $(LDSKCOCO3FPGAROMRTC)

info:
	@$(ECHO) "*** NitrOS-9/$(CPU) Level $(LEVEL) for the $(MACHINE) ***"
	@$(foreach dsk, $(DSKS), $(ECHO) $(dsk);)

