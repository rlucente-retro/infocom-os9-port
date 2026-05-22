# COCOZIP to NitrOS-9 Porting Guide (Consolidated Specification)

This document provides a comprehensive technical blueprint for porting the COCOZIP Z-machine interpreter from its original standalone disk-based environment to the NitrOS-9 operating system (Level 1 and Level 2).

---

## 1. Process and Memory Architecture (OS-9 Native)

The port follows the standard NitrOS-9 process model, utilizing the kernel's memory management to allocate and protect resources.

### 1.1 Data Area Allocation
- **Module Header:** The interpreter's Program Module header defines the required static data area size (e.g., 1024 bytes).
- **F$Fork / F$Chain:** When the shell launches the interpreter, the kernel allocates this initial data area.
- **Dynamic Allocation (F$Mem):** At startup, the interpreter calls `F$Mem` to expand its data area to accommodate the large file buffers (`pagesz * numpg`).
- **Process Data Area:** This area (accessible via offsets from the data pointer `U`) contains:
    - **Global State:** `cur_cols`, `cur_rows`, `cur_x`, `cur_y`, `page_lines`, `was_cr`.
    - **Transient Buffers:** `display_codes` (3 bytes for escape sequences), `dev_opts` (32 bytes for terminal status).
    - **Z-Machine Buffers:** Pointers to the dynamic memory blocks for story preload and paging.

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
1.  **Command-line Overrides:** Parses the parameter area (at `X`) for strings like `80x24`.
2.  **System Query:** Calls `I$GetStt` with `SS.ScSiz` ($26) on Path 1.
3.  **Defaults:** Fallback to 32x16 if detection fails.

**Note on 32x16 (VDG) Compatibility:**
If 32x16 is detected, the interpreter must verify that the terminal driver supports reverse video (required for the status line). This is done by:
1.  Calling `F$Link` for the `TERM` device descriptor.
2.  Checking the byte at offset `$26` (VDG type/options).
3.  If the value is not `$02` (Reverse Video), the interpreter should abort with an error message, as the standard VDG T1 mode is insufficient.

### 2.2 Hardware Context
- **Global Variables:** `cur_cols` and `cur_rows` store the detected dimensions.
- **Status Line Area:** Row 0 (Columns 0 to `cur_cols-1`).
- **Play Area:** Rows 1 to `cur_rows-1`.
- **Character Encoding:** ASCII compatible.
- **Driver Convention:** Uses standard NitrOS-9 `I$Write` calls to the terminal path.

### 2.3 Terminal Control Codes (Abstraction)
The prototype uses standard NitrOS-9 VDG terminal escape sequences:
- **Move Cursor:** `$02 <col+32> <row+32>`.
- **Clear Screen:** `$0C` (Form Feed).
- **Reverse Video:** On VDG screens, characters with the high bit set (`$80-$FF`) appear in reverse video. For other terminals, standard ANSI or driver-specific sequences must be substituted.

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
- **Threshold:** Triggered when `page_lines` reaches `cur_rows-2` (leaving space for the bottom row).
- **Execution:** 
    - Print `[more]` at current cursor.
    - Wait for keypress via `I$Read` (Path 0).
    - Overwrite `[more]` with spaces and reset `page_lines` to 1.

### 2.6 Critical Implementation: Custom Scrolling
Because standard drivers lack protected regions, a **Partial Screen Scroll** is mandatory to keep the Status Line (Row 0) static while the rest of the screen scrolls.

#### Method A: Driver-Assisted Scrolling (Preferred)
The most efficient "OS-9 way" is to use terminal escape sequences if the driver supports them:
1.  **Working Area (`CWArea`):** Send `1B 32 <x> <y> <w> <h>` to restrict the scrolling region to Rows 1-29. Subsequent Carriage Returns will then naturally scroll only this region.
2.  **Delete Line:** If `CWArea` is unavailable, manual scrolling can be achieved by moving the cursor to Row 1 and sending the **Delete Line** code (`1B 5B 4D` or `$1F $22` depending on driver). This shifts all lines below Row 1 up, leaving Row 0 untouched.

#### Method B: RAM Shadow Buffer (Portable Fallback)
For "dumb" terminals or basic Level 1 drivers that do not support line operations:
1.  **Allocation:** At startup, use `F$Mem` to allocate a `cur_cols * cur_rows` byte buffer in the data area.
2.  **Tracking:** All characters sent to the screen are also mirrored into this buffer.
3.  **Manual Scroll:** 
    - When a scroll is needed, use a high-speed assembly loop (`LDU/STU`) to shift rows 2 through `cur_rows-1` up by one row in the RAM buffer.
    - Fill the last row of the buffer with spaces.
    - Re-print the affected rows to the terminal.
4.  **Note:** While slower on serial terminals, this method is 100% portable across all NitrOS-9 platforms and drivers.

#### Method D: Redraw Status Line on Scroll (Current Prototype)
A lightweight alternative for drivers without windowing or line deletion:
1.  **Trigger:** When `cur_y` reaches `cur_rows - 2`, move the cursor to `(0, cur_rows-1)`.
2.  **Scroll:** Send an ASCII LF (`$0A`). This scrolls the entire screen up.
3.  **Restore:** Immediately move the cursor to `(0, 0)` and redraw the Status Line (Row 0).
4.  **Sync:** Move the cursor back to the start of the "new" bottom line (still `cur_rows - 2`) to continue output.

---

## 3. System Services and Signal Handling

### 3.1 Signal Interception
To ensure clean termination and handle user interrupts (e.g., `Ctrl-C` / `Keyboard Abort`), the interpreter must establish a signal trap:
1.  **Setup:** Call `F$Icpt` with the address of a signal handler routine.
2.  **Handler:** The handler should typically close open paths and exit via `F$Exit`.

### 3.2 Terminal State Management
During blocking input operations (like `[more]` paging):
1.  **Echo Control:** Use `I$GetStt`/`I$SetStt` with `SS.Opt` to temporarily disable terminal echo (`PD.EKO`) so that the paging keypress doesn't appear on screen.
2.  **Restoration:** Always restore the original terminal options after the keypress is received.

---

## 4. Virtual Memory and Paging (File-Based)

To support standard 64K hardware, the interpreter uses a file-backed paging system.

### 4.1 Strategy: Buffered File Access
1.  **File Handle:** Keep the story file path open throughout the execution.
2.  **Preload:** Load the first ~8KB of the story directly into the reserved space in the data area at startup. This ensures the Z-Header and core global data are always resident.
3.  **Paging Window:** A 4KB RAM buffer (16 Z-pages) reserved in the data area acts as a sliding window.
4.  **Demand Paging:** When the Z-machine requests a page outside the preload:
    - Check if the requested virtual address is already in the buffer.
    - If not, calculate the 32-bit file offset: `Offset = Virtual_Page * 256`.
    - Call `I$Seek` (Function `$88`) to position the file pointer.
    - Call `I$Read` (Function `$89`) to load 4KB into the buffer.
    - Update the tracking variable for the current window base.

### 4.2 Address Translation (Z-Page to Logical)
1.  **If Page < ZPURE:** Address = `PRELOAD_BASE + (Page * 256)`.
2.  **If Page >= ZPURE:**
    - Is `(Page * 256)` within the current window?
    - If No: Perform `I$Seek`/`I$Read` to refresh window.
    - Address = `WINDOW_BASE + ((Page * 256) % 4096)`.

---

## 5. File-Based Save/Restore (Detailed)

Replaces raw sector writing with named files.

### 5.1 Binary Save Layout
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

### 5.2 I/O Sequence
- **Save:** `I$Create` -> `I$Write` (Header) -> `I$Write` (Locals) -> `I$Write` (Stack) -> `I$Write` (Preload) -> `I$Close`.
- **Restore:** `I$Open` -> `I$Read` (Header) -> Verify ID -> `I$Read` (Data) -> `I$Close`.

---

## 6. Redundant Legacy Functionality (Retirement List)

The following original CoCo 2 standalone code must be **removed**:
- **ROM Banking:** `ROMIN`, `ROMOUT`.
- **Disk Geometry:** `UDIV`, `GETDSK`.
- **Hardware Drivers:** `MYCON` (Disk), `MYCAT` (Keyboard), `MYCHR` (Screen).
- **Interrupts:** `DIRQSV`.

---

## 7. Command Line Interface

The interpreter acts as a standard shell utility.
- **Usage:** `zip <story_file_path> [<cols>x<rows>]`
- **Parameter Parsing:** 
    - At entry, register `X` points to the parameter area.
    - Extract the story pathlist (terminates at space or CR).
    - Optionally parse the screen size (e.g., `80x24`).
    - Call `I$Open` on the story path.

---

## 8. Execution Summary

### 8.1 Startup Sequence
1.  **Launch:** Shell calls `F$Fork`.
2.  **Init:** Parse story pathname from parameter area.
3.  **Load:** Open story file, keep path open for paging.
4.  **Preload:** Read the initial static Z-code into the reserved data area.
5.  **Warmstart:** Initialize Z-machine state and begin execution loop.

### 8.2 Termination Sequence
1.  **Files:** Close all open file paths.
2.  **Exit:** Terminate process via `F$Exit`.
