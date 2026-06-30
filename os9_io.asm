*******************************************************************************
* OS9_IO.ASM - OS-9 I/O and Terminal Abstraction
*******************************************************************************


*-------------------------------------------------------------------------------
* Terminal Control Codes
*-------------------------------------------------------------------------------
REVON   set     $1f20
REVOFF  set     $1f21

*-------------------------------------------------------------------------------
* MYCAT: Keyboard Input (Replacement for standalone keyboard scan)
* Entry: None
* Exit: A = Character (0 if none ready)
*-------------------------------------------------------------------------------
MYCAT:
        pshs    b,x,y
        lda     #0              * Path 0 (stdin)
        ldb     #SS.Ready       * Check if character ready
        os9     I$GetStt
        bcs     cat_none        * If error or not ready, return 0
        
        lda     #0              * Path 0 (stdin)
        leax    IOCHAR,u        * Use IOCHAR as transient buffer
        ldy     #1
        os9     I$Read          * Read the character
        bcs     cat_none
        
        lda     IOCHAR,u
        puls    b,x,y,pc
cat_none:
        clra
        puls    b,x,y,pc

*-------------------------------------------------------------------------------
* MYCHR: Character Output (Replacement for standalone screen output)
* Entry: A = Character
* Exit: None
*-------------------------------------------------------------------------------
MYCHR:
        tst     inv_flag,u
        bne     mychr_direct_dispatch
        tst     in_input_mode,u
        bne     mychr_direct_dispatch

        * Word buffering logic
        cmpa    #$20            * Space
        beq     mychr_delim
        cmpa    #$09            * Tab
        beq     mychr_delim
        cmpa    #$0D            * CR
        beq     mychr_delim
        cmpa    #$0A            * LF
        beq     mychr_delim

        * Normal character: append to buffer
        pshs    b,x
        ldb     word_len,u
        cmpb    #63             * Buffer full?
        blo     mychr_append
        lbsr    FLUSH_WORD      * Flush first
        ldb     word_len,u      * Reload length (which is 0)
mychr_append:
        leax    word_buf,u
        sta     b,x             * Append character
        inc     word_len,u
        puls    b,x,pc          * Done, return

mychr_delim:
        lbsr    FLUSH_WORD      * Flush current word
        * Fall through to print delimiter directly

mychr_direct_dispatch:
        lbra    mychr_direct

mychr_direct:
        pshs    a,b,x,y
        sta     IOCHAR,u        * Save char in DP variable
        
        * Convert lowercase to uppercase for Level 1 instances
        ldx     scroll_vec,u
        leay    L1Scroll,pcr
        pshs    y
        cmpx    ,s++
        bne     mychr_no_l1_conv
        
        cmpa    #'a'
        blo     mychr_no_l1_conv
        cmpa    #'z'
        bhi     mychr_no_l1_conv
        suba    #$20            * Convert to uppercase
        sta     IOCHAR,u
mychr_no_l1_conv:
        
        * 1. Detect Regular Characters (range $20 to $FF)
        cmpa    #$20
        bhs     chr_reg
        
        * 2. Detect Special Characters
        cmpa    #$08            * Backspace
        beq     chr_bs
        cmpa    #$09            * Tab
        beq     chr_tab
        cmpa    #$0A            * LF
        beq     chr_lf
        cmpa    #$0C            * Form Feed / Clear Screen
        beq     chr_cls
        cmpa    #$0D            * CR
        beq     chr_cr
        lbra    chr_done        * Ignore other control codes
        
chr_reg:
        * Early Wrap Check
        ldb     cur_x,u
        cmpb    cur_cols,u
        blo     chr_reg_in
        lbsr    HandleWrapAndNewline
chr_reg_in:
        clr     was_cr,u        
        lbsr    WriteStdoutChar 
        inc     cur_x,u
        puls    a,b,x,y,pc

chr_tab:
        clr     was_cr,u
        lda     #$20            * Expand Tab to spaces
chr_t_lp:
        ldb     cur_x,u
        cmpb    cur_cols,u
        blo     chr_t_reg
        lbsr    HandleWrapAndNewline
chr_t_reg:
        lbsr    WriteStdoutChar
        inc     cur_x,u
        ldb     cur_x,u
        andb    #$07            * Tab stops every 8 columns
        bne     chr_t_lp         
        puls    a,b,x,y,pc

chr_cr:
        lda     #1
        sta     was_cr,u        
        lbsr    HandleWrapAndNewline
        puls    a,b,x,y,pc

chr_lf:
        tst     was_cr,u        
        bne     chr_lf_skip     * Ignore LF if part of CRLF
        lbsr    HandleWrapAndNewline
chr_lf_skip:
        clr     was_cr,u        
        puls    a,b,x,y,pc

chr_cls:
        clr     cur_x,u
        lda     #1
        sta     cur_y,u
        clr     page_lines,u
        lda     #$0C            * Ensure Form Feed character is written to clear the screen
        lbsr    WriteStdoutChar
        lbsr    MoveCursor
        puls    a,b,x,y,pc

chr_bs:
        ldb     cur_x,u
        bne     chr_bs_sub      * If cur_x > 0, just decrement cur_x
        * If cur_x == 0, wrap back to previous line
        lda     cur_y,u
        cmpa    #1              * Can't go above row 1 (row 0 is status line)
        bls     chr_bs_done
        dec     cur_y,u
        tst     page_lines,u
        beq     chr_bs_no_dec
        dec     page_lines,u
chr_bs_no_dec:
        ldb     cur_cols,u
        decb
        stb     cur_x,u
        lbsr    MoveCursor
        bra     chr_bs_done
chr_bs_sub:
        dec     cur_x,u
        lda     #$08
        lbsr    WriteStdoutChar
chr_bs_done:
        puls    a,b,x,y,pc

chr_done:
        puls    a,b,x,y,pc

*-------------------------------------------------------------------------------
* FLUSH_WORD: Output the buffered word, checking if it fits or needs wrapping
* Entry: None
* Exit: None
*-------------------------------------------------------------------------------
FLUSH_WORD:
        pshs    a,b,x,y
        ldb     word_len,u
        beq     fw_exit         * Empty buffer, done
        
        lda     cur_x,u
        adda    word_len,u      * A = cur_x + word_len
        bcs     fw_wrap         * Overflow: wrap
        cmpa    cur_cols,u
        bls     fw_print        * Fits!
fw_wrap:
        lda     word_len,u
        cmpa    cur_cols,u
        bhi     fw_print        * If word is longer than line, don't wrap (it wouldn't fit anyway)
        
        * Wrap: emit CR
        lda     #$0D
        lbsr    mychr_direct
        
fw_print:
        * Iterate and print buffered characters
        clrb                    * B = loop index
fw_lp:  cmpb    word_len,u
        bhs     fw_done
        leax    word_buf,u
        lda     b,x
        pshs    b
        lbsr    mychr_direct
        puls    b
        incb
        bra     fw_lp
        
fw_done:
        clr     word_len,u      * Reset length
fw_exit:
        puls    a,b,x,y,pc

*-------------------------------------------------------------------------------
* HandleWrapAndNewline: Move cursor to next line, handle paging and scrolling
*-------------------------------------------------------------------------------
HandleWrapAndNewline:
        pshs    a,b,x,y
        clr     cur_x,u
        inc     page_lines,u
        
        * 1. Check for Paging ([MORE] prompt)
        lda     page_lines,u
        ldb     cur_rows,u
        subb    #2              
        pshs    b
        cmpa    ,s+             
        blo     nh_no_paging
        
        bsr     DisplayMorePrompt
        clr     page_lines,u
        
nh_no_paging:
        * 2. Check for Scrolling
        lda     cur_y,u
        ldb     cur_rows,u
        subb    #2              
        pshs    b
        cmpa    ,s+             
        blo     nh_inc
        
        * At Row Limit, trigger terminal scroll
        jsr     [scroll_vec,u]
        bra     nh_sync

nh_inc:
        inc     cur_y,u

nh_sync:
        lbsr    MoveCursor           
        puls    a,b,x,y,pc

*-------------------------------------------------------------------------------
* DisplayMorePrompt: Show [MORE] at the bottom and wait for keypress
*-------------------------------------------------------------------------------
more_msg   fcc     /[more]/
           fcb     0
more_len   equ     *-more_msg-1

DisplayMorePrompt:
        pshs    a,b,x,y
        ldx     cur_x,u         * Save logical cursor position
        pshs    x
        ldd     cur_cols,u
        decb                    * Row rows-1
        clra                    * Col 0
        lbsr    MoveCursorToXY
        
        leax    more_msg,pcr
        lda     ,x+             * Get '['
        lbsr    WriteStdoutChar
        ldy     #4              * 'more'
        jsr     [prtinv_vec,u]  
        lda     ,x              * Get ']'
        lbsr    WriteStdoutChar
        
        lbsr    WaitForKeypress        
        
        * Erase [MORE] by overwriting with spaces
        ldd     cur_cols,u
        decb
        clra
        lbsr    MoveCursorToXY
        ldb     #more_len
        lda     #$20            * Space
dm_cl:  lbsr    WriteStdoutChar
        decb                    
        bne     dm_cl
        
        * Restore cursor to the content area
        puls    x
        stx     cur_x,u         * Restore logical cursor position
        lbsr    MoveCursor
        puls    a,b,x,y,pc

*-------------------------------------------------------------------------------
* WaitForKeypress: Halt execution until a key is pressed on stdin
*-------------------------------------------------------------------------------
WaitForKeypress:
        pshs    a,b,x,y,u
        lda     #0              * Path 0 (stdin)
        ldb     #SS.Opt         * Get terminal options
        leax    dev_opts,u
        os9     I$GetStt        
        bcs     wk_read         
        clr     PD.EKO-PD.OPT,x        
        lda     #0
        ldb     #SS.Opt         
        os9     I$SetStt
wk_read:
        clra                    * Path 0 (stdin)
        leax    IOCHAR,u        * Read into transient buffer
        ldy     #1              
        os9     I$Read          * Blocking read for 1 byte
        
        * Restore original terminal echo settings
        lda     #0
        ldb     #SS.Opt
        leax    dev_opts,u
        os9     I$GetStt
        bcs     wk_done
        lda     #1
        sta     PD.EKO-PD.OPT,x        
        lda     #0
        ldb     #SS.Opt         
        os9     I$SetStt
wk_done:
        puls    a,b,x,y,u,pc

*-------------------------------------------------------------------------------
* MoveCursor: Move terminal cursor to cur_x, cur_y
*-------------------------------------------------------------------------------
MoveCursor:
        ldd     cur_x,u         
MoveCursorToXY:
        std     cur_x,u         * Update logical cursor position
        pshs    a,b,x,y
        adda    #32             
        addb    #32
        std     display_codes+1,u
        lda     #$02            
        sta     display_codes,u
        lda     #1              * Path 1
        leax    display_codes,u
        ldy     #3
        os9     I$Write
        puls    a,b,x,y,pc

*-------------------------------------------------------------------------------
* WriteStdoutChar: Output character in A to Path 1
*-------------------------------------------------------------------------------
WriteStdoutChar: 
        sta     IOCHAR,u        * Save char in DP
        pshs    a,b,x,y         * Protect registers for caller
        tst     cur_y,u
        bne     wsc_normal
        ldb     cur_x,u
        cmpb    #80
        bhs     wsc_normal
        leax    status_buf,u
        abx
        sta     ,x
wsc_normal:
        lda     #1              * Path 1 (stdout)
        leax    IOCHAR,u        * Point to character
        ldy     #1              
        os9     I$Write
        puls    a,b,x,y,pc        

*-------------------------------------------------------------------------------
* L1Scroll: Level 1 scroll content area (LF at bottom + header redraw)
*-------------------------------------------------------------------------------
L1Scroll:
        ldx     cur_x,u
        pshs    x               * Save logical cursor position
        * 1. Scroll screen using LF
        ldd     cur_cols,u
        decb                    * B = Row rows-1
        clra                    * A = Col 0
        lbsr    MoveCursorToXY
        lda     #$0A            
        lbsr    WriteStdoutChar
        
        * 2. Clear the new bottom game line at cur_rows - 2
        ldd     cur_cols,u
        subb    #2              * B = Row rows-2
        clra                    * A = Col 0
        lbsr    MoveCursorToXY
        ldb     cur_cols,u      * count = cur_cols
        lda     #$20            * space character
l1_clr_lp: lbsr    WriteStdoutChar
        decb
        bne     l1_clr_lp
        
        * 3. Redraw dynamic status header from buffer
        pshs    u
        clra
        clrb
        lbsr    MoveCursorToXY  * Move to (0,0)
        leax    status_buf,u
        ldb     cur_cols,u
        clra
        tfr     d,y
        lbsr    L1PrintInv
        puls    u
        puls    x
        stx     cur_x,u         * Restore logical cursor position
        rts

*-------------------------------------------------------------------------------
* L2Scroll: Level 2 scroll content area (Delete line at Row 1)
*-------------------------------------------------------------------------------
L2Scroll:
        ldx     cur_x,u
        pshs    x               * Save cursor position
        ldd     #$0001          
        lbsr    MoveCursorToXY
        lda     #$1F            
        sta     display_codes,u
        lda     #$31            
        sta     display_codes+1,u
        pshs    y
        lda     #1              
        leax    display_codes,u
        ldy     #2
        os9     I$Write
        puls    y
        puls    x
        stx     cur_x,u         * Restore cursor position
        rts

*-------------------------------------------------------------------------------
* L1PrintInv: Level 1 print inverse text
*-------------------------------------------------------------------------------
L1PrintInv:
        pshs    a,y
        cmpy    #0
        beq     l1_done
l1_loop:
        lda     ,x+             
        cmpa    #'A'
        blo     l1_chk_sp
        cmpa    #'Z'
        bhi     l1_chk_sp
        adda    #$20            
        bra     l1_print
l1_chk_sp:
        cmpa    #$20
        bne     l1_print
        lda     #$80            
l1_print:
        lbsr    WriteStdoutChar
        inc     cur_x,u
        leay    -1,y            
        bne     l1_loop
l1_done:
        puls    a,y,pc

*-------------------------------------------------------------------------------
* L2PrintInv: Level 2 print inverse text
*-------------------------------------------------------------------------------
L2PrintInv:
        pshs    a,y
        cmpy    #0
        beq     l2_done
        ldd     #REVON          
        lbsr    WriteStdoutChar
        tfr     b,a
        lbsr    WriteStdoutChar
l2_loop:
        lda     ,x+             
        lbsr    WriteStdoutChar
        inc     cur_x,u
        leay    -1,y            
        bne     l2_loop
        ldd     #REVOFF
        lbsr    WriteStdoutChar
        tfr     b,a
        lbsr    WriteStdoutChar
l2_done:
        puls    a,y,pc

*-------------------------------------------------------------------------------
* INPUT: Read a line of text from the user into ARG1 buffer.
* Exit: A = length of input string.
*-------------------------------------------------------------------------------
INPUT:
        pshs    y               * Save Z-stack pointer
        lbsr    FLUSH_WORD      * Flush any pending printed characters
        lda     #1
        sta     in_input_mode,u * Enable input mode
        * 1. Turn off terminal echo for stdin (Path 0)
        lda     #0
        ldb     #SS.Opt
        leax    dev_opts,u
        os9     I$GetStt
        bcs     inp_loop_start  * Ignore error and proceed
        clr     PD.EKO-PD.OPT,x
        lda     #0
        ldb     #SS.Opt
        os9     I$SetStt

inp_loop_start:
        * 2. Initialize Buffer
        ldx     zcode_ptr,u
        ldd     ARG1,u
        leax    d,x             * X = pointer to text buffer
        ldb     ,x+             * B = Max buffer size (byte 0)
        * We are now pointing at byte 1 (where input starts)
        * Store current length in MTEMP+1 (0) and max in MTEMP
        stb     MTEMP,u
        clr     MTEMP+1,u
        stx     TEMP2,u         * Save buffer pointer

inp_loop:
        * 3. Blocking Read Character
        clra                    * Path 0
        leax    IOCHAR,u        * Read into IOCHAR
        ldy     #1
        os9     I$Read
        bcc     inp_read_ok
        cmpb    #E$EOF          * End of file?
        lbeq    ExitCleanly     * Yes, exit cleanly
        cmpb    #E$HangUp       * Carrier lost?
        lbeq    ExitCleanly     * Yes, exit cleanly
        cmpb    #E$USigP        * Signal pending?
        beq     inp_retry       * Yes, retry
        lbra    ExitCleanly     * Other error: exit cleanly
inp_retry:
        clr     IOCHAR,u
        lbra    inp_loop
inp_read_ok:
        lda     IOCHAR,u
        
        * 4. Process Character
        cmpa    #$08            * Backspace
        beq     inp_bs
        cmpa    #$0D            * CR
        beq     inp_done
        cmpa    #$0A            * LF
        beq     inp_lf
        
        * Regular Character
        ldb     MTEMP+1,u       * Check length
        cmpb    MTEMP,u         * At max?
        bhs     inp_loop        * Yes, ignore new characters
        
        * Convert to lowercase
        cmpa    #'A'
        blo     inp_store
        cmpa    #'Z'
        bhi     inp_store
        adda    #$20            * To lowercase
inp_store:
        ldx     TEMP2,u         * Get buffer pointer
        sta     b,x             * Store in buffer
        inc     MTEMP+1,u       * Increment length
        lbsr    MYCHR           * Echo character manually
        lbra    inp_loop

inp_bs:
        tst     MTEMP+1,u       * Is buffer empty?
        lbeq    inp_loop        * Yes, ignore backspace
        dec     MTEMP+1,u       * Decrement length
        * Visual Backspace: Backspace, Space, Backspace
        lda     #$08
        lbsr    MYCHR
        lda     #$20
        lbsr    MYCHR
        lda     #$08
        lbsr    MYCHR
        lbra    inp_loop

inp_lf:
        tst     MTEMP+1,u       * Is buffer empty?
        bne     inp_done        * No, terminate input
        lbra    inp_loop        * Yes, discard/ignore it

inp_done:
        * Null-terminate the string
        ldx     TEMP2,u
        ldb     MTEMP+1,u
        clr     b,x
        
        * Echo the CR
        lda     #$0D
        lbsr    MYCHR
        
        * 5. Restore terminal echo
        lda     #0
        ldb     #SS.Opt
        leax    dev_opts,u
        os9     I$GetStt
        bcs     inp_exit
        lda     #1
        sta     PD.EKO-PD.OPT,x
        lda     #0
        ldb     #SS.Opt
        os9     I$SetStt

inp_exit:
        clr     in_input_mode,u * Disable input mode
        lda     MTEMP+1,u       * Return length in A
        puls    y,pc            * Restore Z-stack pointer

*-------------------------------------------------------------------------------
* GETFILENAME: Prompt user and read a filename into BUFSAV
* Input: X = Pointer to prompt string, Y = Length of prompt
* Exit: Carry clear = Success (path in BUFSAV, null terminated)
*       Carry set = Error or empty input
*-------------------------------------------------------------------------------
GETFILENAME:
        lbsr    FLUSH_WORD      * Flush any pending characters
        pshs    a,b,x,y
        * 1. Print Prompt character-by-character
gfn_pr_lp:
        cmpy    #0
        beq     gfn_pr_done
        lda     ,x+
        lbsr    MYCHR
        leay    -1,y
        bra     gfn_pr_lp
gfn_pr_done:
        lbsr    FLUSH_WORD      * Flush prompt text to screen
        lda     #1
        sta     in_input_mode,u * Enable input mode

        * 2. Turn off terminal echo for stdin (Path 0)
        lda     #0
        ldb     #SS.Opt
        leax    dev_opts,u
        os9     I$GetStt
        bcs     gfn_read_start  * Ignore error and proceed
        clr     PD.EKO-PD.OPT,x
        lda     #0
        ldb     #SS.Opt
        os9     I$SetStt

gfn_read_start:
        ldb     #0              * B = current length
gfn_read_lp:
        clra                    * Path 0
        leax    IOCHAR,u
        ldy     #1
        os9     I$Read          * Read one character
        bcc     gfn_read_ok
        cmpb    #E$USigP        * Signal pending?
        beq     gfn_retry       * Yes, retry
        bra     gfn_done_err    * No, return error
gfn_retry:
        clr     IOCHAR,u
        bra     gfn_read_lp
gfn_read_ok:
        lda     IOCHAR,u
        
        cmpa    #$08            * Backspace
        beq     gfn_bs
        cmpa    #$0D            * CR
        beq     gfn_done_ok
        cmpa    #$0A            * LF
        beq     gfn_lf
        
        * Regular character
        cmpb    #29             * Max filename length (32 bytes max in BUFSAV)
        bhs     gfn_read_lp
        
        leax    BUFSAV,u
        sta     b,x             * Store character
        incb
        lbsr    MYCHR           * Echo character manually
        bra     gfn_read_lp
        
gfn_lf:
        cmpb    #0              * Is buffer empty?
        bne     gfn_done_ok     * No, terminate filename input
        bra     gfn_read_lp     * Yes, discard/ignore it

gfn_bs:
        cmpb    #0              * Is buffer empty?
        beq     gfn_read_lp
        decb                    * Decrement length
        lda     #$08
        lbsr    MYCHR
        lda     #$20
        lbsr    MYCHR
        lda     #$08
        lbsr    MYCHR
        bra     gfn_read_lp
        
gfn_done_ok:
        * Put CR ($0D) terminator at the end of the filename
        leax    BUFSAV,u
        lda     #$0D
        sta     b,x
        
        * Echo the CR
        lda     #$0D
        lbsr    MYCHR
        
        pshs    b               * Save the filename length
        * Restore terminal echo
        lda     #0
        ldb     #SS.Opt
        leax    dev_opts,u
        os9     I$GetStt
        bcs     gfn_restore_pop
        lda     #1
        sta     PD.EKO-PD.OPT,x
        lda     #0
        ldb     #SS.Opt         
        os9     I$SetStt
gfn_restore_pop:
        puls    b               * Restore the filename length
        
gfn_check_empty:
        tstb                    * Check if empty
        beq     gfn_done_err
        
        clr     in_input_mode,u * Disable input mode
        andcc   #$FE            * Clear carry
        puls    a,b,x,y,pc
        
gfn_done_err:
        * Restore terminal echo
        lda     #0
        ldb     #SS.Opt
        leax    dev_opts,u
        os9     I$GetStt
        bcs     gfn_err_exit
        lda     #1
        sta     PD.EKO-PD.OPT,x
        lda     #0
        ldb     #SS.Opt
        os9     I$SetStt
gfn_err_exit:
        clr     in_input_mode,u * Disable input mode
        orcc    #$01            * Set carry
        puls    a,b,x,y,pc

*-------------------------------------------------------------------------------
* Dummy Handlers for Phase 3
*-------------------------------------------------------------------------------
MYCON:  rts
DIRQSV: rts

*-------------------------------------------------------------------------------
* MYCHR_INV: Output a single character in inverse video
*-------------------------------------------------------------------------------
MYCHR_INV:
        pshs    a
        pshs    x,y
        ldy     #1
        leax    4,s             * Point to saved 'a' on stack
        jsr     [prtinv_vec,u]
        puls    x,y
        puls    a,pc

