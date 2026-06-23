*******************************************************************************
* OS9_SCREEN.ASM - OS-9 Port of Status Line and Paging Logic
*******************************************************************************


*-------------------------------------------------------------------------------
* ZCRLF: Handle Carriage Return and [MORE] prompt
*-------------------------------------------------------------------------------
ZCRLF:  lda     #$0D
        lbsr     MYCHR
        rts

*-------------------------------------------------------------------------------
* ZUSL: Update Status Line (Opcode Handler)
*-------------------------------------------------------------------------------
ZUSL:   pshs    cc
        orcc    #$50            * Disable interrupts during USL
        
        * Save interpreter state (nested string decoding) without corrupting Y
        ldd     ZSTWRD,u
        pshs    d
        ldx     cur_x,u         * Save cursor position
        pshs    x
        lda     CHRPNT,u
        ldb     STBYTF,u
        pshs    d

        ldd     CSTEMP,u
        pshs    d
        ldx     MPCM,u
        pshs    x
        lda     MPCH,u
        ldb     BINDEX,u
        pshs    d

        * Initialize status line drawing
        clra
        clrb
        lbsr     MoveCursorToXY  * Move to (0,0)
        
        * Start inverse video
        clra
        clrb
        ldb     cur_cols,u
        pshs    y               * Save Z-stack pointer
        tfr     d,y
        leax    spaces_msg,pcr
        jsr     [prtinv_vec,u]  * Clear line with inverse spaces
        puls    y               * Restore Z-stack pointer
        
        clra
        clrb
        lbsr     MoveCursorToXY  * Back to (0,0)

        * Get Room Name
        lda     #1
        sta     inv_flag,u      * Enable inverse printing
        
        lda     #$10            * Global 0
        lbsr     VARGET
        lda     TEMP+1,u
        lbsr     PRNTDC          * Decodes object description

        tst     TIMEFL,u
        bne     USL_TIME_POS

        * Score/Moves Game Position
        lda     #$11            * Global 1
        lbsr    VARGET          * TEMP,u = Score
        lbsr    GetNumLen       * B = Score length
        pshs    b               * Save score length on stack
        
        lda     #$12            * Global 2
        lbsr    VARGET          * TEMP,u = Moves
        lbsr    GetNumLen       * B = Moves length
        puls    a               * A = Score length
        
        pshs    b
        adda    ,s+             * A = Score len + Moves len
        inca                    * A = Score len + Moves len + 1 (for '/')
        
        pshs    a
        ldb     cur_cols,u
        decb
        subb    ,s+             * B = X (column)
        tfr     b,a             * A = X
        clrb                    * B = 0 (Y)
        lbsr    MoveCursorToXY
        
        * Print Score/Moves
        lda     #$11            * Global 1
        lbsr    VARGET
        lbsr    NUMBER
        
        lda     #$2F            * '/'
        lbsr    MYCHR
        
        lda     #$12            * Global 2
        lbsr    VARGET
        lbsr    NUMBER
        lbra    USL_DONE

USL_TIME_POS:
        lda     #$11            * Global 1
        lbsr    VARGET          * TEMP,u = Hours
        lda     TEMP+1,u
        bne     t_ut1           * 00 is really 24
        lda     #24
t_ut1:  cmpa    #12
        ble     t_ut2
        suba    #12             * Convert to 12-hour time
t_ut2:  sta     TEMP+1,u
        clr     TEMP,u
        lbsr    GetNumLen       * B = Hours length
        tfr     b,a
        adda    #6              * total width = Hours len + 6
        pshs    a
        ldb     cur_cols,u
        decb
        subb    ,s+             * B = X (column)
        tfr     b,a             * A = X
        clrb                    * B = 0 (Y)
        lbsr    MoveCursorToXY
        
        * Now go to print time logic
        lbra    USL_TIME

USL_TIME:
        lda     TEMP+1,u
        bne     ut1             * 00 is really 24
        lda     #24
ut1:    cmpa    #12
        ble     ut2
        suba    #12             * Convert to 12-hour time
        sta     TEMP+1,u
ut2:    lbsr    NUMBER          * Print hours
        lda     #$3A            * ':'
        lbsr    MYCHR
        
        lda     #$12            * Global 2 (minutes)
        lbsr    VARGET
        lda     TEMP+1,u
        cmpa    #10             * Less than 10?
        bhs     ut_m
        lda     #$30            * '0' padding
        lbsr    MYCHR
ut_m:   lbsr    NUMBER          * Print minutes
        
        lda     #$20            * ' '
        lbsr    MYCHR
        lda     #$11            * Global 1 again (hours)
        lbsr    VARGET
        lda     TEMP+1,u
        cmpa    #12             * Past noon?
        bhs     ut_pm
        lda     #$41            * 'A'
        bra     ut_d
ut_pm:  lda     #$50            * 'P'
ut_d:   lbsr    MYCHR
        lda     #$4D            * 'M'
        lbsr    MYCHR
        
USL_DONE:
        clr     inv_flag,u      * Disable inverse printing
        
        * Restore interpreter state without corrupting Y
        puls    d               * Pull MPCH, BINDEX
        sta     MPCH,u
        stb     BINDEX,u
        puls    x               * Pull MPCM
        stx     MPCM,u
        puls    d               * Pull CSTEMP, CSPERM
        std     CSTEMP,u
        
        puls    d               * Pull CHRPNT, STBYTF
        sta     CHRPNT,u
        stb     STBYTF,u
        puls    x               * Pull cur_x
        stx     cur_x,u
        puls    d               * Pull ZSTWRD
        std     ZSTWRD,u
        
        * Return cursor to content area
        lbsr     MoveCursor
        clr     MPCFLG,u
        puls    cc              * Restore Flags
        rts                     * Balanced Return
* Calculate length of 16-bit integer in TEMP,u. Returns length in B.
GetNumLen:
        pshs    a,x
        ldb     #1              * minimum length 1 (for 0)
        tst     TEMP,u          * check sign
        bpl     gnl_pos
        incb                    * for minus sign
        pshs    b               * Save B (length)
        lbsr    ABTEMP          * TEMP = absolute value of TEMP
        puls    b               * Restore B (length)
gnl_pos:
        ldx     TEMP,u
        cmpx    #10
        blo     gnl_done
        incb
        cmpx    #100
        blo     gnl_done
        incb
        cmpx    #1000
        blo     gnl_done
        incb
        cmpx    #10000
        blo     gnl_done
        incb
gnl_done:
        puls    a,x,pc

spaces_msg fcc     /                                                                                /
