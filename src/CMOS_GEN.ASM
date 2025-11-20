	PAGE	 	59,132
	TITLE		GLaDISK FDC Generic

;----------------------------------------------------------------------------;
; GLaDISK (Gizmo Linkage and Dynamic Information Storage Keeper)
; Copyright (c) 2024-2025, 640KB and contributors
;----------------------------------------------------------------------------;
INCLUDE	GLADISK.INC

OPTROM	SEGMENT BYTE PUBLIC 'CODE'
		ASSUME  DS:OPTROM, SS:OPTROM, CS:OPTROM, ES:OPTROM

;----------------------------------------------------------------------------;
; Generic or uncommon FDC types are located here
;----------------------------------------------------------------------------;

		IF CMOS_TYPE_PE510 EQ 1
;----------------------------------------------------------------------------;
; PE-510B FDC type
;----------------------------------------------------------------------------;
PE510_CONF	EQU	370H				; drive select DIP SW1 I/O port
			IF SHOW_FDC EQ 1
S_CM_PE510	DB	'PE-510', SZ
			ENDIF

;----------------------------------------------------------------------------;
; PE-510 Config register (READ) at 370H switch SW1
;----------------------------------------------------------------------------;
; 76543210
; 4 drive model PE-510C: (not implemented)
; xx      |			- P5D2	drive 2 (00=1.44, 01=1.2, 10=720, 11=360)
;   xx    |			- P5D3	drive 3 (00=1.44, 01=1.2, 10=720, 11=360)
; 2 drive model PE-510B:
; 1111    |			- P5X1	always 0FH
;     xx  |			- P5D0	drive 0 (00=1.44, 01=1.2, 10=720, 11=360)
;       xx|			- P5D1	drive 1 (00=1.44, 01=1.2, 10=720, 11=360)
;----------------------------------------------------------------------------;
PE510_CFG RECORD	P5X1:4=0FH, P5D0:2, P5D1:2

;----------------------------------------------------------------------------;
; Read drive select SW1 on PE-510B card
;----------------------------------------------------------------------------;
; Input:
;	DS = BDA_ABS (0000)
; Output:
;	AL = CMOS type byte
;	BP = display string
;	always NC
;
; Clobbers: AH, DX
;----------------------------------------------------------------------------;
; Switches are labeled as UP/DOWN, read from low nibble of 370H.
; A: bits 1-0, B: bits 2-3.
;
; 		SW1 	370H	CMOS type
; 360		UU	00	1
; 1.2		DU	01	2
; 720		UD	10	3
; 1.44	DD	11 	4
;----------------------------------------------------------------------------;
			ASSUME DS:_BDA_ABS
PUBLIC SETUP_CMOS_PE510
SETUP_CMOS_PE510	PROC
	MOV	DX, PE510_CONF			; drive select DIP SW1
	IN	AL, DX

;----------------------------------------------------------------------------;
; Swap drive numbers as read from SW1
;
	AND	AX, MASK P5D0 OR MASK P5D1	; isolate drive bits
	ROR	AX, 1					; roll drive 0 into high bits of AH
	ROR	AX, 1
	SHR	AH, 1					; shift drive 0 into high nibble
	SHR	AH, 1
	OR	AL, AH				; combine nibbles
	ADD	AL, 11H				; increment to CMOS 1-based types
			IF SHOW_FDC EQ 1
	MOV	BP, OFFSET S_CM_PE510
			ENDIF
	RET
SETUP_CMOS_PE510 ENDP
			ASSUME DS:NOTHING
		ENDIF	; IF CMOS_TYPE_PE510 EQ 1

		IF CMOS_TYPE_MT883 EQ 1
;----------------------------------------------------------------------------;
; Mysterious MT883 board
;----------------------------------------------------------------------------;
; https://www.vogons.org/viewtopic.php?t=66239
;----------------------------------------------------------------------------;
MT_CONF	EQU	01EFH				; MT883 JP register port
			IF SHOW_FDC EQ 1
PUBLIC	SETUP_CMOS_MT
S_CM_MT883	DB	'MT883', SZ
			ENDIF

;----------------------------------------------------------------------------;
; Read MT883 drive switches
;----------------------------------------------------------------------------;
; Input:
;	DS = BDA_ABS (0000)
; Output:
;	AL = CMOS type byte
;	BP = display string
;	always NC
;----------------------------------------------------------------------------;
			ASSUME DS:_BDA_ABS
SETUP_CMOS_MT PROC
	MOV	DX, MT_CONF
	IN	AL, DX
	AND	AL, 01111B				; mask low four bits
	ROR	AX, 1					; AL bits 0-1 to AX bits 14-15
	ROR	AX, 1					; AL bits 2-3 to AL bits 0-1
	ROR	AH, 1					; AL bits 0-1 to high AX nibble
	ROR	AH, 1
	AND	AX, DNW < 0111B, , , 0111B >	; isolate high and low nibbles
	OR	AL, AH				; combine nibbles
	ADD	AL, 11H				; convert to CMOS types
			IF SHOW_FDC EQ 1
	MOV	BP, OFFSET S_CM_MT883
			ENDIF
	RET
SETUP_CMOS_MT ENDP
			ASSUME DS:NOTHING
		ENDIF	; /IF CMOS_TYPE_MT883 EQ 1

OPTROM	ENDS
		END