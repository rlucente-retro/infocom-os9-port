*******************************************************************************
* OS9_MAIN.ASM - OS-9 Port of Z-Machine Main Loop
*******************************************************************************


*-------------------------------------------------------------------------------
* MLOOP: Main interpreter loop
*-------------------------------------------------------------------------------
MLOOP:  dec     RAND2,u         * randomness
        dec     RAND2,u

        clr     ARGCNT,u        * reset argument count
        lbsr     NEXTPC          * fetch next opcode byte
        sta     OPCODE,u

        lbpl    OP2             * 0-127 = 2-OP
        cmpa    #176
        blo     OP1             * 128-175 = 1-OP
        cmpa    #192
        blo     OP0             * 176-191 = 0-OP

*-------------------------------------------------------------------------------
* OPEXT: Handle an X-OP (Extended Opcode)
*-------------------------------------------------------------------------------
OPEXT:  lbsr     NEXTPC          * get argument type byte
        sta     TEMP2,u
        clr     TEMP2+1,u       * init argument index
        bra     OPX1

OPX0:   lda     TEMP2,u
        asla
        asla
        sta     TEMP2,u

OPX1:   anda    #%11000000      * isolate current arg type
        bne     OPX2
        lbsr     GETLNG          * 00 = long immediate
        bra     OPXNXT

OPX2:   cmpa    #%01000000
        bne     OPX3
        lbsr     GETSHT          * 01 = short immediate
        bra     OPXNXT

OPX3:   cmpa    #%10000000
        bne     OPX4            * 11 = no more args
        lbsr     GETVAR          * 10 = variable

OPXNXT: ldb     TEMP2+1,u       * get current index
        leax    ARG1,u          * address of argument array
        leax    b,x             * offset to current argument
        ldd     TEMP,u          * get fetched value
        std     ,x              * store in array
        inc     ARGCNT,u
        ldb     TEMP2+1,u
        addb    #2              * increment index (2 bytes per arg)
        stb     TEMP2+1,u
        cmpb    #8              * 4 arguments max
        blo     OPX0

* Dispatch the X-OP
OPX4:   ldb     OPCODE,u
        cmpb    #224            * is it an extended 2-OP?
        lblo    OP2EX           * handle like 2-OP if so
        andb    #%00011111      * else isolate opcode bits
        cmpb    #NOPSX
        blo     DISPX           * valid opcode?

        lda     #1              * error 1: illegal x-op
        lbra     ZERROR

DISPX:  leax    OPTX,pcr        * PCR dispatch table
DODIS:  aslb                    * 2 bytes per entry
        ldd     b,x             * get offset from table
        leax    d,x             * calculate absolute routine address
        jsr     ,x              * execute handler
        lbra    MLOOP           * loop back


*-------------------------------------------------------------------------------
* OP0: Handle a 0-OP
*-------------------------------------------------------------------------------
OP0:    leax    OPT0,pcr        * PCR dispatch table
        ldb     OPCODE,u
        andb    #%00001111      * isolate opcode bits
        cmpb    #NOPS0
        blo     DODIS           * valid opcode?

        lda     #2              * error 2: illegal 0-op
        lbra     ZERROR

*-------------------------------------------------------------------------------
* OP1: Handle a 1-OP
*-------------------------------------------------------------------------------
OP1:    anda    #%00110000      * isolate argument bits
        bne     OP1A
        lbsr     GETLNG          * 00 = long immediate
        bra     OP1EX

OP1A:   cmpa    #%00010000
        bne     OP1B
        lbsr     GETSHT          * 01 = short immediate
        bra     OP1EX

OP1B:   cmpa    #%00100000
        beq     OP1C

        lda     #3              * error 3: illegal 1-op
        lbra     ZERROR

OP1C:   lbsr     GETVAR          * 10 = variable

OP1EX:  ldd     TEMP,u
        std     ARG1,u
        inc     ARGCNT,u
        leax    OPT1,pcr        * PCR dispatch table
        ldb     OPCODE,u
        andb    #%00001111
        cmpb    #NOPS1
        bhs     M_BADOP1
        bra     DODIS

M_BADOP1: lda   #3
        lbra     ZERROR

*-------------------------------------------------------------------------------
* OP2: Handle a 2-OP
*-------------------------------------------------------------------------------
OP2:    anda    #%01000000      * isolate 1st arg bit
        bne     OP2A
        lbsr     GETSHT          * 0 = short immediate
        bra     OP2B

OP2A:   lbsr     GETVAR          * 1 = variable

OP2B:   ldd     TEMP,u
        std     ARG1,u
        inc     ARGCNT,u

        lda     OPCODE,u
        anda    #%00100000      * isolate 2nd arg bit
        bne     OP2C
        lbsr     GETSHT          * 0 = short immediate
        bra     OP2D

OP2C:   lbsr     GETVAR          * 1 = variable

OP2D:   ldd     TEMP,u
        std     ARG2,u
        inc     ARGCNT,u

OP2EX:  leax    OPT2,pcr        * PCR dispatch table
        ldb     OPCODE,u
        andb    #%00011111      * isolate opcode bits
        cmpb    #NOPS2
        lblo    DODIS

        lda     #4              * error 4: illegal 2-op
        lbra     ZERROR

BADOP1_LOCAL: lda #3
        lbra     ZERROR

BADOP2_LOCAL: lda #4
        lbra     ZERROR

