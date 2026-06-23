# Makefile for NitrOS-9 Infocom Port (Phase 1)

SHELF = $(HOME)/development/git/coco-shelf
LWASM = $(SHELF)/bin/lwasm
NITROS9 = $(HOME)/development/git/nitros9
OPTIONS = -DLevel=1 --pragma=cescapes,pcaspcr,nosymbolcase,condundefzero,undefextern,dollarnotlocal,noforwardrefmax

# Target binary name
TARGET = OS9ZIP

DEPS = OS9_COCOZIP.ASM OS9_EQ.ASM OS9_IO.ASM OS9_DISK.ASM OS9_PAGING.ASM \
       OS9_SUBS.ASM OS9_OBJECTS.ASM OS9_ZSTRING.ASM OS9_READ.ASM OS9_OPS.ASM \
       OS9_SCREEN.ASM OS9_MAIN.ASM OS9_DISPATCH.ASM

all: $(TARGET)

$(TARGET): $(DEPS)
	$(LWASM) -f os9 $(OPTIONS) --includedir=$(NITROS9)/defs -o $@ OS9_COCOZIP.ASM


# Clean up build artifacts
clean:
	rm -f $(TARGET) *.list *.map *.bak

# Create a test disk image (requires imgtool and os9 tools)
disk: $(TARGET)
	rm -f os9test.dsk
	imgtool create coco_jvc_os9 os9test.dsk
	os9 format os9test.dsk
	os9 copy $(TARGET) os9test.dsk,$(TARGET)
	os9 copy ZORK1.DAT os9test.dsk,ZORK1.DAT
	os9 attr -e -pe os9test.dsk,$(TARGET)

.PHONY: all clean disk
