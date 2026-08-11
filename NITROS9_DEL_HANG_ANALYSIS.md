# NitrOS-9 `del` Command Hang Analysis

## Overview

When running NitrOS-9 (Level 1 CoCo image `l1_coco.dsk`) and executing `del CHK1` (a large save game file created by Infocom's `SAVE` command in `GAMES/ZORK1`), the system hangs indefinitely. 

Analysis of the execution trace log (`output.txt`) and NitrOS-9 kernel sources (`../nitros9`) reveals that the hang is caused by an **operating system deadlock between the `shell` process and its child `del` process over the terminal device (`term`)**, triggered specifically during multi-sector file deallocations.

---

## Why `del` Works on Small Files but Hangs on `CHK1`

| File Size | Deallocation Pattern in `rbf.asm` | `term.V.BUSY` Conflict? | Result |
| :--- | :--- | :--- | :--- |
| **Small File** (1 sector / 256 bytes) | Single-pass directory & bitmap update; no multi-stage I/O loop. | None; completes inline before any I/O queueing occurs. | **Succeeds** |
| **Large File** (`CHK1`, 15KB–30KB save file) | Multi-stage cluster deallocation loop ([`L1012`](file:///Users/richardlucente/development/git/nitros9/level1/modules/rbf.asm#L2101) / `F$DelBit` / [`L1069`](file:///Users/richardlucente/development/git/nitros9/level1/modules/rbf.asm#L2154) sector flushes). | `scf.asm` checks `term.V.BUSY` during multi-stage I/O, detects `shell` (Process #1) owns `term`, and puts `del` to sleep in `F$IOQu`. | **Deadlock (Hang)** |

### Technical Explanation:
* **Small Files**: NitrOS-9's Random Block File Manager ([`rbf.asm`: lines 2050–2120](file:///Users/richardlucente/development/git/nitros9/level1/modules/rbf.asm#L2050-L2120)) clears the single directory entry and single bitmap cluster bit in a single inline pass. It finishes instantly without multi-stage disk I/O flushes or device queue re-checks.
* **Large Files (`CHK1`: ~15KB–30KB save file spanning 60–120+ sectors)**: `rbf.asm` enters a deallocation loop ([`L1012` in `rbf.asm`](file:///Users/richardlucente/development/git/nitros9/level1/modules/rbf.asm#L2101-L2115)) to read allocation bitmaps, call `F$DelBit` across multiple clusters, write out bitmap sectors ([`L1069`](file:///Users/richardlucente/development/git/nitros9/level1/modules/rbf.asm#L2154)), and flush sector buffers ([`L1207`](file:///Users/richardlucente/development/git/nitros9/level1/modules/rbf.asm#L2371)). During this extended I/O activity, `scf.asm` checks device occupancy (`AcquireDevice`). Because `shell` (Process #1) wrote the prompt (`GAMES/ZORK1: `) to `stdout` right before forking `del`, `term.V.BUSY` was left set to `1` (Process #1). Seeing `term.V.BUSY == 1`, `scf.asm` puts Process #2 (`del`) into `F$Sleep` indefinitely waiting for Process #1.

---

## Detailed Execution Sequence from Trace Log (`output.txt`)

1. **Device Reservation (`term.V.BUSY`)**:
   * Process #1 (`shell`) displays the command prompt (`GAMES/ZORK1: `) by writing to standard output (Path 1 / `term`).
   * The Sequential Character File Manager ([`scf.asm`](file:///Users/richardlucente/development/git/nitros9/level1/modules/scf.asm#L890-L915)) handles the output request (`AcquireDevice`) and marks the terminal device as busy by storing Process #1's ID in `term.V.BUSY`:
     $$\text{term.V.BUSY} = 1 \quad (\text{Process \#1, shell})$$

2. **Process Fork & Parent Wait**:
   * Process #1 (`shell`) forks Process #2 (`del`) at line **3614684** (`F$Fork`).
   * Process #1 immediately calls `F$Wait` at line **3620276** to put itself to sleep until child Process #2 terminates.
   * **Issue**: Process #1 enters `F$Wait` while keeping `stdout` open, leaving `term.V.BUSY = 1`.

3. **Multi-Sector Deallocation & Queue Insertion**:
   * Child Process #2 (`del`) begins deleting `CHK1`. Lines **3617353–3617448** show `del` linking `RBF` to perform multi-cluster bitmap sector deallocations (`F$DelBit` and `L1069`).
   * At line **3616821** (`a523`), `scf.asm` checks `AcquireDevice`. It finds `term.V.BUSY == 1` (Process #1).
   * Because `term.V.BUSY != 2`, `scf.asm` assumes `term` is actively used by another process. It calls `F$IOQu` at line **3618806**.
   * `F$IOQu` ([`ioman.asm`](file:///Users/richardlucente/development/git/nitros9/level1/modules/ioman.asm#L2159-L2164)) links Process #2 to Process #1's I/O queue (`P$IOQN`) and issues `os9 F$Sleep` (`X = 0`) at line **3618876** (`b8dd`).
   * `X = 0` instructs the kernel to put Process #2 to sleep **indefinitely** until it receives a wakeup signal (`S$Wake`).

4. **Missing Wakeup Signal & Kernel Deadlock**:
   * When `scf.asm` releases device ownership (`ReleaseDeviceIfOwned`), it clears `term.V.BUSY = 0`, but **fails to check `P$IOQN` or send `S$Wake` (`F$Send`)** to any process queued on that device.
   * **Deadlock State**:
     * Process #1 (`shell`) is asleep in `F$Wait` waiting for Process #2 (`del`) to exit.
     * Process #2 (`del`) is asleep in `F$Sleep` waiting for `S$Wake` from Process #1.
   * With both processes asleep and no active tasks left, the NitrOS-9 kernel executes `F$NProc` at line **3620384** and drops into an infinite CPU idle loop (`CWAI #$af` at line **3620482**).

---

## Root Cause Analysis in NitrOS-9 Source Code

1. **`AcquireDevice` in [`level1/modules/scf.asm`](file:///Users/richardlucente/development/git/nitros9/level1/modules/scf.asm#L890-L905)**:
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

2. **`ReleaseDeviceIfOwned` in [`level1/modules/scf.asm`](file:///Users/richardlucente/development/git/nitros9/level1/modules/scf.asm#L880-L887)**:
   ```assembly
   ReleaseDeviceIfOwned beq       ReleaseDeviceReturn
                       ldx       V$STAT,x  ; get static storage pointer
                       cmpa      V.BUSY,x  ; same process as current process?
                       bne       ReleaseDeviceReturn
                       clra                ; clear V.BUSY
                       sta       V.BUSY,x  ; mark device as free
   ReleaseDeviceReturn rts
   ```
   Unlike RBF ([`rbf.asm`: `L0C56`](file:///Users/richardlucente/development/git/nitros9/level1/modules/rbf.asm#L1531)), `scf.asm`'s `ReleaseDeviceIfOwned` clears `V.BUSY` without checking `P$IOQN` to issue `F$Send (S$Wake)` to wake up queued processes.

---

## Recommended Solutions

1. **Fix in `scf.asm` ([`level1/modules/scf.asm`](file:///Users/richardlucente/development/git/nitros9/level1/modules/scf.asm#L881))**:
   Update `ReleaseDeviceIfOwned` so that when `V.BUSY` is cleared, it checks if `<D.Proc` has a non-zero `P$IOQN`. If so, clear `P$IOQN` and issue `os9 F$Send` with `B = #S$Wake` to wake up the sleeping child process.

2. **Fix in `shell_21.asm` ([`level1/cmds/shell_21.asm`](file:///Users/richardlucente/development/git/nitros9/level1/cmds/shell_21.asm#L860))**:
   Ensure `shell_21` releases standard device ownership (`ReleaseDevices`) before invoking `F$Wait` for child processes.
