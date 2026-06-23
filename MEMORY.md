# OS9ZIP (NitrOS-9 Z-Machine Interpreter) Memory Map

This document describes the memory organization and variable layout of the NitrOS-9 native Z-machine interpreter.

---

## 1. Process Workspace Layout

Under NitrOS-9, the process workspace is allocated dynamically by the kernel at startup and expanded via the `F$Mem` system call. The compiled program module is position-independent, and the `U` register points to the base of the dynamic data area (variables and stack).

The workspace is organized as follows:

| Offset Range / Symbol | Size (Bytes) | Description |
|:---|:---|:---|
| `U + $0000` - `U + ZPGTOP` | ~$140 | **Dynamic Direct Page Variables** (Access via `setdp 0`) |
| `U + ZSTACK` | 1024 | **Z-Stack** (512 words, dedicated Z-machine stack) |
| `U + PTABLE` | 320 | **Paging Translation Table** (Holds virtual page numbers for cached blocks) |
| `U + LRUMAP` | 160 | **Timestamp LRU Map** (Tracks buffer page usage for eviction) |
| `U + LOCALS` | 32 | **Active Locals Variable Buffer** (Stores active routine local state) |
| `U + BUFFER` | 32 | **I/O Line Input Buffer** |
| `U + BUFSAV` | 32 | **I/O Aux Buffer / Filename Storage** |
| `U + status_buf` | 80 | **Transient Status Line Buffer** |
| `U + STATIC_SIZE` | - | **Base of Story Preload (`zcode_ptr`)** |
| `zcode_ptr` to `PAGE0` page | `ZPURE * 256` | **Permanently Resident Z-Code Preload** (Z-Header + static data) |
| `PAGE0 * 256` to High Memory | `PMAX * 256` | **Virtual Memory Swapping Page Pool** (256-byte LRU cache pages) |

---

## 2. Dynamic Direct Page Variables (U-Relative Offsets)

These variables are defined starting at offset `0` relative to the `U` register. They are mapped to the Direct Page at runtime to enable fast execution using short-offset instructions:

| Offset (Hex) | Label | Size | Description |
|:---|:---|:---|:---|
| `$00` | `OPCODE` | 1 | Current Z-machine opcode |
| `$01` | `ARGCNT` | 1 | Number of arguments for current opcode |
| `$02` | `ARG1` | 2 | Argument #1 (Word) |
| `$04` | `ARG2` | 2 | Argument #2 (Word) |
| `$06` | `ARG3` | 2 | Argument #3 (Word) |
| `$08` | `ARG4` | 2 | Argument #4 (Word) |
| `$0A` | `LRU` | 1 | Least Recently Used page timestamp index |
| `$0B` | `ZPURE` | 1 | First virtual page of non-preloaded Z-code (MSB) |
| `$0C` | `PMAX` | 1 | Maximum number of swapping pages allocated in RAM |
| `$0D` | `ZPAGE` | 1 | Currently active swapping page index (0 to PMAX-1) |
| `$0E` | `PAGE0` | 1 | Starting page boundary (MSB) of the swapping space in RAM |
| `$0F` | `TABTOP` | 2 | End pointer of the initialized `PTABLE` |
| `$11` | `STAMP` | 1 | Current timestamp counter for LRU mapping |
| `$12` | `SWAP` | 1 | Index of the earliest page to swap out |
| `$13` | `ZPCH` | 1 | High bit of Z-machine Program Counter (PC) |
| `$14` | `ZPCM` | 1 | Middle 8 bits of ZPC |
| `$15` | `ZPCL` | 1 | Low 8 bits of ZPC |
| `$16` | `ZPCPNT` | 2 | Absolute pointer in RAM to active PC page |
| `$18` | `ZPCFLG` | 2 | Flag byte: non-zero if cached `ZPCPNT` is valid |
| `$1A` | `MPCH` | 1 | High bit of Memory Program Counter (MPC) |
| `$1B` | `MPCM` | 1 | Middle 8 bits of MPC |
| `$1C` | `MPCL` | 1 | Low 8 bits of MPC |
| `$1D` | `MPCPNT` | 2 | Absolute pointer in RAM to active MPC page |
| `$1F` | `MPCFLG` | 2 | Flag byte: non-zero if cached `MPCPNT` is valid |
| `$21` | `GLOBAL` | 2 | Base offset of Global Variable Table |
| `$23` | `VOCAB` | 2 | Base offset of Vocabulary Table |
| `$25` | `FWORDS` | 2 | Base offset of F-Words (Abbreviation) Table |
| `$45` | `CUR_NLOCS`| 1 | Number of active locals in current routine |
| `$46` | `OZSTAK` | 2 | Stack pointer snapshot (ZSP) saved for routine calls |
| `$5A` | `VAL` | 2 | Value return registers |
| `$5C` | `TEMP` | 2 | Primary temporary register |
| `$5E` | `TEMP2` | 2 | Secondary temporary register |
| `$61` | `global_ptr`| 2 | Absolute pointer to the global table in RAM |
| `$63` | `vocab_ptr` | 2 | Absolute pointer to the vocab table in RAM |
| `$65` | `TIMEFL` | 1 | Score layout select flag (0 = Score/Moves, non-zero = Time) |
| `$79` | `zcode_ptr` | 2 | Base address of story file preload area (`U + STATIC_SIZE`) |
| `$7B` | `zsp_top` | 2 | Base address of Z-Stack top |
| `$7D` | `cur_cols` | 1 | Total columns of terminal (e.g. 32, 40, 80) |
| `$7E` | `cur_rows` | 1 | Total rows of terminal (e.g. 16, 24, 30) |
| `$7F` | `cur_x` | 1 | Current terminal cursor column coordinate |
| `$80` | `cur_y` | 1 | Current terminal cursor row coordinate |
| `$81` | `inv_flag` | 1 | Invert output flag (0 = Normal text, 1 = Reverse video) |
| `$82` | `page_lines`| 1 | Lines outputted since last screen pause |
| `$83` | `was_cr` | 1 | CR state tracker to prevent double newlines |
| `$84` | `path_num` | 1 | NitrOS-9 file path number for the open story file |

---

## 3. Z-Code Story Header Offsets

These offsets are defined by the Z-machine specification and parsed relative to the story preload base `zcode_ptr`:

| Offset | Label | Size | Description |
|:---|:---|:---|:---|
| `0` | `ZVERS` | 1 | Version byte (should be `3` for V3 games) |
| `1` | `ZMODE` | 1 | Mode configuration byte |
| `2` | `ZID` | 2 | Unique game identifier word |
| `4` | `ZENDLD` | 2 | Boundary of the dynamic preload segment (in pages) |
| `6` | `ZBEGIN` | 2 | Initial PC address inside Z-code space |
| `8` | `ZVOCAB` | 2 | Offset to Vocabulary Table |
| `10` | `ZOBJEC` | 2 | Offset to Object Table |
| `12` | `ZGLOBA` | 2 | Offset to Global Variable Table |
| `14` | `ZPURBT` | 2 | Size of the writable/pure Z-code section |
| `24` | `ZFWORD` | 2 | Offset to F-Words (Abbreviations) Table |
| `26` | `ZLENTH` | 2 | Total size of the Z-code file in words |
| `28` | `ZCHKSM` | 2 | Checksum word of Z-code file |

---

## 4. Retiring Hardware-Direct Routines

Because the interpreter executes within the NitrOS-9 operating system framework, raw hardware addresses and direct vectors are not accessed. Standard standalone routines are replaced by standard OS-9 requests:

*   **Keyboard scanning (`MYCAT`/`POLCAT` replacement):** Replaced by standard blocking/non-blocking reads (`os9 I$Read`) from path `0` (stdin).
*   **Text rendering (`MYCHR`/`CHROUT` replacement):** Replaced by system-level terminal output writes (`os9 I$Write`) to path `1` (stdout).
*   **Disk sector-access (`MYCON`/`DSKCON` replacement):** Replaced by file seeks (`os9 I$Seek`) and file reads (`os9 I$Read`) relative to `path_num`.
*   **Timer Interrupts (`DIRQSV`):** Handled transparently by the NitrOS-9 kernel.
