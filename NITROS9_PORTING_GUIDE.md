# NitrOS-9 Z-Machine Interpreter (infocom) Porting and Implementation Reference

This document serves as the technical reference for the completed port of the Infocom Z-machine interpreter (ZIP) to the NitrOS-9 operating system (Level 1 and Level 2).

---

## 1. Process and Memory Architecture

The interpreter is built on the NitrOS-9 native process model. All code is position-independent and reentrant, using the `U` register to locate the dynamically allocated process workspace.

### 1.1 Stack Pointer Safety and Dynamic Memory Expansion Sequence (`F$Mem`)
Under NitrOS-9, the stack pointer `S` is initialized by the kernel to the top of the initial memory block allocated for the process (which is at least `STATIC_SIZE` bytes, but can be larger due to system page alignment limits on Level 2). To prevent stack corruption and avoid dangerous stack relocations:
1.  **Dynamic Stack Boundary Detection:** At startup, the interpreter queries the initial memory block size via `F$Mem` (using `D = 0`). The returned size is saved in `zcode_offset`, establishing a safe stack boundary below which the system stack and variables reside.
2.  **Preload Base Allocation:** The story preload base `zcode_ptr` is dynamically mapped to `U + zcode_offset`. This places all loaded Z-code and swapping buffers entirely above the stack area, guaranteeing stack safety on both Level 1 and Level 2 without relocating the stack pointer.
3.  **Header Loading:** The interpreter expands memory to `zcode_offset + 256` bytes to load the first 256 bytes of the Z-code story header.
4.  **Size Detection:** It extracts the boundary of the dynamic story segment (`ZENDLD` offset `4`) to calculate the size of the preload data (`ZPURE = ZENDLD + 1` pages).
5.  **Target Paging Allocation:** The interpreter tries to allocate memory for the entire `ZPURE` preload plus 16 swapping pages relative to the stack boundary (total size `zcode_offset` + `(ZPURE + 16) * 256` bytes). If this fails, it falls back to a minimum memory requirement of `ZPURE + 8` swapping pages.
6.  **Optimal Expansion:** Starting from the successfully allocated base, the interpreter runs an incremental loop, requesting 1 more page (256 bytes) via `F$Mem` in each iteration until it reaches a maximum of `ZPURE + 160` pages, or the allocation fails.
7.  **Parameter Configuration:** The interpreter sets:
    -   `PAGE0,u` (the RAM page MSB of the swapping buffer start) immediately following the preload area.
    -   `PMAX,u` (the total number of swapping page slots) as `Total dynamic pages - ZPURE` (where total dynamic pages is computed by subtracting `zcode_offset` from the total allocated memory).

---

## 2. Display and Terminal I/O Management

To accommodate different terminal drivers and screens (VDG 32x16, 40-column, 80-column), the display sub-system is dynamically configured at runtime.

### 2.1 Screen Dimension Resolution
The interpreter determines the screen rows and columns in the following order of priority:
1.  **Command-Line Parameter:** Parses the parameter area pointed to by `X` at entry for resolution strings (e.g. `80x24`, `32x16`).
2.  **OS-9 System Query:** If no override is provided, it performs an `I$GetStt` status call with `SS.ScSiz` (`$26`) on stdout (Path 1).
3.  **Default Fallback:** Defaults to a standard 32x16 terminal.

**Validation Check:** If the resolved dimensions are smaller than 10 columns by 4 rows, the interpreter aborts immediately.

### 2.2 VDG Reverse Video Support
When running on Level 1 systems with a 32x16 VDG screen, the status line requires reverse video support. The interpreter:
1.  Calls `F$Link` for the `TERM` device descriptor.
2.  Checks the VDG type/options byte at offset `$26`.
3.  If the value is not `$02` (which enables reverse video capabilities on VDG), the program prints an error and exits cleanly.

### 2.3 Terminal Codes Abstraction
To print characters in reverse video, the interpreter uses a function vector `prtinv_vec` populated during initialization:
*   **Level 1 (VDG):** Maps uppercase characters to lowercase (which are represented as inverse on a standard VDG text screen) and uses character `$80` for inverted spaces.
*   **Level 2 (ANSI/VT100 Windowing):** Emits standard escape code sequences: `REVON` (`$1F $20`) and `REVOFF` (`$1F $21`).

### 2.4 Status Line Rendering (Row 0)
The status bar (containing room name, score, and moves or time) is printed at Row 0 using reverse video. The interpreter manually moves the cursor to `(0, 0)`, outputs the rooms and score string left- and right-aligned, and then restores the cursor to the text input position.

### 2.5 Word-Wrapping and Scrolling
- **Text PAUSE (`[more]` logic):** When the output line counter reaches `cur_rows-2`, the output pauses and prompts the user with `[more]` in inverse video. The terminal input echo is temporarily disabled (`PD.EKO`), a single key is read from Path 0, the echo is restored, and the `[more]` text is cleared.
- **Partial-Screen Scroll:** To keep the status line on Row 0 untouched when the text scrolls, the interpreter:
  1.  Moves the cursor to `(0, cur_rows-1)` when it reaches the bottom boundary.
  2.  Sends an ASCII LF (`$0A`) to scroll the entire screen up.
  3.  Immediately moves the cursor to `(0, 0)` and redrafts the reverse-video Status Line.
  4.  Moves the cursor back to the bottom line to continue output.

---

## 3. Dynamic File-Paging System

Paging Z-code from the story file is managed through a table-based Least Recently Used (LRU) paging scheme.

### 3.1 LRU Buffer Management
The paging system tracks buffers through two structures located in the workspace:
*   `PTABLE`: Maps the page slot index to its current resident Z-code page number (2 bytes per entry).
*   `LRUMAP`: Tracks timestamps for each page buffer (1 byte per entry).

### 3.2 Demand Swapping (`PAGE` and `GETDSK`)
When the interpreter requests a Z-code byte:
1.  **Preload Check:** If the requested page is less than `ZPURE`, it is accessed directly from the memory-resident preload at `zcode_ptr,u`.
2.  **Cache Lookup:** If the page is `>= ZPURE`, the interpreter searches `PTABLE` to check if the page is already cached in RAM.
    -   *Hit:* The page's timestamp in `LRUMAP` is updated to the current `STAMP` value.
    -   *Miss:* The page must be swapped into RAM:
        1.  The interpreter runs `EARLY` to search `LRUMAP` and locate the least recently used page buffer.
        2.  It updates `PTABLE` with the new page assignment.
        3.  It calculates the 32-bit file offset: `Offset = DBLOCK * 256`.
        4.  It calls `I$Seek` to position the file pointer inside the open story file path (`path_num`).
        5.  It calls `I$Read` to load exactly 256 bytes into the target buffer.
3.  **Address Translation:** The absolute address is calculated: `Buffer_Start + (Buffer_Index * 256) + Page_Offset`.

---

## 4. File-Based Save/Restore

The original standalone track-and-sector disk writing is replaced by standard named save files.

### 4.1 Save State Layout (File Structure)
The save state is written as a contiguous binary file structured as follows:

| Offset (Hex) | Size (Bytes) | Description |
|:---|:---|:---|
| `$0000` | 32 | **Header Data Buffer:** Stores the Game ID (`ZID`), `OZSTAK`, stack pointer `Y`, program counters `ZPCH`/`ZPCM`/`ZPCL`, and metadata padding. |
| `$0020` | 510 | **Z-Stack:** The dynamic Z-machine stack space. |
| `$021E` | `ZPURE * 256` | **Impure Game State Preload:** Dynamic memory variables and writeable game data. |

### 4.2 Save/Restore I/O Sequence
- **Save Operation:**
  1.  Prompts the user for a filename and reads it into `BUFSAV`.
  2.  Creates the file via `I$Create` with Read/Write permissions.
  3.  Copies state registers into `LOCALS` and writes the 32-byte header.
  4.  Writes the 510-byte `ZSTACK`.
  5.  Writes `ZPURE * 256` bytes of the dynamic preload.
  6.  Closes the file via `I$Close`.
- **Restore Operation:**
  1.  Prompts the user for a filename.
  2.  Opens the file via `I$Open` in Read mode.
  3.  Reads the 32-byte header and verifies the Game ID matches `ZID`.
  4.  Reads the 510-byte `ZSTACK` and the `ZPURE * 256` bytes of preload.
  5.  Closes the file via `I$Close`, restores state registers, and invalidates the program counter cache (`ZPCFLG`).

---

## 5. Retired Standalone Code

The following modules, hardware-specific entry points, and ROM-dependent routines from the original DECB version have been **completely retired** and removed from the codebase:

*   **ROM Management (`ROMON`/`ROMOFF`):** Replaced by standard OS-9 process address isolation.
*   **Direct Hardware Disk Control (`MYCON`/`DSKCON`):** Disk operations are handled via the OS-9 file manager filesystem calls (`I$Seek`/`I$Read`/`I$Write`).
*   **Low-Level Interrupts (`DIRQSV`):** Replaced by OS-9 kernel process scheduling.
*   **Direct Keyboard Matrix Scanning (`MYCAT`/`POLCAT`):** Keyboard input is handled via standard console stream reads (`I$Read` on Path 0).
*   **Hardcoded Video RAM Rendering (`MYCHR`/`CHROUT`):** Text output is rendered via standard console output writes (`I$Write` on Path 1).
