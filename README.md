# NitrOS-9 Z-Machine Interpreter (infocom)

This repository contains the NitrOS-9 (Level 1 and Level 2) native port of the Infocom Z-machine interpreter (ZIP). This project is a port of the original Infocom assembly source code for the Tandy Color Computer, which can be found in the [infocom-z-interpreter](https://github.com/rlucente-retro/infocom-z-interpreter) repository. 

The interpreter runs as a standard user process under the NitrOS-9 operating system, supporting Infocom Version 3 Z-code games (such as *Zork I, II, III*, *Planetfall*, *The Witness*, *Deadline*, etc.) loaded directly from the OS-9 filesystem.

---

## Architectural Features

*   **OS-9 Native Process Model:** Position-independent, reentrant architecture using the `U` register to address the dynamic process data area.
*   **Dynamic LRU Memory Paging:** At startup, the interpreter queries the kernel for memory via `F$Mem`. It dynamically scales its swapping space from a minimum of 8 pages (2KB) up to 160 pages (40KB), caching story file pages using a Least Recently Used (LRU) eviction policy.
*   **File-System Integration:** Story file blocks are paged dynamically from disk using standard OS-9 filesystem requests (`I$Seek` / `I$Read`).
*   **Adaptive Terminal Formatting:** Detects terminal dimensions at runtime via the `SS.ScSiz` status query. It dynamically wraps text, displays a reverse-video status bar on Row 0, and handles `[more]` paging automatically.
*   **File-Based Save/Restore:** Replaces track/sector-based saves with standard named save files in the OS-9 filesystem.

---

## Codebase Organization

The project is structured into modular assembly components included by the master file:

*   [`os9_cocozip.asm`](file:///Users/richardlucente/development/git/infocom-os9-port/os9_cocozip.asm): The master entry point and initialization file.
*   [`os9_eq.asm`](file:///Users/richardlucente/development/git/infocom-os9-port/os9_eq.asm): Direct page equates and variable structures relative to the `U` register.
*   [`os9_dispatch.asm`](file:///Users/richardlucente/development/git/infocom-os9-port/os9_dispatch.asm): Dispatch tables for 0-OP, 1-OP, 2-OP, and Extended-OP instructions.
*   [`os9_io.asm`](file:///Users/richardlucente/development/git/infocom-os9-port/os9_io.asm): Console, keyboard input (with echo control), and utility functions.
*   [`os9_disk.asm`](file:///Users/richardlucente/development/git/infocom-os9-port/os9_disk.asm): Target file seeking and page reading logic.
*   [`os9_paging.asm`](file:///Users/richardlucente/development/git/infocom-os9-port/os9_paging.asm): Memory page lookup, LRU tracking, and buffer eviction.
*   [`os9_subs.asm`](file:///Users/richardlucente/development/git/infocom-os9-port/os9_subs.asm): Core utility functions, sign extension, stack operations (push/pop), and PC branching.
*   [`os9_objects.asm`](file:///Users/richardlucente/development/git/infocom-os9-port/os9_objects.asm): Traversal and manipulation of the Z-machine object and property tables.
*   [`os9_zstring.asm`](file:///Users/richardlucente/development/git/infocom-os9-port/os9_zstring.asm): Decompression and decoding of compressed Z-strings and abbreviation tables.
*   [`os9_read.asm`](file:///Users/richardlucente/development/git/infocom-os9-port/os9_read.asm): Text parser, lexical analysis, and vocabulary matching.
*   [`os9_screen.asm`](file:///Users/richardlucente/development/git/infocom-os9-port/os9_screen.asm): Layout control, reverse-video status bar updates, partial-screen line wrapping, and `[more]` paging.
*   [`os9_main.asm`](file:///Users/richardlucente/development/git/infocom-os9-port/os9_main.asm): Main Z-machine decoding and execution loop.
*   [`os9_ops.asm`](file:///Users/richardlucente/development/git/infocom-os9-port/os9_ops.asm): Implementation of individual Z-machine opcodes, including math, logic, jumps, and Save/Restore.

---

## Building and Running

### Prerequisites
1.  **Toolchain (`lwasm` & `os9`)**: The `lwasm` cross-assembler and `os9` disk management utilities from the `coco-shelf` toolchain must be installed and available in your `PATH`.
2.  **`curl`**: Used to download game story files defined in [`masterpiece.csv`](file:///Users/richardlucente/development/git/infocom-os9-port/masterpiece.csv).
3.  **NitrOS-9 Repository**: The `NITROS9DIR` environment variable must point to the root of your NitrOS-9 repository clone (used to locate kernel definitions and disk recipe makefiles).

```bash
export NITROS9DIR=/path/to/nitros9
```

---

### Build Targets & Usage Instructions

The [`Makefile`](file:///Users/richardlucente/development/git/infocom-os9-port/Makefile) provides two main workflows: single-story minimal floppy disks (optimized for rapid development and testing in MAME) and FujiNet / DriveWire multi-game disk images.

#### 1. Single-Story Floppy Disk Images (Development & MAME Testing)

By default, running `make` compiles the `infocom` interpreter and builds a minimal bootable floppy disk image containing the interpreter in `/CMDS` and the test story `ziptest.z3`:

```bash
make
```

* **Customize the story file (using local files or fetched games from `games/`):**
  ```bash
  # Using a fetched .z3 game (will be downloaded automatically on demand):
  make STORY=games/zork1.z3

  # Or using any local .z3 story file:
  make STORY=zork1.z3
  ```
  This creates `zork1.dsk` containing `/CMDS/infocom` and `zork1.z3`.

* **Target CoCo 1/2 vs. CoCo 3:**
  - Default target is CoCo 3 (`l2_coco3_minimal.dsk`).
  - Target CoCo 1/2 (`l1_coco_minimal.dsk`):
    ```bash
    make STORY=games/zork1.z3 MAME_MACHINE=coco2b
    ```

* **Launch directly in MAME:**
  ```bash
  # Boot default ziptest.dsk on CoCo 3:
  make run

  # Boot a specific story game:
  make run STORY=games/zork1.z3

  # Boot custom story on CoCo 1/2 (coco2b):
  make run STORY=games/zork1.z3 MAME_MACHINE=coco2b
  ```

---

#### 2. FujiNet / DriveWire Multi-Game Disks (CoCo)

FujiNet / DriveWire disks are 127MB NitrOS-9 DriveWire filesystem images that include the `infocom` executable in `/CMDS` and a full suite of classic Infocom games placed in the `/GAMES` directory.

The list of games and download URLs is defined in [`masterpiece.csv`](file:///Users/richardlucente/development/git/infocom-os9-port/masterpiece.csv). Missing story files are automatically downloaded into a local `games/` cache directory using `curl` during the build.

* **Build both CoCo 1/2 and CoCo 3 FujiNet disk images:**
  ```bash
  make fujinet
  ```
  This generates:
  - `infocom_coco_dw.dsk`: Level 1 NitrOS-9 DriveWire image based on `recipes/coco/dw`.
  - `infocom_coco3_dw.dsk`: Level 2 NitrOS-9 DriveWire image based on `recipes/coco3/dw`.

* **Build for CoCo 3 only:**
  ```bash
  make fujinet-coco3
  # Or:
  make infocom_coco3_dw.dsk
  ```

* **Build for CoCo 1/2 only:**
  ```bash
  make fujinet-coco
  # Or:
  make infocom_coco_dw.dsk
  ```

---

#### 3. Wildbits Multi-Game Disks

Builds a 127MB NitrOS-9 Level 2 Wildbits disk image containing `infocom` in `/CMDS` and all game story files in `/GAMES`:

* **Build for Wildbits (default `PLATFORM=jr2`):**
  ```bash
  make wildbits
  # Or:
  make wildbits-jr2
  ```
  This creates `infocom_wildbits_jr2.dsk` based on `$(NITROS9DIR)/recipes/wildbits/l2` with `PLATFORM=jr2`.

* **Build for Wildbits (`PLATFORM=k2`):**
  ```bash
  make wildbits PLATFORM=k2
  # Or:
  make wildbits-k2
  ```
  This creates `infocom_wildbits_k2.dsk` based on `$(NITROS9DIR)/recipes/wildbits/l2` with `PLATFORM=k2`.

---

#### 4. Downloading Game Files Only

* **Pre-fetch all game story files without building disks:**
  ```bash
  make fetch-games
  ```

---

### Cleaning Build Artifacts

* **Clean binaries and disk images (preserves downloaded games in `games/`):**
  ```bash
  make clean
  ```

* **Delete the downloaded games cache:**
  ```bash
  make clean-games
  ```

* **Complete clean (removes binaries, disk images, and downloaded games):**
  ```bash
  make distclean
  ```

---

## Running Games in NitrOS-9

When running from the NitrOS-9 shell, execute `infocom` followed by the path to the story file:

### From Single-Story Floppy Disks:
```bash
infocom ziptest.z3
# Or:
infocom zork1.z3
```

### From FujiNet Multi-Game Disks:
```bash
# Direct invocation:
infocom GAMES/zork1.z3
infocom GAMES/planetfall.z3
infocom GAMES/leathergoddesses.z3

# Or change the data directory to GAMES:
chd GAMES
infocom ballyhoo.z3
```

### Save and Restore
Under NitrOS-9, `SAVE` and `RESTORE` are commands issued directly by the user inside the Infocom game itself during gameplay. When invoked, the interpreter prompts for an OS-9 filesystem path to store or retrieve the game state.

> [!NOTE]
> **FujiNet / DriveWire Game Saves:**
> When running from a FujiNet DriveWire multi-game disk image, you will need a separate formatted disk image mounted on your FujiNet SD card to store game saves.
>
> 1. **Create an empty save disk image:**
>    Use the `os9` utility from [Toolshed](https://github.com/nitros9project/toolshed) to format a blank disk image:
>    ```bash
>    os9 format -t1024 -st18 -e -n"SAVE" infocom_save.dsk
>    ```
> 2. **Mount on the FujiNet SD card:**
>    Place `infocom_save.dsk` onto your FujiNet SD card and mount it in the second drive slot (Slot 1) with read/write access. Under NitrOS-9, this second slot is identified as the `/X1` drive device.
> 3. **Saving inside the game:**
>    While playing any Infocom game:
>    - Type `SAVE` at the game prompt.
>    - When prompted for a filename, enter the full path specifying the `/X1` device, for example:
>      ```text
>      /X1/chk1
>      ```
>      *(You can use any filename you prefer, such as `/X1/zork1_save1` or `/X1/chk1`, as long as the `/X1/` device prefix is included).*
> 4. **Restoring inside the game:**
>    - Type `RESTORE` at the game prompt.
>    - Enter the same full path (e.g., `/X1/chk1`) to reload your saved game state.

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
