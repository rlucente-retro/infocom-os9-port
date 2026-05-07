# COCOZIP to NitrOS-9 Porting Guide (Consolidated Specification)

This document provides a comprehensive technical blueprint for porting the COCOZIP Z-machine interpreter from its original standalone disk-based environment to the NitrOS-9 Level 2 operating system.

---

## 1. Process and Memory Architecture

The port leverages the NitrOS-9 Level 2 MMU to separate executable code from volatile game state and large story assets.

### 1.1 Partitioning the Z-Machine State
- **Interpreter (Shared Code):** Implemented as a re-entrant NitrOS-9 Program Module (`PrgMod`). This allows multiple processes to share the same physical RAM for code.
- **Process Data Area:** Private segment (allocated via `F$Mem`) containing the Z-Stack (512 bytes), Global Variables (480 bytes), Local Variables (32 bytes), and I/O buffers.
- **Story Data:** Stored in high RAM (System RAM blocks) using `F$SRqMem`, managed independently of the 64K process space.

### 1.2 Logical Memory Map
| Logical Address | Segment | Description |
| :--- | :--- | :--- |
| `$0000` - `$1FFF` | Data Area | Z-Variables, Stack, Buffers, Interpreter Vars |
| `$2000` - `$7FFF` | Story Area | Static "Preload" (Mapped once at startup) |
| `$8000` - `$9FFF` | **Paging Window** | Dynamic 8KB MMU Mapping (`F$MapBlk`) |
| `$A000` - `$DFFF` | Program Module | Read-only shared Interpreter Code |
| `$E000` - `$FFFF` | System | OS-9 Vectors and Reserved System Area |

---

## 2. Display and I/O Management (Detailed)

The port targets an 80x30 resolution and uses the **FNX6809 DisplayCodes** for hardware independence.

### 2.1 Hardware Context
- **Resolution:** 80 columns x 30 rows.
- **Status Line Area:** Row 0 (Columns 0 - 79).
- **Play Area:** Rows 1 - 29.
- **Character Encoding:** ASCII compatible character set using **FNX6809 DisplayCodes**.
- **Driver Convention:** Uses +32 offset for coordinates (e.g., Column 0 = `$20`).

### 2.2 FNX6809 DisplayCodes Table
| Code (Hex) | Description | Parameters |
| :--- | :--- | :--- |
| `0x01` | Home Cursor | None |
| `0x02` | Move Cursor | `<X+32> <Y+32>` |
| `0x03` | Erase Line | None |
| `0x04` | Erase to EOL | None |
| `0x05` | Cursor Ctrl | `0x20` (Off), `0x21` (On) |
| `0x0C` | Clear Screen | None (Homes cursor) |
| `0x0D` | Carriage Return| Returns cursor to Column 0 |
| `0x1B 0x20` | Set Window | `CPX, CPY, SZX, SZY, STY, FG, BG, BD` |
| `0x1F 0x20` | Reverse On | Swaps Foreground and Background |
| `0x1F 0x21` | Reverse Off| Returns to normal attributes |

### 2.3 Status Line Management
- **Visuals:** Row 0 must always appear in **Reverse Video** (`0x1F 0x20`).
- **Update Cycle:**
    1.  Save cursor position (`0x02` query or manual tracking).
    2.  Move cursor to `(0, 0)` using `0x02 0x20 0x20`.
    3.  Enable Reverse Video (`0x1F 0x20`).
    4.  Print Room Name (left-aligned), Score/Moves (right-aligned).
    5.  Disable Reverse Video (`0x1F 0x21`).
    6.  Restore cursor position.

### 2.4 Paging (`[more]` Logic)
- **Threshold:** Triggered when `LINCNT` reaches **28**.
- **Execution:** 
    - Print `[more]` at current cursor.
    - Wait for keypress via `I$Read` (Path 0).
    - Overwrite `[more]` with spaces and reset `LINCNT`.

### 2.5 Critical Implementation: Custom Scrolling
Because standard drivers lack protected regions, a **Partial Screen Scroll** is mandatory:
- **Detection:** Intercept characters that would cause the cursor to move past Row 29.
- **Mechanism:**
    1.  Shift memory for Rows 2-29 up to Rows 1-28.
    2.  This must be done via direct memory access to the video buffer or by reading/writing rows back to the driver if direct access is restricted.
    3.  Fill Row 29 with spaces (`0x20`).
    4.  Reset cursor to the start of Row 29.
- **Safety:** Ensure Row 0 is **never** included in the shift.

---

## 3. Virtual Memory and Paging (Detailed)

NitrOS-9 eliminates synchronous disk swapping by caching the story file in system memory.

### 3.1 Strategy: Full Memory Residency
1.  **Allocation:** Use `F$SRqMem` to request enough physical RAM blocks (8KB each) to hold the entire file.
2.  **Loading:** Use standard `I$Read` to populate these blocks during initialization.
3.  **Mapping:** Map the first 24KB of the story (Preload) permanently to `$2000-$7FFF`.
4.  **MMU Swapping:** For pages > `ZPURE`:
    - Calculate `Block_Idx = Virtual_Page / 32`.
    - If not currently in the window, call `F$ClrBlk` then `F$MapBlk` for the required physical block into `$8000`.

### 3.2 Fallback: Seek/Read Buffer Pool (Low RAM)
If total system RAM is insufficient to hold the entire file:
- Allocate a smaller buffer pool (e.g., 4-8 pages of 8KB) in the process space.
- Use `I$Seek` (32-bit offset) and `I$Read` to swap chunks from the story file into these buffers as needed.
- **Note:** This bypasses the original CoCo's Track/Sector math in favor of standard file offsets.

### 3.3 Address Translation (Z-Page to Logical)
- **Page Size:** 256 Bytes.
- **Block Index:** `Virtual_Page / 32`.
- **Offset within 8KB Block:** `(Virtual_Page * 256) % 8192`.
- **Logical Address:** `Segment_Base + Offset`.

---

## 4. File-Based Save/Restore (Detailed)

Replaces raw sector writing with named files.

### 4.1 Binary Save Layout
| Offset (Hex) | Size | Description |
| :--- | :--- | :--- |
| `$0000` | 2 | **Game ID:** From `ZCODE + ZID` |
| `$0002` | 2 | **OZSTAK:** Saved stack pointer from Z-Machine |
| `$0004` | 2 | **Stack Pointer:** Hardware `U` register |
| `$0006` | 1 | **ZPC High:** Program Counter MSB |
| `$0007` | 2 | **ZPC Low:** Program Counter LSBs |
| `$0009` | 23| **Reserved:** Future metadata |
| `$0020` | 32| **Locals:** 15 variables + frame info |
| `$0040` | 512| **Z-Stack:** Current Z-machine stack data |
| `$0240` | Var | **Preload:** `(ZPURBT + 1) * 256` bytes |

### 4.2 I/O Sequence
- **Save:** `I$Create` -> `I$Write` (Header) -> `I$Write` (Locals) -> `I$Write` (Stack) -> `I$Write` (Preload) -> `I$Close`.
- **Restore:** `I$Open` -> `I$Read` (Header) -> Verify ID -> `I$Read` (Data) -> `I$Close`.
- **Error Handling:** Standard NitrOS-9 error codes are reported via `F$Perr`.

---

## 5. Redundant Legacy Functionality (Retirement List)

The following original CoCo 2 code must be **removed**:

### 5.1 Removed Subsystems
- **ROM Banking:** `ROMIN`, `ROMOUT` are obsolete.
- **Disk Geometry:** `UDIV`, `GETDSK`, and track/sector skipping logic are removed.
- **Hardware Drivers:** `MYCON` (Disk Controller) and `MYCAT` (Keyboard Matrix scan) are replaced by OS-9 system calls.
- **Interrupts:** `DIRQSV` (IRQ/NMI hooks) is no longer required as no low-level hardware routines are performed.
- **RBF Direct Access:** The interpreter does not use RBF descriptors or raw sector access. All story data is handled via the file system (`I$Open/Read`) or pre-allocated RAM.

---

## 6. Command Line Interface

The interpreter acts as a standard shell utility.

- **Usage:** `zip <story_file_path>`
- **Parameter Parsing:** 
    - At entry, register `X` points to the parameter area.
    - Extract the pathlist, terminating at a space or CR.
    - Call `I$Open` on this path. If it fails, report the error via `F$Perr` and exit.

---

## 7. Execution Summary

### 7.1 Startup Sequence
1.  **Launch:** Shell calls `F$Fork`.
2.  **Init:** Parse story pathname from parameter area.
3.  **Load:** Open story file, allocate RAM, and load blocks into memory.
4.  **Map:** Set MMU registers for static preload.
5.  **Warmstart:** Initialize Z-machine state and begin execution loop.

### 7.2 Termination Sequence
1.  **Memory:** Release all `F$SRqMem` allocated blocks via `F$SRtMem`.
2.  **Files:** Close all open file paths (Save files, Log files).
3.  **Exit:** Terminate process via `F$Exit`.
