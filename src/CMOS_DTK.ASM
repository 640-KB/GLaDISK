	PAGE	 	59,132
	TITLE		GLaDISK FDC DTK

;----------------------------------------------------------------------------;
; GLaDISK (Gizmo Linkage and Dynamic Information Storage Keeper)
; Copyright (c) 2024-2025, 640KB and contributors
;----------------------------------------------------------------------------;
INCLUDE	GLADISK.INC

OPTROM	SEGMENT BYTE PUBLIC 'CODE'
		ASSUME  DS:OPTROM, SS:OPTROM, CS:OPTROM, ES:OPTROM

			IF CMOS_TYPE_DTK1 EQ 1
;----------------------------------------------------------------------------;
; Setup for DTK PII-151B MINI-MICRO-2 FDC CARD (DP8473)
;----------------------------------------------------------------------------;
DTK_CONF	EQU	FDC_C0		; 03F0H DTK config port

;----------------------------------------------------------------------------;
; DTK Config register (READ) at 350H switch JP3
;----------------------------------------------------------------------------;
; 76543210
; 11      |			- DTKX1	always 11
;   xx    |			- DTKD0	drive 0 (11=1.44, 10=1.2, 01=720, 00=360)
;     xx  |			- DTKD1	drive 1 (11=1.44, 10=1.2, 01=720, 00=360)
;       11|			- DTKX2	always 11
;----------------------------------------------------------------------------;
DTK1CFG RECORD	DTKX1:2=11B,DTKD0:2,DTKD1:2,DTKX2:2=11B

PUBLIC	SETUP_CMOS_DTK1

			IF USE_FDC_DEBUG EQ 1
EXTRN		FDC_DEBUG:NEAR
			ENDIF

			IF SHOW_FDC EQ 1
;----------------------------------------------------------------------------;
; POST banner display string
;
PUBLIC	S_CM_DTK1
S_CM_DTK1	DB	'DTK', SZ
			ENDIF

;----------------------------------------------------------------------------;
; Read DTK JP/DIP setting switches and set CMOS type
;----------------------------------------------------------------------------;
; Input:
;	DS = BDA_ABS (0000)
; Output:
;	AL = CMOS type byte
;	CF if not valid (NC doesn't necessarily mean valid though)
;
; Clobbers: AH
;----------------------------------------------------------------------------;
; 		JP3 	3F0H	CMOS type
; 1.44	OO	11 	4
; 1.2		OC	10	2
; 720		CO	01	3
; 360		CC	00	1
;
; NOTE: jumper settings on card silkscreen appear to be backwards:
; "0" means closed jumper, "1" means open
; https://stason.org/TULARC/pc/io-cards/C-D/DTK-COMPUTER-INC-Floppy-drive-controller-PII-151B.html
;----------------------------------------------------------------------------;
			ASSUME DS:_BDA_ABS
SETUP_CMOS_DTK1 PROC

;----------------------------------------------------------------------------;
; Get config DIP switch value
;
	PUSH	DX
	MOV	DX, DTK_CONF			; DTK config register
	IN	AL, DX
	POP	DX

;----------------------------------------------------------------------------;
; Decode jumper settings
;
	MOV	AH, AL				; save AL
	AND	AL, MASK DTKX1 OR MASK DTKX2	; isolate "fingerprint"
	CMP	AL, DTK1CFG <>			; valid read?
	STC						; presume failure
	JNE	SETUP_CMOS_DTK1_DONE
	MOV	AL, AH				; restore AL

;----------------------------------------------------------------------------;
; Convert DTK numbering to standard CMOS values - 720 and 1.2 are reversed
;
	AND	AL, MASK DTKD1			; check drive 1 bits
	JPE	D1_DONE				; jump if 0 or 3
	XOR	AL, MASK DTKD1			; swap types 1-2
D1_DONE:
	AND	AH, MASK DTKD0			; check drive 0 bits
	JPE	D0_DONE				; jump if 0 or 3
	XOR	AH, MASK DTKD0			; swap types 1-2
D0_DONE:
		REPT DTKD1
	SHR	AL, 1					; move drive 1 to low nibble of AL
		ENDM
	OR	AL, AH				; combine drives
	ADD	AL, 11H				; increment to CMOS 1-based types
			IF SHOW_FDC EQ 1
	MOV	BP, OFFSET S_CM_DTK1
			ENDIF
SETUP_CMOS_DTK1_DONE:
	RET
SETUP_CMOS_DTK1 ENDP
			ASSUME DS:NOTHING
		ENDIF					; /IF CMOS_TYPE_DTK1 EQ 1

OPTROM	ENDS
		END