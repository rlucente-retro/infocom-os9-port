; ---------------------------------------------------------------------
; COCO_EQ.ASM - Global Equates for the Infocom Z-interpreter (CoCo)
; ---------------------------------------------------------------------

        IFNDEF COCO_EQ_ASM_INC
COCO_EQ_ASM_INC EQU 1

; --- CoCo Hardware Registers ---
PIA0    EQU     $FF00           ; Peripheral Interface Adapter 0
DSKREG  EQU     $FF40           ; Disk Controller: Hardware control register
MOTOR   EQU     $FF40           ; Alias for DSKREG
FDCREG  EQU     $FF48           ; WD1793 Floppy Disk Controller base register

; --- Disk Controller Variables (CoCo DOS Convention) ---
DCB     EQU     $EA             ; Start of Disk Control Block (DCB) structure
DCOPC   EQU     $EA             ; Disk Controller: Command code (Read/Write)
DCDRV   EQU     $EB             ; Disk Controller: Drive number (0-3)
DCTRK   EQU     $EC             ; Disk Controller: Target Track (0-34)
DSEC    EQU     $ED             ; Disk Controller: Target Sector (1-18)
DCBPT   EQU     $EE             ; Disk Controller: Pointer to data buffer
DCSTA   EQU     $F0             ; Disk Controller: Status of last operation
DR0TRK  EQU     $97E            ; Disk Controller: Current track position for Drive 0
NMIFLG  EQU     $982            ; Flag used to synchronize NMI disk transfers
DNMIVC  EQU     $983            ; Disk Controller: NMI vector for data transfer
RDYTMR  EQU     $985            ; Disk motor-on countdown timer (60Hz units)
DRGRAM  EQU     $986            ; Disk Controller: Shadow copy of register $FF40

; --- ROM/System Variables ---
IRQVEC  EQU     $10C            ; Hardware IRQ vector location
CASFLG  EQU     $011A           ; Cassette I/O status flag
DEBVAL  EQU     $011B           ; Keyboard debounce timer value
KEYBUF  EQU     $0152           ; Keyboard buffer address
RVEC3   EQU     $0167           ; RAM hook for character output
DEVNUM  EQU     $6F             ; Current I/O device number (0=Screen)
CURPOS  EQU     $88             ; Current cursor position address
VIDRAM  EQU     $0400           ; Start of VDG Text Video RAM

; --- ASCII and Control Characters ---
BS      EQU     $08             ; ASCII Backspace
CR      EQU     $0D             ; ASCII Carriage Return
SPACE   EQU     $20             ; ASCII Space

; --- Utility Opcodes ---
SKP2    EQU     $8C             ; 6809 Opcode to skip next 2 bytes (BITB <imm16>)
ZERO    EQU     $8A             ; Pointer to a constant zero value

        ENDIF   ; COCO_EQ_ASM_INC
