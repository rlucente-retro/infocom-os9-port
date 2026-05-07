# NitrOS-9 System Call Documentation

This document provides a comprehensive instructional guide to the NitrOS-9 system calls. It is based on a direct analysis of the operating system's assembly source code.

## Table of Contents
- [Process Management](#process-management)
- [Memory Management](#memory-management)
- [I/O Management](#io-management)
- [Module Management](#module-management)
- [System Services](#system-services)
- [Other System Calls](#other-system-calls)

---

## Process Management

#### F$LINK (Function $0)

**Intent:** Link to a module already in memory.

**Status:** Implemented

- **Entry:** A = Module type, X = Address of the module name
- **Exit:** Y = Module entry point address, U = Module header address, A = Module type, B = Module revision, X = Address past the module name

**Description:** Searches for a module of the specified type and name in the module directory. If found, it increments its link count and returns its addresses.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/flink.asm`


#### F$LOAD (Function $1)

**Intent:** Load a module from a file into memory.

**Status:** Implemented

- **Entry:** A = Module type, X = Address of the pathlist (module name)
- **Exit:** Y = Module entry point address, U = Module header address, A = Module type, B = Module revision, X = Address past the module name

**Description:** Opens the specified file, loads the module into a newly allocated memory block, and returns its addresses and header information.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `3rdparty/utils/fpgarom/boot.asm`
  - `3rdparty/utils/fpgarom/test.asm`
  - `defs/os9.d`
  - `level1/modules/ioman.asm`
  - `level2/modules/ioman.asm`


#### F$UNLINK (Function $2)

**Intent:** Unlink a module from the process.

**Status:** Implemented

- **Entry:** U = Address of the module header
- **Exit:** None

**Description:** Decrements the link count of the specified module. If the count reaches zero, the memory occupied by the module is deallocated.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/funlink.asm`


#### F$FORK (Function $3)

**Intent:** Start a new program as a child process.

**Status:** Implemented

- **Entry:** A = Module type/language byte, B = Size of optional data area (in pages), X = Address of the module name or filename, Y = Size of the parameter area (in bytes), U = Starting address of the parameter area
- **Exit:** A = New process ID (PID), X = Address past the module name

**Description:** Starts a new program as a child process. It allocates a process descriptor, memory, copies parameters, and schedules the new process.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/ffork.asm`


#### F$WAIT (Function $4)

**Intent:** Suspend the calling process until a child process terminates.

**Status:** Implemented

- **Entry:** None
- **Exit:** A = PID of the child that exited, B = Exit status/error code of the child

**Description:** Suspends the calling process until a child process terminates. Returns the PID and exit status of the terminated child.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/fwait.asm`
  - `level2/modules/kernel/fallprc.asm`


#### F$CHAIN (Function $5)

**Intent:** Chain Process to New Module

**Status:** Implemented

- **Entry:** A = Module type/language byte, B = Size of optional data area (in pages), X = Address of the module name or filename, Y = Size of the parameter area (in bytes), U = Starting address of the parameter area
- **Exit:** Does not return to caller on success

**Description:** Loads and executes a new primary module, replacing the current process. It unlinks the old primary module and reconfigures the data area.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/fchain.asm`


#### F$EXIT (Function $6)

**Intent:** Terminate the current process.

**Status:** Implemented

- **Entry:** B = Exit status/error code
- **Exit:** Does not return

**Description:** Terminates the current process, deallocates its resources, and returns the status to the waiting parent process.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `3rdparty/utils/sleuth3/cssmiscl3.asm`
  - `3rdparty/utils/sleuth3/sleuth3.asm`
  - `defs/os9.d`
  - `level1/modules/kernel/fexit.asm`


#### F$SEND (Function $8)

**Intent:** Send Signal to Process

**Status:** Implemented

- **Entry:** A = Process ID of recipient, B = Signal code
- **Exit:** None

**Description:** Sends a single-byte signal to the specified process. If the process is sleeping or waiting, it is activated to process the signal.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/fsend.asm`


#### F$ICPT (Function $9)

**Intent:** Set Signal Intercept

**Status:** Implemented

- **Entry:** X = Address of the intercept routine, U = Address of the routine's data area
- **Exit:** None

**Description:** Registers a routine to handle signals sent to the process. When a signal is received, the kernel calls this routine with B = signal code and U = data area.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/ficpt.asm`


#### F$SLEEP (Function $A)

**Intent:** Suspend Process

**Status:** Implemented

- **Entry:** X = Number of system clock ticks to sleep (0 = indefinitely until signal)
- **Exit:** X = Remaining ticks if awakened early

**Description:** Suspends the process for the specified number of clock ticks. A value of 1 sleeps for the remainder of the current time slice.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/fsleep.asm`


#### F$SSPD (Function $B)

**Intent:** Suspend Process

**Status:** Typically not implemented in current NitrOS-9 kernels.

- **Entry:** A = Process ID to suspend
- **Exit:** None

**Description:** Historically intended to suspend the specified process by removing it from the active process queue. In NitrOS-9, process suspension is typically handled through signals (F$Send) and the F$Sleep system call. Most current kernels do not provide a direct implementation for this function code.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`


#### F$ID (Function $C)

**Intent:** Return Process ID

**Status:** Implemented

- **Entry:** None
- **Exit:** A = Process ID, Y = User ID

**Description:** Returns the calling process's unique process ID and the associated user ID.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/fid.asm`


#### F$SPRIOR (Function $D)

**Intent:** Set Process Priority

**Status:** Implemented

- **Entry:** A = Process ID to modify, B = New priority (0-255)
- **Exit:** None

**Description:** Changes the scheduling priority of the specified process. A process can only change the priority of processes with the same user ID.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/fsprior.asm`


#### F$SSWI (Function $E)

**Intent:** Set Software Interrupt

**Status:** Implemented

- **Entry:** A = Software interrupt code (1=SWI, 2=SWI2, 3=SWI3), X = Address of the new handler routine
- **Exit:** None

**Description:** Sets local software interrupt vectors for the process. Note that OS-9 system calls use SWI2.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/fsswi.asm`


#### F$APROC (Function $2C)

**Intent:** Enter Active Process Queue

**Status:** Implemented

- **Entry:** X = The address of the process descriptor to insert.
- **Exit:** None.

**Description:** Insert process into active process queue.  Error:  B = A non-zero error code. CC = Carry flag set to indicate error.  F$AProc inserts a process into the active process queue so that the kernel can schedule the process for execution. The kernel sorts all processes in the queue by process age (the count of how many process switches have occurred since the process’s last time slice). When a process moves to the active process queue, the kernel sets its age according to its priority. The higher the priority, the higher the age.  An exception is a newly active process that was deactivated while in the system state. The kernel gives such a process higher priority because it's typically executing critical routines that affect shared system resources.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/faproc.asm`


#### F$NPROC (Function $2D)

**Intent:** Start Next Process

**Status:** Implemented

- **Entry:** None.
- **Exit:** None. Control doesn't return to the caller. F$NProc takes the next process out of the active process queue and initiates its execution. If the queue doesn't contain a process, the kernel waits for an interrupt and then checks the queue again. The process calling F$NProc must already be in one of the three process queues. If it isn't, it becomes unknown to the system even though the process descriptor still exists and can be displayed by `procs`.

**Description:** Execute the next process in the active process queue.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/fnproc.asm`
  - `level2/modules/kernel/ccbfnproc.asm`


#### F$ALLPRC (Function $4B)

**Intent:** Allocate Process Descriptor

**Status:** Implemented

- **Entry:** None
- **Exit:** U = Address of the new process descriptor

**Description:** Allocates a new 512-byte process descriptor from system memory and initializes its technical fields.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/fallprc.asm`


#### F$DELPRC (Function $4C)

**Intent:** Deallocate Process Descriptor

**Status:** Implemented

- **Entry:** A = Process ID to deallocate
- **Exit:** None

**Description:** Deallocates the process descriptor and returns its memory to the system pool.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/fallprc.asm`


#### F$SUSER (Function $1C)

**Intent:** Set User ID number ($1C)

**Status:** Implemented

- **Entry:** Y = Desired user ID
- **Exit:** None

**Description:** Sets the user ID for the calling process (privileged call).

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/fsuser.asm`


#### F$UNLOAD (Function $1D)

**Intent:** Unlink Module by name

**Status:** Implemented

- **Entry:** A = Module type, X = Pointer to module name
- **Exit:** None

**Description:** Decrements the link count of a module identified by its type and name. If the link count reaches zero, the module is removed from memory. For I/O modules (File Managers, Drivers, etc.), it also handles removing associated device table entries via `F$IODel`.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/funload.asm`


#### F$GPRDSC (Function $18)

**Intent:** Get Process Descriptor copy

**Status:** Implemented

- **Entry:** A = Desired process ID, X = 512 byte buffer pointer
- **Exit:** None

**Description:** Copies the 512-byte process descriptor of the specified PID into the caller's buffer. This is a privileged call typically used by system utilities like `procs`.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/fgprdsc.asm`


## Memory Management


#### F$MEM (Function $7)

**Intent:** Change the size of the process's data area.

**Status:** Implemented

- **Entry:** D = Desired size in bytes (0 to query current size)
- **Exit:** D = Current size in bytes, Y = Upper bound address

**Description:** Changes the size of the process's data area. If increasing, it requests new memory from the system. If 0, it returns the current status.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/coco1/modules/sspak.asm`
  - `level1/modules/kernel/fmem.asm`


#### F$SRQMEM (Function $28)

**Intent:** System Memory Request

**Status:** Implemented

- **Entry:** D = Number of bytes requested
- **Exit:** D = Number of bytes allocated, U = Start address of allocated area

**Description:** Allocates contiguous pages (256 bytes each) of system memory.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/fsrqmem.asm`
  - `level2/modules/kernel/ccbfsrqmem.asm`


#### F$SRTMEM (Function $29)

**Intent:** System Memory Return

**Status:** Implemented

- **Entry:** D = Number of bytes to return, U = Start address of area to return
- **Exit:** None

**Description:** Returns a previously allocated block of system memory to the free memory pool.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/fsrqmem.asm`
  - `level2/modules/kernel/ccbfsrqmem.asm`


#### F$ALLBIT (Function $13)

**Intent:** Allocate in Bit Map

**Status:** Implemented

- **Entry:** D = First bit number to set, X = Allocation bitmap address, Y = Number of bits to set
- **Exit:** None

**Description:** Marks a range of bits as 'allocated' (sets them to 1) in the specified bitmap.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/fallbit.asm`


#### F$DELBIT (Function $14)

**Intent:** Deallocate in Bit Map

**Status:** Implemented

- **Entry:** D = First bit number to clear, X = Allocation bitmap address, Y = Number of bits to clear
- **Exit:** None

**Description:** Marks a range of bits as 'free' (clears them to 0) in the specified bitmap.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/fallbit.asm`


#### F$SCHBIT (Function $12)

**Intent:** Search Bit Map

**Status:** Implemented

- **Entry:** X = Allocation bitmap address, D = Starting bit number, Y = Number of clear bits requested, U = End address of bitmap
- **Exit:** D = Starting bit number found, Y = Size of block found

**Description:** Searches for a contiguous range of clear bits in the specified bitmap.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/fallbit.asm`


#### F$MOVE (Function $38)

**Intent:** Move Data (low bound first)

**Status:** Implemented

- **Entry:** A = Source task #, B = Destination task #, X = Source pointer, Y = Byte count, U = Destination pointer
- **Exit:** None

**Description:** Copies a block of data between two technical task address spaces.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/mc09l2/modules/mc09clock.asm`
  - `level2/modules/clock.asm`
  - `level2/modules/kernel/fmove.asm`


#### F$ALLRAM (Function $39)

**Intent:** Allocate RAM blocks

**Status:** Implemented

- **Entry:** B = Desired block count
- **Exit:** D = Beginning RAM block number

**Description:** Allocates physical RAM blocks from the system block map.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/fallram.asm`


#### F$DELRAM (Function $51)

**Intent:** Deallocate RAM blocks

**Status:** Implemented

- **Entry:** A = Starting block number, B = Block count
- **Exit:** None

**Description:** Deallocates a range of physical RAM blocks, returning them to the system pool.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/fdelram.asm`


#### F$ALLTSK (Function $3F)

**Intent:** Allocate Process Task number

**Status:** Implemented

- **Entry:** X = Process descriptor pointer
- **Exit:** None

**Description:** Allocates a unique hardware task number for a process and initializes its technical DAT mapping.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/falltsk.asm`


#### F$DELTSK (Function $40)

**Intent:** Deallocate Process Task number

**Status:** Implemented

- **Entry:** X = Process descriptor pointer
- **Exit:** None

**Description:** Deallocates the hardware task number assigned to a process.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/falltsk.asm`


#### F$SETTSK (Function $41)

**Intent:** Set Process Task DAT registers

**Status:** Implemented

- **Entry:** X = Process descriptor pointer
- **Exit:** None

**Description:** Updates the hardware MMU registers for a process task based on its current DAT image.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/falltsk.asm`


#### F$RESTSK (Function $42)

**Intent:** Reserve Task number

**Status:** Implemented

- **Entry:** None
- **Exit:** B = Task number

**Description:** Reserves a hardware task number for system use.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/falltsk.asm`


#### F$RELTSK (Function $43)

**Intent:** Release Task number

**Status:** Implemented

- **Entry:** B = Task number
- **Exit:** None

**Description:** Releases a previously reserved system task number.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/falltsk.asm`


#### F$ALLIMG (Function $3A)

**Intent:** Allocate Image RAM blocks

**Status:** Implemented

- **Entry:** A = Starting block number, B = Block count, X = Process descriptor pointer
- **Exit:** None

**Description:** Allocates physical RAM blocks and maps them into a process's DAT image.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/fallimg.asm`


#### F$DELIMG (Function $3B)

**Intent:** Deallocate Image RAM blocks

**Status:** Implemented

- **Entry:** A = Starting block number, B = Block count, X = Process descriptor pointer
- **Exit:** None

**Description:** Deallocates physical RAM blocks and removes them from a process's DAT image.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/fdelimg.asm`


#### F$SETIMG (Function $3C)

**Intent:** Set Process DAT Image

**Status:** Implemented

- **Entry:** A = Starting block number, B = Block count, X = Process descriptor pointer, U = New image data pointer
- **Exit:** None

**Description:** Copies technical DAT image data directly into a process descriptor.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/ffreehb.asm`


#### F$FREELB (Function $3D)

**Intent:** Get Free Low Block

**Status:** Implemented

- **Entry:** B = Block count, Y = DAT image pointer
- **Exit:** A = Lowest free block number

**Description:** Finds the lowest contiguous range of free blocks in the specified DAT image. This is typically used by the kernel when allocating memory to find a suitable gap in the process's address space.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/ffreehb.asm`


#### F$FREEHB (Function $3E)

**Intent:** Get Free High Block

**Status:** Implemented

- **Entry:** B = Block count, Y = DAT image pointer
- **Exit:** A = Highest free block number

**Description:** Finds the highest contiguous range of free blocks in the specified DAT image.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/ffreehb.asm`


#### F$ALL64 (Function $30)

**Intent:** Allocate Process/Path Descriptor

**Status:** Implemented

- **Entry:** X = Base address of page table
- **Exit:** A = New block number, Y = Address of block

**Description:** Allocates a 64-byte memory block (used for process or path descriptors).

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/fall64.asm`
  - `level2/modules/kernel/ffind64.asm`


#### F$FIND64 (Function $2F)

**Intent:** Find Process/Path Descriptor

**Status:** Implemented

- **Entry:** A = Block number, X = Base address of page table
- **Exit:** Y = Address of block

**Description:** Locates the memory address of a 64-byte block when given its ID number.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/ffind64.asm`
  - `level2/modules/kernel/ffind64.asm`


#### F$RET64 (Function $31)

**Intent:** Return Process/Path Descriptor

**Status:** Implemented

- **Entry:** A = Block number, X = Base address of page table
- **Exit:** None

**Description:** Returns a 64-byte memory block to the system pool.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/fret64.asm`
  - `level2/modules/kernel/ffind64.asm`


#### F$BTMEM (Function $36)

**Intent:** Bootstrap Memory Request

**Status:** Implemented (Mapped to F$SRqMem)

- **Entry:** D = Number of bytes requested
- **Exit:** D = Number of bytes allocated, U = Start address of allocated area

**Description:** Requests memory during the system bootstrap phase. In current NitrOS-9 kernels, this system call is directly mapped to the standard system memory request call (F$SRqMem).

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/krn.asm`


#### F$MAPBLK (Function $4F)

**Intent:** Map Specific Block

**Status:** Implemented

- **Entry:** B = The number of blocks to map in. X = The starting block number.
- **Exit:** U = The address of the first block in the caller's address space.

**Description:** Map one or more blocks into the calling process' address space.  Error:  B = A non-zero error code. CC = Carry flag set to indicate error.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/fmapblk.asm`


#### F$CLRBLK (Function $50)

**Intent:** Clear Specific Block

**Status:** Implemented

- **Entry:** B = Number of blocks, U = Address of first block
- **Exit:** None

**Description:** Clears a range of blocks from the calling process's DAT image, effectively unmapping them. It does NOT zero out the RAM itself, but marks the blocks as free in the process's logical address space.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/fclrblk.asm`
  - `level2/wildbits/cmds/drawtest.asm`


#### F$DATLOG (Function $44)

**Intent:** Convert DAT Block/Offset to Logical

**Status:** Implemented

- **Entry:** B = DAT image block number, X = Offset into block
- **Exit:** X = Logical address

**Description:** Converts a hardware block/offset pair into a logical memory address.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/fdatlog.asm`


#### F$DATTMP (Function $45)

**Intent:** Make temporary DAT image (Obsolete)

**Status:** No implementation found in kernel source code

- **Entry:** N/A
- **Exit:** N/A

**Description:** This system call is obsolete and no longer implemented in current NitrOS-9 kernels.

- **Implementation References:**
  - `defs/os9.d`


#### F$GBLKMP (Function $19)

**Intent:** Get System Block Map copy ($19)

**Status:** Implemented

- **Entry:** X = 1024 byte buffer pointer
- **Exit:** D = Bytes per block, Y = Size of block map

**Description:** Retrieves a copy of the system physical memory block map.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/fgblkmp.asm`


## I/O Management

#### I$ATTACH (Function $80)

**Intent:** Attach I/O Device

**Status:** Implemented

- **Entry:** A = Device access mode, X = Address of device name
- **Exit:** U = Pointer to device table entry, X = Address past device name

**Description:** Links the process to a device and its driver, initializing technical metadata in the device table.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/ioman.asm`
  - `level2/modules/ioman.asm`


#### I$DETACH (Function $81)

**Intent:** Detach I/O Device

**Status:** Implemented

- **Entry:** U = Pointer to device table entry
- **Exit:** None

**Description:** Unlinks the process from a device. If the device's user count reaches zero, its resources are deallocated.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/ioman.asm`
  - `level2/modules/ioman.asm`


#### I$DUP (Function $82)

**Intent:** Duplicate Path

**Status:** Implemented

- **Entry:** A = Path number to duplicate
- **Exit:** A = New path number

**Description:** Allocates a new path number that refers to the same file or device as an existing open path.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/ioman.asm`
  - `level2/modules/ioman.asm`


#### I$CREATE (Function $83)

**Intent:** Create New File

**Status:** Implemented

- **Entry:** A = Access mode, B = File attributes, X = Address of the pathlist
- **Exit:** A = Path number

**Description:** Creates a new file or device and opens it for access, returning a unique path number.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/ioman.asm`
  - `level2/modules/ioman.asm`


#### I$OPEN (Function $84)

**Intent:** Open an existing file or device.

**Status:** Implemented

- **Entry:** A = Access mode (Read, Write, etc.), X = Address of the pathlist
- **Exit:** A = Path number

**Description:** Opens an existing file or device for access and returns a unique path number for subsequent operations.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/ioman.asm`
  - `level2/modules/ioman.asm`


#### I$MAKDIR (Function $85)

**Intent:** Make Directory File

**Status:** Implemented

- **Entry:** A = Device access mode (usually $05 for DIR+WRITE), X = Address of the pathlist
- **Exit:** None

**Description:** Creates a new directory file at the specified technical pathlist location.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/ioman.asm`
  - `level2/modules/ioman.asm`


#### I$CHGDIR (Function $86)

**Intent:** Change Default Directory

**Status:** Implemented

- **Entry:** A = Access mode (usually $01 for READ), X = Address of the pathlist
- **Exit:** None

**Description:** Changes the current working directory or execution directory for the process.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/ioman.asm`
  - `level2/modules/ioman.asm`


#### I$DELETE (Function $87)

**Intent:** Delete File

**Status:** Implemented

- **Entry:** X = Address of the pathlist
- **Exit:** None

**Description:** Deletes the file specified by the pathlist. The process must have write permission for the file.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/ioman.asm`
  - `level2/modules/ioman.asm`


#### I$DELETX (Function $90)

**Intent:** Delete from current exec dir

**Status:** Implemented

- **Entry:** X = Address of the pathlist
- **Exit:** None

**Description:** Deletes a file from the current execution directory.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/ioman.asm`
  - `level2/modules/ioman.asm`


#### I$SEEK (Function $88)

**Intent:** Change Current Position

**Status:** Implemented

- **Entry:** A = Path number, X = High 16 bits of position, U = Low 16 bits of position
- **Exit:** None

**Description:** Changes the current file position for an open path. Both X and U together form a 32-bit offset.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/ioman.asm`
  - `level2/modules/ioman.asm`


#### I$READ (Function $89)

**Intent:** Read raw data from a path.

**Status:** Implemented

- **Entry:** A = Path number, X = Buffer address, Y = Number of bytes to read
- **Exit:** Y = Number of bytes actually read

**Description:** Reads the specified number of bytes from an open path into a memory buffer.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/coco1/modules/sspak.asm`
  - `level1/modules/ioman.asm`
  - `level1/wildbits/modules/wizfi.asm`
  - `level2/modules/ioman.asm`


#### I$WRITE (Function $8A)

**Intent:** Write raw data to a path.

**Status:** Implemented

- **Entry:** A = Path number, X = Buffer address, Y = Number of bytes to write
- **Exit:** Y = Number of bytes actually written

**Description:** Writes the specified number of bytes from a memory buffer to an open path.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/coco1/modules/sspak.asm`
  - `level1/modules/ioman.asm`
  - `level2/modules/ioman.asm`


#### I$READLN (Function $8B)

**Intent:** Read Line of ASCII Data

**Status:** Implemented

- **Entry:** A = Path number, X = Buffer address, Y = Maximum number of bytes to read
- **Exit:** Y = Number of bytes actually read

**Description:** Reads a line of ASCII data (terminated by a carriage return) from an open path.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/ioman.asm`
  - `level2/modules/ioman.asm`


#### I$WRITLN (Function $8C)

**Intent:** Write Line of ASCII Data

**Status:** Implemented

- **Entry:** A = Path number, X = Buffer address, Y = Number of bytes to write
- **Exit:** Y = Number of bytes actually written

**Description:** Writes a line of ASCII data (appends a carriage return) to an open path.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/ioman.asm`
  - `level2/modules/ioman.asm`


#### I$GETSTT (Function $8D)

**Intent:** Get Path Status

**Status:** Implemented

- **Entry:** A = Path number, B = Status code, (other registers depend on code)
- **Exit:** Depends on the status code requested

**Description:** Retrieves technical status information about an open path or device.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/ioman.asm`
  - `level2/modules/ioman.asm`


#### I$SETSTT (Function $8E)

**Intent:** Set Path Status

**Status:** Implemented

- **Entry:** A = Path number, B = Status code, (other registers depend on code)
- **Exit:** None

**Description:** Modifies technical status information or issues control commands to an open path or device.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`


#### I$CLOSE (Function $8F)

**Intent:** Close an open path.

**Status:** Implemented

- **Entry:** A = Path number
- **Exit:** None

**Description:** Closes an open path, releasing its technical resources and notifying the file manager.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/ioman.asm`
  - `level2/modules/ioman.asm`


#### I$MODDSC (Function $91)

**Intent:** Modify SCF/RBF Descriptor in Memory

**Status:** Implemented

- **Entry:** A = Path number, B = Number of byte pairs, X = Address of device descriptor name, U = Address of byte pairs buffer
- **Exit:** None

**Description:** Modifies technical configuration parameters in a device descriptor that is already loaded into memory.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/ioman.asm`


#### F$IODEL (Function $33)

**Intent:** Delete I/O Module

**Status:** Implemented

- **Entry:** X = Address of a module (FMgr, Driver, or Descriptor)
- **Exit:** None

**Description:** Deletes all entries from the system device table that reference the specified module.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/ioman.asm`
  - `level2/modules/ioman.asm`


#### F$IOQU (Function $2B)

**Intent:** Enter I/O Queue

**Status:** Implemented

- **Entry:** U=Callers register stack ptr
- **Exit:** None

**Description:** processes I/O Queue, and puts 'A' to sleep Note: This is a linked list (with each process descriptor containing process #'s for both the next entry (P$IOQN) and the previous entry (P$IOQP).

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/ioman.asm`
  - `level2/modules/ioman.asm`


## Module Management

#### F$FMODUL (Function $4E)

**Intent:** Find Module Directory Entry

**Status:** Implemented

- **Entry:** A = Module type, X = Module name pointer, Y = DAT image pointer
- **Exit:** A = Module type, B = Module revision, X = Updated past name, U = Directory entry pointer

**Description:** Finds a module's technical entry in the system module directory.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/ffmodul.asm`


#### F$VMODUL (Function $2E)

**Intent:** Validate Module

**Status:** Implemented

- **Entry:** X = Pointer to the module to validate
- **Exit:** U = Pointer to module header (possibly updated to higher revision)

**Description:** Validates a module in memory, checking its header and CRC, and comparing it with existing modules.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/fvmodul.asm`


#### F$NMLINK (Function $1F)

**Intent:** Color Computer 3 Non-Mapping Link ($21)

**Status:** Implemented

- **Entry:** A = Module type, X = Address of the module name
- **Exit:** A = Module type, B = Module revision, X = Address past the module name, Y = Memory requirement

**Description:** Links to a module without mapping it into the process's address space. Used for technical system-level module management.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/ioman.asm`


#### F$NMLOAD (Function $20)

**Intent:** Color Computer 3 Non-Mapping Load ($22)

**Status:** Implemented

- **Entry:** X = Address of the pathlist
- **Exit:** A = Module type, B = Module revision, X = Address past the module name, Y = Memory requirement

**Description:** Loads a module from a file into system memory without mapping it into the caller's process space.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/ioman.asm`


#### F$CRCMOD (Function $55)

**Intent:** CRC mode, toggle or report current status

**Status:** Implemented

- **Entry:** A = Flag (0=report, 1=off, 2=on)
- **Exit:** A = Current state (0=off, 1=on)

**Description:** Enables, disables, or reports the status of automatic system CRC checking.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/fcrcmod.asm`


#### F$ELINK (Function $4D)

**Intent:** Link using Module Directory Entry

**Status:** Implemented

- **Entry:** B = Module type, X = Module directory entry pointer
- **Exit:** Y = Entry point, U = Header pointer, A = Type, B = Attributes/Revision

**Description:** Links to a memory module using its direct directory entry instead of a name.

- **Implementation References:**
  - `defs/os9.d`
  - `level1/modules/kernel/flink.asm`


#### F$SLINK (Function $34)

**Intent:** System Link

**Status:** Implemented

- **Entry:** A = Module type, X = Name pointer, Y = DAT image pointer
- **Exit:** Y = Entry point, U = Header pointer, A = Type, B = Attributes/Revision

**Description:** Links to a module using its name and a specific technical DAT image for name lookup.

- **Implementation References:**
  - `defs/os9.d`
  - `level1/modules/kernel/flink.asm`


#### F$GMODDR (Function $1A)

**Intent:** Get Module Directory copy ($1A)

**Status:** Implemented

- **Entry:** X = 2048 byte buffer pointer
- **Exit:** Y = End address in buffer, U = Start address in buffer

**Description:** Retrieves a copy of the system module directory.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/fgmoddr.asm`


## System Services

#### F$TIME (Function $15)

**Intent:** Get the current system time.

**Status:** Implemented

- **Entry:** X = Address of a 6-byte buffer
- **Exit:** Buffer filled with: YY, MM, DD, HH, MM, SS

**Description:** Returns the current system date and time in the provided 6-byte buffer.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/mc09/modules/mc09clock.asm`
  - `level1/modules/clock.asm`


#### F$STIME (Function $16)

**Intent:** Set the current system time.

**Status:** Implemented

- **Entry:** X = Address of a 6-byte buffer containing new time (YY, MM, DD, HH, MM, SS)
- **Exit:** None

**Description:** Sets the current system date and time using the provided packet information.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/mc09/modules/mc09clock.asm`
  - `level1/modules/clock.asm`
  - `level1/modules/kernel/fstime.asm`


#### F$CRC (Function $17)

**Intent:** Generate CRC ($17)

**Status:** Implemented

- **Entry:** X = Start address of data, Y = Number of bytes, U = Pointer to 3-byte CRC accumulator
- **Exit:** None (CRC updated in accumulator)

**Description:** Generates or updates a CRC (Cyclic Redundancy Check) value for a block of memory.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/fcrc.asm`
  - `level1/modules/kernel/fvmodul.asm`


#### F$PRSNAM (Function $10)

**Intent:** Parse Pathlist Name

**Status:** Implemented

- **Entry:** X = The address of the pathlist to parse, U = Starting address of the routine’s memory area
- **Exit:** X = The address of the character past the optional "/", Y = The address of the last character plus one, A = The trailing delimiter character, B = The length of the pathlist

**Description:** Scans the input text string for a legal NitrOS-9 name. It terminates the name at any character that is not a legal name character (e.g., a space, comma, or another slash). This call is essential for processing pathlist arguments. Because it processes only one name component at a time, multiple calls are needed to parse a full pathlist.

**Example:**
```
Before: /D0/PAYROLL
        ^X

After:  /D0/PAYROLL
         ^X ^Y       B = 2 (length of "D0")
```

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/fprsnam.asm`


#### F$CMPNAM (Function $11)

**Intent:** Compare Two Names

**Status:** Implemented

- **Entry:** X = Address of the first name, Y = Address of the second name, B = Length of the first name
- **Exit:** CC = Carry flag clear if names match; otherwise, set

**Description:** Compares two names for equality, typically used in conjunction with `F$PrsNam`. The comparison is generally case-insensitive. The second name (pointed to by Y) must have the most significant bit (bit 7) of its last character set to indicate the end of the string.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/fcmpnam.asm`


#### F$PERR (Function $F)

**Intent:** Print Error

**Status:** Implemented

- **Entry:** B = Error code
- **Exit:** Error message printed to stderr (path 2)

**Description:** Prints a standard technical error message string for the specified error code.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/cmds/printerr.asm`
  - `level1/modules/ioman.asm`
  - `level2/modules/ioman.asm`


#### F$DEBUG (Function $21)

**Intent:** Drop the system into the debugger ($23)

**Status:** Implemented

- **Entry:** A = Function code (255=Reboot)
- **Exit:** None

**Description:** Enters the system debugger or issues a hardware reboot command.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/fdebug.asm`
  - `level1/wildbits/modules/rbmem.asm`
  - `level2/modules/kernel/fdebug.asm`


#### F$SSVC (Function $32)

**Intent:** Service Request Table Initialization

**Status:** Implemented

- **Entry:** Y = The address of the system call initialization table.
- **Exit:** None.

**Description:** Add or replace system calls.  Error:  B = A non-zero error code. CC = Carry flag set to indicate error.  F$SSvc adds or replaces system calls in the kernel's user and system mode system call tables. Y holds the address of a table that contains the function codes and offsets for system call routines. The table has the following format:  Relative Address      Use ---------------------------------- | $00	       Function code      |<-- First entry | $01         Offset from byte 3   | | $02         to function handler  | |..................................| | $03	       Function code      |	<-- Second entry | $04         Offset From byte 6   | | $05         to function handler  | |..................................| |                                  | |           More Entries           | |                                  | |..................................| |               $80                | End-of-table mark ----------------------------------  If the most significant bit of the function code is set, the kernel updates the system table only; otherwise, both system and user tables are updated. The function request codes are in the range $29-$34. I/O calls are in the range $80-$90. To use a privileged system call, you must be executing a program that's executing in the system state. The system call handler routine must process the system call and return from the subroutine with an RTS instruction. The handler routing may alter all CPU registers, except SP. U holds the address of the register stack to the system call hander as shown in the following diagram:  Relative Address     Name ----------------------------------- U -->	CC        $00       R$CC A        $01       R$A (R$D) B        $02       R$B DP        $03       R$DP X        $04       R$X Y        $06       R$Y U        $08       R$U PC        $0A       R$PC

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/kernel/fssvc.asm`


#### F$IRQ (Function $2A)

**Intent:** Enter IRQ Polling Table

**Status:** Implemented

- **Entry:** D = Device status register address, X = Pointer to IRQ packet (flip, mask, priority), Y = Service routine address, U = Static storage address
- **Exit:** None

**Description:** Installs or removes a handler in the system IRQ polling table. If X=0, the handler is removed.

- **Implementation References:**
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/modules/ioman.asm`
  - `level2/modules/ioman.asm`


#### F$VIRQ (Function $27)

**Intent:** Install/Delete Virtual IRQ

**Status:** Implemented

- **Entry:** D = Number of clock ticks between polls, X = Routine address, Y = Data area address
- **Exit:** None

**Description:** Installs or removes a virtual interrupt handler that is called periodically by the system clock. If X=0, the handler is removed.

- **Implementation References:**
  - `3rdparty/drivers/disto/cc3disk_disto.asm`
  - `3rdparty/packages/cpm/defs/os9.d`
  - `defs/os9.d`
  - `level1/mc09/modules/mc09clock.asm`
  - `level1/modules/clock.asm`


#### F$ALARM (Function $1E)

**Intent:** Color Computer 3 Alarm Call ($1E)

**Status:** Implemented

- **Entry:** D = PID and Signal (0=erase), X = Pointer to 5-byte time packet
- **Exit:** None

**Description:** Schedules a signal to be sent to a process at a specific system time.

- **Implementation References:**
  - `defs/os9.d`


#### F$TIMALM (Function $26)

**Intent:** CoCo individual process alarm call

**Status:** Implemented

- **Entry:** D = PID and Signal code, X = Address of 5-byte time packet
- **Exit:** None

**Description:** Schedules a signal to be sent to a process at a specific system time. Similar to F$Alarm but usually handled by the clock module.

- **Implementation References:**
  - `defs/os9.d`


#### F$REBOOT (Function $54)

**Intent:** Reboot machine (reload OS9Boot) or drop to RSDOS

**Status:** Implemented

- **Entry:** None
- **Exit:** Does not return

**Description:** Triggers a hardware reboot of the system, typically by jumping to the system reset vector.

- **Implementation References:**
  - `defs/os9.d`


#### F$REGDMP (Function $70)

**Intent:** Ron Lammardo's debugging register dump

**Status:** Implemented

- **Entry:** None
- **Exit:** None

**Description:** Dumps the current CPU registers to the system console for debugging purposes.

- **Implementation References:**
  - `defs/os9.d`


#### F$TPS (Function $25)

**Intent:** Return System's Ticks Per Second

**Status:** Implemented

- **Entry:** None
- **Exit:** D = Number of system clock ticks per second

**Description:** Returns the configured technical frequency of the system clock.

- **Implementation References:**
  - `defs/os9.d`


#### F$XTIME (Function $56)

**Intent:** Get Extended time packet from RTC (fractions of second)

**Status:** Implemented

- **Entry:** X = Pointer to buffer
- **Exit:** Buffer filled with extended time data

**Description:** Retrieves the current technical system time including fractional seconds.

- **Implementation References:**
  - `defs/os9.d`


#### F$GPROCP (Function $37)

**Intent:** Get Process pointer

**Status:** Implemented

- **Entry:** A = Process ID
- **Exit:** Y = Pointer to process descriptor

**Description:** Retrieves the memory address (pointer) of the process descriptor for the specified PID. This is a privileged call.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/fgprocp.asm`


#### F$LDABX (Function $49)

**Intent:** Load A from 0,X in task B

**Status:** Implemented

- **Entry:** B = Task number, X = Data pointer
- **Exit:** A = Data byte at 0,x in task's address space

**Description:** Loads a single byte from the specified task's address space. It temporarily maps the required memory block from task B into the system's address space to perform the read.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/fldabx.asm`


#### F$LDAXY (Function $46)

**Intent:** Load A [X,[Y]]

**Status:** Implemented

- **Entry:** X = Block offset, Y = DAT image pointer
- **Exit:** A = Data byte at X offset of Y

**Description:** Loads a byte from a location specified by a DAT image and an offset within a block. This allows the system to read from memory that is not currently mapped into the process's address space.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/fld.asm`


#### F$LDAXYP (Function $47)

**Intent:** Load A [X+,[Y]]

**Status:** Implemented

- **Entry:** X = Offset within block, Y = DAT image pointer
- **Exit:** A = Data byte, X = Updated offset (incremented)

**Description:** Loads a byte from an address specified by a DAT image and offset, then increments the offset.

- **Implementation References:**
  - `defs/os9.d`


#### F$LDDDXY (Function $48)

**Intent:** Load D [D+X,[Y]]

**Status:** Implemented

- **Entry:** D = Offset to offset, X = Base offset, Y = DAT image pointer
- **Exit:** D = 16-bit word value

**Description:** Loads a 16-bit word from a location calculated using a double-indirect DAT image mapping.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/fld.asm`


#### F$STABX (Function $4A)

**Intent:** Store A at 0,X in task B

**Status:** Implemented

- **Entry:** A = Data byte to store in task's address space, B = Task number, X = Logical address in task's address space
- **Exit:** None

**Description:** Stores a single byte into the specified task's address space. Similar to `F$LDABX`, it temporarily maps the target memory block into the system space to perform the write.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/fldabx.asm`


#### F$VBLOCK (Function $57)

**Intent:** Verify modules in a block of memory, add to module directory

**Status:** Implemented

- **Entry:** D = Size of block, X = Start address
- **Exit:** None (Carry flag set on error)

**Description:** Verifies the technical integrity of a memory block (e.g. by checking module signatures).

- **Implementation References:**
  - `defs/os9.d`
  - `level1/modules/kernel/fsrqmem.asm`
  - `level2/modules/kernel/ccbfsrqmem.asm`


#### F$BOOT (Function $35)

**Intent:** Bootstrap System

**Status:** Implemented

- **Entry:** None
- **Exit:** None

**Description:** Instructs the kernel to load and initialize the technical system bootfile.

- **Implementation References:**
  - `defs/os9.d`
  - `level1/modules/kernel/fsrqmem.asm`
  - `level2/modules/kernel/ccbfsrqmem.asm`


## Other System Calls

#### F$ALHRAM (Function $53)

**Intent:** Allocate HIGH RAM Blocks

**Status:** Implemented

- **Entry:** B = Desired block count
- **Exit:** D = Beginning RAM block number

**Description:** Allocates physical RAM blocks from the top of system memory downwards.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/fallram.asm`


#### F$CPYMEM (Function $1B)

**Intent:** Copy External Memory ($1B)

**Status:** Implemented

- **Entry:** D = Starting block number, X = Offset in block, Y = Byte count, U = Destination buffer pointer
- **Exit:** None

**Description:** Copies data from a specific physical memory block into a process's address space.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/fcpymem.asm`


#### F$GCMDIR (Function $52)

**Intent:** Pack module directory

**Status:** Implemented

- **Entry:** X = Address of allocation bitmap, D = Number of first bit to set, Y = Bit count (number of bits to set)
- **Exit:** None

**Description:** Compacts the system module directory by removing empty entries. This is typically used to optimize memory usage and directory search times.

- **Implementation References:**
  - `defs/os9.d`
  - `level2/modules/kernel/fgcmdir.asm`


#### F$NVRAM (Function $71)

**Intent:** Non-Volatile RAM access

**Status:** Hardware dependent (typically not in base kernel)

- **Entry:** A = Mode (0=read, 1=write), B = NVRAM address, X = Data byte (if write)
- **Exit:** A = Data byte (if read)

**Description:** Provides access to non-volatile memory, such as battery-backed RAM on a Real-Time Clock chip. Implementation is hardware-specific and is often provided by a separate module or custom kernel extension rather than the base NitrOS-9 kernel.

- **Implementation References:**
  - `defs/os9.d`


