*******************************************************************************
* OS9_DISK.ASM - OS-9 Port of Disk Paging I/O
*******************************************************************************

        IFEQ    OS9_DISK_ASM
OS9_DISK_ASM EQU 1

*-------------------------------------------------------------------------------
* GETDSK: Read a 256-byte Z-page from the story file into memory
* Input Context: DBLOCK = Z-page # to read, DBUFF = Absolute destination address
*-------------------------------------------------------------------------------
GETDSK:
        * Register push order: U, Y, X, B, A. Total 8 bytes.
        * Plus 2 bytes for the return address from LBSR.
        * Stack layout at entry: [0,s]=RetAddr, [2,s]=U_orig, [4,s]=Y, [6,s]=X, [8,s]=B, [9,s]=A
        * Wait, PSHS pushes registers in BIT ORDER: PC, U, Y, X, DP, B, A, CC.
        * Higher bits (like PC and U) are at HIGHER addresses.
        * So A is at lowest address (0,s), then B (1,s), then X (2,s), then Y (4,s), then U (6,s).
        pshs    a,b,x,y,u       

        * 1. Calculate 32-bit File Offset (DBLOCK * 256)
        * MSW = [0, DBLOCK_Hi]
        * LSW = [DBLOCK_Lo, 0]
        
        ldb     DBLOCK,u        * B = Hi
        clra                    * A = 0
        tfr     d,x             * X = MSW [0, Hi]
        
        lda     DBLOCK+1,u      * A = Lo
        clrb                    * B = 0
        tfr     d,u             * U = LSW [Lo, 0]
        
        * 2. Perform I$Seek
        * We must preserve our data pointer U.
        pshs    u               * Save LSW offset to stack (2 bytes).
        * Current Stack: [0,s]=LSW, [2,s]=A, [3,s]=B, [4,s]=X, [6,s]=Y, [8,s]=U_orig
        ldu     8,s             * Retrieve U_orig from stack
        lda     path_num,u
        puls    u               * Restore LSW offset for I$Seek
        
        os9     I$Seek          * X:U = Offset. Returns X:U = New Position.
        bcs     disk_err
        
        * 3. Perform I$Read
        ldu     6,s             * Restore U_orig from original pshs
        lda     path_num,u
        ldx     DBUFF,u
        ldy     #256            * Read exactly 1 page (256 bytes)
        os9     I$Read
        bcs     disk_err
        
        puls    a,b,x,y,u,pc

disk_err:
        ldu     6,s             * Ensure U is restored for ZERROR
        lda     #14             * Disk Error
        lbra    ZERROR

        ENDC                    * OS9_DISK_ASM
