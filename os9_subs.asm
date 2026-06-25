*******************************************************************************
* OS9_SUBS.ASM - OS-9 Port of Interpreter Subroutines
*******************************************************************************


*-------------------------------------------------------------------------------
* GETSHT: Fetch a short immediate (1 byte) from Z-machine PC
*-------------------------------------------------------------------------------
GETSHT: lbsr     NEXTPC          * Next Z-byte is LSB
        sta     TEMP+1,u
        clr     TEMP,u          * MSB is zero
        rts

*-------------------------------------------------------------------------------
* GETLNG: Fetch a long immediate (2 bytes) from Z-machine PC
*-------------------------------------------------------------------------------
GETLNG: lbsr     NEXTPC          * MSB
        sta     TEMP,u
        lbsr     NEXTPC          * LSB
        sta     TEMP+1,u
        rts

*-------------------------------------------------------------------------------
* VARGET: Fetch a variable within an opcode
* Input: A = variable ID
*-------------------------------------------------------------------------------
VARGET: tsta                    * If zero, value is on stack
        bne     GETVR1
        cmpy    zsp_top,u       * Check stack empty
        lbhs    UNDER           * Underflow if Y >= zsp_top
        ldd     ,y              * Peek top word
        std     TEMP,u
        rts

*-------------------------------------------------------------------------------
* GETVAR: Fetch variable ID from PC and return value in TEMP
*-------------------------------------------------------------------------------
GETVAR: lbsr     NEXTPC          * Grab var-type byte
        tsta
        lbeq    POPSTK          * 0 = Z-stack

GETVR1: cmpa    #16
        bhs     GETVRG          * 16-255 = Global

* Local variable (1-15)
        deca                    * 0-aligned index
        asla                    * word index
        leax    LOCALS,u
        ldd     a,x             * fetch value
        std     TEMP,u
        rts

* Global variable
GETVRG: suba    #16
        tfr     a,b
        clra
        aslb                    * word-align (index * 2)
        rola                    * D is now 16-bit offset
        ldx     global_ptr,u    * absolute Table base
        ldd     d,x             * fetch word
        std     TEMP,u
        rts

*-------------------------------------------------------------------------------
* VARPUT: Return a value to a variable
* Input: A = variable ID, TEMP = value
*-------------------------------------------------------------------------------
VARPUT: tsta
        bne     PUTVR1
        cmpy    zsp_top,u       * Check stack empty
        lbhs    UNDER           * Underflow if Y >= zsp_top
        ldd     TEMP,u          * Load value
        std     ,y              * Overwrite top word directly
        rts

*-------------------------------------------------------------------------------
* PUTBYT: Return byte in A as word in TEMP
*-------------------------------------------------------------------------------
PUTBYT: sta     TEMP+1,u
        clr     TEMP,u
        * fall through to PUTVAL

*-------------------------------------------------------------------------------
* PUTVAL: Store value in TEMP into variable ID fetched from PC
*-------------------------------------------------------------------------------
PUTVAL: ldx     TEMP,u
        pshs    x               * save value
        lbsr     NEXTPC          * get var-type byte
        puls    x
        stx     TEMP,u
        tsta
        beq     PSHSTK          * 0 = Z-stack

PUTVR1: cmpa    #16
        bhs     PUTVLG

* Local variable
        deca
        asla
        tfr     a,b
        leax    LOCALS,u
        leax    b,x
        ldd     TEMP,u
        std     ,x
        rts

* Global variable
PUTVLG: suba    #16
        tfr     a,b
        clra
        aslb
        rola
        ldx     global_ptr,u
        leax    d,x
        ldd     TEMP,u
        std     ,x
        rts

*-------------------------------------------------------------------------------
* PSHSTK: Push TEMP to Z-stack (Y)
*-------------------------------------------------------------------------------
PSHSTK: ldd     TEMP,u
        * fall through to PSHDZ

*-------------------------------------------------------------------------------
* PSHDZ: Push D to Z-stack (Y)
*-------------------------------------------------------------------------------
PSHDZ:  std     ,--y
        pshs    x
        leax    ZSTACK,u        * X = absolute address of ZSTACK
        pshs    y
        cmpx    ,s++            * Compare ZSTACK base to current Y
        bhi     OVER            * If ZSTACK > Y, stack has overflowed
        puls    x,pc

*-------------------------------------------------------------------------------
* POPSTK: Pop word from Z-stack (Y) into TEMP and D
*-------------------------------------------------------------------------------
POPSTK: ldd     ,y++
        std     TEMP,u
        cmpy    zsp_top,u
        bhi     UNDER
        rts

*-------------------------------------------------------------------------------
* Error Handlers
*-------------------------------------------------------------------------------
UNDER:  lda     #5
        lbra     ZERROR
OVER:   lda     #6
        lbra     ZERROR

*-------------------------------------------------------------------------------
* Predicate Handling
*-------------------------------------------------------------------------------
PREDF:  lbsr     NEXTPC          * Get 1st branch byte
        tsta
        bpl     PREDB           * Bit 7=0: branch on success
PREDNB: anda    #%01000000      * Bit 6 set?
        bne     PNBX            * Yes: 1-byte branch
        lbsr     NEXTPC          * No: skip 2nd byte
PNBX:   rts

PREDS:  lbsr     NEXTPC
        tsta
        bpl     PREDNB          * Branch on failure?
        * fall through to PREDB

PREDB:  bita    #%01000000      * Long or short?
        beq     PREDLB
        anda    #%00111111      * Short offset
        sta     TEMP+1,u
        clr     TEMP,u
        bra     PREDB1

PREDLB: anda    #%00111111      * MSB
        bita    #%00100000      * Sign extend 14-bit
        beq     DOB2
        ora     #%11100000
DOB2:   pshs    a
        lbsr     NEXTPC
        sta     TEMP+1,u
        puls    a
        sta     TEMP,u

PREDB1: ldd     TEMP,u
        lbeq    ZRFALS          * 0 = RFALSE
        subd    #1
        lbeq    ZRTRUE          * 1 = RTRUE

PREDB3: subd    #1              * D = Offset - 2
        std     TEMP,u
        
        * PC Update Logic (17-bit)
        sta     VAL+1,u
        clrb
        asla                    * extend sign
        rolb
        stb     VAL,u           * Top 9 bits in VAL,VAL+1
        
        lda     TEMP+1,u
        andcc   #%11111110
        adca    ZPCL,u
        bcc     PDB0
        inc     VAL+1,u
        bne     PDB0
        inc     VAL,u

PDB0:   sta     ZPCL,u
        ldd     VAL,u
        beq     PDB1_CLR        * No page change, but clear cache flag!
        
        lda     VAL+1,u
        andcc   #%11111110
        adca    ZPCM,u
        sta     ZPCM,u
        lda     VAL,u
        adca    ZPCH,u
        anda    #$01
        sta     ZPCH,u
PDB1_CLR:
        clr     ZPCFLG,u        * Invalidate PC cache
PDB1:   rts

