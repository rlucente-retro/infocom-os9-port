ZCALL:  ldd     ARG1,u
        bne     DOCALL
        lbra     MATH

DOCALL: ldd     OZSTAK,u
        lbsr     PSHDZ
        ldb     ZPCL,u
        lbsr     PSHDZ
        ldd     ZPCH,u
        lbsr     PSHDZ
        
        clra
        asl     ARG1+1,u
        rol     ARG1,u
        rola
        sta     ZPCH,u
        ldd     ARG1,u
        std     ZPCM,u
        clr     ZPCFLG,u
        
        lbsr     NEXTPC
        pshs    a               * Save N on stack
        tfr     a,b
        beq     ZCALL2
        
        leax    LOCALS,u
ZCALL1: ldd     ,x
        pshs    x,b
        lbsr     PSHDZ
        lbsr     NEXTPC
        pshs    a
        lbsr     NEXTPC
        tfr     a,b
        puls    a
        puls    x,b
        std     ,x++
        decb
        bne     ZCALL1

ZCALL2: lda     ,s              * Original N
        sta     TEMP2,u
        
        dec     ARGCNT,u
        beq     ZCALL4
        tst     TEMP2,u
        beq     ZCALL4
        ldd     ARG2,u
        std     LOCALS,u
        dec     TEMP2,u
        
        dec     ARGCNT,u
        beq     ZCALL4
        tst     TEMP2,u
        beq     ZCALL4
        ldd     ARG3,u
        std     LOCALS+2,u
        dec     TEMP2,u
        
        dec     ARGCNT,u
        beq     ZCALL4
        tst     TEMP2,u
        beq     ZCALL4
        ldd     ARG4,u
        std     LOCALS+4,u

ZCALL4: puls    a               * N
        coma
        lbsr     PSHDZ
        sty     OZSTAK,u
        rts
