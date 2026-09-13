include $(NITROS9DIR)/rules.mak

# raakatu
dirs	= arcadepak basic09 bf cpm deskmate3 ccompiler flightsim2 koronis kyumgai mmission multivue os9l2bbs pacos9 rescueof rogue sierra subsim uucpbb

.PHONY: all clean dsk dskcopy dskclean info $(dirs)

all: $(dirs)

$(dirs):
	$(MAKE) -C $@

clean: $(addsuffix -clean,$(dirs))
%-clean:
	$(MAKE) -C $* clean

dsk: $(addsuffix -dsk,$(dirs))
%-dsk:
	$(MAKE) -C $* dsk

dskcopy: $(addsuffix -dskcopy,$(dirs))
%-dskcopy:
	$(MAKE) -C $* dskcopy

dskclean: $(addsuffix -dskclean,$(dirs))
%-dskclean:
	$(MAKE) -C $* dskclean

info:
	@$(foreach dir, $(dirs), $(MAKE) -C $(dir) info; $(ECHO);)
