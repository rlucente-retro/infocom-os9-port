# Makefile for NitrOS-9 Infocom Port (Phase 1)

ASM = lwasm
OPTIONS = -DLevel=1 --pragma=cescapes,pcaspcr,nosymbolcase,condundefzero,undefextern,dollarnotlocal,noforwardrefmax

# Target binary name
TARGET = infocom

DEPS = os9_cocozip.asm os9_eq.asm os9_io.asm os9_disk.asm os9_paging.asm \
       os9_subs.asm os9_objects.asm os9_zstring.asm os9_read.asm os9_ops.asm \
       os9_screen.asm os9_main.asm os9_dispatch.asm

SRCDISKIMAGE = $(NITROS9DIR)/recipes/coco3/floppy/l2_coco3_minimal.dsk
DSKIMAGE = zork.dsk

all: $(DSKIMAGE)

$(TARGET): $(DEPS)
	$(ASM) -f os9 $(OPTIONS) --includedir=$(NITROS9DIR)/defs -o $@ os9_cocozip.asm

# Create a test disk image (requires imgtool and os9 tools)
$(DSKIMAGE): $(TARGET) $(SRCDISKIMAGE) zork1.dat raakatu.dat
	cp $(SRCDISKIMAGE) $(DSKIMAGE)
	os9 copy $(TARGET) $(DSKIMAGE),CMDS/$(TARGET)
	os9 attr -e -pe -q $(DSKIMAGE),CMDS/$(TARGET)
	os9 copy zork1.dat $(DSKIMAGE),zork1.dat
	os9 copy raakatu.dat $(DSKIMAGE),raakatu.dat

.PHONY: all clean

MAME_BINARY  ?= mame
MAME_MACHINE ?= coco3
MAME_FLAGS   ?= -rompath $(MAME_ROM_PATH) -window -skip_gameinfo -autoboot_delay 5 -autoboot_command "DOS\n" -ext fdc -ext:fdc:wd17xx:0 525qd

$(SRCDISKIMAGE):
	make -C $(NITROS9DIR)/recipes/coco3/floppy MINIMAL=1

run: $(DSKIMAGE)
	$(MAME_BINARY) $(MAME_MACHINE) $(MAME_FLAGS) -flop1 $(DSKIMAGE)

# Clean up build artifacts
clean:
	rm -f $(TARGET) *.dsk *.list *.map *.bak
