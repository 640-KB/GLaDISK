	PAGE	 	59,132
	TITLE		GLaDISK FDC ACC3201

;----------------------------------------------------------------------------;
; GLaDISK (Gizmo Linkage and Dynamic Information Storage Keeper)
; Copyright (c) 2025, 640KB and contributors
;----------------------------------------------------------------------------;
INCLUDE	GLADISK.INC

;----------------------------------------------------------------------------;
; ACC drive type config port
;
ACC_CONF		EQU	FDC_C0		; 03F0H ACC config port

ACC_GEN		EQU	1			; Generic
ACC_UNIQUE		EQU	2			; UNIQUE-FDC

;----------------------------------------------------------------------------;
; Different ACC 3201 adapter manufacturers use different DIP/jumper encodings
; to select drive type. Config byte is inverted and bit-reversed as read.
;
ACC_TYPE		EQU	ACC_UNIQUE		; Select card model

			IF ACC_TYPE EQ ACC_GEN
; "Generic" / "80 Data" SUPER FDC settings:
; ON-ON=360, OFF-ON=1.2, ON-OFF=720, OFF-OFF=1.44
ACC_JP		EQU	< FDCM_360, FDCM_12, FDCM_720, FDCM_14 >
			ENDIF

			IF ACC_TYPE EQ ACC_UNIQUE
; UNIQUE-FDC settings:
; ON-OFF=360, ON-ON=720, OFF-OFF=1.2, OFF-ON=1.44
ACC_JP		EQU 	< FDCM_720, FDCM_360, FDCM_14, FDCM_12 >
			ENDIF

OPTROM	SEGMENT BYTE PUBLIC 'CODE'
		ASSUME  DS:OPTROM, SS:OPTROM, CS:OPTROM, ES:OPTROM

			IF SHOW_FDC AND (CMOS_TYPE_ACC EQ 1)
;----------------------------------------------------------------------------;
; POST banner display string
;
PUBLIC	S_CM_ACC
S_CM_ACC	DB	'ACC', SZ			; 'ACC' for POST display
			ENDIF

			IF CMOS_TYPE_ACC EQ 1
;----------------------------------------------------------------------------;
; ACC 3201 Config register (READ) at 3F0H
;----------------------------------------------------------------------------;
; 76543210
; 76      |		- ACCD3	Drive 3
;   54    |		- ACCD2	Drive 2
;     32  |		- ACCD1	Drive 1
;       10|		- ACCD0	Drive 0
;----------------------------------------------------------------------------;
ACCCFG RECORD	ACCD3:2,ACCD2:2,ACCD1:2,ACCD0:2

;----------------------------------------------------------------------------;
; Read ACC 3201 drive select jumper setting to set CMOS type
;----------------------------------------------------------------------------;
; Output:
;	AL = CMOS type byte drives 0/1
;	AH = CMOS type byte drives 2/3
; 	CF = success - always 0 since all possible values are valid
;	BP = near pointer to display string
;
; Clobbers: CX, DX
;----------------------------------------------------------------------------;
; 80-DATA/Generic Jumpers are encoded as standard CMOS order:
; JP	Type	Bit	Dec	CMOS	
; CC	360	00	0	1
; OC	1.2	01	1	2
; CO	720	10	2	3
; CC	1.44	11	3	4
;
; UNIQUE-FDC Jumpers are encoded as:
; JP	Type	Bit	Rev	Dec	CMOS	
; CO	360	10	01	1	1
; CC	720	00	00	0	3
; OO	1.2	11	11	3	2
; OC	1.44	01	10	2	4
;
; Examples:
; 3F0H		JPs		CMOS Drive types
;	4 3 2 1	1 2 3 4	A B C D
; FD	11111101	OCOOOOOO	4 2 2 2	1.4 1.2 1.2 1.2
; 72	01110010	COCCOOOC	1 3 2 4	360 720 1.2 1.4
; 4E	01001110	COOOCCOC	1 2 3 4	360 1.2 720 1.4
; DD	11011101	OCOOOCOO	4 2 4 2	1.4 1.2 1.4 1.2
;----------------------------------------------------------------------------;
CMOS_ACC_TBL	LABEL BYTE
			IRP	D, < %ACC_JP >
		DB	D
			ENDM

PUBLIC SETUP_CMOS_ACC
			ASSUME DS:_BDA_ABS
SETUP_CMOS_ACC PROC
	PUSH	SI
	PUSH	BX				; preserve working registers
	MOV	BX, OFFSET CMOS_ACC_TBL	; BX = CMOS type table
	MOV	DX, ACC_CONF		; ACC DIP switch I/O port
	IN	AL, DX			; read from FDC conf reg
	XCHG	AX, DX			; DL = input byte
	MOV	CX, DBW <4, 4>		; drive and shift counters
DRV_LOOP:
	XOR	AX, AX			; clear AX
		REPT 2
	RCR	DL, 1				; shift next two drive bits to AL
	RCL	AL, 1				;  and reverse bit order
		ENDM
	XLAT	CS:[BX]			; AL = CMOS drive type from table
	SHL	SI, CL			; shift result left by nibble
	OR	SI, AX			; save CMOS nibble to SI, clear CF
	DEC	CH				; dec drive loop counter
	JNZ	DRV_LOOP
	XCHG	AX, SI			; result in AX
	XCHG	AH, AL			; AH = drives 2/3, AL = drives 0/1
	POP	BX
	POP	SI
			IF SHOW_FDC EQ 1
	MOV	BP, OFFSET S_CM_ACC
			ENDIF
	RET
SETUP_CMOS_ACC ENDP
			ASSUME DS:NOTHING
			ENDIF

OPTROM	ENDS
		END