# NitrOS-9 Z-Machine Interpreter (infocom)

This repository contains the NitrOS-9 (Level 1 and Level 2) native port of the Infocom Z-machine interpreter (ZIP). This project is a port of the original Infocom assembly source code for the Tandy Color Computer, which can be found in the [infocom-z-interpreter](https://github.com/rlucente-retro/infocom-z-interpreter) repository. 

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

By default, the build compiles the interpreter and copies the default test story file `ziptest.z3` (which is based on the official regression test suite `ziptest-r40-s840613.z3` available at [Andrew Plotkin's eblong.com catalog](https://eblong.com/infocom/#ziptest)) onto a bootable floppy disk image (`ziptest.dsk`).

Run the default build target:
```bash
make
```
This compiles the master source file `os9_cocozip.asm` using `lwasm` and outputs the executable binary `infocom` and the story file inside the command and data directories of the generated `ziptest.dsk` image.

#### Customizing the Story File
You can easily change the story file packaged into the disk image by overriding the `STORY` variable on the command line or editing the `Makefile`. For example, to generate a disk image containing `zork1.dat`:
```bash
make STORY=zork1.dat
```
This dynamically names and builds `zork1.dsk` containing both the `infocom` executable and the `zork1.dat` story file.

#### Targeting CoCo 2 vs CoCo 3
By default, the Makefile targets the Tandy Color Computer 3 (`coco3`). You can target the Tandy Color Computer 2 (`coco2b`) by overriding the `MAME_MACHINE` variable:
```bash
make MAME_MACHINE=coco2b
```
This automatically selects the CoCo 2 minimal base disk image (`l1_coco_minimal.dsk`), invokes the appropriate NitrOS-9 sub-make recipes to build it if it does not exist, and runs MAME with the `coco2b` machine configuration.

To run the generated disk image in the MAME emulator:
```bash
make run
# Or for a custom story disk image / machine target:
make run STORY=zork1.dat MAME_MACHINE=coco2b
```

### Running the Interpreter
Under the NitrOS-9 shell, execute `infocom` by specifying the story file path:
```bash
infocom ziptest.z3
# Or:
infocom zork1.dat
```

---

## Attribution

The assembly source code in this repository is a port of the CoCo ZIP interpreter from the [infocom-z-interpreter](https://github.com/rlucente-retro/infocom-z-interpreter) repository. 

The original source code was sourced from the [infocom-zcode-terps](https://github.com/erkyrath/infocom-zcode-terps/tree/master/colorcomputer) repository maintained by Andrew Plotkin (erkyrath). For more context on Andrew Plotkin's effort to recover this and other Infocom tools, see the Ars Technica article: [Infocom’s ingenious code-porting tools for Zork and other games have been found](https://arstechnica.com/gaming/2023/11/infocoms-ingenious-code-porting-tools-for-zork-and-other-games-have-been-found/).

Additionally, John Linville's series of articles on the RetroTinker blog provided valuable insights into building and using Z-machine tools for the CoCo:
* [Building CoCo Games with Inform](https://retrotinker.blogspot.com/2017/11/building-coco-games-with-inform.html)
* [Using Infocom's ZIP on the CoCo](https://retrotinker.blogspot.com/2017/11/using-infocoms-zip-on-coco.html)
* [Building Infocom Disk Images for the CoCo](https://retrotinker.blogspot.com/2017/11/building-infocom-disk-images-for-coco.html)
* [Z Interpreter Source for CoCo Recovered](https://retrotinker.blogspot.com/2018/02/z-intepreter-source-for-coco-recovered.html)

This NitrOS-9 port builds upon that work, with the following modifications:
*   **NitrOS-9 Integration**: Replaced track/sector-based floppy disk I/O with standard OS-9 filesystem requests (`I$Seek` / `I$Read`).
*   **User-Space Execution**: Rewritten as a position-independent assembly program supporting standard user processes, avoiding ROM overrides.
*   **Adaptive Terminal Control**: Detects terminal width dynamically to format text with word wrap, reverse-video status line updates, and paging (`[MORE]` scrolls).
*   **Standardized Saves**: Replaced disk-sector save/restore with standard named save files in the OS-9 filesystem.

