	PAGE	 	59,132
	TITLE		GLaDISK FDC C810

;----------------------------------------------------------------------------;
; GLaDISK (Gizmo Linkage and Dynamic Information Storage Keeper)
; Copyright (c) 2024-25, 640KB and contributors
;----------------------------------------------------------------------------;
INCLUDE	GLADISK.INC

;----------------------------------------------------------------------------;
; CompuAdd C810
;
C810_CONF		EQU	FDC_IN		; 03F7H SW1 DIR port

OPTROM	SEGMENT BYTE PUBLIC 'CODE'
		ASSUME  DS:OPTROM, SS:OPTROM, CS:OPTROM, ES:OPTROM

			IF SHOW_FDC AND (CMOS_TYPE_CA EQ 1)
;----------------------------------------------------------------------------;
; POST banner display string
;
PUBLIC	S_CM_CA
S_CM_CA	DB	'C810', SZ			; 'C810' for POST display
			ENDIF

			IF CMOS_TYPE_CA EQ 1
;----------------------------------------------------------------------------;
; CompuAdd 810 FDC Digital Input Register (READ) at 3F7H (WD37C65C)
;----------------------------------------------------------------------------;
; 84218421
; 7	    |		- CAFDCHG	diskette change
;  654    |		- CAFDTBD	TBD
;     32  |		- CASW1B	SW1 3,4	Drive B config
;       10|		- CASW1A	SW1 1,2 	Drive A config
;----------------------------------------------------------------------------;
FDC_DI_C810 RECORD	CAFDCHG:1, CAFDTBD:3, CASW1B:2, CASW1A:2

;----------------------------------------------------------------------------;
; Read drive select DIP SW1 setting to set CMOS type
;----------------------------------------------------------------------------;
; Output:
;	AL = CMOS type byte drives 0/1
; 	CF = success - always 0 since all possible values are valid
;
; Clobbers: AH, DX
;----------------------------------------------------------------------------;
; ON-ON=360, ON-OFF=720, OFF-ON=1.2, OFF-OFF=1.44
;
; SW	Type	Bit	Dec	CMOS
; 11	360	00	0	1
; 10	1.2	01	1	2
; 01	720	10	2	3
; 00	1.44	11	3	4
;----------------------------------------------------------------------------;
PUBLIC SETUP_CMOS_CA
			ASSUME DS:_BDA_ABS
SETUP_CMOS_CA PROC
	MOV	DX, C810_CONF		; C810 DIP switch DIR port
	IN	AL, DX			; read from FDC conf reg
	AND	AX, MASK CASW1B OR MASK CASW1A	; isolate drive bits
	ROR	AX, 1				; drive B to low nibble of low byte
	ROR	AX, 1
	SHR	AH, 1				; drive A to high nibble of high byte
	SHR	AH, 1
	OR	AL, AH			; combine nibbles
	ADD	AL, 11H			; increment both nibbles
			IF SHOW_FDC EQ 1
	MOV	BP, OFFSET S_CM_CA
			ENDIF
	RET
SETUP_CMOS_CA ENDP
			ASSUME DS:NOTHING
			ENDIF

OPTROM	ENDS
		END