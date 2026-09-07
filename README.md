# NitrOS-9 Z-Machine Interpreter (infocom)

This repository contains the NitrOS-9 (Level 1 and Level 2) native port of the Infocom Z-machine interpreter (ZIP). For details on original source code provenance and licensing, see [Attribution & Intellectual Property](#attribution--intellectual-property).

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

*   [`os9_cocozip.asm`](os9_cocozip.asm): The master entry point and initialization file.
*   [`os9_eq.asm`](os9_eq.asm): Direct page equates and variable structures relative to the `U` register.
*   [`os9_dispatch.asm`](os9_dispatch.asm): Dispatch tables for 0-OP, 1-OP, 2-OP, and Extended-OP instructions.
*   [`os9_io.asm`](os9_io.asm): Console, keyboard input (with echo control), and utility functions.
*   [`os9_disk.asm`](os9_disk.asm): Target file seeking and page reading logic.
*   [`os9_paging.asm`](os9_paging.asm): Memory page lookup, LRU tracking, and buffer eviction.
*   [`os9_subs.asm`](os9_subs.asm): Core utility functions, sign extension, stack operations (push/pop), and PC branching.
*   [`os9_objects.asm`](os9_objects.asm): Traversal and manipulation of the Z-machine object and property tables.
*   [`os9_zstring.asm`](os9_zstring.asm): Decompression and decoding of compressed Z-strings and abbreviation tables.
*   [`os9_read.asm`](os9_read.asm): Text parser, lexical analysis, and vocabulary matching.
*   [`os9_screen.asm`](os9_screen.asm): Layout control, reverse-video status bar updates, partial-screen line wrapping, and `[more]` paging.
*   [`os9_main.asm`](os9_main.asm): Main Z-machine decoding and execution loop.
*   [`os9_ops.asm`](os9_ops.asm): Implementation of individual Z-machine opcodes, including math, logic, jumps, and Save/Restore.

---

## Building and Running

### Prerequisites
1.  **Toolchain (`lwasm` & `os9`)**: The `lwasm` cross-assembler and `os9` disk management utilities from the `coco-shelf` toolchain must be installed and available in your `PATH`.
2.  **`curl`**: Used to download game story files defined in [`masterpiece.csv`](masterpiece.csv).
3.  **NitrOS-9 Repository**: The `NITROS9DIR` environment variable must point to the root of your NitrOS-9 repository clone (used to locate kernel definitions and disk recipe makefiles).

```bash
export NITROS9DIR=/path/to/nitros9
```

---

### Build Targets & Usage Instructions

The [`Makefile`](Makefile) provides two main workflows: single-story minimal floppy disks (optimized for rapid development and testing in MAME) and FujiNet / DriveWire multi-game disk images.

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
  This creates `zork1.dsk` containing `/CMDS/infocom` and `/GAMES/INFOCOM/zork1.z3`.

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

FujiNet / DriveWire disks are 127MB NitrOS-9 DriveWire filesystem images that include the `infocom` executable in `/CMDS` and Infocom games placed in the `/GAMES/INFOCOM` directory.

> [!NOTE]
> By default, only the open-source *Zork* trilogy is packaged onto multi-game disk images (see [Attribution & Intellectual Property](#attribution--intellectual-property) for copyright and licensing details). To include all titles from [`masterpiece.csv`](masterpiece.csv), build with `ALL_GAMES=1` (e.g., `make fujinet ALL_GAMES=1`) or selectively enable individual games by setting their third column in [`masterpiece.csv`](masterpiece.csv) to `1`.

The list of games, download URLs, and inclusion flags is defined in [`masterpiece.csv`](masterpiece.csv). Missing story files are automatically downloaded into a local `games/` cache directory using `curl` during the build.

* **Build Universal Data Disk for Multiple Computers (CoCo 1/2, CoCo 3, Wildbits):**
  Since the `infocom` executable and game files are identical across NitrOS-9 Level 1 and Level 2, you can generate a clean data disk image (`infocom_dw.dsk`) that works across multiple machines (CoCo 1/2, CoCo 3, and Wildbits jr2/k2) after booting the system from a separate OS disk image:
  ```bash
  make fujinet-data
  # Or with all games:
  make fujinet-data ALL_GAMES=1
  ```
  *(Aliases: `make dw-data`, `make dw`, `make infocom_dw.dsk`)*

  This creates a 127MB RBF disk image containing **only**:
  - `/CMDS/infocom` (with execution attributes)
  - `/GAMES/INFOCOM/<game files>`

  No boot tracks, kernel modules, or other system files are included on this disk image. Once your computer is booted from its primary OS disk, mount `infocom_dw.dsk` on a secondary DriveWire or FujiNet drive (such as `/x1`), and launch games with:
  ```bash
  chx /x1/CMDS
  chd /x1/GAMES/INFOCOM
  infocom zork1.z3
  ```
  *(or directly: `/x1/CMDS/infocom /x1/GAMES/INFOCOM/zork1.z3`)*

* **Build CoCo Bootable FujiNet DriveWire Disk Images:**
  To generate full, bootable NitrOS-9 DriveWire disk images with complete OS commands and kernels:
  ```bash
  # Build both CoCo 1/2 and CoCo 3 bootable disks:
  make fujinet
  # Or with all games:
  make fujinet ALL_GAMES=1
  ```

  This generates:
  - `infocom_coco_dw.dsk`: Level 1 NitrOS-9 DriveWire boot image based on `recipes/coco/dw`.
  - `infocom_coco3_dw.dsk`: Level 2 NitrOS-9 DriveWire boot image based on `recipes/coco3/dw`.

* **Build Bootable Disk for CoCo 3 only:**
  ```bash
  make fujinet-coco3
  # Or with all games:
  make fujinet-coco3 ALL_GAMES=1
  ```

* **Build Bootable Disk for CoCo 1/2 only:**
  ```bash
  make fujinet-coco
  # Or with all games:
  make fujinet-coco ALL_GAMES=1
  ```

---

#### 3. Wildbits Multi-Game Disks

Builds a 127MB NitrOS-9 Level 2 Wildbits disk image containing `infocom` in `/CMDS` and game story files in `/GAMES/INFOCOM` (defaults to the open-source Zork games; pass `ALL_GAMES=1` to include all games):

* **Build for Wildbits (default `PLATFORM=jr2`):**
  ```bash
  make wildbits
  # Or with all games:
  make wildbits ALL_GAMES=1
  ```
  This creates `infocom_wildbits_jr2.dsk` based on `$(NITROS9DIR)/recipes/wildbits/l2` with `PLATFORM=jr2`.

* **Build for Wildbits (`PLATFORM=k2`):**
  ```bash
  make wildbits PLATFORM=k2
  # Or with all games:
  make wildbits PLATFORM=k2 ALL_GAMES=1
  ```
  This creates `infocom_wildbits_k2.dsk` based on `$(NITROS9DIR)/recipes/wildbits/l2` with `PLATFORM=k2`.

---

#### 4. Downloading Game Files Only

* **Pre-fetch included game story files (Zork 1–3 by default):**
  ```bash
  make fetch-games
  ```

* **Pre-fetch all 21 game story files:**
  ```bash
  make fetch-games ALL_GAMES=1
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

### Direct Invocation:
```bash
# Direct execution from anywhere on the disk:
infocom GAMES/INFOCOM/ziptest.z3
infocom GAMES/INFOCOM/zork1.z3
infocom GAMES/INFOCOM/planetfall.z3
```

### Changing the Data Directory (`chd`):
```bash
# Change directory to GAMES/INFOCOM:
chd GAMES/INFOCOM

# Run games directly by name:
infocom ziptest.z3
infocom zork1.z3
infocom planetfall.z3
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

> [!IMPORTANT]
> **FujiNet Firmware Requirement (> v1.6.1):**
> To successfully save and restore game progress on a FujiNet device, your FujiNet hardware must run a firmware release **later than v1.6.1**. In v1.6.1 and earlier, a post-write sector seek bug causes subsequent disk operations on `/X1` to fail with `ERROR #211` / `Interpreter Error #14`.
>
> At present, this requires flashing a **nightly build** of the firmware to your FujiNet device (using [FujiNet-Flasher](https://github.com/FujiNetWIFI/fujinet-flasher)). If you encounter errors while writing to or reading from DriveWire disks, check for and install a newer firmware release for FujiNet to ensure the issue has not already been resolved upstream.

---

## Attribution & Intellectual Property

### Intellectual Property & The Infocom Catalog
* **Copyright Ownership:** Copyright for the Infocom game library rests with **Microsoft** following its 2023 acquisition of Activision.
* **Open-Source Zork Trilogy:** In November 2025, Microsoft declared that [*Zork I*, *Zork II*, and *Zork III* are open source](https://opensource.microsoft.com/blog/2025/11/20/preserving-code-that-shaped-generations-zork-i-ii-and-iii-go-open-source/) under the MIT License.
* **Historical Preservation & The Infocom Catalog:** The story files referenced in [`masterpiece.csv`](masterpiece.csv) are sourced from Andrew Plotkin's [Obsessively Complete Infocom Catalog](https://eblong.com/infocom/). As highlighted in the catalog's [Disclaimer](https://eblong.com/infocom/#disclaimer), these historical materials were preserved and reconstructed through the dedication of private collectors and the interactive fiction community, as the original corporate copyright holders did not maintain the tools or environments to compile or preserve the code. All non-Zork game titles, trademarks, and story files remain the intellectual property of Microsoft.

### Interpreter Source Code
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
