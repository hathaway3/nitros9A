include ../rules.mak

dirs	= booters drivers fmgrs p2mods subrtns utils packages

.PHONY: all clean dsk dskcopy dskclean info $(dirs)

# Make all components
all: $(dirs)

$(dirs):
	$(MAKE) -C $@

# Clean all components
clean: $(addsuffix -clean,$(dirs))
%-clean:
	$(MAKE) -C $* clean

dskdirs = drivers utils packages

# Make DSK images
dsk: $(addsuffix -dsk,$(dskdirs))
%-dsk:
	$(MAKE) -C $* dsk

# Clean DSK images
dskclean: $(addsuffix -dskclean,$(dskdirs))
%-dskclean:
	$(MAKE) -C $* dskclean

# Copy DSK images
dskcopy: $(addsuffix -dskcopy,$(dskdirs))
%-dskcopy:
	$(MAKE) -C $* dskcopy

# Info
info:
	@$(foreach dir, $(dirs), $(MAKE) -C $(dir) info;)
