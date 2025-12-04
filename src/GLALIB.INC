
;----------------------------------------------------------------------------;
; GLaDISK (Gizmo Linkage and Dynamic Information Storage Keeper)
;
; It's floppy but good.
;
; Copyright (c) 2022-2025, 640KB and contributors
;----------------------------------------------------------------------------;
; These are the actual General Libraries used for Companion ROMs.
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; PC Text Colors
; https://stanislavs.org/helppc/colors.html
;
BLACK			EQU	0
DARKBLUE		EQU	1
DARKGREEN		EQU	2
CYAN			EQU	3
DARKRED		EQU	4
DARKMAGENTA		EQU	5
BROWN			EQU	6
GRAY			EQU	7
DARKGRAY		EQU	8
BLUE			EQU	9
GREEN			EQU	10
LIGHTCYAN		EQU	11
RED			EQU	12
MAGENTA		EQU	13
YELLOW		EQU	14
WHITE			EQU	15

;----------------------------------------------------------------------------;
; POST colors and visuals
;----------------------------------------------------------------------------;
POST_THEME		=	1		; color theme for POST screen (see below)

;----------------------------------------------------------------------------;
; Theme My POST Test!
; Pick theme from below or roll your own!
;----------------------------------------------------------------------------;
		IF POST_THEME EQ 3

; Theme #3 - "Boring"
POST_CLR_TXT	EQU	GRAY			; primary color for text
POST_CLR_VAL1	EQU	GRAY			; value text color
POST_CLR_VAL2	EQU	GRAY			; value text alternate color
POST_CLR_COLD	EQU	BLUE			; COLD color
POST_CLR_WARM	EQU	RED			; WARM color
POST_CLR_GB		EQU	GRAY			; BIOS name in bootup screen
		ELSE
		IF POST_THEME EQ 2

; Theme #2 - "Kinda l33t?"
POST_CLR_TXT	EQU	DARKGRAY
POST_CLR_VAL1	EQU	BLUE
POST_CLR_VAL2	EQU	GREEN
POST_CLR_COLD	EQU	BLUE
POST_CLR_WARM	EQU	RED
POST_CLR_GB		EQU	WHITE
		ELSE

; Theme #1 - "Old skool BBS" (default)
POST_CLR_TXT	EQU	CYAN
POST_CLR_VAL1	EQU	GREEN
POST_CLR_VAL2	EQU	YELLOW
POST_CLR_COLD	EQU	BLUE
POST_CLR_WARM	EQU	DARKRED
POST_CLR_GB		EQU	GRAY
		ENDIF
		ENDIF

;----------------------------------------------------------------------------;
; POST screen column layout options
;
POST_L		EQU	<' [ '>		; left separator string
POST_R		EQU	<' ]'>		; right separator string
L_POST_L		EQU	2			; length of separator

POST_TAB_COL	EQU	32			; horiz tab width for second column
POST_COL_LBL_W	EQU	7			; column label width
POST_COL_PAD	EQU	4			; padding (non colored) space between cols

POST_COL_W		EQU	POST_COL_LBL_W-1	; zero-based column index

; column label width plus separator
POST_COL_VT		EQU	POST_COL_LBL_W + L_POST_L

; space between next column
POST_TAB_COL_I	EQU	POST_TAB_COL - POST_COL_LBL_W - L_POST_L - POST_COL_PAD

; prefer period-correct "KB" or IEC "KiB"
				IF UNITS_IEC EQ 1
POST_K_UNIT		EQU	<'KiB'>		; KiB size unit abbrev.
POST_M_UNIT		EQU	<'MiB'>		; MiB size
				ELSE
POST_K_UNIT		EQU	<'KB'>		; KB size unit abbrev.
POST_M_UNIT		EQU	<'MB'>		; MB size
				ENDIF

VID_SP		EQU	' '			; fill byte for blank video RAM char


;----------------------------------------------------------------------------;
; Useful CP-437/Control Chars
;
SZ			EQU	00H			; Zero terminator
CR 			EQU	0DH 			; Carriage return
LF 			EQU	0AH 			; Line feed
BS			EQU	08H			; Backspace ASCII
BELL			EQU	07H			; BELL ASCII
SYN			EQU	16H			; SYN C0 control char
VL			EQU	0B3H			; vertical line
HL			EQU	0C4H			; horizontal line
CURL_TOP		EQU	0F4H
CURL_BOT		EQU	0F5H
BULL			EQU	0F9H			; Bullet operator (medium centered dot)
DOT			EQU	0FAH			; Small middle dot
SQUARE		EQU	0FEH			; Black square (rectangle)
HEART			EQU	03H			; faithful companion
NOTE1			EQU	0DH
NOTE2			EQU	0EH
DBLARROW		EQU	01DH
HALF			EQU	0ABH			; 1/2
QUARTER		EQU	0ACH			; 1/4


;----------------------------------------------------------------------------;
; PC ISA (Instruction Set Architecture) I/O Port Addresses
;----------------------------------------------------------------------------;

; 8237A DMA Controller
DMA_0_A		EQU	00H 			; W   Start Address Register channel 0
DMA_0_C		EQU	01H			; W   Count Register channel 0
DMA_1_A		EQU	02H			; W   Start Address Register channel 1
DMA_1_C		EQU	03H			; W   Count Register channel 1
DMA_2_A		EQU	04H			; W   Start Address Register channel 2
DMA_2_C		EQU	05H			; W   Count Register channel 2
DMA_3_A		EQU	06H			; W   Start Address Register channel 3
DMA_3_C		EQU	07H			; W   Count Register channel 3
DMA_CMD		EQU	08H			; RW  Status / Command Register
DMA_REQ		EQU	09H			; W   Request Register
DMA_MASK		EQU	0AH 			; W   Single Channel Mask Register
DMA_MODE		EQU	0BH 			; W   Mode Register
DMA_FF		EQU	0CH 			; W   Flip-Flop Reset Register
DMA_RESET		EQU	0DH 			; W   Master Reset Register (Mask bits ON)
DMA_MASKR		EQU	0EH 			; W   Mask Reset Register (Mask bits OFF)
DMA_MMASK		EQU	0FH 			; RW  MultiChannel Mask Register

; DMA Page Registers (74LS670)
DMA_P_C0		EQU	87H			; DMA Channel (unused on PC)
DMA_P_C1		EQU	83H			; DMA Channel 0 and 1
DMA_P_C2		EQU	81H			; DMA Channel 2
DMA_P_C3		EQU	82H			; DMA Channel 3

; 8259 PIC Interrupt Controller
INT_P0		EQU	20H 			; Port 0
INT_IMR		EQU	21H 			; Port 1 - OCW1 Interrupt Mask Register

; 8253 PIT Timer
PIT_CH0		EQU	40H			; Timer Channel/Counter 0
PIT_CH1		EQU	41H			; Timer Channel/Counter 1
PIT_CH2		EQU	42H			; Timer Channel/Counter 2 - Speaker
PIT_CTRL		EQU	43H			; Timer Control Word

; 8255 PPI Peripheral Interface
PPI_A			EQU	60H			; PPI (8255) Port A IN  - Keyboard input
PPI_B			EQU	61H			; PPI (8255) Port B OUT - Speaker, Switch selection, Misc
PPI_C			EQU	62H			; PPI (8255) Port C IN  - Switches
PPI_CW		EQU	63H			; PPI (8255) Port Control Word

; 8042 (AT) Keyboard Controller
ATKB_IO		EQU	60H			; 8042 Keyboard input/output buffer register
ATKB_CMD		EQU	64H			; 8042 Keyboard command/status register

; AT CMOS
ATC_IDX		EQU	70H			; AT CMOS index register
ATC_DATA		EQU	71H			; AT CMOS data register

; POST TEST card I/O
POST_CARD_PORT	EQU	80H			; can be 60H, 80H, 300H, 313H

; Unused IO port addresses - used for ISA clearing
IO_PORT_UNUSED_1	EQU	0BFH			; 10111111
IO_PORT_UNUSED_2	EQU	0EBH			; 11101011

; Trivial RAM / data patterns
MAGIC_WORD		EQU	0AA55H		; Magic Word used for option ROM

;----------------------------------------------------------------------------;
; Define Nibbles to Byte
; Convert two nibbles to byte (big endian)
;----------------------------------------------------------------------------;
DNB	RECORD	HBN:4, LBN:4

;----------------------------------------------------------------------------;
; Define Bytes to Word
; Convert two bytes to word (big endian)
;----------------------------------------------------------------------------;
DBW	RECORD	HWB:8, LWB:8

;----------------------------------------------------------------------------;
; Define Nibbles to Word
; Convert two nibbles to byte (big endian)
;----------------------------------------------------------------------------;
DNW	RECORD	NW4:4, NW3:4, NW2:4, NW1:4

;----------------------------------------------------------------------------;
; Convert KiB to Bytes ( K * 1024 )
;----------------------------------------------------------------------------;
KB	RECORD	KBK:6, KBS:10

;----------------------------------------------------------------------------;
; Convert KiB to Words ( K * 1024 / 2 )
;----------------------------------------------------------------------------;
KBW	RECORD	KBWK:7, KBWS:9

;----------------------------------------------------------------------------;
; Convert KiB to Paragraphs ( K * 1024 / 16 )
;----------------------------------------------------------------------------;
KBP	RECORD	KBPK:10, KBPS:6

;----------------------------------------------------------------------------;
; Convert Word to Paragraphs ( K SHL 4 )
;----------------------------------------------------------------------------;
KP	RECORD	KPWP:12, KPWPX:4

;----------------------------------------------------------------------------;
; x86 EFLAGS
;----------------------------------------------------------------------------;
EFLAGS86	RECORD FSF:1,FZF:1,FR1:1,FAF:1,FR2:1,FPF:1,FR3:1=1,FCF:1
HFLAGS86	RECORD FR4:4,FOF:1,FDF:1,FIF:1,FTF:1

;============================================================================;
;
; 			   * * *   S T R U C T S   * * *
;
;============================================================================;

;----------------------------------------------------------------------------;
; BDA Timer Counters (6CH-70H)
;----------------------------------------------------------------------------;
TIMER_C STRUC
LW		DW	?	; 6CH  Timer Counter Low Word (ticks)
HW	  	DW	? 	; 6EH  Timer Counter High Word (hours)
OF 		DB	? 	; 70H  Timer Overflow flag
TIMER_C ENDS

;============================================================================;
;
; 			   * * *   R E C O R D S   * * *
;
;============================================================================;

;----------------------------------------------------------------------------;
; BDA Equipment Flags (40:10H)
;----------------------------------------------------------------------------;
; 00      |			- LPT : # of LPT ports
;   x     |			- X1  :  unused, PS/2 internal modem
;    0    |			- GAM : Game port present
;     000 |			- COM : # of COM ports present
;        0| 		- DMA : DMA (should always be 0)
;         |00	 	- FLP : Floppy drives present (+1) (0=1 drive,1=2,etc)
;         |  00		- VID : Video mode (00=EGA/VGA, 01=CGA 40x25,
; 				-	10=CGA 80x25, 11=MDA 80x25)
;         |    11 	- MBRAM: MB RAM (00=64K, 01=128K, 10=192K, 11=256K+)
;         |      0	- FPU : FPU installed
;         |       1	- IPL : Floppy drive(s) installed (always 1 on 5160)
;----------------------------------------------------------------------------;
EQFLAGS RECORD	LPT:2,X1:1,GAM:1,COM:3,DMA:1,FLP:2,VID:2,MBRAM:2=11b,FPU:1,IPL:1=1

;----------------------------------------------------------------------------;
; GLaBIOS Equipment Flags (40:12H)
;----------------------------------------------------------------------------;
; 76543210
; x       |			- TBD		Reserved
;  x      |			- ATFC	1 if machine ID is FC (AT)
;   x     |			- ATCMOS	1 if AT working CMOS
;    x    |			- ATWAIT	1 if AT INT 15H WAIT support
;     x   |			- TURBO	Turbo supported
;      x  |			- V20		1 if V20, 0 if 8088
;       xx|			- TBD		Reserved
; 84218421
;----------------------------------------------------------------------------;
GFLAGS RECORD	GTBD1:1,ATFC:1,ATCMOS:1,ATWAIT:1,TURBO:1,V20:1,GTBD2:2

;----------------------------------------------------------------------------;
; POST status flags are stored in BP
;----------------------------------------------------------------------------;
; BP:
; 76543210
; x 	    |			- WARM  	Warm Boot flag
;  x 	    |			- PKI   	POST Keyboard Interrupt Received
;   x     |			- PKEY  	Keyboard key stuck
;    x    |			- PFDC  	FDC init failure
;     x   |			- PFSK  	FDC seek test failure
;      x  |			- PDMA  	DMA error
;       x |			- PMEM  	Memory Error
;        x|			- PFXX  	Reserved (do not use)
;         |xxxxxx		- TBD
;         |      xx	- GRND	Random number for tagline
; 84218421
;----------------------------------------------------------------------------;
PFLAGS RECORD WARM:1,PKI:1,PKEY:1,PFDC:1,PFSK:1,PDMA:1,PMEM:1,PFXX:1,PTBD:6,GRND:2

;----------------------------------------------------------------------------;
; BDA Keyboard Flags
;----------------------------------------------------------------------------;
; 40:17	Keyboard Flags Byte 1 (Low)
;----------------------------------------------------------------------------;
;          84218421
; 	    |7 	    	- K1IN	insert is active
; 	    | 6 	    	- K1CL	caps-lock is active
; 	    |  5	    	- K1NL	num-lock is active
; 	    |   4    	- K1SL	scroll-lock is active
; 	    |    3   	- K1AL	ALT key depressed
; 	    |     2  	- K1CT	CTRL key depressed
; 	    |      1 	- K1LS	left shift key depressed
; 	    |       0	- K1RS	right shift key depressed
;----------------------------------------------------------------------------;
KBFLAGS1 RECORD	K1IN:1,K1CL:1,K1NL:1,K1SL:1,K1AL:1,K1CT:1,K1LS:1,K1RS:1

;----------------------------------------------------------------------------;
; 40:18	Keyboard Flags Byte 2 (High)
;----------------------------------------------------------------------------;
; 84218421
; 7 	    |			- K2IN	insert key is depressed
;  6 	    |			- K2CL	caps-lock key is depressed
;   5	    |			- K2NL	num-lock key is depressed
;    4    |			- K2SL	scroll lock key is depressed
;     3   |			- K2PA	pause (Ctrl-NumLock) is active
;      2  |			- K2SY	system key depressed and held
;       1 |			- K2LA	left ALT key depressed
;        0|			- K2LC	left CTRL key depressed
;----------------------------------------------------------------------------;
KBFLAGS2 RECORD	K2IN:1,K2CL:1,K2NL:1,K2SL:1,K2PA:1,K2SY:1,K2LA:1,K2LC:1

;----------------------------------------------------------------------------;
; PIT Timer CW
;----------------------------------------------------------------------------;
; Control Word Counter 1 (port 43H) - System Timer:
;  01 		- SC: Select Counter 1
;    11		- RW: Read/Write 2xR/2xW
;      010		- M:  Mode 2, Rate Gen
;         0		- BCD: 0
;----------------------------------------------------------------------------;
PIT_CW RECORD	PCWSC:2, PCWRW:2, PCWM:3, PCWBCD:1

;----------------------------------------------------------------------------;
; DMA Mode Register
;----------------------------------------------------------------------------;
; 01 			; Mode 1 (Single)
;   0 		; INC: address decrement
;    1 		; Auto-initialization
;     10 		; Operation: Read from memory
;       00 		; Channel 0
;----------------------------------------------------------------------------;
DMA_MR RECORD	DMM:2=01B, DMINC:1, DMAI:1=1, DMOP:2, DMCH:2

;----------------------------------------------------------------------------;
; 8237 DMA Command Register
;----------------------------------------------------------------------------;
; 84218421
; 7 	    |		- DACK	1 = DACK sense active high, 0 = low
;  6      |		- DREQ	1 = DREQ sense active high, 0 = low
;   5     |		- DWS		1 = Extended write selection, 0 = Late write
;    4    |		- DPRI	1 = Rotating priority, 0 = Fixed priority
;     3   |		- DTIM	1 = Compressed timing, 0 = Normal timing
;      2  |		- DDIS	1 = Controller disable, 0 = Controller enable
;       1 |		- DHLD	1 = Channel 0 address hold enable, 0 = disable
;        0|		- DM2M	1 = Memory-to-memory enable, 0 = disable
;----------------------------------------------------------------------------;
DMA_CR RECORD	DACK:1,DREQ:1,DWS:1,DPRI:1,DTIM:1,DDIS:1,DHLD:1,DM2M:1

;----------------------------------------------------------------------------;
; 8237 DMA Status Register
;----------------------------------------------------------------------------;
; 84218421
; 7 	    |		- CR3		1 = Channel 3 request
;  6      |		- CR2		1 = Channel 2 request
;   5     |		- CR1		1 = Channel 1 request
;    4    |		- CR0		1 = Channel 0 request
;     3   |		- TC3		1 = Channel 3 has reached TC
;      2  |		- TC2		1 = Channel 2 has reached TC
;       1 |		- TC1		1 = Channel 1 has reached TC
;        0|		- TC0		1 = Channel 0 has reached TC
;----------------------------------------------------------------------------;
DMA_SR RECORD	DCR3:1,DCR2:1,DCR1:1,DCR0:1,TC3:1,TC2:1,TC1:1,TC0:1

;----------------------------------------------------------------------------;
; 8237 DMA Single Channel Mask Register
;----------------------------------------------------------------------------;
; 84218421
;      2  |		- SMCLR	1 = Set mask bit, 0 = Clear mask bit
;       10|		- SMCH	Select channel mask bit (0-3)
;----------------------------------------------------------------------------;
DMA_SMR RECORD	SMCLR:6,SMCH:2

;----------------------------------------------------------------------------;
; PIC Control Registers
;----------------------------------------------------------------------------;
; ICW1:
;  000 		- A7-A5: unused on 8086 mode
;     1 		- D4:   1 = ICW1 (and Port 0)
;      0 		- LTIM: 0 = Edge Triggered Mode (low to high TTL transition)
;       0 		- ADI:  0 = Call Address Interval of 8
;        1 		- SNGL: 1 = Single mode (no cascading PICs or ICW3)
;         1		- IC4:  1 = ICW4 Needed
;----------------------------------------------------------------------------;
ICW1	RECORD	D4:4, LTIM:1, ADI:1, SNGL:1=1, IC4:1=1

; ICW2:
;  00001 		- T7-T3: Interrupt Vector Address:
;				INT = INT | 8 -> IRQ 0-7 to CPU INT 8-15
;       000 	- D2-D0: unused on 8086 mode
;----------------------------------------------------------------------------;
ICW2	RECORD	ICW2IVA:5, ICW2X:3=0

; ICW4:
;  000 		- D7-D5: unused
;     0		- SFNM: 0 = Not Special Fully Nested Mode
;      10		- BUF:  2 = Buffered Mode/Slave
;        0		- AEOI: 0 = normal EOI
;         1		- uPM:  1 = 8086 system
;----------------------------------------------------------------------------;
ICW4	RECORD	SFNM:4, ICWBUF:2, AEOI:1, uPM:1

;----------------------------------------------------------------------------;
; IMR / OCW1 Interrupt Mask
;----------------------------------------------------------------------------;
; 84218421
; 7 	    |		- IRQ7	1=interrupt masked (disabled), 0=not masked
;  6      |		- IRQ6
;   5     |		- IRQ5
;    4    |		- IRQ4
;     3   |		- IRQ3
;      2  |		- IRQ2
;       1 |		- IRQ1
;        0|		- IRQ0
;----------------------------------------------------------------------------;
OCW1	RECORD	IRQ7:1,IRQ6:1,IRQ5:1,IRQ4:1,IRQ3:1,IRQ2:1,IRQ1:1,IRQ0:1

;----------------------------------------------------------------------------;
; OCW2
;----------------------------------------------------------------------------;
; 84218421
; 765	    |		- O2CMD	Rotate and End of Interrupt Mode Command
;					001b = Non-Specific EOI Command (default)
;    43   |		- O2X		unused (00)
;      210|		- O2L		Interrupt level acted upon
;----------------------------------------------------------------------------;
OCW2	RECORD	O2CMD:3=001b, O2X:2, O2L:3
EOI	EQU		OCW2 <>		; Non-Specific EOI

;----------------------------------------------------------------------------;
; OCW3
;----------------------------------------------------------------------------;
; 84218421
; 7 	    |		- O3D7	unused (0)
;  65     |		- ESMM/SMM	Enable/special mask mode
;    43   |		- O3D3	unused (01b)
;      2  |		- O3P		1=Poll command, 0=No Poll command
;       10|		- O3RR	Read Register command
;----------------------------------------------------------------------------;
OCW3	RECORD	O3D7:1, ESMM:2, O3D3:2=1, O3P:1, O3RR:2

;----------------------------------------------------------------------------;
; NMI Mask Register
;----------------------------------------------------------------------------;
; 84218421
; x 	    |		- NMIE	1=enable NMI, 0=disable
;  0000000|		- NMIX	unused (0)
;----------------------------------------------------------------------------;
NMI	RECORD	NMIE:1, NMIX:7


;----------------------------------------------------------------------------;
; CMOS/RTC Data
;----------------------------------------------------------------------------;
; High nibble = RTC type (0-15)
; Low 3 nibbles = I/O port address
;----------------------------------------------------------------------------;
RTC_DAT	RECORD	RTTYPE:4, RTPORT:12

; TODO: these should move elsewhere? Not really part of GLALIB?
RTC_NONE	EQU	0		; No RTC/CMOS installed
RTC_AT	EQU	1		; 1  AT  - DS12x85/MC146818
RTC_NS	EQU	14		; 14 NS  - MM58167AN 16 ports
RTC_NS2	EQU	15		; 15 NS2 - MM58167AN 2 ports

;============================================================================;
;
;	 			* * *   M A C R O S   * * *
;
;============================================================================;

;----------------------------------------------------------------------------;
; Introduce a short delay of ~15 clock cycles for I/O
;----------------------------------------------------------------------------;
; - Code size: 2 bytes
; - 15 clock cycles
; - Affects no registers or flags
; - CPU Instruction cache is purged
; - No stack required
;----------------------------------------------------------------------------;
IO_DELAY_SHORT	MACRO
		LOCAL _DONE
			IF ARCH_TYPE NE ARCH_EMU
	JMP	SHORT _DONE
_DONE:
			ENDIF
		ENDM

;----------------------------------------------------------------------------;
; Variable delay ~ CX * 15 clock cycles
;----------------------------------------------------------------------------;
; Input: CX delay in 15 clock cycle increments
; Output: CX = 0
;----------------------------------------------------------------------------;
IO_DELAY	MACRO
		LOCAL _DONE
_DONE:
	LOOP	_DONE					; long delay for I/O
		ENDM

;----------------------------------------------------------------------------;
; Long delay ~1.18m clock cycles (roughly 1/4 second on 4.77MHz)
;----------------------------------------------------------------------------;
; Output: CX = 0
;----------------------------------------------------------------------------;
IO_DELAY_LONG	MACRO
			IF ARCH_TYPE NE ARCH_EMU
	XOR	CX, CX 				; delay 65535 LOOPs
	IO_DELAY
			ENDIF
		ENDM

;----------------------------------------------------------------------------;
; Variable delay with slowdown for Turbo builds
;----------------------------------------------------------------------------;
; Input: CX delay in 30 clock cycle increments
; Output: CX = 0
;----------------------------------------------------------------------------;
IO_DELAY_TURBO	MACRO
		LOCAL _DONE
_DONE:
		IF IS_TURBO
	IO_DELAY_SHORT
		ENDIF
	LOOP	_DONE					; long delay for I/O
		ENDM

;----------------------------------------------------------------------------;
; Clear ISA bus before I/O port read by taking all data lines high
; Clobbers AL
;----------------------------------------------------------------------------;
ISA_CLEAR	MACRO
			IF FDC_HD_ENABLE EQ 1
	MOV	AL, 0FFH			; write all 1s to bus to clear buffer ICs
	OUT	IO_PORT_UNUSED_1, AL	; write to any unused port
			ENDIF
		ENDM

;----------------------------------------------------------------------------;
; Clear ISA bus before I/O port read
; If w is specified (any value) will write 16 bit value of AX to both lines
;----------------------------------------------------------------------------;
ISA_DELAY	MACRO w
			IF FDC_HD_ENABLE EQ 1
			IFNB <w>
	OUT	IO_PORT_UNUSED_2, AX	; write to any unused ports on both addr lines
			ELSE
	OUT	IO_PORT_UNUSED_2, AL	; write to any unused ports
			ENDIF
			ENDIF
		ENDM

;----------------------------------------------------------------------------;
; Compare an equipment flag
;----------------------------------------------------------------------------;
; Input:
;	FLAG = field name from EQUIP_FLAGS RECORD
;	FVAL = value to compare
;	SET_BDA = if defined, saves CX and sets DS = BDA
;		otherwise assumes DS = BDA and clobbers CX
; Output: AX = flag value
;
; Note: flags must not cross byte boundary (which they don't)
;----------------------------------------------------------------------------;
CMP_EFLAG	MACRO	FLAG, FVAL, SET_BDA
		LOCAL FLAG_MASK, FLAG_BIT, FLAG_MEM
			IFNB <SET_BDA>
	PUSH	CX					; save CX
	PUSH	DS
	MOV	CX, SEG _BDA			; DS = BDA
	MOV	DS, CX
			ENDIF

;----------------------------------------------------------------------------;
; Shift if flag is in high byte to low for byte operations
;
			IF FLAG LT 8		; is in low byte?
FLAG_MASK	= MASK FLAG
FLAG_BIT	= FLAG AND 0111B
FLAG_MEM	= EQUIP_FLAGS[0]			; low BDA flags byte
			ELSE				; is in high byte
FLAG_MASK	= HIGH MASK FLAG
FLAG_BIT	= (FLAG - 8) AND 0111B
FLAG_MEM	= EQUIP_FLAGS[1]			; high BDA flags byte
			ENDIF

	MOV	AL, BYTE PTR FLAG_MEM
	AND	AL, FLAG_MASK
	CMP	AL, FVAL SHL FLAG_BIT

			IFNB <SET_BDA>
	POP	DS
	POP	CX
			ENDIF
		ENDM

;----------------------------------------------------------------------------;
; Get an equipment flag
;----------------------------------------------------------------------------;
; Input:
;	FLAG = field name from EQUIP_FLAGS RECORD
;	SET_BDA = if defined, saves CX and sets DS = BDA
;		otherwise assumes DS = BDA and clobbers CX if 3 or 4 shifts
;	OUT_AL = do not clear AH
; Output: AX = flag value
;
; Note: flags must not cross byte boundary (which they don't)
;----------------------------------------------------------------------------;
GET_EFLAG	MACRO	FLAG, SET_BDA, OUT_AL
		LOCAL FLAG_MASK, FLAG_BIT, FLAG_MEM
			IFNB <SET_BDA>
	PUSH	CX					; save CX
	PUSH	DS
	MOV	CX, SEG _BDA			; DS = BDA
	MOV	DS, CX
			ENDIF

;----------------------------------------------------------------------------;
; Shift if flag is in high byte to low for byte operations
;
			IF FLAG LT 8		; is in low byte?
FLAG_MASK	= MASK FLAG
FLAG_BIT	= FLAG AND 0111B
FLAG_MEM	= EQUIP_FLAGS[0]			; low BDA flags byte
				IF FLAG + WIDTH FLAG GT 8
					.ERR
					%OUT ERROR: BDA EQFLAG crosses byte boundary
				ENDIF
			ELSE				; is in high byte
FLAG_MASK	= HIGH MASK FLAG
FLAG_BIT	= (FLAG - 8) AND 0111B
FLAG_MEM	= EQUIP_FLAGS[1]			; high BDA flags byte
			ENDIF

	MOV	AL, BYTE PTR FLAG_MEM		; AL = equipment flag byte
			IF OUT_AL EQ 1
	AND	AL, FLAG_MASK			; isolate bits, preserve AH
			ELSE
	AND	AX, FLAG_MASK			; isolate bits, clear AH
			ENDIF

;----------------------------------------------------------------------------;
; Determine optimal number of shifts based on bit position and shift
; right or left depending on fewest.
;
			IF CPU_TYPE	EQ CPU_V20
				IF FLAG_BIT GT 4
	ROL	AL, 8-FLAG_BIT			; shift value into position
				ELSE
					IF FLAG_BIT EQ 4
	ROL4	AL					; shift value into position
					ELSE
						IF FLAG_BIT GT 0
	ROR	AL, FLAG_BIT			; shift value into position
						ENDIF
					ENDIF
				ENDIF
			ELSE
				IF FLAG_BIT GT 4	; optimal to roll left
					FLAG_BIT = 8-FLAG_BIT
					IF FLAG_BIT GT 2	; 3-4 shifts use CL
	MOV	CL, FLAG_BIT			; CL = bit(s) position of record
	ROL	AL, CL				; shift value into position
					ELSE		; 0-2 shifts use single op(s)
						REPT FLAG_BIT
	ROL	AL, 1					; shift value into position
						ENDM
					ENDIF
				ELSE			; optimal to roll right
					IF FLAG_BIT GT 2
	MOV	CL, FLAG_BIT			; CL = bit(s) position of record
	ROR	AL, CL				; shift value into position
					ELSE
						REPT FLAG_BIT
	ROR	AL, 1					; shift value into position
						ENDM
					ENDIF
				ENDIF
			ENDIF
			IFNB <SET_BDA>
	POP	DS
	POP	CX
			ENDIF
		ENDM

;----------------------------------------------------------------------------;
; Set an equipment flag
;----------------------------------------------------------------------------;
; Input: 
;	AL = flag value (clobbered)
;	FLAG = field name from EQUIP_FLAGS RECORD
;	SET_BDA = if defined, saves CL and set DS = BDA 
;		otherwise *requires* DS = BDA and CL clobbered
; Output: none
;----------------------------------------------------------------------------;
SET_EFLAG	MACRO	FLAG, SET_BDA
			IFNB	<SET_BDA>
	PUSH	CX
	PUSH	DS
	MOV	CX, SEG _BDA			; DS = BDA
	MOV	DS, CX
			ENDIF

			IF FLAG LT 8		; is in low byte?
FLAG_MASK	= MASK FLAG
FLAG_BIT	= FLAG AND 111B
FLAG_MEM	= EQUIP_FLAGS[0]			; low BDA flags byte
			ELSE				; is in high byte
FLAG_MASK	= HIGH MASK FLAG
FLAG_BIT	= (FLAG - 8) AND 0111B
FLAG_MEM	= EQUIP_FLAGS[1]			; high BDA flags byte
			ENDIF

	AND	AL, MASK FLAG SHR FLAG		; isolate flag's bit width

;----------------------------------------------------------------------------;
; Determine optimal number of shifts based on bit position and shift
; right or left depending on fewest.
;
			IF CPU_TYPE	EQ CPU_V20
				IF FLAG_BIT GT 4
	ROR	AL, 8-FLAG_BIT			; shift value into position
				ELSE
	ROL	AL, FLAG_BIT			; shift value into position
				ENDIF
			ELSE
				IF FLAG_BIT GT 4
	MOV	CL, 8-FLAG_BIT			; CL = bit(s) position of record
	ROR	AL, CL				; shift value into position
				ELSE
	MOV	CL, FLAG_BIT			; CL = bit(s) position of record
	ROL	AL, CL				; shift value into position
				ENDIF
			ENDIF

	AND	BYTE PTR FLAG_MEM, NOT FLAG_MASK	; clear existing bits(s)
	OR	BYTE PTR FLAG_MEM, AL			; set new bit(s)

			IFNB <SET_BDA>
	POP	DS
	POP	CX
			ENDIF
		ENDM

;----------------------------------------------------------------------------;
; Test a single BDA equipment flag
;----------------------------------------------------------------------------;
; Input: FLAG = field name from EQUIP_FLAGS RECORD
; Output: ZF if 0, NZ if 1
;
; Requires: DS = BDA
;----------------------------------------------------------------------------;
TEST_EFLAG	MACRO	FLAG
			IF FLAG LT 8
	TEST	BYTE PTR EQUIP_FLAGS, LOW MASK FLAG
			ELSE
	TEST	BYTE PTR EQUIP_FLAGS[1], HIGH MASK FLAG
			ENDIF
		ENDM

;----------------------------------------------------------------------------;
; Set a single GLaBIOS flag
;----------------------------------------------------------------------------;
; Input:
;	FLAG = field name from GB_FLAGS RECORD
;	FLAG_CLR = if set, zeros flags first
; Requires: DS = BDA
;----------------------------------------------------------------------------;
SET_GFLAG	MACRO	FLAG, FLAG_CLR
			IFNB	<FLAG_CLR>
	AND	GB_FLAGS, MASK FLAG		; clear existing flag(s)
			ENDIF
	OR	GB_FLAGS, MASK FLAG		; set flag(s)
		ENDM

;----------------------------------------------------------------------------;
; Set a single GLaBIOS flag
;----------------------------------------------------------------------------;
; Input:
;	FLAG = field name from GB_FLAGS RECORD
;	FLAG_CLR = if set, zeros flags first
; Requires: DS = _BDA_ABS (0000H)
;----------------------------------------------------------------------------;
SET_GFLAG_ABS	MACRO	FLAG, FLAG_CLR
			IFNB	<FLAG_CLR>
	AND	GB_FLAGS_ABS, MASK FLAG		; clear existing flag(s)
			ENDIF
	OR	GB_FLAGS_ABS, MASK FLAG		; set flag(s)
		ENDM

;----------------------------------------------------------------------------;
; Test a single GLaBIOS flag
;----------------------------------------------------------------------------;
; Input:
;	FLAG = field name from GB_FLAGS RECORD
; Output: ZF if 0, NZ if 1
;
; Requires: DS = BDA
;----------------------------------------------------------------------------;
TEST_GFLAG	MACRO	FLAG
	TEST	GB_FLAGS, MASK FLAG
		ENDM

;----------------------------------------------------------------------------;
; Test a single GLaBIOS flag
;----------------------------------------------------------------------------;
; Input:
;	FLAG = field name from GB_FLAGS RECORD
; Output: ZF if 0, NZ if 1
;
; Requires: DS = BDA
;----------------------------------------------------------------------------;
TEST_GFLAG_ABS	MACRO	FLAG
	TEST	GB_FLAGS_ABS, MASK FLAG
		ENDM

;----------------------------------------------------------------------------;
; Clear a single GLaBIOS flag
;----------------------------------------------------------------------------;
; Input:
;	FLAG = field name from GB_FLAGS RECORD
; Requires: DS = _BDA_ABS (0000H)
;----------------------------------------------------------------------------;
CLR_GFLAG_ABS	MACRO	FLAG
	AND	GB_FLAGS_ABS, NOT MASK FLAG		; clear existing flag
		ENDM

;----------------------------------------------------------------------------;
; Clear a single GLaBIOS flag
;----------------------------------------------------------------------------;
; Input:
;	FLAG = field name from GB_FLAGS RECORD
; Requires: DS = _BDA (0040H)
;----------------------------------------------------------------------------;
CLR_GFLAG	MACRO	FLAG
	AND	GB_FLAGS, NOT MASK FLAG		; clear existing flag
		ENDM

;----------------------------------------------------------------------------;
; Shortcut to write a null-terminated string to console
;----------------------------------------------------------------------------;
; Input:
;	SZ = string to print
;	SAVE_REGS = define (anything) to preserve SI (cost of 2 bytes)
;----------------------------------------------------------------------------;
PRINT_SZ	MACRO	SZ, SAVE_REGS
		IFNB	<SAVE_REGS>
	PUSH	SI					; save SI
		ENDIF
		IFDIFI <SZ>,<SI>			; if SZ is not SI
	MOV	SI, OFFSET SZ
		ENDIF
	CALL	OUT_SZ
		IFNB	<SAVE_REGS>
	POP	SI
		ENDIF
		ENDM

;----------------------------------------------------------------------------;
; Same as above but print CRLF at the end
;----------------------------------------------------------------------------;
; Input:
;	SZ = string to print
;	SAVE_REGS = define (anything) to preserve SI (cost of 2 bytes)
;
; If called as PRINTLN_SZ SI, will use SI (effectively an alias to 
;	'CALL OUTLN_SZ')
;----------------------------------------------------------------------------;
PRINTLN_SZ	MACRO	SZ, SAVE_REGS
		IFNB	<SAVE_REGS>
	PUSH	SI					; save SI
		ENDIF
		IFDIFI <SZ>,<SI>			; if SZ is not SI
	MOV	SI, OFFSET SZ
		ENDIF
	;CALL	OUTLN_SZ
	CALL	OUT_SZ_NL
		IFNB	<SAVE_REGS>
	POP	SI
		ENDIF
		ENDM

;----------------------------------------------------------------------------;
; Set text attribute for a block of chars starting at current cursor
;----------------------------------------------------------------------------;
; This is a more efficient way to set text colors so any normal way to write
; to console may be used.
;
; Example usage:
;   SET_SZ_ATTR 0EH, 10			; set attribute to 0EH for next 10 chars
;
; Code size:
; 	16 bytes if registers NOT saved
;	22 bytes if registers saved
; 	-3 bytes if ATTR is BL
;----------------------------------------------------------------------------;
SET_SZ_ATTR	MACRO	ATTR, LN, SAVE_REGS
			IF POST_THEME NE 0	; if color enabled
		IFNB	<SAVE_REGS>
	PUSH	AX
	PUSH	BX
	PUSH	CX
		ENDIF ; IFNB
	MOV	AX, DBW <9, VID_SP>	; AH = write char w/attr, AL = space
		IFDIFI <ATTR>,<BL>	; if ATTR is not BL
	MOV	BX, LOW ATTR		; BH = video page 0, BL = attribute
		ENDIF	; IFDIFI
	MOV	CX, LN			; CX = repeat times
	INT	10H
		IFNB	<SAVE_REGS>
	POP	CX
	POP	BX
	POP	AX
		ENDIF	; IFNB
			ENDIF
		ENDM

;----------------------------------------------------------------------------;
; POST column UI
;----------------------------------------------------------------------------;
POST_COL_1	MACRO LBL_STR, INNER_ATTR, SAVE_REGS, ZERO_BH
		IFNB	<SAVE_REGS>
	PUSH	BX					; save BX
		ENDIF
		IFNB	<ZERO_BH>
	MOV	BX, LOW INNER_ATTR		; BH = 0, BL = attribute
		ELSE
	MOV	BL, LOW INNER_ATTR		; BL = attribute
		ENDIF
	MOV	SI, OFFSET LBL_STR
	CALL	POST_START_COL_1
		IFNB	<SAVE_REGS>
	POP	BX
		ENDIF

		ENDM

POST_COL_2	MACRO LBL_STR, INNER_ATTR, SAVE_REGS, ZERO_BH
		IFNB	<SAVE_REGS>
	PUSH	BX					; save BX
		ENDIF
		IFNB	<ZERO_BH>
	MOV	BX, LOW INNER_ATTR		; BH = 0, BL = attribute
		ELSE
	MOV	BL, LOW INNER_ATTR		; BL = attribute
		ENDIF
	MOV	SI, OFFSET LBL_STR
	CALL	POST_START_COL_2
		IFNB	<SAVE_REGS>
	POP	BX
		ENDIF
		ENDM

POST_COL_END	MACRO	SAVE_REGS
		IFNB	<SAVE_REGS>
	PUSH	BX					; save BX
		ENDIF
	CALL	POST_END_COL
		IFNB	<SAVE_REGS>
	POP	BX
		ENDIF
		ENDM

POST_COL_END_NL	MACRO SAVE_REGS
		IFNB	<SAVE_REGS>
	PUSH	BX					; save BX
		ENDIF
	CALL	POST_END_COL_NL
		IFNB	<SAVE_REGS>
	POP	BX
		ENDIF
		ENDM

;----------------------------------------------------------------------------;
; Write to POST status card, if enabled
;----------------------------------------------------------------------------;;
; Input: AL (default) or imm8
;
; Clobbers AL if imm8
;----------------------------------------------------------------------------;
POST_CARD EQU 1
POST_CODE	MACRO	CODE
		IF POST_CARD EQ 1
			IFNB	<CODE>		; if CODE is not blank
			IFDIFI <CODE>,<AL>	; if CODE is not AL
	MOV	AL, LOW CODE
			ENDIF
			ENDIF
	OUT	POST_CARD_PORT, AL
		ENDIF
		ENDM

POST_CODE_H	MACRO	CODE
		IF POST_CARD EQ 1
			IFNB	<CODE>		; if CODE is not blank
			IFDIFI <CODE>,<AL>	; if CODE is not AL
	MOV	AL, LOW CODE
			ENDIF
			ENDIF
	OUT	POST_CARD_PORT+1, AL
		ENDIF
		ENDM


;----------------------------------------------------------------------------;
; x86/V20 Instruction MACROs
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; AAM, AAD with immediate other than 0AH
;
AAM_I		MACRO	IMM
	;DB	0D4H, IMM			; AAM	imm
	AAM
			IF IMM NE 0AH
		ORG	$-1
	DB	IMM				;; replace second opcode byte
			ENDIF
		ENDM

AAD_I		MACRO	IMM
	;DB	0D5H, IMM			; AAD	imm
	AAD
			IF IMM NE 0AH
		ORG	$-1
	DB	IMM				;; replace second opcode byte
			ENDIF
		ENDM

;----------------------------------------------------------------------------;
; V20 MACROs for instruction mnemonics not supported by MASM
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; V20_R General Purpose Register operands
;
V20_R		RECORD	VRW:5, ROPC:3

;----------------------------------------------------------------------------;
; Format 3 - Single Register OPC, Variant 1
;
V20_F3	RECORD	VF3_OPC:5=11000b, VF3_SRC:3

;----------------------------------------------------------------------------;
; Registers used as operands for V20 MACROs
;
V_AL	EQU	V20_R	<, 000b>		; reg8
V_CL	EQU	V20_R <, 001b>
V_DL	EQU	V20_R <, 010b>
V_BL	EQU	V20_R <, 011b>
V_AH	EQU	V20_R <, V_AL OR 100b>
V_CH	EQU	V20_R <, V_CL OR 100b>
V_DH	EQU	V20_R <, V_DL OR 100b>
V_BH	EQU	V20_R <, V_BL OR 100b>
V_AX	EQU	V20_R <1, V_AL>		; reg16
V_CX	EQU	V20_R <1, V_CL>
V_DX	EQU	V20_R <1, V_DL>
V_BX	EQU	V20_R <1, V_BL>
V_SP	EQU	V20_R <1, V_AH>
V_BP	EQU	V20_R <1, V_CH>
V_SI	EQU	V20_R <1, V_DH>
V_DI	EQU	V20_R <1, V_BH>

;----------------------------------------------------------------------------;
; Format 1 - Opcode with Size (Byte/Word)
;
V20_OP1	MACRO OP, REG, IMM
		LOCAL W, R

		IFDEF V_&REG				;; Is REG defined as V20 V_REG?
	R	= V_&REG					; R = V20 register opcode
	W	= (R AND MASK VRW) SHR VRW		; W=1 if 16, 0 if 8
	DB	0FH, OP OR W				; register Width
	V20_F3 <, R AND MASK ROPC >			; dest register
			IFNB <IMM>
	DB	IMM
			ENDIF

		ELSE						;; V_REG not defined as V20 register
	.ERR
	%OUT	REG& not defined
		ENDIF

		ENDM

TEST1		MACRO R, IMM
	V20_OP1	18H, R, IMM
		ENDM

SET1		MACRO R, IMM
	V20_OP1	1CH, R, IMM
		ENDM

CLR1		MACRO R, IMM
	V20_OP1	1AH, R, IMM
		ENDM

NOT1		MACRO R, IMM
	V20_OP1	1EH, R, IMM
		ENDM

;----------------------------------------------------------------------------;
; ROL4: roll nibbles left in AL through R8
;----------------------------------------------------------------------------;
; R8(low nibble)  = AL(low nibble)
; R8(high nibble) = R8(low nibble)
; AL(low nibble)  = R8(high nibble)
; AL(high nibble) clobbered
;----------------------------------------------------------------------------;
ROL4		MACRO R8
	V20_OP1	28H, R8					; ROL4
		ENDM

;----------------------------------------------------------------------------;
; ROR4: roll nibbles right in AL through R8
;----------------------------------------------------------------------------;
; R8(high nibble) = AL(low nibble)
; R8(low nibble)  = R8(high nibble)
; AL(low nibble)  = R8(low nibble)
; AL(high nibble) clobbered
;----------------------------------------------------------------------------;
ROR4		MACRO R8
	V20_OP1	2AH, R8					; ROR4
		ENDM

;----------------------------------------------------------------------------;
; PUSH multiple (X number of) registers (up to 8)
;----------------------------------------------------------------------------;
PUSHX	MACRO r1, r2, r3, r4, r5, r6, r7, r8
			IFNB <r1>			; exit if last reg
	PUSH	r1 					; push register and repeat
	PUSHX	r2, r3, r4, r5, r6, r7, r8
			ENDIF
		ENDM

;----------------------------------------------------------------------------;
; POP multiple registers (up to 8)
;----------------------------------------------------------------------------;
POPX	MACRO r1, r2, r3, r4, r5, r6, r7, r8
			IFNB <r1>			; exit if last reg
	POP	r1 					; pop register and repeat
	POPX	r2, r3, r4, r5, r6, r7, r8
			ENDIF
		ENDM
