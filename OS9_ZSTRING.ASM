*******************************************************************************
* OS9_ZSTRING.ASM - OS-9 Port of Z-Machine String Logic
*******************************************************************************

*-------------------------------------------------------------------------------
* SETSTR: Point MPC to a Z-string (WORD-address in TEMP)
*-------------------------------------------------------------------------------
SETSTR: clra
        asl     TEMP+1,u
        rol     TEMP,u
        rola
        sta     MPCH,u
        ldd     TEMP,u
        std     MPCM,u
        clr     MPCFLG,u
        rts

*-------------------------------------------------------------------------------
* GETZCH: Fetch next 5-bit character from Z-string
* Entry: MPC points to current 2-byte word
* Exit: A = 5-bit character, Carry set if end of string
*-------------------------------------------------------------------------------
GETZCH: lda     STBYTF,u        * Get byte phase (0, 1, or 2, or negative for EOF)
        bpl     GTZ0
        comb                    * Set carry to indicate no more characters
        rts

GTZ0:   bne     GETZH1          * If phase is 1 or 2
        inc     STBYTF,u        * Set phase to 1
        lbsr    GETWRD          * Fetch next 16-bit word from MPC
        ldd     TEMP,u
        std     ZSTWRD,u
        lsra
        lsra
GTEXIT: anda    #$1F            * Isolate 5 bits
        clrb                    * Clear carry
        rts

GETZH1: deca
        bne     GETZH2          * Must be phase 2
        lda     #2
        sta     STBYTF,u        * Set phase to 2
        ldd     ZSTWRD,u
        lsra
        rorb
        lda     ZSTWRD,u
        lsra
        lsra
        rorb
        lsrb
        lsrb
        lsrb
GETZH3: tfr     b,a
        bra     GTEXIT

GETZH2: clr     STBYTF,u        * Reset phase to 0
        ldd     ZSTWRD,u
        bpl     GETZH3
        com     STBYTF,u        * Set STBYTF to $FF (EOF flag)
        bra     GETZH3

*-------------------------------------------------------------------------------
* PZSTR: Print Z-string at MPC
*-------------------------------------------------------------------------------
PZSTR:  clr     CSPERM,u
        clr     STBYTF,u
        lda     #$FF
        sta     CSTEMP,u

PZSTRL: lbsr    GETZCH
        bcs     ZSTEX
        sta     MASK,u          * Save char
        beq     PZSTRS          * 0 = Space
        cmpa    #4
        blo     PZSTRF          * F-word
        cmpa    #6
        blo     PZSTRT          * Shift char

        lbsr    GETMOD          * Get current charset (in A)
        tsta                    * Charset 0?
        bne     PZSTR1

        lda     #$61-6          * ASCII 'a' minus Z-offset
PZSTP0: adda    MASK,u
PZSTP1: lbsr    MYCHR           * Output character
        bra     PZSTRL

PZSTR1: cmpa    #1              * Charset 1?
        bne     PZSTR2          * No, it's charset 2

        lda     #$41-6          * ASCII 'A' minus Z-offset
        bra     PZSTP0

PZSTR2: ldb     MASK,u
        subb    #6
        beq     PZSTRA          * 6 = Direct ASCII
        leax    CHRTBL,pcr
        lda     b,x
        bra     PZSTP1

PZSTRA: lbsr    GETZCH          * Get next Z-byte (5 bits)
        asla
        asla
        asla
        asla
        asla
        sta     MASK,u
        lbsr    GETZCH          * Get next Z-byte
        sta     MASK+1,u
        lda     MASK,u
        ora     MASK+1,u        * Superimpose to get 10-bit ASCII code
        bra     PZSTP1

PZSTRS: lda     #$20            * Space
        bra     PZSTP1

PZSTRT: suba    #3              * Convert 4-5 to 1-2
        tfr     a,b
        lbsr    GETMOD
        bne     PZSTRP          * Permanent shift
        stb     CSTEMP,u        * Temporary shift
        bra     PZSTRL

PZSTRP: stb     CSPERM,u
        cmpa    CSPERM,u
        beq     PZSTRL
        clr     CSPERM,u
        bra     PZSTRL

ZSTEX:  rts

*-------------------------------------------------------------------------------
* GETMOD: Get active charset (0, 1, or 2)
*-------------------------------------------------------------------------------
GETMOD: lda     CSTEMP,u
        bpl     GM
        lda     CSPERM,u
        rts
GM:     ldb     #$FF
        stb     CSTEMP,u
        rts

*-------------------------------------------------------------------------------
* PZSTRF: Handle F-words (Abbreviations)
*-------------------------------------------------------------------------------
PZSTRF: deca                    * Convert 1-3 to 0-2
        ldb     #64             * 64 bytes per group
        mul
        stb     PZSTFO,u
        lbsr    GETZCH          * Get abbreviation index
        tfr     a,b
        aslb
        addb    PZSTFO,u
        
        * Calculate absolute address of table entry
        clra                    * D = offset
        addd    FWORDS,u        * D = FWORDS offset + entry offset
        ldx     zcode_ptr,u
        leax    d,x             * X = absolute entry address
        ldd     ,x              * D = F-word word address
        std     TEMP,u

        * Save print state on machine stack
        lda     MPCH,u
        pshs    a
        ldd     ZSTWRD,u
        pshs    d
        lda     CSPERM,u
        ldb     STBYTF,u
        ldx     MPCM,u
        pshs    x,b,a

        * Print nested abbreviation Z-string
        lbsr    SETSTR
        lbsr    PZSTR

        * Restore print state
        puls    x,b,a
        stx     MPCM,u
        stb     STBYTF,u
        sta     CSPERM,u
        puls    d
        std     ZSTWRD,u
        puls    a
        sta     MPCH,u

        lda     #$FF
        sta     CSTEMP,u
        clr     MPCFLG,u
        lbra    PZSTRL

*-------------------------------------------------------------------------------
* CONZST: Convert ASCII string in ZSTBUI to Z-string in ZSTBUO
*-------------------------------------------------------------------------------
CONZST: ldd     #$0505
        std     ZSTBUO,u
        std     ZSTBUO+2,u
        std     ZSTBUO+4,u

        inca                    * A = 6
        sta     MASK,u          * Character count limit
        
        clr     VAL,u           * Output index
        clr     TEMP,u          * Input index

CNZSL1: ldb     TEMP,u
        inc     TEMP,u
        leax    ZSTBUI,u
        lda     b,x
        sta     MASK+1,u
        bne     CNZSL2
        lda     #5              * Padding character
        bra     CNZSLO

CNZSL2: lda     MASK+1,u
        lbsr    ZCHRCS          * Get charset (0, 1, or 2)
        tsta
        beq     CNZSLC          * Lowercase: charset 0
        adda    #3              * Shift code: 4 or 5
        ldb     VAL,u
        leax    ZSTBUO,u
        sta     b,x
        inc     VAL,u
        dec     MASK,u
        lbeq    CNZSLE

CNZSLC: lda     MASK+1,u
        lbsr    ZCHRCS
        deca
        bpl     CNZSC1          * Charset 1 or 2
        lda     MASK+1,u
        suba    #$61-6          * 'a' minus 6
CNZSLO: ldb     VAL,u
        leax    ZSTBUO,u
        sta     b,x
        inc     VAL,u
        dec     MASK,u
        beq     CNZSLE
        bra     CNZSL1

CNZSC1: bne     CNZSC3          * Charset 2
        lda     MASK+1,u
        suba    #$41-6          * 'A' minus 6
        bra     CNZSLO

CNZSC3: lda     MASK+1,u
        lbsr    CNZS2M          * Check if in symbol table
        bne     CNZSLO
        lda     #6              * Direct ASCII escape character
        ldb     VAL,u
        leax    ZSTBUO,u
        sta     b,x
        inc     VAL,u
        dec     MASK,u
        beq     CNZSLE

        * Convert to 10-bit raw ASCII (2 5-bit characters)
        lda     MASK+1,u
        lsra
        lsra
        lsra
        lsra
        lsra
        anda    #$03
        ldb     VAL,u
        leax    ZSTBUO,u
        sta     b,x
        inc     VAL,u
        dec     MASK,u
        beq     CNZSLE
        lda     MASK+1,u
        anda    #$1F
        bra     CNZSLO

*-------------------------------------------------------------------------------
* CNZS2M: Search Charset 2 table for character in A
*-------------------------------------------------------------------------------
CNZS2M: leax    CHRTBL,pcr
        ldb     #25
CNLOOP: cmpa    b,x
        beq     CNOK
        decb
        bne     CNLOOP
        rts

CNOK:   tfr     b,a
        adda    #6
        rts

*-------------------------------------------------------------------------------
* ZCHRCS: Get charset for ASCII character in A
*-------------------------------------------------------------------------------
ZCHRCS: cmpa    #$61            * 'a'
        blo     ZCHR1
        cmpa    #$7B            * 'z' + 1
        bhs     ZCHR1
        clra
        rts

ZCHR1:  cmpa    #$41            * 'A'
        blo     ZCHR2
        cmpa    #$5B            * 'Z' + 1
        bhs     ZCHR2
        lda     #1
        rts

ZCHR2:  tsta
        beq     ZCHRX
        bmi     ZCHRX
        lda     #2
ZCHRX:  rts

*-------------------------------------------------------------------------------
* CNZSLE: Pack the output triplets into Z-string words
*-------------------------------------------------------------------------------
CNZSLE: ldd     ZSTBUO,u
        aslb
        aslb
        aslb
        aslb
        rola
        aslb
        rola
        orb     ZSTBUO+2,u
        std     ZSTBUO,u

        ldd     ZSTBUO+3,u
        aslb
        aslb
        aslb
        aslb
        rola
        aslb
        rola
        orb     ZSTBUO+5,u
        ora     #$80            * Set end-of-string bit in last Z-word
        std     ZSTBUO+2,u
        rts

*-------------------------------------------------------------------------------
* Charset 2 Decode Table
*-------------------------------------------------------------------------------
CHRTBL: fcb     0               * Dummy byte
        fcb     $0D             * Carriage Return
        fcc     "0123456789.,!?_#"
        fcb     $27             * Single Quote
        fcb     $22             * Double Quote
        fcc     "/\\-:()"
