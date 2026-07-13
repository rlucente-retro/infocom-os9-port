# NitrOS-9 Z-Machine Interpreter (infocom)

This repository contains the NitrOS-9 (Level 1 and Level 2) native port of the Infocom Z-machine interpreter (ZIP). 

The interpreter runs as a standard user process under the NitrOS-9 operating system, supporting Infocom Version 3 Z-code games (such as *Zork I, II, III*, *Planetfall*, *The Witness*, *Deadline*, etc.) loaded directly from the OS-9 filesystem.

---

## Architectural Features

*   **OS-9 Native Process model:** Position-independent, reentrant architecture using the `U` register to address the dynamic process data area.
*   **Dynamic LRU Memory Paging:** At startup, the interpreter queries the kernel for memory via `F$Mem`. It dynamically scales its swapping space from a minimum of 8 pages (2KB) up to 160 pages (40KB), caching story file pages using a Least Recently Used (LRU) eviction policy.
*   **File-System Integration:** Story file blocks are paged dynamically from disk using standard OS-9 filesystem requests (`I$Seek` / `I$Read`).
*   **Adaptive Terminal Formatting:** Detects terminal dimensions at runtime via the `SS.ScSiz` status query. It dynamically wraps text, displays a reverse-video status bar on Row 0, and handles `[more]` paging automatically.
*   **File-Based Save/Restore:** Replaces track/sector-based saves with standard named save files in the OS-9 filesystem.

---

## Codebase Organization

The project is structured into modular assembly components included by the master file:

*   `os9_cocozip.asm`: The master entry point and initialization file.
*   `os9_eq.asm`: Direct page equates and variable structures relative to the `U` register.
*   `os9_dispatch.asm`: Dispatch tables for 0-OP, 1-OP, 2-OP, and Extended-OP instructions.
*   `os9_io.asm`: Console, keyboard input (with echo control), and utility functions.
*   `os9_disk.asm`: Target file seeking and page reading logic.
*   `os9_paging.asm`: Memory page lookup, LRU tracking, and buffer eviction.
*   `os9_subs.asm`: Core utility functions, sign extension, stack operations (push/pop), and PC branching.
*   `os9_objects.asm`: Traversal and manipulation of the Z-machine object and property tables.
*   `os9_zstring.asm`: Decompression and decoding of compressed Z-strings and abbreviation tables.
*   `os9_read.asm`: Text parser, lexical analysis, and vocabulary matching.
*   `os9_screen.asm`: Layout control, reverse-video status bar updates, partial-screen line wrapping, and `[more]` paging.
*   `os9_main.asm`: Main Z-machine decoding and execution loop.
*   `os9_ops.asm`: Implementation of individual Z-machine opcodes, including math, logic, jumps, and Save/Restore.

---

## Building and Running

### Prerequisites
1.  **lwasm**: The `lwasm` assembler from the `coco-shelf` toolchain must be installed and in your `PATH`.
2.  **NitrOS-9 Source / Defs**: Access to the NitrOS-9 kernel definitions (specifically `defsfile`) is required.

### Build Instructions
Before building, ensure that the `NITROS9DIR` environment variable is set to the root of your local NitrOS-9 repository (used to locate system definition files and the base minimal disk image recipes). The assembler (`lwasm`) must be installed and available in your `PATH`.

Once configured, run the default build target to compile the interpreter and build the bootable disk image (`zork.dsk`) containing the `infocom` executable and `zork1.dat`:
```bash
make
```
This compiles the master source file `os9_cocozip.asm` using `lwasm` and outputs the executable binary `infocom` inside the command directory of the generated `zork.dsk` image.

To run the generated disk image in the MAME emulator:
```bash
make run
```

### Running the Interpreter
Under the NitrOS-9 shell, execute `infocom` by specifying the story file path (e.g. `zork1.dat`):
```bash
infocom zork1.dat
```
