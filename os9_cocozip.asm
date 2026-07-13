*******************************************************************************
* OS9_COCOZIP.ASM - OS-9 Master Module for Z-Machine Interpreter
*******************************************************************************
        use     defsfile
        include OS9_EQ.ASM

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

        * 1. Save parameter pointer
        pshs    x

        * 2. Initialize Direct Page variables to zero
        * Avoid clearing buffers and stack area.
        tfr     u,x
        ldd     #TotalDataSize
clr_lp: clr     ,x+
        subd    #1
        bne     clr_lp

        * 3. Restore parameter pointer
        puls    x

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
        
        * 6. Determine screen resolution (X now points to remaining arguments)
        lbsr    ParseOptRes     * Try to get resolution from arguments
        bcc     GotResolution   * If carry clear, resolution was parsed

        * No resolution on command line: Query the terminal driver
        lda     #1              * Path 1 (stdout)
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
        
        * 15. Clear the screen
        lda     #$0C            * Form Feed / Clear Screen
        lbsr    MYCHR
        
        * Start the Z-machine
        lbra    MLOOP

*-------------------------------------------------------------------------------
* ParseOptRes: Parse command line for resolution strings (e.g., "80x30")
*-------------------------------------------------------------------------------
ParseOptRes:
        lda     ,x+             
        cmpa    #$0D            
        beq     gsp_fail        
        cmpa    #$20            
        beq     ParseOptRes     
        leax    -1,x            
        tfr     x,y             
gsp_lp: lda     ,x+
        cmpa    #$0D            
        beq     gsp_fail        * Not a resolution string (no 'x')
        cmpa    #$20            
        beq     gsp_fail        * Not a resolution string (no 'x')
        cmpa    #'x'            
        bne     gsp_lp
        
        * Found an 'x', parse digits before it
        pshs    x               
        leax    -1,x            
        lda     #0
        sta     ,x              * Terminate first string
        tfr     y,x             
        lbsr    DecToBin        
        stb     cur_cols,u
        puls    x               
        
        * Now parse digits after 'x'
        tfr     x,y             
gsp_lp2: lda     ,x+
        cmpa    #$0D
        beq     gsp_ok2
        cmpa    #$20
        beq     gsp_ok2
        bra     gsp_lp2
gsp_ok2:
        leax    -1,x
        lda     #0
        sta     ,x
        tfr     y,x
        lbsr    DecToBin
        stb     cur_rows,u
        andcc   #%11111110      
        rts

gsp_fail:
        orcc    #$01            
        rts

*-------------------------------------------------------------------------------
* DecToBin: Convert null-terminated decimal string in X to byte in B
*-------------------------------------------------------------------------------
DecToBin:
        clrb                    
dtb_lp: lda     ,x+
        tsta
        beq     dtb_done
        suba    #'0'
        blo     dtb_done
        cmpa    #9
        bhi     dtb_done
        pshs    a
        lda     #10
        mul                     
        addb    ,s+
        bra     dtb_lp
dtb_done:
        rts

*-------------------------------------------------------------------------------
* PrintOS9Error: Print "OS-9 Error #" and the code in B
*-------------------------------------------------------------------------------
PrintOS9Error:
        pshs    a,b,x,y
        tfr     b,a
        clrb
        exg     a,b
        std     TEMP,u          * Save error code
        leax    err_os9,pcr
        ldy     #err_os9_len
        lda     #1
        os9     I$Write
        lbsr    NUMBER          * Print error code in TEMP
        lda     #$0D
        lbsr    WriteStdoutChar
        puls    a,b,x,y,pc

err_os9 fcc /OS-9 Error #/
err_os9_len equ *-err_os9

*-------------------------------------------------------------------------------
* SignalHandler: Standard OS-9 Ctrl-C intercept
*-------------------------------------------------------------------------------
SignalHandler:
        clrb                    * Exit status 0
        os9     F$Exit

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
gm_exit:
        andcc   #$FE            * Clear carry flag (success)
        puls    d,y,pc
gm_err:
        puls    d,y
        orcc    #$01            * Set carry
        rts

*-------------------------------------------------------------------------------
* Exit Logic
*-------------------------------------------------------------------------------
ExitProgram:
        lbsr    PrintOS9Error   * Show why we are exiting
ExitCleanly:
        clrb                    * Exit status 0
        os9     F$Exit

term_name fcs   /TERM/
err_msg   fcc   /VDG MUST BE IN REVERSE VIDEO MODE/
err_len   equ   *-err_msg

        include OS9_DISPATCH.ASM
        include OS9_IO.ASM
        include OS9_DISK.ASM
        include OS9_PAGING.ASM
        include OS9_SUBS.ASM
        include OS9_OBJECTS.ASM
        include OS9_ZSTRING.ASM
        include OS9_READ.ASM
        include OS9_SCREEN.ASM
        include OS9_MAIN.ASM
        include OS9_OPS.ASM

        emod
eom     equ     *

        END
