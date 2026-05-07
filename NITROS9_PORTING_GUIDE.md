# COCOZIP to NitrOS-9 Porting Guide (Consolidated Specification)

This document provides a comprehensive technical blueprint for porting the COCOZIP Z-machine interpreter from its original standalone disk-based environment to the NitrOS-9 operating system (Level 1 and Level 2).

---

## 1. Process and Memory Architecture (OS-9 Native)

The port follows the standard NitrOS-9 process model, utilizing the kernel's memory management to allocate and protect resources.

### 1.1 Data Area Allocation
- **Module Header:** The interpreter's Program Module header defines the required data area size (storage).
- **F$Fork / F$Chain:** When the shell launches the interpreter, the kernel allocates a data area of the size specified in the module header.
- **Process Data Area:** This area (accessible via offsets from the data pointer) contains:
    - **Z-Machine State:** Variables, Z-Stack, and I/O buffers.
    - **Story Preload:** A reserved block for the resident part of the Z-code (~4-8KB).
    - **Paging Window:** A 4KB RAM buffer used for demand paging.

### 1.2 Logical Memory Map (Conceptual)
The logical address space of the process is organized by the kernel at runtime.

| Logical Region | Description |
| :--- | :--- |
| **Data Area** | Starts at `$0000` (relative to process). Contains variables, stacks, preload, and paging buffers. |
| **Program Module** | The executable code, loaded by the kernel. Can occupy memory up to `$FEFF`. |
| **System Area** | `$FF00` - `$FFFF`. Reserved for I/O and System Vectors. |

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
The interpreter should use a table-driven approach for terminal control (e.g., Home, Move Cursor, Clear Screen) to allow easy adaptation to different terminal drivers.

### 2.3 Status Line Management
- **Visuals:** Row 0 must always appear in **Reverse Video**.
- **Update Cycle:**
    1.  Save cursor position or track manually.
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

To support standard 64K hardware, the interpreter uses a file-backed paging system.

### 3.1 Strategy: Buffered File Access
1.  **File Handle:** Keep the story file path open throughout the execution.
2.  **Preload:** Load the first ~8KB of the story directly into the reserved space in the data area at startup. This ensures the Z-Header and core global data are always resident.
3.  **Paging Window:** A 4KB RAM buffer (16 Z-pages) reserved in the data area acts as a sliding window.
4.  **Demand Paging:** When the Z-machine requests a page outside the preload:
    - Check if the requested virtual address is already in the buffer.
    - If not, calculate the 32-bit file offset: `Offset = Virtual_Page * 256`.
    - Call `I$Seek` (Function `$88`) to position the file pointer.
    - Call `I$Read` (Function `$89`) to load 4KB into the buffer.
    - Update the tracking variable for the current window base.

### 3.2 Address Translation (Z-Page to Logical)
1.  **If Page < ZPURE:** Address = `PRELOAD_BASE + (Page * 256)`.
2.  **If Page >= ZPURE:**
    - Is `(Page * 256)` within the current window?
    - If No: Perform `I$Seek`/`I$Read` to refresh window.
    - Address = `WINDOW_BASE + ((Page * 256) % 4096)`.

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
4.  **Preload:** Read the initial static Z-code into the reserved data area.
5.  **Warmstart:** Initialize Z-machine state and begin execution loop.

### 7.2 Termination Sequence
1.  **Files:** Close all open file paths.
2.  **Exit:** Terminate process via `F$Exit`.
