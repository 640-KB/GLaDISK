
;============================================================================;
;
;	   		   * * *   S E G M E N T S   * * * 
;
;============================================================================;

;----------------------------------------------------------------------------;
; 0000:0000 - 8086 INT vector table
;----------------------------------------------------------------------------;
_IVT		SEGMENT AT 0H
		ORG	8H * 4
IVT_08 		DW	?			; INT 08H - Timer
IVT_08_SEG		DW	?			; INT 08H - Timer Segment
IVT_09 		DW	?			; INT 09H - Keyboard
IVT_09_SEG		DW	?			; INT 09H - Keyboard Segment
		ORG	0EH * 4
IVT_0E		DW	?			; INT 0EH - Floppy disk IRQ
		ORG	10H * 4
IVT_10		DW	?			; INT 10H - BIOS video services
IVT_10_SEG		DW	?			; INT 10H - Segment
		ORG	13H * 4
IVT_13H	LABEL DWORD
IVT_13H_OFF		DW	?			; INT 13H - BIOS disk services
IVT_13H_SEG		DW	?			; INT 13H - Segment
		ORG	18H * 4
IVT_18		DW	?			; INT 18H - ROM BASIC
IVT_18_SEG		DW	?			; INT 18H - Segment
		ORG	1DH * 4
IVT_1D		DD	?			; INT 1DH - CRTC param table
IVT_1E		DD	?			; INT 1EH - Floppy param table
IVT_1F		DD	?			; INT 1FH - User Font bitmap table
		ORG	40H * 4
IVT_40H	LABEL DWORD
IVT_40H_OFF		DW	?			; INT 40H - BIOS disk vectored
IVT_40H_SEG		DW	?			; INT 40H - Segment
		ORG	0C0H * 4
IVT_C0H	LABEL DWORD				; INT C0H - alternate disk revector
_IVT 		ENDS

;----------------------------------------------------------------------------;
; 0000:0400 - BIOS data area (BDA) - Zero Page Segment Addressing
;----------------------------------------------------------------------------;
_BDA_SEG	=	KP < 40H >			; BDA Seg 40H
_BDA_ABS	SEGMENT AT 0H
		ORG	12H + _BDA_SEG
GB_FLAGS_ABS2	GFLAGS <> 			; 12H  Custom Equipment Flags
		ORG	1AH + _BDA_SEG
KB_BUF_HD_ABS	DW	?			; 40:1AH Keyboard buffer head ptr
		ORG	3EH + _BDA_SEG
FD_CAL_ST_ABS	FDC_SF <>			; 40:3EH Floppy drive recalibration
		ORG	40H + _BDA_SEG
FD_MOTOR_CT_ABS	DB	?			; 40:40H FD motor shutoff counter
		ORG	6BH + _BDA_SEG
INT_LAST_ABS	DB	?			; 40:6BH POST / Interrupt happened?
		ORG	72H + _BDA_SEG
WARM_FLAG_ABS	DW	?			; 40:72H Warm Boot Flag
		ORG	80H + _BDA_SEG
KB_BUF_ST_ABS	DW	?			; 40:80H Keyboard buffer start ptr

;----------------------------------------------------------------------------;
; 8BH, 8FH-95H: FD HD config/state bytes (drive 0-1)
;
		ORG	08BH + _BDA_SEG
FD_LR_ABS		FDC_RATE <>			; 8BH  Last diskette data rate selected
		ORG	08FH + _BDA_SEG
FD_MODE_ABS		FDC_MODE <>			; 8FH  FDC Drive Mode (see FDC_MODE)
FD_MEDIA_ST_ABS	FDC_STATE 2 DUP(<>)	; 90H-91H  Drive 0-1 media state
FD_CMOS_TYPE_ABS	FD_CMOS_TYPES <>		; 92H CMOS types Drive 0-1 (drive 0=high nibble, 1=low)
FDC_ST_ABS		FDC_SPEC_ST <>		; 93H  FDC Last Specify/mode byte state
FD_TRACK_ABS	DB	2 DUP(?)		; 94H-95H  Drive 0-1 current track

;----------------------------------------------------------------------------;
; CBH-CFH: GLaDISK extended FDC 1 config/state bytes (drives 0-3)
;
		ORG	0CBH + _BDA_SEG
			DB	?			; reserved
FD_CHG_TYPE_ABS	FD_CHG_TYPE_R <>		; CCH  FD disk change type (2 bits/disk) Drive 0-3 (TODO)
FDC_VER_ABS		DB	?			; CDH  FDC PARTID version byte (0 if not supported)
CMOS_DATA_ABS	RTC_DAT <>			; CEH-CFH  GLaDISK CMOS/RTC address and type

;----------------------------------------------------------------------------;
; D0H-D5H: GLaDISK extended FD config/state bytes (drive 2-3)
;
		ORG	0D0H + _BDA_SEG
FD2_MEDIA_ST_ABS	FDC_STATE 2 DUP(<>)	; D0H-D1H  Disk 2-3 media state
FD2_CMOS_TYPE_ABS	FD_CMOS_TYPES <>		; D2H  CMOS types (drive 0=high nibble, 1=low) Drive 2-3
FD2_MODE_ABS	FDC_MODE <>			; D3H  Drive 2-3 capabilities/state
FD2_TRACK_ABS	DB	2 DUP(?)		; D4H-D5H  Drive 2-3 current track (same as FD_TRACK)

;----------------------------------------------------------------------------;
; GLaBIOS extended BDA E8H-EEH
;
		ORG	0EDH + _BDA_SEG
GB_FLAGS_ABS	GFLAGS <> 			; EDH  GLaCustom Equipment Flags (ALT)
_BDA_ABS	ENDS

;----------------------------------------------------------------------------;
; 0040:0000 - BIOS data area (BDA)
;----------------------------------------------------------------------------;
; https://stanislavs.org/helppc/bios_data_area.html
; http://www.bioscentral.com/misc/bda.htm
;----------------------------------------------------------------------------;
_BDA		SEGMENT AT 40H
COM_ADDR		DW	4 DUP(?) 		; 00H  COM1-4 base addresses
LPT_ADDR_B		EQU	$-_BDA		;	 Low byte hack to force short sign-extend encoding
LPT_ADDR		DW	3 DUP(?) 		; 08H  LPT1-3 base addresses
			DW	? 			; 0EH  Extended BIOS data area segment
EQUIP_FLAGS		EQFLAGS <> 			; 10H  Equipment Flags
GB_FLAGS2		GFLAGS <> 			; 12H  Custom Equipment Flags
MEM_SZ_KB		DW	?			; 13H  Memory size in kilobytes
MEM_SZ_PC		DW	?			; 15H  Memory size SW2 on 5150
KB_FLAGS		LABEL WORD
KB_FLAGS1		KBFLAGS1 <>			; 17H  Keyboard flags 1
KB_FLAGS2		KBFLAGS2 <>			; 18H  Keyboard flags 2
KB_ALT 		DB	?			; 19H  Alt-keypad entry byte
KB_BUF_HD		DW	?			; 1AH  Keyboard buffer head ptr
KB_BUF_TL		DW	?			; 1CH  Keyboard buffer tail ptr
KB_BUF		DW	16 DUP(?) 		; 1EH  Keyboard buffer
KB_BUF_END		LABEL WORD			; 3EH  End of keyboard buffer (not inclusive)
KB_BUF_END_B	EQU	FD_MEDIA_ST		;	 Low byte to force short sign-extend encoding
FD_CAL_ST		FDC_SF <>			; 3EH  Floppy drive recalibration status
							;	0 = drive not calibrated
							;	high bit = working interrupt flag
FD_MOTOR_ST		FDC_MF <>			; 3FH  FD motor status
							;	high bit = write operation
FD_MOTOR_CT		DB	?			; 40H  FD motor shutoff counter (decr. by INT 8)
FD_LAST_OP		DB	?			; 41H  BIOS Status of last FD operation
FDC_LAST_ST		FDC_CSB <>			; 42H  FDC command status last result (7 bytes)
VID_MODE		DB	?			; 49H  Current video mode
VID_COLS		DW	?			; 4AH  Number of screen columns
VID_BUF_SZ		DW	?			; 4CH  Size of video regen buffer in bytes
VID_SEG		DW	? 			; 4EH  Starting address in video regen buffer (offset) 
VID_CURS_POS	DW	8 DUP(?)		; 50H-5FH Cursor position of pages 1-8, high=row, low=col
VID_CURS_TYPE	DW	? 			; 60H  Starting (Top), Ending (bottom) scan line for cursor
VID_PAGE		DB	? 			; 62H  Active display page number
VID_PORT		DW	?			; 63H  Base port address for active 6845 CRT controller
VID_MODE_REG	DB	?			; 65H  6845 CRT mode control register value (port 3x8H)
VID_COLOR		DB	? 			; 66H  CGA current color palette setting (port 3D9H)
L_VID_BDA		EQU	$-VID_MODE		;      Length in bytes of video data in BDA
CAS_TIME_CNT	LABEL WORD			; 67H  5150 Cassette: Counter
ROM_INIT_SS		DW	?			; 67H   or Temp location for SS:SP during block move
CAS_CRC		LABEL	WORD			; 69H  5150 Cassette: CRC
ROM_INIT_SP 	DW	? 			; 69H	  or Option ROM init
CAS_PREV		LABEL	BYTE			; 6BH  5150 Cassette: Previous byte
;FE2010_CONF_REG	LABEL BYTE			; 6BH  FE2010A Config Reg (Standard 63H)
INT_LAST		DB	? 			; 6BH  Reserved for POST / Interrupt happened?
TIMER			TIMER_C <>			; 6CH-70H Timer Counter
BIOS_BREAK		DB	?			; 71H  BIOS break flag (high bit means ctrl-break)
WARM_FLAG		DW	?			; 72H  Warm Boot Flag (1234H to bypass RAM test)
HD_LAST_ST		DB 	? 			; 74H  Status of last hard disk operation (see INT 13,1)
HD_COUNT		DB 	? 			; 75H  Number of hard disks attached
HD_CTRL		DB 	? 			; 76H  XT fixed disk drive control byte
HD_PORT		DB 	? 			; 77H  Port offset to current fixed disk adapter
LPT_TIME_B		EQU	$-_BDA		;	 Low byte hack to force short sign-extend encoding
LPT_TIME		DB	4 DUP(?) 		; 78H  Time-out value for LPT1-4 (in # of 64K LOOPs)
COM_TIME_B		EQU	$-_BDA		;	 Low byte hack to force short sign-extend encoding
COM_TIME		DB	4 DUP(?) 		; 7CH  Time-out value for COM1-4
KB_BUF_ST		DW	?			; 80H  Keyboard buffer start
			DW	?			; 82H  Keyboard buffer end

;----------------------------------------------------------------------------;
; 8BH, 8FH-95H: FD HD config/state bytes (drive 0-1) 
;
		ORG	08BH
FDC_CAP	LABEL	BYTE				; alias for FDC capabilities byte
FD_LR			FDC_RATE <>			; 8BH  Last data rate selected and
							;	 FDC capabilities/state
		ORG	08FH
FD_MODE		FDC_MODE <>			; 8FH  Drive 0-1 capabilities/state
FD_MEDIA_ST		FDC_STATE 2 DUP(<>)	; 90H-91H  Disk 0-1 media state
FD_CMOS_TYPE	FD_CMOS_TYPES <>		; 92H  CMOS types (drive 0=high nibble, 1=low) Drive 0-1
FDC_ST		FDC_SPEC_ST <>		; 93H  FDC Last Specify/mode byte state
FD_TRACK		DB	2 DUP(?)		; 94H-95H  Drive 0-1 current track

;----------------------------------------------------------------------------;
; CBH-CFH: GLaDISK extended FDC 1 config/state bytes (drives 0-3)
;
		ORG	0CBH
			DB	?			; CBH  reserved
FD_CHG_TYPE		FD_CHG_TYPE_R <>		; CCH  FD disk change type (2 bits/disk) Drive 0-3
FDC_VER		DB	?			; CDH  FDC PARTID version byte (0 if not supported)
CMOS_DATA		RTC_DAT <>			; CEH-CFH  GLaDISK CMOS/RTC address and type
							; (unused since this is not persisted)

;----------------------------------------------------------------------------;
; D0H-D5H: GLaDISK extended FD config/state bytes (drive 2-3)
;
		ORG	0D0H
FD2_MEDIA_ST	FDC_STATE 2 DUP(<>)	; D0H-D1H  Disk 2-3 media state
FD2_CMOS_TYPE	FD_CMOS_TYPES <>		; D2H  CMOS types (drive 0=high nibble, 1=low) Drive 2-3
FD2_MODE		FDC_MODE <>			; D3H  Drive 2-3 capabilities/state
FD2_TRACK		DB	2 DUP(?)		; D4H-D5H  Drive 2-3 current track (same as FD_TRACK)
							; Must be FD2_MEDIA_ST+4H - same as FD_TRACK-FD_MEDIA_ST

;----------------------------------------------------------------------------;
; GLaBIOS extended BDA E8H-EEH
;
		ORG	0E8H				; E8H-EFH "Reserved" (can be used?)
VID_MEM_SEG_DW	LABEL DWORD			; E8H-EAH Video mem segment using LDS/LES
CURSOR_DEFAULT	DW	?			; E8H  Power on cursor bottom:top scan line (for Turbo)
VID_MEM_SEG		DW	?			; EAH	 Video mem segment (MDA = B000, CGA = B800)
FE2010_CONF_REG	DB	?			; ECH  FE2010A Config Reg (63H) (alternate)
;			DB	?			; EDH
GB_FLAGS		GFLAGS <> 			; EDH  GLaCustom Equipment Flags (ALT)
RTC_DATA		RTC_DAT <>			; EEH-EFH  GLaTICK address and RTC type

_BDA		ENDS

;----------------------------------------------------------------------------;
; F000:E000 - System BIOS ROM segment map
;----------------------------------------------------------------------------;
; Intel EFI Compatibility spec for Fixed BIOS Entry Points:
; https://www.intel.com/content/dam/doc/reference-guide/efi-compatibility-support-module-specification-v097.pdf
;----------------------------------------------------------------------------;
_BIOS		SEGMENT AT 0F000H
		ORG	0C000H
_BIOS_16K	LABEL WORD				; start of 16K BIOS
		ORG	0E000H
_BIOS_TOP	LABEL WORD				; start of 8K BIOS
		ORG	0E05BH
_BOOT		LABEL WORD				; BIOS boot offset
		ORG	0EC59H
_INT_13	LABEL	FAR				; compat ORG for INT 13H
		ORG	0EF57H
_INT_0E	LABEL	FAR
		ORG	0FFF0H
_POWER_ON	LABEL WORD				; CPU power-on jump address
_BIOS		ENDS

;----------------------------------------------------------------------------;
; FFFF:0000: 8086 power-on reset vector
;----------------------------------------------------------------------------;
; The x86 CPU begins code excution at hard-coded address FFFF:0000.
; This is that address. Welcome to the party!
;----------------------------------------------------------------------------;
RESET    	SEGMENT AT 0FFFFH
__POWER_ON	LABEL	FAR				; FFFF:0000
		ORG	0EH
_ARCH_ID	DB	?				; FFFF:000E	machine type byte
RESET		ENDS