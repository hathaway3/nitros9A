
ifndef NITROS9DIR
NITROS9DIR = $(PWD)
endif

export NITROS9DIR
include rules.mak

dirs	=  $(NOSLIB) $(LEVEL1) $(LEVEL2) $(3RDPARTY) #$(LEVEL3)

# Allow the user to specify a selection of ports to build
ifdef PORTS
dirs = $(NOSLIB)
dirs += $(filter $(foreach p,$(PORTS),$(LEVEL1)/$(p) $(LEVEL2)/$(p)),$(wildcard $(LEVEL1)/* $(LEVEL2)/*))
endif

.PHONY: all clean dsk dskcopy dskclean info $(dirs)
.NOTPARALLEL: $(NOSLIB)

# Make all components
all: $(dirs)

$(dirs):
	$(MAKE) -C $@

# Dependency ordering: level1, level2, 3rdparty depend on lib (NOSLIB)
$(filter $(LEVEL1) $(LEVEL2) $(LEVEL1)/% $(LEVEL2)/%,$(dirs)): $(NOSLIB)
$(filter $(3RDPARTY) $(3RDPARTY)/%,$(dirs)): $(filter $(LEVEL2) $(LEVEL2)/coco3,$(dirs)) $(NOSLIB)

# Clean all components
clean: $(addsuffix -clean,$(dirs))
	$(RM) nitros9project.zip
	$(RM) $(DSKDIR)/*.dsk $(DSKDIR)/*.DSK $(DSKDIR)/*.img
	$(RM) $(DSKDIR)/ReadMe
	$(RM) $(DSKDIR)/index.html $(DSKDIR)/index.shtml
	$(RM) defs/buildinfo

%-clean:
	$(MAKE) -C $* clean

# Make DSK images
dsk: $(addsuffix -dsk,$(dirs))

%-dsk:
	$(MAKE) -C $* dsk

$(filter $(addsuffix -dsk,$(LEVEL1) $(LEVEL2) $(LEVEL1)/% $(LEVEL2)/%),$(addsuffix -dsk,$(dirs))): $(NOSLIB)
$(filter $(addsuffix -dsk,$(3RDPARTY) $(3RDPARTY)/%),$(addsuffix -dsk,$(dirs))): $(filter $(addsuffix -dsk,$(LEVEL2) $(LEVEL2)/coco3),$(addsuffix -dsk,$(dirs))) $(NOSLIB)

# Copy DSK images
$(DSKDIR):
	mkdir -p $@

dskcopy: $(DSKDIR) $(addsuffix -dskcopy,$(dirs))
	$(MKDSKINDEX) $(DSKDIR) > $(DSKDIR)/index.html

$(addsuffix -dskcopy,$(dirs)): | $(DSKDIR)

%-dskcopy:
	$(MAKE) -C $* dskcopy

# Clean DSK images
dskclean: $(addsuffix -dskclean,$(dirs))

%-dskclean:
	$(MAKE) -C $* dskclean

info:
	@$(foreach dir,$(dirs), $(MAKE) --no-print-directory -C $(dir) info &&) :

# This section is to do the nightly build and upload 
# to sourceforge.net you must set the environment
# variable SOURCEUSER to the userid you have for sourceforge.net
# The "burst" script is found in the scripts folder and must
# on your ssh account at sourceforge.net
ifdef	SOURCEUSER
nightly: clean dskcopy
	$(MAKE) info > $(DSKDIR)/ReadMe
	$(ARCHIVE) nitros9project $(DSKDIR)/*
	scp nitros9project.zip $(SOURCEUSER),nitros9@web.sourceforge.net:/home/project-web/nitros9/htdocs/nitros9project-$(shell date +%Y%m%d).zip 
	ssh $(SOURCEUSER),nitros9@shell.sourceforge.net create
	ssh $(SOURCEUSER),nitros9@shell.sourceforge.net "./burst nitros9project $(shell date +%Y%m%d)"
else
nightly:
	@$(ECHO) ""
	@$(ECHO) ""
	@$(ECHO) "You need to set the SOURCEUSER variable"
	@$(ECHO) "You may wish to refer to the nightly"
	@$(ECHO) "section of the makefile."
endif
