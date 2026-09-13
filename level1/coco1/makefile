include port.mak

# Level 1 - Specify which shell should be used
#WHICHSHELL	= shellplus
WHICHSHELL	= shell_21

DISTRO		= $(CPU)L$(LEVEL)
DISTRONAME	= NOS9_$(CPU)_L$(LEVEL)
DISTROVER	= $(DISTRONAME)_$(NITROS9VER)_$(PORT)
BOOTFILE_COVDG	= bootfiles/bootfile_covdg
BOOTFILE_COVGA	= bootfiles/bootfile_covga
BOOTFILE_COHR	= bootfiles/bootfile_cohr
BOOTFILE_CO42	= bootfiles/bootfile_co42
BOOTFILE_COWPRS	    = bootfiles/bootfile_cowprs
BOOTFILE_COVDG_DS80	= bootfiles/bootfile_covdg_ds80
BOOTFILE_COVGA_DS80	= bootfiles/bootfile_covga_ds80
BOOTFILE_DW_HEADLESS	= bootfiles/bootfile_dw_headless
BOOTFILE_BECKER_HEADLESS	= bootfiles/bootfile_becker_headless
BOOTFILE_COCOLINK_HEADLESS	= bootfiles/bootfile_cocolink_headless
BOOTFILE_RS232PAK_HEADLESS	= bootfiles/bootfile_rs232pak_headless
BOOTFILE_DIRECTMODEMPAK_HEADLESS	= bootfiles/bootfile_directmodempak_headless
BOOTFILE_MMMPIU1_HEADLESS	= bootfiles/bootfile_mmmpiu1_headless
BOOTFILE_MMMPIU2_HEADLESS	= bootfiles/bootfile_mmmpiu2_headless
BOOTFILE_ARDUINO_HEADLESS	= bootfiles/bootfile_arduino_headless
BOOTFILE_COVDG_DW	= bootfiles/bootfile_covdg_dw
BOOTFILE_COVGA_DW	= bootfiles/bootfile_covga_dw
BOOTFILE_COVDG_BECKER	= bootfiles/bootfile_covdg_becker
BOOTFILE_COVGA_BECKER	= bootfiles/bootfile_covga_becker
BOOTFILE_COVDG_COCOLINK	= bootfiles/bootfile_covdg_cocolink
BOOTFILE_COVGA_COCOLINK	= bootfiles/bootfile_covga_cocolink
BOOTFILE_COVDG_RS232PAK	= bootfiles/bootfile_covdg_rs232pak
BOOTFILE_COVGA_RS232PAK	= bootfiles/bootfile_covga_rs232pak
BOOTFILE_COVDG_DIRECTMODEMPAK	= bootfiles/bootfile_covdg_directmodempak
BOOTFILE_COVGA_DIRECTMODEMPAK	= bootfiles/bootfile_covga_directmodempak
BOOTFILE_COVDG_MMMPIU1	= bootfiles/bootfile_covdg_mmmpiu1
BOOTFILE_COVGA_MMMPIU1	= bootfiles/bootfile_covga_mmmpiu1
BOOTFILE_COVDG_MMMPIU2	= bootfiles/bootfile_covdg_mmmpiu2
BOOTFILE_COVGA_MMMPIU2	= bootfiles/bootfile_covga_mmmpiu2
BOOTFILE_COVDG_ARDUINO	= bootfiles/bootfile_covdg_arduino
BOOTFILE_COVGA_ARDUINO	= bootfiles/bootfile_covga_arduino
BOOTFILE_COVDG_COCOSDC	= bootfiles/bootfile_covdg_cocosdc
BOOTFILE_COVGA_COCOSDC	= bootfiles/bootfile_covga_cocosdc
BOOTFILE_COHR_DS80	= bootfiles/bootfile_cohr_ds80
BOOTFILE_CO42_DS80	= bootfiles/bootfile_co42_ds80
BOOTFILE_COHR_DW	= bootfiles/bootfile_cohr_dw
BOOTFILE_CO42_DW	= bootfiles/bootfile_co42_dw
BOOTFILE_COHR_BECKER	= bootfiles/bootfile_cohr_becker
BOOTFILE_COHR_COCOLINK	= bootfiles/bootfile_cohr_cocolink
BOOTFILE_COHR_RS232PAK	= bootfiles/bootfile_cohr_rs232pak
BOOTFILE_COHR_DIRECTMODEMPAK	= bootfiles/bootfile_cohr_directmodempak
BOOTFILE_COHR_ARDUINO	= bootfiles/bootfile_cohr_arduino
KERNELFILE	= bootfiles/kernel_1773
KERNELFILE_DW	= bootfiles/kernel_dw
KERNELFILE_BECKER	= bootfiles/kernel_becker
KERNELFILE_COCOLINK	= bootfiles/kernel_cocolink
KERNELFILE_RS232PAK	= bootfiles/kernel_rs232pak
KERNELFILE_DIRECTMODEMPAK	= bootfiles/kernel_directmodempak
KERNELFILE_MMMPIU1	= bootfiles/kernel_mmmpiu1
KERNELFILE_MMMPIU2	= bootfiles/kernel_mmmpiu2
KERNELFILE_ARDUINO	= bootfiles/kernel_arduino
KERNELFILE_COCOSDC	= bootfiles/kernel_cocosdc
DIRS		= cmds modules defs sys bootfiles bootroms wwwroot


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
MODULECMDS	= $(WHICHSHELL) del echo format makdir merge os9gen prompt tmode

SYSTEXT		:= $(shell $(CD) sys; make --no-print-directory showtextfiles)
SYSBIN		:= $(shell $(CD) sys; make --no-print-directory showbinfiles)
WWWROOT		:= $(shell $(CD) wwwroot; make --no-print-directory showobjs)
DEFS		:= $(shell $(CD) defs; make --no-print-directory showobjs)
STARTUP		= startup
STARTUP_DW	= startup.dw

DSKDW           = $(DISTROVER)_dw.dsk
LDSKDW          = $(DISTRONAME)_$(PORT)_dw.dsk
DSKVGADW        = $(DISTROVER)_vga_dw.dsk
LDSKVGADW       = $(DISTRONAME)_$(PORT)_vga_dw.dsk
DSKDWHEADLESS   = $(DISTROVER)_dw_headless.dsk
LDSKDWHEADLESS  = $(DISTRONAME)_$(PORT)_dw_headless.dsk
DSK360K_1       = $(DISTROVER)_40d_1.dsk
LDSK360K_1      = $(DISTRONAME)_$(PORT)_40d_1.dsk
DSKVGA360K_1    = $(DISTROVER)_vga_40d_1.dsk
LDSKVGA360K_1   = $(DISTRONAME)_$(PORT)_vga_40d_1.dsk
DSK360K_2       = $(DISTROVER)_40d_2.dsk
LDSK360K_2      = $(DISTRONAME)_$(PORT)_40d_2.dsk
DSK720K         = $(DISTROVER)_80d.dsk
LDSK720K        = $(DISTRONAME)_$(PORT)_80d.dsk
DSKVGA720K      = $(DISTROVER)_vga_80d.dsk
LDSKVGA720K     = $(DISTRONAME)_$(PORT)_vga_80d.dsk
DSKBECKER       = $(DISTROVER)_becker.dsk
LDSKBECKER      = $(DISTRONAME)_$(PORT)_becker.dsk
DSKVGABECKER    = $(DISTROVER)_vga_becker.dsk
LDSKVGABECKER   = $(DISTRONAME)_$(PORT)_vga_becker.dsk
DSKCOCOLINK     = $(DISTROVER)_dw_cocolink.dsk
LDSKCOCOLINK    = $(DISTRONAME)_$(PORT)_dw_cocolink.dsk
DSKVGACOCOLINK  = $(DISTROVER)_vga_dw_cocolink.dsk
LDSKVGACOCOLINK = $(DISTRONAME)_$(PORT)_vga_dw_cocolink.dsk
DSKRS232PAK     = $(DISTROVER)_dw_rs232pak.dsk
LDSKRS232PAK    = $(DISTRONAME)_$(PORT)_dw_rs232pak.dsk
DSKVGARS232PAK         = $(DISTROVER)_vga_dw_rs232pak.dsk
LDSKVGARS232PAK        = $(DISTRONAME)_$(PORT)_vga_dw_rs232pak.dsk
DSKDIRECTMODEMPAK      = $(DISTROVER)_dw_directmodempak.dsk
LDSKDIRECTMODEMPAK     = $(DISTRONAME)_$(PORT)_dw_directmodempak.dsk
DSKVGADIRECTMODEMPAK   = $(DISTROVER)_vga_dw_directmodempak.dsk
LDSKVGADIRECTMODEMPAK  = $(DISTRONAME)_$(PORT)_vga_dw_directmodempak.dsk
DSKMMMPIU1      = $(DISTROVER)_dw_mmmpiu1.dsk
LDSKMMMPIU1     = $(DISTRONAME)_$(PORT)_dw_mmmpiu1.dsk
DSKVGAMMMPIU1   = $(DISTROVER)_vga_dw_mmmpiu1.dsk
LDSKVGAMMMPIU1  = $(DISTRONAME)_$(PORT)_vga_dw_mmmpiu1.dsk
DSKMMMPIU2      = $(DISTROVER)_dw_mmmpiu2.dsk
LDSKMMMPIU2     = $(DISTRONAME)_$(PORT)_dw_mmmpiu2.dsk
DSKVGAMMMPIU2   = $(DISTROVER)_vga_dw_mmmpiu2.dsk
LDSKVGAMMMPIU2  = $(DISTRONAME)_$(PORT)_vga_dw_mmmpiu2.dsk
DSKBECKERHEADLESS   = $(DISTROVER)_becker_headless.dsk
LDSKBECKERHEADLESS  = $(DISTRONAME)_$(PORT)_becker_headless.dsk
DSKRS232PAKHEADLESS = $(DISTROVER)_dw_rs232pak_headless.dsk
LDSKRS232PAKHEADLESS	= $(DISTRONAME)_$(PORT)_dw_rs232pak_headless.dsk
DSKDIRECTMODEMPAKHEADLESS	= $(DISTROVER)_dw_directmodempak_headless.dsk
LDSKDIRECTMODEMPAKHEADLESS	= $(DISTRONAME)_$(PORT)_dw_directmodempak_headless.dsk
DSKMMMPIU1HEADLESS	= $(DISTROVER)_dw_mmmpiu1_headless.dsk
LDSKMMMPIU1HEADLESS	= $(DISTRONAME)_$(PORT)_dw_mmmpiu1_headless.dsk
DSKMMMPIU2HEADLESS	= $(DISTROVER)_dw_mmmpiu2_headless.dsk
LDSKMMMPIU2HEADLESS	= $(DISTRONAME)_$(PORT)_dw_mmmpiu2_headless.dsk
DSKARDUINO	= $(DISTROVER)_arduino.dsk
LDSKARDUINO	= $(DISTRONAME)_$(PORT)_arduino.dsk
DSKVGAARDUINO	= $(DISTROVER)_vga_arduino.dsk
LDSKVGAARDUINO	= $(DISTRONAME)_$(PORT)_vga_arduino.dsk
DSKARDUINOHEADLESS	= $(DISTROVER)_arduino_headless.dsk
LDSKARDUINOHEADLESS	= $(DISTRONAME)_$(PORT)_arduino_headless.dsk
DSKCOCOSDC	= $(DISTROVER)_cocosdc.dsk
LDSKCOCOSDC	= $(DISTRONAME)_$(PORT)_cocosdc.dsk
DSKVGACOCOSDC	= $(DISTROVER)_vga_cocosdc.dsk
LDSKVGACOCOSDC	= $(DISTRONAME)_$(PORT)_vga_cocosdc.dsk

DSKS		= $(DSKDW) $(DSKDWHEADLESS) $(DSKBECKER) $(DSKBECKERHEADLESS) \
		$(DSKARDUINO) $(DSKARDUINOHEADLESS) $(DSK360K_1) $(DSK360K_2) \
		$(DSK720K) $(DSKCOCOSDC) $(DSKRS232PAK) $(DSKDIRECTMODEMPAK) \
		$(DSKRS232PAKHEADLESS) $(DSKDIRECTMODEMPAKHEADLESS) \
		$(DSKCOCOLINK) $(DSKVGA360K_1) $(DSKVGA720K) $(DSKVGACOCOLINK) \
		$(DSKVGARS232PAK) $(DSKVGADIRECTMODEMPAK) $(DSKVGAARDUINO) \
		$(DSKVGACOCOSDC) $(DSKVGADW) \
		$(DSKMMMPIU1) $(DSKVGAMMMPIU1) $(DSKMMMPIU1HEADLESS) \
		$(DSKMMMPIU2) $(DSKVGAMMMPIU2) $(DSKMMMPIU2HEADLESS)
LDSKS		= $(LDSKDW) $(LDSKDWHEADLESS) $(LDSKBECKER) $(LDSKBECKERHEADLESS) \
		$(LDSKARDUINO) $(LDSKARDUINOHEADLESS) $(LDSK360K_1) $(LDSK360K_2) \
		$(LDSK720K) $(LDSKCOCOSDC) $(LDSKRS232PAK) $(LDSKDIRECTMODEMPAK) \
		$(LDSKRS232PAKHEADLESS) $(LDSKDIRECTMODEMPAKHEADLESS) \
		$(LDSKCOCOLINK) $(LDSKVGA360K_1) $(LDSKVGA720K) $(LDSKVGACOCOLINK) \
		$(LDSKVGARS232PAK) $(LDSKVGADIRECTMODEMPAK) $(LDSKVGAARDUINO) \
		$(LDSKVGACOCOSDC) $(LDSKVGADW) \
		$(LDSKMMMPIU1) $(LDSKVGAMMMPIU1) $(LDSKMMMPIU1HEADLESS) \
		$(LDSKMMMPIU2) $(LDSKVGAMMMPIU2) $(LDSKMMMPIU2HEADLESS)

# Make all components
all:
	@$(ECHO) "************************************************************"
	@$(ECHO) "*"
	@$(ECHO) "*      NitrOS-9/$(CPU) Level $(LEVEL) $(MACHINE) ($(PORT))"
	@$(ECHO) "*"
	@$(ECHO) "************************************************************"
	$(foreach dir,$(DIRS),$(MAKE) -C $(dir) &&) :

# Clean all components
clean:	dskclean
	$(foreach dir,$(DIRS),$(MAKE) -C $(dir) clean &&) :

dskclean:
	$(RM) $(DSKS) $(LDSKS) tpl_*.dsk

TEMPLATES	= tpl_dw.dsk tpl_40d_1.dsk tpl_80d.dsk
$(DSKS) $(TEMPLATES): | all
dsk: $(DSKS)

dskcopy: $(DSKS)
	$(CP) $(DSKS) $(DSKDIR)

tpl_dw.dsk:
	$(RM) $@
	$(OS9FORMAT_DW) -q $@ -n"NitrOS-9/$(CPU) Level $(LEVEL)"
	$(MAKDIR) $@,CMDS $@,SYS $@,DEFS $@,WWWROOT 		$@,NITROS9 $@,NITROS9/$(DISTRO) $@,NITROS9/$(DISTRO)/CMDS 		$@,NITROS9/$(DISTRO)/MODULES $@,NITROS9/$(DISTRO)/MODULES/BOOTTRACK 		$@,NITROS9/$(DISTRO)/MODULES/KERNEL $@,NITROS9/$(DISTRO)/MODULES/SYSMODS 		$@,NITROS9/$(DISTRO)/MODULES/CLOCKS $@,NITROS9/$(DISTRO)/MODULES/RBF 		$@,NITROS9/$(DISTRO)/MODULES/SCF $@,NITROS9/$(DISTRO)/MODULES/PIPE 		$@,NITROS9/$(DISTRO)/BOOTLISTS $@,NITROS9/$(DISTRO)/SCRIPTS
	$(CD) cmds; $(OS9COPY) $(sort $(CMDS_DW) $(CMDS_D2)) ../$@,CMDS
	$(OS9ATTR_EXEC) $(foreach file,$(sort $(CMDS_DW) $(CMDS_D2)),$@,CMDS/$(file))
	$(OS9RENAME) $@,CMDS/$(WHICHSHELL) shell
	$(CD) sys; $(CPL) $(SYSTEXT) ../$@,SYS
	$(OS9ATTR_TEXT) $(foreach file,$(SYSTEXT),$@,SYS/$(file))
	$(CD) sys; $(OS9COPY) $(SYSBIN) ../$@,SYS
	$(CD) wwwroot; $(OS9COPY) $(WWWROOT) ../$@,WWWROOT
	$(OS9ATTR_TEXT) $(foreach file,$(WWWROOT),$@,WWWROOT/$(file))
	$(CD) defs; $(CPL) $(DEFS) ../$@,DEFS
	$(OS9ATTR_TEXT) $(foreach file,$(DEFS),$@,DEFS/$(file))
	$(CPL) $(STARTUP_DW) $@,startup
	$(OS9ATTR_TEXT) $@,startup
	$(CD) cmds; $(OS9COPY) $(MODULECMDS) ../$@,NITROS9/$(DISTRO)/CMDS
	$(OS9ATTR_EXEC) $(foreach file,$(MODULECMDS),$@,NITROS9/$(DISTRO)/CMDS/$(file))
	$(OS9RENAME) $@,NITROS9/$(DISTRO)/CMDS/$(WHICHSHELL) shell
	$(CD) modules; $(OS9COPY) $(BOOTTRACK) ../$@,NITROS9/$(DISTRO)/MODULES/BOOTTRACK
	$(OS9ATTR_EXEC) $(foreach file,$(BOOTTRACK),$@,NITROS9/$(DISTRO)/MODULES/BOOTTRACK/$(file))
	$(CD) modules; $(OS9COPY) $(KERNEL) ../$@,NITROS9/$(DISTRO)/MODULES/KERNEL
	$(OS9ATTR_EXEC) $(foreach file,$(KERNEL),$@,NITROS9/$(DISTRO)/MODULES/KERNEL/$(file))
	$(CD) modules; $(OS9COPY) $(SYSMODS) ../$@,NITROS9/$(DISTRO)/MODULES/SYSMODS
	$(OS9ATTR_EXEC) $(foreach file,$(SYSMODS),$@,NITROS9/$(DISTRO)/MODULES/SYSMODS/$(file))
	$(CD) modules; $(OS9COPY) $(CLOCKS) ../$@,NITROS9/$(DISTRO)/MODULES/CLOCKS
	$(OS9ATTR_EXEC) $(foreach file,$(CLOCKS),$@,NITROS9/$(DISTRO)/MODULES/CLOCKS/$(file))
	$(CD) modules; $(OS9COPY) $(RBF) ../$@,NITROS9/$(DISTRO)/MODULES/RBF
	$(OS9ATTR_EXEC) $(foreach file,$(RBF),$@,NITROS9/$(DISTRO)/MODULES/RBF/$(file))
	$(CD) modules; $(OS9COPY) $(SCF) ../$@,NITROS9/$(DISTRO)/MODULES/SCF
	$(OS9ATTR_EXEC) $(foreach file,$(SCF),$@,NITROS9/$(DISTRO)/MODULES/SCF/$(file))
	$(CD) modules; $(OS9COPY) $(PIPE) ../$@,NITROS9/$(DISTRO)/MODULES/PIPE
	$(OS9ATTR_EXEC) $(foreach file,$(PIPE),$@,NITROS9/$(DISTRO)/MODULES/PIPE/$(file))
	$(CD) bootlists; $(CPL) *.bl ../$@,NITROS9/$(DISTRO)/BOOTLISTS
	$(CD) scripts; $(CPL) mb* ../$@,NITROS9/$(DISTRO)/SCRIPTS

$(DSKDW): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COVDG_DW) -t=$(KERNELFILE_DW)
	$(RM) $(LDSKDW)
	$(SOFTLINK) $@ $(LDSKDW)

$(DSKVGADW): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COVGA_DW) -t=$(KERNELFILE_DW)
	$(RM) $(LDSKVGADW)
	$(SOFTLINK) $@ $(LDSKVGADW)

$(DSKBECKER): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COVDG_BECKER) -t=$(KERNELFILE_BECKER)
	$(RM) $(LDSKBECKER)
	$(SOFTLINK) $@ $(LDSKBECKER)

$(DSKCOCOLINK): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COVDG_COCOLINK) -t=$(KERNELFILE_COCOLINK)
	$(RM) $(LDSKCOCOLINK)
	$(SOFTLINK) $@ $(LDSKCOCOLINK)

$(DSKVGACOCOLINK): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COVGA_COCOLINK) -t=$(KERNELFILE_COCOLINK)
	$(RM) $(LDSKVGACOCOLINK)
	$(SOFTLINK) $@ $(LDSKVGACOCOLINK)

$(DSKRS232PAK): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COVDG_RS232PAK) -t=$(KERNELFILE_RS232PAK)
	$(RM) $(LDSKRS232PAK)
	$(SOFTLINK) $@ $(LDSKRS232PAK)

$(DSKVGARS232PAK): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COVGA_RS232PAK) -t=$(KERNELFILE_RS232PAK)
	$(RM) $(LDSKVGARS232PAK)
	$(SOFTLINK) $@ $(LDSKVGARS232PAK)

$(DSKDIRECTMODEMPAK): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COVDG_DIRECTMODEMPAK) -t=$(KERNELFILE_DIRECTMODEMPAK)
	$(RM) $(LDSKDIRECTMODEMPAK)
	$(SOFTLINK) $@ $(LDSKDIRECTMODEMPAK)

$(DSKVGADIRECTMODEMPAK): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COVGA_DIRECTMODEMPAK) -t=$(KERNELFILE_DIRECTMODEMPAK)
	$(RM) $(LDSKVGADIRECTMODEMPAK)
	$(SOFTLINK) $@ $(LDSKVGADIRECTMODEMPAK)

$(DSKMMMPIU1): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COVDG_MMMPIU1) -t=$(KERNELFILE_MMMPIU1)
	$(RM) $(LDSKMMMPIU1)
	$(SOFTLINK) $@ $(LDSKMMMPIU1)

$(DSKVGAMMMPIU1): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COVGA_MMMPIU1) -t=$(KERNELFILE_MMMPIU1)
	$(RM) $(LDSKVGAMMMPIU1)
	$(SOFTLINK) $@ $(LDSKVGAMMMPIU1)

$(DSKMMMPIU2): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COVDG_MMMPIU2) -t=$(KERNELFILE_MMMPIU2)
	$(RM) $(LDSKMMMPIU2)
	$(SOFTLINK) $@ $(LDSKMMMPIU2)

$(DSKVGAMMMPIU2): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COVGA_MMMPIU2) -t=$(KERNELFILE_MMMPIU2)
	$(RM) $(LDSKVGAMMMPIU2)
	$(SOFTLINK) $@ $(LDSKVGAMMMPIU2)

$(DSKARDUINO): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COVDG_ARDUINO) -t=$(KERNELFILE_ARDUINO)
	$(RM) $(LDSKARDUINO)
	$(SOFTLINK) $@ $(LDSKARDUINO)

$(DSKVGAARDUINO): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COVGA_ARDUINO) -t=$(KERNELFILE_ARDUINO)
	$(RM) $(LDSKVGAARDUINO)
	$(SOFTLINK) $@ $(LDSKVGAARDUINO)

$(DSKCOCOSDC): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COVDG_COCOSDC) -t=$(KERNELFILE_COCOSDC)
	$(RM) $(LDSKCOCOSDC)
	$(SOFTLINK) $@ $(LDSKCOCOSDC)

$(DSKVGACOCOSDC): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COVGA_COCOSDC) -t=$(KERNELFILE_COCOSDC)
	$(RM) $(LDSKVGACOCOSDC)
	$(SOFTLINK) $@ $(LDSKVGACOCOSDC)

$(DSKDWHEADLESS): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_DW_HEADLESS) -t=$(KERNELFILE_DW)
	$(RM) $(LDSKDWHEADLESS)
	$(SOFTLINK) $@ $(LDSKDWHEADLESS)

$(DSKBECKERHEADLESS): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_BECKER_HEADLESS) -t=$(KERNELFILE_BECKER)
	$(RM) $(LDSKBECKERHEADLESS)
	$(SOFTLINK) $@ $(LDSKBECKERHEADLESS)

$(DSKRS232PAKHEADLESS): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_RS232PAK_HEADLESS) -t=$(KERNELFILE_RS232PAK)
	$(RM) $(LDSKRS232PAKHEADLESS)
	$(SOFTLINK) $@ $(LDSKRS232PAKHEADLESS)

$(DSKDIRECTMODEMPAKHEADLESS): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_DIRECTMODEMPAK_HEADLESS) -t=$(KERNELFILE_DIRECTMODEMPAK)
	$(RM) $(LDSKDIRECTMODEMPAKHEADLESS)
	$(SOFTLINK) $@ $(LDSKDIRECTMODEMPAKHEADLESS)

$(DSKMMMPIU1HEADLESS): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_MMMPIU1_HEADLESS) -t=$(KERNELFILE_MMMPIU1)
	$(RM) $(LDSKMMMPIU1HEADLESS)
	$(SOFTLINK) $@ $(LDSKMMMPIU1HEADLESS)

$(DSKMMMPIU2HEADLESS): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_MMMPIU2_HEADLESS) -t=$(KERNELFILE_MMMPIU2)
	$(RM) $(LDSKMMMPIU2HEADLESS)
	$(SOFTLINK) $@ $(LDSKMMMPIU2HEADLESS)

$(DSKARDUINOHEADLESS): tpl_dw.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_ARDUINO_HEADLESS) -t=$(KERNELFILE_ARDUINO)
	$(RM) $(LDSKARDUINOHEADLESS)
	$(SOFTLINK) $@ $(LDSKARDUINOHEADLESS)

tpl_40d_1.dsk:
	$(RM) $@
	$(OS9FORMAT_DS40) -q $@ -n"NitrOS-9/$(CPU) Level $(LEVEL) Disk 1"
	$(MAKDIR) $@,CMDS $@,SYS $@,DEFS
	$(CD) cmds; $(OS9COPY) $(CMDS) ../$@,CMDS
	$(OS9ATTR_EXEC) $(foreach file,$(CMDS),$@,CMDS/$(file))
	$(OS9RENAME) $@,CMDS/$(WHICHSHELL) shell
	$(CD) sys; $(CPL) $(SYSTEXT) ../$@,SYS
	$(OS9ATTR_TEXT) $(foreach file,$(SYSTEXT),$@,SYS/$(file))
	$(CD) sys; $(OS9COPY) $(SYSBIN) ../$@,SYS
	$(CD) defs; $(CPL) $(DEFS) ../$@,DEFS
	$(OS9ATTR_TEXT) $(foreach file,$(DEFS),$@,DEFS/$(file))
	$(CPL) $(STARTUP) $@,startup
	$(OS9ATTR_TEXT) $@,startup

$(DSK360K_1): tpl_40d_1.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COVDG) -t=$(KERNELFILE)
	$(RM) $(LDSK360K_1)
	$(SOFTLINK) $@ $(LDSK360K_1)

$(DSKVGA360K_1): tpl_40d_1.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COVGA) -t=$(KERNELFILE)
	$(RM) $(LDSKVGA360K_1)
	$(SOFTLINK) $@ $(LDSKVGA360K_1)

$(DSK360K_2):
	$(RM) $@
	$(OS9FORMAT_DS40) -q $@ -n"NitrOS-9/$(CPU) Level $(LEVEL) Disk 2"
	$(MAKDIR) $@,CMDS $@,NITROS9 $@,NITROS9/$(DISTRO) $@,NITROS9/$(DISTRO)/CMDS 		$@,NITROS9/$(DISTRO)/MODULES $@,NITROS9/$(DISTRO)/MODULES/BOOTTRACK 		$@,NITROS9/$(DISTRO)/MODULES/KERNEL $@,NITROS9/$(DISTRO)/MODULES/SYSMODS 		$@,NITROS9/$(DISTRO)/MODULES/CLOCKS $@,NITROS9/$(DISTRO)/MODULES/RBF 		$@,NITROS9/$(DISTRO)/MODULES/SCF $@,NITROS9/$(DISTRO)/MODULES/PIPE 		$@,NITROS9/$(DISTRO)/BOOTLISTS $@,NITROS9/$(DISTRO)/SCRIPTS
	$(CD) cmds; $(OS9COPY) $(CMDS_D2) ../$@,CMDS
	$(OS9ATTR_EXEC) $(foreach file,$(CMDS_D2),$@,CMDS/$(file))
	$(CD) cmds; $(OS9COPY) $(MODULECMDS) ../$@,NITROS9/$(DISTRO)/CMDS
	$(OS9ATTR_EXEC) $(foreach file,$(MODULECMDS),$@,NITROS9/$(DISTRO)/CMDS/$(file))
	$(OS9RENAME) $@,NITROS9/$(DISTRO)/CMDS//$(WHICHSHELL) shell
	$(CD) modules; $(OS9COPY) $(BOOTTRACK) ../$@,NITROS9/$(DISTRO)/MODULES/BOOTTRACK
	$(OS9ATTR_EXEC) $(foreach file,$(BOOTTRACK),$@,NITROS9/$(DISTRO)/MODULES/BOOTTRACK/$(file))
	$(CD) modules; $(OS9COPY) $(KERNEL) ../$@,NITROS9/$(DISTRO)/MODULES/KERNEL
	$(OS9ATTR_EXEC) $(foreach file,$(KERNEL),$@,NITROS9/$(DISTRO)/MODULES/KERNEL/$(file))
	$(CD) modules; $(OS9COPY) $(SYSMODS) ../$@,NITROS9/$(DISTRO)/MODULES/SYSMODS
	$(OS9ATTR_EXEC) $(foreach file,$(SYSMODS),$@,NITROS9/$(DISTRO)/MODULES/SYSMODS/$(file))
	$(CD) modules; $(OS9COPY) $(CLOCKS) ../$@,NITROS9/$(DISTRO)/MODULES/CLOCKS
	$(OS9ATTR_EXEC) $(foreach file,$(CLOCKS),$@,NITROS9/$(DISTRO)/MODULES/CLOCKS/$(file))
	$(CD) modules; $(OS9COPY) $(RBF) ../$@,NITROS9/$(DISTRO)/MODULES/RBF
	$(OS9ATTR_EXEC) $(foreach file,$(RBF),$@,NITROS9/$(DISTRO)/MODULES/RBF/$(file))
	$(CD) modules; $(OS9COPY) $(SCF) ../$@,NITROS9/$(DISTRO)/MODULES/SCF
	$(OS9ATTR_EXEC) $(foreach file,$(SCF),$@,NITROS9/$(DISTRO)/MODULES/SCF/$(file))
	$(CD) modules; $(OS9COPY) $(PIPE) ../$@,NITROS9/$(DISTRO)/MODULES/PIPE
	$(OS9ATTR_EXEC) $(foreach file,$(PIPE),$@,NITROS9/$(DISTRO)/MODULES/PIPE/$(file))
	$(CD) bootlists; $(CPL) *.bl ../$@,NITROS9/$(DISTRO)/BOOTLISTS
	$(CD) scripts; $(CPL) mb* ../$@,NITROS9/$(DISTRO)/SCRIPTS
	$(RM) $(LDSK360K_2)
	$(SOFTLINK) $@ $(LDSK360K_2)

tpl_80d.dsk:
	$(RM) $@
	$(OS9FORMAT_DS80) -q $@ -n"NitrOS-9/$(CPU) Level $(LEVEL)"
	$(MAKDIR) $@,CMDS $@,SYS $@,DEFS $@,NITROS9 $@,NITROS9/$(DISTRO) 		$@,NITROS9/$(DISTRO)/CMDS $@,NITROS9/$(DISTRO)/MODULES 		$@,NITROS9/$(DISTRO)/MODULES/BOOTTRACK $@,NITROS9/$(DISTRO)/MODULES/KERNEL 		$@,NITROS9/$(DISTRO)/MODULES/SYSMODS $@,NITROS9/$(DISTRO)/MODULES/CLOCKS 		$@,NITROS9/$(DISTRO)/MODULES/RBF $@,NITROS9/$(DISTRO)/MODULES/SCF 		$@,NITROS9/$(DISTRO)/MODULES/PIPE $@,NITROS9/$(DISTRO)/BOOTLISTS $@,NITROS9/$(DISTRO)/SCRIPTS
	$(CD) cmds; $(OS9COPY) $(sort $(CMDS) $(CMDS_D2)) ../$@,CMDS
	$(OS9ATTR_EXEC) $(foreach file,$(sort $(CMDS) $(CMDS_D2)),$@,CMDS/$(file))
	$(OS9RENAME) $@,CMDS/$(WHICHSHELL) shell
	$(CD) sys; $(CPL) $(SYSTEXT) ../$@,SYS
	$(OS9ATTR_TEXT) $(foreach file,$(SYSTEXT),$@,SYS/$(file))
	$(CD) sys; $(OS9COPY) $(SYSBIN) ../$@,SYS
	$(CD) defs; $(CPL) $(DEFS) ../$@,DEFS
	$(OS9ATTR_TEXT) $(foreach file,$(DEFS),$@,DEFS/$(file))
	$(CPL) $(STARTUP) $@,startup
	$(OS9ATTR_TEXT) $@,startup
	$(CD) cmds; $(OS9COPY) $(MODULECMDS) ../$@,NITROS9/$(DISTRO)/CMDS
	$(OS9ATTR_EXEC) $(foreach file,$(MODULECMDS),$@,NITROS9/$(DISTRO)/CMDS/$(file))
	$(OS9RENAME) $@,NITROS9/$(DISTRO)/CMDS/$(WHICHSHELL) shell
	$(CD) modules; $(OS9COPY) $(BOOTTRACK) ../$@,NITROS9/$(DISTRO)/MODULES/BOOTTRACK
	$(OS9ATTR_EXEC) $(foreach file,$(BOOTTRACK),$@,NITROS9/$(DISTRO)/MODULES/BOOTTRACK/$(file))
	$(CD) modules; $(OS9COPY) $(KERNEL) ../$@,NITROS9/$(DISTRO)/MODULES/KERNEL
	$(OS9ATTR_EXEC) $(foreach file,$(KERNEL),$@,NITROS9/$(DISTRO)/MODULES/KERNEL/$(file))
	$(CD) modules; $(OS9COPY) $(SYSMODS) ../$@,NITROS9/$(DISTRO)/MODULES/SYSMODS
	$(OS9ATTR_EXEC) $(foreach file,$(SYSMODS),$@,NITROS9/$(DISTRO)/MODULES/SYSMODS/$(file))
	$(CD) modules; $(OS9COPY) $(CLOCKS) ../$@,NITROS9/$(DISTRO)/MODULES/CLOCKS
	$(OS9ATTR_EXEC) $(foreach file,$(CLOCKS),$@,NITROS9/$(DISTRO)/MODULES/CLOCKS/$(file))
	$(CD) modules; $(OS9COPY) $(RBF) ../$@,NITROS9/$(DISTRO)/MODULES/RBF
	$(OS9ATTR_EXEC) $(foreach file,$(RBF),$@,NITROS9/$(DISTRO)/MODULES/RBF/$(file))
	$(CD) modules; $(OS9COPY) $(SCF) ../$@,NITROS9/$(DISTRO)/MODULES/SCF
	$(OS9ATTR_EXEC) $(foreach file,$(SCF),$@,NITROS9/$(DISTRO)/MODULES/SCF/$(file))
	$(CD) modules; $(OS9COPY) $(PIPE) ../$@,NITROS9/$(DISTRO)/MODULES/PIPE
	$(OS9ATTR_EXEC) $(foreach file,$(PIPE),$@,NITROS9/$(DISTRO)/MODULES/PIPE/$(file))
	$(CD) bootlists; $(CPL) *.bl ../$@,NITROS9/$(DISTRO)/BOOTLISTS
	$(CD) scripts; $(CPL) mb* ../$@,NITROS9/$(DISTRO)/SCRIPTS

$(DSK720K): tpl_80d.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COVDG_DS80) -t=$(KERNELFILE)
	$(RM) $(LDSK720K)
	$(SOFTLINK) $@ $(LDSK720K)

$(DSKVGA720K): tpl_80d.dsk
	$(CP) $< $@
	$(OS9GEN) $@ -b=$(BOOTFILE_COVGA_DS80) -t=$(KERNELFILE)
	$(RM) $(LDSKVGA720K)
	$(SOFTLINK) $@ $(LDSKVGA720K)


info:
	@$(ECHO) "*** NitrOS-9/$(CPU) Level $(LEVEL) for the $(MACHINE) ***"
	@$(foreach dsk, $(DSKS), $(ECHO) $(dsk);)

