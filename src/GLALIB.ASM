	PAGE		59,132
	TITLE		GLaLIB

;----------------------------------------------------------------------------;
; GLaLIB - General Libraries and LIBraries
;----------------------------------------------------------------------------;
; These are the actual General Libraries used for Companion ROMs.
;----------------------------------------------------------------------------;
INCLUDE	GLADISK.INC

;----------------------------------------------------------------------------;
; Start of segment
;----------------------------------------------------------------------------;
OPTROM	SEGMENT BYTE PUBLIC 'CODE'
		ASSUME  DS:OPTROM, SS:OPTROM, CS:OPTROM, ES:OPTROM

;----------------------------------------------------------------------------;
; GLaDISK EXTRN
;----------------------------------------------------------------------------;
EXTRN		STR_CRLF:NEAR

;----------------------------------------------------------------------------;
; GLaLIB PUBLIC PROCs
;----------------------------------------------------------------------------;
			IF GB_UI
PUBLIC	OUT_CHAR, OUT_SZ_ATTR, OUT_SZ, OUT_SZ_NL, OUT_NL, CRLF
PUBLIC	POST_START_COL_1, POST_START_COL_2, POST_END_COL, POST_END_COL_NL
PUBLIC	IS_GLABIOS
			ENDIF

PUBLIC	IO_WAIT_MS_125, IO_DELAY_MS_FDC

;----------------------------------------------------------------------------;
; Delay using PIT counter increments of 125 ms
;----------------------------------------------------------------------------;
; Input:
;	AL = wait in 125 ms increments
;
; AX clobbered
; Size: 53 bytes
;----------------------------------------------------------------------------;
			ASSUME DS:_BDA
IO_WAIT_MS_125 PROC NEAR
	MOV	AH, 125
	MUL	AH				; AX = wait in 1 ms

;----------------------------------------------------------------------------;
; Delay using PIT counter increments of 1 ms
;----------------------------------------------------------------------------;
; - Calculate the total number of PIT ticks necessary (where 1,193,000 = 1s)
; - Latch the PIT and draw down the countdown total on each read.
; - Exit when countdown underflows.
;
; Note: Mode 3 (Square Wave) decements the readable counter by 2, so the
; effective frequency of the counter is actually 2,386,360 Hz.
;
; Input:
;	AX = wait in number of ms (clobbered)
;
; Based on contribution by @Raffzahn (under CC BY-SA 4.0):
; https://retrocomputing.stackexchange.com/a/24874/21323
;
; https://stanislavs.org/helppc/8253.html
;
; Input:
;	DS = BDA
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; Delay using PIT counter increments of UNSAFE_FLP_DIV ms for floppy drive
; head settling time.
;----------------------------------------------------------------------------;
; Note: this is based on Counter 0 running in Square Mode (mode 3). If timer
; is re-programmed to another mode by a program, these delays could be doubled.
;----------------------------------------------------------------------------;
IO_DELAY_MS_FDC PROC
			IF UNSAFE_FLOPPY EQ 1
				IF AT_WAIT EQ 1
	TEST_GFLAG	ATWAIT
	JNZ	IO_DELAY_MS_AT
				ENDIF
	PUSH	BX
	MOV	BX, 1193 * 2 * UNSAFE_FLP_DIV
	JMP	SHORT IO_DELAY_TICK
			ENDIF

IO_DELAY_MS PROC NEAR
			IF AT_WAIT EQ 1	; AT and no unsafe floppy (code opt.)
	TEST_GFLAG	ATWAIT
	JNZ	IO_DELAY_MS_AT
			ENDIF
	PUSH	BX
	MOV	BX, 1193 * 2		; 1,193,182 / 1000 ms * 2 = 2,386 ticks/ms

;----------------------------------------------------------------------------;
; Delay using PIT counter DX:AX number of ticks
; 1 tick = ~ 0.83809511 microseconds
; 18 ticks = ~ 15.085 microseconds 
;----------------------------------------------------------------------------;
IO_DELAY_TICK PROC
	PUSH	CX
	PUSH	DX
	MUL	BX				; DX:AX = countdown of PIT ticks to wait
	XCHG	AX, BX			; DX:BX = countdown ticks
	CALL	IO_WAIT_LATCH		; AX = start read
IO_WAIT_MS_LOOP:
	MOV	CX, AX			; CX = last read
	CALL	IO_WAIT_LATCH		; AX = current counter reading
	SUB	CX, AX			; CX = # of ticks elapsed since last reading
	SUB	BX, CX			; subtract change in ticks from countdown
	SBB	DX, 0				; borrow out of high word (if necessary)
	JAE	IO_WAIT_MS_LOOP		; loop while countdown >= 0
	POP	DX
	POP	CX
	POP	BX
IO_WAIT_MS_DONE:
	RET

;----------------------------------------------------------------------------;
; Latch PIT 0 and read counter to AX
;----------------------------------------------------------------------------;
; Output: AX = current counter
; Time: 123 clock cycles (including CALL) (25.7 us @ 4.77 MHz)
;----------------------------------------------------------------------------;
IO_WAIT_LATCH PROC
	MOV	AL, PIT_CW <0, 0>		; Counter 0, Latch (00b)
	PUSHF					; save current IF
	CLI					; disable interrupts
	OUT	PIT_CTRL, AL		; Write command to CTC
	IN	AL, PIT_CH0			; Read low byte of Counter 0 latch
	MOV	AH, AL			; Save it
	IN	AL, PIT_CH0			; Read high byte of Counter 0 latch
	POPF					; restore IF state
	XCHG	AL, AH			; convert endian
	RET
IO_WAIT_LATCH ENDP
IO_DELAY_TICK ENDP
IO_DELAY_MS ENDP
IO_DELAY_MS_FDC ENDP
IO_WAIT_MS_125 ENDP

;----------------------------------------------------------------------------;
; AT Delay using PIT counter increments of 1 ms
;----------------------------------------------------------------------------;
			IF AT_WAIT EQ 1
IO_DELAY_MS_FDC_AT LABEL NEAR
IO_DELAY_MS_AT PROC
	PUSHF
	PUSH	CX
	PUSH	DX
	MOV	DX, 1000
	MUL	DX			; dx:ax = DX * ax
	XCHG	AX, DX		; DX = AX
	XCHG	AX, CX		; CX = DX
	MOV	AH, 86H
	;STC				; if CF is cleared, function success
	INT	15H			; AH=86H, wait CX:DX # of microseconds
	POP	DX
	POP	CX
	POPF
	RET
IO_DELAY_MS_AT ENDP
			ASSUME DS:NOTHING
			ENDIF

			IF IRET_FLAGS EQ 1
;----------------------------------------------------------------------------;
; IRET with all previous status flags and current CF.
; IF is also set since most INT 13H BIOSes always return with IF=1.
;----------------------------------------------------------------------------;
			ASSUME DS:NOTHING
PUBLIC	IRET_CF, IRET_CF_BP
IRET_CF	PROC NEAR
	PUSH	BP

;----------------------------------------------------------------------------;
; Same except BP already on top of stack
;----------------------------------------------------------------------------;
IRET_CF_BP	PROC NEAR
	MOV	BP, SP				; get stack pointer
	RCR	BYTE PTR [BP][6], 1		; current CF to MSB
	ROL	BYTE PTR [BP][6], 1		; MSB to saved CF, restore CF
	POP	BP
	IRET
IRET_CF_BP	ENDP
IRET_CF	ENDP
			ENDIF

			IF GB_UI
;----------------------------------------------------------------------------;
; GLaLIB "UI" - only used if POST display is shown
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; Write POST column label and start separator 
;----------------------------------------------------------------------------;
; - Start new line
; - display column name in color 1
; - display left separator in color 1
; - set color for inner text to be color 2
;----------------------------------------------------------------------------;
; Input:
; - SI: column name string
; - BL: inner text color/attribute
;
; Output:
; - SI: beginning of next adjacent string
; - CX: inner text color length = POST_TAB_COL_I
;----------------------------------------------------------------------------;
			ASSUME DS:_BDA
POST_COL PROC

POST_LSEP		DB	POST_L, 0
POST_RSEP		DB	POST_R, 0

;----------------------------------------------------------------------------;
; Handle 40 column mode - move to next line and fall through to col 1
;
POST_START_COL_2_40:
	CALL	CRLF				; move to next line
	POP	AX				; rebalance stack

POST_START_COL_1 PROC
	PUSH	AX
	MOV	AL, POST_COL_W		; column 1 tab width
POST_START_COL_START:
	PUSH	BX				; save inner text color
	MOV	AH, BL			; save text color
	MOV	CX, POST_COL_VT		; set attribute on next CX # of chars
	MOV	BX, LOW POST_CLR_TXT	; set outer text color
	CALL	OUT_SZ_ATTR			; write SI string with attribute
	CALL	MOVE_COL			; move cursor to separator column
	PUSH	SI				; save end of string
	MOV	SI, OFFSET POST_LSEP	; write separator string with
	CALL	OUT_SZ			;  existing attributes
	MOV	BL, AH			; restore text color
	DEC	SI				; [SI] = previous null char
	MOV	CL, POST_TAB_COL_I	; CX = repeat times
	PUSH	CX				; save for return
	CALL	OUT_SZ_ATTR			; set attributes, skip null string
	POP	CX				; CX = inner text color length
	POP	SI				; restore string position
	POP	BX				; BL = attribute for next CX chars
	POP	AX
	RET
POST_START_COL_1 ENDP

;----------------------------------------------------------------------------;
; Same as POST_START_COL_1 except starts at column 2
;----------------------------------------------------------------------------;
POST_START_COL_2 PROC
	PUSH	AX
	MOV	AH, 0FH			; get video mode
	INT	10H				; AL = video mode
	CMP	AL, 1				; is 40 column mode?
	JLE	POST_START_COL_2_40
	MOV	AL, POST_TAB_COL		; move to start of column 2
	CALL	MOVE_COL
	MOV	AL, POST_TAB_COL+POST_COL_W	; set abs. position for column 2 tab
	JMP	POST_START_COL_START
POST_START_COL_2 ENDP

;----------------------------------------------------------------------------;
; Same as POST_END_COL and displays a CRLF
;----------------------------------------------------------------------------;
POST_END_COL_NL PROC
	CALL	POST_END_COL

;----------------------------------------------------------------------------;
; Write a CRLF string to console - SI preserved
;----------------------------------------------------------------------------;
CRLF PROC
	PUSH	SI
	CALL	OUT_NL
	POP	SI
	RET
CRLF ENDP

POST_END_COL_NL ENDP

;----------------------------------------------------------------------------;
; Write POST column end separator 
;----------------------------------------------------------------------------;
; Display right separator in color POST_CLR_TXT
;----------------------------------------------------------------------------;
POST_END_COL PROC NEAR
	MOV	SI, OFFSET POST_RSEP
POST_END_COL_STR PROC NEAR
	MOV	CX, 2
	MOV	BX, LOW POST_CLR_TXT	; Fall through to OUT_SZ_ATTR and RET
POST_END_COL_STR ENDP
POST_END_COL ENDP

;----------------------------------------------------------------------------;
; Write a zero-terminated string to console with attributes, no cursor move
;----------------------------------------------------------------------------;
; Sets attribute in BL for the next CX number of characters, past end of string.
;
; Input: CS:SI = String, CX = length, BL = attribute, BH = video page
; Output: SI = end of string
;----------------------------------------------------------------------------;
OUT_SZ_ATTR PROC
			IF POST_THEME NE 0	; enable color/attribute display
	PUSH	AX
	MOV	AX, DBW < 9, ' ' >	; AH = function 9, AL = space char
	INT	10H				; write CX number of chars with attribute
	POP	AX				; Fall through to OUT_SZ and RET
			ENDIF			; POST_THEME NE 0

;----------------------------------------------------------------------------;
; Display a zero-terminated string in BIOS at CS:[SI]
;----------------------------------------------------------------------------;
; Input: CS:SI = String
; Output: SI = end of String
;----------------------------------------------------------------------------;
OUT_SZ PROC
	PUSH	AX
	PUSH	BX
	XOR	BX, BX
OUT_SZ_LOOP:
	LODS	BYTE PTR CS:[SI]		; AL = CS:[SI++]
	TEST	AL, AL			; is zero terminator?
	JZ	OUT_SZ_DONE			; if so, exit
	MOV	AH, 0EH			; TTY output
	INT	10H
	JMP	SHORT OUT_SZ_LOOP
OUT_SZ_DONE:
	POP	BX
	POP	AX
	RET
OUT_SZ ENDP

;----------------------------------------------------------------------------;
; Display a zero-terminated string in BIOS at CS:[SI], followed by CRLF
;----------------------------------------------------------------------------;
OUT_SZ_NL PROC
	CALL	OUT_SZ

;----------------------------------------------------------------------------;
; Write a CRLF string to console - SI clobbered
;----------------------------------------------------------------------------;
OUT_NL PROC
	MOV	SI, OFFSET STR_CRLF
	JMP	SHORT OUT_SZ
OUT_NL ENDP

OUT_SZ_NL ENDP

OUT_SZ_ATTR ENDP

;----------------------------------------------------------------------------;
; Locate cursor to column on current line
;----------------------------------------------------------------------------;
; Input: AL = new col
;----------------------------------------------------------------------------;
MOVE_COL PROC
	PUSH	AX				; must preserve all of these
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	AX				; preserve AL on INT 10H call
	XOR	BH, BH 			; video page 0
	MOV	AH, 3 			; get cursor position
	INT	10H 				; DH = row, DL = column
	POP	AX
MOVE_COL_SET:
	MOV	DL, AL			; set new column
	MOV	AH, 2 			; set cursor position
	INT	10H 				; row = DH, column = DL
	POP	DX
	POP	CX
	POP	BX
	POP	AX
	RET
MOVE_COL ENDP
POST_COL ENDP

;----------------------------------------------------------------------------;
; Are you still there?
;----------------------------------------------------------------------------;
; Output: ZF if GLaBIOS, otherwise NZ
;----------------------------------------------------------------------------;
			ASSUME DS:_BIOS
IS_GLABIOS	PROC
	PUSH	AX
	PUSH	DS
	MOV	AX, SEG _BIOS
	MOV	DS, AX
	CMP	_BIOS_TOP, DBW < 'G', LF >	; ZF if is GB
	POP	DS
	POP	AX
	RET
IS_GLABIOS	ENDP
			ASSUME DS:NOTHING
			ENDIF			; END IF GB_UI EQ 1

			IF USE_FDC_DEBUG EQ 1 OR GB_UI
;----------------------------------------------------------------------------;
; Write a space char to console (8 bytes)
;----------------------------------------------------------------------------;
PUBLIC SPACE
SPACE PROC
	PUSH	AX				; no clobbery AX
	MOV	AX, DBW <0EH, ' '>	; AH = 0Eh, AL = space char
	INT	10H				; send to console
	POP	AX
	RET
SPACE ENDP
			ENDIF

			;IF USE_FDC_DEBUG EQ 1 OR 1

PUBLIC	WORD_HEX, BYTE_HEX, NIB_HEX
			ASSUME DS:NOTHING
;----------------------------------------------------------------------------;
; Display WORD in AX
; If AX >= 100H display as four digits, otherwise display as two.
;----------------------------------------------------------------------------;
PUBLIC	WORD_HEX_TRIM, WORD_HEX_TRIM_Z
WORD_HEX_TRIM PROC
	TEST	AH, AH				; high byte 0?
WORD_HEX_TRIM_Z PROC
	JZ	BYTE_HEX				; display only low byte
			IF USE_FDC_DEBUG EQ 1	; fall through if no DWORD_HEX :)
	JMP	SHORT WORD_HEX			; display as word
			ENDIF
WORD_HEX_TRIM_Z ENDP
WORD_HEX_TRIM ENDP

			IF USE_FDC_DEBUG EQ 1
;----------------------------------------------------------------------------;
; Write DWORD BX:AX as HEX to console
;----------------------------------------------------------------------------;
; Input: BX:AX - 32 bit value to write
; WORDS are separated by a colon ex: 1234:ABCD
;
; AX clobbered
;
; Only used for FDC_DEBUG
;----------------------------------------------------------------------------;
PUBLIC DWORD_HEX
DWORD_HEX PROC
	PUSH	AX 				; save AX
	MOV	AX, BX
	CALL	WORD_HEX 			; write AX to console as HEX
	MOV	AL, ':'
	CALL	OUT_CHAR			; Write char in AL to console
	POP	AX 				; restore AX
			ENDIF

;--------------------------------------------------------------------------
; Write WORD AX as HEX to console
;--------------------------------------------------------------------------
WORD_HEX PROC
	PUSH	AX 				; save AX
	MOV	AL, AH 			; move high byte into low byte
	CALL	BYTE_HEX 			; write byte as HEX to console
	POP	AX 				; restore AX

;--------------------------------------------------------------------------
; Write BYTE AL as HEX to console
;--------------------------------------------------------------------------
BYTE_HEX PROC
	PUSH	AX 				; save AL
			IF CPU_TYPE	EQ CPU_V20
	ROL4	AL				; AL(low nibble) = AL(high nibble)
			ELSE
				IF CPU_TYPE EQ CPU_186
	SHR	AL, 4				; shift high nibble into low nibble
				ELSE
		REPT	4			; repeat SHR 4 times
	SHR	AL, 1				; shift high nibble into low nibble
		ENDM
				ENDIF
			ENDIF
	CALL	NIB_HEX 			; write low nibble of AL as HEX to console
	POP	AX 				; restore AL

;--------------------------------------------------------------------------
; Write low nibble of AL as HEX to console
;--------------------------------------------------------------------------
NIB_HEX PROC
	AND	AL, 0FH 			; isolate low nibble
	CMP	AL, 0AH 			; if < 0Ah, CF=1 and set up a -1 for ASCII
						;  adjust since 'A'-'9' is 7 (not 6)
	SBB	AL, -('0'+66H+1) 		; BCD bias for ASCII (30h + 66h + CF)
						;  AF = AL < 0Ah, CF = 1
						;  if > 9, high_nibble = 0Ah
						;  if <=9, high_nibble = 09h
	DAS					; BCD adjust to ASCII
						;  if low_nibble < 0Ah, low_nibble -= 6
						;  high_nibble -= 6
			;ENDIF
;--------------------------------------------------------------------------
; Write char in AL to console
;--------------------------------------------------------------------------
OUT_CHAR PROC
	PUSH	AX
	PUSH	BX
	MOV	BH, 0				; video page = 0
	MOV	AH, 0EH			; Write AL to screen tty mode
	INT	10H				; send to console
	POP	BX
	POP	AX
	RET
OUT_CHAR ENDP
NIB_HEX ENDP
BYTE_HEX ENDP
WORD_HEX ENDP
			IF USE_FDC_DEBUG EQ 1
DWORD_HEX ENDP

;----------------------------------------------------------------------------;
; Floppy disk debug output
;----------------------------------------------------------------------------;
; FD_CAL_ST		FDC_SF <>			; 3EH  Floppy drive recalibration status
;							;	0 = drive not calibrated
;							;	high bit = working interrupt flag
; FD_MOTOR_ST	FDC_MF <>			; 3FH  FD motor status
;							;	high bit = write operation
; FD_MOTOR_CT	DB	?			; 40H  FD motor shutoff counter (decr. by INT 8)
; FD_LAST_OP	DB	?			; 41H  BIOS Status of last FD operation
; FDC_LAST_ST	FDC_CSB <>			; 42H  FDC command status last result (7 bytes)
;
; FD_LR		FDC_RATE <>			; 8BH  Last diskette data rate selected
;							;	 and FDC capabilities
; FD_MODE		FDC_MODE <>			; 8FH  FD Drive 0-1 Mode (see FDC_MODE)
; FD_MEDIA_ST	FDC_STATE 4 DUP(<>)	; 90H
;----------------------------------------------------------------------------;
; Output:
; Offs  Regs        Fl  MSR
; OOOO  AX:BX CX:DX ZC  XX  3E 3F 40 41  42 43 44 45 46 47 48
;----------------------------------------------------------------------------;
FDC_DEBUG_NI	EQU	0			; display with interrupts off

PUBLIC FDC_DEBUG
FDC_DEBUG PROC
	PUSHF						; save caller IF
		IF FDC_DEBUG_NI EQ 1		; run with no interrupts
	CLI						; no INTs
		ENDIF
	CALL	PRINT_IP				; display SEG:IP
	CALL	SPACE
	CALL	SPACE
	CALL	PRINT_REGS				; display CPU regs and flags
	CALL	SPACE
	CALL	SPACE
	CALL	PRINT_BDA				; display FD BDA data
	CALL	CRLF					; new line
	POPF						; restore caller flags and IF
	RET

;----------------------------------------------------------------------------;
; Display FDC data from BDA
;----------------------------------------------------------------------------;
			ASSUME DS:_BDA
PRINT_BDA PROC
	PUSHF						; caller flags must be preserved
	PUSHX	DS, CX, AX, SI
	MOV	AX, SEG _BDA			; DS = BDA
	MOV	DS, AX

;----------------------------------------------------------------------------;
; Display HD data bytes from BDA
;
	MOV	AL, FD_LR				; display last rate [40:8B]
	;MOV	AL, FD_CAL_ST			; display calibration stat [40:3E]
	CALL	BYTE_HEX
	CALL	SPACE

	MOV	SI, OFFSET FD_MODE
	LODSB
	CALL	BYTE_HEX				; display FD_MODE [40:8F]
	CALL	SPACE

	LODSW
	CALL	WORD_HEX				; display FD_MEDIA_ST [40:90]

;----------------------------------------------------------------------------;
; Display FDC bytes from BDA (03Eh - 048h)
;
	MOV	SI, OFFSET FD_LAST_OP		; start with last op
	MOV	CX, (SIZE FDC_LAST_ST) + 1	; LAST_OP and 7 result bytes
BDA_LOOP:
	CALL	SPACE	
	LODSB
	CALL	BYTE_HEX
	CMP	CL, 49H - 41H			; extra space before result bytes
	JNE	BDA_NO_CRLF
	CALL	SPACE
BDA_NO_CRLF:
	LOOP	BDA_LOOP
	POPX	SI, AX, CX, DS
	POPF						; restore flags
	RET
PRINT_BDA ENDP

;----------------------------------------------------------------------------;
; Print current instruction pointer
;----------------------------------------------------------------------------;
PRINT_IP PROC
	PUSHF						; always preserve caller flags
	PUSH	AX
	PUSH	BP
	MOV	BP, SP
	MOV	AX, [BP+8]				; caller IP from stack
	SUB	AX, 3					; will be +3 bytes offset
	CALL	WORD_HEX
	POP	BP
	POP	AX
	POPF
	RET
PRINT_IP ENDP

;----------------------------------------------------------------------------;
; Display current regs and flags
; AX:BX CX:DX Flags
;----------------------------------------------------------------------------;
PRINT_REGS PROC
				IF CPU_TYPE EQ CPU_186 OR CPU_TYPE EQ CPU_V20
	PUSHA
				ELSE
	PUSHX	AX, BX, CX, DX, SI, DI		; preserve all
				ENDIF
	PUSHF

	XCHG	AX, BX				; display AX:BX
	CALL	DWORD_HEX
	CALL	SPACE

	XCHG	AX, DX				; display CX:DX
	MOV	BX, CX
	CALL	DWORD_HEX
	CALL	SPACE

	XCHG	AX, DI				; display SI:DI
	;MOV	BX, SI
	MOV	BX, BP				; display BP:DI
	CALL	DWORD_HEX
	CALL	SPACE

	POPF						; restore and re-save flags
	PUSHF

;----------------------------------------------------------------------------;
; Display state of CF and ZF
;
PRINT_FLAGS_PF	EQU	0
PRINT_FLAGS:
	;PUSHF						; necessary?
	MOV	AL, '-'
	JNZ	PF_ZF
	MOV	AL, 'Z'
PF_ZF:
	CALL	OUT_CHAR
	MOV	AL, '-'
	JNC	PF_CF
	MOV	AL, 'C'
PF_CF:
	CALL	OUT_CHAR
		IF PRINT_FLAGS_PF EQ 1
	MOV	AL, '-'
	JNP	PF_PF
	MOV	AL, 'P'
PF_PF:
	CALL	OUT_CHAR
		ENDIF
	;POPF
	CALL	SPACE
	CALL	SPACE

;----------------------------------------------------------------------------;
; Display FDC Main Status Register
;
	MOV	DX, FDC_STAT
	IN	AL, DX
	CALL	BYTE_HEX

;----------------------------------------------------------------------------;
; Restore all flags and registers
;
	POPF
				IF CPU_TYPE EQ CPU_186 OR CPU_TYPE EQ CPU_V20
	POPA
				ELSE
	POPX	DI, SI, DX, CX, BX, AX
				ENDIF

	RET
PRINT_REGS ENDP
			ASSUME DS:NOTHING
FDC_DEBUG ENDP
			ENDIF

OPTROM	ENDS
		END
