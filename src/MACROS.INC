;----------------------------------------------------------------------------;
; GLaDISK (Gizmo Linkage and Dynamic Information Storage Keeper)
;
; It's floppy but good.
;
; Copyright (c) 2022-2025, 640KB and contributors
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; GLaDISK-specific MACROS
;----------------------------------------------------------------------------;

MOVE_ISR	MACRO	SRC, DST
	MOV	SI, OFFSET SRC
	MOV	DI, OFFSET DST
	MOVSW
	MOVSW
		ENDM

SETUP_ISR	MACRO	ISR, IVT
			IFNB <IVT>
	MOV	DI, OFFSET IVT			; Move IVT to ISR
			ENDIF
	MOV	AX, OFFSET ISR
	STOSW
	MOV	AX, CS
	STOSW	
		ENDM

;----------------------------------------------------------------------------;
; Define ROM drive types from MASM literal list
;----------------------------------------------------------------------------;
; Usage:	CMOS_ROM_TYPE  LBL, %TYPES
; Input:
;	LBL		BYTE label for first drive type
;	TYPES		literal list <> of CMOS drive types (0-7)
; Output:
;	DB for FD_CMOS_TYPES drive types in little endian nibbles
;----------------------------------------------------------------------------;
CMOS_ROM_TYPE  	MACRO	LBL, TYPES, MAX_DRIVES
			LOCAL	X, D
LBL		LABEL BYTE
X		=	0				;; counter
D		=	0				;; drive type working byte
		IRP	T, < TYPES >
X		=	X + 1
			IF X MOD 2 EQ 1
D		=	T SHL FDT0 AND MASK FDT0 ;; shift odd drive into high nibble
			ELSE
D 		=	D OR (T AND MASK FDT1)	;; combine nibbles
			DB	D, -D			; drive types and checksum offset
			ENDIF
		ENDM
;;---------------------------------------------------------------------------;
;; If there was an odd number of drives in the list, pad with a 0 for last
;;
		IF X MOD 2 EQ 1
			DB	D, -D			; pad drive type
		ENDIF
			ORG	LBL+MAX_DRIVES	; pad for max drives
		ENDM

;----------------------------------------------------------------------------;
; IRET with all current flags OR only current CF, IF=1. And POP BP.
;----------------------------------------------------------------------------;
; Many INT 13H BIOSes simply RETF 2 and discard caller's flags, leaving IF=1.
; This behavior may be counted upon so best to leave it.
;----------------------------------------------------------------------------;
IRET_F_BP	MACRO
			IF IRET_FLAGS EQ 1
	JMP	NEAR PTR IRET_CF_BP		; return from INT with current CF
			ELSE
	POP	BP
	RETF	2
			ENDIF
		ENDM

;----------------------------------------------------------------------------;
; Display debug info if USE_FDC_DEBUG enabled
; Input:
;	MSG: display during build and during call
;----------------------------------------------------------------------------;
.LALL
FD_DEBUG	MACRO	MSG, NO_REGS
		LOCAL	L_MSG, L_START
			IF USE_FDC_DEBUG EQ 1	;; only display if USE_FDC_DEBUG
			IFNB	<MSG>
			IF2
	%OUT FDC_DEBUG: MSG
			ENDIF
	JMP	SHORT L_START
L_MSG	DB	MSG, CR, LF, SZ
L_START:
	PUSHF
	PUSH	SI
	MOV	SI, OFFSET L_MSG
EXTRN	OUT_SZ:NEAR
	CALL	OUT_SZ
	POP	SI
	POPF
			ENDIF
			IFB <NO_REGS>		;; if NO_REGS don't do DEBUG output
	CALL	FDC_DEBUG
			ENDIF
			ENDIF
		ENDM

;----------------------------------------------------------------------------;
; Skip next 1 byte instruction - replace with TEST AL, imm8
;----------------------------------------------------------------------------;
; CF = 0, Clobbers ZF
;----------------------------------------------------------------------------;
SKIP1		MACRO
	DB	0A8h			; TEST	AL, imm8
		ENDM

;----------------------------------------------------------------------------;
; Skip next 2 byte instruction - replace with TEST AX, imm16
;----------------------------------------------------------------------------;
; CF = 0, Clobbers ZF
;----------------------------------------------------------------------------;
SKIP2		MACRO
	DB	0A9h			; TEST	AX, imm16
		ENDM

;----------------------------------------------------------------------------;
; Jump if Warm Boot
;----------------------------------------------------------------------------;
JWB		MACRO	LBL
			ASSUME DS:_BDA
	CMP	WARM_FLAG, WARM_BOOT		; is warm boot?
	JE	LBL					; jump if so
		ENDM

;----------------------------------------------------------------------------;
; Jump if not Warm Boot
;----------------------------------------------------------------------------;
JNWB		MACRO	LBL
	CMP	WARM_FLAG, WARM_BOOT		; is warm boot?
	JNE	LBL					; jump if not
		ENDM