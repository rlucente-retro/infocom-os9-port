*******************************************************************************
* OS9_EQ.ASM - OS-9 Data Area and Z-Machine Equates
*******************************************************************************


*-------------------------------------------------------------------------------
* Module Header Constants
*-------------------------------------------------------------------------------
tylg            equ     Prgrm+Objct     * Program module, object code
atrv            equ     ReEnt+rev       * Re-entrant, revision 0
rev             equ     0

*-------------------------------------------------------------------------------
* Z-Code Header Offsets (Constant)
*-------------------------------------------------------------------------------
ZVERS   EQU     0               * VERSION BYTE
ZMODE   EQU     1               * MODE SELECT BYTE
ZID     EQU     2               * GAME ID WORD
ZENDLD  EQU     4               * START OF NON-PRELOADED Z-CODE
ZBEGIN  EQU     6               * EXECUTION ADDRESS
ZVOCAB  EQU     8               * START OF VOCABULARY TABLE
ZOBJEC  EQU     10              * START OF OBJECT TABLE
ZGLOBA  EQU     12              * START OF GLOBAL VARIABLE TABLE
ZPURBT  EQU     14              * START OF "PURE" Z-CODE
ZSCRIP  EQU     16              * FLAG WORD
ZSERIA  EQU     18              * 3-WORD ASCII SERIAL NUMBER
ZFWORD  EQU     24              * START OF FWORDS TABLE
ZLENTH  EQU     26              * LENGTH OF Z-PROGRAM IN WORDS
ZCHKSM  EQU     28              * Z-CODE CHECKSUM WORD

*-------------------------------------------------------------------------------
* Data Area Definitions (Relative to U)
*-------------------------------------------------------------------------------
                org     0

*--- Direct Page Variables (Accessible via setdp 0 / U-relative) ---
OPCODE          rmb     1       * CURRENT OPCODE
ARGCNT          rmb     1       * # ARGUMENTS
ARG1            rmb     2       * ARGUMENT #1 (WORD)
ARG2            rmb     2       * ARGUMENT #2 (WORD)
ARG3            rmb     2       * ARGUMENT #3 (WORD)
ARG4            rmb     2       * ARGUMENT #4 (WORD)

LRU             rmb     1       * (BYTE) LEAST RECENTLY USED PAGE INDEX
ZPURE           rmb     1       * (BYTE) 1ST VIRTUAL PAGE OF PURE Z-CODE
PMAX            rmb     1       * (BYTE) MAXIMUM # SWAPPING PAGES
ZPAGE           rmb     1       * (BYTE) CURRENT SWAPPING PAGE
PAGE0           rmb     1       * (BYTE) 1ST ABS PAGE OF SWAPPING SPACE
TABTOP          rmb     2       * (WORD) ADDRESS OF LAST P-TABLE ENTRY
STAMP           rmb     1       * (BYTE) CURRENT TIMESTAMP
SWAP            rmb     1       * (BYTE) EARLIEST BUFFER

ZPCH            rmb     1       * HIGHEST-ORDER BIT OF PC
ZPCM            rmb     1       * MIDDLE 8 BITS OF PC
ZPCL            rmb     1       * LOWER 8 BITS OF PC
ZPCPNT          rmb     2       * POINTER TO ACTUAL PC PAGE (WORD)
ZPCFLG          rmb     2       * FLAG: "TRUE" IF ZPCPNT VALID

MPCH            rmb     1       * HIGHEST-ORDER BIT OF MEM POINTER
MPCM            rmb     1       * MIDDLE 8 BITS OF MEM POINTER
MPCL            rmb     1       * LOW-ORDER 8 BITS OF MEMORY POINTER
MPCPNT          rmb     2       * ACTUAL POINTER TO MEMORY (WORD)
MPCFLG          rmb     2       * FLAG: "TRUE" IF MPCPNT VALID

GLOBAL          rmb     2       * GLOBAL VARIABLE POINTER (WORD)
VOCAB           rmb     2       * VOCAB TABLE POINTER (WORD)
FWORDS          rmb     2       * FWORDS TABLE POINTER (WORD)

CUR_NLOCS        rmb     1       * NUMBER OF LOCALS IN CURRENT ROUTINE
OZSTAK          rmb     2       * ZSP SAVE REGISTER (FOR ZCALL)

CSTEMP          rmb     1       * SET IF TEMP CHARSET IN EFFECT
CSPERM          rmb     1       * CURRENT PERM CHARSET
STBYTF          rmb     1       * 0=1ST, 1=2ND, 2=3RD, 0=LAST

ZSTWRD          rmb     2       * WORD STORAGE (WORD)
ZSTBUI          rmb     6       * Z-STRING INPUT BUFFER (6 BYTES)
ZSTBUO          rmb     6       * Z-STRING OUTPUT BUFFER (6 BYTES)
RTABP           rmb     1       * RESULT TABLE POINTER
STABP           rmb     1       * SOURCE TABLE POINTER
PZSTFO          rmb     1       * FWORD TABLE BLOCK OFFSET

VAL             rmb     2       * VALUE RETURN REGISTER (WORD)
TEMP            rmb     2       * TEMPORARY REGISTER (WORD)
TEMP2           rmb     2       * ANOTHER TEMPORARY REGISTER (WORD)
MASK            rmb     2       * BIT-MASK REGISTER (WORD)
SQUOT           rmb     1       * SIGN OF QUOTIENT
SREM            rmb     1       * SIGN OF REMAINDER
MTEMP           rmb     2       * MATH TEMP REGISTER (WORD)

DRIVE           rmb     1       * DRIVE NUMBER
DBUFF           rmb     2       * DISK I/O BUFFER POINTER (WORD)
DBLOCK          rmb     2       * Z-BLOCK # (WORD)
track           rmb     2       * TRACK/SECTOR ADDRESS (WORD)

*--- Optimized Absolute Pointers ---
global_ptr      rmb     2       * Absolute address of Global table
vocab_ptr       rmb     2       * Absolute address of Vocabulary table

TIMEFL          rmb     1       * "TRUE" IF TIME MODE


CHRPNT          rmb     1       * I/O BUFFER INDEX
CPSAV           rmb     1       * SAVE REGISTER FOR [CHRPNT]
BINDEX          rmb     1       * BUFFER DISPLAY INDEX
LINCNT          rmb     1       * # LINES DISPLAYED SINCE LAST USL
IOCHAR          rmb     1       * CURRENT I/O CHARACTER
GDRIVE          rmb     1       * GAME-SAVE DEFAULT DRIVE #
GPOSIT          rmb     1       * GAME-SAVE DEFAULT POSITION
RAND1           rmb     1       * RANDOM NUMBER REGISTER
RAND2           rmb     1       * DITTO
CYCLE           rmb     2       * TIMER FOR CURSOR BLINK (WORD)
BLINK           rmb     1       * MASK FOR CURSOR BLINK
CFLAG           rmb     1       * CURSOR ENABLE FLAG
SCRIPT          rmb     1       * SCRIPTING ENABLE FLAG
IHOLD           rmb     1       * INTERRUPT HOLD
TPOSIT          rmb     1       * TEMP GAME POSITION
TDRIVE          rmb     1       * TEMP GAME DRIVE

*--- OS-9 Specific Data Area (Still in Direct Page) ---
zcode_ptr       rmb     2       * Pointer to base of Z-code in RAM
zcode_offset    rmb     2       * Dynamic offset of Z-code preload (aligned with stack)
zsp_top         rmb     2       * Top of Z-stack (absolute address)
zstack_limit    rmb     2       * Limit (bottom) of Z-stack (absolute address)
cur_cols        rmb     1       * Current terminal columns
cur_rows        rmb     1       * Current terminal rows
cur_x           rmb     1       * Current cursor X position (0 to cols-1)
cur_y           rmb     1       * Current cursor Y position (1 to rows-1)
inv_flag        rmb     1       * Flag for inverse printing (1 = inverse)
page_lines      rmb     1       * Lines printed since last [MORE] prompt
was_cr          rmb     1       * State for CRLF detection (1 if last char was CR)
display_codes   rmb     3       * Transient buffer for terminal control escape sequences
dev_opts        rmb     32      * Buffer for I$GetStt/I$SetStt terminal options
path_num        rmb     1       * Path number to the open file
buffer_start    rmb     2       * address of a contiguous set of 256 byte buffers
buffer_size     rmb     2       * total size of buffer in bytes
prtinv_vec      rmb     2       * vector to subroutine to print inverse characters
scroll_vec      rmb     2       * vector to subroutine to scroll content area
ver_flag        rmb     1       * Flag to force disk reads during game verification

ZPGTOP          equ     .       * End of Direct Page variables

*--- Large Buffers (Non-Direct Page, U-relative) ---
ZSTACK          rmb     1024    * Z-STACK (512 WORDS)
PTABLE          rmb     320     * PAGING TABLE ($140 BYTES)
LRUMAP          rmb     160     * TIMESTAMP MAP ($A0 BYTES)
LOCALS          rmb     32      * LOCAL VARIABLE STORAGE (32 BYTES)
BUFFER          rmb     32      * I/O LINE BUFFER (32 BYTES)
BUFSAV          rmb     32      * I/O AUX BUFFER (32 BYTES)
status_buf      rmb     80      * STATUS LINE BUFFER (80 BYTES)
TotalDataSize   equ     .

* STATIC_SIZE calculation:
* TotalDataSize + 1KB stack space, rounded up to 256-byte page boundaries
STATIC_SIZE     equ     $0A00

