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

## 2. Display and I/O Management (Dynamic)

The port is designed to be hardware-agnostic and adapt to various screen dimensions (e.g., 32x16, 40x24, 80x24, or 80x30).

### 2.1 Screen Size Detection
The interpreter determines the screen dimensions at runtime using the following priority:
1.  **Command-line Overrides:** If the user provides a size (e.g., `zip story.z3 40x24`), these values take precedence.
2.  **System Query:** The interpreter calls `I$GetStt` with function code `SS.ScSiz` ($26) on Path 1 (Stdout).
    - **Entry:** `A` = Path, `B` = `$26`.
    - **Exit:** `X` = Columns, `Y` = Rows.
3.  **Defaults:** Fallback to 80x24 if auto-detection fails or is unsupported by the driver.

### 2.2 Hardware Context
- **Global Variables:** `G_COLS` and `G_ROWS` store the detected dimensions.
- **Status Line Area:** Row 0 (Columns 0 to `G_COLS-1`).
- **Play Area:** Rows 1 to `G_ROWS-1`.
- **Character Encoding:** ASCII compatible.
- **Driver Convention:** Uses standard NitrOS-9 `I$Write` calls to the terminal path.

### 2.3 Terminal Control Codes (Abstraction)
The interpreter should use a table-driven approach for terminal control (e.g., Home, Move Cursor, Clear Screen) to allow easy adaptation to different terminal drivers.

### 2.4 Status Line Management
- **Visuals:** Row 0 must always appear in **Reverse Video**.
- **Update Cycle:**
    1.  Save cursor position or track manually.
    2.  Move cursor to `(0, 0)`.
    3.  Enable Reverse Video.
    4.  Print Room Name (left-aligned), Score/Moves (right-aligned).
    5.  Disable Reverse Video.
    6.  Restore cursor position.

### 2.5 Paging (`[more]` Logic)
- **Threshold:** Triggered when `LINCNT` reaches `G_ROWS-2` (leaving space for the bottom row).
- **Execution:** 
    - Print `[more]` at current cursor.
    - Wait for keypress via `I$Read` (Path 0).
    - Overwrite `[more]` with spaces and reset `LINCNT` to 1.

### 2.6 Critical Implementation: Custom Scrolling
Because standard drivers lack protected regions, a **Partial Screen Scroll** is mandatory to keep the Status Line (Row 0) static while the rest of the screen scrolls.

#### Method A: Driver-Assisted Scrolling (Preferred)
The most efficient "OS-9 way" is to use terminal escape sequences if the driver supports them:
1.  **Working Area (`CWArea`):** Send `1B 32 <x> <y> <w> <h>` to restrict the scrolling region to Rows 1-29. Subsequent Carriage Returns will then naturally scroll only this region.
2.  **Delete Line:** If `CWArea` is unavailable, manual scrolling can be achieved by moving the cursor to Row 1 and sending the **Delete Line** code (`1B 5B 4D` or `$1F $22` depending on driver). This shifts all lines below Row 1 up, leaving Row 0 untouched.

#### Method B: RAM Shadow Buffer (Portable Fallback)
For "dumb" terminals or basic Level 1 drivers that do not support line operations:
1.  **Allocation:** At startup, use `F$Mem` to allocate a `G_COLS * G_ROWS` byte buffer in the data area.
2.  **Tracking:** All characters sent to the screen are also mirrored into this buffer.
3.  **Manual Scroll:** 
    - When a scroll is needed, use a high-speed assembly loop (`LDU/STU`) to shift rows 2 through `G_ROWS-1` up by one row in the RAM buffer.
    - Fill the last row of the buffer with spaces.
    - Re-print the affected rows to the terminal.
4.  **Note:** While slower on serial terminals, this method is 100% portable across all NitrOS-9 platforms and drivers.

#### Method C: Direct Memory Access (CoCo 1/2 Level 1)
On Level 1 systems without an MMU, if the interpreter knows it is running on native hardware (e.g., a 32x16 VDG screen at `$0400`), it may directly manipulate the video RAM for maximum speed. This should be a last-resort, hardware-specific optimization.

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
- **Usage:** `zip <story_file_path> [<cols>x<rows>]`
- **Parameter Parsing:** 
    - At entry, register `X` points to the parameter area.
    - Extract the story pathlist (terminates at space or CR).
    - Optionally parse the screen size (e.g., `80x24`).
    - Call `I$Open` on the story path.

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
