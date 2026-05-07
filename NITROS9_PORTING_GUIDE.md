# COCOZIP to NitrOS-9 Porting Guide (Consolidated Specification)

This document provides a comprehensive technical blueprint for porting the COCOZIP Z-machine interpreter from its original standalone disk-based environment to the NitrOS-9 operating system (Level 1 and Level 2).

---

## 1. Process and Memory Architecture (Level 1 Optimized)

The port is designed to run within a standard 64K NitrOS-9 logical address space, sharing memory with the kernel and other resident modules.

### 1.1 Partitioning the Z-Machine State
- **Interpreter (Shared Code):** Implemented as a re-entrant NitrOS-9 Program Module (`PrgMod`). This module is loaded into high RAM by the OS-9 shell.
- **Process Data Area:** Private segment (allocated via `F$Mem`) containing the Z-Stack (512 bytes), Global Variables (480 bytes), Local Variables (32 bytes), and I/O buffers.
- **Story Data (Minimal Preload):** Only the most critical part of the Z-code (Z-Header and initial data, ~4-8KB) is kept resident in the data area.
- **Paging Window:** A single 2KB or 4KB RAM buffer used to cache Z-code pages from the story file via standard `I$Seek`/`I$Read`.

### 1.2 Logical Memory Map (Target)
| Logical Address | Segment | Description |
| :--- | :--- | :--- |
| `$0000` - `$0FFF` | Data Area | Z-Variables, Stack, Buffers, Interpreter Vars |
| `$1000` - `$2FFF` | Story Preload | Minimal static Z-code (~8KB) |
| `$3000` - `$3FFF` | **Paging Window** | RAM Buffer for dynamic Z-code (4KB) |
| `Top of Mem`     | Program Module | Interpreter Code (Loaded by OS-9) |
| `$E000` - `$FFFF` | System | OS-9 Vectors and Reserved System Area |

---

## 2. Display and I/O Management (Detailed)

The port targets an 80x30 resolution and uses a hardware-independent abstraction for terminal control.

### 2.1 Hardware Context
- **Resolution:** 80 columns x 30 rows.
- **Status Line Area:** Row 0 (Columns 0 - 79).
- **Play Area:** Rows 1 - 29.
- **Character Encoding:** ASCII compatible.
- **Driver Convention:** Uses standard NitrOS-9 `I$Write` calls to the terminal path (Path 1).

### 2.2 Terminal Control Codes (Abstraction)
The interpreter should use a table-driven approach for terminal control (e.g., Home, Move Cursor, Clear Screen) to allow easy adaptation to different terminal drivers (VDG, GrfDrv, or FNX).

### 2.3 Status Line Management
- **Visuals:** Row 0 must always appear in **Reverse Video**.
- **Update Cycle:**
    1.  Save cursor position (if supported by driver) or track manually.
    2.  Move cursor to `(0, 0)`.
    3.  Enable Reverse Video.
    4.  Print Room Name (left-aligned), Score/Moves (right-aligned).
    5.  Disable Reverse Video.
    6.  Restore cursor position.

### 2.4 Paging (`[more]` Logic)
- **Threshold:** Triggered when `LINCNT` reaches the bottom of the defined play area.
- **Execution:** 
    - Print `[more]` at current cursor.
    - Wait for keypress via `I$Read` (Path 0).
    - Overwrite `[more]` with spaces and reset `LINCNT`.

### 2.5 Critical Implementation: Custom Scrolling
Because standard drivers lack protected regions, a **Partial Screen Scroll** is mandatory:
- **Detection:** Intercept characters that would cause the cursor to move past the last row of the play area.
- **Mechanism:**
    1.  Shift memory for play area rows up by one.
    2.  Fill the now-empty last row with spaces.
    3.  Reset cursor to the start of the last row.
- **Safety:** Ensure the Status Line (Row 0) is **never** included in the shift.

---

## 3. Virtual Memory and Paging (File-Based)

To support NitrOS-9 Level 1 and standard 64K CoCo 2 hardware, the interpreter uses a file-backed paging system.

### 3.1 Strategy: Buffered File Access
1.  **File Handle:** Keep the story file path open throughout the execution.
2.  **Preload:** Load the first ~8KB of the story directly into the `$1000-$2FFF` region at startup. This ensures the Z-Header and core global data are always resident.
3.  **Paging Window:** A 4KB RAM buffer (16 Z-pages) at `$3000` acts as a sliding window.
4.  **Demand Paging:** When the Z-machine requests a page outside the preload:
    - Check if the requested virtual address is already in the `$3000` buffer.
    - If not, calculate the 32-bit file offset: `Offset = Virtual_Page * 256`.
    - Call `I$Seek` (Function `$88`) to position the file pointer.
    - Call `I$Read` (Function `$89`) to load 4KB into the buffer.
    - Update the `CURRENT_WINDOW_BASE` tracking variable.

### 3.2 Address Translation (Z-Page to Logical)
1.  **If Page < ZPURE:** Address = `$1000 + (Page * 256)`.
2.  **If Page >= ZPURE:**
    - Is `(Page * 256)` within `[Window_Offset, Window_Offset + 4096)`?
    - If No: Perform `I$Seek`/`I$Read` to refresh window.
    - Address = `$3000 + ((Page * 256) % 4096)`.

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

---

## 5. Redundant Legacy Functionality (Retirement List)

The following original CoCo 2 standalone code must be **removed**:
- **ROM Banking:** `ROMIN`, `ROMOUT`.
- **Disk Geometry:** `UDIV`, `GETDSK`.
- **Hardware Drivers:** `MYCON` (Disk), `MYCAT` (Keyboard), `MYCHR` (Screen).
- **Interrupts:** `DIRQSV`.

---

## 6. Command Line Interface

The interpreter acts as a standard shell utility.
- **Usage:** `zip <story_file_path>`
- **Parameter Parsing:** 
    - At entry, register `X` points to the parameter area.
    - Extract the pathlist, terminating at a space or CR.
    - Call `I$Open` on this path.

---

## 7. Execution Summary

### 7.1 Startup Sequence
1.  **Launch:** Shell calls `F$Fork`.
2.  **Init:** Parse story pathname from parameter area.
3.  **Load:** Open story file, keep path open for paging.
4.  **Preload:** Read the initial static Z-code into the data area.
5.  **Warmstart:** Initialize Z-machine state and begin execution loop.

### 7.2 Termination Sequence
1.  **Files:** Close all open file paths.
2.  **Exit:** Terminate process via `F$Exit`.

---

## 8. Level 1 Memory Footprint (CoCo 2)

On a Level 1 system, the 64K map is shared by the Kernel, File Managers (RBF, SCF), Device Drivers, the Shell, and other resident modules.

### 8.1 Minimizing Resident State
- **Static Allocation:** Only the most critical Z-machine state is kept at fixed addresses.
- **Dynamic Growth:** The interpreter uses `F$Mem` at startup to request exactly the amount of RAM needed for the Preload and Paging Window.

### 8.2 Code vs. Data
- The interpreter code is a **Program Module**. OS-9 loads this module into high RAM.
- The **Data Area** (where we store the preload and buffers) begins at the address returned by the shell or the base of the process's data memory.
