*******************************************************************************
* OS9_PAGING.ASM - OS-9 Port of Z-Machine Paging System
*******************************************************************************


*-------------------------------------------------------------------------------
* FETCH A VIRTUAL WORD
*-------------------------------------------------------------------------------
GETWRD: bsr     GETBYT
        sta     TEMP,u
        bsr     GETBYT
        sta     TEMP+1,u
        rts

*-------------------------------------------------------------------------------
* FETCH NEXT Z-BYTE (from PC)
*-------------------------------------------------------------------------------
NEXTPC: pshs    x
        tst     ZPCFLG,u        * Is ZPCPNT valid?
        bne     NPC2            * Yes, get byte

* Z-page has changed
        ldd     ZPCH,u          * get top 9 bits of PC
        tsta                    * top bit set?
        bne     NPC0            * yes, must swap

        cmpb    ZPURE,u         * is this page preloaded?
        bhs     NPC0            * no, swap it in

* Calculate absolute page of preloaded code
        addb    zcode_ptr,u     * add MSB of preload base
        bra     NPC1

NPC0:   clr     MPCFLG,u        * invalidate MPC for safety
        bsr     PAGE            * swap in page, returns page in B

NPC1:   stb     ZPCPNT,u        * set MSB of buffer address
        clr     ZPCPNT+1,u      * LSB is always 0 (page aligned)
        lda     #TRUE
        sta     ZPCFLG,u

NPC2:   ldb     ZPCL,u          * get byte index
        ldx     ZPCPNT,u        * absolute page address
        abx                     * unsigned 8-bit offset addition
        lda     ,x              * fetch byte
        inc     ZPCL,u          * point to next byte
        bne     NPC3            * if no overflow, done

        clr     ZPCFLG,u        * invalidate cache
        inc     ZPCM,u          * point to next page
        bne     NPC3
        inc     ZPCH,u

NPC3:   puls    x,pc                     * return byte in A

*-------------------------------------------------------------------------------
* GET NEXT VIRTUAL BYTE (from MPC)
*-------------------------------------------------------------------------------
GETBYT: pshs    x
        tst     MPCFLG,u
        bne     GTBT2

* Z-page has changed
        ldd     MPCH,u
        tsta
        bne     GTBT0

* Patch point for Verify (Phase 1 used a label, we'll keep it)
PATCH_LABEL:
        tst     ver_flag,u
        bne     GTBT0           * If verification in progress, force swap from disk
        cmpb    ZPURE,u
        bhs     GTBT0

        addb    zcode_ptr,u
        bra     GTBT1

GTBT0:  clr     ZPCFLG,u
        bsr     PAGE

GTBT1:  stb     MPCPNT,u
        clr     MPCPNT+1,u
        lda     #TRUE
        sta     MPCFLG,u

GTBT2:  ldb     MPCL,u
        ldx     MPCPNT,u
        abx
        lda     ,x
        inc     MPCL,u
        bne     GTBT3
        clr     MPCFLG,u
        inc     MPCM,u
        bne     GTBT3
        inc     MPCH,u

GTBT3:  puls    x,pc

*-------------------------------------------------------------------------------
* LOCATE A SWAPPABLE Z-PAGE
* Input: D = target page (top 9 bits)
* Exit: B = absolute buffer page MSB
*-------------------------------------------------------------------------------
PAGE:   std     DBLOCK,u
        lda     PMAX,u          * loop counter
        pshs    a               * push to stack
        leax    PTABLE,u        * bottom of paging table
PG0:    cmpd    ,x++            * found it?
        beq     PG_FOUND
        dec     ,s
        bne     PG0
        puls    a               * clean stack on failure

* Swap in the target page
        bsr     EARLY           * find earliest page (LRU)
        ldb     SWAP,u
        stb     ZPAGE,u

        addb    PAGE0,u         * calc absolute page (MSB)
        stb     DBUFF,u         * tell disk where to put data
        clr     DBUFF+1,u

        leax    PTABLE,u
        ldb     ZPAGE,u
        aslb                    * 2 bytes per entry
        leax    b,x
        ldd     DBLOCK,u
        std     ,x              * splice into table

        lbsr     GETDSK          * FETCH DATA (Phase 4)
        bra     PG1

PG_FOUND:
        lda     PMAX,u
        suba    ,s+             * A = PMAX - remaining loop counter
        sta     ZPAGE,u

* Update timestamp
PG1:    ldb     ZPAGE,u
        leax    LRUMAP,u
        lda     b,x
        cmpa    STAMP,u
        beq     PG5             * already current

        inc     STAMP,u
        bne     PG4

* Handle stamp overflow
        bsr     EARLY
        leax    LRUMAP,u
        clrb
PG2:    lda     b,x
        beq     PG3             * skip zero
        suba    LRU,u
        sta     b,x
PG3:    incb
        cmpb    PMAX,u
        blo     PG2

        lda     #0
        suba    LRU,u
        sta     STAMP,u

* Stamp the page
PG4:    ldb     ZPAGE,u
        leax    LRUMAP,u
        lda     STAMP,u
        sta     b,x

PG5:    ldb     ZPAGE,u
        addb    PAGE0,u         * return absolute page MSB
        rts

*-------------------------------------------------------------------------------
* LOCATE EARLIEST TIMESTAMP
* Exit: LRU = earliest stamp, SWAP = index to buffer
*-------------------------------------------------------------------------------
EARLY:  leax    LRUMAP,u
        pshs    x               * Push absolute address of index 0 to stack
        lda     ,x+             * A = 1st reading, X = LRUMAP + 1
        ldb     PMAX,u
        decb                    * B = loop counter (PMAX - 1)
        beq     EAR_EXIT
EAR0:   cmpa    ,x
        blo     EAR1
        lda     ,x
        stx     ,s              * Update address of lowest stamp on stack
EAR1:   leax    1,x
        decb
        bne     EAR0

EAR_EXIT:
        sta     LRU,u
        puls    x               * Retrieve absolute address of lowest stamp
        tfr     x,d
        subd    #LRUMAP
        pshs    u
        subd    ,s++            * D = matching index (0 to PMAX-1)
        stb     SWAP,u          * store index back to SWAP
        rts

*-------------------------------------------------------------------------------
* POINT MPC TO TEMP
*-------------------------------------------------------------------------------
SETWRD_MPC:
        ldd     TEMP,u
        std     MPCM,u
        clr     MPCH,u
        clr     MPCFLG,u
        rts

