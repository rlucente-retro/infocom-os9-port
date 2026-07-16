# Makefile for NitrOS-9 Infocom Port (Phase 1)

ASM = lwasm
OPTIONS = -DLevel=1 --pragma=cescapes,pcaspcr,nosymbolcase,condundefzero,undefextern,dollarnotlocal,noforwardrefmax

# Target binary name
TARGET = infocom

DEPS = os9_cocozip.asm os9_eq.asm os9_io.asm os9_disk.asm os9_paging.asm \
       os9_subs.asm os9_objects.asm os9_zstring.asm os9_read.asm os9_ops.asm \
       os9_screen.asm os9_main.asm os9_dispatch.asm

# MAME machine to target (coco3 or coco2b)
MAME_MACHINE ?= coco3

# Story file to include on the disk image (e.g., ziptest.z3, ZORK1.DAT)
STORY = ziptest.z3
LOWER_STORY = $(shell echo $(STORY) | tr 'A-Z' 'a-z')

ifeq ($(MAME_MACHINE),coco2b)
SRCDISKIMAGE = $(NITROS9DIR)/recipes/coco/floppy/l1_coco_minimal.dsk
SRCDISKDIR = $(NITROS9DIR)/recipes/coco/floppy
else
SRCDISKIMAGE = $(NITROS9DIR)/recipes/coco3/floppy/l2_coco3_minimal.dsk
SRCDISKDIR = $(NITROS9DIR)/recipes/coco3/floppy
endif

DSKIMAGE = $(basename $(LOWER_STORY)).dsk

all: $(DSKIMAGE)

$(TARGET): $(DEPS)
	$(ASM) -f os9 $(OPTIONS) --includedir=$(NITROS9DIR)/defs -o $@ os9_cocozip.asm

# Create a test disk image (requires imgtool and os9 tools)
$(DSKIMAGE): $(TARGET) $(SRCDISKIMAGE)
	cp $(SRCDISKIMAGE) $(DSKIMAGE)
	os9 copy $(TARGET) $(DSKIMAGE),CMDS/$(TARGET)
	os9 attr -e -pe -q $(DSKIMAGE),CMDS/$(TARGET)
	os9 copy $(STORY) $(DSKIMAGE),$(notdir $(LOWER_STORY))

.PHONY: all clean

MAME_BINARY  ?= mame
MAME_FLAGS   ?= -rompath $(MAME_ROM_PATH) -window -skip_gameinfo -autoboot_delay 5 -autoboot_command "DOS\n" -ext fdc -ext:fdc:wd17xx:0 525qd

$(SRCDISKIMAGE):
	make -C $(SRCDISKDIR) MINIMAL=1

run: $(DSKIMAGE)
	$(MAME_BINARY) $(MAME_MACHINE) $(MAME_FLAGS) -flop1 $(DSKIMAGE)

# Clean up build artifacts
clean:
	rm -f $(TARGET) *.dsk *.list *.map *.bak
