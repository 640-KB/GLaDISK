;----------------------------------------------------------------------------;
; GLaDISK (Gizmo Linkage and Dynamic Information Storage Keeper)
;
; Copyright (c) 2022-2025, 640KB and contributors
;----------------------------------------------------------------------------;
INCLUDE EQU.INC

;----------------------------------------------------------------------------;
; GLaDISK Config Build Options
;----------------------------------------------------------------------------;
SHOW_BANNER		=	1		; display GLaDISK banner
SHOW_BANNER_GB	=	0		; display GLaDISK banner on GLaBIOS (TODO but why?)
SHOW_DRIVES		=	1		; display drive types on POST
SHOW_FDC		=	1		; display FDC and CMOS type on POST
UNITS_IEC		=	0		; 0=period-correct "KB" or 1=modern IEC "KiB"
IS_TURBO		= 	1		; optimize for faster CPUs

;----------------------------------------------------------------------------;
; Specific controller model sub-types - these are cards that have onboard
; methods to select drive types or features unique to that card
;
; If unsure, try Advanced HD controller or leave all commented out for
; fully customized settings further down.
;
FDC_MODEL	=	FDC_MODEL_ADV	; Advanced high density controller
;FDC_MODEL	=	FDC_MODEL_HD	; Basic high density controller
;FDC_MODEL	=	FDC_MODEL_5170	; 5170 "combo card" controller (765)
;FDC_MODEL	=	FDC_MODEL_DTK	; DTK PII-151B (DP8473)
;FDC_MODEL	=	FDC_MODEL_LSI1	; LCS-6610F-U (765)
;FDC_MODEL	=	FDC_MODEL_LSI2	; LCS-6812F/6814F Rev A2 (DP8473)
;FDC_MODEL	=	FDC_MODEL_ACC	; ACC 3201
;FDC_MODEL	=	FDC_MODEL_CA	; CompuAdd 810 (765)
;FDC_MODEL	=	FDC_MODEL_PE510	; PE-510 (DP8473)
;FDC_MODEL	=	FDC_MODEL_QF	; QuadFlop or XT-FDC_ForQuadFloppies
;FDC_MODEL	=	FDC_MODEL_NUXT	; NuXT 2.0

;----------------------------------------------------------------------------;
; Default drive type configuration for ROM CMOS type
; This is the fallback if there is no software or hardware drive settings.
; This can be also modified by editing the ROM binary (see Github for details)
;
;CMOS_DRIVE_TYPES	EQU	< FDCM_28, FDCM_14 >		; A: 2.88 / B: 1.44
;CMOS_DRIVE_TYPES	EQU	< FDCM_28, FDCM_12 >		; A: 2.88 / B: 1.2
CMOS_DRIVE_TYPES	EQU	< FDCM_14, FDCM_12 >		; A: 1.44 / B: 1.2
;CMOS_DRIVE_TYPES	EQU	< FDCM_14, FDCM_NONE >		; A: 1.44 / B: none
;CMOS_DRIVE_TYPES	EQU	< FDCM_14, FDCM_360 >		; A: 1.44 / B: 360
;CMOS_DRIVE_TYPES	EQU	< FDCM_360, FDCM_14 >		; A: 1.44 / B: 360
;CMOS_DRIVE_TYPES	EQU	< FDCM_12, FDCM_14 >		; A: 1.2 / B: 1.44
;CMOS_DRIVE_TYPES	EQU	< FDCM_360, FDCM_NONE >		; A: 360 / B: none
;CMOS_DRIVE_TYPES	EQU	< FDCM_720, FDCM_NONE >		; A: 720 / B: none
;CMOS_DRIVE_TYPES	EQU	< FDCM_360, FDCM_360 >		; A: 360 / B: 360
;CMOS_DRIVE_TYPES	EQU	< FDCM_720, FDCM_360 >		; A: 720 / B: 360

;CMOS_DRIVE_TYPES	EQU	< FDCM_14, FDCM_12, FDCM_14, FDCM_12 >
;CMOS_DRIVE_TYPES	EQU	< FDCM_14, FDCM_720, FDCM_12, FDCM_360 >
;CMOS_DRIVE_TYPES	EQU	< FDCM_14, FDCM_12, FDCM_720, FDCM_14 >
;CMOS_DRIVE_TYPES	EQU	< FDCM_14, FDCM_720, FDCM_12, FDCM_14 >
;CMOS_DRIVE_TYPES	EQU	< FDCM_14, FDCM_12, FDCM_12, FDCM_14 >
;CMOS_DRIVE_TYPES	EQU	< FDCM_360, FDCM_12, FDCM_720, FDCM_14 >
;CMOS_DRIVE_TYPES	EQU	< FDCM_360, FDCM_360, FDCM_14, FDCM_12 >

;----------------------------------------------------------------------------;
; Advanced Options
;----------------------------------------------------------------------------;
AT_WAIT		=	0		; use AT WAIT instead of PIT delay
AT_TEST_MID		=	1		; test Machine ID byte for AT (FCH)
CHECK_BUILD_CPU	=	0		; verify CPU is compatible with build
FAST_STEP_RATE	=	1		; use faster head step rates for 360, 1.44 and 2.88
FDC_ADV_SEEK	=	1		; cache head locations in BDA
FDC_BDA_MAX		=	0		; set BDA drive count to FDX_MAX_DRIVES
FDC_DBL_RECAL	=	1		; recal twice to 80 track media
FDC_DSR_RESET	=	0		; use DSR reset on supported chipsets
FDC_HLT_WAIT	=	1		; Halt CPU during FD access
FDC_PMODE		=	0		; enable perpendicular mode for 2.88 drive/media
FDC_PMODE_500	=	0		; enable 500K PMode GAP=1 and WGATE=0 PMODE
FDC_SPMODE		=	1		; enable 82072 compatible standard PMODE
FDC_TWADDLE		=	0		; enable "twaddle" support (not implemented)
FIFO_DEPTH		=	10		; FIFO threshold/depth (if supported/enabled)
FIFO_DEPTH_PMODE	=	12		; FIFO threshold/depth (if PMODE supported)
GLADISK_INT_0EH	=	1		; replace existing BIOS FDC IRQ
GLADISK_INT_1EH	=	1		; replace existing BIOS default DBT
FDC_IMR_IRQ6	=	1		; unmask IRQ6 on FDC reset
RECAL_ON_POST	=	1		; recal all drives on POST
POST_TEST_SEEK	=	0		; perform GLaBIOS style seek test on POST
UNSAFE_FLOPPY	=	1		; Use % of DBT specified disk head settle time
;UNSAFE_FLP_DIV	EQU	<1/2>		; 50%
UNSAFE_FLP_DIV	EQU	<1/3>		; 33%
;UNSAFE_FLP_DIV	EQU	<1/4>		; 25% (begins to get unreliable here)
;UNSAFE_FLP_DIV	EQU	<1/6>		; 17%
;UNSAFE_FLP_DIV	EQU	<1/80>	; insane!
;BOOT_DATA_RATE	EQU	FSR250	; uncomment to set initial rate, otherwise 
						; data rate is set to max rate of drive 0
BOOT_DATA_RATE	=	80H		; TODO: fix since MASM 6 and 5 handle differently?

;----------------------------------------------------------------------------;
; Default options for all HD controllers
;----------------------------------------------------------------------------;
FDC_HD_ENABLE	=	1		; enable HD support
FDC_MAX_DRIVES	=	2		; up to 2 drives (for now)
FDC_DBL_RECAL	=	1		; always double recal
FDC_EIS		=	0		; Implied seek disabled
FDC_FIFO		=	1		; FIFO enabled
FDC_NO_POLL		=	0		; disable drive POLL via CONFIGURE to 
						;  avoid four sense operations on reset

;----------------------------------------------------------------------------;
; NVRAM-based (CMOS) drive type config setting supported - multiple may be enabled
;
;CMOS_TYPE_AT	=	1		; AT/MC146818/DS18x85, ports 70, 240, 2C0
;CMOS_TYPE_NS	=	1		; MM51687 (NS), ports 240, 2C0

;----------------------------------------------------------------------------;
; FDC chipset type - the highest feature set options available
; Only necessary if custom configuring by NOT using an FDC_MODEL
;
;FDC_TYPE	=	FDC_TYPE_DD		; 765/8272 double density controller only
;FDC_TYPE	=	FDC_TYPE_HD1	; Basic HD: WD37C65 / 765B (HD1)
;FDC_TYPE	=	FDC_TYPE_HD2	; 82072 (HD2)
;FDC_TYPE	=	FDC_TYPE_HD3	; 82077 (HD3)
;FDC_TYPE	=	FDC_TYPE_ADV	; 82077+, PC8477B (HD4)
;FDC_TYPE	=	FDC_TYPE_NSC	; NSC DP8473 only

;----------------------------------------------------------------------------;
; Target PC Architecture
;
	IFNDEF ARCH_TYPE
ARCH_TYPE		EQU	ARCH_5160		; PC 5160, 5150, non-Turbo
;ARCH_TYPE		EQU	ARCH_TURBO		; Standard Turbo XT
;ARCH_TYPE		EQU	ARCH_TD3300		; TD3300A (ST-xx/UNIQUE/Auva)
;ARCH_TYPE		EQU	ARCH_EMU		; Emulator
;ARCH_TYPE		EQU	ARCH_AT		; AT, 286, 386+
	ENDIF

;----------------------------------------------------------------------------;
; CPU Architecture Instruction types
;
; Note: Using non-8088 makes very little difference and will only result in a
; less compatible ROM.
;
CPU_TYPE		=	CPU_8088		; all CPUs (recommended)
;CPU_TYPE		=	CPU_186		; use 186/286/386+ instructions
;CPU_TYPE		=	CPU_V20		; use V20+ only instructions

;----------------------------------------------------------------------------;
;
; END Config - DO NOT EDIT BELOW (or else)
;
;----------------------------------------------------------------------------;


;----------------------------------------------------------------------------;
; Devloper options
;----------------------------------------------------------------------------;
USE_FDC_DEBUG	= 	0	; FD_DEBUG available
ENFORCE_HST		=	0	; disallow non-zero head settle times on write
FD_ENABLE_SS	=	1	; check only head 0 when detecting media to 
					;  support single sided disks
FDC_ZERO_BDA	=	0	; clear all FD status bytes between ops
					;  causes issues with badly behaved ROMS like Seagate MFM
					;  leave this off
IRET_FLAGS		=	0	; preserve result flags on IRET? (aka do the right thing)
					;  enabling this creates known compatibility issues,
					;  leave this off too
PCE_FIX		=	0	; debug workaround to use low density controller
XT_V3_FIX		=	0	; workaround 5160 V3 BDA issue

FDC_SOFT_POLL	=	1	; enable/disable polling by detection if FDC_NO_POLL = 1
USE_NSC_MODE	=	0	; Send NSC MODE command on reset
FDC_MULTI_MOTOR	=	0	; Allow multiple motors on at same time
					;  TODO: this is not complete
BANNER_VER		=	1	; display version number on banner
BANNER_BLD		=	0	; display build details (CPU, ARCH, FDC)
BANNER_TAG		=	1	; display tagline
BANNER_DATE		=	0	; display release date
CMOS_VAL_TYPE	=	1	; validate CMOS types, set to 0/None if invalid


;----------------------------------------------------------------------------;
; Reconfigure options based on adapter models
;----------------------------------------------------------------------------;
	IF FDC_MODEL EQ FDC_MODEL_HD
FDC_TYPE		=	FDC_TYPE_HD		; basic 765 support only
	ENDIF

	IF FDC_MODEL EQ FDC_MODEL_ADV
FDC_TYPE		=	FDC_TYPE_ADV	; has 82077AA/PC8477
	ENDIF

	IF FDC_MODEL EQ FDC_MODEL_5170	; 5170 Combo Controller
CMOS_TYPE_AT	=	1			; likely installed on 5170
FDC_MAX_DRIVES	=	2			; max 2 drives
FDC_PMODE		=	0			; does not support PMODE
FDC_TYPE		=	FDC_TYPE_HD1	; is a 765 FDC
FDC_DBL_RECAL	=	1			; always double recal
	ENDIF

	IF FDC_MODEL EQ FDC_MODEL_LSI1	; LSI LCS-6610F-U
CMOS_TYPE_LSI1	=	1
FDC_TYPE		=	FDC_TYPE_HD1	; is a 765 FDC
FDC_MAX_DRIVES	=	2			; max 2 drives
FDC_PMODE		=	0			; necessary?
	ENDIF

	IF FDC_MODEL EQ FDC_MODEL_LSI2	; LSI LCS-6812F
CMOS_TYPE_LSI2	=	1
FDC_MAX_DRIVES	=	2			; max 2 drives (TODO 4?)
FDC_TYPE		=	FDC_TYPE_NSC	; NSC DP8473
	ENDIF

	IF FDC_MODEL EQ FDC_MODEL_DTK		; DTK PII-151B
		IFNDEF CMOS_TYPE_AT
CMOS_TYPE_AT	=	0			; why?
		ENDIF
CMOS_TYPE_DTK1	=	1
FDC_MAX_DRIVES	=	2			; max 2 drives
FDC_TYPE		=	FDC_TYPE_NSC	; NSC DP8473 only
	ENDIF

	IF FDC_MODEL EQ FDC_MODEL_ACC
CMOS_TYPE_AT	=	0
CMOS_TYPE_ACC	=	1
FDC_MAX_DRIVES	=	4			; max 4 drives
;FDC_MAX_DRIVES	=	2			; max 2 drives
;FDC_PMODE		=	0
;FDC_DSR_RESET	=	0			; DOR reset only
;FDC_EIS		=	0			; no Implied seek
FDC_TYPE		=	FDC_TYPE_HD1	; TODO verify this
	ENDIF

	IF FDC_MODEL EQ FDC_MODEL_CA		; CompuAdd C810
;CMOS_TYPE_AT	=	0			; uncomment to use CMOS
CMOS_TYPE_CA	=	1			; use motherboard DIP switch
FDC_MAX_DRIVES	=	2			; max 2 drives
;FDC_PMODE		=	0
;FDC_FIFO		=	0			; FIFO
FDC_DSR_RESET	=	0			; DOR reset only
FDC_EIS		=	0			; Implied seek
FDC_TYPE		=	FDC_TYPE_HD1	; TODO verify this
IS_TURBO		= 	1
	ENDIF

	IF FDC_MODEL EQ FDC_MODEL_PE510
CMOS_TYPE_PE510	=	1			; PE-510
FDC_TYPE		=	FDC_TYPE_NSC
	ENDIF

	IF FDC_MODEL EQ FDC_MODEL_NUXT
AT_WAIT		=	0			; not AT BIOS
AT_TEST_MID		=	0			; not AT BIOS
CMOS_TYPE_AT	=	1			; has integrated port 70H DS12x85
FDC_TYPE		=	FDC_TYPE_ADV	; has 82077AA/PC8477
FDC_MAX_DRIVES	=	2			; integrated FDC supports two drives
IS_TURBO		= 	1
UNITS_IEC		=	1			; use modern IEC MiB, KiB
FDC_SOFT_POLL	=	0			; use only CONFIGURE to disable poll
	ENDIF

	IF FDC_MODEL EQ FDC_MODEL_QF
FDC_TYPE		=	FDC_TYPE_ADV	; has 82077AA/PC8477
FDC_MAX_DRIVES	=	4			; max 4 drives
	ENDIF

;	IF FDC_MODEL EQ FDC_MODEL_86BOX
;FDC_TYPE		=	FDC_TYPE_ADV	; has 82077AA/PC8477
;IS_TURBO		= 	1
;	ENDIF

;----------------------------------------------------------------------------;
; Reconfigure options based on FDC types
;----------------------------------------------------------------------------;

	IF FDC_TYPE EQ FDC_TYPE_DD
;----------------------------------------------------------------------------;
; Double Density only controller (360K or 720K)
;
FDC_HD_ENABLE	=	0		; no HD support
FDC_MAX_DRIVES	=	4		; up to 4 drives
FDC_DSR_RESET	=	0		; DOR reset only
FDC_DBL_RECAL	=	0		; only one recal
CMOS_TYPE_NONE	=	0		; no drive types for DD controllers
FDC_DBL_RECAL	=	0		; do not double recal
	ENDIF

;----------------------------------------------------------------------------;
; HD1 basic controller feature support (WD37C65, 765B, many Multi-I/Os)
;
	IF FDC_TYPE EQ FDC_TYPE_HD1
FDC_EIS		=	0		; No implied seek
FDC_FIFO		=	0		; FIFO
FDC_DSR_RESET	=	0		; DOR reset only
FDC_NO_POLL		=	0		; do not disable drive POLL via CONFIGURE
FDC_PMODE		=	0		; disable perpendicular mode for 2.88 drive/media
FDC_DBL_RECAL	=	1		; always double recal (only 77 pulses)
	ENDIF

;----------------------------------------------------------------------------;
; HD2 controller feature support (82072)
;
	IF FDC_TYPE EQ FDC_TYPE_HD2
FDC_FIFO		=	1		; FIFO
FDC_EIS		=	1		; Implied seek
FDC_DSR_RESET	=	1		; DSR reset supported
FDC_PMODE		=	0		; disable perpendicular mode for 2.88 drive/media
FDC_SPMODE		=	0		; disable standard pmode (2.88 won't work with 82072)
ENABLE_EPMODE	=	0		; disable enhanced pmode (TODO)
FDC_NO_POLL		=	1		; disable drive POLL via CONFIGURE
FDC_DBL_RECAL	=	0		; 82072 does 256 pulses
	ENDIF

;----------------------------------------------------------------------------;
; HD3 controller feature support (82077)
;
	IF FDC_TYPE EQ FDC_TYPE_HD3
FDC_FIFO		=	1		; FIFO
FDC_EIS		=	0		; Implied seek (incomplete)
FDC_DSR_RESET	=	1		; DSR reset supported
FDC_PMODE		=	1		; enable perpendicular mode for 2.88 drive/media
FDC_SPMODE		=	1		; enable standard pmode (2.88 won't work with 82072)
ENABLE_EPMODE	=	0		; disable enhanced pmode (TODO)
FDC_NO_POLL		=	1		; disable drive POLL via CONFIGURE
FDC_DBL_RECAL	=	0		; 82072 does 255 pulses
	ENDIF

;----------------------------------------------------------------------------;
; Advanced (HD4) controller feature support (82077AA/SL, PC8477 and above)
;
	IF FDC_TYPE EQ FDC_TYPE_ADV
FDC_FIFO		=	1		; FIFO
FDC_EIS		=	0		; Implied seek (incomplete)
FDC_DSR_RESET	=	1		; DSR reset supported
FDC_PMODE		=	1		; enable perpendicular mode for 2.88 drive/media
FDC_SPMODE		=	0		; disable standard pmode
FDC_NO_POLL		=	1		; disable drive POLL via CONFIGURE
;FDC_DBL_RECAL	=	0		; leave at default so build can work on all
	ENDIF

;----------------------------------------------------------------------------;
; NSC controller feature support (DP8473)
;
	IF FDC_TYPE EQ FDC_TYPE_NSC
FDC_FIFO		=	1		; FIFO
FDC_EIS		=	0		; Implied seek (incomplete)
FDC_DSR_RESET	=	1		; DSR reset supported
FDC_PMODE		=	0		; no perpendicular mode
FDC_SPMODE		=	0		; disable standard pmode (2.88 won't work with DP8473)
;FDC_NO_POLL		=	0		; disable drive POLL on CONFIGURE 
FDC_NO_POLL		=	1		; disable drive POLL on CONFIGURE
;FDC_SOFT_POLL	=	0
USE_NSC_MODE	=	1
FDC_DBL_RECAL	=	1		; always double recal (DP8473 only 77 pulses)
	ENDIF

;----------------------------------------------------------------------------;
; 86Box only works if 1 for 82077AA, only works if 0 for 765
;
;	IF FDC_MODEL EQ FDC_MODEL_86BOX
;FDC_NO_POLL		=	1		; disable drive POLL via CONFIGURE
;	ENDIF

;----------------------------------------------------------------------------;
; Reconfigure options based on PC platform
;----------------------------------------------------------------------------;
	IF ARCH_TYPE EQ ARCH_5160
;FAST_STEP_RATE	=	0		; use standard step rate on 4.77MHz 8088
AT_WAIT		=	0
IS_TURBO		= 	0		; use slower timings
;CMOS_TYPE_AT	=	0		; no reason to disable this
XT_V3_FIX		=	1		; workaround to V3 BDA overwrite bug
	ENDIF

	IF ARCH_TYPE EQ ARCH_TURBO
AT_WAIT		=	0
IS_TURBO		= 	1
	ENDIF

	IF ARCH_TYPE EQ ARCH_TD3300
AT_WAIT		=	0
AT_TEST_MID		=	0		; not AT BIOS
FDC_HLT_WAIT	=	0		; TD3300A fails if this enabled
IS_TURBO		= 	1
	ENDIF

	IF ARCH_TYPE EQ ARCH_AT		; AT, 286, 386 or above
AT_WAIT		=	1
AT_TEST_MID		=	1		; test for AT BIOS
CMOS_TYPE_AT	=	1
FDC_DSR_RESET	=	1		; TODO: shouldn't this be set by FDC?
FDC_HLT_WAIT	=	1		; since it's not a TD3300A
IS_TURBO		= 	1
CPU_TYPE		=	CPU_186	; only 286+
	ENDIF

;----------------------------------------------------------------------------;
; Final reconfigure based on all above options
;----------------------------------------------------------------------------;
	IF FDC_EIS EQ 1
FDC_ADV_SEEK	=	0		; not necessary with EIS
GLADISK_INT_1EH	=	1		; DOS is dumb
	ENDIF

	IF FDC_PMODE EQ 1
FIFO_DEPTH		=	FIFO_DEPTH_PMODE	; increase FIFO threshold for 2.88
	ENDIF

;----------------------------------------------------------------------------;
; Use to conditionally remove POST test display code
;
GB_UI		EQU	(SHOW_BANNER EQ 1) OR (SHOW_DRIVES EQ 1) OR (SHOW_FDC EQ 1)

;----------------------------------------------------------------------------;
; Enable 186 instructions if supported
;
	IF CPU_TYPE EQ CPU_V20 OR CPU_TYPE EQ CPU_186
.186
CHECK_BUILD_CPU	=	1		; validate CPU on V20/186 builds
	ENDIF

	IF CPU_TYPE EQ CPU_V20
AT_WAIT		=	0		; cannot have AT delay with V20
	ENDIF

	IF USE_FDC_DEBUG EQ 1
FDC_ZERO_BDA	=	1		; helps keep bytes clear for debug
	ENDIF

;FDC_MAX_DRIVES	=	4
;CMOS_TYPE_AT	=	0
;CMOS_TYPE_NS	=	1

INCLUDE GLALIB.INC
INCLUDE FDC.INC
INCLUDE SEGS.INC
INCLUDE MACROS.INC
INCLUDE INT_13.INC
INCLUDE CMOS.INC

;----------------------------------------------------------------------------;
; Final thoughts...
;
FDC_CONF_BYTE	= FDC_CCB <>				; default config byte
				IF FDC_FIFO EQ 1
FDC_CONF_BYTE	= FDC_CONF_BYTE OR FDC_CCB <,0,0,0,FIFO_DEPTH>	; set FIFO
				ENDIF
				IF FDC_EIS EQ 1
FDC_CONF_BYTE	= FDC_CONF_BYTE OR FDC_CCB <,1>	; enable implied seek
				ENDIF
				IF FDC_NO_POLL EQ 1
FDC_CONF_BYTE	= FDC_CONF_BYTE OR MASK FCPL		; disable POLL
				ENDIF

	IF FDC_MAX_DRIVES GT 4
.ERR
%OUT ERROR: Max 4 drives supported
	ENDIF
