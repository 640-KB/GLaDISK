;----------------------------------------------------------------------------;
; GLaDISK (Gizmo Linkage and Dynamic Information Storage Keeper)
;
; It's floppy but good.
;
; Copyright (c) 2022-2025, 640KB and contributors
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; EQUATES USED BY CONFIG FILE
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; FDC types
;
FDC_TYPE_DD		EQU	0		; standard uPD765/8272 (no HD support)
FDC_TYPE_HD1	EQU	1		; HD1: Generic Basic HD
FDC_TYPE_HD2	EQU	2		; HD2: 
FDC_TYPE_HD3	EQU	3		; HD3: 
FDC_TYPE_HD4	EQU	4		; HD4: 
FDC_TYPE_NSC	EQU	5		; NSC DP8473

FDC_TYPE_HD		EQU	FDC_TYPE_HD1	; HD1: Generic Basic HD1
FDC_TYPE_ADV	EQU	FDC_TYPE_HD4	; HD4: PC8477B "SuperFDC", 
							;  82077AA FIFO+Implied seek

;----------------------------------------------------------------------------;
; Adapter model types
;
FDC_MODEL_HD	EQU	'1'		; Basic HD controller (FDC_TYPE_HD1)
FDC_MODEL_ADV	EQU	'2'		; Advanced HD controller (FDC_TYPE_HD4)
FDC_MODEL_PS2	EQU	'3'		; PS/2 specific HD, excl. PS/2 30
FDC_MODEL_PS2_30	EQU	'4'		; PS/2 Model 30
FDC_MODEL_DTK	EQU	'5'		; PII-151B (DP8473)
FDC_MODEL_LSI1	EQU	'6'		; LCS6610F-U (U3) / Jameco JE1043 (D,E)
FDC_MODEL_LSI2	EQU	'7'		; LCS-6812F/6814F Rev A2
FDC_MODEL_5170	EQU	'8'		; 765 + WD16C92A (5170 compatible/combo card)
FDC_MODEL_ACC	EQU	'9'		; ACC 3201
FDC_MODEL_CA	EQU	'A'		; CompuAdd 810
FDC_MODEL_86BOX	EQU	'B'		; 86Box
FDC_MODEL_PE510	EQU	'C'		; PE-510
FDC_MODEL_NUXT	EQU	'D'		; NuXT (PC8477) with port 70H w/AT RTC
FDC_MODEL_CUST	EQU	'Z'		; Custom
FDC_MODEL	=	FDC_MODEL_CUST	; default

;----------------------------------------------------------------------------;
; CPU Architecture Instruction types
;
CPU_8088		EQU	'8'			; 808x compatible
CPU_V20		EQU	'V'			; V20 only
CPU_186		EQU	'2'			; 186/286+

;----------------------------------------------------------------------------;
; Build Target Architecture equates
;
ARCH_5150		EQU	'P'			; 5150
ARCH_5160		EQU	'X'			; 5160 v1
ARCH_TURBO		EQU	'T'			; Standard Turbo or clone
ARCH_TD3300		EQU	'S'			; TD3300A
ARCH_FE2010		EQU	'F'			; FE2010A
ARCH_EMU		EQU	'E'			; Emulator
ARCH_AT		EQU	'A'			; AT, 386 +

;----------------------------------------------------------------------------;
; CMOS Drive Types
;----------------------------------------------------------------------------;
; https://wiki.osdev.org/CMOS#Accessing_CMOS_Registers
; https://bochs.sourceforge.io/techspec/CMOS-reference.txt
;
FDCM_NONE		EQU	0			; drive not installed
FDCM_360		EQU	1			; 360K DD
FDCM_12		EQU	2			; 1.2M HD
FDCM_720		EQU	3			; 720K DD
FDCM_14		EQU	4			; 1.44M HD
FDCM_28A		EQU	5			; 2.88 HD
FDCM_28B		EQU	6			; 2.88 HD ALT (Phoenix)
FDCM_8		EQU	7			; 8"
FDCM_28		EQU	FDCM_28A		; Use standard CMOS type

FDCM_MAX		EQU	FDCM_28		; highest valid drive type

;----------------------------------------------------------------------------;
; CMOS configuration type defaults
; multiple may be enabled
;
CMOS_TYPE_AT	=	0		; use port 70 AT/CMOS values
CMOS_TYPE_NS	=	0		; use NS RTC
CMOS_TYPE_LSI1	=	0		; LCS6610F-U JP6-9/DIP switches
CMOS_TYPE_LSI2	=	0		; LCS-6812F
CMOS_TYPE_DTK1	=	0		; DTK PII-151B JP3 jumpers
CMOS_TYPE_MT883	= 	0		; mysterious "MT883" board
CMOS_TYPE_PE510	= 	0		; FDC PE-510B
CMOS_TYPE_ACC	=	0		; ACC 3201
CMOS_TYPE_CA	=	0		; CompuAdd 810
CMOS_TYPE_NONE	=	1		; drive types hard coded in ROM image

;----------------------------------------------------------------------------;
; Other defaults
;
;FDC_EIS		=	0			; Implied seek disabled
;FDC_FIFO		=	1			; FIFO enabled

