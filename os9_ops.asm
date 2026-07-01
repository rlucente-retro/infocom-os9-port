*******************************************************************************
* OS9_OPS.ASM - OS-9 Port of Z-Machine Opcode Handlers
*******************************************************************************


*-------------------------------------------------------------------------------
* 0-OPS
*-------------------------------------------------------------------------------

ZRTRUE: ldb     #1
ZRT:    clra
        std     ARG1,u
        lbra     ZRET

ZRFALS: clrb
        bra     ZRT

ZPRI:   lda     ZPCH,u
        sta     MPCH,u
        ldd     ZPCM,u
        std     MPCM,u
        clr     MPCFLG,u
        lbsr     PZSTR
        lda     MPCH,u
        sta     ZPCH,u
        ldd     MPCM,u
        std     ZPCM,u
        lda     MPCFLG,u
        sta     ZPCFLG,u
        ldd     MPCPNT,u
        std     ZPCPNT,u
ZNOOP:  rts

ZPRR:   bsr     ZPRI
        lbsr     ZCRLF
        bra     ZRTRUE

ZRSTAK: lbsr     POPSTK
        std     ARG1,u
        lbra     ZRET

ZVER:   lbsr    VERNUM          * Display ZIP version code
        ldx     zcode_ptr,u
        ldd     ZLENTH,x        * Get length of Z-code in words
        std     ARG2,u
        
        clra
        clrb
        std     ARG1,u          * Running checksum
        std     ARG3,u          * 17th bit of length
        std     TEMP,u          * Byte count
        
        * Convert length to bytes: shift left by 1 (words * 2)
        asl     ARG2+1,u
        rol     ARG2,u
        rol     ARG3+1,u        * 17th bit
        
        lda     #$40            * Skip first 64 bytes
        sta     TEMP+1,u
        lbsr    SETWRD_MPC      * MPC points to first byte ($0040)
        
        lda     #1
        sta     ver_flag,u      * Enable verification bypass (force disk reads)
        
vsum_lp:
        lbsr    GETBYT          * Get byte from disk
        clrb
        adca    ARG1+1,u        * Add to checksum (16-bit)
        sta     ARG1+1,u
        bcc     vsum_no_inc
        inc     ARG1,u
vsum_no_inc:
        ldd     MPCM,u          * Check if we reached the end of Z-code
        cmpd    ARG2,u
        bne     vsum_lp
        
        lda     MPCH,u
        cmpa    ARG3+1,u
        bne     vsum_lp
        
        clr     ver_flag,u      * Disable verification bypass
        
        ldx     zcode_ptr,u
        ldd     ZCHKSM,x        * Get expected checksum from header
        cmpd    ARG1,u          * Compare with calculated checksum
        lbeq    PREDS           * Match: predicate succeeds
        lbra    PREDF           * Mismatch: predicate fails

ZSAVE:  
        pshs    y               * Protect Z-stack pointer
        sty     BUFSAV+4,u      * Store current Z-stack pointer for saving
        
        leax    save_prompt,pcr
        ldy     #save_plen
        lbsr     GETFILENAME
        lbcs    sz_fail_pop     * Long branch to prevent byte overflow
        
        * I$Create
        leax    BUFSAV,u
        lda     #READ.+WRITE.   * Access mode
        ldb     #3              * Attributes (Read/Write)
        os9     I$Create
        lbcs    sz_fail_pop     * Long branch to prevent byte overflow
        sta     TEMP2,u         * Save file path
        
        * Write Header
        ldx     zcode_ptr,u
        ldd     ZID,x           * Game ID
        std     BUFSAV,u
        ldd     OZSTAK,u
        std     BUFSAV+2,u
        * BUFSAV+4 already has Y
        lda     ZPCH,u
        sta     BUFSAV+6,u
        ldd     ZPCM,u
        std     BUFSAV+7,u
        
        lda     TEMP2,u         * Path
        leax    BUFSAV,u        * Buffer
        ldy     #32             * Length
        os9     I$Write
        bcs     sz_fail_close
        
        * Write Stack
        lda     TEMP2,u
        leax    ZSTACK,u
        ldy     #510
        os9     I$Write
        bcs     sz_fail_close
        
        * Write Local Variables (32 bytes)
        lda     TEMP2,u
        leax    LOCALS,u
        ldy     #32
        os9     I$Write
        bcs     sz_fail_close
        
        * Write Preload
        lda     ZPURE,u
        clrb                    * D = ZPURE * 256
        tfr     d,y
        lda     TEMP2,u
        ldx     zcode_ptr,u
        os9     I$Write
        bcs     sz_fail_close
        
        * Close and Succeed
        lda     TEMP2,u
        os9     I$Close
        puls    y               * Restore sacred pointer
        lbra     PREDS

sz_fail_close:
        lda     TEMP2,u
        os9     I$Close
sz_fail_pop:
        puls    y
sz_fail:
        lbra     PREDF

ZREST:  
        pshs    y               * Protect Z-stack pointer
        leax    rest_prompt,pcr
        ldy     #rest_plen
        lbsr     GETFILENAME
        lbcs    rz_fail_pop     * Long branch to prevent byte overflow
        
        * I$Open
        leax    BUFSAV,u
        lda     #READ.
        os9     I$Open
        lbcs    rz_fail_pop     * Long branch to prevent byte overflow
        sta     TEMP2,u         * Save file path
        
        * Read Header (into BUFSAV)
        leax    BUFSAV,u
        ldy     #32
        os9     I$Read
        bcs     rz_fail_close
        
        * Verify Game ID
        ldx     zcode_ptr,u
        ldd     ZID,x
        cmpd    BUFSAV,u
        bne     rz_fail_close   * ID mismatch
        
        * Read Stack
        lda     TEMP2,u
        leax    ZSTACK,u
        ldy     #510
        os9     I$Read
        bcs     rz_fail_close
        
        * Read Local Variables (32 bytes)
        lda     TEMP2,u
        leax    LOCALS,u
        ldy     #32
        os9     I$Read
        bcs     rz_fail_close
        
        * Read Preload
        lda     ZPURE,u         * Number of pages to read
        clrb                    * D = ZPURE * 256
        tfr     d,y
        lda     TEMP2,u
        ldx     zcode_ptr,u
        os9     I$Read
        bcs     rz_fail_close
        
        * Restore State
        ldd     BUFSAV+2,u
        std     OZSTAK,u
        ldy     BUFSAV+4,u      * Restore Z-Stack pointer!
        sty     ,s              * Update saved Y on stack
        
        lda     BUFSAV+6,u
        sta     ZPCH,u
        ldd     BUFSAV+7,u
        std     ZPCM,u
        clr     ZPCFLG,u        * Invalidate PC Cache
        
        * Close and Succeed
        lda     TEMP2,u
        os9     I$Close
        puls    y               * Restore (potentially new) pointer
        lbra     PREDS

rz_fail_close:
        lda     TEMP2,u
        os9     I$Close
rz_fail_pop:
        puls    y
rz_fail:
        lbra     PREDF

ZSTART: lbra    RESTART_GAME

*-------------------------------------------------------------------------------
* String Constants
*-------------------------------------------------------------------------------
save_prompt fcc     /Enter save file name: /
save_plen   equ     *-save_prompt

rest_prompt fcc     /Enter restore file name: /
rest_plen   equ     *-rest_prompt

ZQUIT:  clrb
        os9     F$Exit

POPSTK_OP:
        lbsr     POPSTK
        rts

*-------------------------------------------------------------------------------
* 1-OPS
*-------------------------------------------------------------------------------

ZZERO:  ldd     ARG1,u
        lbeq    PREDS
        lbra     PREDF

ZNEXT:  lda     ARG1+1,u
        lbsr     OBJLOC
        ldb     #5              * Offset to NEXT in object table
        bra     FIRST1

ZFIRST: lda     ARG1+1,u
        lbsr     OBJLOC
        ldb     #6              * Offset to FIRST

FIRST1: ldx     TEMP,u
        lda     b,x
        sta     TEMP+1,u
        clr     TEMP,u
        pshs    a
        lbsr     PUTVAL
        puls    a
        tsta
        lbeq    PREDF
        lbra     PREDS

ZLOC:   lda     ARG1+1,u
        lbsr     OBJLOC
        ldx     TEMP,u
        lda     4,x             * Parent object
        sta     TEMP+1,u
        clr     TEMP,u
        lbra     PUTVAL

ZPTSIZ: ldd     ARG1,u
        ldx     zcode_ptr,u
        leax    d,x
        leax    -1,x
        stx     TEMP,u
        clrb
        lbsr     PROPL
        inca
        lbra     PUTBYT

ZINC:   lda     ARG1+1,u
        lbsr     VARGET
        ldd     TEMP,u
        addd    #1
ZINC1:  std     TEMP,u
        pshs    d
        lda     ARG1+1,u
        lbsr     VARPUT
        puls    d
        std     TEMP,u
        rts

ZDEC:   lda     ARG1+1,u
        lbsr     VARGET
        ldd     TEMP,u
        subd    #1
        bra     ZINC1

ZPRB:   ldd     ARG1,u
        std     TEMP,u
        lbsr     SETWRD_MPC
        lbra     PZSTR

ZREMOV: lda     ARG1+1,u
        lbsr     OBJLOC
        ldx     TEMP,u
        lda     4,x
        beq     REMVEX
        pshs    x
        lbsr     OBJLOC
        ldx     TEMP,u
        lda     6,x
        cmpa    ARG1+1,u
        bne     REMVC1
        puls    x
        pshs    x
        lda     5,x
        ldx     TEMP,u
        sta     6,x
        bra     REMVC2
REMVC1: lbsr     OBJLOC
        ldx     TEMP,u
        lda     5,x
        cmpa    ARG1+1,u
        bne     REMVC1
        puls    x
        pshs    x
        lda     5,x
        ldx     TEMP,u
        sta     5,x
REMVC2: puls    x
        clr     4,x
        clr     5,x
REMVEX: rts

ZPRD:   lda     ARG1+1,u
PRNTDC: lbsr     OBJLOC
        ldx     TEMP,u
        ldd     7,x
        addd    #1
        std     TEMP,u
        lbsr     SETWRD_MPC
        lbra     PZSTR
ZRET:   ldy     OZSTAK,u        * restore stack pointer to call frame
        ldd     ,y++            * Pop Caller's N (fast)
        stb     CUR_NLOCS,u     * Restore it
        tstb
        beq     ZRET2
        
        stb     VAL+1,u         * Loop counter N (use VAL+1 to avoid POPSTK overwrites)
        clra
        aslb                    * D = 2*N
        leax    LOCALS,u
        leax    d,x             * X points to LOCALS + 2*N
ZRET1:  ldd     ,y++            * Pop local (fast)
        std     ,--x
        dec     VAL+1,u
        bne     ZRET1

ZRET2:  ldd     ,y++            * Pop ZPCH (fast)
        std     ZPCH,u
        ldd     ,y++            * Pop ZPCL (fast)
        stb     ZPCL,u
        ldd     ,y++            * Pop OZSTAK (fast)
        std     OZSTAK,u
        clr     ZPCFLG,u
        ldd     ARG1,u
        std     TEMP,u
        lbra     PUTVAL
RETERR: lda     #15
        lbra     ZERROR

ZJUMP:  ldd     ARG1,u
        subd    #1
        std     TEMP,u
        lbra     PREDB3

ZPRINT: ldd     ARG1,u
        std     TEMP,u
        lbsr     SETSTR
        lbra     PZSTR

ZVALUE: lda     ARG1+1,u
        lbsr     VARGET
        lbra     PUTVAL

ZBCOM:  ldd     ARG1,u
        coma
        comb
        std     TEMP,u
        lbra     PUTVAL

BADOP1: lda     #3
        lbra     ZERROR

*-------------------------------------------------------------------------------
* 2-OPS
*-------------------------------------------------------------------------------

ZEQUAL: dec     ARGCNT,u
        bne     DOEQ
        lda     #9
        lbra     ZERROR
DOEQ:   ldd     ARG1,u
        cmpd    ARG2,u
        beq     EQOK
        dec     ARGCNT,u
        beq     EQBAD
        cmpd    ARG3,u
        beq     EQOK
        dec     ARGCNT,u
        beq     EQBAD
        cmpd    ARG4,u
        beq     EQOK
EQBAD:  lbra     PREDF
EQOK:   lbra     PREDS

ZLESS:  ldd     ARG1,u
        std     TEMP,u
        ldd     ARG2,u
        std     VAL,u
        bra     CEXIT

ZGRTR:  ldd     ARG1,u
        std     VAL,u
        ldd     ARG2,u
        std     TEMP,u
        bra     CEXIT

ZDLESS: lbsr     ZDEC
        ldd     ARG2,u
        std     VAL,u
        bra     CEXIT

ZIGRTR: lbsr     ZINC
        ldd     TEMP,u
        std     VAL,u
        ldd     ARG2,u
        std     TEMP,u

CEXIT:  bsr     SCOMP
        blo     POK
PBAD:   lbra     PREDF

SCOMP:  lda     VAL,u
        eora    TEMP,u
        bpl     SCMP
        lda     VAL,u
        cmpa    TEMP,u
        rts
SCMP:   ldd     TEMP,u
        cmpd    VAL,u
        rts

ZIN:    lda     ARG1+1,u
        lbsr     OBJLOC
        ldx     TEMP,u
        lda     ARG2+1,u
        cmpa    4,x
        bne     PBAD
POK:    lbra     PREDS

ZBTST:  ldd     ARG2,u
        anda    ARG1,u
        andb    ARG1+1,u
        cmpd    ARG2,u
        beq     POK
        bra     PBAD

ZBOR:   ldd     ARG1,u
        ora     ARG2,u
        orb     ARG2+1,u
ZB0:    std     TEMP,u
        lbra     PUTVAL

ZBAND:  ldd     ARG1,u
        anda    ARG2,u
        andb    ARG2+1,u
        bra     ZB0

ZFSETP: lbsr     FLAGSU
        ldd     VAL,u
        anda    MASK,u
        sta     VAL,u
        andb    MASK+1,u
        orb     VAL,u
        bne     POK
        bra     PBAD

ZFSET:  lbsr     FLAGSU
        ldx     TEMP,u
        ldd     VAL,u
        ora     MASK,u
        orb     MASK+1,u
        std     ,x
        rts

ZFCLR:  lbsr     FLAGSU
        ldx     TEMP,u
        ldd     MASK,u
        coma
        comb
        anda    VAL,u
        andb    VAL+1,u
        std     ,x
        rts

ZSET:   ldd     ARG2,u
        std     TEMP,u
        lda     ARG1+1,u
        lbra     VARPUT

ZMOVE:  lbsr     ZREMOV
        lda     ARG1+1,u
        lbsr     OBJLOC
        ldx     TEMP,u
        pshs    x
        lda     ARG2+1,u
        sta     4,x
        lbsr     OBJLOC
        ldx     TEMP,u
        lda     6,x
        sta     VAL,u
        lda     ARG1+1,u
        sta     6,x
        puls    x
        lda     VAL,u
        beq     ZMVEX
        sta     5,x
ZMVEX:  rts

ZGET:   asl     ARG2+1,u
        rol     ARG2,u
        ldd     ARG2,u
        addd    ARG1,u
        std     TEMP,u
        lbsr     SETWRD_MPC
        lbsr     GETWRD
        lbra     PUTVAL

ZGETB:  ldd     ARG1,u
        addd    ARG2,u
        std     TEMP,u
        lbsr     SETWRD_MPC
        lbsr     GETBYT
        sta     TEMP+1,u
        clr     TEMP,u
        lbra     PUTVAL

ZGETP:  lbsr     PROPB
GETP1:  lbsr     PROPN
        cmpa    ARG2+1,u
        beq     GETP2
        blo     GETP3
        lbsr     PROPNX
        bra     GETP1

GETP3:  ldx     zcode_ptr,u
        ldd     ZOBJEC,x
        addd    zcode_ptr,u
        tfr     d,x
        ldb     ARG2+1,u
        decb
        aslb
        ldd     b,x
        bra     ETPEX

GETP2:  lbsr     PROPL
        leax    1,x             * point past header to data
        tsta
        beq     GETP2A
        cmpa    #1
        beq     GETP2B
        lda     #7
        lbra     ZERROR
GETP2B: ldd     ,x
        bra     ETPEX
GETP2A: ldb     ,x
        clra
ETPEX:  std     TEMP,u
        lbra     PUTVAL

RET0:   clra
        clrb
        std     TEMP,u
        lbra     PUTVAL

ZGETPT: lbsr     PROPB
GETPT1: lbsr     PROPN
        cmpa    ARG2+1,u
        beq     GETPT2
        lblo    RET0
        lbsr     PROPNX
        bra     GETPT1
GETPT2: leax    1,x             * point to property data
        tfr     x,d             * D = absolute address
        ldx     zcode_ptr,u
        pshs    x
        subd    ,s++            * D = relative address
        std     TEMP,u
        lbra     PUTVAL

ZNEXTP: lbsr     PROPB
        lda     ARG2+1,u
        beq     NXTP2
NXTP1:  lbsr     PROPN
        cmpa    ARG2+1,u
        beq     NXTP3
        lbcs    RET0
        lbsr     PROPNX
        bra     NXTP1
NXTP3:  lbsr     PROPNX
NXTP2:  lbsr     PROPN
        lbra     PUTBYT

ZADD:   ldd     ARG1,u
        addd    ARG2,u
MATH:   std     TEMP,u
        lbra     PUTVAL

ZSUB:   ldd     ARG1,u
        subd    ARG2,u
        bra     MATH

ZMUL:   ldx     #17             * INIT LOOP INDEX
        clra                    * CLEAR THE
        clrb                    * CARRY
        std     MTEMP,u         * AND TEMP REGISTER

ZMLOOP: ror     MTEMP,u
        ror     MTEMP+1,u
        ror     ARG2,u          * SHIFT A BIT
        ror     ARG2+1,u        * INTO POSITION
        bcc     ZMNEXT          * NO ADDITION IF BIT CLEAR

        ldd     ARG1,u
        addd    MTEMP,u
        std     MTEMP,u

ZMNEXT: leax    -1,x            * ALL BITS EXAMINED?
        bne     ZMLOOP          * NO, KEEP SHIFTING

        ldd     ARG2,u          * ELSE GRAB PRODUCT
        bra     MATH            * AND RETURN

ZDIV:   bsr     DVINIT
        lbra     PUTVAL

ZMOD:   bsr     DVINIT
        ldd     VAL,u
        bra     MATH

DVINIT: ldd     ARG1,u
        std     TEMP,u
        ldd     ARG2,u
        std     VAL,u

DIVIDE: lda     TEMP,u
        sta     SREM,u
        eora    VAL,u
        sta     SQUOT,u

        tst     TEMP,u
        bpl     TABS
        bsr     ABTEMP

TABS:   tst     VAL,u
        bpl     DOUDIV
        bsr     ABSVAL

DOUDIV: bsr     UDIV

        tst     SQUOT,u
        bpl     RFLIP
        bsr     ABTEMP

RFLIP:  tst     SREM,u
        bpl     DIVEX

ABSVAL: clra
        clrb
        subd    VAL,u
        std     VAL,u

DIVEX:  rts

ABTEMP: clra
        clrb
        subd    TEMP,u
        std     TEMP,u
        rts

UDIV:   ldd     VAL,u
        beq     DIVERR          * CAN'T DIVIDE BY ZERO!

        ldx     #16             * INIT LOOP INDEX
        clra
        clrb
        std     MTEMP,u

UDLOOP: rol     TEMP+1,u
        rol     TEMP,u
        rol     MTEMP+1,u
        rol     MTEMP,u

        ldd     MTEMP,u
        subd    VAL,u
        bcs     UDNEXT
        std     MTEMP,u
        coma
        bra     DECX

UDNEXT: clra

DECX:   leax    -1,x
        bne     UDLOOP

        rol     TEMP+1,u
        rol     TEMP,u
        ldd     MTEMP,u
        std     VAL,u
        rts

DIVERR: lda     #8
        lbra     ZERROR

BADOP2: lda     #4
        lbra     ZERROR

*-------------------------------------------------------------------------------
* X-OPS
*-------------------------------------------------------------------------------

ZCALL:  ldd     ARG1,u
        bne     DOCALL
        lbra     MATH

DOCALL: ldd     OZSTAK,u
        lbsr     PSHDZ
        ldb     ZPCL,u
        clra
        lbsr     PSHDZ
        ldd     ZPCH,u
        lbsr     PSHDZ
        
        * Save current locals
        ldb     CUR_NLOCS,u
        clra
        pshs    d               * save N
        tstb
        beq     ZCALL_S2
        stb     TEMP2,u         * use TEMP2 for loop counter
        leax    LOCALS,u
ZCALL_S1: ldd     ,x++
        pshs    x
        lbsr     PSHDZ
        puls    x
        dec     TEMP2,u
        bne     ZCALL_S1
ZCALL_S2: puls    d               * N
        lbsr     PSHDZ           * push N
        
        * Update PC
        clra
        asl     ARG1+1,u
        rol     ARG1,u
        rola
        sta     ZPCH,u
        ldd     ARG1,u
        std     ZPCM,u
        clr     ZPCFLG,u
        
        * Get new local count
        lbsr     NEXTPC
        sta     CUR_NLOCS,u
        tfr     a,b
        beq     ZCALL_I2
        stb     TEMP2,u         * use TEMP2 for loop counter
        leax    LOCALS,u
ZCALL_I1: lbsr     NEXTPC          * MSB
        pshs    a
        lbsr     NEXTPC          * LSB
        tfr     a,b
        puls    a
        std     ,x++
        dec     TEMP2,u
        bne     ZCALL_I1
ZCALL_I2: lda     CUR_NLOCS,u     * Restore new N
        sta     TEMP2+1,u       * temporary storage for new N

        * Override with passed arguments
        dec     ARGCNT,u        * skip address
        beq     ZCALL_DONE
        tst     TEMP2+1,u
        beq     ZCALL_DONE
        ldd     ARG2,u
        std     LOCALS,u
        dec     TEMP2+1,u
        
        dec     ARGCNT,u
        beq     ZCALL_DONE
        tst     TEMP2+1,u
        beq     ZCALL_DONE
        ldd     ARG3,u
        std     LOCALS+2,u
        dec     TEMP2+1,u
        
        dec     ARGCNT,u
        beq     ZCALL_DONE
        tst     TEMP2+1,u
        beq     ZCALL_DONE
        ldd     ARG4,u
        std     LOCALS+4,u

ZCALL_DONE: sty     OZSTAK,u
        rts

ZPUT:   asl     ARG2+1,u
        rol     ARG2,u
        ldd     ARG2,u
        addd    ARG1,u
        ldx     zcode_ptr,u
        leax    d,x
        ldd     ARG3,u
        std     ,x
        rts

ZPUTB:  ldd     ARG2,u
        addd    ARG1,u
        ldx     zcode_ptr,u
        leax    d,x
        lda     ARG3+1,u
        sta     ,x
        rts

ZPUTP:  lbsr    PROPB
PUTP1:  lbsr    PROPN
        cmpa    ARG2+1,u
        beq     PUTP2
        bhs     PTP

        * *** ERROR #10: BAD PROPERTY NUMBER ***
        lda     #10
        lbra    ZERROR

PTP:    lbsr    PROPNX          * NEXT ITEM
        bra     PUTP1

PUTP2:  lbsr    PROPL
        tsta
        beq     PUTP2A
        cmpa    #1
        beq     PTP1

        * *** ERROR #11: PROPERTY LENGTH ***
        lda     #11
        lbra    ZERROR

PTP1:   ldd     ARG3,u
        std     1,x
        rts

PUTP2A: lda     ARG3+1,u
        sta     1,x
        rts

ZREAD:  lbsr     ZUSL            * Update status line first

        lbsr     INPUT           * Read string into ARG1 buffer. A = length
        sta     MASK+1,u        * Save length in low byte
        clr     MASK,u          * Clear high byte for LDD MASK,u in ZLEX

        * Check if parse table (ARG2) is provided
        ldd     ARG2,u
        beq     zr_done

        * Call Lexical Analyzer
        lbsr     ZLEX
        
zr_done:
        rts

ZPRC:   lda     ARG1+1,u
        lbra     MYCHR

ZPRN:   ldd     ARG1,u
        std     TEMP,u

NUMBER: ldd     TEMP,u
        bpl     DIGCNT
        lda     #$2D            * '-'
        lbsr     MYCHR
        lbsr     ABTEMP

DIGCNT: clr     MASK,u
        clr     MASK+1,u
DGC:    ldd     TEMP,u
        beq     PRNTN3
        ldd     #10
        std     VAL,u
        lbsr     UDIV
        lda     VAL+1,u
        pshs    a
        inc     MASK+1,u
        bra     DGC

PRNTN3: lda     MASK+1,u
        beq     PZERO
PRNTN4: puls    a
        adda    #$30            * '0'
        lbsr     MYCHR
        dec     MASK+1,u
        bne     PRNTN4
        rts

PZERO:  lda     #$30            * '0'
        lbra     MYCHR

ZRAND:  ldd     ARG1,u
        std     VAL,u
        ldd     RAND1,u
        addd    #$AA55
        sta     RAND2,u
        stb     RAND1,u
        anda    #%01111111
        std     TEMP,u
        lbsr     DIVIDE
        ldd     VAL,u
        addd    #1
        lbra     MATH

ZPUSH:  ldd     ARG1,u
        lbra     PSHDZ

ZPOP:   lbsr     POPSTK
        lda     ARG1+1,u
        lbra     VARPUT

ZSPLIT: rts
ZSCRN:  rts

*-------------------------------------------------------------------------------
* Error Output
*-------------------------------------------------------------------------------
ZERROR: pshs    a,y
        leax    err_pre,pcr
        ldy     #err_pre_len
        lda     #1
        os9     I$WritLn
        
        puls    a,y
        pshs    a,y
        sta     TEMP+1,u
        clr     TEMP,u
        lbsr     NUMBER          * Print the error code
        
        lda     #1
        leax    err_cr,pcr
        ldy     #1
        os9     I$Write
        
        puls    a,y
        clrb                    * Exit status 0
        os9     F$Exit

err_pre fcc     /Interpreter Error #/
err_pre_len equ *-err_pre
err_cr  fcb     $0d

*-------------------------------------------------------------------------------
* VERNUM: Print interpreter version code
*-------------------------------------------------------------------------------
VERNUM: pshs    a,x,y
        leax    vcode_msg,pcr
        ldy     #vcode_len
        lda     #1              * stdout
        os9     I$WritLn
        puls    a,x,y,pc

vcode_msg fcc     /infocom VERSION A/
          fcb     $0d
vcode_len equ     *-vcode_msg

