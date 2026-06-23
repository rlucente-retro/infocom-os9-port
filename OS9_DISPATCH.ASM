*******************************************************************************
* OS9_DISPATCH.ASM - OS-9 Port of Opcode Dispatch Tables
*******************************************************************************


*-------------------------------------------------------------------------------
* 0-OPS Dispatch Table
*-------------------------------------------------------------------------------
OPT0:   fdb     ZRTRUE-OPT0     * 0
        fdb     ZRFALS-OPT0     * 1
        fdb     ZPRI-OPT0       * 2
        fdb     ZPRR-OPT0       * 3
        fdb     ZNOOP-OPT0      * 4
        fdb     ZSAVE-OPT0      * 5
        fdb     ZREST-OPT0      * 6
        fdb     ZSTART-OPT0     * 7
        fdb     ZRSTAK-OPT0     * 8
        fdb     POPSTK_OP-OPT0  * 9 
        fdb     ZQUIT-OPT0      * 10
        fdb     ZCRLF-OPT0      * 11
        fdb     ZUSL-OPT0       * 12
        fdb     ZVER-OPT0       * 13

NOPS0   EQU     14

*-------------------------------------------------------------------------------
* 1-OPS Dispatch Table
*-------------------------------------------------------------------------------
OPT1:   fdb     ZZERO-OPT1      * 0
        fdb     ZNEXT-OPT1      * 1
        fdb     ZFIRST-OPT1     * 2
        fdb     ZLOC-OPT1       * 3
        fdb     ZPTSIZ-OPT1     * 4
        fdb     ZINC-OPT1       * 5
        fdb     ZDEC-OPT1       * 6
        fdb     ZPRB-OPT1       * 7
        fdb     BADOP1_LOCAL-OPT1 * 8
        fdb     ZREMOV-OPT1     * 9
        fdb     ZPRD-OPT1       * 10
        fdb     ZRET-OPT1       * 11
        fdb     ZJUMP-OPT1      * 12
        fdb     ZPRINT-OPT1     * 13
        fdb     ZVALUE-OPT1     * 14
        fdb     ZBCOM-OPT1      * 15

NOPS1   EQU     16

*-------------------------------------------------------------------------------
* 2-OPS Dispatch Table
*-------------------------------------------------------------------------------
OPT2:   fdb     BADOP2_LOCAL-OPT2 * 0
        fdb     ZEQUAL-OPT2     * 1
        fdb     ZLESS-OPT2      * 2
        fdb     ZGRTR-OPT2      * 3
        fdb     ZDLESS-OPT2     * 4
        fdb     ZIGRTR-OPT2     * 5
        fdb     ZIN-OPT2        * 6
        fdb     ZBTST-OPT2      * 7
        fdb     ZBOR-OPT2       * 8
        fdb     ZBAND-OPT2      * 9
        fdb     ZFSETP-OPT2     * 10
        fdb     ZFSET-OPT2      * 11
        fdb     ZFCLR-OPT2      * 12
        fdb     ZSET-OPT2       * 13
        fdb     ZMOVE-OPT2      * 14
        fdb     ZGET-OPT2       * 15
        fdb     ZGETB-OPT2      * 16
        fdb     ZGETP-OPT2      * 17
        fdb     ZGETPT-OPT2     * 18
        fdb     ZNEXTP-OPT2     * 19
        fdb     ZADD-OPT2       * 20
        fdb     ZSUB-OPT2       * 21
        fdb     ZMUL-OPT2       * 22
        fdb     ZDIV-OPT2       * 23
        fdb     ZMOD-OPT2       * 24

NOPS2   EQU     25

*-------------------------------------------------------------------------------
* X-OPS Dispatch Table
*-------------------------------------------------------------------------------
OPTX:   fdb     ZCALL-OPTX      * 0
        fdb     ZPUT-OPTX       * 1
        fdb     ZPUTB-OPTX      * 2
        fdb     ZPUTP-OPTX      * 3
        fdb     ZREAD-OPTX      * 4
        fdb     ZPRC-OPTX       * 5
        fdb     ZPRN-OPTX       * 6
        fdb     ZRAND-OPTX      * 7
        fdb     ZPUSH-OPTX      * 8
        fdb     ZPOP-OPTX       * 9
        fdb     ZSPLIT-OPTX     * 10
        fdb     ZSCRN-OPTX      * 11

NOPSX   EQU     12

