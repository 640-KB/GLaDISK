	PAGE	 	59,132
	TITLE		GLaTICK_RTC_NS

;----------------------------------------------------------------------------;
; GLaTICK (Generational Logic and Time Interval Cadence Keeper)
;----------------------------------------------------------------------------;
; RTC Support for NS MM58167AN: SixPakPlus V1, Clone I/O boards
;----------------------------------------------------------------------------;
; TODO:
; - CMOS for 4 drives
; - Detection conflict with CMOS_AT
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; MM58167 Equates (do not edit)
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; Hardware variants
;
RTC_NS_STD		EQU	1			; standard
RTC_NS_TEC		EQU	2			; Tecmar Captain (data reg is +2)

;----------------------------------------------------------------------------;
; Software compatibility
;
RTC_DRV_STD		EQU	1			; standard (ASTCLOCK, CLOCK.COM)
RTC_DRV_OLD		EQU	2			; previous (<= 0.8.3) behavior
RTC_DRV_86B		EQU	3			; 86Box (AST, 5PAK or EV-170)
RTC_DRV_86B2	EQU	4			; 86Box (PII-147)

;----------------------------------------------------------------------------;
; MM58167 Register Indexes
;
NS_MS			EQU	00H			; milliseconds
NS_TSEC		EQU	01H			; hundredths/tenths of seconds
NS_SEC		EQU	02H			; seconds
NS_MIN		EQU	03H			; minutes
NS_HOUR		EQU	04H			; hour
NS_DOW		EQU	05H			; day of week
NS_DAY		EQU	06H			; day of month
NS_MONTH		EQU	07H			; month
NS_RAM		EQU	08H			; address offset for RAM registers
NS_RAM1		EQU	NS_RAM + NS_MS	; 08H - RAM1 ms high nibble only, low = 0
NS_RAM2		EQU	NS_RAM + NS_TSEC	; 09H - RAM2 last month (Year DTK Hexa)
NS_RAM3		EQU	NS_RAM + NS_SEC	; 0AH - RAM3 year (AST)
NS_RAM4		EQU	NS_RAM + NS_MIN	; 0BH - RAM4 clock valid
NS_RAM5		EQU	NS_RAM + NS_HOUR	; 0CH - RAM5 not used
NS_RAM6		EQU	NS_RAM + NS_DOW	; 0DH - RAM6 week low nibble only, high = 0
NS_RAM7		EQU	NS_RAM + NS_DAY	; 0EH - RAM7 not used (Year 86Box)
NS_RAM8		EQU	NS_RAM + NS_MONTH	; 0FH - RAM8 not used
NS_TIME_RST		EQU	12H			; counter reset
NS_RAM_RST		EQU	13H			; RAM reset
NS_STATUS		EQU	14H			; rollover status bit

NS_RST		EQU	0FFH			; send all -1 to reset TIME and RAM
NS_STATE_OK		EQU	222			; Clock valid flag for NS_RAM4 (0BH)
NS_TEST		EQU	0AAH			; test value used for detection

;----------------------------------------------------------------------------;
; Standard RAM register addresses
;
NS_MONTH2		=	NS_RAM2		; 09H RAM - last month storage
NS_YEAR		=	NS_RAM3		; 0AH RAM - year storage
NS_STATE		=	NS_RAM4		; 0BH clock valid flag (222 = valid)

;----------------------------------------------------------------------------;
; FD CMOS RAM addresses
;----------------------------------------------------------------------------;
NS_FD			=	NS_RAM5		; 0CH - CMOS drives 0-1
NS_FD2		=	NS_RAM8		; 0FH - CMOS drives 2-3

;----------------------------------------------------------------------------;
; Config Defaults
;----------------------------------------------------------------------------;
READ_RETRY		=	10		; times to retry for rollover bit on reads
SHOW_CLOCK		=	1		; enable display of clock on boot
RST_STATE		=	1		; reset clock if no valid state flag
Y2K_OFFSET		=	1		; store as year-80 (00=1980, 20=2000, etc)
YEAR_BCD		=	0		; 1=store year as BCD, 0=byte
YEAR_INCR		=	1		; increment year (normal)
DBL_PARITY		=	1		; 1=parity check is per drive, 0=per byte

;----------------------------------------------------------------------------;
; Hardware type: Uncomment to select
;
RTC_NS_TYPE		=	RTC_NS_STD		; set for standard
;RTC_NS_TYPE	=	RTC_NS_TEC		; set for Tecmar

;----------------------------------------------------------------------------;
; Driver Software compatibility: Uncomment to select
;
RTC_DRV_TYPE	=	RTC_DRV_STD		; set for standard (year as byte)
;RTC_DRV_TYPE	=	RTC_DRV_OLD		; set for <= 0.8.3 behavior
;RTC_DRV_TYPE	=	RTC_DRV_86B		; set for 86Box (AST, 5PAK or EV-170)
;RTC_DRV_TYPE	=	RTC_DRV_86B2	; set for 86Box (PII-147)

;----------------------------------------------------------------------------;
; Reconfigure for specific hardware/software
;----------------------------------------------------------------------------;

;		IF RTC_DRV_TYPE EQ RTC_DRV_OLD
;----------------------------------------------------------------------------;
; GLaTICK <= 0.8.3 behavior
;
;YEAR_BCD		=	1			; store year as BCD
;		ENDIF

		IF RTC_DRV_TYPE EQ RTC_DRV_86B
;----------------------------------------------------------------------------;
; 86Box (AST, 5PAK or EV-170)
;
NS_YEAR		=	NS_RAM7		; use 0EH for year storage (-80)
YEAR_BCD		=	0			; store year as byte
RST_STATE		=	0			; reset clock if no valid state flag
YEAR_INCR		=	0			; year increment is handled by 86Box
		ENDIF

		IF RTC_DRV_TYPE EQ RTC_DRV_86B2
;----------------------------------------------------------------------------;
; 86Box (PII-147)
;
NS_YEAR		=	NS_RAM2		; use 09H for year storage
NS_MONTH2		=	NS_RAM7		; use 0EH for last month
RST_STATE		=	0			; reset clock if no valid state flag
Y2K_OFFSET		=	0			; store as (80=1980, 00=2000, etc)
YEAR_BCD		=	1			; store year as BCD
YEAR_INCR		=	0			; year increment is handled by 86Box
		ENDIF

;----------------------------------------------------------------------------;
; NS I/O ports definition
;
;NS_IO_PORTS		EQU	< 2C0H, 240H, 340H >
NS_IO_PORTS		EQU	< 2C0H, 240H >
;NS_IO_PORTS		EQU	< 2C0H >
;NS_IO_PORTS		EQU	< 240H >

INCLUDE	GLADISK.INC

			IF CMOS_TYPE_NS EQ 1
;----------------------------------------------------------------------------;
; Start of segment
;----------------------------------------------------------------------------;
OPTROM	SEGMENT BYTE PUBLIC 'CODE'
		ASSUME  DS:OPTROM, SS:OPTROM, CS:OPTROM, ES:OPTROM

PUBLIC	NS_DETECT
PUBLIC	SETUP_CMOS_NS

			IF USE_FDC_DEBUG EQ 1
EXTRN		FDC_DEBUG:NEAR
			ENDIF

RTC_NS_PROC PROC

			IF SHOW_FDC EQ 1
;----------------------------------------------------------------------------;
; POST banner display string
;
PUBLIC	S_CM_NS
S_CM_NS	DB	'58167', SZ
			ENDIF

;----------------------------------------------------------------------------;
; Supported I/O ports
;----------------------------------------------------------------------------;
NS_PORTS	LABEL  WORD
			IRP	P, < %NS_IO_PORTS >
		DW	P
			ENDM
NS_PORTS_CT	EQU	($-NS_PORTS)/2	; number of supported ports

;----------------------------------------------------------------------------;
; Detect NS RTC and read floppy config
;----------------------------------------------------------------------------;
; Uses a simple parity bit check to ensure value read is (more likely) valid.
;
; Output:
;	AL = floppy types, if CF=0
;	DX = port, if detected
;	BP = display string, if detected
;	CF if error
;	ZF if no error, but no drives configured
;	NZ if no error and drives valid
;	CMOS_DATA set to port and RTC type
;
;	CF or ZF, do not use these values (JBE)
;----------------------------------------------------------------------------;
		ASSUME DS:_BDA_ABS
SETUP_CMOS_NS PROC
	PUSH	BP
	CALL	NS_DETECT
	STC					; presume failure
	JNZ	SETUP_CMOS_NS_RET		; exit with CF=1 if not detected
	MOV	AH, AL			; save RTC type

;----------------------------------------------------------------------------;
; Read floppy config
; Since this register may contain invalid data, an odd parity bit is used to
; eliminate half of the possible states considered corrupt, such as 00 and FF.
; Set as CMOS type only if drive byte is valid.
;
	MOV	AL, NS_FD			; FD drive type register index
	CALL	NS_READ_PO			; read from RTC with odd parity check
	JPE	SETUP_CMOS_NS_RET		; exit if invalid read

	AND	AL, MASK FDT0 OR MASK FDT1 ; ZF if no drives installed, CF = 0
	JZ	SETUP_CMOS_NS_RET		; if no drives installed, exit CF = 0

;----------------------------------------------------------------------------;
; NS detected - shift floppy types and save to BDA
;
		REPT	4
	SHL	AH, 1				; shift RTC type to high nibble
		ENDM
	OR	DH, AH			; save to CMOS data WORD, CF = 0
	MOV	CMOS_DATA_ABS, DX		; save to BDA
	POP	BP				; discard saved BP
	MOV	BP, OFFSET S_CM_NS	; 58167 display string
	RET

SETUP_CMOS_NS_ERR:
	STC

SETUP_CMOS_NS_RET:
	POP	BP
	RET

SETUP_CMOS_NS ENDP
		ASSUME DS:NOTHING

;----------------------------------------------------------------------------;
;
; MM58167 I/O Routines
;
;----------------------------------------------------------------------------;

		ASSUME DS:OPTROM
;----------------------------------------------------------------------------;
; Get register port for either 2 or 16 port mode
;----------------------------------------------------------------------------;
; Input:
;	AL = register index
;	BP = 2/16 flag	 TODO: set this
;	DI = base port
; Output:
;	DX = data port
; Clobbers: BX (on 16 port mode)
;----------------------------------------------------------------------------;
NS_GET_PORT PROC
	TEST	BP, BP			; is 2 or 16 port mode?
	JNZ	NS_SET_2			; if 1, is 2 port mode

;----------------------------------------------------------------------------;
; Set address port in DX for 16 port direct mode
;
	MOV	BX, AX			; BL = register index
	AND	BX, 1FH			; only valid registers, clear high word
	LEA	DX, [BX][DI]		; DX data port
	RET

;----------------------------------------------------------------------------;
; Set address port for 2 port mode
;
NS_SET_2:
	MOV	DX, DI			; DX = base port
	OUT	DX, AL			; set register index
			IF RTC_NS_TYPE EQ RTC_NS_TEC
	CMP	DX, 02C0H			; if port 2C0, data port is 2C1
	JE	NS_TEC_DONE
	INC	DX				; DX = data port = index port + 2
NS_TEC_DONE:
			ENDIF
	INC	DX				; DX = data port
	RET
NS_GET_PORT ENDP

;----------------------------------------------------------------------------;
; Read register from MM58167AN RTC and validate as BCD <= 59H
;----------------------------------------------------------------------------;
; Input: AL = register index, BP = 2/16 flag, DI = base port
; Output: AL = byte register value
; 	CF if invalid (value > 59H), NC if valid
; Clobbers: BX
;----------------------------------------------------------------------------;
NS_READ PROC
	PUSH	DX
	CALL	NS_GET_PORT			; DX = data port for register AL
	IN	AL, DX			; AL = register value
	CMP	AL, 59H + 1			; is valid BCD?
	CMC					; CF if > 59
	POP	DX
	RET
NS_READ ENDP

;----------------------------------------------------------------------------;
; Read register from MM58167AN RTC with odd parity in high bit check
;----------------------------------------------------------------------------;
; Input: AL = register index, BP = 2/16 flag, DI = base port
; Output: AL = byte register value
;	PO if valid odd parity check (JPO/JNP)
;	PE if invalid check (JPE/JP)
;----------------------------------------------------------------------------;
NS_READ_PO PROC
	PUSH	DX
	CALL	NS_GET_PORT				; DX = data port for register AL
	IN	AL, DX				; AL = register value
	POP	DX
		IF DBL_PARITY EQ 1
	TEST	AL, MASK FDS1 OR MASK FDT1	; test low nibble
	JPE	NS_READ_PO_RET			; if even, not okay, exit with PE
	TEST	AL, MASK FDS0 OR MASK FDT0	; test high nibble
NS_READ_PO_RET:
		ELSE
	TEST	AL, AL				; check single parity of byte
		ENDIF
	RET
NS_READ_PO ENDP

			IF 0	; NS_CHECK_STATE, NS_RESET, NS_WRITE_PO unused
;----------------------------------------------------------------------------;
; Check that clock is in valid state and reset clock if not
;----------------------------------------------------------------------------;
; Clobbers: AX, BX
;----------------------------------------------------------------------------;
NS_CHECK_STATE PROC
	MOV	AL, NS_STATE		; state register
	CALL	NS_READ			; AL = state register value
	CMP	AL, NS_STATE_OK		; is OK?
	JE	NS_RET			; exit if so
						; otherwise fall through to reset
NS_CHECK_STATE ENDP

;----------------------------------------------------------------------------;
; Reset all counters (time) and alarms
;----------------------------------------------------------------------------;
; Clobbers: AX, BX
;----------------------------------------------------------------------------;
NS_RESET PROC
			IF RST_STATE EQ 1
	MOV	AX, DBW <NS_RST, NS_TIME_RST>	; counter reset register
	CALL	NS_WRITE				; write all 1's to reset
	MOV	AL, NS_RAM_RST			; RAM reset register
	CALL	NS_WRITE
			ENDIF
	MOV	AX, DBW <NS_STATE_OK, NS_STATE>	; set state register to OK
							; fall through to write
NS_RESET ENDP

;----------------------------------------------------------------------------;
; Write to Register with odd parity in high order bit
;----------------------------------------------------------------------------;
; Input: AL = register index, AH = register value
;----------------------------------------------------------------------------;
NS_WRITE_PO PROC
			IF DBL_PARITY EQ 1
	TEST	AH, MASK FDS1 OR MASK FDT1	; test low nibble
	JPO	NS_WRITE_PO_HI
	XOR	AH, MASK FDS1			; toggle low nibble parity
NS_WRITE_PO_HI:
	TEST	AH, MASK FDS0 OR MASK FDT0	; test high nibble
	JPO	NS_WRITE				; if even, make parity odd
	XOR	AH, MASK FDS0			; toggle high nibble parity
			ELSE
	TEST	AH, AH				; calculate parity
	JPO	NS_WRITE				; okay if odd parity
	XOR	AH, MASK FDS0			; toggle high byte parity
			ENDIF
;NS_WRITE_PO ENDP
			ENDIF

;----------------------------------------------------------------------------;
; Write to Register
;----------------------------------------------------------------------------;
; Input: AL = register index, AH = register value
; Clobbers: AL, BX
;----------------------------------------------------------------------------;
NS_WRITE PROC
	PUSH	DX
	CALL	NS_GET_PORT			; DX = data port in AL
	MOV	AL, AH			; AL = register value
	OUT	DX, AL
	POP	DX
NS_RET:
	RET
NS_WRITE ENDP


;----------------------------------------------------------------------------;
; Detect MM58167 RTC
;----------------------------------------------------------------------------;
; Output:
;	ZF if found, NZ if not
;	AL = card type and CF = 0 on success
;	AH = 0
;	DX = base address (2C0, 240, 340, etc), 0 if not detected
;	BP = detected 2/16 flag
;
; Clobbers: AX, SI, DI
;----------------------------------------------------------------------------;
; Port 2C0H is used with multiple RTCs:
;
; On MM58167AN (NS), port 2C0H is ms and low nibble is always 0
; On Ricoh (RS), port 2C0H is write only, so reading will always return FFH
; On DS12x85/MC146818 (AT), port 2C0H is ... ?
;----------------------------------------------------------------------------;
NS_DETECT PROC
	PUSH	CX
	MOV	SI, OFFSET NS_PORTS	; supported ports
	MOV	CX, NS_PORTS_CT		; number of supported ports

NS_DETECT_LOOP:
	MOV	DI, WORD PTR CS:[SI]	; DI = next port to try

;----------------------------------------------------------------------------;
; Check 16 port mode - ZF if found
;
	XOR	BP, BP			; BP = 0 (16 port mode)
			IF RTC_DRV_TYPE EQ RTC_DRV_86B OR RTC_DRV_TYPE EQ RTC_DRV_86B2
	XOR	AX, AX
	CALL	NS_WRITE
			ENDIF
	CALL	NS_DETECT_PORT		; check for NS at DI and BP (16 mode)
	MOV	AL, RTC_NS			; default to 16 port direct
	JNC	NS_DETECT_FOUND		; NS found

;----------------------------------------------------------------------------;
; Check 2 port mode - ZF if found
;
	INC	BP				; BP = 1 (2 port mode)
	CALL	NS_DETECT_PORT		; check for NS at DI and BP (2 mode)
	LODSW					; next port (clobbers AX)
	MOV	AL, RTC_NS2			; 2 port latched
	JNC	NS_DETECT_FOUND		; NS found

	LOOP	NS_DETECT_LOOP		; try next port

;----------------------------------------------------------------------------;
; NS NOT detected
;
	CBW					; AH = 0
	CWD					; DX = 0
	MOV	DI, DX			; DI = 0
	CMP	AL, 0				; ZF = 0 (not found), CF = 0

NS_DETECT_EXIT:
	POP	CX
	RET

;----------------------------------------------------------------------------;
; NS detected
;
NS_DETECT_FOUND:
	MOV	DX, DI			; DX = detected port
	XOR	AH, AH			; ZF = 1 (found), CF = 0
	JMP	SHORT NS_DETECT_EXIT

NS_DETECT ENDP

;----------------------------------------------------------------------------;
; Detect if NS is present
;----------------------------------------------------------------------------;
; Input: BP = 2/16 flag, DI = base port
;
; Output: CF if not found
;
; Clobbers: AX, DX
;----------------------------------------------------------------------------;
; Detection:
;
; 1. Read register 0 - if 0, maybe NS or AT (not RP)
; 2. Read register 0Dh and save, write AAh, read back, finally restore
;	- if 80h or 0 then is an AT or Ricoh
;	- if 0FAh or 0AHh, then likely NS
;	- if 0AAh, then unknown card
;----------------------------------------------------------------------------;
NS_DETECT_PORT PROC
	PUSHF					; save IF (TODO: necessary?)
	CLI					; disable interrupts

;----------------------------------------------------------------------------;
; Test register 00h
;
	MOV	AL, NS_MS			; NS register 0 low nibble is always 0
	CALL	NS_READ
	AND	AL, 0FH			; ZF if 0, maybe NS
	
	JNZ	NS_DETECT_PORT_ND		; not 0, so isn't NS

;----------------------------------------------------------------------------;
; Test register 0Dh
;
	MOV	AL, NS_RAM6			; register 0DH
	CALL	NS_READ			; read original value
	XCHG	AX, DX			; save to DL
	MOV	AX, DBW < NS_TEST, NS_RAM6 > ; AH = test value, AL = register 0DH
	CALL	NS_WRITE			; write test value 
	MOV	AL, NS_RAM6			; register 0DH
	CALL	NS_READ			; AL = re-read value
	XCHG	AX, DX			; AL = original value, DL = test read	

;----------------------------------------------------------------------------;
; Restore previous value
;
	MOV	AH, AL			; AH = original value
	MOV	AL, NS_RAM6			; register 0DH
	CALL	NS_WRITE			; write back
	XCHG	AX, DX			; AL = test read
	TEST	AL, 0FH			; is low nibble 0?
	JZ	NS_DETECT_PORT_ND		; if so, not detected
			IF RTC_DRV_TYPE EQ RTC_DRV_86B OR RTC_DRV_TYPE EQ RTC_DRV_86B2
	CMP	AL, NS_TEST			; if 0AAh, then likely NS (workaround 86Box bug)
			ELSE
	CMP	AL, NS_TEST AND 0FH	; if 0Ah, then likely NS
			ENDIF
	JNZ	NS_DETECT_PORT_ND		; jump if not

;----------------------------------------------------------------------------;
; NS detected
;
	POPF					; restore IF
	CLC					; CF = 0 (found)
	RET

;----------------------------------------------------------------------------;
; NS NOT detected
;
NS_DETECT_PORT_ND:
	POPF					; restore IF
	STC					; CF = 1 (not found)
	RET

NS_DETECT_PORT ENDP

RTC_NS_PROC ENDP

OPTROM	ENDS
			ENDIF			; IFDEF RTC_NS
		END
