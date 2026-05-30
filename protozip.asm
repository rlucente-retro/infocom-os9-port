*******************************************************************************
* Prototype NitrOS-9 ProtoZIP (Stream-based Paged Output)
*******************************************************************************

        nam     ProtoZIP
        ttl     NitrOS-9 ProtoZIP Prototype

*-------------------------------------------------------------------------------
* lwasm Pragmas for OS-9
*-------------------------------------------------------------------------------
        pragma  cescapes        * Enable C-style escape sequences

        use     defsfile

tylg    set     Prgrm+Objct
atrv    set     ReEnt+rev
rev     set     $00
edition set     1
* page size is always 256 bytes
minpgs  set     8
maxpgs  set     160
REVON   set     $1f20
REVOFF  set     $1f21

*-------------------------------------------------------------------------------
* Data Area Definitions (Relative to U)
*-------------------------------------------------------------------------------
                org     0
cur_cols        rmb     1       * Current terminal columns
cur_rows        rmb     1       * Current terminal rows
cur_x           rmb     1       * Current cursor X position (0 to cols-1)
cur_y           rmb     1       * Current cursor Y position (1 to rows-1)
page_lines      rmb     1       * Lines printed since last [MORE] prompt
was_cr          rmb     1       * State for CRLF detection (1 if last char was CR)
display_codes   rmb     3       * Transient buffer for terminal control escape sequences
dev_opts        rmb     32      * Buffer for I$GetStt/I$SetStt terminal options
path_num        rmb     1       * Path number to the open file
buffer_start    rmb     2       * address of a contiguous set of 256 byte buffers
buffer_size     rmb     2       * total size of buffer in bytes
prtinv_vec      rmb     2       * vector to subroutine to print inverse characters
scroll_vec      rmb     2       * vector to subroutine to scroll content area
static_size     equ     1024    * Total data area allocation (stack grows down from here)

*-------------------------------------------------------------------------------
* Module Header
*-------------------------------------------------------------------------------
        mod     eom,name,tylg,atrv,MainEntryPoint,static_size  

name    fcs     /protozip/

*-------------------------------------------------------------------------------
* Constant Data
*-------------------------------------------------------------------------------
term_name:
        fcs     /TERM/
err_msg fcc     /The TERM device descriptor is   /
        fcc     /not configured for reverse      /
        fcc     /video. Refer to VDG_T1=0 in the /
        fcc     /NitrOS-9 Level 1 build./
        fcb     $0d
err_len equ     *-err_msg

*-------------------------------------------------------------------------------
* Main Entry Point
*-------------------------------------------------------------------------------
MainEntryPoint:
        setdp   0               * NitrOS-9 sets DP to the high byte of U (data area)

        * Set signal trap to handle interrupts (like Ctrl-C) immediately.
        pshs    x
        leax    SignalHandler,pcr
        os9     F$Icpt
        
        * Set default routine for L2 inverse characters
        leax    L2PrintInv,pcr
        stx     prtinv_vec,u
        * Set default routine for L2 scrolling
        leax    L2Scroll,pcr
        stx     scroll_vec,u
        puls    x               

        * Open story file (x already points to required pathlist)
        lda     #READ.          
        os9     I$Open          
        lbcs    ExitProgram     * bail if error
        sta     path_num,u      

        * Determine screen resolution
        lbsr    ParseOptRes     * Try to get resolution from arguments
        bcc     Check32x16      * If carry clear, resolution was parsed

        * No arguments: Query the terminal driver for screen size
        lda     #1              * Path 1 (stdout)
        ldb     #SS.ScSiz       * Service request: Get Screen Size
        os9     I$GetStt
        bcc     SetDimensions   * If query success, process results
        
        * Both failed: Default to standard 32x16 resolution
        ldd     #32*256+16      
        std     cur_cols,u      
        bra     Check32x16

SetDimensions:
        * Extract Cols (X) and Rows (Y) from status registers
        sty     cur_cols,u      
        tfr     x,d
        stb     cur_cols,u      

Check32x16:
        * If resolution is 32x16, check TERM for reverse video
        ldd     cur_cols,u
        cmpd    #32*256+16
        bne     SafetyCheck

        pshs    u,x             * Save registers
        leax    L1PrintInv,pcr  * set inv vec to L1 print routine
        stx     prtinv_vec,u
        leax    L1Scroll,pcr    * set scroll vec to L1 scroll routine
        stx     scroll_vec,u

        lda     #Devic+Objct
        leax    term_name,pcr
        os9     F$Link
        bcc     link_ok
        puls    u,x             * Link failed cleanup
        lbra    ExitProgram
link_ok:
        lda     $26,u           * Check reverse video byte
        pshs    a
        os9     F$Unlink
        puls    a,u,x           * Restore registers
        cmpa    #2              * $02 = reverse video
        beq     SafetyCheck

        * Not reverse video: show error and exit
        leax    err_msg,pcr
        ldy     #err_len
        lda     #1
        os9     I$WritLn
        lbra     ExitCleanly

SafetyCheck:
        * Safety Check: Ensure dimensions are reasonable
        lda     cur_rows,u
        cmpa    #4
        blo     ExitProgram
        lda     cur_cols,u
        cmpa    #10
        blo     ExitProgram

AllocateBuffers:
        * first, request minimum space for file buffers
        ldd     #256*minpgs+static_size
        os9     F$Mem
        lbcs    ExitProgram
        lbsr    SaveBufferParms

        * iteratively ask for more memory until error
        lda     #minpgs+1       * num pages to request on stack
        pshs    a

AllocMoreMem:
        lda     ,s
        cmpa    #maxpgs         * if greater than max pages, bail
        bhi     NoMoreMem
        
        clrb
        addd    #static_size    * d = requested memory size

        os9     F$Mem
        bcs     NoMoreMem       * if allocation fails, bail

        lbsr    SaveBufferParms * save successful allocation
        inc     ,s              * increase num pages to request
        bra     AllocMoreMem

NoMoreMem:
        leas    1,s             * clean up stack

        * Initialize application state
        lbsr    InitializePage  
        ldd     #$0001          * Col 0, Row 1
        std     cur_x,u         
        clr     page_lines,u
        clr     was_cr,u

        * Explicitly move cursor to content area
        lbsr    MoveCursor

ReadFileLoop:
        * Read a chunk from the file
        clrb
        lda     path_num,u
        ldx     buffer_start,u
        ldy     buffer_size,u     
        os9     I$Read
        bcs     CheckEOF        
        cmpy    #0
        beq     CheckEOF        
        
        ldx     buffer_start,u      
ProcessChunkLoop:
        lda     ,x+             
        lbsr    OutputCharacter 
        leay    -1,y            
        cmpy    #0
        bne     ProcessChunkLoop
        bra     ReadFileLoop

CheckEOF:
        pshs    b               
        lda     path_num,u
        os9     I$Close
        puls    b               
        cmpb    #E$EOF          
        bne     ExitProgram
ExitCleanly:
        clrb
ExitProgram:
        os9     F$Exit

*-------------------------------------------------------------------------------
* SaveBufferParms: save the file buffer start and size
* Input: D = size in bytes of buffer, Y = top of data area, U = data area
*-------------------------------------------------------------------------------
SaveBufferParms:
        subd    #static_size
        std     buffer_size,u
        coma                    * Negate D (buffer size)
        comb
        addd    #1
        leax    d,y
        stx     buffer_start,u  * x = y (upper bound) - buffer_size
        rts

*-------------------------------------------------------------------------------
* SignalHandler: Intercept routine for system signals (like Ctrl-C)
* Input: B = Signal Code, U = Data area pointer
*-------------------------------------------------------------------------------
SignalHandler:
        clrb                    * Clear B for successful exit status
        os9     F$Exit

*-------------------------------------------------------------------------------
* OutputCharacter: Main logic for character display with wrapping and paging
* Input: A = character
*-------------------------------------------------------------------------------
OutputCharacter:
        pshs    a,b,x,y
        
        * 1. Detect Regular Characters (range $20 to $FF)
        cmpa    #$20
        bhs     pc_reg
        
        * 2. Detect Special Characters
        cmpa    #$09            * Tab
        beq     pc_tab
        cmpa    #$0A            * LF
        beq     pc_lf
        cmpa    #$0D            * CR
        beq     pc_cr
        bra     pc_done         * Ignore other control codes
        
pc_reg:
        * Early Wrap Check
        ldb     cur_x,u
        cmpb    cur_cols,u
        blo     pc_reg_in
        lbsr    HandleWrapAndNewline
pc_reg_in:
        clr     was_cr,u        
        lbsr    WriteStdoutChar 
        inc     cur_x,u
        puls    a,b,x,y,pc

pc_tab:
        clr     was_cr,u
        lda     #$20            * Expand Tab to spaces
pc_t_lp:
        ldb     cur_x,u
        cmpb    cur_cols,u
        blo     pc_t_reg
        lbsr    HandleWrapAndNewline
pc_t_reg:
        lbsr    WriteStdoutChar
        inc     cur_x,u
        ldb     cur_x,u
        andb    #$07            * Tab stops every 8 columns
        bne     pc_t_lp         
        puls    a,b,x,y,pc

pc_cr:
        lda     #1
        sta     was_cr,u        
        lbsr    HandleWrapAndNewline
        puls    a,b,x,y,pc

pc_lf:
        tst     was_cr,u        * Optimized: check for zero/non-zero without CMP
        bne     pc_lf_skip      * Ignore LF if part of CRLF
        lbsr    HandleWrapAndNewline
pc_lf_skip:
        clr     was_cr,u        
        puls    a,b,x,y,pc

pc_done:
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
        cmpa    ,s+             * Compare page_lines (A) to limit (B)
        blo     nh_no_paging
        
        lbsr    DisplayMorePrompt
        clr     page_lines,u
        
nh_no_paging:
        * 2. Check for Scrolling
        lda     cur_y,u
        ldb     cur_rows,u
        subb    #2              
        pshs    b
        cmpa    ,s+             * Compare cur_y (A) to limit (B)
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
DisplayMorePrompt:
        pshs    a,b,x,y
        ldd     cur_cols,u
        decb                    * Row rows-1
        clra                    * Col 0
        lbsr    MoveCursorToXY
        
        leax    more_msg,pcr
        lda     ,x+             * Get '['
        lbsr    WriteStdoutChar
        ldy     #4              * 'more'
        jsr     [prtinv_vec,u]  * X points to 'm', Y=4. Inside: X is incremented to ']'
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
        decb                    * 8-bit countdown
        bne     dm_cl
        
        * Restore cursor to the content area
        lbsr    MoveCursor
        clr     cur_x,u
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
        clr     PD.EKO,x        * Temporarily disable terminal echo (was lda #0/sta)
        lda     #0
        ldb     #SS.Opt         
        os9     I$SetStt
wk_read:
        clra                    * Path 0 (stdin)
        leax    display_codes,u * Read into transient buffer
        ldy     #1              
        os9     I$Read          * Blocking read for 1 byte
        
        * Restore original terminal echo settings
        lda     #0
        ldb     #SS.Opt
        leax    dev_opts,u
        os9     I$GetStt
        bcs     wk_done
        lda     #1
        sta     PD.EKO,x        
        lda     #0
        ldb     #SS.Opt         
        os9     I$SetStt
wk_done:
        puls    a,b,x,y,u,pc

*-------------------------------------------------------------------------------
* InitializePage: Reset the terminal display and data area state
*-------------------------------------------------------------------------------
InitializePage:
        ldd     #0
        std     cur_x,u         * Clear cur_x and cur_y
        lda     #$0C            * Form Feed (Clear Screen)
        lbsr    WriteStdoutChar
        lbra    DrawStatusHeader 

*-------------------------------------------------------------------------------
* MoveCursor: Move terminal cursor to cur_x, cur_y
*-------------------------------------------------------------------------------
MoveCursor:
        ldd     cur_x,u         
MoveCursorToXY:
        pshs    a,b,x,y
        adda    #32             * VDG/Terminal offset
        addb    #32
        std     display_codes+1,u
        lda     #$02            * Escape sequence header
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
        pshs    a,x,y           * Save char and caller's X, Y
        lda     #1              * Path 1 (stdout)
        tfr     s,x             * X points to A on stack
        ldy     #1              * length 1
        os9     I$Write
        puls    a,x,y,pc        * Restore A and return

*-------------------------------------------------------------------------------
* WriteStdoutString: Output a raw string to Path 1 (stdout)
*-------------------------------------------------------------------------------
WriteStdoutString:  
        pshs    a,x,y
        lda     #1              * Path 1 (stdout)
        os9     I$Write
        puls    a,x,y,pc        

*-------------------------------------------------------------------------------
* ParseOptRes: Parse command line for resolution strings (e.g., "80x30")
*-------------------------------------------------------------------------------
ParseOptRes:
        lda     ,x+             
        cmpa    #$0D            
        beq     p_e             
        leax    -1,x            
        pshs    x               
        leay    known_resolutions,pcr    
outer:  ldx     ,s              
        clrb                    
pr:     lda     ,x+             
        cmpa    b,y             
        beq     match           
        cmpa    #'X             
        bne     fail            
        lda     b,y              
        cmpa    #'x             
        bne     fail            
match:  incb                    
        cmpb    #6              
        bne     pr              
        
        ldd     6,y             
        std     cur_cols,u      
        andcc   #$FE            * Success
        puls    x,pc            

fail:   leay    8,y             
        tst     ,y              
        bne     outer           
        puls    x               
p_e:    orcc    #$01            * Not found
        rts

*-------------------------------------------------------------------------------
* Resolution Table
*-------------------------------------------------------------------------------
known_resolutions:
        fcc     '32x16'
        fcb     $0d
        fdb     32*256+16       
        fcc     '40x24'
        fcb     $0d
        fdb     40*256+24
        fcc     '40x30'
        fcb     $0d
        fdb     40*256+30
        fcc     '80x24'
        fcb     $0d
        fdb     80*246+24
        fcc     '80x30'
        fcb     $0d
        fdb     80*256+30
        fcb     0               

*-------------------------------------------------------------------------------
* DrawStatusHeader: Draw the static status line at Row 0
*-------------------------------------------------------------------------------
DrawStatusHeader:
        pshs    a,b,x,y
        ldd     #0              * Col 0, Row 0
        lbsr    MoveCursorToXY
        leax    header_msg,pcr       
        ldy     #header_len
        jsr     [prtinv_vec,u]
        ldb     cur_cols,u
        subb    #header_len          
        ble     dh_d            
        clra
        tfr     d,y
        leax    spaces_msg,pcr
        jsr     [prtinv_vec,u]
dh_d:   puls    a,b,x,y,pc

header_msg fcc     /protozip prototype/
header_len equ     *-header_msg
more_msg   fcc     /[more]/
           fcb     0
more_len   equ     *-more_msg-1
spaces_msg fcc     /                                                                                /

*-------------------------------------------------------------------------------
* L1Scroll: Level 1 scroll content area (LF at bottom + header redraw)
*-------------------------------------------------------------------------------
L1Scroll:
        ldd     cur_cols,u
        decb                    * B = Row rows-1
        clra                    * A = Col 0
        lbsr    MoveCursorToXY
        lda     #$0A            * Line Feed triggers scroll
        lbsr    WriteStdoutChar
        lbsr    DrawStatusHeader 
        rts

*-------------------------------------------------------------------------------
* L2Scroll: Level 2 scroll content area (Delete line at Row 1)
*-------------------------------------------------------------------------------
L2Scroll:
        ldd     #$0001          * Col 0, Row 1
        lbsr    MoveCursorToXY
        lda     #$1F            * Escape for screen functions
        sta     display_codes,u
        lda     #$31            * Delete Line code
        sta     display_codes+1,u
        lda     #1              * Path 1
        leax    display_codes,u
        ldy     #2
        os9     I$Write
        rts

*-------------------------------------------------------------------------------
* L1PrintInv: Level 1 print inverse text
*-------------------------------------------------------------------------------
L1PrintInv:
        pshs    a,y
        cmpy    #0
        beq     l1_done
l1_loop:
        lda     ,x+             * Autoincrement
        cmpa    #'A'
        blo     l1_chk_sp
        cmpa    #'Z'
        bhi     l1_chk_sp
        adda    #$20            * convert all text to lowercase
        bra     l1_print
l1_chk_sp:
        cmpa    #$20
        bne     l1_print
        lda     #$80            * inverted space for L1
l1_print:
        lbsr    WriteStdoutChar
        leay    -1,y            * Use Y for counter to be safe
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
        ldd     #REVON          * use REVON/REVOFF escape sequence
        lbsr    WriteStdoutChar
        tfr     b,a
        lbsr    WriteStdoutChar
l2_loop:
        lda     ,x+             * Autoincrement
        lbsr    WriteStdoutChar
        leay    -1,y            * Use Y for counter (preserves D)
        bne     l2_loop
        ldd     #REVOFF
        lbsr    WriteStdoutChar
        tfr     b,a
        lbsr    WriteStdoutChar
l2_done:
        puls    a,y,pc

eom     equ     *
        emod                    
        end
