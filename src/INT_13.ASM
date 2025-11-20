	PAGE		59,132
	TITLE		GLaDISK_INT_13

;----------------------------------------------------------------------------;
; GLaDISK (Gizmo Linkage and Dynamic Information Storage Keeper)
;
; INT 13H - Diskette BIOS standard Services
;----------------------------------------------------------------------------;
INCLUDE 	GLADISK.INC
INCLUDE	INT_13.INC

;----------------------------------------------------------------------------;
; Start of segment
;----------------------------------------------------------------------------;
OPTROM	SEGMENT BYTE PUBLIC 'CODE'
		ASSUME  DS:OPTROM, SS:OPTROM, CS:OPTROM, ES:OPTROM

;----------------------------------------------------------------------------;
; GLaLIB EXTRN PROCs
;----------------------------------------------------------------------------;
EXTRN		IO_WAIT_MS_125:NEAR, IO_DELAY_MS_FDC:NEAR
			IF IRET_FLAGS EQ 1
EXTRN		IRET_CF:NEAR, IRET_CF_BP:NEAR
			ENDIF
			IF USE_FDC_DEBUG EQ 1
EXTRN		FDC_DEBUG:NEAR
			ENDIF

			IF FDC_HD_ENABLE EQ 1
;----------------------------------------------------------------------------;
; INT_13_H EXTRN PROCs
;----------------------------------------------------------------------------;
EXTRN		INT_13_HD:NEAR
EXTRN		FD_CMOS_TBL:NEAR
EXTRN		FD_TBL:NEAR
EXTRN		FD_RESET_STATE:NEAR
EXTRN		INT_13_2_5_HD_SETUP:NEAR
EXTRN		FDC_NSC_MODE:NEAR
			ENDIF

;----------------------------------------------------------------------------;
; INT_13 PUBLIC PROCs
;----------------------------------------------------------------------------;
PUBLIC	INT_13		; INT 13H ISR entry point
PUBLIC	FDC_MOTOR_ON	; Turn on motor
PUBLIC	FDC_SEEK		; Seek to track
PUBLIC	FDC_RECAL		; Turn on motor and recal if necessary
PUBLIC	FDC_RECAL_DBL	; Turn on motor and recal twice if necessary
PUBLIC	FDC_RESET		; Reset FDC
PUBLIC	FDC_SEND		; Send command byte to FDC
PUBLIC	FDC_SEND_PARAM	; Send command byte to FDC from DBT
PUBLIC	FDC_RECV_ALL	; Receive all result bytes from FDC to BDA
PUBLIC	FDC_WAIT_STATUS	; Wait for WIF, get result and check for error

;----------------------------------------------------------------------------;
; INT 13H - Diskette BIOS Services
;----------------------------------------------------------------------------;
;	INT 13,0  Reset disk system
;	INT 13,1  Get disk status
;	INT 13,2  Read disk sectors
;	INT 13,3  Write disk sectors
;	INT 13,4  Verify disk sectors
;	INT 13,5  Format disk track
;
;  Typical params:
;	AH = function request number
;	AL = number of sectors	(1-128)
;	CH = cylinder number	(0-1023)
;	CL = sector number	(1-17)
;	DH = head number		(0-15)
;	DL = drive number		(0=A:, 1=B:, 80H=C:, 81H=D:) (for AH=2-5)
;	ES:BX = address of user buffer
;
;  Output:
;	CF = 0 if successful
;	   = 1 if error
;	AH = status of operation (https://stanislavs.org/helppc/int_13-1.html)
;
;----------------------------------------------------------------------------;
;  All functions:
;	- return FD_LAST_OP ([41H]) in AH
;	- set CF if error
;	- reset motor shutoff counter
;
;  Reference:
;	https://stanislavs.org/helppc/int_13.html
;	https://stanislavs.org/helppc/765.html
;	NEC Microcomputers, Inc. PD765C Application Note 8 (Mar 1979)
;
;  Ports:
;	3F0-3F7 Floppy disk controller (except PCjr)
;	3F0 Diskette controller status A
;	3F1 Diskette controller status B
;	3F2 controller control port
;	3F4 controller status register
;	3F5 data register (write 1-9 byte command, see INT 13)
;	3F6 Diskette controller data
;	3F7 Diskette digital input
;
;----------------------------------------------------------------------------;
		ASSUME DS:_BDA
INT_13 PROC
	STI 						; enable interrupts
	CLD
	;FD_DEBUG 'I13'
	PUSHX	BP, DS, DI				; save caller registers
	MOV	DI, SEG _BDA			; DS = BDA
	MOV	DS, DI
	INC	DI					; DI = FD_LAST_OP throughout
	AND	_FD_MOTOR_ST, NOT MASK FWRT	; clear write operation flag
	CMP	AH, 1 				; AH = 1?
	JE	INT_13_1 				; AH = 1, jump to Status
	PUSHX	DX, CX, BX				; save working registers
	MOV	BP, SP				; set up stack frame
	MOV	_FD_LAST_OP, FDC_ST_OK		; clear last operation status
	JB	INT_13_0 				; AH = 0, jump to Reset
			IF FDC_HD_ENABLE EQ 0
	CMP	DL, FDC_MAX_DRIVES-1		; is drive number > 3?
	JA	INT_13_BAD_CMD 			; if so, exit
			ENDIF
	CMP	AH, 6 				; AH = 2 through 5?
	JB	INT_13_2_5 				; jump to FDC RWVF command
			IF FDC_HD_ENABLE EQ 1
				IF CPU_TYPE EQ CPU_186 OR CPU_TYPE EQ CPU_V20
	PUSH	OFFSET INT_13_HD_DONE		; set return address
	JMP	INT_13_HD				; try HD function
				ELSE
	CALL	INT_13_HD				; otherwise try HD function
	JMP	SHORT INT_13_HD_DONE		; do not set return CF from AH
				ENDIF
			ENDIF
INT_13_BAD_CMD:
	INC	_FD_LAST_OP				; otherwise return "bad command" (1)
INT_13_DONE:
	MOV	AH, _FD_LAST_OP 			; AH = last operation status
INT_13_SET_MOTOR_CT:
	CMP	AH, FDC_ST_OK+1			; check AH for error (CF = AH < 1)
	CMC   					; invert CF for return (CF = ! CF)
			IF USE_FDC_DEBUG EQ 1
	JNC	INT_13_HD_DONE
INT_13_ERR:
	FD_DEBUG 'ER'
	;EXTRN	FDC_DUMPREG:NEAR
	;PUSHF
	;CALL	FDC_DUMPREG
	;POPF
			ENDIF
INT_13_HD_DONE:
	XCHG	AX, BX				; save AL/AH
	MOV	AL, DBT.FMCT 			; INT_1E[2] = motor shutoff counter
	CALL	INT_1E_PARAM 			; AL = shutoff counter value (37)
	MOV	FD_MOTOR_CT, AL 			; update in BDA
	XCHG	AX, BX				; restore AL/AH
INT_13_EXIT:
	POPX	BX, CX, DX				; restore caller registers
INT_13_EXIT_1:
	POPX	DI, DS
	IRET_F_BP					; return from INT with current CF
							;  IF=1 and POP BP

;----------------------------------------------------------------------------;
; INT 13, 0: Reset disk system
;----------------------------------------------------------------------------;
; Performs hard reset on FDC controller
;
; Input:
;	AH = 00
;	DL = drive number (0=A:, 1=2nd floppy, 80h=drive 0, 81h=drive 1)
;		(unused - drive is determined by BDA motor status)
;
; Output:
;	AH = disk operation status  (see INT 13,STATUS)
;	CF = 0 if successful
;	   = 1 if error
;----------------------------------------------------------------------------;
; Things you must do:
;
;	- if a motor flag is on in BDA, turn it on in the FDC also
;	- clear reset flag in controller
;	- set ALL disks need recalibration on next seek
;	- setting the controller reset flag causes the disk to recalibrate
;	  	on the next disk operation
;	- if bit 7 is set, the diskette drive indicated by the lower 7 bits
;		will reset then the hard disk will follow; return code in AH is
;		for the drive requested (this is done by hard drive BIOS)
;
; Things you must do HD:
; 	- reset data rate (CCR)
;----------------------------------------------------------------------------;
INT_13_0 PROC
	CALL	FDC_RESET				; reset FDC

;----------------------------------------------------------------------------;
; Exit and return with AL = 0
;
INT_13_0_DONE:
	MOV	AL, 0					; 0 sectors read
	JMP	SHORT INT_13_DONE
INT_13_0 ENDP

;----------------------------------------------------------------------------;
; INT 13, 1: Get disk status
;----------------------------------------------------------------------------;
; Output:
;	AL and AH = status of last operation
;	CF if last operation error
;----------------------------------------------------------------------------;
INT_13_1 PROC
	MOV	AL, _FD_LAST_OP 			; AL = last operation status
	MOV	AH, AL				; AH = last operation status
	JMP	SHORT INT_13_EXIT_1
INT_13_1 ENDP

;----------------------------------------------------------------------------;
; DMA page boundary overrun
;
FDC_DMA_BOUND:
	OR	_FD_LAST_OP, FDC_ST_DMA_64K	; DMA boundary error
	STC						; re-set CF
	JMP	SHORT FDC_INIT_DMA_EXIT		; rebalance stack and exit
	;JMP	NEAR PTR FDC_INIT_DMA_EXIT			; rebalance stack and exit

;----------------------------------------------------------------------------;
; Calculate DMA size for Format operation
;
FDC_INIT_DMA_FMT:
	MOV	AL, AH				; AL = sectors to read
	CBW						; AX = sectors to read
	MOV	CL, 2					; track address fields block
	JMP	SHORT FDC_INIT_DMA_1		;  = four bytes per sector

;----------------------------------------------------------------------------;
; INT 13, AH=2-5: FDC read/write operations
;----------------------------------------------------------------------------;
; All commands:
;
; 	AL = number of sectors to read  (1-128 dec.)
;	AH = function number
;	CH = track/cylinder number  (0-1023 dec., see below)
;	CL = sector number  (1-17 dec.)
;	DH = head number  (0-15 dec.)
;	DL = drive number (0=A:, 1=2nd floppy, 80h=drive 0, 81h=drive 1)
;	ES:BX = pointer to buffer
;----------------------------------------------------------------------------;
; Things you must do:
;
;	1. Set FD_MOTOR_ST read/write flag for operation
;	2. Motor ON (update BDA)
;		- is motor already on? Skip wait for spin up
;		- wait only for writes?
;		- check if recalibration is necessary
;	3. Set up DMA
;	4. seek drive DL to cylinder CH, head DH
; 	5. send command
;	6. wait for interrupt
;	7. fetch results
;	8. Check FDC status bytes for result
;
; Things you should do:
;	- Check if drive is valid? Check if exists in BDA and not a hard drive
;
;----------------------------------------------------------------------------;
INT_13_2_5 PROC
			IF FDC_HD_ENABLE EQ 1
	CMP	DL, FDC_MAX_DRIVES-1		; is drive number > 3?
	JA	INT_13_BAD_CMD 			; if so, exit
			ENDIF
	XCHG	AL, AH				; AL = function, AH = sectors to read
	PUSH	AX					; save function, sector count
	PUSH	DX					; save head, drive

			IF FDC_HD_ENABLE EQ 1
;----------------------------------------------------------------------------;
; Setup for HD disk functions
;----------------------------------------------------------------------------;
	TEST	_FDC_CAP, MASK FHD		; adapter supports HD?
	JZ	INT_13_2_5_HD_SETUP_SKIP	; skip if not
	CALL	INT_13_2_5_HD_SETUP
	JC	INT_13_2_5_SEEK_ERR		; exit if disk changed
INT_13_2_5_HD_SETUP_SKIP:
			ENDIF

;----------------------------------------------------------------------------;
; Set up DMA modes for INT 13H functions
;
	MOV	DH, DMA_MR <1,0,0,1,2> 		; set DMA read mode 1 (AH = 2)
	CMP	AL, 2					; is read?
	JE	INT_13_2_5_SETUP_DMA		; if so, proceed to setup
	MOV	DH, DMA_MR <1,0,0,0,2> 		; set DMA verify mode 0 (AH = 4)
	CMP	AL, 4					; is verify?
	JE	INT_13_2_5_SETUP_DMA		; if so, proceed to setup
	MOV	DH, DMA_MR <1,0,0,2,2> 		; else DMA write/format mode 2 (AH = 3,5)
	OR	_FD_MOTOR_ST, MASK FWRT		; turn on write flag
INT_13_2_5_SETUP_DMA:

			IF FDC_EIS EQ 1
;----------------------------------------------------------------------------;
; If EIS supported, do not seek. Only check if RECAL is needed.
;
	PUSH	AX
	CALL	FDC_EIS_SEEK			; Turn on motor, seek or recal if EIS
	POP	AX
			ELSE
	CALL	FDC_SEEK 				; Turn on motor, CH = track, DL = drive
			ENDIF
	JC	INT_13_2_5_SEEK_ERR		; exit if seek error
							; fall through to set up DMA

;----------------------------------------------------------------------------;
; FDC_INIT_DMA: Configure DMA channel 2 for FDC operation
;----------------------------------------------------------------------------;
; Input:
;  AL = INT 13h function 2-5
;  AH = sectors to read
;  DH = DMA mode:
;	01000110 (46H) - Read
;	01000010 (42H) - Verify
;	01001010 (4AH) - Write
; 	01 			; Mode: Single mode select
; 	  0  			; Address increment
;	   0 			; Auto-initialization disable
;	    xx		; 00=verify, 01=write, 10=read, 11=unused
;	      10		; Channel 2 select
;  ES:BX = pointer to buffer
;
; Output:
;  CF = 0 success, 1 if error DMA exceeds segment
;----------------------------------------------------------------------------;
; Things you must do:
;	- Calculate # of bytes to transfer by multiplying AL (sectors) by
;		sector size in INT 1E Disk Base Table.
;	- Calculate physical memory address from ES:BX and normalize to
;		Paragraph:Offset (P:FFFFH).
;	- Verify that Offset + Byte Count does not exceed the remaining
;		space in that paragraph. The DMA controller can only select one
;		paragraph bank at a time, so writes will NOT wrap to next para.
;		Exit with DMA Boundary error if segment is exceeded.
;	- Reset the high/low byte flip-flop (send any value to I/O port 0CH)
;	- Set DMA mode for Channel 2 to either Verify, Read or Write/Format
;	- Disable interrupts while programming DMA
;	- Set the DMA Page (memory paragraph) for DMA channel 2 (I/O port 81H)
;	- Set the DMA Byte Counter to size of transfer minus 1 (since
;		DMA's counter is 0-indexed)
;	- Set the DMA Address register to beginning of DMA buffer from ES:BX
;	- Enable interrupts and unmask DMA Channel 2
;
;----------------------------------------------------------------------------;
; References:
;  https://pdf1.alldatasheet.com/datasheet-pdf/view/127822/AMD/8237A.html
;  https://wiki.osdev.org/ISA_DMA#Floppy_Disk_DMA_Initialization
;  https://stackoverflow.com/questions/52396915/how-to-write-assembly-language-to-make-dma-works
;  https://userpages.umbc.edu/~squire/intel_book.pdf
;----------------------------------------------------------------------------;
FDC_INIT_DMA:
	PUSH	CX					; save track / sector
	CMP	AL, 5					; is format?
	PUSHF						; save ZF if format
	MOV	AL, DH				; AL = DMA mode
	MOV	DX, ES 				; get and shift ES by one nibble
			IF CPU_TYPE EQ CPU_V20 OR CPU_TYPE EQ CPU_186
	ROL	DX, 4					; V20/186 only
			ELSE
	MOV	CL, 4					; DL = lowest and highest nibble of ES
	ROL	DX, CL				; DH = middle nibbles
			ENDIF
	OUT	DMA_MODE, AL			; write to DMA mode reg (port 0BH)
	POPF						; ZF if format
	JE	FDC_INIT_DMA_FMT			; only calculate TAF block size for format

;----------------------------------------------------------------------------;
; Calculate DMA size for Read/Write/Verify operations
;
	XOR	AL, AL				; AX = sectors to read << 8
	XCHG	AX, CX				; CX = sectors, AX = scratch
	MOV	AL, DBT.FBPS			; get bytes/sector param (0=128, 1=256, 2=512, 3=1024)
	CALL	INT_1E_PARAM			; AL = shift count (default 2 => 512)
	XCHG	AX, CX				; AX = sectors, CL = bytes per sector shifts
	SHR	AX, 1					; adjust shift for bytes/sector * 128

FDC_INIT_DMA_1:
	SHL	AX, CL				; AX = bytes to transfer (AX * 2^CL)
	DEC	AX					; AX = bytes to transfer - 1
	XCHG	AX, CX				; CX = bytes to transfer - 1
	MOV	AL, DL				; AL = lowest and highest nibble of ES
	AND	AL, 0FH				; AL = only high nibble of ES
	AND	DL, 0F0H				; DX = low three nibbles of ES (shifted left 1 nibble)
	ADD	BX, DX				; BX = DMA start offset for transfer
	ADC	AL, 0					; AL = DMA page
	MOV	DX, BX				; check that buffer offset + length does not exceed segment
	ADD	DX, CX				; DX = DMA end offset, test for boundary overflow
	JC	FDC_DMA_BOUND			; error if DMA access across 64k boundary
	CLI						; Disable interrupts
	OUT	DMA_FF, AL				; DMA clear flip-flop (port 0CH) (any value)
	OUT	DMA_P_C2, AL 			; set DMA Channel 2 Page Address Register (port 81H)
	XCHG	AX, BX				; AL = address low byte, AH = high byte
	OUT	DMA_2_A, AL				;
	XCHG	AL, AH 				; AH = address low byte, AL = high byte
	OUT	DMA_2_A, AL				;
	XCHG	AX, CX				; AL = byte/count low byte, AH = high byte
	OUT	DMA_2_C, AL				;
	XCHG	AL, AH				; AH = byte/count low byte, AL = high byte
	OUT	DMA_2_C, AL
	STI						; Enable interrupts
	MOV	AL, DMA_SMR <0, 2>		; DMA clear single channel 2 mask bit
	OUT	DMA_MASK, AL			; Unmask DMA Channel 2 (port 0AH)
FDC_INIT_DMA_EXIT:
	POP	CX					; CL = sector, CH = track
INT_13_2_5_SEEK_ERR:
	POP	DX 					; DL = drive, DH = head
	POP	AX					; AL = function, AH = sectors to read
	JC	FDC_DMA_ERR				; exit if DMA error with AL = 0

;----------------------------------------------------------------------------;
; Set FDC command byte
;
	MOV	BL, FDC_CB <1,,0,FDC_CMD_WR>	; FDC Write Data - Multi-Track, MFM
	CMP	AL, 3 				; is write (AH=3)?
	JE	FDC_RWVF				; jump if write
	MOV	BL, FDC_CB <0,,0,FDC_CMD_FMT>	; FDC Format Track - Single-Track, MFM
	CMP	AL, 5 				; is format (AH=5)?
	JE	FDC_RWVF 				; jump if format
	MOV	BL, FDC_CB <1,,1,FDC_CMD_RD>	; FDC Read/Verify - MT, MFM, Skip deleted
							; else read (AH=2,4)
FDC_RWVF:
	XCHG	AX, BX				; AL = FDC cmd byte, BL = function

;----------------------------------------------------------------------------;
; FDC_RWVF: read, write, verify or format sectors
;----------------------------------------------------------------------------;
; Input:
;	AL = FDC command byte
;	BL = INT 13h function number
;	BH = sectors to read
;	DL = drive (0-3)
;	DH = head (0-1)
;----------------------------------------------------------------------------;
	CALL	FDC_SEND 				; [0] send command in AL, CF if error
	JC	FDC_RWV_ERR
	MOV	AL, DH				; AL/DH = head, DL=drive
	SHL	AL, 1					; [1] head / drive byte: 
	SHL	AL, 1					;  xxxxx     ; unused
	OR	AL, DL 				;       h    ; head number (bit 3)
	AND	AL, MASK FC1HD OR MASK FC1DS	;        dd  ; drive number (bit 1,2)
	CALL	FDC_SEND 				; send command in AL, CF if error
	JC	FDC_RWV_ERR
	CMP	BL, 5					; is format?
	JE	FDC_FORMAT

;----------------------------------------------------------------------------;
; FDC_RWV: read, write or verify sectors
;----------------------------------------------------------------------------;
; Input:
;	CH = track/cylinder number (0-39)
;	CL = sector number (1-17)
;	DH = head number (0-1) (bounds not checked)
;
; Output:
;	AL = number of sectors read, written or verified
;----------------------------------------------------------------------------;
FDC_RWV PROC
	MOV	AL, CH 				; [2] cylinder number
	CALL	FDC_SEND 				; send command in AL, CF if error
	JC	FDC_RWV_ERR
	MOV	AL, DH 				; [3] head number
	CALL	FDC_SEND 				; send command in AL, CF if error
	JC	FDC_RWV_ERR
	MOV	AL, CL 				; [4] sector number
	CALL	FDC_SEND 				; send command in AL, CF if error
	JC	FDC_RWV_ERR
	MOV	AL, DBT.FBPS			; [5] bytes per sector
	CALL	FDC_SEND_PARAM			; 2 = 512 bytes
	JC	FDC_RWV_ERR
	MOV	AL, DBT.SPT				; [6] end of track (last sector in track)
	CALL	FDC_SEND_PARAM
	JC	FDC_RWV_ERR
	MOV	BL, AL				; BL = sectors per track
	MOV	AL, DBT.SGAP			; [7] sector gap length
	CALL	FDC_SEND_PARAM
	JC	FDC_RWV_ERR
	MOV	AL, DBT.LSEC			; [8] data length (if cmd byte 5==0)

;----------------------------------------------------------------------------;
; Send last param and wait for status
;
FDC_RWV_SEND_WAIT:
	CALL	FDC_SEND_PARAM
	JC	FDC_RWV_ERR
	CALL	FDC_WAIT_STATUS			; wait for WIF and get status
	;JC	FDC_RWV_ERR				; check for timeout error
							; fall through for FDC SEC COUNT
							; OR report complete sectors

;----------------------------------------------------------------------------;
; FDC_SEC_COUNT: get the number of sectors read/verified/written
;----------------------------------------------------------------------------;
; Input:
;	BL = sectors per track (1-9)
;	BH = number of sectors to read
;	CH = start track/cylinder number (0-39)
;	CL = start sector number (1-17)
;	DH = head number (0-1)
; Output:
;	AL = sectors transferred
;	AH = preserved
;
; Note: If the operation finishes at the last head/sector of a track, 
;	FDC will report the head/track/sector position to be the beginning 
;	of the next track.
;----------------------------------------------------------------------------;
FDC_SEC_COUNT:
	MOV	AL, FDC_LAST_ST.SEC		; AL = FDC reported end sector
	XCHG	DL, CH				; DL = start track, CH = drive
	CMP	DX, WORD PTR _FDC_LAST_ST.CYL	; rolled to next head or track?
	JE	FDC_SEC_COUNT_SAME		; if not, ended on the same head/track

;----------------------------------------------------------------------------;
; FDC has ended on a different head or track. Calculate the correct number of
; sectors spanned.
;
	CMP	DH, _FDC_LAST_ST.HEAD		; end on same head but different track?
	JNE	FDC_SEC_COUNT_SAME_CYL		; if so, has spanned a full head
	ADD	AL, BL				; add two tracks worth of sectors

;----------------------------------------------------------------------------;
; In this (unusual) situation, the head position register and the actual
; head position will be out of agreement, requiring a recal. This is due to
; the behavior of the 765 in MT (multi-track) mode if the sector counter
; exceeds the last sector of head 1. The head will step to the next track,
; however the 765's track number register is not incremented leaving the two
; out of agreement and will generate an error on next command.
; Flag the drive for recal here to avoid a retry error on the next command.
;
; TODO: validate behavior on all FDC types hardware and validate fix.
;
;	PUSH	CX
;	MOV	CL, CH				; CL = drive number
;	MOV	CH, 0001b				; create bitfield for drive number
;	SHL	CH, CL
;	NOT	CH					; invert to mask for clear
;	AND	_FD_CAL_ST, CH 			; clear recal status bit
;	POP	CX
; ; OR just flag all drives for recal
;	AND	_FD_CAL_ST, FDC_RECAL_MASK	; 
;

FDC_SEC_COUNT_SAME_CYL:
	ADD	AL, BL				; add ending sector
FDC_SEC_COUNT_SAME:
	SUB	AL, CL				; AL = ending - starting = sec read
	;CMP	AL, BH				; verify requested # of sectors was
							; # actually read (not necessary).

FDC_RWV ENDP					; fall through for exit

;----------------------------------------------------------------------------;
; Done with all disk operations and return AL
;
INT_13_2_5_EXIT:
	JMP	INT_13_DONE

;----------------------------------------------------------------------------;
; Clear AL and exit on any read/write error
;
FDC_DMA_ERR:
FDC_RWV_ERR:
FDC_FORMAT_ERR:
	JMP	INT_13_0_DONE			; on error: exit with sectors read = 0

;----------------------------------------------------------------------------;
; INT 13, 5: Format Track
;----------------------------------------------------------------------------;
; Input:
;	AL = interleave value (XT only) / sectors per track
;	BL = 05
;	CX = track/cylinder number
;	DL = head number  (0-15 dec.)
;	ES:BX = pointer to block of "track address fields" (provided by DOS)
;----------------------------------------------------------------------------;
FDC_FORMAT PROC
	MOV	AL, DBT.FBPS			; [2] bytes per sector
	CALL	FDC_SEND_PARAM
	JC	FDC_FORMAT_ERR
	MOV	AL, DBT.SPT				; [3] sectors per track
	CALL	FDC_SEND_PARAM
	JC	FDC_FORMAT_ERR
	MOV	AL, DBT.FGAP			; [4] format gap length
	CALL	FDC_SEND_PARAM
	JC	FDC_FORMAT_ERR
	MOV	AL, DBT.FFILL			; [5] format fill byte
	MOV	CL, 1					; format always starts at sector 1
	JMP	SHORT FDC_RWV_SEND_WAIT		; send, wait for WIF and get status
FDC_FORMAT ENDP

INT_13_2_5 ENDP

			IF FDC_EIS EQ 1
;----------------------------------------------------------------------------;
; SEEK in EIS mode
;----------------------------------------------------------------------------;
; If EIS supported, do not seek. Only check if RECAL is needed.
;
; Input:
;	AL = FDC command (2=read,3=write,4=verify,5=format)
; Output:
; 	CH = track, DL = drive
;	CF if error
; Clobbers: AX, BX (if advanced seek)
;----------------------------------------------------------------------------;
FDC_EIS_SEEK PROC
	TEST	_FDC_CAP, FDC_FT_EIS		; test if EIS support detected
	JZ	FDC_SEEK				; if not, use standard seek
	CMP	AL, 4					; if EIS and is read, write or verify?
	JBE	FDC_RECAL_DBL			; if so, check for recal twice
FDC_EIS_SEEK ENDP					; otherwise fall through for seek
			ENDIF

;----------------------------------------------------------------------------;
; FDC_SEEK: Seek to track
;----------------------------------------------------------------------------;
; Input:
;	CH = track
;	DL = drive (0-3) (bounds not checked)
;	DI = OFFSET FD_LAST_OP
;----------------------------------------------------------------------------;
FDC_SEEK PROC
	PUSH	AX
	PUSH	BX
	CALL	FDC_RECAL_DBL			; turn on motor, recal twice if needed
	JC	FDC_SEEK_RECAL_ERR

			IF FDC_ADV_SEEK EQ 1
;----------------------------------------------------------------------------;
; If FDC_ADV_SEEK, the current track where the head is positioned is saved in
; the BDA so that a subsequent operation on the same track will not require
; another seek.
;
	JNZ	FDC_CHECK_SEEK			; recal not needed, check if seek

;----------------------------------------------------------------------------;
; Recal was executed and now on track 0. Just do a head settle if it was
; the destination track.
;
	TEST	CH, CH				; destination track 0?
	JZ	FDC_SEEK_SETTLE			; if so, skip to head settle time

FDC_CHECK_SEEK:
;----------------------------------------------------------------------------;
; Check BDA to see if head is already positioned at the destination track.
;
	XOR	BH, BH
	MOV	BL, DL				; BX = drive #
				IF FDC_MAX_DRIVES GT 2
	AND	BL, 011B				; mask drive number to 0-3
	CMP	DL, 2					; is drive 2 or 3?
	JB	FDC_CHECK_SEEK_1			; jump if 0 or 1
	LEA	BX, [FD2_TRACK-FD_TRACK-2][BX]	; adjust to drive 2-3 table
FDC_CHECK_SEEK_1:
				ELSE
	AND	BL, 01B				; mask drive number to 0-1
				ENDIF
	CMP	_FD_TRACK[BX], CH			; compare last track seek to dest
	JE	FDC_SEEK_DONE			; already on track - nothing to do
			ELSE
	XOR	BH, BH				; still needed for dub step
	MOV	BL, DL				; BX = drive #
			ENDIF				; end IF FDC_ADV_SEEK

	MOV	AL, FDC_CMD_SEEK			; seek command (0FH)
	CALL	FDC_SEND 				; [0] send command, CF if error
	JC	FDC_SEEK_ERR
	MOV	AL, DL 				; AL = drive number
	CALL	FDC_SEND 				; [1] send drive, CF if error
	JC	FDC_SEEK_ERR			; necessary?
	MOV	AL, CH 				; AL = track number

			IF FDC_HD_ENABLE EQ 1
;----------------------------------------------------------------------------;
; Check if double stepping is required for 360K disk in 1.2M drive. If so,
; seek twice as many tracks. Note: the track number in the RWV command and 
; the last seeked track must still be the original track number.
; TODO: won't work without BX set by FDC_ADV_SEEK
;
			ASSUME DS:_BDA
				IF FDC_EIS EQ 0	; TODO temp for now
	TEST	_FD_MEDIA_ST[BX], MASK FDUB	; dub step required?
	JZ	FDC_SEEK_NO_DUB			; jump if not required
	ADD	AL, CH				; dub'le it
	;FD_DEBUG 'DUB'
FDC_SEEK_NO_DUB:
				ENDIF
			ENDIF

	CALL	FDC_SEND 				; [2] send track number, CF if error
	;FD_DEBUG
	JC	FDC_SEEK_ERR

;----------------------------------------------------------------------------;
; Experimental EIS SEEK TODO: does not generate interrupt?
;
;			IF FDC_EIS EQ 1
;	CALL	FDC_WAIT_INT			; if EIS, INT only, do not sense
;	JMP	SHORT FDC_SEEK_DONE_NC
;			ELSE
	CALL	FDC_WAIT_SENSE			; wait for WIF, sense and get status
;			ENDIF
	;FD_DEBUG 'SEEKDUB2'
	JC	FDC_SEEK_ERR
	XOR	AL, FDC_ST0 <01B, 1>		; select abnormal term, seek complete
	AND	AL, FDC_ST0 <01B, 1>		; ZF = abnormal term AND seek complete
	JZ	FDC_SEEK_ERR
			IF FDC_ADV_SEEK EQ 1
	MOV	_FD_TRACK[BX], CH			; save last seeked track (BX = drv #)
			ENDIF

;----------------------------------------------------------------------------;
; Allow time for heads to settle after seek. This may be skipped on emulators
; that don't implement head settle time.
;
FDC_SEEK_SETTLE:
			IF ARCH_TYPE NE ARCH_EMU
	MOV	AX, DBT.HDST			; AH=0 JIC (AH=0 from FDC_WAIT_SENSE)
	CALL	INT_1E_PARAM			; AL = head settle time (ms)

				IF ENFORCE_HST EQ 1
;----------------------------------------------------------------------------;
; If DBT head settle time is 0, allow for reads but force writes to be 15.
;
	TEST	AX, AX				; verify is non-zero
	JNZ	FDC_SEEK_SETTLE_WAIT		; if not zero, proceed to wait
	TEST	_FD_MOTOR_ST, MASK FWRT		; is zero and is write?
	JZ	FDC_SEEK_DONE			; if not write, allow a 0 wait
	MOV	AL, HUT				; use default value of 15ms for write
FDC_SEEK_SETTLE_WAIT:
				ENDIF

	CALL	IO_DELAY_MS_FDC			; delay AX ms
			ENDIF				; not emulator

FDC_SEEK_DONE_NC:
	CLC						; no error
FDC_SEEK_DONE:
	POP	BX
	POP	AX
	RET
FDC_SEEK_ERR:
	OR	_FD_LAST_OP, FDC_ST_ERR_SEEK
FDC_SEEK_RECAL_ERR:
	;FD_DEBUG
	STC
	JMP	SHORT FDC_SEEK_DONE
FDC_SEEK ENDP

;----------------------------------------------------------------------------;
; FDC_MOTOR_ON: Turn on motor
;----------------------------------------------------------------------------;
; Input:
; 	DL = drive number (0-3) (bounds not checked)
; Output:
;	CH = motor index bitfield
; Clobbers: AX
;----------------------------------------------------------------------------;
FDC_MOTOR_ON PROC
	MOV	CL, DL 				; move to CL for shift

;----------------------------------------------------------------------------;
; Convert drive number to motor run format
;
	MOV	AX, 110H 				; AH -> RUN_ST, AL -> new FDC DOR byte
	SHL	AX, CL 				; shift drive flags
	CLI 						; disable interrupts
	MOV	_FD_MOTOR_CT, 255			; restart timer to max for operation
	MOV	CH, _FD_MOTOR_ST			; get current RUN_ST
	TEST	CH, AH 				; is drive already running?
	JNZ	FDC_DRIVE_STARTED			; skip startup if so
	OR	AL, CL 				; combine drive number with new FDC DOR byte
	OR	AL, MASK FDDMA OR MASK FDCEN	; set DMA and controller enable flags
			IF FDC_MULTI_MOTOR EQ 1	; TODO: non-working
	OR	CH, AH				; combine RUN_ST with new motor bit
	PUSH	CX
	MOV	CL, 4
	SHL	CH, CL				; move current motors to 
	OR	AL, CH				; combine previous motors
	POP	CX
			ENDIF
	PUSH	DX					; preserve DX
	MOV	DX, FDC_CTRL			; turn on motor
	OUT	DX, AL				; port 3F2H, FDC Digital Output
	POP	DX
	MOV	AL, CH 				; AL = new FD_MOTOR_ST
	MOV	CH, AH				; CH = save RUN_ST drive bit field
			IF FDC_MULTI_MOTOR EQ 0
	AND	AL, NOT MASK FMOT 		; clear motor status of FD_MOTOR_ST
			ENDIF
	OR	AL, AH				; combine nibbles, SF if write
	MOV	FD_MOTOR_ST, AL			; write to motor status
	JNS	FDC_DRIVE_STARTED 		; delay for motor spinup if write op

;----------------------------------------------------------------------------;
; Delay using timer tick counter
;
	STI 						; enable interrupts
	MOV	AL, DBT.FMST			; AL = INT_1E[10]
	CALL	INT_1E_PARAM 			; AL = motor startup time (in 125ms)
	CALL	IO_WAIT_MS_125			; wait AL * 125ms

FDC_DRIVE_STARTED:
	AND	CH, MASK FMOT			; isolate drives, remove write flag
	STI 						; ensure interrupts enabled
FDC_RECAL_DBT_RET:
	RET
FDC_MOTOR_ON ENDP

;----------------------------------------------------------------------------;
; FDC_RECAL: recalibrate drive TWICE, if necessary
;----------------------------------------------------------------------------;
FDC_RECAL_DBL PROC
			IF FDC_DBL_RECAL EQ 1
	CALL	FDC_RECAL				; first recal
	JNC	FDC_RECAL_DBT_RET			; if no error, return
			ENDIF				; otherwise fall through and retry
FDC_RECAL_DBL ENDP

;----------------------------------------------------------------------------;
; FDC_RECAL: recalibrate drive, if necessary
;----------------------------------------------------------------------------;
; Input:
;	DL = drive to recalibrate (0-3) (bounds not checked)
;	DI = OFFSET FD_LAST_OP
; Output:
;	CF if error
;
; Clobbers: AX, BX (if ADV_SEEK)
;----------------------------------------------------------------------------;
FDC_RECAL PROC
	PUSH	CX
	CALL	FDC_MOTOR_ON			; return CH = bit field for drive #

;----------------------------------------------------------------------------;
; Calibrate drive if necessary
;
	TEST	CH, _FD_CAL_ST 			; 0 means drive is uncalibrated
	JNZ	FDC_RECAL_DONE 			; if drive is calibrated, exit
	MOV	AL, FDC_CMD_RECAL 		; recalibrate command (07H)
	CALL	FDC_SEND 				; [0] send command, CF if error
	JC	FDC_RECAL_ERR
	MOV	AL, DL 				; AL = drive number
	CALL	FDC_SEND 				; [1] send command, CF if error
	JC	FDC_RECAL_ERR			; (necessary?)
	CALL	FDC_WAIT_SENSE 			; wait for WIF, sense and get status in AL
	JC	FDC_RECAL_ERR
	XOR 	AL, FDC_ST0 <01B, 1>		; select abnormal term, seek complete
	AND	AL, FDC_ST0 <01B, 1>		; ZF = abnormal term AND seek complete
	STC						; presume failure
	JZ	FDC_RECAL_ERR			; jump if error
	OR	_FD_CAL_ST, CH 			; mark drive as calibrated and CLC

			IF FDC_ADV_SEEK EQ 1
;----------------------------------------------------------------------------;
; Save track 0 to BDA FD_TRACK
;
	XOR	BH, BH				; track 0 and set ZF
	MOV	BL, DL				; BX = drive index
				IF FDC_MAX_DRIVES GT 2
	CMP	DL, 2					; is drive 2 or 3?
	JB	FDC_RECAL_ADV_1			; jump if 0 or 1
	LEA	BX, [FD2_TRACK-FD_TRACK-2][BX]	; adjust to drive 2-3 table
FDC_RECAL_ADV_1:
	XOR	BH, BH				; reset ZF
				ENDIF
	MOV	_FD_TRACK[BX], BH			; save last track seek 0
			ENDIF

FDC_RECAL_ERR:
FDC_RECAL_DONE:
	POP	CX
FDC_RESET_RET:
	RET
FDC_RECAL ENDP

;----------------------------------------------------------------------------;
; FDC_RESET: Reset FDC
;----------------------------------------------------------------------------;
; Input:
;	DI = FD_LAST_OP
;	DS = BDA
; Clobbers: DX, AX, CX
;----------------------------------------------------------------------------;
FDC_RESET PROC

;----------------------------------------------------------------------------;
; Check BDA DOR to see if it is zero (default after reset).  If not, the
; current DOR state will need to be re-sent to the FDC after reset.
;
	CLI 						; disable interrupts
	MOV	AL, FD_MOTOR_ST 			; 3FH - Diskette motor status
	MOV	CH, AL 				; save to CH
	AND	AX, MASK FMOT			; isolate motor status flags, AH = 0
	JZ	INT_13_0_2				; jump if no motors are on, DOR = 0
	;FD_DEBUG 'RESET'

;----------------------------------------------------------------------------;
; One motor is on (according to BDA) or drive select is not 0. 
; Save drive select/motor state since DOR registers are cleared on reset.
;
; To Convert FD_MOTOR_ST to FDC byte use the following table/formula:
;	Motors On 	Drive #
;	0 0 0 0	 	- 			AND with 1111, jump if AL = 0
;	1 x x x		3			TEST bit 1000, if non-zero then AL = 3
;	0 1 0 x		2 			Shift right once and AL will be correct
;	0 0 1 x		1 			"
;	0 0 0 x	 	0			"
;
	SHR	AL, 1					; disregard low bit (will be 0 either way)
	TEST	AL, MASK FMOT3 SHR 1		; test for drive 3?
	JZ	INT_13_0_1				; if not drive 3, AL is now correct
	MOV	AL, 3 				; otherwise set AL to drive 3
INT_13_0_1:
			IF CPU_TYPE	EQ CPU_V20
	ROL4	CH					; CH = (FD_MOTOR_ST SHL 4) OR (AL AND 0FH)
	MOV	AL, CH				; AL = CH
			ELSE
				IF CPU_TYPE EQ CPU_186
	SHL	CH, 4
				ELSE
	MOV	CL, 4 				; move low nibble of FD_MOTOR_ST
	SHL	CH, CL				;  into high nibble of CH
				ENDIF
	OR	AL, CH 				; combine nibbles with AL
			ENDIF

INT_13_0_2:
	MOV	DX, FDC_CTRL			; port 3F2H, FDC Digital Output

			IF FDC_DSR_RESET EQ 1
;----------------------------------------------------------------------------;
; Determine if controller supports faster DSR reset
;
	TEST	_FDC_CAP, FDC_FT_DSR_RST	; supports DSR reset?
	JZ	FDC_RESET_DOR			; if not, use DOR reset

;----------------------------------------------------------------------------;
; DSR reset
;----------------------------------------------------------------------------;
FDC_RESET_DSR:
			IF CPU_TYPE	NE CPU_V20	; if V20, CH = AL already
	MOV	CH, AL				; save AL
			ENDIF
	MOV	AL, MASK FCRST			; DSR reset bit
	MOV	DL, LOW FDC_DSR			; DX = DSR I/O address
	TEST	CH, CH				; was DOR 0?
	;FD_DEBUG 'DSR RST', 1
	JZ	INT_13_0_RESET_OUT		; if so, skip restoring DOR
							; and just send reset

;----------------------------------------------------------------------------;
; Restore DOR state after DSR reset
;
	OUT	DX, AL				; AL = register value
	MOV	DL, LOW FDC_CTRL			; DX = DOR I/O address
	MOV	AL, CH				; restore AL (saved DOR)
	JMP	SHORT INT_13_0_RESET_EN		; enable FDC, DMA and send
			ENDIF				; FDC_DSR_RESET EQ 1

;----------------------------------------------------------------------------;
; DOR reset
;----------------------------------------------------------------------------;
FDC_RESET_DOR:
	FD_DEBUG 'DOR RST', 1
	OR	AL, MASK FDDMA			; enable DMA & I/O interface, FDC reset
	OUT	DX, AL				; send to FDC
		IF IS_TURBO EQ 1
	IO_DELAY_SHORT				; additional delay for faster systems
		ENDIF

INT_13_0_RESET_EN:
	OR	AL, MASK FDCEN OR MASK FDDMA	; enable DMA & I/O interface

INT_13_0_RESET_OUT:
	MOV	_FD_CAL_ST, AH 			; flag all drives for recal, clear WIF
	OUT	DX, AL				; send to DOR
	STI 						; enable interrupts

;----------------------------------------------------------------------------;
; Send CONFIGURE command if LOCK is not supported (HD2, HD3) OR EIS
;----------------------------------------------------------------------------;
;			IF FDC_EIS EQ 1
;	EXTRN	FDC_CONFIGURE:NEAR
;	MOV	AX, FDC_CONF_BYTE			; configure command, AH = 0
;	CALL	FDC_CONFIGURE			; sets CF and FD_LAST_OP
;			ENDIF

			IF FDC_NO_POLL EQ 1 OR FDC_EIS EQ 1
;----------------------------------------------------------------------------;
; Disable Drive Polling by CONFIGURE to avoid interrupt and senses
;
			IF FDC_NO_POLL EQ 1 AND FDC_SOFT_POLL EQ 1
	TEST	_FDC_CAP, FDC_FT_CONF		; controller supports CONFIGURE?
	JZ	INT_13_0_POLL_SETUP		; if not, wait and sense four INTs
			ENDIF

	EXTRN	FDC_CONFIGURE:NEAR
	MOV	AX, FDC_CONF_BYTE			; configure command, AH = 0
	CALL	FDC_CONFIGURE			; sets CF and FD_LAST_OP

			IF FDC_NO_POLL EQ 1 AND FDC_SOFT_POLL EQ 1
	JMP	SHORT INT_13_0_RESET_DONE
			ENDIF

			ENDIF

			IF FDC_NO_POLL EQ 0 OR FDC_SOFT_POLL EQ 1
;----------------------------------------------------------------------------;
; Wait for Interrupt (WIF) from FDC and eat four POLL senses
;
INT_13_0_POLL_SETUP:
	CALL	FDC_WAIT_INT 			; wait for WIF
	JC	INT_13_0_RESET_BAD
	MOV	CX, 4					; four POLL senses
	MOV	DL, FDC_ST0 < 11B > - 1		; pre-decrement test result
INT_13_0_POLL_CLR:
	CALL	FDC_SENSE				; wait for FDC to signal interrupt
	JC	INT_13_0_RESET_BAD
	INC	DX					; inc here to preserve CMP flag
	CMP	AL, DL				; FDC_ST0 + drive index?
	LOOPE	INT_13_0_POLL_CLR
	JE	INT_13_0_RESET_DONE		; last result ok?
	STC						; ensure failure

INT_13_0_RESET_BAD:
	MOV	AH, FDC_ST_ERR_FDC		; exit with controller failure

INT_13_0_RESET_DONE:
;			IF USE_FDC_DEBUG EQ 1
;	EXTRN	FDC_DUMPREG:NEAR
;	CALL	FDC_DUMPREG
;			ENDIF

			ENDIF				; FDC_NO_POLL EQ 1

;----------------------------------------------------------------------------;
; Completed
;
	MOV	_FD_LAST_OP, AH			; set last result	
	JC	FDC_RESET_RET_1			; exit if not successful

		IF FDC_HD_ENABLE EQ 1
;----------------------------------------------------------------------------;
; Additional HD controller stuff here
;----------------------------------------------------------------------------;
	AND	_FDC_ST, NOT MASK FLSV		; clear specify byte valid flag

	MOV	AL, FDC_CAP				; AL = FDC capabilities (necessary?)
	TEST	AL, MASK FHD			; FDC supports HD
	JZ	FDC_RESET_SPEC			; skip HD setup if not

;----------------------------------------------------------------------------;
; Send last data rate to FDC
;
	MOV	AL, FD_LR				; last data rate FDC_RATE
	AND	AL, MASK FSR			; isolate data rates
	ROL	AL, 1					; move data rate to low two bits
	ROL	AL, 1
	MOV	DL, LOW FDC_CONF			; Rate Configuration Control Register
	OUT	DX, AL				; AL = register value

		ENDIF					; FDC_HD_ENABLE

;----------------------------------------------------------------------------;
; Send Specify bytes to FDC - regardless of last specify status
;
FDC_RESET_SPEC:
	MOV	AL, FDC_CMD_SPEC 			; [0] FDC Specify command
	CALL	FDC_SEND 				; send command in AL, CF if error
	JC	FDC_RESET_RET_1
	MOV	AL, DBT.SRT				; [1] step rate time, head unload time
	CALL	FDC_SEND_PARAM
	JC	FDC_RESET_RET_1
	MOV	AL, DBT.HLT_ND			; [2] head load time (01H), DMA mode (ND)

			IF USE_NSC_MODE EQ 0 OR FDC_EIS EQ 0
	JMP	SHORT FDC_SEND_PARAM		; send Specify and RET
			ELSE

	CALL	FDC_SEND_PARAM
;----------------------------------------------------------------------------;
; Send NSC MODE if supported. PC8477B data sheet suggests this should occur
; after SPECIFY. Only necessary if using EIS with NSC.
;
	PUSHF
	TEST	_FDC_CAP, FDC_FT_MODE
	JZ	FDC_RESET_NO_MODE
	;FD_DEBUG 'NSC_MODE1'
	CALL	FDC_NSC_MODE
	;FD_DEBUG 'NSC_MODE2'
FDC_RESET_NO_MODE:
	POPF
	RET
			ENDIF

FDC_RESET ENDP

;----------------------------------------------------------------------------;
; FDC_RECV: Wait for FDC ready to send and read next FDC Status byte into AL
;----------------------------------------------------------------------------;
; Timeout is 5 timer ticks = ~275ms.
;
; Input: None
; Output:
;	AL = top of FDC status stack
;	AH = 80H if error, 0 if success
;	CF if timeout or error
;----------------------------------------------------------------------------;
FDC_RECV PROC
	PUSH	BX
	XOR	BX, BX				; flag is 0 if RECV operation
	JMP	SHORT FDC_SEND_RECV

;----------------------------------------------------------------------------;
; FDC_SEND_PARAM: Wait for FDC ready and send a floppy param in AL
;----------------------------------------------------------------------------;
; Same as below except AL input is INT_1E param index
;----------------------------------------------------------------------------;
FDC_SEND_PARAM PROC
	CALL	INT_1E_PARAM 			; AL = INT_1E[AL] param

;----------------------------------------------------------------------------;
; FDC_SEND: Wait for FDC ready to receive and send a single command
;----------------------------------------------------------------------------;
; Timeout is 5 timer ticks = ~275ms.
;
; Input:
;	AL = byte to send to FDC
;
; Output:
;	AL = status register
;	AH = 80H if error, 0 if success
;	CF and ZF if error
;----------------------------------------------------------------------------;
FDC_SEND PROC
	PUSH	BX
	MOV	BL, 1					; flag is 1 if SEND operation

FDC_SEND_RECV:
	MOV	BH, AL				; save byte to send
	PUSH	CX
	PUSH	DX 					; call-preserve used registers

;----------------------------------------------------------------------------;
; Wait for FDC I/O direction = CPU to FDC and Data Reg Ready
;
	MOV	CX, 5					; CX = # of ticks to wait
	MOV	AH, BYTE PTR TIMER.LW		; get starting tick counter low byte

FDC_SEND_WAIT_POLL:
	MOV	DX, FDC_STAT 			; port 3F4H - FDC Main Status Register
	IN	AL, DX				; AL = FDC status register
	TEST	AL, AL				; is DRR/RQM = I/O to/from CPU?
	JNS	FDC_SEND_WAIT_TIMER		; if not, check if timeout has elapsed

;----------------------------------------------------------------------------;
; FDC is ready for I/O
;
	INC	DX 					; port 3F5H - FDC Command Status Register
	TEST	BL, BL				; is send or receive?
	JZ	FDC_RECV_WAIT_POLL		; jump if receive

;----------------------------------------------------------------------------;
; SEND operation
;----------------------------------------------------------------------------;
FDC_SEND_WAIT_POLL_1:
	TEST	AL, MASK FIOD			; is DIO I/O direction = CPU to FDC (0)?
	JNZ	FDC_SEND_WAIT_TIMER		; if not, check if timeout has elapsed

;----------------------------------------------------------------------------;
; Status is ready to send
;
FDC_SEND_READY:
	MOV	AL, BH				; restore AL byte to send
	OUT	DX, AL				; send command
		IF IS_TURBO
	IO_DELAY_SHORT
		ENDIF
	JMP	SHORT FDC_WAIT_DONE		; status = success (0), CF = 0 and done

;----------------------------------------------------------------------------;
; RECEIVE operation
;----------------------------------------------------------------------------;
FDC_RECV_WAIT_POLL:
	TEST	AL, MASK FIOD			; is DIO I/O direction = FDC to CPU (1)?
	JZ	FDC_SEND_WAIT_TIMER		; if not, check if timeout has elapsed

;----------------------------------------------------------------------------;
; Data is ready to read
;
FDC_RECV_READY:
		IF IS_TURBO
	IO_DELAY_SHORT
		ENDIF
	IN	AL, DX				; read from FDC

;----------------------------------------------------------------------------;
; Completed with success
;
FDC_WAIT_DONE:
	XOR	AH, AH 				; status = success (0), CF = 0

FDC_WAIT_EXIT:
	POP	DX
	POP	CX
	POP	BX
FDC_RESET_RET_1:
	RET

;----------------------------------------------------------------------------;
; Check if timeout has expired
;
FDC_SEND_WAIT_TIMER:
	MOV	AL, BYTE PTR TIMER.LW		; get current tick counter
	CMP	AL, AH				; still the same?
	JZ	FDC_SEND_WAIT_POLL		; loop if the same
	MOV	AH, AL				; otherwise, save new tick value to AH
	LOOPNZ FDC_SEND_WAIT_POLL		; loop until # of ticks (CX) has elapsed

;----------------------------------------------------------------------------;
; Timeout has expired
;
FDC_WAIT_TIMEOUT:
	MOV	AH, FDC_ST_TIMEOUT 		; time out, drive not ready error
	OR	FD_LAST_OP, AH			; set flag in BDA
	STC						; set error
	JMP	SHORT	FDC_WAIT_EXIT

FDC_SEND ENDP
FDC_SEND_PARAM ENDP
FDC_RECV ENDP

;----------------------------------------------------------------------------;
; FDC_WAIT_SENSE: wait for WIF, sense status and get status bytes
;----------------------------------------------------------------------------;
; Output:
;	CF if FDC read/timeout error
;	NZ if result status error
;	AL = FDC_LAST_ST (BDA Floppy drive status)
;	AH = 0 if success, 80H if failure
;----------------------------------------------------------------------------;
FDC_WAIT_SENSE PROC
	CALL	FDC_WAIT_INT 			; wait for WIF
	JC	FDC_WAIT_SENSE_EXIT

FDC_SENSE PROC
	MOV	AL, FDC_CMD_SENSE			; sense Interrupt status
	CALL	FDC_SEND

;----------------------------------------------------------------------------;
; FDC_RECV_STATUS:
;----------------------------------------------------------------------------;
; Output:
;	CF if FDC read/timeout error
;	NZ if result status error
;
;	AL = FDC_LAST_ST (BDA Floppy drive status), if success
;	AH = 0 if success, 80H or 20H if failure
;----------------------------------------------------------------------------;
FDC_RECV_STATUS PROC
	JC	FDC_WAIT_SENSE_EXIT		; return if timeout error
							; fall through to FDC_RECV_ALL

;----------------------------------------------------------------------------;
; FDC_RECV_ALL: Pop all status bytes from FDC to BDA
;----------------------------------------------------------------------------;
; Check for FDC errors and set FD_LAST_OP if necessary
; Input: DS = BDA (40H), DI = FD_LAST_OP (41H)
; Output: AH = 0 if success, 80H if failure
;----------------------------------------------------------------------------;
FDC_RECV_ALL PROC
	PUSHX	ES, CX, DI, DX			; preserve DI (FD_LAST_OP)
	MOV	DX, FDC_STAT
	PUSH	DS					; ES = BDA segment
	POP	ES
	INC	DI					; DI = FDC_LAST_ST (FDC Last Result)
	MOV	CX, SIZE FDC_LAST_ST		; loop up to 7 FDC bytes
FDC_RECV_ALL_LOOP:
	CALL	FDC_RECV				; AL = next byte, AH = 0 if success
	JC	FDC_RECV_ALL_DONE			; CF if failure
	STOSB						; write to BDA

;----------------------------------------------------------------------------;
; Additional delay for FDC to settle
; "After each byte of data read or written to the data register, the CPU 
; should wait for 12 microseconds before reading main status register"
;
		IF IS_TURBO
	MOV	AL, 20				; delay 372 clocks (~31us at 12MHz,
		ELSE					;  ~37us at 10MHz, ~46us at 8MHz)
	MOV	AL, 10				; delay ~225 clocks (~47us at 4.77)
		ENDIF
FDC_RECV_DELAY:
	DEC	AL
	JNZ	FDC_RECV_DELAY

;----------------------------------------------------------------------------;
; Check for additional bytes to be read from FDC registers
;
	IN	AL, DX				; DX = 03F4H
	AND	AL, MASK FDRW 			; is FDC R/W command in progress flag?
	LOOPNZ FDC_RECV_ALL_LOOP		; loop until no flag or 7 bytes read
	JNZ	FDC_RECV_FDC_ERR			; command still in progress?
							; AL = 0 (no command in progress) or CX = 0
		IF FDC_ZERO_BDA EQ 1
	REP	STOSB 				; zero out rest of results in BDA
		ENDIF
FDC_RECV_CHECK_ERR:
	MOV	AL, FDC_LAST_ST.SB0 		; AL = last FDC status byte 0
	TEST	AL, MASK ST0CS			; check Last Command Status
FDC_RECV_ALL_DONE:
	POPX	DX, DI, CX, ES			; DI = FD_LAST_OP
FDC_WAIT_SENSE_EXIT:
	RET
FDC_RECV_FDC_ERR:
	FD_DEBUG 'FDC_ERR'
	MOV	AH, FDC_ST_ERR_FDC		; controller still busy after
	OR	FD_LAST_OP, AH			;  reading max bytes
	STC
	JMP	SHORT FDC_RECV_ALL_DONE
FDC_RECV_ALL ENDP
FDC_RECV_STATUS ENDP
FDC_SENSE ENDP
FDC_WAIT_SENSE ENDP

;----------------------------------------------------------------------------;
; FDC_WAIT_STATUS: Wait for WIF, get status bytes and check for error
;----------------------------------------------------------------------------;
FDC_WAIT_STATUS PROC
	CALL	FDC_WAIT_INT 			; wait for WIF
	CALL	FDC_RECV_STATUS			; read FDC status into BDA
							; CF if FDC error, NZ if status error
	JBE	FDC_WAIT_ERR_EXIT_OK		; exit if ZF or CF error

;----------------------------------------------------------------------------;
; FDC_WAIT_STATUS_ERR: Map FDC Command Status Register 1 to BDA error codes
;----------------------------------------------------------------------------;
; Input:
;	AL = Last result from FDC_LAST_ST
; Output:
;	CF if error
;	AH/AL = BDA Floppy drive status
;----------------------------------------------------------------------------;
FDC_WAIT_STATUS_ERR PROC
	TEST	AL, FDC_ST0 < 01B >		; command terminated abnormally?
	MOV	AL, FDC_ST_ERR_FDC		; if not, FDC error
	JZ	FDC_WAIT_STATUS_ERR_DONE
	CBW						; AH = 0
	OR	AH, _FDC_LAST_ST.SB1		; AH = last status byte 1, ZF if 0
	JZ	FDC_WAIT_STATUS_ERR_DONE	; skip if AH = 0
	PUSH	SI
	MOV	SI, OFFSET FDC_ERR1_MAP
FDC_ERR_MAP_LOOP:
	LODS	BYTE PTR CS:[SI]			; fetch next error byte
	SHL	AH, 1					; CF if this status flag
	JA	FDC_ERR_MAP_LOOP			; loop if NC (not this flag)
	POP	SI					;  and NZ (more flags to check)
FDC_WAIT_STATUS_ERR_DONE:
	MOV	AH, AL				; AH = last result
FDC_WAIT_ERR_EXIT:
	OR	_FD_LAST_OP, AH			; BDA 40:41H
	STC
FDC_WAIT_ERR_EXIT_OK:
	RET

;----------------------------------------------------------------------------;
; FDC Status register to INT 13h error map
; Note: Must check from most sig bit to lowest since higher
; bits are more meaningful.
;
FDC_ERR1_MAP LABEL BYTE
	DB	FDC_ST_ERR_SEC			; 80 end of cylinder
	DB	FDC_ST_ERR_FDC			; 40 unused (always zero)
	DB	FDC_ST_ERR_CRC			; 20 data error CRC
	DB	FDC_ST_DMA_OVR			; 10 DMA timeout/overrun
	DB	FDC_ST_ERR_FDC			; 08 unused (always zero)
	DB	FDC_ST_ERR_SEC			; 04 Sector Not Found
	DB	FDC_ST_ERR_WP			; 02 Write Protect
	DB	FDC_ST_ERR_MARK			; 01 Address mark not found or bad sector

FDC_WAIT_STATUS_ERR ENDP
FDC_WAIT_STATUS ENDP

;----------------------------------------------------------------------------;
; Retrieve a parameter value from the DBT by index
;----------------------------------------------------------------------------;
; Input:
;	AL = parameter index (bounds not checked)
; Output:
;	AL = byte
;	Flags preserved
;
; Size: 14 bytes
;----------------------------------------------------------------------------;
INT_1E_PARAM PROC
	PUSH	DS
	PUSH	BX
	MOV	BX, SEG _IVT			; BX = IVT (preserve flags)
	MOV	DS, BX 				; DS = IVT
			ASSUME DS:_IVT
	LDS	BX, IVT_1E				; DS:BX = INT 1EH in IVT
	XLAT 						; AL = byte
	POP	BX
	POP	DS
			ASSUME DS:NOTHING
	RET
INT_1E_PARAM ENDP

;----------------------------------------------------------------------------;
; FDC_WAIT_INT: Wait for BDA Working Interrupt Flag from FDC
;----------------------------------------------------------------------------;
; Input: DS = BDA, DI = FD_LAST_OP
; Output: CF if timeout
;----------------------------------------------------------------------------;
FDC_WAIT_INT PROC
			ASSUME DS:_BDA
	STI						; ensure interrupts are on
	PUSH	AX 					; call preserve regs
	PUSH	CX
	MOV	CX, 2 * (1000/55) + 1		; timeout ~2 sec (37 ticks)
FDC_WAIT_INT_LOOP1:
	MOV	AX, TIMER.LW			; AX = time ticks
FDC_WAIT_INT_LOOP2:
	TEST	_FD_CAL_ST, MASK FWIF 		; check for WIF in FD_CAL_ST (3EH)
	JNZ	FDC_WAIT_INT_OK			; if so, exit
			IF FDC_HLT_WAIT GT 0
	HLT						; wait for any INT
			ELSE
	NOP						; allow extra time for INTs
			ENDIF
	CMP	AX, TIMER.LW			; has timer tick changed?
	JE	FDC_WAIT_INT_LOOP2		; if not, wait for next INT
	LOOP	FDC_WAIT_INT_LOOP1		; decrement tick counter and resume loop
	OR	_FD_LAST_OP, FDC_ST_TIMEOUT 	; FDC result set time out, drive not ready
	STC
	JMP	SHORT FDC_WAIT_INT_DONE
FDC_WAIT_INT_OK:
	AND	_FD_CAL_ST, NOT MASK FWIF 	; clear working interrupt flag
FDC_WAIT_INT_DONE:
	POP	CX
	POP	AX
	RET
FDC_WAIT_INT ENDP

		IF GLADISK_INT_0EH EQ 1
;----------------------------------------------------------------------------;
; INT 0EH - Floppy Disk Interrupt IRQ6
;----------------------------------------------------------------------------;
; This interrupt is issued upon floppy disk I/O completion and sets the
; floppy disk working interrupt flag at 40:3E, bit 7.
;----------------------------------------------------------------------------;
		;ORG 0EF57H				; EFI compatibility ORG
PUBLIC INT_0E
INT_0E PROC
	PUSH	AX
	PUSH	DS
	XOR	AX, AX				; DS = BDA_ABS segment
	MOV	DS, AX
			ASSUME DS:_BDA_ABS
	OR	FD_CAL_ST_ABS, MASK FWIF	; turn on working interrupt flag
	MOV	AL, EOI 				; End of Interrupt OCW
	OUT	INT_P0, AL				; write EOI to port 0
	POP	DS
			ASSUME DS:NOTHING
	POP	AX
	IRET
INT_0E ENDP
		ENDIF

			IF GLADISK_INT_1EH EQ 1
;----------------------------------------------------------------------------;
; INT 1E - Disk Initialization Parameter Table Vector
;----------------------------------------------------------------------------;
; Provides a "pluggable" method to allow additional disk ROMs or DOS to 
; replace this table.
;
;  00  Head Step Rate (SRT) = 0CH = 12ms
;      Head Unload Time (HUT) = 15 x (16ms increments) = 240ms(?)
;  01  Head Load Time = 1 (2ms increments) = 2, DMA flag (0 = use DMA)
;  02  timer ticks to wait before disk motor shutoff = 37
;  03  512 bytes per sector (0=128, 1=256, 2=512, 3=1024) = 2
;  04  sectors per track (last sector number) = 9
;  05  inter-block gap length/gap between sectors (mills) = 42
;  06  data length, if sector length not specified = 0FFH
;  07  gap length between sectors for format (mills) = 80
;  08  fill byte for formatted sectors = 0F6H
;  09  head settle time in milliseconds = 25
;  0A  motor startup time in eighths of a second = 4
;  MFM = 2
;
; https://stanislavs.org/helppc/dbt.html
; https://stanislavs.org/helppc/765.html
; https://stanislavs.org/helppc/int_1e.html
; https://www.isdaman.com/alsos/hardware/fdc/floppy.htm#ctrlcom
;----------------------------------------------------------------------------;
; NOTE: This is optimized for 360K media in a 360K drive.
; DOS may use this as the "default" DBT when not doing an operation.
;----------------------------------------------------------------------------;
		;ORG 	0EFC7H			; EFI compatibility ORG
PUBLIC	INT_1E
INT_1E	DBT 	< FDC_SB0 <12>,, 37, 2, 9, 42, 0FFH, 80, 0F6H, 25, 4 >
			ENDIF

INT_13 ENDP

OPTROM	ENDS
		END
