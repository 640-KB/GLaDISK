	PAGE	 	59,132
	TITLE		GLaDISK FDC LSI

;----------------------------------------------------------------------------;
; GLaDISK (Gizmo Linkage and Dynamic Information Storage Keeper)
; Copyright (c) 2024-2025, 640KB and contributors
;----------------------------------------------------------------------------;
INCLUDE	GLADISK.INC

;----------------------------------------------------------------------------;
; LSI config ports
;
LS1_CONF		EQU	FDC_C0+1		; 03F1H LSI v1 config port
LS2_CONF		EQU	FDC_C0		; 03F0H LSI v2 config port

OPTROM	SEGMENT BYTE PUBLIC 'CODE'
		ASSUME  DS:OPTROM, SS:OPTROM, CS:OPTROM, ES:OPTROM

			IF SHOW_FDC AND (CMOS_TYPE_LSI1 EQ 1 OR CMOS_TYPE_LSI2 EQ 1)
;----------------------------------------------------------------------------;
; POST banner display string
;
PUBLIC	S_CM_LSI
S_CM_LSI	DB	'LSI', SZ
			ENDIF

			IF CMOS_TYPE_LSI1 EQ 1
;----------------------------------------------------------------------------;
; LSI LCS-6610F-U (U3) Config register (READ) at 3F1H
;----------------------------------------------------------------------------;
; 76543210
; 010     |			- LS1F	Config fingerprint (always 010)?
;    x    |			- LS1J6	J6 (1=open, 0=closed)
;     x   |			- LS1X1	reserved
;      x  |			- LS1J7	J7 (1=open, 0=closed)
;       x |			- LS1J9	J9 (1=open, 0=closed)
;        x|			- LS1J8	J8 (1=open, 0=closed)
;----------------------------------------------------------------------------;
LS1CFG RECORD	LS1F:3=010B,LS1J6:1,LS1X1:1=0,LS1J7:1,LS1J9:1,LS1J8:1

;----------------------------------------------------------------------------;
; Read LSI LCS-6610F-U JP/DIP setting switches and set CMOS type
;----------------------------------------------------------------------------;
; Output:
;	AL = CMOS type byte
;
; Clobbers AH, CX
;----------------------------------------------------------------------------;
;
; 3F1H		JPs	Drive types
;    6   798	6789	A	B
;010 0 0 111 47H	COOO	1.2	1.44
;010 0 0 110 46H	COCO	1.2	1.2
;010 1 0 110 56H	OOCO	1.44	1.2
;010 1 0 001 51H	OCOC	720	720
;010 1 0 101 55H	OOOC	1.44	720
;010 0 0 000 40H	CCCC	360	360
;
;----------------------------------------------------------------------------;
			ASSUME DS:_BDA_ABS
PUBLIC SETUP_CMOS_LSI1
SETUP_CMOS_LSI1 PROC

;----------------------------------------------------------------------------;
; Get config DIP switch value
;
	PUSH	DX
	MOV	DX, LS1_CONF		; LSI config register
	IN	AL, DX
	POP	DX
	MOV	AH, AL			; save
	AND	AL, MASK LS1F		; isolate "fingerprint"
	CMP	AL, LS1CFG <>		; valid read?
	STC					; CF = 1
	JNE	SETUP_CMOS_LSI1_DONE	; read invalid

;----------------------------------------------------------------------------;
; Decode drive 0
;
	MOV	AL, AH
	AND	AL, MASK LS1J6 OR MASK LS1J7	; read drive 0
	MOV	CL, 3
	SHR	AL, CL			; shift J6 to bit 1, CF = J7
	ADC	AL, 1				; type = 2*J6 + J7 + 1
	INC	CX				; CL = 4
	SHL	AL, CL			; move to high nibble
	MOV	CH, AL			; save

;----------------------------------------------------------------------------;
; Decode drive 1
;
	AND	AX, DBW < MASK LS1J8 OR MASK LS1J9, 0 >
	ROR	AX, 1				; AL bit 7 = J8, AH bit 0 = J9
	ROL	AL, 1				; AL bit 1 = J8
	ROL	AL, 1
	OR	AL, AH			; combine bits
	INC	AX				; AL = CMOS type
	OR	AL, CH			; combine drives, CF = 0
			IF SHOW_FDC EQ 1
	MOV	BP, OFFSET S_CM_LSI	; 'LSI' CMOS type string
			ENDIF
SETUP_CMOS_LSI1_DONE:
	RET
SETUP_CMOS_LSI1 ENDP
			ASSUME DS:NOTHING
			ENDIF

			IF CMOS_TYPE_LSI2 EQ 1
;----------------------------------------------------------------------------;
; LSI LCS-6812F Config register (READ) at 3F0H
;----------------------------------------------------------------------------;
; 76543210
; 76      |		- LS2D3	Drive 3 (4) 00=1.44, 01=720, 10=1.2, 11=360
;   54    |		- LS2D2	Drive 2 (3)
;     32  |		- LS2D1	Drive 1 (B)
;       10|		- LS2D0	Drive 0 (A)
;----------------------------------------------------------------------------;
LS2CFG RECORD	LS2D3:2,LS2D2:2,LS2D1:2,LS2D0:2

;----------------------------------------------------------------------------;
; Read LCS-6812F JP/DIP setting switches and set CMOS type
;----------------------------------------------------------------------------;
; Output:
;	AL = CMOS type byte drives 0/1
;	AH = CMOS type byte drives 2/3
; 	CF = success - always 0 since all possible values are valid
;
; Clobbers: CX, DX
;----------------------------------------------------------------------------;
; Jumpers are encoded bit-reversed. Examples:
;
; 3F0H		JPs		Drive types
;			A B C D	A B C D
; F3	11110011	OOCCOOOO	4 1 4 4
; 72	01110010	COCCOOOC	2 1 4 3
; 60	01100000	CCCCCOOC	1 1 2 3
;
; JP	Type	CMOS
; OO	1.44	4
; OC	720	3
; CO	1.2	2
; CC	360	1
;----------------------------------------------------------------------------;
			ASSUME DS:_BDA_ABS
PUBLIC SETUP_CMOS_LSI2
SETUP_CMOS_LSI2 PROC
	MOV	DX, LS2_CONF
	IN	AL, DX			; read from FDC conf reg
	XCHG	AX, DX			; DL = input byte
	MOV	CL, 4				; number of drives
DRV_LOOP:
	SHL	AX, 1				; space two bits between drive nibbles
	SHL	AX, 1
	MOV	CH, 2				; number of bits per drive
BIT_LOOP:
	SHR	DL, 1				; move and reverse two drive type bits
	RCL	AX, 1
	DEC	CH				; dec bit move counter
	JNZ	BIT_LOOP			; repeat shift for drive
	INC	AX				; convert to 1-based CMOS types
	LOOP	DRV_LOOP
	XCHG	AL, AH			; AL = drive 0/1, AH = drive 2/3
	CLC					; all values are valid
			IF SHOW_FDC EQ 1
	MOV	BP, OFFSET S_CM_LSI	; 'LSI' CMOS type string
			ENDIF
	RET
SETUP_CMOS_LSI2 ENDP
			ASSUME DS:NOTHING
			ENDIF

OPTROM	ENDS
		END