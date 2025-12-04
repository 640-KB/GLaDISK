;----------------------------------------------------------------------------;
; GLaDISK (Gizmo Linkage and Dynamic Information Storage Keeper)
;
; It's floppy but good.
;
; Copyright (c) 2022-2025, 640KB and contributors
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; FDC Related equates
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; FDC (NEC PD765x) Controller 
;
FDC_C0		EQU	03F0H			; base address for first controller
FDC_C1		EQU	0370H			; base address for second controller
FDC_B			EQU	FDC_C0		; use first controller base address

; Standard Floppy Disk Controller Ports
FDC_A_STAT		EQU	FDC_B+0		; 03F0H R: Diskette controller status A
FDC_B_STAT		EQU	FDC_B+1		; 03F1H R: Diskette controller status B
FDC_CTRL		EQU	FDC_B+2		; 03F2H W: FD controller control port (DOR)
FDC_STAT		EQU	FDC_B+4		; 03F4H R: FD controller status register (MSR)
;FDC_MSR		EQU	FDC_B+4		; 03F4H R: FD controller status register (MSR)
FDC_DSR		EQU	FDC_B+4		; 03F4H W: DSR and DCR Reset
FDC_DATA		EQU	FDC_B+5		; 03F5H W: Data FIFO register (write 1-9 byte 
FDC_DATA2		EQU	FDC_DATA+1		;  command, see INT 13)
FDC_IN		EQU	FDC_B+7		; 03F7H R: HD FDC digital input (DIR)
FDC_CONF		EQU	FDC_IN		; 03F7H W: HD FDC control (CCR called DSR in AT)
FDC_CCR		EQU	FDC_IN		; 03F7H W: HD FDC control (CCR)

; FDC Commands
FDC_CMD_RTRK	EQU	00000010B		; 02H: Read Track (Diagnostic)
FDC_CMD_SPEC 	EQU	00000011B		; 03H: Specify Step & Head Load
FDC_CMD_STAT 	EQU	00000100B		; 04H: Sense Drive Status
FDC_CMD_WR		EQU	00000101B		; 05H: Write Sector
FDC_CMD_RD		EQU	00000110B		; 06H: Read Sector
FDC_CMD_RECAL	EQU	00000111B		; 07H: Recalibrate
FDC_CMD_SENSE	EQU	00001000B		; 08H: Sense Interrupt Status
FDC_CMD_WDEL	EQU	00001001B		; 09H: Write Deleted Sector
FDC_CMD_RSID	EQU	00001010B		; 0AH: Read Sector ID
FDC_CMD_RDEL	EQU	00001100B		; 0CH: Read Deleted Sector
FDC_CMD_FMT		EQU	00001101B		; 0DH: Format Track
FDC_CMD_SEEK	EQU	00001111B		; 0FH: Seek
FDC_CMD_RMID	EQU	01001010B		; 4AH: Read Media ID

; FDC Commands 82077A+
FDC_CMD_DUMPREG	EQU	00001110B		; 0EH: Dump registers
FDC_CMD_VER		EQU	00010000B		; 10H: Version (80H=765, 90H=82077, 73H=PC8477)
FDC_CMD_PMODE	EQU	00010010B		; 12H: Set Perpendicular Mode
FDC_CMD_CONFIG	EQU	00010011B		; 13H: Configure (82077A+)
FDC_CMD_LOCK	EQU	10010100B		; 94H: Lock Configuration
FDC_CMD_UNLOCK	EQU	00010100B		; 14H: Unlock Configuration
FDC_CMD_NSC		EQU	00011000B		; 18H: NSC/PART ID Extended Version Command
FDC_CMD_MODE	EQU	00000001B		; 01H: NDC MODE Command

; BDA INT 13H Status Flags 
; https://stanislavs.org/helppc/int_13-1.html
FDC_ST_OK		EQU	00H			; No error
FDC_ST_BADCMD	EQU	01H			; Bad command passed to driver
FDC_ST_ERR_MARK	EQU	02H			; Address mark not found or bad sector
FDC_ST_ERR_WP	EQU	03H			; Write Protect Error
FDC_ST_ERR_SEC	EQU	04H			; Sector not found
FDC_ST_DISK_CHG	EQU	06H			; diskette changed or removed
FDC_ST_DISK_NOCHG	EQU	00H			; diskette not changed or removed
FDC_ST_DMA_OVR	EQU	08H			; DMA overrun
FDC_ST_DMA_64K	EQU 	09H			; DMA access across 64k boundary
FDC_ST_ERR_MED	EQU	0CH			; Invalid media type
FDC_ST_ERR_CRC	EQU	10H			; ECC/CRC error on disk read
FDC_ST_ERR_FDC	EQU	20H			; Controller error
FDC_ST_ERR_SEEK	EQU	40H			; Seek failure
FDC_ST_TIMEOUT	EQU	80H 			; Time out, drive not ready
FDC_ST_SENSE	EQU	0FFH 			; Sense operation failed

;----------------------------------------------------------------------------;
; INT 1E Disk Initialization Parameter Table Vector
;
; https://stanislavs.org/helppc/dbt.html
;----------------------------------------------------------------------------;
HUT			EQU	15			; 15ms standard HUT
FHLT			EQU	1			; standard Head Load Time
FHLT_EIS		EQU	2			; EIS Head Load/Settle Time
FSRT			EQU	16-(6*250/500)	; 0DH: 360k   SRT 6ms
							; 360 in 1.2  SRT 5ms
							; 1.2m/1.44m  SRT 3ms
FHDST			EQU	15			; standard Head Settle Time (ms)

;----------------------------------------------------------------------------;
; SPECIFY Command Byte 0
;----------------------------------------------------------------------------;
; 84218421
; 7654    |			- SSRT	SRT: Step rate interval/time
;     3210|			- SHUT	HUT/MFT: Head unload time/Motor Off Time
;----------------------------------------------------------------------------;
FDC_SB0	RECORD	SSRT:4=FSRT, SHUT:4=HUT

;----------------------------------------------------------------------------;
; SPECIFY Command Byte 1
;----------------------------------------------------------------------------;
; 84218421
; 7654321 |			- SHLT	HLT/MNT: Head Load Time/Motor On Time
;        0|			- SNDMA	ND: Non-DMA (1=no DMA, 0=DMA)
;----------------------------------------------------------------------------;
; When using implied seeks the minimum head settling time can be enforced
; by the head load time (HLT) parameter designated in the SPECIFY command.
; For example a HLT value of 8 will yield an effective head settling time
; of 16 ms for a programmed data rate of 500 Kbps. Of course if the head
; is already positioned over the correct cylinder the head settling time
; does not need to be enforced. A HLT value of 0 is treated as 128.
; HLT: The time interval that FDC waits after loading the head and before
; initiating a read or write operation.
; The HLT (Head Load Time) defines the time between the Head Load signal
; goes high and the read write operation starts.
;----------------------------------------------------------------------------;
			IF FDC_EIS EQ 1
FDC_SB1	RECORD	SHLT:7=FHLT_EIS, SNDMA:1=0
			ELSE
FDC_SB1	RECORD	SHLT:7=FHLT, SNDMA:1=0
			ENDIF

;----------------------------------------------------------------------------;
; Fast/Slow step rate for disk types
;
			IF FAST_STEP_RATE EQ 1
SRT_360	EQU	FDC_SB0 < 16 - ( 4 * 250/500 ) >	; EFH - 360k  SRT 4ms
SRT_144	EQU	FDC_SB0 < 16 - ( 3 * 500/500 ) >	; DFH - 1.44m SRT 3ms
;SRT_144	EQU	FDC_SB0 < 16 - ( 2 * 500/500 ) >	; EFH - 1.44m SRT 2ms (alt)
SRT_288	EQU	FDC_SB0 < 16 - ( 3 * 1000/500 ) >	; AFH - 2.88m SRT 3ms
			ELSE
SRT_360	EQU	FDC_SB0 <>					; DFH - 360k  SRT 6ms
;SRT_144	EQU	FDC_SB0 < 16 - ( 5 * 500/500 ) >	; BFH - 1.44m SRT 5ms (alt)
SRT_144	EQU	FDC_SB0 < 16 - ( 6 * 500/500 ) >	; AFH - 1.44m SRT 6ms
;SRT_288	EQU	FDC_SB0 < 16 - ( 3 * 1000/500 ) >	; AFH - 2.88m SRT 3ms (alt)
SRT_288	EQU	FDC_SB0 < 16 - ( 6 * 1000/500 ) >	; 4FH - 2.88m SRT 6ms
			ENDIF
SRT_STD	EQU	FDC_SB0 <>					; DFH - 360k  SRT 6ms

;----------------------------------------------------------------------------;
; Disk Base Table
;----------------------------------------------------------------------------;
DBT STRUC
SRT		DB	FDC_SB0 <>	; 00 step-rate time SRT (6ms), head unload time HUT/MFT
HLT_ND	DB	FDC_SB1 <>	; 01 head load time HLT/MNT, DMA mode ND (0)
FMCT		DB	37 	; 02 timer ticks to wait before disk motor shutoff
FBPS		DB	2 	; 03 bytes per sector (0=128, 1=256, 2=512, 3=1024)
SPT		DB	9 	; 04 sectors per track (last sector number)
SGAP		DB	42 	; 05 inter-block gap length/gap between sectors (mills)
LSEC		DB	0FFH 	; 06 data length, if sector length not specified
FGAP		DB	80 	; 07 gap length between sectors for format (mills)
FFILL		DB	0F6H 	; 08 fill byte for formatted sectors
HDST		DB	FHDST	; 09 head settle time in milliseconds
FMST		DB	8 	; 0A motor startup time in eighths of a second
			IF FDC_HD_ENABLE EQ 1
TRKS		DB	39		; 0B last track
RATE 		DB	FSR500	; 0C data transfer rate (high) / FC_MODE (low)
			ENDIF
DBT ENDS

;----------------------------------------------------------------------------;
; STRUC for FD_TBL (MASM 5 does not support nested STRUCs)
;----------------------------------------------------------------------------;
FD_TBL_S STRUC
FDT_MS	DB	?		; FD Media State
FDT_SC	DW	?		; sectors/cylinders
FDT_DBT	DB	(SIZE DBT) DUP (?)	; DBT STRUC
FD_TBL_S ENDS

;----------------------------------------------------------------------------;
; 40:42H-49H	FDC_LAST_ST	FDC Command Status Bytes
;----------------------------------------------------------------------------;
FDC_CSB STRUC
SB0		DB	?		; 00 - status register 0
SB1		DB	?		; 01 - status register 1
SB2		DB	?		; 02 - status register 2
CYL		DB	?		; 03 - cylinder number
HEAD		DB	?		; 04 - head number
SEC		DB	?		; 05 - sector number
BPS		DB	?		; 06 - bytes per sector
FDC_CSB ENDS

;----------------------------------------------------------------------------;
; 40:3E	FD_CAL_ST	Drive recalibration status flags
;----------------------------------------------------------------------------;
; 84218421
; 7 	    |			- FWIF	1=working interrupt flag
;  654    |			- FSTBD	unused
;     3   |			- FCAL3	1=recalibrate drive 3
;      2  |			- FCAL2	1=recalibrate drive 2
;       1 |			- FCAL1	1=recalibrate drive 1
;        0|			- FCAL0	1=recalibrate drive 0
;----------------------------------------------------------------------------;
FDC_SF RECORD	FWIF:1,FSTBD:3,FCAL3:1,FCAL2:1,FCAL1:1,FCAL0:1
FDC_RECAL_MASK	EQU	LOW (NOT(MASK FCAL3 OR MASK FCAL2 OR MASK FCAL1 OR MASK FCAL0))

;----------------------------------------------------------------------------;
; 40:3F	FD_MOTOR_ST	Diskette motor status flags
;----------------------------------------------------------------------------;
; 84218421
; 7 	    |			- FWRT	1=write operation
;  654    |			- FMTBD	unused
;     3210|			- FMOT	1=drive 3 motor on
;----------------------------------------------------------------------------;
FDC_MF RECORD	FWRT:1,FMTBD:3,FMOT:4

;----------------------------------------------------------------------------;
; 40:3F	FD_MOTOR_ST	Diskette motor status flags - separated drives
;----------------------------------------------------------------------------;
; 84218421
; 7654    |			- FMOTX	unused
;     3   |			- FMOT3	1=drive 3 on
;      2  |			- FMOT2	1=drive 2 on
;       1 |			- FMOT1	1=drive 1 on
;        0|			- FMOT0	1=drive 0 on
;----------------------------------------------------------------------------;
FDC_MFD RECORD	FMOTX:4,FMOT3:1,FMOT2:1,FMOT1:1,FMOT0:1

;----------------------------------------------------------------------------;
; FDC Digital Output Register (DOR/DCR) at 3F2h (WRITE)
;----------------------------------------------------------------------------;
; 84218421
; 7 	    |			- FDMD	1 = turn floppy drive D motor on
;  6      |			- FDMC	1 = turn floppy drive C motor on
;   5     |			- FDMB	1 = turn floppy drive B motor on
;    4    |			- FDMA	1 = turn floppy drive A motor on
;     3   |			- FDDMA	1 = DMA & I/O interface enabled
;      2  |			- FDCEN	1 = FDC enable, 0 = hold FDC at reset
;       10|			- FDDRV	floppy drive select (0=A, 1=B, 2=C, 3=D)
;----------------------------------------------------------------------------;
FDC_DOR RECORD	FDMD:1,FDMC:1,FDMB:1,FDMA:1,FDDMA:1,FDCEN:1,FDSEL:2

;----------------------------------------------------------------------------;
; FDC Main Status Register (MSR) at 3F4h (READ)
;----------------------------------------------------------------------------;
; 84218421
; 7 	    |			- FDRR	RQM:  data reg ready for I/O to/from CPU
;  6      |			- FIOD	DIO:  I/O direction; 1=FDC to CPU; 0=CPU to FDC
;   5     |			- FDND	NDMA: FDC is in non-DMA mode
;    4    |			- FDRW	BSY:  F DC read or write command in progress
;     3   |			- F3SK	floppy drive 3 in seek mode/busy
;      2  |			- F2SK	floppy drive 2 in seek mode/busy
;       1 |			- F1SK	floppy drive 1 in seek mode/busy
;        0|			- F0SK	floppy drive 0 in seek mode/busy
;----------------------------------------------------------------------------;
FDC_MSR RECORD	FDRR:1,FIOD:1,FDND:1,FDRW:1,F3SK:1,F2SK:1,F1SK:1,F0SK:1

;----------------------------------------------------------------------------;
; FDC Command Status Register 0 at 3F5h
;----------------------------------------------------------------------------;
; 84218421
; 76	    |			- ST0CS	last command status (see below)
;   5     |			- ST0SK	set to 1 when FDD completes a seek command
;    4    |			- ST0CHK	equipment check (see note)
;     3   |			- ST0NR	not ready on read/write or SS access to head 1
;      2  |			- ST0HD	head number at interrupt (head 0 or 1)
;       10|			- ST0DRV	unit selected at interrupt (0=A, 1=B, 2=...)
;----------------------------------------------------------------------------;
; Bits
;	 76  Last Command Status
;	 00  command terminated successfully
;	 01  command execution started but terminated abnormally
;	 10  invalid command issued
;	 11  command terminated abnormally due to a change in state of
;	     the Ready Signal from the FDC  (reserved on PS/2)
;
;	- equipment check can occur if FDD signals a fault or track zero is
;	  not found after 77 steps on a recalibrate command
;----------------------------------------------------------------------------;
FDC_ST0 RECORD	ST0CS:2,ST0SK:1,ST0CHK:1,ST0NR:1,ST0HD:1,ST0DRV:2

;----------------------------------------------------------------------------;
; FDC Command Byte 0
;----------------------------------------------------------------------------;
; 84218421
; 7       |			- FC0MT	MT = Multi-Track
;  6      |			- FC0MF	MF = MFM mode
;   5     |			- FC0SK	SK = SKip Deleted-data address mark
;    43210|			- FC0CMD	FDC command number
;----------------------------------------------------------------------------;
FDC_CB RECORD	FC0MT:1,FC0MF:1=1,FC0SK:1,FC0CMD:5

;----------------------------------------------------------------------------;
; FDC R/W/V Command Byte 1
;----------------------------------------------------------------------------;
; 84218421
; 76543   |			- FC1X	unused
;      2  |			- FC1HD	head (0-1)
;       10|			- FC1DS	drive (0-3)
;----------------------------------------------------------------------------;
FDC_CB1 RECORD	FC1X:5,FC1HD:1,FC1DS:2

;----------------------------------------------------------------------------;
;
; BEGIN HD Floppy Related
;
;----------------------------------------------------------------------------;


;----------------------------------------------------------------------------;
; BDA/FDC Drive Rates
;----------------------------------------------------------------------------;
DR_500		EQU	0000B			; 0 = 500 Kb/s
DR_300		EQU	0001B			; 1 = 300 Kb/s
DR_250		EQU	0010B			; 2 = 250 Kb/s
DR_1K			EQU	0011B			; 3 = 1000 Kb/s

;----------------------------------------------------------------------------;
; 40:8B	FDC_RATE (FD_LR)	Last diskette data rate selected (Standard)
;----------------------------------------------------------------------------;
; 84218421
; 76 	    |			- FLR		last floppy data rate selected (DR_*)
;   54    |			- FLS		last floppy drive step rate selected
; 	32  |			- FLRS	last floppy data rate started
;       1 |			- FLSB	last drive specify bytes sent (0-1)
;						  TODO: extend for 4 drives
;        0|			- FLHD	adapter supports HD
;----------------------------------------------------------------------------;
;	Data Rate 			Step Rate
;	00  500K bps		00  step rate time of 0C (or 8ms?)
;	01  300K bps		01  step rate time of 0D (or 7ms?)
;	10  250K bps		10  step rate time of 0A (or 6ms?)
;	11  1000K bps		11  reserved (or 5ms?)
;----------------------------------------------------------------------------;
;FDC_RATE RECORD	FLR:2,FLS:2,FLRS:2,FLSB:1,FLHD:1
;FDC_RATE RECORD	FLR:2,FLRS:2,FLSV:1,FLSD:2,FLHD:1

;----------------------------------------------------------------------------;
; 40:8B	FDC_RATE	Last diskette data rate (Alternate)
;----------------------------------------------------------------------------;
; 84218421
; 76 	    |			- FLRA	last floppy data rate sent
;   54    |			- FLX1	unused
; 	32  |			- FSRA	last floppy data rate started
;       1 |			- FLX2	last drive specify bytes sent (0-1)
;        0|			- FRHD	adapter supports HD
;----------------------------------------------------------------------------;
;FDC_RATE2 RECORD	FLRA:2,FLX1:2,FSRA:2,FLX2:1,FRHD:1

;----------------------------------------------------------------------------;
; 40:8B	FDC_RATE (FD_LR) ALT 2	Disk data rate / controller capability
; Obsolete GLaDISK
; one per FDC (4 drives)
;----------------------------------------------------------------------------;
; 84218421
; 76 	    |			- FLR		last floppy data rate sent (DR_*)
;   5     |			- FLHD3	adapter is NSC PC8477/PC87306
;    4    |			- FLHD2	adapter is Intel 82077+
;     3   |			- FLSV	last drive specify sent is still valid
; 	 21 |			- FLSD	last floppy drive specify sent (0-3)
;        0|			- FLHD	adapter supports HD (AT/WD37C65/basic MIO)
;----------------------------------------------------------------------------;
; HD FDC feature support (detected at runtime)
; FLHD (82072/7*65B):
;	- Set Data rate (250, 300, 500)
;	- Change line (DIR)
; FLHD2 (82077+):	All above plus:
;	- DSR/SWR soft reset
;	- CONFIGURE
;	- DUMPREG
;	- FIFO 16 byte
;	- Implied SEEK (EIS) via CONFIGURE
;	- LOCK (*not supported on 82077-1)
;	- Perpendicular mode
;	- Set data rate (1000)
; FLHD3 (NSC DP8473*/PC8477):
;	- MODE
;	- NSC EIS (per command bit)
;	- LOCK (*not supported on DP8473)
;	- Burst Mode (*not supported on DP8473)
;
; TODO: split into separate specify/sent byte to make space for additional
; config bits such as NSC DP8473, etc.
;----------------------------------------------------------------------------;
;FDC_RATE RECORD	FLR:2,FLHD3:1,FLHD2:1,FLSV:1,FLSD:2,FLHD:1

;----------------------------------------------------------------------------;
; 40:8B	FDC_RATE (FD_LR)	GLaDISK Current Disk data rate / FDC capability
; per FDC (4 drives)
;----------------------------------------------------------------------------;
; 84218421
; 76 	    |			- FLR		last floppy data rate selected (DR_*)
;   5     |			- FLRX1	reserved
;    4    |			- FNSC	adapter supports NSC cmds (DP8473/PC8477)
; 	3   |			- FHD4	adapter 82077AA, 82077SL+, PC8477+
; 	 2  |			- FHD3	adapter is 82077, 82077-1 or above
;       1 |			- FHD2	adapter is Intel 82072+ or above
;        0|			- FHD		adapter supports HD (AT/WD37C65/basic MIO)
;----------------------------------------------------------------------------;
; HD FDC feature support:
; FHD  (82072/7*65B):
;	- Set Data rate (250, 300, 500)
;	- Change line (DIR)
;	- Double recal required (only 77 pulses)
; FHD2 (82072+, some generic MIO adapters, 82077?):
;	- DSR/SWR soft reset
;	- CONFIGURE
;	- DUMPREG
;	- FIFO 16 byte
;	- Implied SEEK (EIS) via CONFIGURE
;	- Set data rate 1MB (doesn't necessarily support pmode/2.88)
;	- Double recal not required
; FDH3 (82077, 82077-1)
;	- Perpendicular mode
;	- VERSION
;	- Double recal not required
; FHD4 (82077AA, 82077SL+, PC8477+):
;	- Enhanced PMODE command
;	- LOCK
;	- Double recal not required (mostly)
; FNSC (NSC DP8473/PC8477):
;	- NSC MODE
;	- Implied SEEK by NSC EIS (per command bit)
;	- "Burst Mode" (whatever that is)
;	- Double recal required for DP8473
;----------------------------------------------------------------------------;
FDC_RATE RECORD	FLR:2,FLRX1:1,FNSC:1,FHD4:1,FHD3:1,FHD2:1,FHD:1

;----------------------------------------------------------------------------;
; FDC feature tests
;
FDC_FT_DR			EQU	MASK FHD			; Can set data rate (250,300,500)
FDC_FT_DIR			EQU	MASK FHD			; Can detect change line

FDC_FT_DSR_RST		EQU	MASK FHD2			; DSR/SWR reset
FDC_FT_CONF			EQU	MASK FHD2			; CONFIGURE
FDC_FT_FIFO			EQU	MASK FHD2			; FIFO
FDC_FT_EIS			EQU	MASK FHD2			; Implied SEEK (EIS) via CONFIGURE
FDC_FT_DUMPREG		EQU	MASK FHD2			; DUMPREG

FDC_FT_PMODE		EQU	MASK FHD3 			; Standard PERPENDICULAR command
FDC_FT_VER			EQU	MASK FHD3 			; VERSION
FDC_FT_DR_1K		EQU	MASK FHD3			; Data rate 1000

FDC_FT_EPMODE		EQU	MASK FHD4 			; Enhanced PERPENDICULAR command
FDC_FT_LOCK			EQU	MASK FHD4 			; LOCK

FDC_FT_MODE			EQU	MASK FNSC 			; MODE
FDC_FT_NSC_EIS		EQU	MASK FNSC			; NSC EIS via command bit
FDC_FT_BURST		EQU	MASK FNSC			; Burst Mode (NSC term for 16-byte FIFO)

HD_TYPE_MASK		EQU	MASK FNSC OR MASK FHD4 OR MASK FHD3 OR MASK FHD2 OR MASK FHD
HD_TYPE_0			EQU	FDC_RATE <,,0,0,0,0,0>	; 765/non-HD 	00H
HD_TYPE_1			EQU	FDC_RATE <,,0,0,0,0,1>	; 82072/765 	01H
HD_TYPE_2			EQU	FDC_RATE <,,0,0,0,1,1>	; Intel 82072+ 	03H
HD_TYPE_3			EQU	FDC_RATE <,,0,0,1,1,1>	; Intel 82077 	07H
HD_TYPE_4			EQU	FDC_RATE <,,0,1,1,1,1>	; Intel 82077AA+ 	0FH
HD_TYPE_NSC1		EQU	FDC_RATE <,,1,0,0,0,1>	; NSC DP8473	11H
HD_TYPE_NSC2		EQU	FDC_RATE <,,1,1,1,1,1>	; NSC PC8477+	1FH

;----------------------------------------------------------------------------;
; Defines for FDC_TYPE config option (too late to define these here)
;
;FDC_TYPE_DD		EQU	HD_TYPE_0			; 765/non-HD 	00H
;FDC_TYPE_HD1		EQU	HD_TYPE_1			; 82072/765 	01H
;FDC_TYPE_HD2		EQU	HD_TYPE_2			; Intel 82072+ 	03H
;FDC_TYPE_HD3		EQU	HD_TYPE_3			; Intel 82077 	07H
;FDC_TYPE_HD4		EQU	HD_TYPE_4			; Intel 82077AA+ 	0FH
;FDC_TYPE_NSC1		EQU	HD_TYPE_NSC1		; NSC DP8473 	0FH
;FDC_TYPE_NSC2		EQU	HD_TYPE_NSC2		; NSC PC8477+ 	0FH

;----------------------------------------------------------------------------;
; 40:8F	FD_MODE 	Floppy drive mode/capabilities (drives 0-1)
; Alt - supports perpendicular mode
;----------------------------------------------------------------------------;
; 84218421
; 7 	    |			- FM1C	1=drive 1 supports change line
;  6      |			- FM1P	1=drive 1 supports perpendicular mode
;   5     |			- FM1M	1=drive 1 supports multiple data rates
;    4    |			- FM18	1=drive 1 supports 80-track, 0=360k drive
;     3   |			- FM0C	1=drive 0 supports change line
;      2  |			- FM0P	1=drive 0 supports perpendicular mode
;       1 |			- FM0M	1=drive 0 supports multiple data rates
;        0|			- FM08	1=drive 0 supports 80-track, 0=360k drive
;----------------------------------------------------------------------------;
FDC_MODE RECORD	FM1C:1,FM1P:1,FM1M:1,FM18:1,FM0C:1,FM0P:1,FM0M:1,FM08:1

; TODO: if single-clock ("hacked") HD FDC, define no chg, no DRR for all drives

FDM_NONE	EQU	FDC_MODE <>
FDM_360	EQU	FDC_MODE <,,,,0,0,0,0>	; no chg, no pmode, no DRR, 40 track
FDM_720	EQU	FDC_MODE <,,,,0,0,0,1>	; no chg, no pmode, no DRR, 80 track

FDM_12	EQU	FDC_MODE <,,,,1,0,1,1>	; chg, no pmode, DRR, 80 track
FDM_14	EQU	FDC_MODE <,,,,1,0,1,1>	; chg, no pmode, DRR, 80 track
FDM_28	EQU	FDC_MODE <,,,,1,1,1,1>	; chg, pmode, DRR, 80 track

;----------------------------------------------------------------------------;
; 40:90H-91H	Floppy drive media state (drives 0-3)
;----------------------------------------------------------------------------;
; 84218421
; 76      |			- FSR		data xfr rate in Kb/s (0=500,1=300,2=250)
;   5     |			- FDDS	1=dub step required
;    4    |			- FSE		1=media established
;     3   |			- FSPM	1=perpendicular mode required
;      210|			- FSD		(see below)
;----------------------------------------------------------------------------;
; FSD values:
;	0 = 360K disk/360K drive not established
;	1 = 360K disk/1.2M drive not established
;	2 = 1.2M disk/1.2M drive not established
;	3 = 360K disk/360K drive established
;	4 = 360K disk/1.2M drive established
;	5 = 1.2M disk/1.2M drive established
;	6 = reserved
;	7 = none of the above
;----------------------------------------------------------------------------;
FDC_STATE RECORD	FSR:2,FDUB:1,FSE:1,FSPM:1,FSD:3
;FDC_STATE RECORD	FSR:2=DR_250,FDUB:1,FSE:1,FSX:1,FSD:3

;----------------------------------------------------------------------------;
; Floppy State Disk (FDC_STATE FSD) type values:
;
FD360			EQU	0 	; 000 = 360K disk/360K drive not established
FD360_12		EQU	1	; 001 = 360K disk/1.2M drive not established
FD12			EQU	2	; 010 = 1.2M disk/1.2M drive not established
FD360E		EQU	3	; 011 = 360K disk/360K drive established
FD360_12E		EQU	4	; 100 = 360K disk/1.2M drive established
FD12E			EQU	5	; 101 = 1.2M disk/1.2M drive established
;FDRES		EQU	6	; 110 = reserved
FD720			EQU	7	; 111 = 720K/1.44M/2.88M disk
FD144			EQU	FD720
FD288			EQU	FD720

;----------------------------------------------------------------------------;
; Media States - Data Rate only
;
FSR250	EQU	FDC_STATE <DR_250>	; 80h = 250 Kb/s
FSR300	EQU	FDC_STATE <DR_300>	; 40h = 300 Kb/s
FSR500	EQU	FDC_STATE <DR_500>	; 00h = 500 Kb/s
FSR1000	EQU	FDC_STATE <DR_1K>		; C0h = 1000 Kb/s

;----------------------------------------------------------------------------;
; Media States
;
FMS360_12	EQU	FDC_STATE <DR_300,1,0,,FD360_12>	; (61H) 360/1.2 not est
FMS720	EQU	FDC_STATE <DR_250, ,0,,FD720>		; (87H) 720 est
FMS12		EQU	FDC_STATE <DR_500, ,0,,FD12>		; (02H) 1.2 not est
FMS144	EQU	FDC_STATE <DR_500, ,0,,FD144>		; (07H) 1.44 not est
FMS288	EQU	FDC_STATE <DR_1K,  ,0,1,FD288>	; (C7H) 2.88 not est/PMODE

FMS360E	EQU	FDC_STATE <DR_250, ,1,,FD360E>	; (93H) 360/360 est
FMS360_12E	EQU	FDC_STATE <DR_300,1,1,,FD360_12E>	; (74H) 360/1.2 est
FMS720E	EQU	FDC_STATE <DR_250, ,1,,FD720>		; (97H) 720 est
FMS12E	EQU	FDC_STATE <DR_500, ,1,,FD12E>		; (15H) 1.2/1.2 est
FMS144E	EQU	FDC_STATE <DR_500, ,1,,FD144>		; (17H) 1.44 est
FMS288E	EQU	FDC_STATE <DR_1K,  ,1,1,FD288>	; (D7H) 2.88 est/PMODE

;----------------------------------------------------------------------------;
; 40:92H	FD CMOS types (FD_CMOS_TYPE)
;----------------------------------------------------------------------------;
; 84218421
; 7	    |			- FDS0	unused (parity bit for NS)
;  654    |			- FDT0	drive 0/2 CMOS type
;     3   |			- FDS1	unused
;      210|			- FDT1	drive 1/3 CMOS type
;----------------------------------------------------------------------------;
FD_CMOS_TYPES RECORD	FDS0:1, FDT0:3, FDS1:1, FDT1:3

;----------------------------------------------------------------------------;
; 40:93H	FDC_SPEC_ST 	FDC specify/config state
; per FDC (4 drives)
;
; TODO: rename since this also holds standard PMODE config valid state?
;----------------------------------------------------------------------------;
; 84218421
; 76	    |			- FLSX1	reserved
;   5     |			- FLENV	if 1: established is invalid - must reset
;    4    |			- FLSV	last drive specify and standard PMODE config sent still valid
;     32  |			- FLSX2	reserved
; 	  10|			- FLSD	last floppy drive specify sent (0-3)
;----------------------------------------------------------------------------;
FDC_SPEC_ST	RECORD	FLSX1:2,FLENV:1,FLSV:1,FLSX2:2,FLSD:2

;----------------------------------------------------------------------------;
; 40:CCH	FD_CHG_TYPE	Change signal support
;----------------------------------------------------------------------------;
; 84218421
; 76	    |			- FDCT3	drive 03 change type (see below)
;   54    |			- FDCT2	drive 02 change type
;     32  |			- FDCT1	drive 01 change type
;       10|			- FDCT0	drive 00 change type
;
; Values:
;	 00 = not checked
;	 01 = twaddle not supported
;	 11 = twaddle supported
;----------------------------------------------------------------------------;
FD_CHG_TYPE_R RECORD	FDCT3:2, FDCT2:2, FDCT1:2, FDCT0:2


;----------------------------------------------------------------------------;
;
; HD FDC I/O REGISTERS
;
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; FDC PS/2 Status Register A (READ) at 3F0H
;----------------------------------------------------------------------------;
; 84218421
; 7	    |			- F2AINT	INT pending
;  6	    |			- F2AD2	_DRV2
;   5	    |			- F2ST	STEP
;    4    |			- F2T0	_TRK0
;     3   |			- F2HS	HDSEL
;      2  |			- F2IDX	_INDX
;       1 |			- F2WP	_WP
;        0|			- F2DIR	data rate (DR_360, DR_720, etc)
;----------------------------------------------------------------------------;
FDC_SRA2 RECORD	F2AINT:1,F2AD2:1,F2ST:1,F2T0:1,F2HS:1,F2IDX:1,F2WP:1,F2DIR:1

;----------------------------------------------------------------------------;
; FDC PS/2 Status Register B (READ) at 3F1H
;----------------------------------------------------------------------------;
; 84218421
; 76	    |			- FB2X	unused (always 1)
;   5	    |			- FB2DS0	DS0
;    4    |			- FB2WR	WRDATA Toggle
;     3   |			- FB2RD	RDDATA Toggle
;      2  |			- FB2WE	WE
;       1 |			- FB2M1	MOT EN1
;        0|			- FB2M0	MOT EN0
;----------------------------------------------------------------------------;
FDC_SRB2 RECORD	FB2X:2,FB2DS0:1,FB2WR:1,FB2RD:1,FB2WE:1,FB2M1:1,FB2M0:1

;----------------------------------------------------------------------------;
; FDC Model 30 Status Register A (READ) at 3F0H
;----------------------------------------------------------------------------;
; 84218421
; 7	    |			- F3AINT	INT pending
;  6	    |			- F3DRQ	DRQ
;   5	    |			- F3ST	STEP
;    4    |			- F3T0	TRK0
;     3   |			- F3HS	_HDSEL
;      2  |			- F3IDX	INDX
;       1 |			- F3WP	_WP
;        0|			- F3DIR	_data rate (DR_360, DR_720, etc)
;----------------------------------------------------------------------------;
FDC_SRA3 RECORD	F3AINT:1,F3AD2:1,F3ST:1,F3T0:1,F3HS:1,F3IDX:1,F3WP:1,F3DIR:1

;----------------------------------------------------------------------------;
; FDC Model 30 Status Register B (READ) at 3F1H
;----------------------------------------------------------------------------;
; 84218421
; 7	    |			- FB3D2	_DRV2
;  6	    |			- FB3DS1	_DS1
;   5	    |			- FB3DS0	_DS0
;    4    |			- FB3WR	WRDATA F/F
;     3   |			- FB3RD	RDDATA F/F
;      2  |			- FB3WE	WE F/F
;       1 |			- FB3DS3	_DS3
;        0|			- FB3DS4	_DS4
;----------------------------------------------------------------------------;
FDC_SRB3 RECORD	FB3D2:1,FB3DS1:1,FB3DS0:1,FB3WR:1,FB3RD:1,FB3WE:1,FB3DS3:1,FB3DS4:1

;----------------------------------------------------------------------------;
; FDC Data Rate Select Register (WRITE) (DSR) at 3F5H
;----------------------------------------------------------------------------;
; 84218421
; 7	    |			- FCHG	diskette change (?)
;  65432  |			- FDIX	reserved
;       10|			- FDIR	data rate (DR_360, DR_720, etc)
;----------------------------------------------------------------------------;
FDC_DI RECORD	FCHG:1,FDIX:5,FDDR:2

;----------------------------------------------------------------------------;
; FDC Digital Input Register (READ) at 3F7H (765/8272/AT)
;----------------------------------------------------------------------------;
; 84218421
; 7	    |			- FDCHG	diskette change
;  6 	    |			- FDRWG	write gate
;   5432  |			- FDRHS	head select/(reduced write current bit 5)
;       10|			- FDRDS	drive select
;----------------------------------------------------------------------------;
FDC_DI_R RECORD	FDCHG:1,FDRWG:1,FDRHS:4,FDRDS:2

;----------------------------------------------------------------------------;
; FDC Digital Input Register (READ) at 3F7H (WD37C65C)
;----------------------------------------------------------------------------;
; 84218421
; 7	    |			- FWDX1	unused (diskette change external)
;  6 	    |			- FWDWP	write gate
;   5	    |			- FWDRY	ready (always 1)
;    4    |			- FWDT0	track 0 (1=track 0)
;     3   |			- FWDWP	state of WP signal from drive
;      2  |			- FWDHS	head select
;       10|			- FWDDS	drive select
;FDC_DIWD_R RECORD	FWDX1:1,FWDWP:1,FWDRY:1,FWDT0:1,FWDWP:1,FWDHS:1,FWDDS:2

;----------------------------------------------------------------------------;
; FDC Digital Input Register (READ) at 3F7H (Model 30)
;----------------------------------------------------------------------------;
; 84218421
; 7	    |			- FD3CHG	diskette change
;  654    |			- FD3X	unused (always 0)
;     3   |			- FD3DMA	DMA gate
;      2  |			- FD3PC	No precomp
;       10|			- FD3DR	data rate selected
;----------------------------------------------------------------------------;
FDC_DI30_R RECORD	FD3CHG:1,FD3X:3,FD3DMA:1,FD3PC:1,FD3DR:2

;----------------------------------------------------------------------------;
; FDC Digital Input Register (READ) (DIR) at 3F7H (82077+)
;----------------------------------------------------------------------------;
; 84218421
; 7	    |			- FDICHG	diskette change
;  6543   |			- FDIRX	unused (always 1)
;      21 |			- FDIRDR	data rate selected
;        0|			- FDIRHD	high density (0=500/1K, 1=250/300)
;----------------------------------------------------------------------------;
FDC_DIR_R RECORD	FDICHG:1,FDIRX:4,FDIRDR:2,FDIRHD:1

;----------------------------------------------------------------------------;
; FDC Data Rate Select (WRITE) (DSR) at 03F4H (82072+)
;----------------------------------------------------------------------------;
; 84218421
; 7       |			- FCRST	DSR reset
;  6      |			- FCPWR	Power Down
;   5     |			- FCPLL	Internal/external PLL (unused always 0)
;    432  |			- FCPC	Precomp amount (default 0, 111b=pmode/disable)
;       10|			- FCDR	data rate
;----------------------------------------------------------------------------;
FDC_DSR_W RECORD	FCRST:1,FCPWR:1,FCPLL:1,FCPC:3,FCDR:2

FDC_PC_PMODE	EQU	111B		; precomp disabled for pmode
FDC_PC_EN		EQU	0		; precomp enabled (default)

;----------------------------------------------------------------------------;
; FDC Configuration Control Register (WRITE) (CCR) at 3F7H (765/8272)
;----------------------------------------------------------------------------;
; 84218421
; 765432  |			- FDWX	reserved
;       10|			- FDWDR	data rate
;----------------------------------------------------------------------------;
;FDC_DI_W RECORD	FDWX:6,FDWDR:2
FDC_CCR_W RECORD	FDWX:6,FDWDR:2

;----------------------------------------------------------------------------;
; FDC CONFIGURE Command Byte 0 (Motor timer 82072 only)
; All others, this byte is always 0.
;----------------------------------------------------------------------------;
; 84218421
; 7       |			- HSDA	motor on/off delays are doubled
;  654    |			- MOFF	index pulses before the MOTOR turned off
;     3210|			- MON		Index pulses after MOTOR on before a cmd
;----------------------------------------------------------------------------;
FDC_CCB0 RECORD	HSDA:1,MOFF:3,MON:4

;----------------------------------------------------------------------------;
; FDC CONFIGURE Command Byte 1 (Byte 0 is always 0)
;----------------------------------------------------------------------------;
; 84218421
; 7       |			- FCCX	unused
;  6      |			- FCEIS	EIS: Enable Implied Seeking (1=enable)
;   5     |			- FCEFF	EFIFO: Enable FIFO (0=enable, 1=disable)
;    4    |			- FCPL	POLL: Disable polling of the drives (0)
;     3210|			- FCTH	FIFOTHR: FIFO Threshhold (default 1)
;----------------------------------------------------------------------------;
FDC_CCB RECORD	FCCX:1,FCEIS:1,FCEFF:1,FCPL:1,FCTH:4

;----------------------------------------------------------------------------;
; FDC CONFIGURE Command Byte 2 - Disk Precomp Track
;----------------------------------------------------------------------------;
; 84218421
; 76543210|			- FC2PC	PRETRK Precomp start track # (default 0)
;----------------------------------------------------------------------------;
FDC_CCB2 RECORD	FC2PC:8

;----------------------------------------------------------------------------;
; FDC LOCK Command Byte 0
;----------------------------------------------------------------------------;
; 84218421
; 7       |			- FLOCK	LOCK configuration status (1)
;  6543210|			- FLKCMD	always 14H
;----------------------------------------------------------------------------;
FDC_LOCK_CB RECORD	FLOCK:1=1,FLKCMD:7=14H

;----------------------------------------------------------------------------;
; FDC UNLOCK Command Byte 0
;----------------------------------------------------------------------------;
; 84218421
; 7       |			- FULOCK	UNLOCK configuration status (0)
;  6543210|			- FULKCMD	always 14H
;----------------------------------------------------------------------------;
FDC_UNLOCK_CB RECORD	FULOCK:1=0,FULKCMD:7=14H
;FDC_CMD_UNLOCK	EQU	FDC_LOCK_CB < 0 >	; just another way to do this

;----------------------------------------------------------------------------;
; FDC LOCK Result Byte 0
;----------------------------------------------------------------------------;
; 84218421
; 765     |			- FRLCBX1	always 0
;    4    |			- FRLOCK	LOCK configuration status (1=locked,0=not)
;     3210|			- FRLCBX2	always 0
;----------------------------------------------------------------------------;
FDC_LOCK_RB RECORD	FRLCBX1:3,FRLOCK:1=1,FRLCBX2:4

;----------------------------------------------------------------------------;
; FDC PERPENDICULAR MODE Command Byte 1 (82077)
;----------------------------------------------------------------------------;
; 84218421
; 765432  |			- FPRX1	always 0
;       1 |			- FPR_WGATE	WGATE (1=write gate perp mode)
;        0|			- FPR_GAP	GAP (1=1 Mb/s if WGATE=1, 0=500 KB/s if WGATE=0)
;----------------------------------------------------------------------------;
FDC_PERP_CB RECORD	FPRX1:6,FPR_WGATE:1,FPR_GAP:1

;----------------------------------------------------------------------------;
; FDC PERPENDICULAR MODE Command Byte 1 (NSC)
;----------------------------------------------------------------------------;
; 84218421
; 7 	    |			- FPN_OW	Overwrite (1=enable FPN_DC3-DC0)
;  6      |			- FPNX1	always 0
;   5     |			- FPN_DC3	drive 3 perp mode (1=perp, 0=standard) if FPN_OW=1
;    4    |			- FPN_DC2	drive 2 perp mode (1=perp, 0=standard)
;     3   |			- FPN_DC1	drive 1 perp mode (1=perp, 0=standard)
;      2  |			- FPN_DC0	drive 0 perp mode (1=perp, 0=standard)
;       1 |			- FPN_WGATE	WGATE perp mode enable (overrides DC0-DC3 if OW=1)
;        0|			- FPN_GAP	GAP (1=1 Mb/s if WGATE=1, 0=500 Kb/s if WGATE=0)
;----------------------------------------------------------------------------;
FDC_PERP_NSC RECORD	FPN_OW:1,FPNX1:1,FPN_DC3:1,FPN_DC2:1,FPN_DC1:1,FPN_DC0:1,FPN_WGATE:1,FPN_GAP:1

FDC_PERP_500	EQU	MASK FPR_WGATE
FDC_PERP_1K		EQU	MASK FPR_WGATE OR MASK FPR_GAP

;----------------------------------------------------------------------------;
; FDC_CMD_MODE Command Byte 1 (NSC)
;----------------------------------------------------------------------------;
; 84218421
; 7 	    |			- TMR		Motor Timer mode (0=mode 1, 1=mode 2)
;  6      |			- IAF		Index Address Format (0=PC (default), 1=ISO)
;   5     |			- IPS		Implied Seek (0=ignore in cmd, 1=use in cmd)
;    4    |			- NM1X0	always 0
;     32  |			- LOWPWR	Low power mode (0=disable, 1=auto, 2=manual)
;       1 |			- NM1X1	always 1
;        0|			- ETR		Extended Track Range (0=256 trks, 1=4096)
;----------------------------------------------------------------------------;
			IF FDC_EIS EQ 1
FDC_NM_CB1 RECORD		TMR:1,IAF:1,IPS:1=1,NM1X0:1,LOWPWR:2,NM1X1:1=1,ETR:1
			ELSE
FDC_NM_CB1 RECORD		TMR:1,IAF:1,IPS:1,NM1X0:1,LOWPWR:2,NM1X1:1=1,ETR:1
			ENDIF

;----------------------------------------------------------------------------;
; FDC_CMD_MODE Command Byte 2 (NSC)
;----------------------------------------------------------------------------;
; 84218421
; 7 	    |			- FWR		*FIFO Write Disable (0=enable, 1=disable)
;  6      |			- FRD		*FIFO Read Disable (0=enable, 1=disable)
;   5     |			- BST		*Burst Mode Disable (0=enable, 1=disable)
;    4    |			- R255	*Recalibrate Step Pulses (0=85, 1=255)
;     3210|			- NM2X0	always 0
;
; *PC8477B only, not supported on DP8473
;----------------------------------------------------------------------------;
FDC_NM_CB2 RECORD		FWR:1, FRD:1, BST:1, R255:1, NM2X0:4

;----------------------------------------------------------------------------;
; FDC_CMD_MODE Command Byte 3 (NSC)
;----------------------------------------------------------------------------;
; 84218421
; 76 	    |			- DENSEL	**Density Select (0=low, 1=high, *3=default)
;   5     |			- BFR		**Disk Interface Buffer (*0=4mA PP, 1=48mA DR)
;    4    |			- WLD		Scan Wild Card (*0=allow FF, 1=ignore FF)
;     3210|			- NHS		Head Settle for EIS - vary by data rate:
;						ms = 250:N*8, 300:N*6.67, 500:N*4, 1K:N*2
;						default: N=8
; *default
; **PC8477B only, not supported on DP8473
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; NSC MODE Head Settle (CB3)
;
NHDST			=	FHDST / 4	; default for 500K data rate
		IF UNSAFE_FLOPPY EQ 1
NHDST			=	NHDST * UNSAFE_FLP_DIV
		ENDIF
		IF NHDST EQ 0
NHDST			=	1		; ensure at least 1
		ENDIF

FDC_NM_CB3 RECORD		DENSEL:2=11B, BFR:1=0, WLD:1=0, NHS:4=NHDST

;----------------------------------------------------------------------------;
; FDC_CMD_MODE Command Byte 4 (NSC)
;----------------------------------------------------------------------------;
; 84218421
; 76543   |			- NM4X0	always 0
;      2  |			- RG		Read Gate DSKCHG (0=normal, 1=test mode)
;       1 |			- NM4X1	always 0
;        0|			- PU		MFM pin PUMP (0=normal, 1=charge pump)
;----------------------------------------------------------------------------;
FDC_NM_CB4 RECORD		NM4X0:5, RG:1, NM4X1:1, PU:1

;----------------------------------------------------------------------------;
; END HD
;----------------------------------------------------------------------------;

