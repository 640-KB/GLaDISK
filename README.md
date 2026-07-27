# GLaDISK

## (Gizmo Linkage and Dynamic Information Storage Keeper) 
A high density floppy disk PC Option ROM for XT, AT, 286, 386+ systems, supporting many vintage and modern floppy disk controllers.

## Version 0.4 (pre-release):
- [Download preview builds here](https://github.com/640-KB/GLaDISK/releases)

## Features
- Drive types are software configurable using AT standard CMOS, [RTC 8088](https://github.com/spark2k06/RTC8088) or MM58167-based RTC boards
- 2.88 MB (Perpendicular Mode) floppy drives (validated on hardware)
- Implements advanced features of later FDC chipsets such as 16-byte FIFO/burst mode, DSR reset, EIS (implied seek), Enhanced Perpendicular Mode (500K and 1M), CONFIGURE disable polling, LOCK configuration where supported
- Supports four floppy drives (with compatible adapter). Can be used to add support for four floppy drives to 286/386+ PCs that have only two drive BIOS support
- Replaces slow (somtimes buggy) BIOS ROMs on old XT high density controllers (LSI, DTK, etc), or add 1.44/2.88 support to older AT or 386 systems lacking BIOS support
- Adds BIOS support for [720K drives on XT system](https://minuszerodegrees.net/5150_5160/720k/5150_5160_formatting_a_720K_diskette.htm) having standard 360K-only adapters
- Highly customizable features at build time
- FAST and small ROM size (4K or less)

## Requirements
- PC, PC/XT, PC/AT, 286, 386 or above
- A high-density compatible controller (see below)
- A ROM socket or software image with 4K available space in option ROM memory space

## Hardware supported and tested

GLaDISK should work with nearly all HD controllers. These controllers have been fully tested and validated:

#### i82077+ or NSC PC8477B
- [ISA FDC](https://github.com/skiselev/isa-fdc) Floppy Disk/Serial Controller (PC8477B or 82077AA)
- [Quad-Flop](https://texelec.com/product/quad-flop-four-port-isa-floppy-controller/) Four Port Floppy Disk Controller (PC8477B or 82077AA)
- [NuXT v2.0](https://monotech.fwscart.com/product/nuxt-v2-0---microatx-turbo-xt---10mhz-832k-xt-ide-multi-io-svga) integrated FDC (PC8477B)
- [Adaptec AHA-154xCF](https://theretroweb.com/expansioncards/s/adaptec-aha-1542cf) (82077SL)

#### DP8473/UM8398
- [DTK PII-151B](https://theretroweb.com/expansioncards/s/dtk-mini-micro-fdc-pii-151b) (DP8473) **
- [MT883](https://www.vogons.org/viewtopic.php?t=66239) (DP8473/UM8398) **
- [LONGSHINE LCS-6812F](https://theretroweb.com/expansioncards/s/longshine-microsystem-inc-lcs-6812f), / [LSI LCS6610F-U (U3)](https://theretroweb.com/expansioncards/s/longshine-microsystem-inc-lcs-6610f) **
- SNB-C018 or Generic DP8473 (4 drives supported) **
  
#### ACC 3201
- [SOTA FLOPPY I/O Plus](https://theretroweb.com/expansioncards/s/sota-technology-inc-floppy-i-o-plus) (ACC 3201) **
- [ACC 3201-based](https://theretroweb.com/expansioncards?itemsPerPage=24&chipIds%5B0%5D=5147) / UNIQUE-FDC (4 drives supported) **

#### 765, 8272A or Other
- [Adaptec ACB-2372](https://theretroweb.com/expansioncards/s/adaptec-acb-2372) (82072)
- [WD1002/A-FOX](https://theretroweb.com/expansioncards/s/western-digital-wd1002a-fox) (WD37C65)
- [PE-510B/C/D](https://theretroweb.com/expansioncards/s/personal-computer-communication-inc-pe-510) (765) 
- [Jameco JE1043 (D,E)](http://www.minuszerodegrees.net/manuals.htm#Jameco) / [LSI LCS6610F Rev B](https://www.minuszerodegrees.net/rom/photo/longshine_lcs6610f_rev_b_card.jpg) (765) **
- [CompuAdd 810](https://archive.org/details/compu-add-810-installation-operations/CompuAdd_810_Installation%26Operations/) (8272A) **
- [5170 "Combo" Diskette Adapter](https://theretroweb.com/expansioncards/s/ibm-fixed-disk-floppy-diskette) (765)
- Most [ISA "Multi-I/O"](https://theretroweb.com/expansioncards/s/ace-c-mega-d) floppy drive interface adapters or high density floppy controllers
- Standard PC 765/8272A (fixed data rate, 360K/720K DD only)

 ** supports on-board drive type settings hardware DIP/jumpers

## Setup and configuration of drives

XT's do not have standard battery backed up system configuration ([CMOS](https://en.wikipedia.org/wiki/Nonvolatile_BIOS_memory)) like AT's and later, so the BIOS must be told which types of disk drives are installed in other ways.  There are three ways to configure the types of drives installed: CMOS, DIP switch/jumpers and ROM.

1. NVRAM/CMOS: This way the drive settings are set by software and kept in battery backed-up memory. This is used by all AT/286, 386+ PCs using the standard BIOS CMOS setup as well as NuXT and XT/PCs that have RTCs based on DS12x85, MC146818 or BQ3285S chips (such as the [RTC 8088](https://github.com/spark2k06/RTC8088)). Additionally, XT realtime clock boards based on the MM58167, including Intel SixPakPlus and many others are also supported. Drive types can be configued by using [GLaSETUP](https://github.com/640-KB/GLaDISK/releases/download/v0.4.8-pre/GLASETUP_0.0.5.COM) for all supported CMOS/NVRAM.
2. Some 8-bit high density controllers such as DTK PII-151, LSI and others have DIP switches or jumpers to configure installed drive types. Use the corresponding ROM image for that controller's DIP switch support.
3. If all else fails, the drive types can be set by editing the ROM with a hex editor. GLaDISK uses the byte at file offset `0005` to define the disk drive types using the following table:

| Drive A: | Drive B: |  File offset `0005`-`06` |
|------------ |------------ |:------:| 
| 3&frac12;" 1.44M | 5&frac14;" 1.2M  | `42 BE` |
| 3&frac12;" 1.44M | None | `40 C0` |
| 5&frac14;" 1.2M | 3&frac12;" 1.44M | `24 DC` |
| 5&frac14;" 1.2M | None | `20 E0` |
| 3&frac12;" 2.88M | 5&frac14;" 1.2M | `52 AE` |
| 3&frac12;" 2.88M | 3&frac12;" 1.44M | `54 AC` |
| 3&frac12;" 720K | 5&frac14;" 360K | `31 CF` |

For other combinations use the method described below:

> [!WARNING]
> __TL;DR Explanation__

GLaDISK uses two bytes to define the drive types: a byte containing the types for drive 0 and 1, followed by a checksum byte. This way it is not necessary to recompute the ROM's file checksum when editing since these two bytes will always sum to the same value.

- The high nibble of hex byte offset `0005` is for drive 0 (A:) and the low nibble is drive 1 (B:). For example: a 3&frac12;" 1.44M for A: and a 5&frac14;" 1.2M for B: would be `42`.
- If GLaDISK is configured to support four high density drives, offsets `0007`-`08` are used for drives 2 and 3.
- In file offset `0006`, enter the negative of the drive types' hex value entered at offset `0005`. Example: `-42h = BEh` or `100h - 42h = BEh`.

For example, a 3&frac12;" 1.44M for A: and a 5&frac14;" 1.2M for B:
```
          00 01 02 03 04 05 06 07 08 ...
  Drives:                AB -AB
00000000: 55 AA 08 EB 5D 42 BE 0A 47 ...
```

#### Standard CMOS drive types

| Drive Type | Value |
|------------ |:------:| 
| Not installed | `0` |
| 5&frac14;" 360K DD | `1` |
| 5&frac14;" 1.2M HD | `2` |
| 3&frac12;" 720K DD | `3` |
| 3&frac12;" 1.44M HD | `4` |
| 3&frac12;" 2.88M HD | `5` |

Note: The persistent storage of drive types using NVRAM, hardware switches or ROM is referred to in GLaDISK as "[CMOS](https://en.wikipedia.org/wiki/Nonvolatile_BIOS_memory)" on POST screen display and inline documentation.

## How to Build:

Configure desired build options in `GLASETUP.INC`

#### Using MASM:

MASM 5: `MAKE GLADISK.MAK`.  

The included `OPT2ROM.COM` (DOS) will convert the produced EXE file to a 4 KiB ROM file.

#### Using JWasm / Open Watcom:

Build and install [JWasm 2.20 or newer](https://github.com/Baron-von-Riedesel/JWasm) and [Open Watcom `wlink` and `wmake`](https://github.com/open-watcom/open-watcom-v2).

`wmake -f GLADISK.WMK`

The included `wbin2rom.py` (Python) will convert `wlink` raw binary output to a 4 KiB ROM file.

## TODO

- [ ] BUG: NS and AT CMOS detection conflict when both enabled
- [ ] Display useful error if no drives installed/configured instead of silently not loading
- [ ] Set BDA number of drives based on CMOS and ignore MB switches or vice-versa?
- [ ] `MULTI_MOTOR`: Leave motors on when switching between drives to eliminate spin up time
- [ ] Four drive support using CMOS/NVRAM for AT, NS
- [ ] Double recal based on FDC detection

82072/82077:
  - [ ] PMODE on standard command, sent on drive change on SPECIFY
  - [ ] CONFIGURE on reset for FDCs that don't support LOCK

Implied seek (EIS):
  - [ ] Disable for double-stepping 360/1.2 disks
  - [ ] Use only if support detected
  - [ ] Implement NSC/MODE type (DP8473)
  - [ ] Correct Head settle timers on NSC FDCs

### Roadmap / Future features, additional research needed
- Tweak-able GAP3 for higher capacity formatting (similar to NFORMAT)
- Multiple controllers
- PS/2 compatibility
- 8" floppy support (FM)
- [Twaddle](https://wiki.osdev.org/Floppy_Disk_Controller#DIR_register,_Disk_Change_bit) (fact or fiction?). Drive/controller combinations where this works?

Copyright &copy; 2023-2025, [640KB](mailto:640kb@glabios.org) and contributors.

