# Booting NitrOS-9 on CoCo 2B with MAME and pyDriveWire (Serial Bit-Banging)

This guide provides step-by-step instructions for running **NitrOS-9 (Level 1)** on a **Tandy Color Computer 2B (`coco2b`)** inside **MAME**, using cycle-accurate **RS-232 serial port bit-banging** to communicate with **pyDriveWire** over TCP. It also covers capturing **full instruction traces** using MAME's built-in debugger.

---

## Architecture and Overview

In this pure DriveWire configuration, **no physical floppy controller (`-ext fdc`) or local floppy disk image is required**. All disk storage is served over the network by pyDriveWire via the CoCo's serial port.

```
+-------------------------------------------------------------------------------+
|                                MAME Emulator                                  |
|                                                                               |
|  +--------------------+        +-------------------------------------------+  |
|  |  CoCo 2B Emulation |        | Serial Port Bit-Banging Emulation         |  |
|  |  - 6809 CPU (1MHz) |        | - Cartridge: hdbdw3cc2.rom (HDB-DOS CC2)  |  |
|  |  - 64KB RAM        |<------>| - Slot: -rs232 null_modem                 |  |
|  |  - 6821 PIA RS-232 |        | - Device: -bitb socket.127.0.0.1:65504    |  |
|  +--------------------+        +---------------------+---------------------+  |
+------------------------------------------------------|------------------------+
                                                       | TCP Serial Stream
                                                       | (Port 65504 / 57600 baud)
                                                       v
                                     +-----------------------------------+
                                     |         pyDriveWire Server        |
                                     |  - Python / PyPy 2.7              |
                                     |  - Serves OS-9 / DW disk images   |
                                     |  - Web UI on port 6800            |
                                     |                                   |
                                     |  Drive 0: infocom_coco_dw.dsk     |
                                     |  Drive 1: infocom_save.dsk (/X1)  |
                                     +-----------------------------------+
```

### How Serial Bit-Banging Works

1. **Hardware Emulation**:
   MAME accurately emulates the serial I/O pins connected to the Motorola 6821 PIA (PIA1). The CPU transmits and receives serial data by cycle-timing bit transitions directly in software at 57,600 baud.
2. **Bitbanger Stream Device (`-bitb`)**:
   MAME's `null_modem` / `bitbanger` device captures the serial bit stream from the PIA and tunnels the serialized bytes over a standard TCP socket to pyDriveWire.
3. **NitrOS-9 Driver**:
   Uses the standard NitrOS-9 Level 1 DriveWire 6809 driver (`dwread_bb6809.asm` / `dwwrite_bb6809.asm`), which is built by default in `recipes/coco/dw`.
4. **Bootstrapping**:
   The HDB-DOS serial ROM for CoCo 2 (`hdbdw3cc2.rom`) is attached as the cartridge. Executing `DOS` in Color BASIC sends the OS-9 boot request across the serial port to pyDriveWire Drive 0.

---

## How Disk Images Are Mounted in pyDriveWire

Because DriveWire serves as the storage system, all virtual disk images are mounted inside **pyDriveWire** as virtual drives 0 through 3 (which NitrOS-9 addresses as `/DD` for the boot drive, and `/X1`, `/X2`, `/X3` for additional drives).

### 1. Command-Line at Startup
Mount disk images directly when starting pyDriveWire:
```bash
# Mounts OS-9 boot disk to Drive 0 and save disk to Drive 1
./pyDriveWire --ui-port 6800 --accept --port 65504 \
    /path/to/infocom_coco_dw.dsk \
    /path/to/infocom_save.dsk
```

### 2. Interactive Console / REPL
At the `pyDriveWire>` prompt:
```text
# Show current drive assignments:
dw disk show

# Mount a disk into Drive 0:
dw disk insert 0 /path/to/infocom_coco_dw.dsk

# Mount a secondary disk into Drive 1:
dw disk insert 1 /path/to/infocom_save.dsk

# Eject a disk:
dw disk eject 1
```

### 3. Web User Interface (Port 6800)
1. Open [http://127.0.0.1:6800](http://127.0.0.1:6800) in your browser.
2. Under **Menu**, select **Disk Images**.
3. Enter the file path or upload an image for **Drive 0**, **Drive 1**, etc., and click **Insert**.

---

## Step-by-Step Instructions

### Step 1: Build the Standard NitrOS-9 Level 1 DriveWire Image

Build the standard Level 1 DriveWire disk image using the default bit-banger driver:

```bash
export NITROS9DIR=/path/to/nitros9

cd $NITROS9DIR
make -C recipes/coco/dw clean
make -C recipes/coco/dw
```

To build the Infocom multi-game disk image (`infocom_coco_dw.dsk`) and create a formatted save disk (`infocom_save.dsk`):
```bash
cd /path/to/infocom-os9-port
make clean fujinet-coco
os9 format -t1024 -st18 -e -n"SAVE" infocom_save.dsk
```

---

### Step 2: Start the pyDriveWire Server

Start pyDriveWire using PyPy 2.7 listening on port `65504` with your disk mounted:

```bash
cd /path/to/pyDriveWire
./pyDriveWire --ui-port 6800 --accept --port 65504 \
    /path/to/infocom-os9-port/infocom_coco_dw.dsk \
    /path/to/infocom_save.dsk
```

---

### Step 3: Configure MAME Serial Baud Rate (57,600 Baud)

> [!IMPORTANT]
> **Why `?I/O ERROR` occurs:**
> MAME's `null_modem` serial device **defaults to 9600 baud**, but HDB-DOS (`hdbdw3cc2.rom`) and NitrOS-9 communicate over the CoCo 2 serial port at **57,600 baud**. You must configure MAME's TX and RX baud rates to `57600`.

#### Option A: Set via In-Game Menu (One-Time Setup)
1. Launch MAME (without autoboot) or pause it:
   ```bash
   mame coco2b \
       -window -skip_gameinfo \
       -cart /path/to/coco-shelf/toolshed/hdbdos/hdbdw3cc2.rom \
       -rs232 null_modem \
       -bitb socket.127.0.0.1:65504
   ```
2. Press **`Fn + Delete`** (on macOS) or **`Scroll Lock`** (on PC keyboards) to toggle MAME **UI Mode**.
3. Press `Tab` to open the MAME Menu.
4. Select **Machine Configuration**.
5. Change **TX Baud** from `9600` to `57600`.
6. Change **RX Baud** from `9600` to `57600`.
7. Press `Tab` to exit the MAME menu.
8. Press **`Fn + F3`** (on macOS) or **`F3` / Reset** while UI Mode is still active to reboot the machine with 57,600 baud.
9. Press **`Fn + Delete`** (on macOS) or **`Scroll Lock`** (on PC keyboards) to exit UI Mode and return to emulation input.

> [!NOTE]
> MAME automatically saves these settings in `~/Library/Application Support/mame/cfg/coco2b.cfg` for all future runs.

#### Option B: Pre-configure `coco2b.cfg` Directly
Create or edit `~/Library/Application Support/mame/cfg/coco2b.cfg`:
```xml
<?xml version="1.0"?>
<mameconfig version="10">
    <system name="coco2b">
        <input>
            <port tag=":rs232:null_modem:RS232_TXBAUD" type="CONFIG" mask="255" defvalue="7" value="12" />
            <port tag=":rs232:null_modem:RS232_RXBAUD" type="CONFIG" mask="255" defvalue="7" value="12" />
        </input>
    </system>
</mameconfig>
```

*(In MAME configuration files, `value="12"` (hex `0x0C`) sets the baud rate to 57,600 baud, overriding the default `defvalue="7"` which corresponds to 9,600 baud.)*

---

### Step 4: Launch MAME with Serial Bit-Banging

Launch MAME with autoboot enabled:

```bash
mame coco2b \
    -window -skip_gameinfo \
    -autoboot_delay 3 -autoboot_command "DOS\n" \
    -cart /path/to/coco-shelf/toolshed/hdbdos/hdbdw3cc2.rom \
    -rs232 null_modem \
    -bitb socket.127.0.0.1:65504
```

1. MAME boots into Extended Color BASIC with HDB-DOS.
2. The autoboot sequence enters `DOS`.
3. HDB-DOS requests the NitrOS-9 boot track over the serial port at 57600 baud, loads the kernel into RAM, and boots NitrOS-9.
4. NitrOS-9 initializes the `dwio` serial bit-banger driver, mounts the boot drive as `/DD` and the save disk as `/X1`, and presents the shell prompt (`$`).

---

### Step 5: Access Mounted Disks in NitrOS-9

From the NitrOS-9 shell:

```sh
# List files on the primary boot drive (/DD)
dir

# List files on a secondary DriveWire disk (/X1)
dir /X1

# Change directory to GAMES on Drive 0
chd /dd/GAMES

# Run an Infocom game
infocom zork1.z3
```

---

## Instruction Tracing in MAME

MAME includes a built-in execution tracer that can log every 6809 CPU instruction executed by the system to a file.

### 1. Automated Tracing via Debugger Script (Recommended)

To start logging immediately on startup without stopping in the interactive debugger UI:

1. **Create a debugger script file (e.g. `trace_script.txt`):**
   ```text
   trace mame_trace.log,maincpu,,{tracelog "A=%02X B=%02X X=%04X Y=%04X U=%04X S=%04X DP=%02X CC=%02X | ",a,b,x,y,u,s,dp,cc}
   go
   ```

2. **Launch MAME with `-debug` and `-debugscript`:**
   ```bash
   mame coco2b \
       -window -skip_gameinfo \
       -debug \
       -debugscript trace_script.txt \
       -autoboot_delay 3 -autoboot_command "DOS\n" \
       -cart /path/to/coco-shelf/toolshed/hdbdos/hdbdw3cc2.rom \
       -rs232 null_modem \
       -bitb socket.127.0.0.1:65504
   ```

MAME will execute normally while writing each executed instruction along with all CPU registers to `mame_trace.log`.

---

### 2. Interactive Tracing via the Debugger Window

1. Launch MAME with `-debug`:
   ```bash
   mame coco2b -debug \
       -cart /path/to/coco-shelf/toolshed/hdbdos/hdbdw3cc2.rom \
       -rs232 null_modem \
       -bitb socket.127.0.0.1:65504
   ```
2. In the debugger console window:
   - **Start trace with full register dumps on each line:**
     ```text
     trace trace.log,maincpu,,{tracelog "A=%02X B=%02X X=%04X Y=%04X U=%04X S=%04X DP=%02X CC=%02X | ",a,b,x,y,u,s,dp,cc}
     ```
   - **Trace basic instructions without registers:**
     ```text
     trace trace.log,maincpu
     ```
   - **Trace but skip subroutine internals (`JSR`/`BSR`):**
     ```text
     traceover trace.log,maincpu
     ```
   - **Resume execution:** Type `go` (or press `F5`).
   - **Stop tracing:**
     ```text
     trace off,maincpu
     ```

---

### Sample Trace Output Format

```text
A=00 B=00 X=0000 Y=A00E U=0000 S=0000 DP=00 CC=50 | A02A: LDX    #$FF20
A=00 B=00 X=FF20 Y=A00E U=0000 S=0000 DP=00 CC=58 | A02D: CLR    -$3,X
A=00 B=00 X=FF20 Y=A00E U=0000 S=0000 DP=00 CC=54 | A02F: CLR    -$1,X
A=00 B=00 X=FF20 Y=A00E U=0000 S=0000 DP=00 CC=54 | A031: CLR    -$4,X
A=00 B=00 X=FF20 Y=A00E U=0000 S=0000 DP=00 CC=54 | A033: LDD    #$FF34
A=FF B=34 X=FF20 Y=A00E U=0000 S=0000 DP=00 CC=58 | A036: STA    -$2,X
A=FF B=34 X=FF20 Y=A00E U=0000 S=0000 DP=00 CC=58 | A038: STB    -$3,X
A=FF B=34 X=FF20 Y=A00E U=0000 S=0000 DP=00 CC=50 | A03A: STB    -$1,X
A=FF B=34 X=FF20 Y=A00E U=0000 S=0000 DP=00 CC=50 | A03C: CLR    $1,X
A=FF B=34 X=FF20 Y=A00E U=0000 S=0000 DP=00 CC=54 | A03E: CLR    $3,X
A=FF B=34 X=FF20 Y=A00E U=0000 S=0000 DP=00 CC=54 | A040: DECA
A=FE B=34 X=FF20 Y=A00E U=0000 S=0000 DP=00 CC=58 | A041: STA    ,X
A=FE B=34 X=FF20 Y=A00E U=0000 S=0000 DP=00 CC=58 | A043: LDA    #$F8
A=F8 B=34 X=FF20 Y=A00E U=0000 S=0000 DP=00 CC=58 | A045: STA    $2,X
A=F8 B=34 X=FF20 Y=A00E U=0000 S=0000 DP=00 CC=58 | A047: STB    $1,X
A=F8 B=34 X=FF20 Y=A00E U=0000 S=0000 DP=00 CC=50 | A049: STB    $3,X
A=F8 B=34 X=FF20 Y=A00E U=0000 S=0000 DP=00 CC=50 | A04B: CLR    $2,X
A=F8 B=34 X=FF20 Y=A00E U=0000 S=0000 DP=00 CC=54 | A04D: LDB    #$02
A=F8 B=02 X=FF20 Y=A00E U=0000 S=0000 DP=00 CC=50 | A04F: STB    ,X
A=F8 B=02 X=FF20 Y=A00E U=FFC0 S=0000 DP=00 CC=50 | A051: LDU    #$FFC0
A=F8 B=02 X=FF20 Y=A00E U=FFC0 S=0000 DP=00 CC=58 | A054: LDB    #$10
A=F8 B=10 X=FF20 Y=A00E U=FFC0 S=0000 DP=00 CC=50 | A056: STA    ,U++
A=F8 B=10 X=FF20 Y=A00E U=FFC2 S=0000 DP=00 CC=58 | A058: DECB
A=F8 B=0F X=FF20 Y=A00E U=FFC2 S=0000 DP=00 CC=50 | A059: BNE    $A056
A=F8 B=0F X=FF20 Y=A00E U=FFC2 S=0000 DP=00 CC=50 | A056: STA    ,U++
A=F8 B=0F X=FF20 Y=A00E U=FFC4 S=0000 DP=00 CC=58 | A058: DECB
A=F8 B=0E X=FF20 Y=A00E U=FFC4 S=0000 DP=00 CC=50 | A059: BNE    $A056

   (loops for 42 instructions)

A=F8 B=00 X=FF20 Y=A00E U=FFE0 S=0000 DP=00 CC=54 | A05B: STA    $FFC9
A=F8 B=00 X=FF20 Y=A00E U=FFE0 S=0000 DP=00 CC=58 | A05E: TFR    B,DP
A=F8 B=00 X=FF20 Y=A00E U=FFE0 S=0000 DP=00 CC=58 | A060: LDB    #$04
```

---

## Quick Reference Summary

| Task | Command / Configuration |
|:---|:---|
| **Build Bit-Banger L1 Kernel** | `cd $(NITROS9DIR) && make -C recipes/coco/dw clean && make -C recipes/coco/dw` |
| **Start pyDriveWire** | `/path/to/pyDriveWire --ui-port 6800 --accept --port 65504 infocom_coco_dw.dsk` |
| **Launch MAME (Serial DW)** | `mame coco2b -cart hdbdw3cc2.rom -rs232 null_modem -bitb socket.127.0.0.1:65504 -autoboot_delay 3 -autoboot_command "DOS\n"` |
| **Launch MAME with Tracing** | Add `-debug -debugscript trace_script.txt` to the MAME launch command |
| **Mount DW Drive 0** | Pass file as first argument to `pyDriveWire` (or `dw disk insert 0 <file>`) |
| **Mount DW Drive 1** | Pass file as second argument to `pyDriveWire` (or `dw disk insert 1 <file>`) |
