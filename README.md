# NitrOS-9 Z-Machine Interpreter (OS9ZIP)

This repository contains the NitrOS-9 (Level 1 and Level 2) native port of the Infocom Z-machine interpreter (ZIP). 

The interpreter runs as a standard user process under the NitrOS-9 operating system, supporting Infocom Version 3 Z-code games (such as *Zork I, II, III*, *Planetfall*, *The Witness*, *Deadline*, etc.) loaded directly from the OS-9 filesystem.

---

## Architectural Features

*   **OS-9 Native Process model:** Position-independent, reentrant architecture using the `U` register to address the dynamic process data area.
*   **Dynamic LRU Memory Paging:** At startup, the interpreter queries the kernel for memory via `F$Mem`. It dynamically scales its swapping space from a minimum of 8 pages (2KB) up to 160 pages (40KB), caching story file pages using a Least Recently Used (LRU) eviction policy.
*   **File-System Integration:** Story file blocks are paged dynamically from disk using standard OS-9 filesystem requests (`I$Seek` / `I$Read`).
*   **Adaptive Terminal Formatting:** Detects terminal dimensions at runtime via the `SS.ScSiz` status query or parses command-line parameters (e.g. `80x24`, `32x16`). It dynamically wraps text, displays a reverse-video status bar on Row 0, and handles `[more]` paging automatically.
*   **File-Based Save/Restore:** Replaces track/sector-based saves with standard named save files in the OS-9 filesystem.

---

## Codebase Organization

The project is structured into modular assembly components included by the master file:

*   `OS9_COCOZIP.ASM`: The master entry point and initialization file.
*   `OS9_EQ.ASM`: Direct page equates and variable structures relative to the `U` register.
*   `OS9_DISPATCH.ASM`: Dispatch tables for 0-OP, 1-OP, 2-OP, and Extended-OP instructions.
*   `OS9_IO.ASM`: Console, keyboard input (with echo control), and utility functions.
*   `OS9_DISK.ASM`: Target file seeking and page reading logic.
*   `OS9_PAGING.ASM`: Memory page lookup, LRU tracking, and buffer eviction.
*   `OS9_SUBS.ASM`: Core utility functions, sign extension, stack operations (push/pop), and PC branching.
*   `OS9_OBJECTS.ASM`: Traversal and manipulation of the Z-machine object and property tables.
*   `OS9_ZSTRING.ASM`: Decompression and decoding of compressed Z-strings and abbreviation tables.
*   `OS9_READ.ASM`: Text parser, lexical analysis, and vocabulary matching.
*   `OS9_SCREEN.ASM`: Layout control, reverse-video status bar updates, partial-screen line wrapping, and `[more]` paging.
*   `OS9_MAIN.ASM`: Main Z-machine decoding and execution loop.
*   `OS9_OPS.ASM`: Implementation of individual Z-machine opcodes, including math, logic, jumps, and Save/Restore.

---

## Building and Running

### Prerequisites
1.  **lwasm**: The `lwasm` assembler from the `coco-shelf` toolchain must be installed and in your `PATH`.
2.  **NitrOS-9 Source / Defs**: Access to the NitrOS-9 kernel definitions (specifically `defsfile`) is required.

### Build Instructions
Before building, ensure that the following variables are configured correctly in the `Makefile` to match your local development environment:
*   `SHELF`: The path to the root of your local `coco-shelf` installation.
*   `LWASM`: The path to the `lwasm` assembler executable (typically inside `$(SHELF)/bin`).
*   `NITROS9`: The path to the root of your local `nitros9` repository (used to locate system definition files).

Once configured, run the default build target:
```bash
make
```
This compiles the master source file `OS9_COCOZIP.ASM` using `lwasm` and outputs the executable binary `OS9ZIP`, along with its map `OS9ZIP.map` and listing `OS9ZIP.list`.

To generate a bootable NitrOS-9 disk image (`os9test.dsk`) containing `OS9ZIP` and `ZORK1.DAT`:
```bash
make disk
```

### Running the Interpreter
Under the NitrOS-9 shell, execute `OS9ZIP` by specifying the story file path and optionally overriding the screen resolution:
```bash
OS9ZIP ZORK1.DAT [columns]x[rows]
```
Example (80x24 console):
```bash
OS9ZIP ZORK1.DAT 80x24
```
Example (standard 32-column screen):
```bash
OS9ZIP ZORK1.DAT 32x16
```
