# NitrOS-9 `del` Command Hang Analysis

## Overview

After booting NitrOS-9 (built via `make -C recipes/coco/floppy`) and issuing shell commands such as `del chk1`, the system hung indefinitely.

Using module load addresses from `notes.txt`, instruction traces in `output.txt`, and NitrOS-9 kernel sources in `nitros9`, this document details the line-by-line cause of the hang, the partial fix applied in PR #385, and the remaining kernel deadlock issue.

---

## PR #385 Update & Current Status

* **PR #385 Merged ([nitros9#385](https://github.com/nitros9project/nitros9/pull/385))**:
  Pull Request #385 (*"Fix Level 1 del command failure in IOMan"*) was merged to fix a bug introduced in commit `f23daf45` (*Merge Level 1 and Level 2 IOMan source into single shared file*). In that commit, Level 1's `IDeletX` routine in `level1/modules/ioman.asm` was incorrectly changed from loading `#I$Delete` (`#$87`) to Level 2's pre-normalized function code `#7`. This caused Level 1 `I$Delete` calls to fail, leading `del` to attempt writing error messages to standard output (`stdout`).
* **Ongoing Deadlock Bug**:
  While PR #385 fixes `IOMan` so valid `del` commands no longer fail and attempt to print error messages, **the root deadlock documented below still exists in NitrOS-9 Level 1**. If `del` (or any child utility) produces error output (e.g., file not found, permission error) or any stdout text while running under `Shell`, the child process will attempt to write to `stdout`. Because `Shell` holds terminal ownership (`term.V.BUSY = 1`) while blocked in `F$Wait`, `scf.asm` puts the child process to sleep (`F$IOQu` / `F$Sleep`). Since `scf.asm` does not send `S$Wake` upon releasing device ownership, both parent and child processes sleep indefinitely, hanging the system.

---

## Memory Map of Loaded Modules (`notes.txt`)

| Module Name | Base Address (Hex) | End Address (Hex) | Size (Hex) | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **`Del`** | `$A400` | `$A466` | `$0067` | Delete Command Utility |
| **`Shell`** | `$E656` | `$EC7C` | `$0627` | NitrOS-9 Command Interpreter (`shell_21`) |
| **`IOMan`** | `$B200` | `$B911` | `$0712` | I/O Manager (`ioman.asm`) |
| **`RBF`** | `$B912` | `$C6F6` | `$0DE5` | Random Block File Manager (`rbf.asm`) |
| **`rb1773`** | `$C6F7` | `$CC45` | `$054F` | CoCo Floppy Disk Driver (`rb1773.asm`) |
| **`SCF`** | `$CD02` | `$D3D1` | `$06D0` | Sequential Character File Manager (`scf.asm`) |
| **`VTIO`** | `$D3D2` | `$DD28` | `$0957` | Video Terminal I/O Driver (`vtio.asm`) |
| **`Krn`** | `$EE7B` | `$F677` | `$07FC` | Kernel Module (`krn.asm`) |
| **`KrnP2`** | `$F683` | `$FB92` | `$0510` | Kernel Part 2 (`krnp2.asm`, `fsleep.asm`) |

---

## Trace Analysis of the Hang (`output.txt`)

1. **Terminal Device Reservation (`term.V.BUSY`)**:
   * Process #1 (`Shell` at `$E656`) displays the command prompt (`GAMES/ZORK1: `) by writing to standard output (Path 1 / `Term`).
   * The Sequential Character File Manager ([`scf.asm`: lines 890–915](file:///Users/richardlucente/development/git/nitros9/level1/modules/scf.asm#L890-L915)) handles the output request (`AcquireDevice`) and marks `Term` as busy by setting its process ID in `term.V.BUSY`:
     * `term.V.BUSY = 1` (Process #1, `Shell`)

2. **Parent Fork & Wait**:
   * At line **6091493** (`Shell+0x56A`), `Shell` calls `F$Fork` (`Krn+0x42B`) to spawn child Process #2 (`Del` at `$A400`).
   * At line **6093700** (`Shell+0x574`), `Shell` calls `F$Wait` (`KrnP2+0x10B`) to wait for `Del` to exit.
   * **Issue**: `Shell` enters `F$Wait` while keeping `stdout` open, leaving `term.V.BUSY = 1`.

3. **Child Execution & Error Output Attempt**:
   * At line **6093899** (`Del+0x023`), child Process #2 (`Del` at `$A400`) executes.
   * Prior to PR #385, `IOMan` failed `I$Delete` because `IDeletX` passed `#7` instead of `#I$Delete` (`#$87`).
   * Upon receiving an error from `IOMan`, `Del` attempts to write an error message to standard output (`stdout`).
   * At line **6094431** (`IOMan+0x10F`), `scf.asm` checks `AcquireDevice` on `Term`. It finds `term.V.BUSY == 1` (Process #1 `Shell`).
   * Because `term.V.BUSY != 2` (`Del`), `scf.asm` calls `F$IOQu` at line **6095884** (`IOMan+0x6B4`).
   * At line **6095954** (`IOMan+0x6DD`), `F$IOQu` ([`ioman.asm`: line 2164](file:///Users/richardlucente/development/git/nitros9/level1/modules/ioman.asm#L2164)) links Process #2 (`Del`) into Process #1's I/O queue (`P$IOQN`) and calls `os9 F$Sleep` with `X = $0000`.
   * `X = $0000` puts Process #2 (`Del`) to sleep **indefinitely** until it receives a `S$Wake` signal from `Shell`.

4. **Missing Wakeup Signal & Deadlock**:
   * When `scf.asm` releases device ownership (`ReleaseDeviceIfOwned`), it clears `term.V.BUSY = 0`, but **fails to check `P$IOQN` or send `S$Wake` (`F$Send`)** to any process queued on that device.
   * **Deadlock State**:
     * Process #1 (`Shell`) is asleep in `F$Wait` waiting for Process #2 (`Del`) to exit.
     * Process #2 (`Del`) is asleep in `F$Sleep` waiting for `S$Wake` from Process #1 (`Shell`).
   * With both processes asleep and no active tasks left in the queue, the kernel executes `F$NProc` at line **6097698** (`KrnP2+0x361`) and enters an infinite CPU idle loop (`CWAI #$af`), causing NitrOS-9 to hang completely.

---

## Root Cause Code Sections in NitrOS-9

1. **`IDeletX` in `level1/modules/ioman.asm` (Fixed in PR #385)**:
   Prior to PR #385, `ioman.asm` loaded `#7` into register `B` on Level 1 instead of `#I$Delete` (`#$87`). PR #385 conditionalized `IDeletX`:
   ```assembly
   ifne Level2
               ldb       #7                  ; pre-normalized delete sub-function code for Level 2
   else
               ldb       #I$Delete           ; #$87 for Level 1
   endc
   ```

2. **`AcquireDevice` in [`level1/modules/scf.asm`](file:///Users/richardlucente/development/git/nitros9/level1/modules/scf.asm#L890-L905)**:
   ```assembly
   CheckDeviceBusy     ldx       V$STAT,x  ; get device static storage address
                       ldb       V.BUSY,x  ; get active process ID
                       beq       ReserveDevice ; no active process, device not busy go reserve it
                       cmpb      ,s        ; is it our own process?
                       beq       AcquireDeviceSuccess
                       bsr       ReleaseDevices
                       tfr       b,a
                       os9       F$IOQu    ; puts current process to sleep queued on process in A
   ```
   When a child process inherits open paths from a parent, `scf.asm` sees `V.BUSY == Parent_PID`, fails `cmpb ,s`, and puts the child to sleep queued on the parent.

3. **`ReleaseDeviceIfOwned` in [`level1/modules/scf.asm`](file:///Users/richardlucente/development/git/nitros9/level1/modules/scf.asm#L880-L887)**:
   ```assembly
   ReleaseDeviceIfOwned beq       ReleaseDeviceReturn
                       ldx       V$STAT,x  ; get static storage pointer
                       cmpa      V.BUSY,x  ; same process as current process?
                       bne       ReleaseDeviceReturn
                       clra                ; clear V.BUSY
                       sta       V.BUSY,x  ; mark device as free
   ReleaseDeviceReturn rts
   ```
   `scf.asm`'s `ReleaseDeviceIfOwned` clears `V.BUSY` without checking `P$IOQN` to issue `F$Send (S$Wake)` to wake up queued processes.

---

## Recommended Fixes in NitrOS-9

1. **Fix in `scf.asm` ([`level1/modules/scf.asm`](file:///Users/richardlucente/development/git/nitros9/level1/modules/scf.asm#L881))**:
   Update `ReleaseDeviceIfOwned` so that when `V.BUSY` is cleared, it checks if `<D.Proc` has a non-zero `P$IOQN`. If so, clear `P$IOQN` and issue `os9 F$Send` with `B = #S$Wake` to wake up the sleeping child process.

2. **Fix in `shell_21.asm` ([`level1/cmds/shell_21.asm`](file:///Users/richardlucente/development/git/nitros9/level1/cmds/shell_21.asm#L860))**:
   Ensure `shell_21` releases standard device ownership (`ReleaseDevices`) before invoking `F$Wait` for child processes.
