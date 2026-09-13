include $(NITROS9DIR)/rules.mak

dirs	= coco3 coco3_6309 coco3fpga wildbits realcocofpga #mc09l2
ifdef PORTS
dirs	= $(PORTS)
endif

.PHONY: all clean dsk dskcopy dskclean info $(dirs)

# Make all components
all: $(dirs)

$(dirs):
	$(MAKE) -C $@

# Clean all components
clean: $(addsuffix -clean,$(dirs))
%-clean:
	$(MAKE) -C $* clean

# Make DSK images
dsk: $(addsuffix -dsk,$(dirs))
%-dsk:
	$(MAKE) -C $* dsk

# Copy DSK images
dskcopy: $(addsuffix -dskcopy,$(dirs))
%-dskcopy:
	$(MAKE) -C $* dskcopy

# Clean DSK images
dskclean: $(addsuffix -dskclean,$(dirs))
%-dskclean:
	$(MAKE) -C $* dskclean

# Info
info:
	@$(foreach dir,$(dirs),$(MAKE) -C $(dir) info; $(ECHO);)
