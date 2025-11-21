	PAGE	 	59,132
	TITLE		GLaDISK

;----------------------------------------------------------------------------;
; GLaDISK (Gizmo Linkage and Dynamic Information Storage Keeper)
;
; It's floppy but good.
;
; Copyright (c) 2022-2025, 640KB and contributors
;----------------------------------------------------------------------------;
;
; This program is free software: you can redistribute it and/or modify it
; under the terms of the GNU General Public License as published by the Free
; Software Foundation, either version 3 of the License, or (at your option)
; any later version.
;
; This program is distributed in the hope that it will be useful, but WITHOUT
; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
; FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
; more details.
;
; You should have received a copy of the GNU General Public License along
; with this program. If not, see <https://www.gnu.org/licenses/>.
;
;----------------------------------------------------------------------------;
VER_NAME	EQU	'GLaDISK'
VER_NUM	EQU	'0.4.8'			; pre-release
VER_DATE	EQU	'11/20/25' 			; must be MM/DD/YY format
COPY_YEAR	EQU	'2025'

;============================================================================;
;
;				* * *   T O D O   * * * 
;
;============================================================================;
;
; TODO / bugs - PRE-RELEASE: (ver 0.4.x)
;
; - NS and AT CMOS detection conflict when both enabled
; - Must display useful error if no drives installed instead of silently not loading
; - BUG: shows B drive only if count is wrong?
; - Set BDA number of drives based on CMOS and ignore MB switches?
; - display 4 drives if DD controller (validate fix)
;
; - Only perform necessary detection tests based on FDC_TYPE_*
; - Standardize banner format with GLaTICK
; - Finish GLaSETUP program
; - Remove unnecessary FDC_DEBUG calls
;
; TODO - AFTER INITIAL RELEASE: (ver 0.8.x)
; - 82072/82077:
; 	- PMODE on standard command, sent on drive change on SPECIFY
; 	- CONFIGURE on reset for FDCs that don't support LOCK
; - Double recal based on FDC detection
; - Implied seek (EIS)
;	- Use only if support detected
;	- Disable for double-stepping 360/1.2 disks
;	- Implement NSC/MODE type (DP8473)
;	- Correct Head settle timers on NSC FDCs
; - Read BDA RTC/CMOS port/config byte from GLaTICK instead of detect
; - MULTI_MOTOR: Leave motors on when switching between drives to 
;	eliminate spin up time
; - Four drive support
;	- CMOS for AT, NS (where to store drive 2-3)
;	- EPMODE
;
; Future features - Additional research needed
; - PS/2 compatibility
; - tweak-able GAP3 for higher capacity formatting
; - 8" floppy support (FM)
; - Twaddle support (fact or fiction?)
; - Slow "Starting MS-DOS..." on 1.44 on 4.77 8088
;	- fixed by faster execution (faster ROMs) and faster head settling(?)
;
;----------------------------------------------------------------------------;
; Hardware Support (tested):
;
; - PC standard 765/8272A (fixed clock, DD only)
; - WD1002-FOX (WD37C65) (DD only)
; - IBM 5170 "combo card" FDC/HDC adapter (765)
; - LSI LCS6610F-U (U3) aka Jameco JE1043 (D,E)
; - Adaptec AHA-154xCF (82077AA)
; - ISA FDC Floppy Disk/Serial Controller (PC8477B or 82077xx)
; - DTK PII-151B (DP8473)
; - LSI LCS-6812F (DP8473)
; - Generic "MT-883" board (1EFH)
; - CompuAdd 810 (765 compat)
; - ACC 3201 (4 drive)
; - PE-510B (DP8473)
;
; TODO/Testing needed:
; - Lo-Tech Quad-Flop (4 drive)
; - https://github.com/sorphin/Modified_XT-FDC_ForQuadFloppies
; - Sunix "SUN-4300" (3F0H)
; - Compacticard IV
; - "Cursed XT controller" (this is standard XT DD controller that has been
;	overclocked to 500 K/s data rate so will only support 1.2 or 1.44 media.
;
;----------------------------------------------------------------------------;
; References, Credits and Inspiration:
;
;  https://stanislavs.org/helppc/
;  https://www.minuszerodegrees.net/
;  https://www.ardent-tool.com/
;  https://www.os2museum.com/wp/the-floppy-controller-evolution/
;  https://wiki.osdev.org/Floppy_Disk_Controller
;  https://retrocmp.de/fdd/general/floppy-bus.htm
;  "System BIOS for IBM(R) PC/XT(TM)/AT(R) Computers and Compatibles",
;	Phoenix Technologies Ltd.
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; State Lifecycle - in order of least to most frequently executed
;
; ROM_INIT: Run once during boot POST test
;	- Unmask IRQ 0, 6 in IMR
;	- Check if GLaDISK already installed (FD_CMOS_TYPE_ABS non-zero)
;	- Test for AT WAIT (INT 15H, AH=86H)
;	- Read from available CMOS providers
;	- Install GLaDISK ISR in either INT 13h or INT 40h
;	- Clear FDC section of BDA
;	- Set up default drive media states for CMOS drive types
;	- Detect FDC type and set FDC_CAP flags
;		- If required/supported:
;			- set Enhanced PERPENDICULAR mode and LOCK
;			- CONFIGURE and LOCK (if needed)
;	- Reset controller and set inital data rate
;	- Display banner, FDC and drive types
; 
; FDC_RESET: Run during INT 13H, AH=0 and on Media Change
;	- Save DOR motor and drive select state
;	- Reset FDC. Use DSR reset if supported by detected FDC.
;	- If FDC does not support LOCK, send CONFIGURE (if needed)
;	- Wait for WIF from reset and SENSE 4x to clear registers
;	- If HD:
;		- reset last data rate to FDC
;		- send SPECIFY bytes to FDC
;
; FDC_SEND_SPECIFY: Run before RWV commands and detecting new media if last 
;		specify and standard PMODE bytes are not valid.
;	- Determine if last specify byte sent is still valid
;		- No: re-send SPECIFY, go to Send SPECIFY
;	- Determine if last specify byte sent is still valid for drive
;		- Yes: exit
;	- Send SPECIFY: bytes and save to BDA as valid for drive
;	- If HD and FDC only support Standard PMODE:
;		- set Standard PERPENDICULAR mode
;		- if 500K PMODE enabled, check data rate and send mode for 500K or 1M
;		- set precomp for PMODE or non-PMODE
;
; INT_13_2_5_HD_SETUP: Run before RWV commands if HD support
;	- Check if media was changed (door opened)
;		- if changed, set FD_LAST_OP = 6 and exit RWV command
;	- Check if media type is established
;		- if format command, do not detect, set specify/rate for 
;			unestablished type and exit
;	- Attempt to determine media by reading track IDs at drive-supported rates
;		- if unable to determine, reset media to default state and exit
;
;----------------------------------------------------------------------------;


;============================================================================;
;
;				* * *   C O D E   * * * 
;
;============================================================================;
INCLUDE 	GLADISK.INC

;----------------------------------------------------------------------------;
; GLADISK.ASM sets up IVT, detects FDC hardware, set up CMOS and displays 
; POST test banners.
;----------------------------------------------------------------------------;
OPTROM	SEGMENT BYTE PUBLIC 'CODE'
		ASSUME DS:OPTROM, SS:OPTROM, CS:OPTROM, ES:OPTROM

;----------------------------------------------------------------------------;
; GLaLIB EXTRN PROCs
;----------------------------------------------------------------------------;
			IF GB_UI
EXTRN		POST_START_COL_1:NEAR, POST_START_COL_2:NEAR
EXTRN		POST_END_COL:NEAR, POST_END_COL_NL:NEAR
EXTRN		OUT_SZ_ATTR:NEAR, OUT_SZ:NEAR, OUT_SZ_NL:NEAR
EXTRN		OUT_NL:NEAR, OUT_CHAR:NEAR, SPACE:NEAR
EXTRN		IS_GLABIOS:NEAR
			ENDIF
EXTRN		WORD_HEX:NEAR, BYTE_HEX:NEAR
EXTRN		WORD_HEX_TRIM_Z:NEAR, WORD_HEX_TRIM:NEAR
			IF USE_FDC_DEBUG EQ 1
EXTRN		WORD_HEX:NEAR, BYTE_HEX:NEAR
EXTRN		DWORD_HEX:NEAR
EXTRN		FDC_DEBUG:NEAR
			ENDIF
			IF CMOS_TYPE_AT EQ 1
EXTRN		READ_CMOS_AT:NEAR
			ENDIF

;----------------------------------------------------------------------------;
; INT_13 EXTRN PROCs
;----------------------------------------------------------------------------;
EXTRN		INT_13:NEAR
			IF GLADISK_INT_0EH EQ 1
EXTRN		INT_0E:NEAR
			ENDIF
			IF GLADISK_INT_1EH EQ 1
EXTRN		INT_1E:NEAR
			ENDIF

;----------------------------------------------------------------------------;
; INT_13H EXTRN PROCs
;----------------------------------------------------------------------------;
			IF FDC_HD_ENABLE EQ 1
EXTRN		FD_CMOS_DRIVE_TBL:NEAR, FDC_SET_RATE:NEAR, FD_SET_MODE_CMOS:NEAR
EXTRN		FD_RESET_STATE:NEAR, FD_SET_STATE:NEAR, FD_SET_STATE_DRV:NEAR
EXTRN		FDC_CONFIGURE_LOCK:NEAR, FDC_CONFIGURE:NEAR
EXTRN		FDC_TEST_CMD:NEAR
EXTRN		FDC_DUMPREG:NEAR
EXTRN		FDC_RESET:NEAR
EXTRN		FDC_SEND_RECV_ALL:NEAR
			ENDIF

;----------------------------------------------------------------------------;
; GLaDISK EXTRNs
;----------------------------------------------------------------------------;
PUBLIC	FD_GET_CMOS		; Get drive count according to BDA
PUBLIC	GET_DRIVE_COUNT	; Get specified drive type from "CMOS"
PUBLIC	STR_CRLF		; CRLF string

;----------------------------------------------------------------------------;
; Companion ROM Header
;----------------------------------------------------------------------------;
;ROM_SIZE	EQU	KB < 8 >			; size of ROM (8K for testing)
ROM_SIZE	EQU	KB < 4 >			; size of ROM (4K)

			ORG	0000H
ROM_HEADER	PROC FAR
	DW	MAGIC_WORD				; ROM magic number
	DB	ROM_SIZE / 512			; ROM size (512 byte blocks)
	JMP	SHORT ROM_INIT
ROM_HEADER	ENDP

			IF CMOS_TYPE_NONE EQ 1
;----------------------------------------------------------------------------;
; Define CMOS_DRV from CMOS_DRIVE_TYPES in GLADISK.INC (DO NOT EDIT HERE)
;
			ORG	0005H			; offset for CMOS types in ROM
	CMOS_ROM_TYPE	CMOS_DRV,  %CMOS_DRIVE_TYPES, FDC_MAX_DRIVES

			ENDIF

;----------------------------------------------------------------------------;
; Banner and Copyright Strings
;----------------------------------------------------------------------------;
				IF SHOW_BANNER EQ 1
VER_BANNER	DB	CR, LF
		DB	VER_NAME
					IF BANNER_VER EQ 1 AND BANNER_TAG EQ 1
		DB	' ', VER_NUM
						IF BANNER_BLD EQ 1
		DB	'-'
		DB	CPU_TYPE, ARCH_TYPE
		DB	FDC_TYPE OR '0'
		DB	FDC_MODEL
						ENDIF
						IF BANNER_DATE EQ 1
		DB	' ', VER_DATE
						ENDIF
					ENDIF
		DB	' [', HEART, '] '
					IF BANNER_TAG EQ 1
		DB	"It's floppy but good"
					ENDIF
					IF BANNER_VER EQ 1 AND BANNER_TAG NE 1
		DB 	VER_NUM
						IF BANNER_BLD EQ 1
		DB	'-'
		DB	CPU_TYPE, ARCH_TYPE
		DB	FDC_TYPE OR '0'
						ENDIF
					ENDIF
		DB	CR, LF
				ELSE
		DB	VER_NAME, ' '
				ENDIF
		DB	'(C) ', COPY_YEAR
		DB	' 640KB Released under GPLv3'
STR_CRLF	DB	CR, LF, SZ
					IF BANNER_VER EQ 0	; just embed in ROM
		DB 	VER_NUM, '-'
		DB	CPU_TYPE, ARCH_TYPE
		DB	FDC_TYPE OR '0'
		DB	' '
		DB	VER_DATE
					ENDIF

;----------------------------------------------------------------------------;
; INIT procedure called during POST
;----------------------------------------------------------------------------;
;
; ROM_INIT:
;
; 1. Check if CPU compatible with build (OPTIONAL)
; 2. Save caller registers
; 3. Unmask IRQ6 and 0 IMR, timer and FDC
; 4. Set DS/ES to IVT
; 5. Check if GLaDISK already set up (FD_CMOS_TYPE = 0)
; 7. Check BDA for disk count (exit if 0 drives)
; 8. Read supported CMOS types and save to BDA
; 9. Determine if PC is AT or XT
;	- check Machine ID byte
; 	- test if AT WAIT supported
; 10. Set up GLaDISK ISR in IVT
; 11. DS/ES to BDA and clear remaining BDA data
; 12. Set up BDA drive states, capabilities and default media
; 13. Set default data rate (OPTIONAL)
; 14. Detect FDC and capabilities, set in FD_LR
;
; POST_SCREEN: (OPTIONAL)
;
; 15. Display GLaDISK banner
; 16. Show drive letters, types and FDC type
;
; 17. Restore IMR, caller registers and FAR RET to caller
;----------------------------------------------------------------------------;
ROM_INIT	PROC
	PUSHF						; save IF flag

			IF CHECK_BUILD_CPU EQ 1
;----------------------------------------------------------------------------;
; Verify CPU is compatible with build type
;
	CALL	VERIFY_CPU				; CF if CPU not compatible
	JNC	CPU_OKAY				; jump if CPU is OK

;----------------------------------------------------------------------------;
; Display error and exit
;
	PUSH	SI
	CALL	PRINT_BANNER
	PRINTLN_SZ	ERR_CPU			; else CPU is not compatible
	POP	SI
	POPF						; restore flags and exit
	RETF

ERR_CPU	DB	'Unsupported CPU', SZ
CPU_OKAY:
			ENDIF

;----------------------------------------------------------------------------;
; Begin INIT procedure
;
			IF CPU_TYPE EQ CPU_186 OR CPU_TYPE EQ CPU_V20
	PUSHA
			ELSE
	PUSHX	AX, CX, DX, BX, BP, SI, DI 	; save caller register state
			ENDIF
	PUSHX	DS, ES

;----------------------------------------------------------------------------;
; Unmask IRQ 6 and IRQ 0 in IMR and save
;
	IN	AL, INT_IMR 			; get current OCW1/IMR register
	PUSH	AX					; save IMR
	STI						; interrupts enabled
	AND	AL, NOT (MASK IRQ6 OR MASK IRQ0) ; unmask IRQ6 (FDC) and IRQ0 (timer)
	OUT	INT_IMR, AL 			; send to A1 (Port 1)

;----------------------------------------------------------------------------;
; Setup DS/ES for IVT
;
			ASSUME DS:_BDA_ABS, ES:_IVT
	CLD
	XOR	AX, AX				; AX = 0
	MOV	DS, AX				; DS = IVT
	MOV	ES, AX

;----------------------------------------------------------------------------;
; Make sure GLaDISK hasn't already been installed
; TODO: additional check?
;----------------------------------------------------------------------------;
	CMP	AL, FD_CMOS_TYPE_ABS		; already been set up?
	JZ	SETUP_DRIVE_COUNT			; continue if not

SETUP_IVT_DONE_1:	
	JMP	SETUP_IVT_DONE			; near jump for exit

SETUP_DRIVE_COUNT:
	CALL	GET_MAX_DRIVE_COUNT		; AL = # drives installed according to BDA
	;FD_DEBUG	'MDC'
	JZ	SETUP_IVT_DONE_1			; exit if zero drives

;----------------------------------------------------------------------------;
; Read drive type configuration
;----------------------------------------------------------------------------;
; Output from SETUP_CMOS_*:
;	AX = CMOS drive types as nibbles (AH=2/3, AL=0/1)
;	BP = display string
;	CF = 1 if error, 0 if success
;----------------------------------------------------------------------------;

		IF FDC_TYPE	EQ FDC_TYPE_DD
;----------------------------------------------------------------------------;
; If HD not enabled, drives are always 360/360.
;
			IF FDC_MAX_DRIVES EQ 4
	MOV	AX, DNW < FDCM_360, FDCM_360, FDCM_360, FDCM_360 >
			ELSE
	MOV	AL, DNB < FDCM_360, FDCM_360 >
			ENDIF

		ELSE
;----------------------------------------------------------------------------;
; High density controller support is enabled in build. Set defaults.
;
	XOR	AL, AL				; default 0, in case no CMOS types
			IF SHOW_FDC EQ 1
	MOV	BP, OFFSET S_CM_NONE		; default display to 'ROM'
			ENDIF

;----------------------------------------------------------------------------;
; Arrange so detected software-set RTC takes precedence over DIP switches
;----------------------------------------------------------------------------;

			IF CMOS_TYPE_AT EQ 1
;----------------------------------------------------------------------------;
; Detect and set up AT style CMOS/NVRAM
;
EXTRN		SETUP_CMOS_AT:NEAR
	CALL	SETUP_CMOS_AT			; attempt read AT CMOS
	JNC	SETUP_IVT_OK			; jump if success

			ENDIF

			IF CMOS_TYPE_NS EQ 1
;----------------------------------------------------------------------------;
; Detect and set up NS (58167) NVRAM
;
EXTRN		SETUP_CMOS_NS:NEAR
	CALL	SETUP_CMOS_NS			; attempt read CMOS from NS RTC
	JA	SETUP_IVT_OK			; jump if success and drive byte not 00

			ENDIF

;----------------------------------------------------------------------------;
; Proprietary hardware DIP/JP based configuration types
;----------------------------------------------------------------------------;

			IF CMOS_TYPE_LSI1 EQ 1
;----------------------------------------------------------------------------;
; Set up with LSI DIP switch config
;
EXTRN		SETUP_CMOS_LSI1:NEAR
	CALL	SETUP_CMOS_LSI1			; attempt read and set switches
	JNC	SETUP_IVT_OK			; jump if success

			ENDIF

			IF CMOS_TYPE_LSI2 EQ 1
;----------------------------------------------------------------------------;
; Set up with LSI DIP switch config
;
EXTRN		SETUP_CMOS_LSI2:NEAR
SETUP_CMOS_LSI2
	CALL	SETUP_CMOS_LSI2			; attempt read and set switches
	JNC	SETUP_IVT_OK			; jump if success

			ENDIF

			IF CMOS_TYPE_DTK1 EQ 1
;----------------------------------------------------------------------------;
; Set up with DTK DIP switch config
;
EXTRN		SETUP_CMOS_DTK1:NEAR
	CALL	SETUP_CMOS_DTK1
	JNC	SETUP_IVT_OK			; jump if success

			ENDIF

			IF CMOS_TYPE_PE510 EQ 1
;----------------------------------------------------------------------------;
; Set up with PE-510 DIP switch config
;
EXTRN		SETUP_CMOS_PE510:NEAR
	CALL	SETUP_CMOS_PE510
	JNC	SETUP_IVT_OK			; jump if success (always CF)

			ENDIF

			IF CMOS_TYPE_ACC EQ 1
;----------------------------------------------------------------------------;
; Set up with DTK DIP switch config
;
EXTRN		SETUP_CMOS_ACC:NEAR
	CALL	SETUP_CMOS_ACC
	JNC	SETUP_IVT_OK			; jump if success

			ENDIF

			IF CMOS_TYPE_CA EQ 1
;----------------------------------------------------------------------------;
; Set up with C810 DIP switch config
;
EXTRN		SETUP_CMOS_CA:NEAR
	CALL	SETUP_CMOS_CA
	JMP	SETUP_IVT_OK			; all DIP switch options are valid

			ENDIF

			IF CMOS_TYPE_MT883 EQ 1
;----------------------------------------------------------------------------;
; Set up with MT883 board
;
EXTRN		SETUP_CMOS_MT:NEAR
	CALL	SETUP_CMOS_MT
	JMP	SETUP_IVT_OK			; all DIP switch options are valid

			ENDIF

			IF CMOS_TYPE_NONE EQ 1
;----------------------------------------------------------------------------;
; Fallback hard-coded types
;
	MOV	AL, CS:CMOS_DRV			; use ROM hard-coded CMOS types

			ENDIF

		ENDIF

;----------------------------------------------------------------------------;
; Drive types successfully read into AL
;
SETUP_IVT_OK:
	TEST	AL, AL				; check returned drive types
	JZ	SETUP_IVT_DONE_1			; exit if both are 0
							; TODO: display error here
			IF CMOS_VAL_TYPE EQ 1
	CALL	CMOS_VER_TYPE			; verify drives in AL are valid
			ENDIF
	MOV	FD_CMOS_TYPE_ABS, AL		; save CMOS type to BDA

			IF FDC_MAX_DRIVES GT 2
;----------------------------------------------------------------------------;
; Set up drives 2-3
; TODO: 4 drives stored in RAM (AT or NS)
;----------------------------------------------------------------------------;

			IF (FDC_MODEL EQ FDC_MODEL_LSI2) OR (FDC_MODEL EQ FDC_MODEL_ACC)
;----------------------------------------------------------------------------;
; Controllers with hardware switches for four drives
;
	MOV	AL, AH				; drives 2-3 are in AH
			ELSE
				IF CMOS_TYPE_NONE EQ 1
	MOV	AL, CS:CMOS_DRV[2]		; Set up drives 2-3 from ROM
				ELSE
	MOV	AL, DNB < FDCM_360, FDCM_360 > ; (should never happen)
				ENDIF
			ENDIF
	;FD_DEBUG 'FD2_CMOS'
			IF CMOS_VAL_TYPE EQ 1
	CALL	CMOS_VER_TYPE			; verify drives in AL are valid
			ENDIF
	MOV	FD2_CMOS_TYPE_ABS, AL		; set CMOS type in BDA

			ENDIF

;----------------------------------------------------------------------------;
; SETUP GLaDISK ISR
;----------------------------------------------------------------------------;
; Determine if GLaDISK should replace the current INT 13h or the
; current (if any) INT 40h.
;----------------------------------------------------------------------------;
	MOV	SI, OFFSET IVT_13H		; presume INT 13H
	MOV	DI, OFFSET IVT_40H		; presume INT 40H

;----------------------------------------------------------------------------;
; Determine type of PC
;----------------------------------------------------------------------------;
; Is system an AT or XT?
;
; Ways to do that:
; - Machine ID byte (not totally reliable)
; - INT 15AH, AH=86H support
; - Valid AT CMOS at 70H (set up during SETUP_CMOS_AT)
; - INT 13H, AH=16h support (might interfere with shady disk BIOSes)
;----------------------------------------------------------------------------;

			IF AT_TEST_MID EQ 1
;----------------------------------------------------------------------------;
; Check MACHINE ID byte:
; https://stanislavs.org/helppc/id_bytes.html
;
CHECK_AT_MID:
	MOV	AX, SEG RESET
			IF 1	; TODO: why use ES?
	PUSH	DS
	MOV	DS, AX				; DS = FFFF
			ASSUME DS:RESET
	MOV	AL, _ARCH_ID			; AL = FFFF:000E (F000:FFFE)
	POP	DS
			ASSUME DS:_BDA_ABS
			ELSE
	PUSH	ES
	MOV	ES, AX				; ES = FFFF
			ASSUME ES:RESET
	MOV	AL, _ARCH_ID			; AL = FFFF:000E (F000:FFFE)
	POP	ES
			ASSUME ES:_IVT
			ENDIF
	CMP	AL, 0FCH				; is AT/386?
	;FD_DEBUG 'MID'
	;JNE	CHECK_AT_WAIT			; if not FC, test AT_WAIT
	JNE	SETUP_ISR_XT			; if not FC, don't test AT_WAIT?
	SET_GFLAG_ABS	ATFC			; set ATFC flag if FC
			ENDIF

			IF AT_WAIT EQ 1
;----------------------------------------------------------------------------;
; Test INT 15H, AH=86H wait function. If available use for FDC delays.
;
CHECK_AT_WAIT:
	XOR	CX, CX
	MOV	DH, 1					; delay 100 us (or so)
	MOV	AH, 86H				; AT WAIT function
	STC						; if CF is cleared, function exists
	INT	15H					; wait CX:DX microseconds
	STI						; ensure BIOS returns with IF=1
	JC	SETUP_ISR_XT			; if failure, use XT WAIT and setup

;----------------------------------------------------------------------------;
; Might be an AT type
;
	SET_GFLAG_ABS	ATWAIT		; AT INT 15H WAIT available

;TEST_AT_WAIT_DONE:
	;TEST_GFLAG_ABS	ATWAIT		; is BIOS AT, as previously detected?
	;JZ	SETUP_ISR_XT			; if not, jump to XT routine

			ELSE
	JMP	SHORT SETUP_ISR_XT		; just do XT version
			ENDIF

;----------------------------------------------------------------------------;
; If AT:
; - Check if CMOS is working
;	- No: assume system must be configured, do not interfere with INT 13H
;		just set up as INT 40H.
;	- Yes: Go to next step
; - Check CMOS if any hard drives installed
;	- Yes: replace INT 40H
;	- No: move INT 13H to INT 40H and replace INT 13H
;
SETUP_ISR_AT:
			IF CMOS_TYPE_AT EQ 1
	;FD_DEBUG '_ISR_AT'
	TEST_GFLAG_ABS	ATCMOS		; working/valid CMOS?
	JZ	SETUP_ISR_AT_DONE			; if not, install as INT 40H
	MOV	AL, CM_HD				; 12H CMOS hard drive type
	MOV	DX, ATC_IDX				; default AT CMOS port
	CALL	READ_CMOS_AT
	;FD_DEBUG 'READ_CMOS_AT'

;----------------------------------------------------------------------------;
; SI = IVT INT 13 (004CH)
; DI = IVT INT 40 (0100H)
;
	TEST	AL, AL				; hard drive installed?
	JZ	SETUP_INT40				; if not, move current INT 13H to INT 40H and 
							;  install GLaDISK as INT 13H
SETUP_ISR_AT_DONE:
			ENDIF
	MOV	SI, DI				; SI = INT 40H (0100H)

;----------------------------------------------------------------------------;
; If XT:
; - Check if INT 13H or INT 40H (SI) is F000:EC59
;	- Yes: move INT 13H to INT 40H and replace INT 13H with GLaDISK
;	- No: replace INT 40H with GLaDISK
;
; - INT 13H is F000:EC59?
;	- Yes: No hard drive BIOS installed
;	- No: Likely hard drive BIOS installed
;
; - INT 40H is F000:EC59?
;	- Yes: System BIOS floppy drive installed and hard drive BIOS
;	- No: Another floppy BIOS OR no hard drive BIOS installed
;
SETUP_ISR_XT:
	;FD_DEBUG '_ISR_XT'
	CMP	WORD PTR [SI], OFFSET _INT_13	; is Intel EFI ORG for INT 13H?
	JNE	SETUP_FD_ISR			; if not, jump and set as INT 40H
	CMP	WORD PTR [SI][2], SEG _INT_13	; is Intel EFI SEG for INT 13H?
	JNE	SETUP_FD_ISR			; if not, jump and set as INT 40H

;----------------------------------------------------------------------------;
; Re-vector current system BIOS INT 13H to 40H, then replace INT 13H.
;
; Copy SI 0000:4C (INT 13H) to DI 0000:0100
;
SETUP_INT40:
	;FD_DEBUG '_INT40'
	PUSH	SI					; save IVT_13H for later
	MOVSW						; copy offset
	MOVSW						; copy segment
	POP	DI					; DI = OFFSET IVT_13H

;----------------------------------------------------------------------------;
; Set 0000:DI (either INT 13H or INT 40H) to GLaDISK's Floppy disk INT 13H ISR
;
SETUP_FD_ISR:
	;FD_DEBUG '_FD_ISR'
	SETUP_ISR	INT_13			; set up GLaDISK ISR INT_13 to IVT at [0000:DI]


			IF GLADISK_INT_0EH EQ 1
;----------------------------------------------------------------------------;
; Set up GLaDISK INT 0EH as FDC IRQ
;
	SETUP_ISR	INT_0E, IVT_0E
			ENDIF

			IF GLADISK_INT_1EH EQ 1
;----------------------------------------------------------------------------;
; Set up GLaDISK INT 1EH as default DBT
;
	SETUP_ISR	INT_1E, IVT_1E
			ENDIF


			IF FDC_HD_ENABLE EQ 1
;----------------------------------------------------------------------------;
; Set up BDA/FDC controller for HD
;----------------------------------------------------------------------------;
		ASSUME DS:_BDA, ES:_BDA
	MOV	AX, SEG _BDA
	MOV	DS, AX
	MOV	ES, AX

;----------------------------------------------------------------------------;
; Clear and set up BDA disk data:
;----------------------------------------------------------------------------;
	XOR	AX, AX				; AX = 0
	MOV	DI, OFFSET FD_CAL_ST		; 3EH-42H
	STOSW						; FD_CAL_ST, FD_MOTOR_ST = 0
	STOSW						; FD_MOTOR_CT, FD_LAST_OP = 0
	STOSB						; FDC_LAST_ST = 0
	MOV	DI, OFFSET FD_MODE		; 8FH, 90H-93H
	STOSB						; FD_MODE = 0 
	STOSW						; FD_MEDIA_ST = 0

			IF FDC_MAX_DRIVES GT 2
;----------------------------------------------------------------------------;
; Clear BDA for drive 2-3
; 
	MOV	DI, OFFSET FD2_MEDIA_ST
	STOSW
	INC	DI					; DI = FD2_MODE
	STOSW
	STOSW
			ENDIF

	MOV	DI, OFFSET FD_LAST_OP		; used for many INT 13H operations

			IF XT_V3_FIX EQ 1
;----------------------------------------------------------------------------;
; Some BIOSes (XTv3 1986) clobber BDA 90h-91h during POST after option ROM init
; Sets a flag that will force this data to be reset on first INT 13h call.
;
	OR	_FDC_ST, MASK FLENV		; set invalid establish state flag
			ENDIF

	MOV	_FD_LR, FDC_RATE < DR_250,,,,,0 >	; default LR

;----------------------------------------------------------------------------;
; Setup CMOS drives in BDA
; TODO: don't skip drives if not valid - use None (or something)
;----------------------------------------------------------------------------;
	;CALL	GET_DRIVE_COUNT			; AX = # of drives (1 based)
	CALL	GET_MAX_DRIVE_COUNT		; AX = # of drives (1 based)
	FD_DEBUG 'DC'
	XCHG	AX, DX				; DX = # of drives (1 based), AH = 0
SETUP_DRIVE_LOOP:
	DEC	DX					; pre-decrement since count is 1 based
	JS	SETUP_DRIVE_DONE			; done if next drive < 0

;----------------------------------------------------------------------------;
; Set drive to unestablished media based on CMOS type
;
	CALL	FD_SET_MODE_CMOS			; set up FDC_MODE for drive DL
	CALL	FD_RESET_STATE			; AL = media state byte
SETUP_DRIVE_NEXT:
	JMP	SHORT SETUP_DRIVE_LOOP

SETUP_DRIVE_DONE:

;----------------------------------------------------------------------------;
; Set FDC initial data rate for drive 0
;
			IFDEF BOOT_DATA_RATE	; TODO: MASM inserts NOP here because of IFDEF
	MOV	AL, BOOT_DATA_RATE		; set to specified default rate
			ENDIF
	CALL	FDC_SET_RATE			; set data rate from state in AL


;----------------------------------------------------------------------------;
; Setup/Detect FDC adapter / chip
;----------------------------------------------------------------------------;
	CALL	FDC_DETECT				; feature detect FDC adapter chip
							; and set capabilities in FD_LR byte

			ENDIF				; END IF FDC_HD_ENABLE EQ 1

;----------------------------------------------------------------------------;
; SETUP COMPLETE - now display POST screen
;----------------------------------------------------------------------------;

			IF SHOW_BANNER EQ 1
;----------------------------------------------------------------------------;
; Optionally display a GLaDISK banner
;
	CALL	PRINT_BANNER			; display if not GLaBIOS
			ENDIF

			IF SHOW_DRIVES EQ 1
;----------------------------------------------------------------------------;
; Optionally show drive letters and types
;
	CALL	SHOW_DRIVE_TYPES
			ENDIF

			IF RECAL_ON_POST EQ 1
;----------------------------------------------------------------------------;
; Optionally recal all drives on POST
;
	CALL	POST_RECAL_DRIVES
			ENDIF

;----------------------------------------------------------------------------;
; Exit Companion ROM init
;----------------------------------------------------------------------------;
SETUP_IVT_DONE:
	POP	AX
	OUT	INT_IMR, AL 			; restore IMR
	POPX	ES, DS
			IF CPU_TYPE EQ CPU_186 OR CPU_TYPE EQ CPU_V20
	POPA						; restore caller register state
			ELSE
	POPX	DI, SI, BP, BX, DX, CX, AX	; restore caller register state
			ENDIF
	POPF						; restore IF
	RETF

ROM_INIT	ENDP
			ASSUME DS:NOTHING, ES:NOTHING
;----------------------------------------------------------------------------;
; END OF ROM INIT
;----------------------------------------------------------------------------;

			IF SHOW_BANNER EQ 1
;----------------------------------------------------------------------------;
; Display a GLaDISK banner if not GLaBIOS
;----------------------------------------------------------------------------;
PRINT_BANNER PROC
	CALL	IS_GLABIOS				; is GLaBIOS?
	JZ	NO_BANNER				; if so, don't display banner
	PRINTLN_SZ VER_BANNER			; otherwise display it
NO_BANNER:
	RET
PRINT_BANNER ENDP
			ENDIF

			IF SHOW_DRIVES EQ 1
;----------------------------------------------------------------------------;
; Display current drives in "CMOS"
;----------------------------------------------------------------------------;
; Clobbers: AX, BX, CX, DS, SI, DI, DX
;----------------------------------------------------------------------------;
			ASSUME DS:_BDA
SHOW_DRIVE_TYPES PROC
	MOV	CX, SEG _BDA
	MOV	DS, CX				; DS = BDA

			IF SHOW_FDC EQ 1
;----------------------------------------------------------------------------;
; Display FDC type
;
	POST_COL_1  S_FDC, POST_CLR_VAL1	; start column 1 - FDC

	CALL	POST_SHOW_FDC_TYPE

				IF USE_FDC_DEBUG EQ 1
;----------------------------------------------------------------------------;
; Display detected FDC type bytes
;
	MOV	AL, ' '				; space
	CALL	OUT_CHAR
	MOV	AL, FD_LR				; AL = LR byte
	AND	AL, HD_TYPE_MASK			; isolate HD capability flags
	MOV	AH, FDC_VER				; get PARTID version
	CALL	WORD_HEX
				ENDIF

	POST_COL_END				; end column 1

;----------------------------------------------------------------------------;
; Display CMOS type
;
; Input:
;	BP = detected CMOS type string, or default 'ROM'
;----------------------------------------------------------------------------;
;
; 1.	Default to 'ROM' (SI)
; 2.	If CMOS_DATA type is set (non-zero):
;		a. If a known RTC type:
;			set SI = BP (previously set string)
;		   Else set string to 'Unknown'
;		d. jump to display string/maybe port
;	Else: (No RTC detected)
;		a. If a known hardware type:
;			- set SI = BP (previously set)
;			- jump to display just string
;		   Else leave SI as default 'ROM'
;
	POST_COL_2  S_CMOS, POST_CLR_VAL1	; start column 2 - CMOS

	MOV	SI, BP				; assume default or detected string

;----------------------------------------------------------------------------;
; Check if this is a detected RTC and display port number if there is a port
;
	MOV	AX, CMOS_DATA			; get CMOS I/O address and type
	MOV	CX, AX				; save to CX
	AND	AH, HIGH MASK RTTYPE		; isolate type
	JZ	SHOW_CMOS_TYPE			; if ROM/None, no port, string already set

;----------------------------------------------------------------------------;
; A RTC type is set in CMOS_DATA. Check if it's one of the supported types
; and display port address after string.
;

			IF CMOS_TYPE_AT EQ 1
;----------------------------------------------------------------------------;
; Is AT CMOS - display 'AT' and port address
;
	CMP	AH, RTC_AT SHL 4			; is AT?
	JE	SHOW_CMOS_PORT
			ENDIF

			IF CMOS_TYPE_NS EQ 1
;----------------------------------------------------------------------------;
; Is NS/NS2 CMOS - display NS and port address
;
	CMP	AH, RTC_NS SHL 4			; is NS or NS2?
	JAE	SHOW_CMOS_PORT
			ENDIF

;----------------------------------------------------------------------------;
; otherwise 'Unknown' and port if non-zero
;
CMOS_TYPE_UNKN:
	MOV	SI, OFFSET FDC_TYPE_U		; otherwise 'Unknown'
	;JMP	SHORT SHOW_CMOS_TYPE		; just fall through to save bytes

SHOW_CMOS_PORT:
	CALL	OUT_SZ

;----------------------------------------------------------------------------;
; Display RTC port address
;
	XCHG	AX, CX				; get CMOS I/O address
	AND	AX, NOT MASK RTTYPE		; clear high nibble (remove type)
	JZ	SHOW_CMOS_TYPE_DONE		; if port 0, do not display
	CALL	SPACE
	CALL	WORD_HEX_TRIM			; display as BYTE or WORD
	JMP	SHORT SHOW_CMOS_TYPE_DONE

SHOW_CMOS_TYPE:
	CALL	OUT_SZ

SHOW_CMOS_TYPE_DONE:
	POST_COL_END_NL				; end column 2

			ENDIF		; show FDC

;----------------------------------------------------------------------------;
; Display drive letters and types
;
	MOV	AH, 8					; get drive count and first drive info
	CWD						; DL = drive 0
	INT	13H					; DL = # of drives, BL = drive CMOS
	JC	SHOW_DRIVE_TYPES_DONE		; BIOS fail or no drives

	XOR	CX, CX
	MOV	CL, DL				; CX = number of drives
	CWD						; DX = 0

	;TEST	BL, BL				; ZF if CMOS type 'None'
	;JZ	NEXT_DRIVE				; skip this drive

;----------------------------------------------------------------------------;
; Display each drive
;
SHOW_DRIVE:
	MOV	DI, BX				; DI = CMOS type
	PUSH	CX					; preserve loop counter
	SET_SZ_ATTR	 POST_CLR_TXT, 1		; set next char to be text color
	MOV	AL, DL				; AL = drive number (0-1)
	ADD	AL, 'A'				; convert to drive letter
	CALL	OUT_CHAR				; write drive letter
	POST_COL_1  S_COLON, POST_CLR_VAL1	; start column 1
	CMP	DI, DRV_N_SZ			; drive type valid in table?
	JB	SHOW_CMOS_TYPE_OK
	XOR	DI, DI				; if out of range, display "None"
SHOW_CMOS_TYPE_OK:
	SHL	DI, 1					; word align drive type table index 
	MOV	SI, CS:DRV_N_TBL[DI]		; SI = drive type string, 1 based index
	CALL	OUT_SZ				; write string
	POST_COL_END_NL				; end column 1
	POP	CX
NEXT_DRIVE:
	INC	DX					; next drive letter in DL
	PUSH	CX
	PUSH	DX
	MOV	AH, 8
	INT	13H
	POP	DX
	POP	CX
	JC	SHOW_DRIVE_TYPES_DONE
	LOOP	SHOW_DRIVE
SHOW_DRIVE_TYPES_DONE:
	RET

;----------------------------------------------------------------------------;
; Drive type display strings
;----------------------------------------------------------------------------;

S_COLON	DB	':', SZ
S_FDC		DB	'FDC', SZ
S_CMOS	DB	'CMOS', SZ
S_CM_NONE	DB	'ROM', SZ

;----------------------------------------------------------------------------;
; Drive Types
;
S_NONE	DB	'None', SZ
S_360		DB	'360 ',  POST_K_UNIT, ' 5', QUARTER, SZ	; 1
S_12		DB	'1.2 ',  POST_M_UNIT, ' 5', QUARTER, SZ	; 2
S_720		DB	'720 ',  POST_K_UNIT, ' 3', HALF, SZ	; 3
S_144		DB	'1.44 ', POST_M_UNIT, ' 3', HALF, SZ	; 4
S_288		DB	'2.88 ', POST_M_UNIT, ' 3', HALF, SZ	; 5

;----------------------------------------------------------------------------;
; Drive CMOS type to name string table
;
DRV_N_TBL	DW	OFFSET S_NONE
		DW	OFFSET S_360		; CMOS type 1
		DW	OFFSET S_12
		DW	OFFSET S_720
		DW	OFFSET S_144
		DW	OFFSET S_288
DRV_N_SZ	EQU	($-DRV_N_TBL)/2

SHOW_DRIVE_TYPES ENDP
			ASSUME DS:NOTHING
			ENDIF				; show drives

;----------------------------------------------------------------------------;
; Detect/Set up FDC version
;----------------------------------------------------------------------------;
; Input:
;	DI = OFFSET FDC_LAST_OP
;	DS = BDA
; Output:
; 	CF if I/O error
;
; Clobbers: AX, DX
;----------------------------------------------------------------------------;
; HD FDC feature support in FD_LR:
;
; FHD  (8272/765/7*65B/multi-IOs):
;	- Set Data rate (250, 300, 500)
;	- Change line (DIR)
; FHD2 (82072+):
;	- DSR/SWR soft reset
;	- CONFIGURE
;	- DUMPREG
;	- FIFO 16 byte
;	- Implied SEEK (EIS) via CONFIGURE
;	- Set data rate 1MB (doesn't necessarily support pmode/2.88)
; FDH3 (82077, 82077-1)
;	- Perpendicular mode
;	- VERSION
; FHD4 (82077AA, 82077SL+, PC8477+):
;	- Enhanced PMODE command
;	- LOCK
; FNSC (NSC DP8473/PC8477):
;	- NSC MODE
;	- Implied SEEK by NSC EIS (per command bit)
;	- "Burst Mode" (whatever that is)
;
; http://dunfield.classiccmp.org/img42841/pcfdc.txt
;----------------------------------------------------------------------------;
; FDC detection process:
;
; Feature	Test
; HD		? (TODO)
; HD2		DUMPREG
; HD3		VERSION 90H
; HD4		VERSION 90H + UN/LOCK
; NSC		MODE
;
; 1. Check FHD bit (TBD)
; 2. DUMPREG command
;	- If error, set HD and done (only HD)
; 3. VERSION
;	- If 80H, set HD2 and done
;	- If 90H, set HD3 and continue
; 4. UNLOCK
;	- If error, done
;	- If success:
;		- set HD4
;		- set Enhanced PERPENDICULAR (configuration if required)
;		- CONFIGURE and LOCK
;		- continue
; 5. MODE
;	- If error, done
;	- If success, set NSC
;
; TODO:
; - Test for basic HD (data rate / change line) vs DD only
; - only perform necessary tests based on FDC_TYPE_*
;
;----------------------------------------------------------------------------;
NSC_TEST_MODE	EQU	1			; 1=use MODE command to test for NSC
							; 0=use PARTID (won't detect DP8473)
			ASSUME DS:_BDA
FDC_DETECT PROC
	XOR	AX, AX				; AH = 0	

			IF FDC_HD_ENABLE NE 1

;----------------------------------------------------------------------------;
; Clear FHD flag only if DD controller build
;
	AND	_FD_LR, NOT HD_TYPE_MASK	; clear all HD feature bits
	MOV	FDC_VER, AL				; BDA version = 00h

			ELSE

;----------------------------------------------------------------------------;
; Reset controller
;
	CWD						; DL = 0
	INT	13H					; AH = 0 reset
	JC	FDC_DETECT_EXIT

;----------------------------------------------------------------------------;
; 1. Check FHD bit (TBD)
;
	OR	_FD_LR, MASK FHD			; just set for now

			IF FDC_MODEL EQ FDC_MODEL_5170
;----------------------------------------------------------------------------;
; 1A. Check if 5170 Combo adapter by reading FDC and HDC diag registers
;
	MOV	DX, 03F1H				; AT combo card diag register
	IN	AL, DX				; read diag status
	AND	AL, 11110000B			; mask high bits
	CMP	AL, 10100000B			; is combo adapter?
	JNE	NOT_FDC_TYPE_5170			; don't set if not combo card
	MOV	DX, 05F7H				; AT FD diag register
	IN	AL, DX				; read diag status
	AND	AL, 11110000B			; mask high bits
	CMP	AL, 10100000B			; is combo adapter?
	JE	NOT_FDC_TYPE_5170			; don't set if not combo card
	OR	_FD_LR, MASK FHD			; set FHD AT bit
	JMP	SHORT FDC_DETECT_DONE		; done - can only be FHD
NOT_FDC_TYPE_5170:
			ENDIF

;----------------------------------------------------------------------------;
; 2. DUMPREG command
;	- If 80H/error, done
;	- If success, set HD2 and continue
;
FDC_SETUP_TEST_DUMPREG:
	CALL	FDC_DUMPREG
	JC	FDC_SETUP_TEST_NSC		; check for DP8473
	OR	_FD_LR, MASK FHD2			; flag 82072+

;----------------------------------------------------------------------------;
; 3. VERSION
;	- If 80H/error, done
;	- If 90H, set HD3 and continue
;
	MOV	AL, FDC_CMD_VER			; FDC Version command
	CALL	FDC_SEND_RECV_ALL
	MOV	FDC_VER, AL				; save to BDA
	JC	FDC_DETECT_DONE			; does not support VERSION
	CMP	AL, 90H				; extended controller result?
	JNE	FDC_DETECT_DONE
	OR	_FD_LR, MASK FHD3 		; flag supports 82077

;----------------------------------------------------------------------------;
; 4. UNLOCK
;	- If error, done
;	- If success, set HD4 and continue
;
	MOV	AL, FDC_CMD_UNLOCK		; FDC UNLOCK command
	CALL	FDC_SEND_RECV_ALL
	JC	FDC_DETECT_DONE			; exit if UNLOCK command not avail.
	OR	_FD_LR, MASK FHD4 		; else, flag supports Intel 82077AA+

;----------------------------------------------------------------------------;
; Set up Enhanced PMODE if enabled in build.
;
			IF FDC_PMODE EQ 1
EXTRN		FDC_SET_EPMODE:NEAR
	CALL	FDC_SET_EPMODE
			ENDIF

;----------------------------------------------------------------------------;
; Since LOCK is supported, configure and LOCK now
;
	MOV	AL, FDC_CONF_BYTE
	CALL	FDC_CONFIGURE_LOCK		; AL = result byte (10H if locked)
	CALL	FDC_DUMPREG

;----------------------------------------------------------------------------;
; 5. Test for NSC DP8473/PC8477
;
FDC_SETUP_TEST_NSC:
			IF NSC_TEST_MODE EQ 0
;----------------------------------------------------------------------------;
; 5. METHOD 1: PARTID - cannot detect DP8473 vs. 82072
; Get extended version (Part ID, NSC)
; If 72H or 73H (NSC FDC) then FDC supports:
;	- MODE
;	- NSC EIS
;	- LOCK
;
FDC_SETUP_TEST_PARTID:
	MOV	AL, FDC_CMD_NSC			; [0] FDC Ext Version command
	CALL	FDC_SEND_RECV_ALL			; AL = PART ID / NSC version
	JC	FDC_DETECT_DONE
	MOV	FDC_VER, AL				; save to BDA
	CMP	AL, 80H				; does not support PARTID
	JE	FDC_DETECT_DONE
	OR	_FD_LR, MASK FNSC 		; flag NSC

			ELSE
;----------------------------------------------------------------------------;
; 5. METHOD 2: MODE
;	- If error, done
;	- If success, set NSC
;
TEST_MODE_CMD:
	MOV	AL, FDC_CMD_MODE
	CALL	FDC_TEST_CMD			; test for NSC command
	JNA	FDC_DETECT_DONE			; not NSC (ZF) or error (CF)
	OR	_FD_LR, MASK FNSC 		; flag NSC - FDC requires reset
			ENDIF

FDC_DETECT_DONE:
;----------------------------------------------------------------------------;
; Reset controller again
;
	XOR	AX, AX				; AH = 0
	CWD						; DL = 0
	INT	13H					; AH = 0 reset
				ENDIF			; HD support

FDC_DETECT_EXIT:
	RET

FDC_DETECT ENDP
			ASSUME DS:NOTHING

			IF SHOW_FDC EQ 1
;----------------------------------------------------------------------------;
; Display detected FDC chipset
;----------------------------------------------------------------------------;
			ASSUME DS:_BDA

POST_SHOW_FDC PROC
;----------------------------------------------------------------------------;
; Adapter ISA type names delimited by SZ. 
;
FDC_TYPE_TBL:
FDC_TYPE_0	DB	HD_TYPE_0, 'DD', SZ		; 00H: 765/8272A - no HD support
FDC_TYPE_1	DB	HD_TYPE_1, '765/8272', SZ	; 01H: AT, 82072/765B/37C65/generic MIO
FDC_TYPE_2	DB	HD_TYPE_2, '82072', SZ		; 03H: Intel 82072+
FDC_TYPE_3	DB	HD_TYPE_3, '82077', SZ		; 07H: Intel 82077
FDC_TYPE_4	DB	HD_TYPE_4, '82077AA', SZ	; 0FH: Intel 82077AA+
FDC_TYPE_N1	DB	HD_TYPE_NSC1, 'DP8473', SZ	; 11H: NSC DP8473
FDC_TYPE_N2	DB	HD_TYPE_NSC2, 'PC8477', SZ	; 1FH: NSC PC8477+
FDC_TYPE_TBL_SZ	EQU	($-FDC_TYPE_TBL)		; size of searchable table
FDC_TYPE_U	DB	'Unknown', SZ			; fall through for no match

;----------------------------------------------------------------------------;
; Display detected FDC chipset
;----------------------------------------------------------------------------;
; Clobbers: AX, CX, SI, DI
;----------------------------------------------------------------------------;
POST_SHOW_FDC_TYPE PROC
	PUSH	ES				; preserve ES (necessary?)
	PUSH	CS
	POP	ES				; ES = CS
	MOV	CX, FDC_TYPE_TBL_SZ	; string table length
	MOV	DI, OFFSET FDC_TYPE_TBL
	MOV	AL, FD_LR
	AND	AX, HD_TYPE_MASK		; AL = FDC type bits, AH = SZ

;----------------------------------------------------------------------------;
; Who doesn't love a linear search?
;
POST_SHOW_FDC_SCAN:
	DEC	CX				; dec counter for SCASB
	SCASB					; is first byte the type?
	JE	POST_SHOW_FDC_FOUND	; if so, string found and exit
	XCHG	AL, AH			; scan for SZ string terminator
	REPNE	SCASB				; look for next delimiter
	XCHG	AL, AH			; scan for FDC type again
	INC	CX				; set up for "JCXNZ" test
	LOOP	POST_SHOW_FDC_SCAN	; if not end of string, check byte

POST_SHOW_FDC_FOUND:
	XCHG	DI, SI			; move found string to SI

POST_SHOW_FDC_NAME:
	CALL	OUT_SZ

POST_SHOW_FDC_TYPE_EXIT:
	POP	ES
	RET
POST_SHOW_FDC_TYPE ENDP
POST_SHOW_FDC ENDP
			ENDIF			; IF SHOW_FDC EQ 1

			IF RECAL_ON_POST EQ 1
;----------------------------------------------------------------------------;
; RECAL both drives on POST
;----------------------------------------------------------------------------;
; Clobbers AX, BX, CX, DX, DI
;----------------------------------------------------------------------------;
EXTRN FDC_RECAL_DBL:NEAR			; from INT_13
POST_RECAL_DRIVES PROC
	CALL	GET_MAX_DRIVE_COUNT		; AL = # of drives or MAX_DRIVES
	JNA	POST_RECAL_DRIVE_ERR		; exit if CF (invalid count) or ZF (zero drives)
	MOV	DI, OFFSET FD_LAST_OP
	CWD						; DL = drive 0
	XCHG	AX, CX				; CX = # of drives
POST_RECAL_DRIVE:
	CALL	FDC_RECAL_DBL
	;JC	POST_RECAL_DRIVE_ERR		; will error if not track 0
	INC	DX
	LOOP	POST_RECAL_DRIVE
POST_RECAL_DRIVE_ERR:
	RET
POST_RECAL_DRIVES ENDP
			ENDIF

;----------------------------------------------------------------------------;
; SUPPORT PROCs RELATED TO GLaDISK
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; FD_GET_CMOS: Get specified drive type from BDA ("CMOS")
;----------------------------------------------------------------------------;
; Input:
; 	DL = drive index (0 - FDC_MAX_DRIVES-1)
; Output:
;	AL = CMOS Drive Types: 0=none, 1=360, 2=1.2, 3=720, 4=1.44, 5=2.88
;	CF if drive (or CMOS type) not valid or not present (type in AL = 0)
;----------------------------------------------------------------------------;
		ASSUME DS:_BDA
FD_GET_CMOS PROC
	CMP	DL, FDC_MAX_DRIVES-1		; is drive # valid (0-3)?
	JA	FD_GET_CMOS_NONE			; exit with CF and AL = 0 if invalid
	MOV	AL, FD_CMOS_TYPE			; BDA CMOS type for drive 0 or 1

			IF FDC_MAX_DRIVES GT 2
;----------------------------------------------------------------------------;
; Longer version to support 4 drives
;
	PUSH	DX
	SHR	DL, 1					; CF if 1 or 3, ZF if 0 or 1
	POP	DX
	JZ	FD_GET_CMOS_01			; jump if drive 0 or 1
	MOV	AL, FD2_CMOS_TYPE			; is drive 2 or 3
FD_GET_CMOS_01:
	JC	FD_GET_CMOS_CHK			; jump if drive 0 or 2

			ELSE
;----------------------------------------------------------------------------;
; Shorter version to support 2 drives
;
	JE	FD_GET_CMOS_CHK			; jump if drive 1

			ENDIF

;----------------------------------------------------------------------------;
; If odd numbered drive, shift high nibble into low
;
			IF CPU_TYPE EQ CPU_V20 OR CPU_TYPE EQ CPU_186
	SHR	AL, 4					; shift high nibble to low
			ELSE
		REPT	4
	SHR	AL, 1					; shift high nibble to low
		ENDM
			ENDIF

;----------------------------------------------------------------------------;
; Verify result is a valid CMOS type
;
FD_GET_CMOS_CHK:
	AND	AL, MASK FDT1			; only low CMOS bits
	JZ	FD_GET_CMOS_DONE			; return CF if CMOS none
	CMP	AL, FDCM_MAX+1			; is CMOS type valid (1-FDCM_MAX)?
	JAE	FD_GET_CMOS_NONE			; set to 0 and exit with CF
FD_GET_CMOS_DONE:
	CMC
	RET
FD_GET_CMOS_NONE:
	MOV	AL, 0
	JMP	SHORT FD_GET_CMOS_DONE
FD_GET_CMOS ENDP
		ASSUME DS:NOTHING

			IF 0
;----------------------------------------------------------------------------;
; Get Detected Port and RTC type from BDA
; TODO: move to CMOS.ASM?
; UNUSED (at the moment)
;----------------------------------------------------------------------------;
; Output:
;	DI = port
;	AL = RTC type (high nibble)
;	ZF if no RTC, NZ if port was not detected during POST
;----------------------------------------------------------------------------;
GET_RTC_CMOS PROC NEAR
	PUSH	DS
	MOV	AX, SEG _BDA 			; get BDA segment
	MOV	DS, AX 				; DS = BDA
	MOV	AX, RTC_DATA
	MOV	DI, AX
	AND	DI, MASK RTPORT			; DI = RTC port
	MOV	AL, AH
	AND	AL, HIGH MASK RTTYPE		; AL (high nibble) = RTC type
	POP	DS
	RET
GET_RTC_CMOS ENDP
			ENDIF

;----------------------------------------------------------------------------;
; GET_DRIVE_COUNT: Get drive count according to BDA
;----------------------------------------------------------------------------;
; Input:
;	DS = BDA (TODO)
; Output:
;	AX = 1-based drive count (0 - 4)
;	CF if out of range in FDC_MAX_DRIVES
;	ZF if 0 drives installed
;----------------------------------------------------------------------------;
		ASSUME DS:_BDA
GET_DRIVE_COUNT PROC
	PUSH	DS					; TODO: necessary?
	MOV	AX, SEG _BDA			; AH = 0
	MOV	DS, AX
	GET_EFLAG	IPL,,1			; AL = floppy IPL/flag
	JZ	GET_DRIVE_COUNT_DONE		; jump if no FDC installed
	GET_EFLAG	FLP,,1			; AL = # of drives
	INC	AX					; adjust to 1 based count
	CMP	AL, FDC_MAX_DRIVES+1
	CMC						; CF if out of range
GET_DRIVE_COUNT_DONE:
	POP	DS
	RET
GET_DRIVE_COUNT ENDP

;----------------------------------------------------------------------------;
; GET_MAX_DRIVE_COUNT: Get drive count according to BDA
;----------------------------------------------------------------------------;
; If BIOS reports more drives than FDC_MAX_DRIVES, FDC_MAX_DRIVES will be used.
;
; Output:
;	AX = 1-based drive count (0 - FDC_MAX_DRIVES)
;	ZF if 0 drives, NZ if 1 or more.
;----------------------------------------------------------------------------;
GET_MAX_DRIVE_COUNT PROC
	CALL	GET_DRIVE_COUNT
	JNC	GET_MAX_DRIVE_COUNT_EXIT	; exit if valid
	MOV	AL, FDC_MAX_DRIVES
	CLC
GET_MAX_DRIVE_COUNT_EXIT:
	RET
GET_MAX_DRIVE_COUNT ENDP
		ASSUME DS:NOTHING

		IF CHECK_BUILD_CPU EQ 1
;----------------------------------------------------------------------------;
; Check if CPU is supported by current build type
;----------------------------------------------------------------------------;
; CPU_IS_8088:
;	NZ: is 186+:
;		- Build V20: exit with CF
;		- Build 186: exit with NC
;	ZF: is V20/8088, check V20 CPU_IS_V20:
;		- ZF: is V20, exit with NC (V20 or 186 Build OK)
;		- NZ: is 8088
;			- Build V20: exit with NC
;			- Build 8088: exit with CF
;----------------------------------------------------------------------------;
VERIFY_CPU PROC
	PUSH	AX
	PUSH	CX

		IF CPU_TYPE	NE CPU_8088
;----------------------------------------------------------------------------;
; Check if 8088/V20 CPU
;----------------------------------------------------------------------------;
; Output:
;	ZF = 1 if V20/8088, ZF = 0 if 186+
;
CPU_IS_8088:
	MOV	CL, 20H			; on 186+, shifts are AND'd with 0FH
	MOV	AX, 1				;  so 20H shifts will have no effect on AX
	SHR	AX, CL			; AX=0 if V20/8088/8086, AX=1 if 186+
	TEST	AX, AX			; SHR is ignored on 286, re-test for flags
			IF CPU_TYPE EQ CPU_186
	JNZ	VERIFY_CPU_OK		; 186 detected and 186 build: OK
			ENDIF

;----------------------------------------------------------------------------;
; Check if V20/30/40 CPU
;----------------------------------------------------------------------------;
; Output:
;	ZF = 1 if Vx0, ZF = 0 if 8088
;
CPU_IS_V20:
	MOV	AX, DBW <1,1>		; Attempt to pack bytes into nibbles
	AAD_I	10H				; result is 11 if V20, 11H if x86
	CMP	AL, 11			; ZF = 1 if V20, ZF = 0 if 8088
	JZ	VERIFY_CPU_OK		; V20 detected and V20 or 186 build: OK
						; else 8088 detected: FAIL
VERIFY_CPU_FAIL:
	STC
	JMP	SHORT VERIFY_CPU_DONE
		ENDIF				; END IF CPU_TYPE NE CPU_8088

VERIFY_CPU_OK:
	CLC
VERIFY_CPU_DONE:
	POP	CX
	POP	AX
	RET
VERIFY_CPU ENDP
		ENDIF

		IF CMOS_VAL_TYPE EQ 1
;----------------------------------------------------------------------------;
; Verify all drives are in valid CMOS type range, if not set to 0
;----------------------------------------------------------------------------;
; Input: AL = drive type packed nibble
; Output: AL = drive type, type is 0 if out of range
;----------------------------------------------------------------------------;
CMOS_VER_TYPE PROC
	CMP	AL, DNB < FDCM_MAX+1, 0 >	; check max valid in high nibble
	JC	CMOS_D0_VALID			; high nibble out of range?
	AND	AL, NOT (MASK FDS0 OR MASK FDT0)	; drive 0 = 0
CMOS_D0_VALID:
	CMP	AL, DNB < 0, FDCM_MAX+1 >	; check max valid in low nibble
	PUSH	AX					; save AH
	LAHF						; save half carry/AF flag
	TEST	AH, MASK FAF			; ZF = ! AF
	POP	AX					; restore AH
	JNZ	CMOS_D1_VALID			; low nibble out of range?
	AND	AL, NOT (MASK FDS1 OR MASK FDT1)	; drive 1 = 0
CMOS_D1_VALID:
	RET
CMOS_VER_TYPE ENDP
		ENDIF					; /CMOS_VAL_TYPE

;----------------------------------------------------------------------------;
; END of ROM
;----------------------------------------------------------------------------;
OPTROM	ENDS
		END

----------------------------------------------------------------------------
Text Auto-Formatting:

----------------------------------------------------------------------------
Sublime Text syntax:
{
 	"tab_completion": false,
	"auto_complete": false,
	"tab_size": 6,
}

----------------------------------------------------------------------------
Modeline magic for various editors

/* vim: set tabstop=6:softtabstop=6:shiftwidth=6:noexpandtab */
# sublime: tab_completion false; auto_complete false; tab_size 6
