


        INCLUDE "COCO_EQ.ASM"

SCREEN  EQU     $400            ; START OF SCREEN RAM
ENDSCR  EQU     $600            ; END OF SCREEN RAM
POLCAT  EQU     $A000           ; KEYCODE FETCH VECTOR
CHROUT  EQU     $A002           ; PRINT CHAR TO DEVICE
CURSOR  EQU     $88             ; ABSOLUTE CURSOR ADDRESS
INT60   EQU     $FF03           ; 60HZ INTERRUPT CONTROL
ROMON   EQU     $FFDE           ; ROM ENABLE
ROMOFF  EQU     $FFDF           ; ROM DISABLE
MEMTOP  EQU     $FE             ; TOP PAGE OF AVAILABLE RAM

EOL     EQU     $0D             ; END-OF-LINE CHARACTER
CDURAT  EQU     5               ; DURATION OF KEYCLICKS
CFREQ   EQU     25              ; FREQUENCY OF KEYCLICKS
BDURAT  EQU     10              ; DURATION OF RAZZ
BFREQ   EQU     500             ; FREQUENCY OF RAZZ
FLASH   EQU     $180            ; CURSOR BLINK FREQUENCY




        ; ------------------
        ; ENABLE ROM FOR I/O
        ; ------------------

; NO LONGER NEEDED IN 0S9 VERSION [ASK 5/17/85]****************************
ROMIN:  STA     IHOLD           ; SAVE [A]
        LDA     INT60           ; ENABLE 60HZ INTERRUPT
        ORA     #%00000001
        STA     ROMON
        STA     INT60
        ANDCC   #%10101111      ; INTERRUPTS ON
        LDA     IHOLD           ; RESTORE [A]
        RTS

        ; ------------------
        ; ACCESS OS KEY-READ
        ; ------------------

;CATPOL:        BSR     ROMIN
;CPL:   JSR     MYCAT           ; TO NON-ROM ROUTINE OF POLCAT
;       BEQ     CPL

CATPOL: JSR     MYCAT
        BEQ     CATPOL
        RTS

        ; ----------------------
        ; DISABLE ROM FOR PAGING
        ; ----------------------

ROMOUT: STA     IHOLD           ; SAVE [A]
;       ORCC    #%01010000      ; DISABLE INTERUPTS
;       LDA     INT60
;       ANDA    #%11111110      ; DISABLE 60HZ INTERRUPT
;       STA     INT60
        STA     ROMOFF          ; AND ROM
        LDA     IHOLD           ; RESTORE [A]
        RTS

        ; --------------------
        ; ACCESS OS CHAR-PRINT
        ; --------------------

;OUTCHR:        BSR     ROMIN
;       JSR     MYCHR           ;CHROUT COPIED
;       BRA     ROMOUT

OUTCHR: JMP     MYCHR

        ; -----------------
        ; READ A SINGLE KEY
        ; -----------------

        ; EXIT: KEYCODE IN [A]

BADKEY: JSR     BOOP            ; RAZZ
        BRA     WINK            ; AND TRY AGAIN

GETKEY: PSHS    U,X,Y,B         ; SAVE THESE

;       BSR     ROMIN           ;[ASK 5/15/85]

WINK:   LDY     #FLASH*4
        STY     CYCLE           ; LONG DELAY
        LDA     #%10000000
        STA     BLINK           ; INIT CURSOR MASK
GK:     JSR     MYCAT           ; (POLCAT COPIED) LET OS DO THE WORK
        INC     RAND1           ; GENERATE RANDOMNESS
        BNE     GKZ
        INC     RAND2
GKZ:    TST     CFLAG           ; BLINK CURSOR?
        BEQ     NOBLIN          ; NOT IF [CFLAG]=0
        LDY     CYCLE
        LEAY    -1,Y
        STY     CYCLE           ; TIME TO BLINK?
        BNE     KTEST           ; NOT YET
        LDY     #FLASH          ; ELSE RESET BLINK TIMER
        STY     CYCLE
        LDB     BLINK
        EORB    #%10000000      ; FLIP CURSOR MASK
        STB     BLINK
KTEST:  LDX     CURSOR
        LDB     ,X
        ANDB    #%01111111
        ORB     BLINK
        STB     ,X
NOBLIN: TSTA
        BEQ     GK              ; 0 = NO KEY YET
        TST     CFLAG
        BEQ     QKEY
        ANDB    #%01111111      ; CLEAR CURSOR
        STB     ,X

        ; SCREEN KEYCODE IN [A]

QKEY:   CMPA    #EOL            ; "ENTER" IS FINE
        BEQ     CLICK
        CMPA    #BS             ; SO IS "LEFT ARROW"
        BEQ     CLICK

        CMPA    #$61            ; LOWER-CASE ALPHA?
        BLO     PKICK           ; NO, CHECK FOR OTHERS
        CMPA    #$7B            ; NOTHING ABOVE "z" IS LEGAL
        BHS     BADKEY
        SUBA    #$20            ; CONVERT TO UPPER-CASE ALPHA
        BRA     CLICK

PKICK:  CMPA    #$5B            ; NOTHING BETWEEN "Z" AND "a"
        BHS     BADKEY          ; IS LEGAL
        CMPA    #$20            ; NOTHING BELOW "SPACE"
        BLO     BADKEY          ; IS LEGAL EITHER

        ; "CLICK" SOUND FOR KEYS

CLICK:  STA     IOCHAR          ; SAVE KEY HERE
        JSR     AINIT           ; ENABLE SOUND
        LDB     #CDURAT
TICK:   LDA     #%11111110
        STA     $FF20
        BSR     CDELAY
        LDA     #%00000010
        STA     $FF20
        BSR     CDELAY
        DECB
        BNE     TICK
        PULS    U,X,Y,B         ; RESTORE THINGS
        LDA     IOCHAR          ; RETRIEVE THE KEYPRESS
        RTS

;       JMP     ROMOUT          ; AND SWITCH OUT THE ROMS  [ASK 5/15/85]

        ; DELAY FOR KEYCLICK

CDELAY: LDX     #CFREQ
CDEL:   LEAX    -1,X
        BNE     CDEL
        RTS

        ; -------------------
        ; READ A LINE OF TEXT
        ; -------------------

        ; ENTRY: [ARG1] HAS ADDRESS OF CHAR BUFFER
        ;        LENGTH OF BUFFER IN 1ST BYTE
        ; EXIT: # CHARS READ IN [A]

INPUT:  JSR     LINOUT          ; FLUSH OUTPUT BUFFER
        CLR     LINCNT          ; RESET LINE COUNTER
        CLR     DEVNUM          ; POINT TO SCREEN
        LDX     ARG1            ; GET ADDRESS OF INPUT BUFFER
        LDB     ,X+             ; GET MAX # CHARS
        SUBB    #2              ; LEAVE A MARGIN FOR ERROR
        STB     BINDEX          ; SAVE MAX # CHARS
        STB     CFLAG           ; ENABLE CURSOR

        CLRB                    ; RESET INDEX
INLOOP: JSR     GETKEY          ; KEY IN [A] AND [IOCHAR]
        CMPA    #EOL            ; IF EOL,
        BEQ     ENDLIN          ; LINE IS DONE
        CMPA    #BS             ; IF BACKSPACE,
        BEQ     GOBACK          ; TAKE CARE OF IT

        CMPA    #$41            ; IF LOWER THAN ASCII "A,"
        BLO     SENDCH          ; SEND THE CHARACTER
        ADDA    #$20            ; ELSE CONVERT TO LOWER-CASE

SENDCH: STA     B,X             ; SEND CHAR TO BUFFER
        INCB                    ; UPDATE INDEX
TOSCR:  LDA     IOCHAR          ; RETRIEVE KEY CHAR
        BSR     CHAR            ; ECHO CHAR TO SCREEN
        CMPB    BINDEX          ; BUFFER FILLED?
        BHS     NOMORE          ; YES -- INSIST ON BS OR EOL
        CMPB    #61             ; 2 SCREEN LINES FILLED?
        BLO     INLOOP          ; NO, KEEP GOING

        ; LINE FULL; INSIST ON EOL OR BACKSPACE

NOMORE: JSR     GETKEY          ; GET NEXT KEY
        CMPA    #EOL            ; IF EOL,
        BEQ     ENDLIN          ; WE'RE FINE
        CMPA    #BS             ; BACKSPACE
        BEQ     GOBACK          ; IS OKAY TOO
        JSR     BOOP
        BRA     NOMORE          ; ELSE PERSIST

        ; HANDLE BACKSPACE

GOBACK: DECB                    ; BACK UP CHAR COUNT
        BPL     TOSCR           ; SEND TO SCREEN IF NO UNDERFLOW
        CLRB                    ; ELSE RESET COUNT
        JSR     BOOP            ; RAZZ
        BRA     INLOOP          ; AND TRY AGAIN

        ; HANDLE EOL

ENDLIN: STA     B,X             ; PUT EOL IN BUFFER
        BSR     CHAR            ; AND ON SCREEN
        INCB                    ; UPDATE CHAR COUNT
        STB     BINDEX          ; SAVE IT HERE

        ; FALL THROUGH TO ...

        ; ---------------------
        ; SCRIPT A LINE OF TEXT
        ; ---------------------

        ; ENTRY: ADDRESS OF TEXT IN [X]
        ;        LENGTH OF LINE IN [BINDEX]

TOPRIN: TST     SCRIPT          ; SCRIPTING ENABLED?
        BEQ     INPEX           ; NO, EXIT IMMEDIATELY
        LDA     ZCODE+ZSCRIP+1  ; GET FLAGS BYTE
        ANDA    #1              ; BIT 0 SET?
        BEQ     INPEX           ; NO, IGNORE THE FOLLOWING
        LDA     #$FE            ; ELSE
        STA     DEVNUM          ; POINT TO PRINTER
        LDB     BINDEX          ; START AT 1ST BUFFER CHAR

;       JSR     ROMIN

SCROUT: LDA     ,X+             ; GRAB A CHAR FROM BUFFER
        JSR     MYCHR
        DECB
        BNE     SCROUT
INPEX:  CLR     DEVNUM          ; POINT BACK TO SCREEN
        LDA     BINDEX          ; RETRIEVE # CHARS IN LINE
        RTS

SFLAG   FCB     0               ; FLAG TO SAVE SCRIPT STATE

;       JMP     ROMOUT          ; MAKE SURE ROM IS GONE [ASK 5/15/85]

        ; -------------------
        ; PRINT A SINGLE CHAR
        ; -------------------

        ; ENTRY: ASCII CODE IN [A]

CHAR:   STA     IOCHAR          ; SAVE CHAR HERE
        CLR     DEVNUM          ; ALWAYS TO SCREEN
        PSHS    X,Y,B           ; SAVE THESE
        INC     RAND1           ; RANDOMNESS
        LDY     CURSOR          ; GET ADDRESS OF CURSOR
        CMPA    #EOL            ; EOL?
        BEQ     OUTEOL          ; HANDLE IT
        CMPY    #ENDSCR-1       ; LAST CHAR ON SCREEN?
        BLO     NOSCRL          ; NO SCROLL NECESSARY

        ; SCROLL SCREEN, RETAINING STATUS LINE

DOSCRL: LDY     #ENDSCR-33      ; LAST POSITION IN LINE 14
        STY     CURSOR          ; MOVE CURSOR
        LDX     #SCREEN+64      ; [X] POINTS TO "SOURCE" LINE
        LDY     #SCREEN+32      ; [Y] POINTS TO "DEST" LINE

SCRL1:  LDB     #31             ; INIT LINE INDEX

SCRL2:  LDA     B,X             ; GET CHAR FROM SOURCE LINE
        STA     B,Y             ; MOVE TO DESTINATION LINE
        DECB                    ; CONTINUE TILL
        BPL     SCRL2           ; ENTIRE LINE IS MOVED

        TFR     X,Y             ; SOURCE IS NOW DEST
        LEAX    32,X            ; ADD 32 TO SOURCE ADDRESS
        CMPX    #ENDSCR         ; END OF SCREEN YET?
        BLO     SCRL1           ; NO, KEEP MOVING

        LDA     #$60            ; SPACE CHAR
SCRL3:  STA     ,Y+
        CMPY    #ENDSCR
        BLO     SCRL3

NOSCRL: LDA     IOCHAR          ; RESTORE CHAR

        ; LOWER-CASE OPTION

;       TST     LCASE           ; LOWER-CASE CAPABILITY?
;       BNE     GOCHR           ; YES, SEND CHAR AS-IS

        CMPA    #$61            ; LESS THAN "a"?
        BLO     GOCHR           ; YES, USE AS-IS
        SUBA    #$20            ; ELSE CONVERT TO UPPER CASE
GOCHR:  JSR     OUTCHR          ; OFF TO THE SCREEN!
        PULS    X,Y,B           ; RESTORE
        RTS

        ; EOL SCROLL?

OUTEOL: CMPY    #ENDSCR-32      ; ON LAST SCREEN LINE?
        BLO     NOSCRL          ; NO, HANDLE NORMALLY
        BRA     DOSCRL          ; ELSE MOVE CURSOR UP!

        ; --------------------------
        ; PRINT CONTENTS OF [BUFFER]
        ; --------------------------

BUFOUT: LDB     CHRPNT          ; # CHARS IN BUFFER
        LDX     #BUFFER         ; BUFFER ADDRESS

        ; FALL THROUGH TO ...

        ; -------------
        ; PRINT MESSAGE
        ; -------------

        ; ENTRY: ADDRESS OF ASCII MESSAGE IN [X]
        ;        LENGTH OF MESSAGE IN [B]

LINE:   STB     BINDEX          ; SAVE LENGTH
        CLRB                    ; INIT INDEX

LN:     LDA     B,X             ; GET A CHAR
        JSR     CHAR
        INCB
        CMPB    BINDEX
        BLO     LN
        JMP     TOPRIN          ; HANDLE SCRIPTING

        ; ----------------
        ; CLEAR THE SCREEN
        ; ----------------

CLS:    LDA     #$60            ; SPACE CHARS
        LDX     #SCREEN
CLS0:   STA     ,X+
        CMPX    #ENDSCR
        BLO     CLS0
        LDD     #SCREEN+32
        STD     CURSOR          ; CURSOR AT LINE 1
        CLR     LINCNT          ; RESET LINE COUNTER
        CLR     CHRPNT          ; AND CHAR INDEX
        RTS

        ; --------------
        ; SOUND HANDLERS
        ; --------------

AINIT:  LDA     $FF01           ; ENABLE SOUND
        ANDA    #%11110111
        STA     $FF01
        LDA     $FF03
        ANDA    #%11110111
        STA     $FF03
        LDA     $FF23
        ORA     #%00001000
        STA     $FF23
        RTS

        ; DO THE RAZZ

BOOP:   PSHS    X,D
        BSR     AINIT
        LDB     #BDURAT         ; GET DURATION
BOOP1:  LDA     #%11111110      ; CREST OF WAVE
        STA     $FF20           ; SEND TO DAC
        BSR     DELAY           ; WAIT ...
        LDA     #%00000010
        STA     $FF20           ; TROUGH
        BSR     DELAY           ; WAIT AGAIN
        DECB                    ; ELSE NEXT DURATION
        BNE     BOOP1
        PULS    X,D
        RTS

        ; TIME DELAY

DELAY:  LDX     #BFREQ          ; INIT FREQUENCY
DELOOP: LEAX    -1,X
        BNE     DELOOP
        RTS

;-----------------------------------------------------------------------------

        ; ---------------------------------------------------------------------
        ; TANDY COLOR COMPUTER ROM-REPLACEMENT ROUTINES
        ;
        ; These routines are functional replacements for the standard CoCo
        ; Color BASIC and Disk BASIC ROM subroutines. They were adapted 
        ; directly from the "BASIC Unravelled" series of books to provide
        ; standalone I/O and disk access when the physical ROMs are swapped 
        ; out of the memory map. This is necessary because the interpreter 
        ; disables the ROMs to enable the full 64K RAM address space for 
        ; Z-code storage and paging. Since the original ROM entry points 
        ; are unavailable in this mode, the developers included these
        ; "copied" routines to maintain hardware functionality.
        ; ---------------------------------------------------------------------

        ; THESE ROM ROUTINES ARE TAKEN FROM THE BASIC UNRAVELED BOOKS
        ; 
        ; THEY ARE HERE BECAUSE THE ROMS ARE DISABLED DURING EXECUTION
        ; TO ALLOW ACCESS TO THE FULL 64K RAM SPACE.
        ;
        ; [ASK 5/15/85]

        ; ROM- ROUTINES

PIA1    EQU     $FF20
DA      EQU     $FF20

LPTPOS  EQU     $9C
LPTWID  EQU     $9B
LPTBTD  EQU     $95
LPTLND  EQU     $97


        ; IRQ HANDLER NEEDED FOR RDYTMR

DIRQSV: LDA     PIA0+3
        BPL     DRTI
        LDA     PIA0+2
        LDA     RDYTMR
        BEQ     DRTI
        DECA
        STA     RDYTMR
        BNE     DRTI
        LDA     DRGRAM
        ANDA    #$B0
        STA     DRGRAM
        STA     DSKREG
DRTI:   RTI

        ; ---------------------------------------------------------------------
        ; MYCAT: Keyboard Scan (Replacement for POLCAT at $A000)
        ; ---------------------------------------------------------------------
        ; THIS ROUTINE GETS A KEYSTROKE FROM THE KEYBOARD IF A KEY
        ; IS DOWN. IT RETURNS ZERO TRUE IF THERE WAS NO KEY DOWN.

LA1AE:  JMP     LA7D3           ; DELAY WHILE X DECREMENTS TO ZERO

MYCAT:  PSHS    U,X,B           ; SAVE REGISTERS
        LDU     #PIA0           ; POINT U TO PIA0
        LDX     #KEYBUF         ; POINT X TO KEYBOARD MEMORY BUFFER
        CLRA                    ; * CLEAR CARRY FLAG, SET COLUMN COUNTER (ACCA)
        DECA                    ; * TO $FF
        PSHS    X,A             ; SAVE COLUMN CTR & 2 BLANK (X REG) ON STACK
        STA     2,U             ; INITIALIZE COLUMN STROBE TO $FF
LA1D5:  ROL     2,U             ; * ROTATE COLUMN STROBE DATA LEFT 1 BIT, CARRY
        BCC     LA220           ; * INTO BIT 0 - BRANCH IF 8 SHIFTS DONE
        INC     ,S              ; INCREMENT COLUMN COUNTER
        BSR     LA239           ; READ KEYBOARD ROW DATA
        STA     1,S             ; TEMP STORE KEY DATA
        EORA    ,X              ; SET ANY BIT WHERE A KEY HAS MOVED
        ANDA    ,X              ; ACCA=0 IF NO NEW KEY DOWN, <70 IF KEY WAS RELEASED
        LDB     1,S             ; GET NEW KEY DATA
        STB     ,X+             ; STORE IT IN KEY MEMORY
        TSTA                    ; WAS A NEW KEY DOWN?
        BEQ     LA1D5           ; NO-CHECK ANOTHER COLUMN
        LDB     2,U             ; * GET COLUMN STROBE DATA AND
        STB     2,S             ; * TEMP STORE IT ON THE STACK

        ; THIS ROUTINE CONVERTS THE KEY DEPRESSION INTO A NUMBER
        ; FROM 0-50 IN ACCB CORRESPONDING TO THE KEY THAT WAS DOWN

        LDB     #$F8            ; TO MAKE SURE ACCB=0 AFTER FIRST ADDB #8
LA1F1:  ADDB    #8              ; ADD 8 FOR EACH ROW OF KEYBOARD
        LSRA                    ; HAS THE ROW NUMBER OF THIS KEY - ADD 8 FOR EACH ROW
        BCC     LA1F1           ; GO ON UNTIL A ZERO APPEARS IN THE CARRY FLAG
        ADDB    ,S              ; ADD IN THE COLUMN NUMBER

        ; NOW CONVERT THE VALUE IN ACCB INTO ASCII

        BEQ     LA244           ; THE 'AT SIGN' KEY WAS DOWN
        CMPB    #26             ; WAS IT A LETTER?
        BHI     LA246           ; NO
        ORB     #$40            ; YES, CONVERT TO UPPER CASE ASCII
        BSR     LA22E           ; CHECK FOR THE SHIFT KEY
        ORA     CASFLG          ; * 'OR' IN THE CASE FLAG & BRANCH IF IN UPPER
        BNE     LA20B           ; * CASE MODE OR SHIFT KEY DOWN
        ORB     #$20            ; CONVERT TO LOWER CASE
LA20B:  STB     ,S              ; TEMP STORE ASCII VALUE
        LDX     DEBVAL          ; GET KEYBOARD DEBOUNCE
        BSR     LA1AE
        LDB     #$FF            ; SET COLUMN STROBE TO ALL ONES (NO
        BSR     LA237           ; STROBE) AND READ KEYBOARD
        INCA                    ; = INCR ROW DATA, ACCA NOW 0 IF NO JOYSTICK
        BNE     LA220           ; = BRANCH IF JOYSTICK BUTTON DOWN
LA21A:  LDB     2,S             ; GET COLUMN STROBE DATA
        BSR     LA237           ; READ A KEY
        CMPA    1,S             ; IS IT THE SAME KEY AS BEFORE DEBOUNCE?
LA220:  PULS    X,A             ; REMOVE TEMP SLOTS FROM THE STACK AND RECOVER
                                ; THE ASCII VALUE OF THE KEY
        BNE     LA22B           ; NOT THE SAME KEY OR JOYSTICK BUTTON
        CMPA    #$12            ; IS SHIFT ZERO DOWN?
        BNE     LA22C           ; NO
        COM     CASFLG          ; YES, TOGGLE UPPER CASE/LOWER CASE FLAG
LA22B:  CLRA                    ; SET ZERO FLAG TO INDICATE NO NEW KEY DOWN
LA22C:  PULS    X,U,B,PC        ; RESTORE REGISTERS

LA22E:  LDA     #$7F            ; COLUMN STROBE
        STA     2,U             ; STORE TO PIA
        LDA     ,U              ; READ KEY DATA
        COMA                    ; *
        ANDA    #$40            ; * SET BIT 6 IF SHIFT KEY DOWN
        RTS                     ; RETURN

LA237:  STB     2,U             ; SAVE NEW COLUMN STROBE VALUE
LA239:  LDA     ,U              ; READ PIA0, PORT A TO SEE IF KEY IS DOWN
                                ; A BIT WILL BE ZERO IF ONE IS
        ORA     #$80            ; MASK OFF THE JOYSTICK COMPARATOR INPUT
        TST     2,U             ; ARE WE STROBING COLUMN 7?
        BMI     LA243           ; NO
        ORA     #$C0            ; YES, FORCE ROW 6 TO BE HIGH - THIS WILL CAUSE
                                ; THE SHIFT KEY TO BE IGNORED
LA243:  RTS                     ; RETURN


LA244:  LDB     #51             ; CODE FOR 'AT SIGN'
LA246:  LDX     #CONTAB-$36     ; POINT X TO CONTROL CODE TABLE
        CMPB    #33             ; KEY NUMBER <33?
        BLO     LA263           ; YES (ARROW KEYS, SPACE BAR, ZERO)
        LDX     #CONTAB-$54     ; POINT X TO MIDDLE OF CONTROL TABLE
        CMPB    #48             ; KEY NUMBER >48?
        BHS     LA263           ; YES (ENTER,CLEAR,BREAK,AT SIGN)
        BSR     LA22E           ; CHECK SHIFT KEY (ACCA WILL CONTAIN STATUS)
        CMPB    #43             ; IS KEY A NUMBER, COLON OR SEMICOLON?
        BLS     LA25C           ; YES
        EORA    #$40            ; TOGGLE BIT 6 OF ACCA WHICH CONTAINS THE SHIFT DATA
                                ; ONLY FOR SLASH,HYPHEN,PERIOD,COMMA
LA25C:  TSTA                    ; SHIFT KEY DOWN?
        BNE     LA20B           ; YES
        ADDB    #$10            ; NO, ADD IN ASCII OFFSET CORRECTION
        BRA     LA20B           ; GO CHECK FOR DEBOUNCE
LA263:  ASLB                    ; MULT ACCB BY 2 - THERE ARE 2 ENTRIES IN CONTROL
                                ; TABLE FOR EACH KEY - ONE SHIFTED, ONE NOT
        BSR     LA22E           ; CHECK SHIFT KEY
        BEQ     LA269           ; NOT DOWN
        INCB                    ; ADD ONE TO GET THE SHIFTED VALUE
LA269:  LDB     B,X             ; GET ASCII CODE FROM CONTROL TABLE
        BRA     LA20B           ; GO CHECK DEBOUNCE

CONTAB: FCB     $5E,$5F         ; UP ARROW
        FCB     $A,$5B          ; DOWN ARROW
        FCB     $8,$15          ; RIGHT ARROW
        FCB     $9,$5D          ; LEFT ARROW
        FCB     $20,$20         ; SPACE BAR
        FCB     $30,$12         ; ZERO
        FCB     $D,$D           ; ENTER
        FCB     $C,$5C          ; CLEAR
        FCB     $3,$3           ; BREAK
        FCB     $40,$13         ; AT SIGN

LA7D1:  LDX     ZERO
LA7D3:  LEAX    -1,X
        BNE     LA7D3
        RTS

; ---------------------------------------------------------------------
; MYCHR: Character Output (Replacement for CHROUT at $A002)
; ---------------------------------------------------------------------
; CONSOLE OUT
MYCHR:  PSHS    B               ; SAVE ACCB
        LDB     DEVNUM          ; GET DEVICE NUMBER
        INCB                    ; SET FLAGS
        PULS    B               ; RESTORE ACCB
        BMI     LA2BF           ; SEND TO LINE PRINTER
        BNE     LA30A           ; SEND TO SCREEN
;SEND TO CASSETTE NOT NEEDED

; SOFTWARE UART TO LINE PRINTER
LA2BF:  PSHS    CC,A,B,X        ; SAVE REGISTERS AND INTERRUPT STATUS
        ORCC    #$50            ; DISABLE IRQ,FIRQ
LA2C3:  LDB     PIA1+2          ; GET RS 232 STATUS
        LSRB                    ; SHIFT RS 232 STATUS BIT INTO CARRY
        BCS     LA2C3           ; LOOP UNTIL READY
        BSR     LA2FB           ; SET OUTPUT TO MARKING
        CLRB                    ; *
        BSR     LA2FD           ; * TRANSMIT ONE START BIT
        LDB     #8              ; SEND 8 BITS
LA2C8:  PSHS    B               ; SAVE BIT COUNTER
        CLRB                    ; CLEAR DA IMAGE I ZEROES TO DA WHEN SENDING RS 232 DATA
        LSRA                    ; ROTATE NEXT BIT OF OUTPUT CHARACTER TO CARRY FLAG
        ROLB                    ; * ROTATE CARRY FLAG INTO BIT ONE
        ASLB                    ; * AND ALL OTHER BITS SET TO ZERO
        BSR     LA2FD           ; TRANSMIT DATA BYTE
        PULS    B               ; GET BIT COUNTER
        DECB                    ; SENT ALL 8 BITS?
        BNE     LA2C8           ; NO
        BSR     LA2FB           ; SEND STOP BIT (ACCB:0)
        PULS    CC,A            ; RESTORE OUTPUT CHARACTER & INTERRUPT STATUS
        CMPA    #CR             ; IS IT CARRIAGE RETURN?
        BEQ     LA2ED           ; YES
        INC     LPTPOS          ; INCREMENT CHARACTER COUNTER
        LDB     LPTPOS          ; CHECK FOR END OF LINE PRINTER LINE
        CMPB    LPTWID          ; AT END OF LINE PRINTER LINE?
        BLO     LA2F3           ; NO
LA2ED:  CLR     LPTPOS          ; RESET CHARACTER COUNTER
        BSR     LA305           ; *
        BSR     LA305           ; * DELAY FOR CARRIAGE RETURN
LA2F3:  LDB     PIA1+2          ; WAIT FOR HANDSHAKE
        LSRB                    ; CHECK FOR RS232 STATUS?
        BCS     LA2F3           ; NOT YET READY
        PULS    B,X,PC          ; RESTORE REGISTERS

LA2FB:  LDB     #2              ; SET RS232 OUTPUT HIGH (MARKING)
LA2FD:  STB     DA              ; STORE TO THE D/A CONVERTER REGISTER
        BSR     LA302           ; GO WAIT A WHILE
LA302:  LDX     LPTBTD          ; GET BAUD RATE
        FCB     SKP2            ; SKIP NEXT TWO BYTES
LA305:  LDX     LPTLND          ; PRINTER CARRIAGE RETURN DELAY
        JMP     LA7D3           ; DELAY ON DECREMENTING X


; PUT A CHARACTER ON THE SCREEN
LA30A:  PSHS    A,B,X           ; SAVE REGISTERS
        LDX     CURPOS          ; POINT X TO CURRENT CHARACTER POSITION
        CMPA    #BS             ; IS IT BACKSPACE?
        BNE     LA31D           ; NO
        CMPX    #VIDRAM         ; AT TOP OF SCREEN?
        BEQ     LA35D           ; YES - DO NOT ALLOW BACKSPACE
        LDA     #$60            ; BLANK
        STA     ,-X             ; PUT IN PREVIOUS POSITION
        BRA     LA344           ; SAVE NEW CURPOS
LA31D:  CMPA    #CR             ; ENTER KEY?
        BNE     LA32F           ; BRANCH IF NOT
        LDX     CURPOS          ; GET CURRENT CHAR POSITION
LA323:  LDA     #$60            ; BLANK
        STA     ,X+             ; PUT IT ON SCREEN
        TFR     X,D             ; *
        BITB    #$1F            ; * TEST FOR BEGINNING OF NEW LINE
        BNE     LA323           ; PUT OUT BLANKS TILL NEW LINE
        BRA     LA344           ; CHECK FOR SCROLLING
LA32F:  CMPA    #SPACE          ; *
        BLO     LA35D           ; * BRANCH IF CONTROL CHARACTER
        TSTA                    ; SET FLAGS
        BMI     LA342           ; IT IS GRAPHIC CHARACTER
        CMPA    #$40            ; *
        BLO     LA340           ; * BRANCH IF NUMBER OR SPECIAL CHARACTER
        CMPA    #$60            ; UPPER/LOWER CASE?
        BLO     LA342           ; BRANCH IF UPPER CASE ALPHA
        ANDA    #$DF            ; CLEAR BIT 5, FORCE ASCII LOWER CASE TO BE UPPER CASE
LA340:  EORA    #$40            ; INVERT BIT 6, CHANGE UPPER CASE TO LOWER & VICE VERSA
LA342:  STA     ,X+             ; STORE CHARACTER TO SCREEN
LA344:  STX     CURPOS          ; SAVE CURRENT CHAR POSITION
        CMPX    #VIDRAM+511     ; END OF SCREEN BUFFER?
        BLS     LA35D           ; RETURN IF NO NEED TO SCROLL
        LDX     #VIDRAM         ; TOP OF SCREEN
; SCROLL THE SCREEN
LA34E:  LDD     32,X            ; GET TWO BYTES
        STD     ,X++            ; MOVE THEM UP ONE ROW
        CMPX    #VIDRAM+$1E0    ; AT THE LAST LINE?
        BLO     LA34E           ; NO
        LDB     #$60            ; BLANK
        JSR     LA92D           ; BLANK LAST LINE
LA35D:  PULS    A,B,X,PC        ; RESTORE REGISTERS

LA92D:  STX     CURPOS          ; SAVE IT IN CURPOS
LA92F:  STB     ,X+             ; FILL SCREEN WITH CONTENTS OF ACCB
        CMPX    #VIDRAM+511     ; END OF SCREEN?
        BLS     LA92F           ; NO
        RTS

; ---------------------------------------------------------------------
; MYCON: Disk Controller (Replacement for DSKCON at $C004)
; ---------------------------------------------------------------------
; DSKCON ROUTINE
MYCON:  PSHS    U,Y,X,D         ; SAVE REGISTERS
        LDA     #5              ; * GET RETRY COUNT AND
        PSHS    A               ; * SAVE IT ON THE STACK
LD672:  CLR     RDYTMR          ; RESET DRIVE NOT READY TIMER
        LDB     DCDRV           ; GET DRIVE NUMBER
        LDX     #LD7AA          ; POINT X TO DRIVE ENABLE MASKS
        LDA     DRGRAM          ; GET DSKREG IMAGE
        ANDA    #$A8            ; KEEP MOTOR STATUS, DOUBLE DENSITY. HALT ENABLE
        ORA     B,X             ; 'OR' IN DRIVE SELECT DATA
        ORA     #$20            ; 'OR' IN DOUBLE DENSITY
        LDB     DCTRK           ; GET TRACK NUMBER
        CMPB    #22             ; PRECOMPENSATION STARTS AT TRACK 22
        BLO     LD68B           ; BRANCH IF LESS THAN 22
        ORA     #$10            ; TURN ON WRITE PRECOMPENSATION IF >= 22
LD68B:  TFR     A,B             ; SAVE PARTIAL IMAGE IN ACCB
        ORA     #8              ; 'OR' IN MOTOR ON CONTROL BIT
        STA     DRGRAM          ; SAVE IMAGE IN RAM
        STA     DSKREG          ; PROGRAM THE 1793 CONTROL REGISTER
        BITB    #8              ; = WERE MOTORS ALREADY ON?
        BNE     LD69F           ; = DON'T WAIT FOR IT TO COME UP TO SPEED IF ALREADY ON
        JSR     LA7D1           ; * WAIT A WHILE
        JSR     LA7D1           ; * WAIT SOME MORE FOR MOTOR TO COME UP TO SPEED
LD69F:  BSR     LD6DE           ; WAIT UNTIL NOT BUSY OR TIME OUT
        BNE     LD6AD           ; BRANCH IF TIMED OUT (DOOR OPEN. NO DISK, NO POWER. ETC.)
        CLR     DCSTA           ; CLEAR STATUS REGISTER
        LDX     #LD7A2          ; POINT TO COMMAND JUMP VECTORS
        LDB     DCOPC           ; GET COMMAND
        ASLB                    ; 2 BYTES PER COMMAND JUMP ADDRESS
        JSR     [B,X]           ; GO DO IT
LD6AD:  PULS    A               ; GET RETRY COUNT
        LDB     DCSTA           ; GET STATUS
        BEQ     LD6BE           ; BRANCH IF NO ERRORS
        DECA                    ; DECREMENT RETRIES COUNTER
        BEQ     LD6BE           ; BRANCH IF NO RETRIES LEFT
        PSHS    A               ; SAVE RETRY COUNT ON STACK
        BSR     LD6C5           ; RESTORE HEAD TO TRACK 0
        BNE     LD6AD           ; BRANCH IF SEEK ERROR
        BRA     LD672           ; GO TRY COMMAND AGAIN IF NO ERROR
LD6BE:  LDA     #120            ; 120*1/60 = 2 SECONDS (1/60 SECOND FOR EACH IRQ INTERRUPT)
        STA     RDYTMR          ; WAIT 2 SECONDS BEFORE TURNING OFF MOTOR
        PULS    PC,U,Y,X,D      ; RESTORE REGISTERS - EXIT DSKCON

; RESTORE HEAD TO TRACK 0
LD6C5:  LDX     #DR0TRK         ; POINT TO TRACK TABLE
        LDB     DCDRV           ; GET DRIVE NUMBER
        CLR     B,X             ; ZERO TRACK NUMBER
        LDA     #3              ; * RESTORE HEAD TO TRACK 0, UNLOAD THE HEAD
        STA     FDCREG          ; * AT START, 30 MS STEPPING RATE
        EXG     A,A             ; =
        EXG     A,A             ; = WAIT FOR 1793 TO RESPOND TO COMMAND
        BSR     LD6DE           ; WAIT TILL DRIVE NOT BUSY
        BSR     LD6FD           ; WAIT SOME MORE
        ANDA    #$10            ; 1793 STATUS : KEEP ONLY SEEK ERROR
        STA     DCSTA           ; SAVE IN DSKCON STATUS
LD6DD:  RTS

; WAIT FOR THE 1793 TO BECOME UNBUSY. IF IT DOES NOT BECOME UNBUSY,
; FORCE AN INTERRUPT AND ISSUE A 'DRIVE NOT READY' 1793 ERROR.
LD6DE:  LDX     ZERO            ; GET ZERO TO X REGISTER - LONG WAIT
LD6E0:  LEAX    -1,X            ; DECREMENT LONG WAIT COUNTER
        BEQ     LD6EC           ; IF NOT READY BY NOW, FORCE INTERRUPT
        LDA     FDCREG          ; * GET 1793 STATUS AND TEST
        BITA    #1              ; * BUSY STATUS BIT
        BNE     LD6E0           ; BRANCH IF BUSY
        RTS
LD6EC:  LDA     #$D0            ; * FORCE INTERRUPT COMMAND - TERMINATE ANY COMMAND
        STA     FDCREG          ; * IN PROCESS. DO NOT GENERATE A 1793 INTERRUPT REQUEST
        EXG     A,A             ; * WAIT BEFORE READING 1793
        EXG     A,A             ; *
        LDA     FDCREG          ; RESET INTRQ (FDC INTERRUPT REQUEST)
        LDA     #$80            ; RETURN DRIVE NOT READY STATUS IF THE DRIVE DID NOT BECOME UNBUSY
        STA     DCSTA           ; SAVE DSKCON STATUS BYTE
        RTS

; MEDIUM DELAY
LD6FD:  LDX     #8750           ; DELAY FOR A WHILE
LD700:  LEAX    -1,X            ; * DECREMENT DELAY COUNTER AND
        BNE     LD700           ; * BRANCH IF NOT DONE
        RTS

; READ ONE SECTOR
LD705:  LDA     #$80            ; $80 IS READ FLAG (1793 READ SECTOR)
        FCB     SKP2            ; SKIP TWO BYTES (THROWN AWAY CMPX INSTRUCTION)
; WRITE ONE SECTOR
LD708:  LDA     #$A0            ; $A0 IS WRITE FLAG (1793 WRITE SECTOR)
        PSHS    A               ; SAVE READ/WRITE FLAG ON STACK
        LDX     #DR0TRK         ; POINT X TO TRACK NUMBER TABLE IN RAM
        LDB     DCDRV           ; GET DRIVE NUMBER
        ABX                     ; POINT X TO CORRECT DRIVE'S TRACK BYTE
        LDB     ,X              ; GET TRACK NUMBER OF CURRENT HEAD POSITION
        STB     FDCREG+1        ; SEND TO 1793 TRACK REGISTER
        CMPB    DCTRK           ; COMPARE TO DESIRED TRACK
        BEQ     LD739           ; BRANCH IF ON CORRECT TRACK
        LDA     DCTRK           ; GET TRACK DESIRED
        STA     FDCREG+3        ; SEND TO 1793 DATA REGISTER
        STA     ,X              ; SAVE IN RAM TRACK IMAGE
        LDA     #$17            ; * SEEK COMMAND FOR 1793: DO NOT LOAD THE
        STA     FDCREG          ; * HEAD AT START, VERIFY DESTINATION TRACK,
        EXG     A,A             ; * 30 MS STEPPING RATE - WAIT FOR
        EXG     A,A             ; * VALID STATUS FROM 1793
        BSR     LD6DE           ; WAIT TILL NOT BUSY
        BNE     LD737           ; RETURN IF TIMED OUT
        BSR     LD6FD           ; WAIT SOME MORE
        ANDA    #$18            ; KEEP ONLY SEEK ERROR OR CRC ERROR IN ID FIELD
        BEQ     LD739           ; BRANCH IF NO ERRORS - HEAD ON CORRECT TRACK
        STA     DCSTA           ; SAVE IN DSKCON STATUS
LD737:  PULS    PC,A

; HEAD POSITIONED ON CORRECT TRACK
LD739:  LDA     DSEC            ; GET SECTOR NUMBER DESIRED
        STA     FDCREG+2        ; SEND TO 1793 SECTOR REGISTER
        LDX     #LD798          ; * POINT X TO ROUTINE TO BE VECTORED
        STX     DNMIVC          ; * TO BY NMI UPON COMPLETION OF DISK I/O AND SAVE VECTOR
        LDX     DCBPT           ; POINT X TO I/O BUFFER
        LDA     FDCREG          ; RESET INTRQ (FDC INTERRUPT REQUEST)
        LDA     DRGRAM          ; GET DSKREG IMAGE
        ORA     #$80            ; SET FLAG TO ENABLE 1793 TO HALT 6809
        PULS    B               ; GET READ/WRITE COMMAND FROM STACK
        LDY     ZERO            ; ZERO OUT Y - TIMEOUT INITIAL VALUE
        LDU     #FDCREG         ; U POINTS TO 1793 INTERFACE REGISTERS
        COM     NMIFLG          ; NMI FLAG = $FF: ENABLE NMI VECTOR
        ORCC    #$50            ; DISABLE FIRQ,IRQ
        STB     FDCREG          ; * SEND READ/WRITE COMMAND TO 1793: SINGLE RECORD, COMPARE
        EXG     A,A             ; * FOR SIDE 0, NO 15 MS DELAY, DISABLE SIDE SELECT
        EXG     A,A             ; * COMPARE, WRITE DATA ADDRESS MARK (FB) - WAIT FOR STATUS
        CMPB    #$80            ; WAS THIS A READ?
        BEQ     LD782           ; IF SO, GO LOOK FOR DATA

; WAIT FOR THE 1793 TO ACKNOWLEDGE READY TO WRITE DATA
        LDB     #2              ; DRQ MASK BIT
LD768:  BITB    ,U              ; IS 1793 READY FOR A BYTE? (DRQ SET IN STATUS BYTE)
        BNE     LD778           ; BRANCH IF SO
        LEAY    -1,Y            ; DECREMENT WAIT TIMER
        BNE     LD768           ; KEEP WAITING FOR THE 1793 DRQ
LD770:  CLR     NMIFLG          ; RESET NMI FLAG
        ANDCC   #$AF            ; ENABLE FIRQ,IRQ
        JMP     LD6EC           ; FORCE INTERRUPT, SET DRIVE NOT READY ERROR


; WRITE A SECTOR
LD778:  LDB     ,X+             ; GET A BYTE FROM RAM
        STB     FDCREG+3        ; SEND IT TO 1793 DATA REGISTER
        STA     DSKREG          ; REPROGRAM FDC CONTROL REGISTER
        BRA     LD778           ; SEND MORE DATA

; WAIT FOR THE 1793 TO ACKNOWLEDGE READY TO READ DATA
LD782:  LDB     #2              ; DRQ MASK BIT
LD784:  BITB    ,U              ; DOES THE 1793 HAVE A BYTE? (DRQ SET IN STATUS BYTE)
        BNE     LD78E           ; YES, GO READ A SECTOR
        LEAY    -1,Y            ; DECREMENT WAIT TIMER
        BNE     LD784           ; KEEP WAITING FOR 1793 DRQ
        BRA     LD770           ; GENERATE DRIVE NOT READY ERROR

; READ A SECTOR
LD78E:  LDB     FDCREG+3        ; GET DATA BYTE FROM 1793 DATA REGISTER
        STB     ,X+             ; PUT IT IN RAM
        STA     DSKREG          ; REPROGRAM FDC CONTROL REGISTER
        BRA     LD78E           ; KEEP GETTING DATA

; BRANCH HERE ON COMPLETION OF SECTOR READ/WRITE
LD798:  ANDCC   #$AF            ; ENABLE IRQ, FIRQ
        LDA     FDCREG          ; * GET STATUS & KEEP WRITE PROTECT, RECORD TYPE/WRITE
        ANDA    #$7C            ; * FAULT, RECORD NOT FOUND, CRC ERROR OR LOST DATA
        STA     DCSTA           ; SAVE IN DSKCON STATUS
        RTS

; DSKCON OPERATION CODE JUMP VECTORS
LD7A2:  FDB     LD6C5           ; RESTORE HEAD TO TRACK ZERO
        FDB     LD6DD           ; NO OP - RETURN
        FDB     LD705           ; READ SECTOR
        FDB     LD708           ; WRITE SECTOR

; DSKREG MASKS FOR DISK DRIVE SELECT
LD7AA:  FCB     1               ; DRIVE SEL 0
        FCB     2               ; DRIVE SEL 1
        FCB     4               ; DRIVE SEL 2
        FCB     $40              ; DRIVE SEL 3




