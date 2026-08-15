# Makefile for NitrOS-9 Infocom Port

ASM = lwasm
OPTIONS = -DLevel=1 --pragma=cescapes,pcaspcr,nosymbolcase,condundefzero,undefextern,dollarnotlocal,noforwardrefmax

# Target binary name
TARGET = infocom

DEPS = os9_cocozip.asm os9_eq.asm os9_io.asm os9_disk.asm os9_paging.asm \
       os9_subs.asm os9_objects.asm os9_zstring.asm os9_read.asm os9_ops.asm \
       os9_screen.asm os9_main.asm os9_dispatch.asm

# MAME machine to target (coco3 or coco2b)
MAME_MACHINE ?= coco3

# Story file to include on the single-story floppy disk image (e.g., ziptest.z3, games/zork1.z3)
STORY ?= ziptest.z3
LOWER_STORY = $(shell echo $(STORY) | tr 'A-Z' 'a-z')

# Floppy base disk images (for single-story disk & MAME run)
ifeq ($(filter $(MAME_MACHINE),coco2b coco coco1 coco2),$(MAME_MACHINE))
SRCDISKIMAGE = $(NITROS9DIR)/recipes/coco/floppy/l1_coco_minimal.dsk
SRCDISKDIR = $(NITROS9DIR)/recipes/coco/floppy
else
SRCDISKIMAGE = $(NITROS9DIR)/recipes/coco3/floppy/l2_coco3_minimal.dsk
SRCDISKDIR = $(NITROS9DIR)/recipes/coco3/floppy
endif

DSKIMAGE ?= $(basename $(notdir $(LOWER_STORY))).dsk

# DriveWire base disk recipes (for FujiNet / multi-game disks)
COCO_DW_SRCDISKDIR = $(NITROS9DIR)/recipes/coco/dw
COCO_DW_SRCDISKIMAGE = $(COCO_DW_SRCDISKDIR)/l1_coco_dw.dsk

COCO3_DW_SRCDISKDIR = $(NITROS9DIR)/recipes/coco3/dw
COCO3_DW_SRCDISKIMAGE = $(COCO3_DW_SRCDISKDIR)/l2_coco3_dw.dsk

# Wildbits base disk recipes (Level 2 jr2 or k2)
PLATFORM ?= jr2
WILDBITS_SRCDISKDIR = $(NITROS9DIR)/recipes/wildbits/l2
WILDBITS_DSK = infocom_wildbits_$(PLATFORM).dsk

# CSV file containing URLs and destination filenames for multi-game disks
CSVFILE ?= masterpiece.csv
GAMES_DIR ?= games

# Extract list of game files from CSV (skipping comment and empty lines)
GAME_FILES = $(shell awk -F',' '{url=$$1; name=$$2; gsub(/[ \r\t]/,"",url); gsub(/[ \r\t]/,"",name); if (url != "" && substr(url,1,1) != "\#" && name != "") print "$(GAMES_DIR)/" name;}' $(CSVFILE) 2>/dev/null)

all: $(DSKIMAGE)

$(TARGET): $(DEPS)
	$(ASM) -f os9 $(OPTIONS) --includedir=$(NITROS9DIR)/defs -o $@ os9_cocozip.asm

# Rules to build the base minimal floppy disk images
$(SRCDISKIMAGE):
	$(MAKE) -C $(SRCDISKDIR) MINIMAL=1

# Create a single-story floppy test disk image
$(DSKIMAGE): $(TARGET) $(SRCDISKIMAGE) $(STORY)
	rm -f $(DSKIMAGE)
	cp $(SRCDISKIMAGE) $(DSKIMAGE)
	os9 copy $(TARGET) $(DSKIMAGE),CMDS/$(TARGET)
	os9 attr -e -pe -q $(DSKIMAGE),CMDS/$(TARGET)
	os9 copy $(STORY) $(DSKIMAGE),$(notdir $(LOWER_STORY))

# Rules for downloading multi-game story files
$(GAMES_DIR):
	mkdir -p $(GAMES_DIR)

$(GAMES_DIR)/%: $(CSVFILE) | $(GAMES_DIR)
	@URL=$$(awk -F',' -v name="$*" '{url=$$1; n=$$2; gsub(/[ \r\t]/,"",url); gsub(/[ \r\t]/,"",n); if (n == name) print url;}' $(CSVFILE)); \
	if [ -n "$$URL" ]; then \
		echo "Downloading $$URL -> $@..."; \
		curl -sSfL "$$URL" -o "$@" || { rm -f "$@"; exit 1; }; \
	else \
		echo "Error: Could not find URL for $* in $(CSVFILE)" >&2; \
		exit 1; \
	fi

fetch-games: $(GAME_FILES)

# Rules to build the base NitrOS-9 DriveWire and Wildbits disk images
$(COCO_DW_SRCDISKIMAGE):
	$(MAKE) -C $(COCO_DW_SRCDISKDIR)

$(COCO3_DW_SRCDISKIMAGE):
	$(MAKE) -C $(COCO3_DW_SRCDISKDIR)

$(WILDBITS_SRCDISKDIR)/l2_wildbits%.dsk:
	$(MAKE) -C $(WILDBITS_SRCDISKDIR) PLATFORM=$*

# FujiNet DriveWire multi-game disk images
infocom_coco_dw.dsk: $(TARGET) $(COCO_DW_SRCDISKIMAGE) $(GAME_FILES)
	rm -f $@
	cp $(COCO_DW_SRCDISKIMAGE) $@
	os9 copy -o=0 $(TARGET) $@,CMDS/$(TARGET)
	os9 attr -e -pe -q $@,CMDS/$(TARGET)
	os9 makdir $@,GAMES
	os9 copy -o=0 $(GAME_FILES) $@,GAMES

infocom_coco3_dw.dsk: $(TARGET) $(COCO3_DW_SRCDISKIMAGE) $(GAME_FILES)
	rm -f $@
	cp $(COCO3_DW_SRCDISKIMAGE) $@
	os9 copy -o=0 $(TARGET) $@,CMDS/$(TARGET)
	os9 attr -e -pe -q $@,CMDS/$(TARGET)
	os9 makdir $@,GAMES
	os9 copy -o=0 $(GAME_FILES) $@,GAMES

# Wildbits multi-game disk images
infocom_wildbits_jr2.dsk: $(TARGET) $(WILDBITS_SRCDISKDIR)/l2_wildbitsjr2.dsk $(GAME_FILES)
	rm -f $@
	cp $(WILDBITS_SRCDISKDIR)/l2_wildbitsjr2.dsk $@
	os9 copy -o=0 $(TARGET) $@,CMDS/$(TARGET)
	os9 attr -e -pe -q $@,CMDS/$(TARGET)
	os9 makdir $@,GAMES
	os9 copy -o=0 $(GAME_FILES) $@,GAMES

infocom_wildbits_k2.dsk: $(TARGET) $(WILDBITS_SRCDISKDIR)/l2_wildbitsk2.dsk $(GAME_FILES)
	rm -f $@
	cp $(WILDBITS_SRCDISKDIR)/l2_wildbitsk2.dsk $@
	os9 copy -o=0 $(TARGET) $@,CMDS/$(TARGET)
	os9 attr -e -pe -q $@,CMDS/$(TARGET)
	os9 makdir $@,GAMES
	os9 copy -o=0 $(GAME_FILES) $@,GAMES

# Target aliases
fujinet: infocom_coco_dw.dsk infocom_coco3_dw.dsk
fujinet-coco: infocom_coco_dw.dsk
fujinet-coco3: infocom_coco3_dw.dsk

wildbits: $(WILDBITS_DSK)
wildbits-jr2: infocom_wildbits_jr2.dsk
wildbits-k2: infocom_wildbits_k2.dsk

.PHONY: all clean clean-games distclean fetch-games fujinet fujinet-coco fujinet-coco3 wildbits wildbits-jr2 wildbits-k2 run

MAME_BINARY  ?= mame
MAME_FLAGS   ?= -rompath $(MAME_ROM_PATH) -window -skip_gameinfo -autoboot_delay 5 -autoboot_command "DOS\n" -ext fdc -ext:fdc:wd17xx:0 525qd

run: $(DSKIMAGE)
	$(MAME_BINARY) $(MAME_MACHINE) $(MAME_FLAGS) -flop1 $(DSKIMAGE)

# Clean up build artifacts
clean:
	rm -f $(TARGET) *.dsk *.list *.map *.bak

clean-games:
	rm -rf $(GAMES_DIR)

distclean: clean clean-games
