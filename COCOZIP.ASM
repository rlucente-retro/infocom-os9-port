

        ; -------------------------------
        ; ZIP/6809 VERSION C
        ; Z-CODE INTERPRETER PROGRAM
        ; FOR 64K TRS-80 COLOR COMPUTER 2
        ; -------------------------------

        ; COMPANY PRIVATE -- NOT FOR DISTRIBUTION

MSTART  EQU     $0A00                   ; START OF FREE PROGRAM RAM

DEBUG   EQU     0                       ; ASSEMBLY FLAG

        ; -----------
        ; ERROR CODES
        ; -----------

        ; 00 -- INSUFFICIENT RAM
        ; 01 -- ILLEGAL X-OP
        ; 02 -- ILLEGAL 0-OP
        ; 03 -- ILLEGAL 1-OP
        ; 04 -- ILLEGAL 2-OP
        ; 05 -- Z-STACK UNDERFLOW
        ; 06 -- Z-STACK OVERFLOW
        ; 07 -- ILLEGAL PROPERTY LENGTH (GETP)
        ; 08 -- DIVISION BY ZERO
        ; 09 -- ILLEGAL ARGUMENT COUNT (EQUAL?)
        ; 10 -- ILLEGAL PROPERTY ID (PUTP)
        ; 11 -- ILLEGAL PROPERTY LENGTH (PUTP)
        ; 12 -- DISK ADDRESS OUT OF RANGE
        ; 13 -- PARSER OVERFLOW
        ; 14 -- DRIVE ACCESS
        ; 15 -- Z-STACK DESTROYED
        ; 16 -- ZIP NOT FULLY LOADED


        INCLUDE EQ.ASM
        INCLUDE WARM.ASM


        INCLUDE MAIN.ASM
        INCLUDE SUBS.ASM
        INCLUDE DISPATCH.ASM


        INCLUDE OPS0.ASM
        INCLUDE OPS1.ASM
        INCLUDE OPS2.ASM
        INCLUDE OPSX.ASM
        INCLUDE READ.ASM


        INCLUDE PAGING.ASM
        INCLUDE ZSTRING.ASM
        INCLUDE OBJECTS.ASM


        INCLUDE IO.ASM
        INCLUDE SCREEN.ASM
        INCLUDE DISK.ASM


        IF DEBUG
        INCLUDE BUGGER.ASM
        ENDIF

        END

