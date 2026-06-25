*******************************************************************************
* OS9_READ.ASM - OS-9 Port of Lexical Analysis (ZLEX)
*******************************************************************************


*-------------------------------------------------------------------------------
* ZLEX: Perform Lexical Analysis on Input Buffer
* Input: ARG1 = Text buffer address, ARG2 = Parse table address, MASK = length
*-------------------------------------------------------------------------------
ZLEX:   clr     PZSTFO,u        * # CHARS IN CURRENT WORD

        ldx     zcode_ptr,u
        ldd     ARG2,u
        leax    d,x
        clr     1,x             * TO ZERO

        lda     #1              * = 1
        sta     STABP,u         * INIT SOURCE TABLE POINTER
        inca                    * = 2
        sta     RTABP,u         * AND RESULT TABLE POINTER

READL:  ldx     zcode_ptr,u
        ldd     ARG2,u
        leax    d,x
        lda     ,x+             * FETCH MAXIMUM # OF WORDS
        cmpa    ,x              * COMPARE TO # WORDS READ
        bhs     RL1             * STILL ROOM

        * *** ERROR #13 -- PARSER OVERFLOW ***
        lda     #13
        lbra     ZERROR

RL1:    lda     MASK+1,u        * Remaining characters in line
        ora     PZSTFO,u        * Any characters in current word?
        bne     RL2             * NOT YET
RDEX:   rts                     * ELSE SCRAM

RL2:    lda     PZSTFO,u        * GET CHAR COUNT
        cmpa    #6              * 6 CHARS DONE?
        blo     RL3             * NOT YET
        lbsr    FLUSHW          * ELSE FLUSH WORD

RL3:    lda     PZSTFO,u        * FIRST CHAR IN WORD?
        bne     READL2          * NOPE

        * CLEAR OUT WORD BUFFER [ZSTBUI]
        clrb                    * [A] IS ALREADY ZERO
        std     ZSTBUI,u
        std     ZSTBUI+2,u
        std     ZSTBUI+4,u

        ldb     RTABP,u
        ldx     zcode_ptr,u
        ldd     ARG2,u
        leax    d,x
        ldb     RTABP,u         * Restore B since LDD trashed it
        abx
        ldb     STABP,u
        stb     3,x             * STORE POSITION

        ldx     zcode_ptr,u
        ldd     ARG1,u
        leax    d,x
        ldb     STABP,u
        lda     b,x             * GRAB A CHAR FROM SOURCE BUFFER
        lbsr    SIBRKP          * IS IT A SIB?
        bcs     RSIBRK          * YES IF CARRY IS SET
        lbsr    NBRKP           * IS IT A "NORMAL" BREAK CHAR?
        bcc     READL2          * NO, KEEP SCANNING
        inc     STABP,u         * ELSE FLUSH STRANDED BREAK
        dec     MASK+1,u          * UPDATE # OF CHARS IN LINE
        lbra    READL           * AND LOOP BACK

READL2: lda     MASK+1,u        * OUT OF CHARS?
        beq     READL3          * SURE ENOUGH
        ldb     STABP,u
        ldx     zcode_ptr,u
        ldd     ARG1,u
        leax    d,x
        ldb     STABP,u         * Restore B
        lda     b,x             * ELSE GRAB NEXT CHAR
        lbsr    RBRKP           * IS IT A BREAK?
        bcs     READL3          * YES IF CARRY SET
        ldb     PZSTFO,u        * ELSE POINT TO
        leax    ZSTBUI,u        * WORD BUFFER
        sta     b,x             * STORE CHAR IN BUFFER
        dec     MASK+1,u          * ONE LESS CHAR IN LINE
        inc     PZSTFO,u        * ONE MORE IN RESULT
        inc     STABP,u         * POINT TO NEXT CHAR
        lbra    READL           * AND LOOP BACK

RSIBRK: sta     ZSTBUI,u        * STORE THE SIB
        dec     MASK+1,u          * UPDATE LINE-CHAR COUNT
        inc     PZSTFO,u        * WORD-CHAR COUNT
        inc     STABP,u         * AND # CHARS IN WORD

READL3: lda     PZSTFO,u        * ANY CHARS IN WORD?
        lbeq    READL           * APPARENTLY NOT

        ldb     RTABP,u         * POINT TO
        ldx     zcode_ptr,u     * IN THIS ENTRY
        ldd     ARG2,u
        leax    d,x
        ldb     RTABP,u         * Restore B
        abx
        lda     PZSTFO,u        * FETCH ACTUAL WORD LENGTH
        sta     2,x             * AND STORE IN 3RD BYTE

        lda     MASK+1,u
        pshs    a               * SAVE THIS
        lbsr     CONZST          * CONVERT TO Z-STRING
        bsr     FINDW           * LOOK UP IN VOCABULARY
        puls    a
        sta     MASK+1,u        * RESTORE

        ldx     zcode_ptr,u
        ldd     ARG2,u
        leax    d,x
        inc     1,x             * UPDATE # WORDS READ
        ldb     RTABP,u         * POINT [X] TO 1ST BYTE
        abx                     * IN CURRENT ENTRY
        addb    #4
        stb     RTABP,u         * POINT TO NEXT ENTRY
        ldd     VAL,u           * STORE [VAL] IN ENTRY
        std     ,x
        clr     PZSTFO,u        * RESET WORD-CHAR COUNT
        lbra     READL           * AND CONTINUE

*-------------------------------------------------------------------------------
* FLUSHW: Flush remaining characters in a word
*-------------------------------------------------------------------------------
FLUSHW: lda     MASK+1,u
        beq     FLEX
        ldb     STABP,u
        ldx     zcode_ptr,u
        ldd     ARG1,u
        leax    d,x
        ldb     STABP,u         * Restore B
        lda     b,x
        bsr     RBRKP           * WORD BREAK?
        bcs     FLEX            * EXIT IF SO
        dec     MASK+1,u
        inc     PZSTFO,u
        inc     STABP,u
        bra     FLUSHW          * KEEP LOOPING
FLEX:   rts

*-------------------------------------------------------------------------------
* RBRKP: Break Character Scan
*-------------------------------------------------------------------------------
RBRKP:  bsr     SIBRKP          * FIRST CHECK FOR SIBS
        bcs     FBRK            * EXIT IF MATCHED
        * FALL THROUGH TO NBRKP

*-------------------------------------------------------------------------------
* NBRKP: Normal Break Character Scan
*-------------------------------------------------------------------------------
NBRKP:  leax    BRKTBL,pcr      * BASE OF BREAK CHAR TABLE
        ldb     #NBRKS-1        * NUMBER OF NORMAL BREAK CHARS
        bra     NBR1

*-------------------------------------------------------------------------------
* SIBRKP: Self-Inserting Break Character Scan
*-------------------------------------------------------------------------------
SIBRKP: ldx     vocab_ptr,u
        ldb     ,x+             * GET # SIB CHARS
        decb                    * ZERO-ALIGN COUNT

NBR1:   cmpa    b,x
        beq     FBRK            * MATCHED!
        decb
        bpl     NBR1            * KEEP LOOPING
        clrb                    * NO MATCH, CLEAR CARRY
        rts
FBRK:   comb                    * SET CARRY TO FLAG MATCH
        rts

*-------------------------------------------------------------------------------
* FINDW: Vocabulary Search
*-------------------------------------------------------------------------------
FINDW:  ldx     vocab_ptr,u
        ldb     ,x+             * GET # SIB BYTES
        abx                     * AND SKIP OVER THEM

        lda     ,x+             * # BYTES PER TABLE ENTRY
        sta     PZSTFO,u        * SAVE IT HERE

        ldd     ,x++            * # OF ENTRIES IN TABLE
        std     VAL,u           * SAVE THAT TOO

FWL1:   ldd     ,x              * CHECK FIRST Z-WORD
        cmpd    ZSTBUO,u
        bne     WNEXT           * NO GOOD
        ldd     2,x             * ELSE CHECK 2ND HALF
        cmpd    ZSTBUO+2,u
        beq     FWSUCC          * MATCHED!

WNEXT:  ldb     PZSTFO,u        * MOVE [X] UP TO
        abx                     * NEXT TABLE ENTRY
        ldd     VAL,u
        subd    #1
        std     VAL,u           * OUT OF ENTRIES YET?
        bne     FWL1            * NO, KEEP LOOKING
        rts                     * ELSE RETURN WITH [VAL]=0

FWSUCC: tfr     x,d             * D = absolute pointer to vocabulary entry
        ldx     zcode_ptr,u     * X = base address of story preload
        pshs    x
        subd    ,s++            * D = absolute - base (result is relative Z-address)
        std     VAL,u           * store in result register
        rts

*-------------------------------------------------------------------------------
* Normal Break Characters
*-------------------------------------------------------------------------------
BRKTBL: fcc     "!?,."
        fcb     $0D
        fcb     $20

NBRKS   EQU     6               * # NORMAL BREAK CHARS

