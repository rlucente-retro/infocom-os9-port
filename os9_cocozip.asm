*******************************************************************************
* OS9_COCOZIP.ASM - OS-9 Master Module for Z-Machine Interpreter
*******************************************************************************
        use     defsfile
        include os9_eq.asm

*-------------------------------------------------------------------------------
* Module Header
*-------------------------------------------------------------------------------
        mod     eom,name,tylg,atrv,MainEntryPoint,STATIC_SIZE  

name    fcs     /infocom/

*-------------------------------------------------------------------------------
* Main Entry Point
*-------------------------------------------------------------------------------
MainEntryPoint:
        setdp   0               

        * 1. Save data pointer
        pshs    u

        * 2. Initialize Direct Page variables to zero
        * Avoid clearing buffers and stack area.
        ldd     #TotalDataSize
clr_lp: clr     ,u+
        subd    #1
        bne     clr_lp

        * 3. Restore data pointer
        puls    u

        * Initialize STAMP to 1
        lda     #1
        sta     STAMP,u

        * Query initial memory size to find the stack boundary
        ldd     #0
        os9     F$Mem
        std     zcode_offset,u

        * Set zcode_ptr = U + zcode_offset
        tfr     u,d
        addd    zcode_offset,u
        std     zcode_ptr,u

        * 4. Open the story file (X points to pathlist)
        * I$Open natively parses the pathlist and updates X to point PAST the pathlist.
        lda     #Read.
        os9     I$Open
        lbcs    ExitProgram     * Failed to open story file
        sta     path_num,u      * Save path for later use

        * 5. Initialize Terminal Defaults
        ldd     #80*256+24      * Default 80x24
        std     cur_cols,u
        lda     #1
        sta     cur_y,u         * Start at Row 1 (below status line)
        
        * 6. Determine screen resolution - Query the terminal driver
*        lda     #1              * Path 1 (stdout) (A is already 1 on previous load)
        ldb     #SS.ScSiz       * Service request: Get Screen Size
        os9     I$GetStt
        bcs     SetFallbacks    * If query fails, use defaults already set
        
        * Smart driver (Level 2 or special Level 1)
        sty     cur_cols,u      * Y = rows (stb cur_rows)
        tfr     x,d
        stb     cur_cols,u      * X = cols
        
GotResolution:
        lda     cur_cols,u
        cmpa    #32
        beq     SetL1Drivers

        * Use Level 2 escape-sequence drivers by default for Level 2
        leax    L2PrintInv,pcr
        stx     prtinv_vec,u
        leax    L2Scroll,pcr
        stx     scroll_vec,u
        bra     SafetyCheck

SetFallbacks:
        * Assume standard 32x16 VDG hardware if GetStt fails and no args
        ldd     #32*256+16      
        std     cur_cols,u      

SetL1Drivers:
        leax    L1PrintInv,pcr  * Use Level 1 hardware drivers
        stx     prtinv_vec,u
        leax    L1Scroll,pcr    
        stx     scroll_vec,u

        * Reinstate VDG reverse video check
        pshs    u               * Save our data area pointer U
        lda     #Devic+Objct
        leax    term_name,pcr
        os9     F$Link
        bcs     term_link_err   * If no TERM, restore U and use defaults (skip check)
        
        lda     $26,u           * Check VDG type/options byte at offset $26 of linked module
        pshs    a
        os9     F$Unlink        * Unlink descriptor (U still has module entry point)
        puls    a
        puls    u               * Restore our data area pointer U
        cmpa    #2              * $02 = reverse video
        beq     SafetyCheck     * Yes: proceed
        
        * Not reverse video: show error and exit
        leax    err_msg,pcr
        ldy     #err_len
        lda     #1
        os9     I$WritLn
        lbra    ExitCleanly

term_link_err:
        puls    u               * Restore our data area pointer U
        bra     SafetyCheck

SafetyCheck:
        * Safety Check: Ensure dimensions are reasonable
        lda     cur_rows,u
        cmpa    #4
        lblo    ExitProgram
        lda     cur_cols,u
        cmpa    #10
        lblo    ExitProgram

        * Set dynamic max_swap_pages limit (Level 1 vs Level 2)
        lda     cur_cols,u
        cmpa    #32
        beq     set_l1_swap_limit
        lda     #160            * Level 2 cap (160 swapping pages)
        sta     max_swap_pages,u
        bra     AllocateBuffers
set_l1_swap_limit:
        lda     #24             * Level 1 cap (24 swapping pages = 6KB, leaving headroom)
        sta     max_swap_pages,u

AllocateBuffers:
        * Clear the screen physically for the loading screen
        lda     #$0C            * Form Feed
        lbsr    WriteStdoutChar
        
        * Calculate row (Y) = cur_rows / 2
        lda     cur_rows,u
        lsra                    * Divide by 2
        pshs    a
        
        * Calculate col (X) = (cur_cols - 24) / 2
        lda     cur_cols,u
        cmpa    #24
        blo     col_zero
        suba    #24
        lsra                    * Divide by 2
        bra     got_col
col_zero:
        clra                    * Default to col 0 if screen is too narrow
got_col:
        puls    b               * B = Row
        lbsr    MoveCursorToXY  * Move to calculated position
        
        * Print loading message
        leax    loading_msg,pcr
        ldy     #loading_len
        lda     #1              * stdout
        os9     I$Write

        * Request space for static variables + 1 header page
        ldd     zcode_offset,u
        addd    #256
        lbsr    GrowMemory
        lbcs    ExitProgram     * Fatal: not enough memory for header

        * The dynamic data area starts at U + zcode_offset.
        tfr     u,d
        addd    zcode_offset,u
        std     zcode_ptr,u     * Set pointer for header/Z-code

RESTART_GAME:
        * Reset Z-stack pointer (Y hardware register)
        leay    ZSTACK,u
        sty     zstack_limit,u
        leay    1024,y          * Point to top of 512-word stack
        sty     zsp_top,u
        sty     OZSTAK,u
        clr     CUR_NLOCS,u

        * 7. Seek to start of story file
        pshs    u               * Save Data Area Pointer
        lda     path_num,u
        ldx     #0              * Offset MSW
        ldu     #0              * Offset LSW
        os9     I$Seek
        puls    u               * Restore Data Area Pointer
        lbcs    ExitProgram

        * 8. Read first 256 bytes to get header
        lda     path_num,u
        ldx     zcode_ptr,u
        pshs    y               * Protect Z-stack pointer Y
        ldy     #256
        os9     I$Read
        puls    y               * Restore Y immediately
        lbcs    ExitProgram
        
        * 9. Extract Game Data and determine preload size
        ldx     zcode_ptr,u
        lda     ZENDLD,x        * High-memory boundary (MSB)
        inca                    * Number of pages to read
        sta     ZPURE,u
        
        * 10. Dynamically expand memory to fit preload + swapping space
        * Start by requesting ZPURE + 16 swapping pages.
        * If that fails, try ZPURE + 8 swapping pages as minimum.
        * If even ZPURE + 8 fails, exit.
        * Otherwise, grow allocation page-by-page up to ZPURE + 160 pages.
        ldb     ZPURE,u         * B = preload pages
        addb    #16             * Add 16 pages for swapping
        stb     TEMP2+1,u       * Save target page count in TEMP2+1
        
        tfr     b,a
        clrb                    * D = dynamic size in bytes
        addd    zcode_offset,u  * D = total desired size
        pshs    y               * Protect Z-stack pointer!
        lbsr    GrowMemory
        puls    y
        bcc     GotInitialMem   * Succeeded with 16 pages!
        
        * Succeeded with 16 failed: try minimum 8 pages
        ldb     ZPURE,u
        addb    #8
        stb     TEMP2+1,u
        
        tfr     b,a
        clrb
        addd    zcode_offset,u
        pshs    y
        lbsr    GrowMemory
        puls    y
        lbcs    ExitProgram     * Fatal: not even minimum memory available
        
GotInitialMem:
        * D contains the current total memory limit returned by F$Mem.
        * Now try to expand page-by-page up to ZPURE + 160 swapping pages (or max 160 swapping pages total).
GrowMemLoop:
        ldb     TEMP2+1,u
        cmpb    #160            * Already at maximum?
        bhs     MemGrowthDone
        ldb     TEMP2+1,u
        subb    ZPURE,u
        cmpb    max_swap_pages,u * Maximum swapping pages limit?
        bhs     MemGrowthDone
        
        inc     TEMP2+1,u       * Request 1 more page
        ldb     TEMP2+1,u
        tfr     b,a
        clrb
        addd    zcode_offset,u  * D = desired size
        pshs    y
        lbsr    GrowMemory
        puls    y
        bcs     MemGrowthFail   * Allocation failed: revert to previous count
        bra     GrowMemLoop
        
MemGrowthFail:
        dec     TEMP2+1,u       * Revert to last successful count
        ldb     TEMP2+1,u
        tfr     b,a
        clrb
        addd    zcode_offset,u  * D = total size in bytes (last successful size)

MemGrowthDone:

        * 11. Set Paging Parameters based on ZPURE and memory returned
        * D contains the new high limit address.
        * Preload starts at U + zcode_offset and is ZPURE * 256 bytes
        * PAGE0 must start AFTER the preload
        pshs    d               * Save TotalSize on stack
        tfr     u,d
        addd    zcode_offset,u  * D = start of preload
        pshs    d
        lda     ZPURE,u
        clrb                    * D = preload size
        addd    ,s++            * D = end of preload (start of buffers)
        sta     PAGE0,u         * Store MSB of swapping space start
        
        * Calculate PMAX: (TotalSize - zcode_offset - PreloadSize) / 256
        puls    d               * Restore TotalSize in D
        subd    zcode_offset,u  * D = Total dynamic size in bytes
        tfr     a,b             * B = Total dynamic pages
        subb    ZPURE,u         * B = Total swapping pages
        cmpb    max_swap_pages,u * Cap at max table/dynamic size
        blo     pmax_ok
        ldb     max_swap_pages,u
pmax_ok:
        stb     PMAX,u
        stb     MASK+1,u        * Total dynamic pages for paging loop

        * 12. Read the rest of the preload
        lda     ZPURE,u
        deca                    * Already read 1 page
        lbeq    init_tables
        
        clrb                    * D = (ZPURE-1) * 256
        pshs    y               * Protect Z-stack pointer Y
        tfr     d,y             * Byte count for I$Read
        lda     path_num,u
        ldx     zcode_ptr,u
        leax    256,x           * Start reading after first page
        os9     I$Read          * Read the rest of preload
        puls    y               * Restore Y immediately
        lbcs    ExitProgram

init_tables:
        * 13. Initialize state from header (which we just finished preloading)
        ldx     zcode_ptr,u
        ldd     ZBEGIN,x        * Initial PC
        std     ZPCM,u
        clr     ZPCH,u          * PC is always in first 64KB (V3)
        clr     ZPCFLG,u        * invalidate cache
        
        ldd     ZGLOBA,x        * Global Table offset
        std     GLOBAL,u
        leax    d,x
        stx     global_ptr,u    * Store absolute pointer
        
        ldx     zcode_ptr,u
        ldd     ZVOCAB,x        * Vocabulary offset
        std     VOCAB,u
        leax    d,x
        stx     vocab_ptr,u     * Store absolute pointer
        
        ldx     zcode_ptr,u
        ldd     ZFWORD,x        * F-Words
        std     FWORDS,u
        
        lda     ZMODE,x         * Get Mode
        ora     #%00001000      * Tandy ID
        sta     ZMODE,x
        anda    #%00000010      * Isolate Time Mode bit
        sta     TIMEFL,u

        * 14. Initialize paging table to empty
        leax    PTABLE,u
        ldd     #$FFFF          * unused marker
        ldb     PMAX,u          * max possible entries
init_pt: std    ,x++
        decb
        bne     init_pt
        stx     TABTOP,u        * save pointer to end of initialized PTABLE
        
        * 15. Clear the screen and position at line 1
        lda     #$0C            * Form Feed
        lbsr    WriteStdoutChar
        lda     #$0A            * Line Feed
        lbsr    WriteStdoutChar
        clr     cur_x,u
        lda     #1
        sta     cur_y,u
        sta     page_lines,u    * Reflected skipped line 0
        
        * Start the Z-machine
        lbra    MLOOP

*-------------------------------------------------------------------------------
* GrowMemory: Expand memory to D bytes if D is larger than current size.
* Input: D = desired size in bytes
* Exit: D = current size in bytes, Carry clear on success, Carry set on error.
*-------------------------------------------------------------------------------
GrowMemory:
        pshs    d,y             * Save desired size and Y
        ldd     #0
        os9     F$Mem           * Query current size
        bcs     gm_err          * If error, exit
        std     TEMP,u          * TEMP = current size
        ldd     ,s              * Retrieve desired size
        cmpd    TEMP,u
        bls     gm_same         * If desired <= current, do nothing
        
        * Desired > current: perform allocation
        os9     F$Mem
        bcs     gm_err
        std     ,s              * Update saved D with new size
        bra     gm_exit
        
gm_same:
        ldd     TEMP,u          * Return current size in D
        std     ,s
        andcc   #$FE            * CMPD may set carry when desired < current
gm_exit:
gm_err:
        puls    d,y,pc

*-------------------------------------------------------------------------------
* Exit Logic and SignalHandler: Standard OS-9 Ctrl-C intercept
*-------------------------------------------------------------------------------
SignalHandler:
ExitCleanly:
        clrb                    * Exit status 0
ExitProgram:
        os9     F$Exit

term_name fcs   /TERM/
err_msg   fcc   /VDG MUST BE IN REVERSE VIDEO MODE/
err_len   equ   *-err_msg
loading_msg fcc /THE STORY IS LOADING .../
loading_len equ *-loading_msg

        include os9_dispatch.asm
        include os9_io.asm
        include os9_disk.asm
        include os9_paging.asm
        include os9_subs.asm
        include os9_objects.asm
        include os9_zstring.asm
        include os9_read.asm
        include os9_screen.asm
        include os9_main.asm
        include os9_ops.asm

        emod
eom     equ     *

        END
