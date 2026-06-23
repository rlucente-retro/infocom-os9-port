*******************************************************************************
* OS9_OBJECTS.ASM - OS-9 Port of Z-Machine Object Logic
*******************************************************************************


*-------------------------------------------------------------------------------
* PROPB: Get pointer to property table for object ARG1+1
* Exit: X = absolute address of first property
*-------------------------------------------------------------------------------
PROPB:  lda     ARG1+1,u
        bsr     OBJLOC
        ldx     TEMP,u
        ldd     7,x             * get property table offset from object
        ldx     zcode_ptr,u
        leax    d,x             * calculate absolute address of name
        ldb     ,x              * first byte is length of name (in words)
        aslb                    * name length in bytes
        leax    1,x             * skip length byte
        leax    b,x             * skip name words
        rts                     * X now points to first property

*-------------------------------------------------------------------------------
* PROPN: Get property number from pointer in X
* Exit: A = property number
*-------------------------------------------------------------------------------
PROPN:  lda     ,x              * get property header byte
        anda    #%00011111      * property number is bits 0-4
        rts

*-------------------------------------------------------------------------------
* PROPL: Get property length from pointer in X
* Exit: A = property length (1 to 8 bytes)
*-------------------------------------------------------------------------------
PROPL:  lda     ,x              * get property header byte
        * length is bits 5-7 (0-7, representing 1-8 bytes)
        lsra
        lsra
        lsra
        lsra
        lsra
        anda    #%00000111
        rts

*-------------------------------------------------------------------------------
* PROPNX: Move to next property in table
* Input: X = current property pointer
* Exit: X = next property pointer
*-------------------------------------------------------------------------------
PROPNX: bsr     PROPL           * get length (0-7 for 1-8 bytes)
        leax    1,x             * skip header byte
        tfr     a,b
        clra                    * D = length-1
        addd    #1              * D = actual data length
        leax    d,x             * skip data bytes
        rts

*-------------------------------------------------------------------------------
* FLAGSU: Prepare mask and pointer for flag manipulation
* Input: ARG1+1 = object ID, ARG2+1 = flag ID
* Exit: TEMP = address of flag word, MASK = bit mask, VAL = current flags
*-------------------------------------------------------------------------------
FLAGSU: lda     ARG1+1,u
        bsr     OBJLOC
        lda     ARG2+1,u
        cmpa    #16             * flags 0-15 are in first word
        blo     FLGSU1
        suba    #16             * flags 16-31 are in second word
        ldx     TEMP,u
        leax    2,x             * point to second flags word
        stx     TEMP,u

FLGSU1: sta     VAL+1,u
        ldd     #1
        std     MASK,u
        ldb     #15
        subb    VAL+1,u

FLGSU2: beq     FLGSU3
        asl     MASK+1,u
        rol     MASK,u
        decb
        bra     FLGSU2

FLGSU3: ldx     TEMP,u
        ldd     ,x
        std     VAL,u           * return current flag word in VAL
        rts

*-------------------------------------------------------------------------------
* OBJLOC: Get absolute address of object A
* Exit: TEMP = absolute RAM address
*-------------------------------------------------------------------------------
OBJLOC: ldb     #9              * 9 bytes per object
        mul
        addd    #53             * (1*9 + 53 = 62) Object 1 starts at offset 62
        pshs    d
        ldx     zcode_ptr,u
        ldd     ZOBJEC,x        * get Object Table offset from Z-header
        addd    ,s++            * add object offset
        leax    d,x             * X = absolute address
        stx     TEMP,u
        rts
