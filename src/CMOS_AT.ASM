	PAGE	 	59,132
	TITLE		GLaDISK CMOS AT

;----------------------------------------------------------------------------;
; GLaDISK (Gizmo Linkage and Dynamic Information Storage Keeper)
; Copyright (c) 2024-2025, 640KB and contributors
;----------------------------------------------------------------------------;
INCLUDE	GLADISK.INC

VERIFY_CHECKSUM		EQU	1		; verify CMOS checksum
VERIFY_SET_CHECKSUM_BIT	EQU	0		; update checksum status bit

;----------------------------------------------------------------------------;
; Supported I/O address ports for AT CMOS, MC146818, DS12x85
;
				IF ARCH_TYPE EQ ARCH_AT
CMOS_IO_PORTS	EQU	< 70H >		; AT should only be 70H
				ELSE
					IF FDC_MODEL EQ FDC_MODEL_NUXT
CMOS_IO_PORTS	EQU	< 70H, 240H, 2C0H > ; 70H is default port on NuXT
					ELSE
CMOS_IO_PORTS	EQU	< 240H, 2C0H >	; don't probe port 70H on XTs
					ENDIF
				ENDIF

OPTROM	SEGMENT BYTE PUBLIC 'CODE'
		ASSUME  DS:OPTROM, SS:OPTROM, CS:OPTROM, ES:OPTROM

			IF CMOS_TYPE_AT EQ 1

			IF USE_FDC_DEBUG EQ 1
EXTRN		FDC_DEBUG:NEAR
			ENDIF

PUBLIC	SETUP_CMOS_AT, READ_CMOS_AT

			IF SHOW_FDC EQ 1
;----------------------------------------------------------------------------;
; POST banner display string
;
PUBLIC	S_CM_AT
S_CM_AT	DB	'AT', SZ		; 'AT'
			ENDIF

;----------------------------------------------------------------------------;
; Supported ports
;
CMOS_PORTS	LABEL  WORD
			IRP	P, < %CMOS_IO_PORTS >
		DW	P
			ENDM
CMOS_PORT_L	EQU	($-CMOS_PORTS)/2

;----------------------------------------------------------------------------;
; Read Drive types from AT CMOS/NVRAM at POST option ROM init
; PUBLIC
;----------------------------------------------------------------------------;
; Input:
;	None
; Output:
;	AL = CMOS drive types for drive 0 and 1 (high/low nibbles)
;	AH = number of drives installed (0 based) (necessary?)
;	CF if CMOS error
;	ZF if no drives installed
;----------------------------------------------------------------------------;
		ASSUME DS:_BDA
SETUP_CMOS_AT PROC
	PUSH	DS				; set DS = BDA
	PUSH	DX
	MOV	DX, SEG _BDA
	MOV	DS, DX

;----------------------------------------------------------------------------;
; Check if CMOS/RTC already installed?
; Do not exit so that this may replace a previous one
;
	;MOV	AX, CMOS_DATA		; get CMOS
	;AND	AH, NOT HIGH MASK RTTYPE
	;JZ	SETUP_CMOS_AT_DONE	; another already installed

;----------------------------------------------------------------------------;
; Detect CMOS/RTC on all supported I/O ports
;
	CALL	AT_DETECT			; ZF, DX = port if found, NZ if not
	JNZ	SETUP_CMOS_ERR		; no CMOS

;----------------------------------------------------------------------------;
; Check that CMOS is valid
;
		IF VERIFY_CHECKSUM EQ 1
	CALL	CMOS_CHECKSUM_VERIFY	; verify checksum and reset diag byte
	JE	CHKSUM_OK
CHKSUM_OK:
		ENDIF
	;JNE	_ERR				; jump if error (necessary?)

	MOV	AL, CM_DIAG			; diagnostic byte (0EH)
	CALL	READ_CMOS_AT

;----------------------------------------------------------------------------;
; Check CMOS valid bits: RTC power not lost, checksum okay, POST config/clock OK
; Clear AH
;
	;AND	AX, MASK CD_RTC_OK OR MASK CD_CHK_OK OR MASK CD_PC_OK OR MASK CD_TM_OK
	AND	AX, MASK CD_RTC_OK OR MASK CD_CHK_OK OR MASK CD_PC_OK
	STC					; presume failure
	JNZ	SETUP_CMOS_ERR		; exit with CF if CMOS invalid

;----------------------------------------------------------------------------;
; Working CMOS found. Set in BDA.
;
	SET_GFLAG	ATCMOS		; set AT CMOS working flag

	MOV	AX, DX			; AX = port number
	OR	AH, HIGH RTC_DAT < RTC_AT >	; set AT CMOS flag
	MOV	CMOS_DATA, AX		; save to BDA
	MOV	BP, OFFSET S_CM_AT

;----------------------------------------------------------------------------;
; Get number of drives installed
;
	MOV	AL, CM_EQ			; Installed Equipment (14H)
	CALL	READ_CMOS_AT
	TEST	AL, MASK IPL		; 0 drives installed?
	JZ	SETUP_CMOS_AT_DONE
	AND	AL, MASK FLP		; isolate floppy bits
	ROL	AL, 1				; move to low bits
	ROL	AL, 1
	MOV	AH, AL			; AH = # of drives (0 based)

;----------------------------------------------------------------------------;
; Get drive type byte
;
	MOV	AL, CM_FD			; Diskette drive types (10H)
	CALL	READ_CMOS_AT
	AND	AL, MASK FDT0 OR MASK FDT1 ; ZF if no drives installed, CF = 0

SETUP_CMOS_AT_DONE:
	POP	DX
	POP	DS
	RET

SETUP_CMOS_ERR:
	CLR_GFLAG	ATCMOS		; flag CMOS not working
	STC
	JMP	SHORT SETUP_CMOS_AT_DONE
SETUP_CMOS_AT ENDP
		ASSUME DS:OPTROM

;----------------------------------------------------------------------------;
; Detect AT RTC
;----------------------------------------------------------------------------;
; Output:
;	ZF if found, NZ if not
;	DX = port for RTC
;	AL = RTC type (RTC_AT)
;
; Clobbers: AH, SI
;
; TODO: may incorrectly detect a 58187 on same port. Need another check.
;----------------------------------------------------------------------------;
AT_DETECT PROC
	PUSHF						; save IF, DF (necessary?)
	PUSH	CX
	MOV	SI, OFFSET CMOS_PORTS
	MOV	CX, CMOS_PORT_L
	CLD						; string direction forward
	CLI						; interrupts off
AT_DETECT_LOOP:
	LODS	WORD PTR CS:[SI]			; AX = next port to check
	XCHG	AX, DX				; DX = next port

;----------------------------------------------------------------------------;
; DS Wait for no Update In Progress (UIP)
;
AT_WAIT_FOR_UIP:
	PUSH	CX					; save outer loop counter
	MOV	CH, HIGH 1024			; timeout ~ 250us ?
AT_UIP_LOOP:
	STI
	MOV	AL, CM_RTC_A			; RTC Status Register A
	CLI
	CALL	READ_CMOS_AT
	TEST	AL, MASK UIP			; check UIP bit
	LOOPNZ AT_UIP_LOOP			; loop until no UIP or timeout
	POP	CX					; restore outer loop
	JNZ	AT_DETECT_NEXT			; CMOS not working if UIP flag never clear

;----------------------------------------------------------------------------;
; Test read/write on Register A
;
	MOV	AX, DBW < CM_REG_A <>, CM_RTC_A > ; AH = defaults, AL = Register A
	CALL	WRITE_CMOS_AT			; write AH to register AL
	CALL	READ_CMOS_AT			; AL = read back value
	CMP	AL, CM_REG_A <>			; ZF if same (success), NZ if not
AT_DETECT_NEXT:
	LOOPNZ AT_DETECT_LOOP
	JNZ	AT_DETECT_EXIT			; NZ if none detected
	MOV	AL, RTC_AT				; RTC type
AT_DETECT_EXIT:
	POP	CX
	LAHF						; save status flags
	POPF						; restore IF
	SAHF						; restore status flags
	RET
AT_DETECT ENDP

;----------------------------------------------------------------------------;
; Read WORD from AT CMOS
;----------------------------------------------------------------------------;
; Input:
;	AL = register index
;	DX = register address port
; Output:
;	AX = register value
;----------------------------------------------------------------------------;
READ_CMOS_AT_WORD PROC
	MOV	AH, AL				; save index register
	CALL	READ_CMOS_AT
	XCHG	AL, AH				; restore index, AH = high data
	INC	AX

;----------------------------------------------------------------------------;
; Read from AT CMOS
;----------------------------------------------------------------------------;
; Input:
;	AL = register index
;	DX = I/O port base
; Output:
;	AL = register value
;----------------------------------------------------------------------------;
READ_CMOS_AT PROC
	PUSHF						; save IF
	CLI						; disable interrupts for read
	OUT	DX, AL
	IO_DELAY_SHORT				; wait for bus to clear
	IO_DELAY_SHORT
	INC	DX
	IN	AL, DX
	DEC	DX
	POPF						; restore IF
READ_CMOS_AT_EXIT:
	RET
READ_CMOS_AT ENDP
READ_CMOS_AT_WORD ENDP

;----------------------------------------------------------------------------;
; Write WORD to AT CMOS
;----------------------------------------------------------------------------;
; Input:
;	AL = register index
;	BX = register value (little endian WORD)
; Output:
;	None
; Clobbers AH
; Flags preserved
;----------------------------------------------------------------------------;
WRITE_CMOS_AT_WORD PROC
	PUSH	AX					; save index register
	MOV	AH, BH				; low byte data
	CALL	WRITE_CMOS_AT
	POP	AX					; restore index
	LAHF						; preserve flags
	INC	AX					; high byte index
	SAHF
	MOV	AH, BL

;----------------------------------------------------------------------------;
; Write to AT CMOS
;----------------------------------------------------------------------------;
; Input:
;	AL = register index
;	AH = register value
;	DX = I/O port base
; Output:
;	AL/AH = register value
;----------------------------------------------------------------------------;
WRITE_CMOS_AT PROC
	PUSHF						; save IF
	CLI						; disable interrupts for write
	OUT	DX, AL				; write register index
	IO_DELAY_SHORT
	IO_DELAY_SHORT
	;ISA_CLEAR					; clear ISA bus (clobbers AL)
	INC	DX					; data port
	XCHG	AL, AH				; AL = value, AH = index
	OUT	DX, AL				; write data
	XCHG	AL, AH				; AL = index, AH = value
	DEC	DX					; index port
	POPF						; restore IF
	RET
WRITE_CMOS_AT ENDP
WRITE_CMOS_AT_WORD ENDP

			IF VERIFY_CHECKSUM EQ 1
;----------------------------------------------------------------------------;
; Calculate and verify CMOS checksum WORD and set invalid bit accordingly
;----------------------------------------------------------------------------;
; Input:
;	DX = CMOS port
; Output:
;	ZF = checksum okay
;	NZ = checksum incorrect
;	BX = calculated checksum
;----------------------------------------------------------------------------;
CMOS_CHECKSUM_VERIFY PROC
	PUSH	AX
	CALL	CMOS_CHECKSUM			; BX = calculated checksum
	MOV	AL, CM_CHKSUM			; stored checksum low byte
	CALL	READ_CMOS_AT_WORD			; AX = stored checksum
	CMP	AX, BX
	LAHF

		IF VERIFY_SET_CHECKSUM_BIT EQ 1
;----------------------------------------------------------------------------;
; If calculated checksum invalid, update CMOS checksum status bit
;
	MOV	AL, CM_DIAG
	CALL	READ_CMOS_AT			; get diag byte
	AND	AL, NOT MASK CD_CHK_OK		; clear bit
	SAHF						; restore flag
	JE	VERIFY_SET_CHECKSUM_DONE	; exit if okay
	OR	AL, MASK CD_CHK_OK		; set invalid bit

;----------------------------------------------------------------------------;
; Write status bit
;
	PUSH	AX					; save AH
	MOV	AH, AL
	MOV	AL, CM_DIAG
	CALL	WRITE_CMOS_AT
	POP	AX					; restore stored flags in AH
	SAHF						; restore flags again

VERIFY_SET_CHECKSUM_DONE:
		ENDIF					; VERIFY_SET_CHECKSUM_BIT

	POP	AX
	RET
CMOS_CHECKSUM_VERIFY ENDP

;----------------------------------------------------------------------------;
; Read and calculate CMOS checksum
;----------------------------------------------------------------------------;
; Input:
;	DX = CMOS port
; Output:
;	BX = Sum of CMOS bytes 10H through 2DH
;----------------------------------------------------------------------------;
CMOS_CHECKSUM PROC
	PUSHX	AX, CX
	XOR	BX, BX				; clear working checksum
	MOV	CX, CM_CHKSUM-CM_FD		; loop 2DH - 10H
CMOS_CHECKSUM_LOOP:
	MOV	AX, CX				; AL = CMOS index, AH = 0
	ADD	AL, CM_FD-1				; adjust 0 based counter
	CALL	READ_CMOS_AT
	ADD	BX, AX				; add to sum
	LOOP	CMOS_CHECKSUM_LOOP
	POPX	CX, AX
	RET
CMOS_CHECKSUM ENDP
			ENDIF				; IF VERIFY_CHECKSUM

;			IF 0	; old
;----------------------------------------------------------------------------;
; Detect AT CMOS/NVRAM
;----------------------------------------------------------------------------;
; Input:
;	DS = BDA
; Output:
;	AL = CMOS drive types for drive 0 and 1 (high/low nibbles)
;	AH = number of drives installed (0 based)
;	CF if CMOS error
;	ZF if no drives installed
;----------------------------------------------------------------------------;
;		ASSUME DS:_BDA
;DETECT_CMOS_AT PROC
;	PUSHX	SI, CX
;	MOV	SI, OFFSET CMOS_PORTS
;	MOV	CX, CMOS_PORT_L
;
;DETECT_CMOS_AT_LOOP:
;	LODS	WORD PTR CS:[SI]		; AX = next port
;	XCHG	AX, DX			; DX = port to try
;
;----------------------------------------------------------------------------;
; Check that CMOS is valid
;
;	FD_DEBUG	'CMOS TRY'
;	;CALL	CMOS_CHECKSUM_VERIFY	; verify checksum and reset diag byte
;	;JNE	_ERR				; jump if error (necessary?)
;
;	MOV	AL, CM_DIAG			; diagnostic byte (0EH)
;	CALL	READ_CMOS_AT
;	;FD_DEBUG	'CMOS RES'
;	CMP	AL, 0FFH
;	JE	SETUP_CMOS_NEXT
;
;----------------------------------------------------------------------------;
; Check CMOS valid bits:
; RTC power not lost, checksum okay, POST config, Time OK
; Clear AH
;
;	AND	AX, MASK CD_RTC_OK OR MASK CD_CHK_OK OR MASK CD_PC_OK OR MASK CD_TM_OK
;	STC					; presume failure
;	JNZ	SETUP_CMOS_NEXT		; exit with CF if CMOS invalid

;----------------------------------------------------------------------------;
; Working CMOS found. Set in BDA and exit with CF=0.
;
;	SET_GFLAG_ABS	ATCMOS	; set AT CMOS working flag

;	MOV	AX, DX			; AX = port number
;	OR	AH, HIGH RTC_DAT < RTC_AT >	; set AT CMOS flag
;	MOV	CMOS_DATA, AX		; save to BDA
;	CLC					; if necessary

;SETUP_CMOS_NEXT:
;	LOOP	DETECT_CMOS_AT_LOOP
;	POPX	CX, SI
;	RET
;DETECT_CMOS_AT ENDP
;		ASSUME DS:OPTROM
;		ENDIF



			ENDIF



OPTROM	ENDS
		END