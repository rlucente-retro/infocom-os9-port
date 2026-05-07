
SHELF = $(HOME)/development/git/coco-shelf
LWASM = $(SHELF)/bin/lwasm

all: COCOZIP.ASM *.ASM
	$(LWASM) -f raw -o cocozip.bin COCOZIP.ASM
	# Pad to exactly 23 sectors ($1700 bytes) to match original expectations
	printf "\0%.0s" {1..64} >> cocozip.bin

clean:
	rm -f cocozip.bin *.map *.list
