include $(NITROS9DIR)/rules.mak

dirs	=  6809l2
 
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
	@$(foreach dir, $(dirs), $(MAKE) -C $(dir) info;)

