# Infocom Z-machine Interpreter for TRS-80 Color Computer (ZIP/6809-C)

This project is a 6809 assembly language implementation of the Infocom Z-machine interpreter (ZIP) for the TRS-80 Color Computer (CoCo). It is designed to run on a 64K CoCo 2 and provides full support for any Infocom Version 3 Z-code games (e.g., Zork I, II, III, Planetfall, The Witness, Deadline, etc.).

## Architecture Overview

The interpreter follows the standard Z-machine architecture but is heavily optimized for the 6809 CPU and the CoCo's hardware constraints. It uses a virtual memory paging system to handle games that are larger than the available RAM.

### Core Components

*   **Main Loop (`main.ASM`):** The central execution engine. It fetches opcodes, decodes them (0-OP, 1-OP, 2-OP, X-OP), and dispatches to specific handlers.
*   **Paging System (`paging.ASM`):** A sophisticated virtual memory manager using a Least Recently Used (LRU) algorithm with timestamps. It allows the interpreter to access up to 128KB (or more) of Z-code by swapping 256-byte pages from disk into a RAM-resident buffer pool.
*   **Z-String Handler (`zstring.ASM`):** Implements the complex Z-string compression and decoding logic, including support for three character sets, temporary/permanent shifts, and abbreviations (F-words).
*   **Object & Property Handler (`objects.ASM`):** Manages the Z-machine's object tree and property tables, providing efficient traversal and manipulation.
*   **I/O System (`ioprims.ASM`, `screen.ASM`):** Provides a 32-column text display, status line updates (Score/Moves or Time), and keyboard input. It includes specialized routines to bypass the CoCo's ROM so the interpreter can enable the full 64K RAM address space for Z-code storage and paging. This ensures hardware functionality remains available when the physical ROMs are swapped out.
*   **Disk System (`disk.ASM`):** Handles track/sector-based disk I/O for both loading Z-code blocks and performing SAVE/RESTORE operations.

## Memory Organization

The interpreter is designed to fit within the 64K address space. For a complete technical breakdown, see the [Detailed Memory Map](MEMORY.md).

*   **Direct Page (Page 0):** Used for the most frequently accessed Z-machine variables (Opcode, Arguments, PC, MPC, etc.).
*   **Machine Stack:** Standard 6809 stack for subroutine calls and local state.
*   **Z-Stack:** Dedicated 255-word stack for Z-machine operations and CALL/RET state.
*   **Paging Table & LRU Map:** Used by the paging system to track which Z-code pages are in RAM and when they were last accessed.
*   **Preloaded Z-Code:** The "pure" part of the Z-code (header and initial data) is kept permanently in RAM.
*   **Swapping Space:** A pool of RAM buffers used to cache "impure" and non-preloaded Z-code pages from disk.

## Disk Organization

The interpreter expects the Z-code game data to be arranged on the disk in a specific format:

*   **Boot Track (Track 34):** Contains the initial loader (`boot.ASM`).
*   **Story Data:** Starts at Track 2, Sector 1.
*   **Save Slots:** Support for 7 save positions, each occupying 5 tracks on a separate save disk.

## Building and Files

The project is structured into multiple source files, with `cocozip.ASM` acting as the master file that includes all other components.

*   `zequates.ASM`: Z-machine constants and memory layout.
*   `main.ASM`: The main interpreter loop.
*   `mainsubs.ASM`: Core utility subroutines.
*   `dispatch.ASM`: Opcode dispatch tables.
*   `ops*.ASM`: Implementation of the various Z-machine opcodes.
*   `read.ASM`: Lexical analyzer and input parser.
*   `paging.ASM`: Virtual memory and LRU paging.
*   `zstring.ASM`: Z-string decoding and encoding.
*   `objects.ASM`: Object and property manipulation.
*   `ioprims.ASM`: Low-level hardware I/O.
*   `screen.ASM`: High-level display and status line management.
*   `disk.ASM`: Disk I/O and Save/Restore logic.
*   `warm.ASM`: Interpreter initialization and startup.
*   `boot.ASM`: Initial loader for the CoCo. This resides on the boot track (Track 34) and is responsible for loading the ZIP into RAM and starting it at `$1100` (the start of `warm.ASM`). Note that `boot.ASM` contains temporary versions of the ROM-replacement routines (`MYCON`, `MYCHR`, `DIRQSV`) which are only used during the boot process. Once the ZIP is loaded, these routines are redefined in `io.ASM` with full interpreter-level support.

## Building the Project

### Prerequisites

1.  **Tooling**: This project requires the `coco-shelf` cross-development tools (specifically `lwasm` and `decb`) available at [https://github.com/strickyak/coco-shelf](https://github.com/strickyak/coco-shelf).
2.  **Story Files**: You need a compiled Infocom Version 3 story file (typically ending in `.DAT` or `.z3`). These files are not included in this repository but are widely available across the internet (e.g., [The Obsessively Complete Infocom Catalog](https://eblong.com/infocom/) or other historical software repositories).

### Build Steps

1.  **Configure Paths**: Open the `Makefile` and update the following variables to match your local environment, or override them on the command line:
    *   `SHELF`: The path to your local `coco-shelf` installation.
    *   `STORY`: The path to the Version 3 story file you wish to bundle.
    *   `DISK`: (Optional) The name of the output disk image (defaults to the story name with a `.dsk` extension).
2.  **Compile and Construct Disk**: Run the following command in your terminal:
    ```bash
    make STORY=/path/to/your/story.z3 DISK=mygame.dsk
    ```
3.  **Output**: This will generate a formatted DECB disk image containing the boot loader, the interpreter, and the story data, ready for use in a Color Computer emulator like XRoar or MAME.


## Version History

*   **Version A (1984):** Initial archival.
*   **Version C (1985):** Significant updates for OS9 compatibility and paging improvements.

## Attribution

The source code in this repository was originally sourced from the [infocom-zcode-terps](https://github.com/erkyrath/infocom-zcode-terps/tree/master/colorcomputer) repository maintained by Andrew Plotkin (erkyrath). For more context on Andrew Plotkin's effort to recover this and other Infocom tools, see the Ars Technica article: [Infocom’s ingenious code-porting tools for Zork and other games have been found](https://arstechnica.com/gaming/2023/11/infocoms-ingenious-code-porting-tools-for-zork-and-other-games-have-been-found/).

Additionally, John Linville's series of articles on the RetroTinker blog provided valuable insights into building and using Z-machine tools for the CoCo:
* [Building CoCo Games with Inform](https://retrotinker.blogspot.com/2017/11/building-coco-games-with-inform.html)
* [Using Infocom's ZIP on the CoCo](https://retrotinker.blogspot.com/2017/11/using-infocoms-zip-on-coco.html)
* [Building Infocom Disk Images for the CoCo](https://retrotinker.blogspot.com/2017/11/building-infocom-disk-images-for-coco.html)

This version has been:
*   **Fully Documented**: Added comprehensive block and inline comments to explain the architectural intent and low-level 6809 assembly logic.
*   **Modernized**: Updated assembly directives and file structures for compatibility with modern cross-development tools like `lwasm`.
*   **Automated**: Includes a `Makefile` for bit-perfect binary reconstruction and automated disk image (`.dsk`) generation.
