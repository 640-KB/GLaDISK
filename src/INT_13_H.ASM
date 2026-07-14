	PAGE	 	59,132
	TITLE		GLaDISK_INT_13 HD

;----------------------------------------------------------------------------;
; GLaDISK (Gizmo Linkage and Dynamic Information Storage Keeper)
;
; INT 13H - Diskette BIOS Services - HD Support
;----------------------------------------------------------------------------;
INCLUDE	GLADISK.INC
INCLUDE	INT_13.INC

;----------------------------------------------------------------------------;
; Start of segment
;----------------------------------------------------------------------------;
OPTROM	SEGMENT BYTE PUBLIC 'CODE'
		ASSUME  DS:OPTROM, SS:OPTROM, CS:OPTROM, ES:OPTROM

		IF FDC_HD_ENABLE EQ 1	; include if HD support enabled

;----------------------------------------------------------------------------;
; INT_13 EXTRN PROCs
;----------------------------------------------------------------------------;
EXTRN		FDC_MOTOR_ON:NEAR
EXTRN		FDC_SEEK:NEAR
EXTRN		FDC_RECAL:NEAR
EXTRN		FDC_RECAL_DBL:NEAR
EXTRN		FDC_RESET:NEAR
EXTRN		FDC_SEND:NEAR
EXTRN		FDC_SEND_PARAM:NEAR
EXTRN		FDC_RECV_ALL:NEAR
EXTRN		FDC_WAIT_STATUS:NEAR

;----------------------------------------------------------------------------;
; GLaDISK EXTRN PROCs
;----------------------------------------------------------------------------;
EXTRN		GET_DRIVE_COUNT:NEAR	; Get drive count according to BDA
EXTRN		FD_GET_CMOS:NEAR		; Get specified drive type from "CMOS"

			IF USE_FDC_DEBUG EQ 1
EXTRN		FDC_DEBUG:NEAR
			ENDIF

;----------------------------------------------------------------------------;
; INT_13_H PUBLIC PROCs
;----------------------------------------------------------------------------;
PUBLIC	INT_13_HD		; entry point for INT 13H, HD functions
PUBLIC	FD_SET_MODE_CMOS	; Setup drive type in FD_MODE BDA for drive number in DL 
PUBLIC	FD_RESET_STATE	; Reset current media state of a drive to default unestablished
PUBLIC	FD_SET_STATE	; Set media state of a drive
PUBLIC	FD_SET_STATE_DRV	; Set media state of a drive (no bounds check)
PUBLIC	FD_GET_MEDIA	; Read Media and attempt to determine type, set in BDA
PUBLIC	FDC_SET_RATE	; Set data rate on FDC and save to BDA
PUBLIC	FD_DISK_CHANGE	; Check if disk in drive DI has changed and clear active line latch.
PUBLIC	FD_CMOS_DRIVE_TBL	; Get the drive table from "CMOS" (BDA) for drive number in DL
PUBLIC	FD_CMOS_TBL		; Get the drive table for CMOS drive type
PUBLIC	FD_TBL		; DBT Table for CMOS types
PUBLIC	INT_13_2_5_HD_SETUP ; HD operations for read/write/verify/format commands
PUBLIC	FDC_SETUP_DRV	; Send specify, standard PMODE and data rate for drive if needed
PUBLIC	FDC_CONFIGURE	; Send CONFIGURE command
PUBLIC	FDC_CONFIGURE_LOCK ; Send CONFIGURE command and LOCK
PUBLIC	FDC_DUMPREG		; Send DUMPREG command
PUBLIC	FDC_SEND_RECV_ALL	; Send command and receive results for non-interrupt commands
PUBLIC	FDC_NSC_MODE	; Send NSC MODE command
PUBLIC	FDC_TEST_CMD	; Test if a command is supported on FDC
			IF FDC_PMODE EQ 1
PUBLIC	FDC_SET_EPMODE	; Send Enhanced PERPENDICULAR command
			ENDIF

;----------------------------------------------------------------------------;
; INT 13,8  Get current drive parameters from CMOS type
;----------------------------------------------------------------------------;
; Input:
;	AH = 08
;	DL = drive number (0=A:, 1=2nd floppy, 80h=drive 0, 81h=drive 1)
; Return:
;	AH = status (1=BADCMD if DL >= 80H, 0=OK if DL is < 80H)
;	BX = CMOS drive type: 0=none, 1=360, 2=1.2, 3=720, 4=1.44, 5=2.88
;	CH = cylinders: 0-79 (0 based)
;	CL = sectors per track: 1-36 (1 based)
;	DH = number of sides: 0-1 (0 based) (always 1 if CMOS RAM valid)
;	DL = number of drives attached (1 based)
;	ES:DI = pointer to 13 byte Disk Base Table (DBT)
;	CF = 0 if successful
;	   = 1 if drive number is hard drive
;----------------------------------------------------------------------------;
; This function returns the diskette parameters for the drive specified in DL.
; If successful, the CF is cleared and diskette status is not modified.
;
; The drive type stored in CMOS RAM determines the parameters returned.
; If the drive type is not stored in CMOS RAM, all registers return a value
; of zero, except DL, which contains the number of drives installed.
;
; If the media type is known, the maximum media capacity is returned in
; registers BL, CH, CL and DH. A pointer to the diskette parameter table
; is returned in ES:DI. If disk media is not currently known, reset in BDA
; to CMOS drive type default.
;
; If DL is a hard drive, preserve all registers and return with CF and AH = 1.
;----------------------------------------------------------------------------;
		ASSUME DS:_BDA, ES:NOTHING
INT_13_8 PROC

;----------------------------------------------------------------------------;
; Check if drive index is a hard drive. If so, exit with error.
;
	TEST	DL, DL				; is hard drive (DL >= 80H)?
	MOV	AH, FDC_ST_BADCMD			; assume result bad command
	STC						;  and error
	JS	INT_13_HD_RET_AH			; exit with CF if hard drive

;----------------------------------------------------------------------------;
; Check BDA if # of drives is not zero or out of range. The number of drives
; is always returned in DL, even on error.
; TODO Note: this will cause this to fail if 2 or 3 drives are selected on DIP
; switches. IS that correct?
;
	PUSH	SI
	CALL	GET_DRIVE_COUNT			; AX = BDA drive count (1 based)
	MOV	CL, AL				; CL = save drive count for return
	JNA	INT_13_8_ERR			; exit if 0 (ZF) or bad drive # (CF)
	CMP	AL, DL				; is requested drive valid?
	JBE	INT_13_8_ERR			; exit if invalid

;----------------------------------------------------------------------------;
; Determine drive type from CMOS. Since there is always a hard-coded CMOS
; to fall back on, these types can be considered reliable and no need to
; attempt to determine from media state.
;
	CALL	FD_GET_CMOS				; AL = CMOS type
	JC	INT_13_8_ERR			; exit if invalid or CMOS type is 0

;----------------------------------------------------------------------------;
; Get FD_TBL pointer for CMOS type to return in ES:DI. The ES segment is used
; to select the correct table since 16 byte DBT tables are paragraph aligned.
;
	CBW						; AH = 0
	XCHG	AX, BX				; BX = CMOS type for return
	MOV	SI, CS				; SI = DBT base segment
	ADD	SI, BX				; add CMOS type index
	MOV	ES, SI				; ES = FD_TBL paragraph indexed
	MOV	SI, OFFSET FD_TBL_1		; ES:DI = DBT for return

;----------------------------------------------------------------------------;
; If current media is not established, reset with default CMOS state type.
;
	CALL	FD_GET_STATE			; AL = drive DL state, NZ if est.
	LODS	BYTE PTR ES:[SI]			; AL = default CMOS drive state, SI++
	JNZ	INT_13_8_EST			; if established, do not set media state
	CALL	FD_SET_STATE_DRV			; reset media state byte to default

;----------------------------------------------------------------------------;
; Get drive geometry, DBT and return.
;
INT_13_8_EST:
	LODS	WORD PTR ES:[SI]			; AX = cyl/head
	MOV	CH, 1					; CMOS types always double-sided
INT_13_8_DONE:
	MOV	_INT_13_BX, BX			; BX = CMOS drive type
	MOV	_INT_13_CX, AX			; CX = cyl/heads
	MOV	_INT_13_DX, CX			; DL = # drives, DH = heads
	MOV	_INT_13_DI, SI			; DI = offset for DBT
	XOR	AX, AX				; AH = FDC_OK, AL = 0, CF = 0
	POP	SI
	JMP	SHORT INT_13_HD_RET_AH		; last status = AH and RET

;----------------------------------------------------------------------------;
; If floppy drive not present, return AX, BX, CX, DH, DI and ES = 0.
;
INT_13_8_ERR:
	XOR	AX, AX				; AX = 0
	MOV	BX, AX				; BX = 0
	MOV	CH, AL				; DH = 0 (0 sides)
	MOV	SI, AX				; DI = 0
	MOV	ES, AX				; ES = 0
	JMP	SHORT INT_13_8_DONE

INT_13_8 ENDP

;----------------------------------------------------------------------------;
; INT 13,16  Disk change line status
;----------------------------------------------------------------------------;
; Detect if a disk change has occurred
;
; Input:
;	AH = 16h
;	DL = drive number (00=A:, 01=2nd floppy)
; Output:
;	AH = 00 Diskette change line signal not active (FDC_ST_DISK_NOCHG)
;	AH = 01 Invalid drive number (FDC_ST_BADCMD)
;	AH = 06 Either change line not supported or diskette
;		change line signal is active (FDC_ST_DISK_CHG)
;	AH = 80 Diskette drive not ready or no drive present (FDC_ST_TIMEOUT)
;
;	FD_LAST_OP = FDC_ST_DISK_CHG if changed
;	CF = set if disk has been removed or an error occurred
;	AL = CMOS type
;----------------------------------------------------------------------------;
; In the BIOS, on most 286+ machines, service 16H reports whether the floppy
; disk in the drive specified in DL was changed. The status is reported in AH.
;
; There are several important points to keep in mind about service 16H.
; Before you use this BIOS service, call service 15H to ensure that the floppy
; disk drive hardware can sense when a disk is changed. You should follow a
; call to service 16H with a call to service 17H (Set Floppy Disk Type)
; whenever you detect a disk change.
;
; Keep in mind that the hardware can detect only whether the disk drive door
; was opened; it cannot tell whether a different disk was placed in the drive.
; You must still read data from the disk to determine whether the volume
; serial number, the root directory or a file allocation table can help to
; uniquely identify a disk.
;----------------------------------------------------------------------------;
		ASSUME DS:_BDA
INT_13_16 PROC
	CALL	FD_CHANGE_SUPPORT		; ZF=0 if no change support
	JNZ	INT_13_16_CHG		; change not supported

;----------------------------------------------------------------------------;
; Turn on motor and read DIR
;
	CALL	FD_GET_DIR			; NZ if drive changed, CF = 0
	CBW					; exit with AH = 00h (FDC_ST_DISK_NOCHG)
	JZ	INT_13_HD_RET_AH		; exit if not changed

;----------------------------------------------------------------------------;
; Exit with disk changed signal
;
INT_13_16_CHG:
	MOV	AH, FDC_ST_DISK_CHG	; exit with 06h
	JMP	SHORT INT_13_HD_ERR	; exit with AH status and CF
INT_13_16	ENDP

;----------------------------------------------------------------------------;
; INT 13 - HD extended functions
;----------------------------------------------------------------------------;
; FD_LAST_OP, AH and CF are set on these and returned from the INT 13 call.
;----------------------------------------------------------------------------;
INT_13_HD	PROC NEAR
	CMP	AH, 18H			; is > 18h?
	JA	INT_13_HD_ERR_BADCMD	; if so, not valid
	JE	INT_13_18			; 18h: Set media type for format
	CMP	AH, 08H			; is 8?
	JE	INT_13_8			; 08h: Get current drive parameters
	CMP	DL, FDC_MAX_DRIVES-1	; is drive number > max?
	JA	INT_13_HD_ERR_BADCMD 	; if so, exit
	CMP	AH, 16H			; is 16h?
	JE	INT_13_16			; 16h: Disk change line status
	JA	INT_13_17			; 17h: Set dasd type for format
	CMP	AH, 15H			; is 15h?
	JE	INT_13_15			; 15h: Read disk type/DASD type
INT_13_HD_ERR_BADCMD:
	MOV	AH, FDC_ST_BADCMD		; exit with 1 / invalid function
INT_13_HD_ERR:	
	STC					; exit with CF
INT_13_HD_RET_AH:
	MOV	FD_LAST_OP, AH		; exit with AH as last operation status
INT_13_HD_RET:
	RET
INT_13_HD	ENDP

;----------------------------------------------------------------------------;
; INT 13,15  Read disk type/DASD type
;----------------------------------------------------------------------------;
; Used to determine if INT 13,16 can detect disk change.
;
; Input:
;	AH = 15h
;	DL = drive number (0=A:, 1=2nd floppy)
; Return:
;	AH = 00 drive not present, CF = 1
;	   = 01 diskette, no change detection present, CF = 0
;	   = 02 diskette, change detection present, CF = 0
;----------------------------------------------------------------------------;
		ASSUME DS:_BDA
INT_13_15 PROC
	MOV	DH, AL				; preserve AL
	CALL	FD_GET_CMOS				; get CMOS type for DL
	CBW						; AH = 0 (not present)
	JC	INT_13_15_DONE
	INC	AH					; AH = 1 (no change detect)
	CALL	FD_CHANGE_SUPPORT			; NZ if no change support on DL
	JNZ	INT_13_15_DONE
	INC	AH					; AH = 2 (change present)
INT_13_15_DONE:
	MOV	AL, DH				; restore AL
	JMP	SHORT INT_13_HD_RET_AH
INT_13_15 ENDP

;----------------------------------------------------------------------------;
; INT 13,17  Set dasd type for format
;----------------------------------------------------------------------------;
; Tells BIOS format routine about the disk type. Only the disk number is 
; checked for validity.
;
; Note: This function is provided for use with DOS 3.0 or 3.1.
; Function 18h replaces this function for DOS version 3.2 and above.
;
; Input:
;	AH = 17h
;	AL = 00 no disk
;	   = 01  320k/360k diskette in 320k/360k drive
;	   = 02  320k/360k diskette in 1.2Mb drive
;	   = 03  1.2Mb diskette in 1.2Mb drive
;	   = 04  720k diskette in 720k drive
;		720K diskette in 1.44Mb drive
;		1.44Mb diskette in 1.44Mb drive
;		** 2.88 not supported
;	DL = drive number (0=A:, 1=2nd floppy)
; Return: nothing
;	AH = 0 is success or 1 if drive not valid, 80H if timeout or no disk
;	CF if error
;----------------------------------------------------------------------------;
; Things you must do:
;
; - If the diskette type in AL is invalid, AH and diskette status are set to
; 01h, CF is set and control is returned to the caller.
; - If the drive number is invalid, CF is set, AH and diskette status (40:41h)
; are set to 01h and control is returned to the caller.
; - The media transfer rate is set according to the drive type specified. For
; diskette types 02h, 03h and 04h, the change line determines if there is a
; diskette in the drive.
; - If there is no diskette in the drive, AH and diskette status are set to 
; 80h (time-out), CF is set and control is returned to the caller.
; - If a diskette is present, diskette status is set to 00h and the following
; values are set according to the diskette type in AL:
;
;	01	250 kb/s	single	known media	360K in 360K	93H
;	02	300 kb/s	dub step	known media	360K in 1.2M	74H
;	03	500 kb/s	single	known media 1.2 in 1.2		15H
;	04	250 kb/s	single	known media 720K			97H
;----------------------------------------------------------------------------;
		ASSUME DS:_BDA
INT_13_17 PROC
	MOV	AH, AL				; save input AL
	CALL	FD_GET_CMOS				; verify drive, AL = CMOS type
	MOV	AL, AH				; restore AL
	JC	INT_13_HD_ERR_BADCMD		; exit if drive not present/valid

;----------------------------------------------------------------------------;
; Is 360k drive? (AL=1)
;
INT_13_17_1:
	CMP	AL, 1					; is 360k drive (1)?
	JC	INT_13_HD_ERR_BADCMD		; low bounds check: CF if < 1
	JNE	INT_13_17_CHG			; if not, try 2-4
	MOV	AL, FMS360E				; Set 360 in 360K (93H)
	JMP	SHORT INT_13_17_SET		; set state and exit

;----------------------------------------------------------------------------;
; Drive supports change line. Determine if there is a disk in the drive.
;
INT_13_17_CHG:
	CALL	FD_DISK_CHANGE			; check media change / status
	JNC	INT_13_17_4				; jump if no error or change
	MOV	AH, _FD_LAST_OP			; get AH from FD_DISK_CHANGE
	JNZ	INT_13_HD_RET			; bad CMOS, reset timeout or no disk
							; fall through if media changed

;----------------------------------------------------------------------------;
; Is 720 or 1.44? (AL=4)
;
INT_13_17_4:
	CMP	AL, 4					; is a 3.5" drive (4)?
	JA	INT_13_HD_ERR_BADCMD		; type not valid (> 4)
	JNE	INT_13_17_23			; if not 4, try 2 or 3
	MOV	AL, FMS720E				; Set 720/1.44 (97H)
	JMP	SHORT INT_13_17_SET

;----------------------------------------------------------------------------;
; Is 1.2 in 1.2 (AL=3) or 360 in 1.2 (AL=2)?
;
INT_13_17_23:
	CMP	AL, 3					; is 1.2 in 1.2 (3)?
	MOV	AL, FMS12E				; set 1.2 in 1.2 (15H)
	JE	INT_13_17_SET
	MOV	AL, FMS360_12E			; must be 360 in 1.2 (74H)

;----------------------------------------------------------------------------;
; Establish state and exit
;
INT_13_17_SET:
	XOR	AH, AH				; AH = FDC_ST_OK
	JMP	FD_SET_STATE_DRV			; set state AL for drive DL

INT_13_17 ENDP

;----------------------------------------------------------------------------;
; INT 13,18  Set media type for format
;----------------------------------------------------------------------------;
; Input:
;	AH = 18h
;	CH = lower 8 bits of number of tracks (0-79)
;	CL = sectors per track (1-36)
;	DL = drive number (0-3)
; Output:
;	ES:DI = pointer to 11-byte Disk Base Table (DBT)
;	AH = 00h if requested combination supported
;	   = 01h if function not available
;	   = 0Ch if not supported or drive type unknown
;	   = 80h if there is no media in the drive
;	CF = 0 if successful
;	   = 1 if error
;----------------------------------------------------------------------------;
; Things you must do:
;
; - Check that drive (DL) is a valid floppy index (0 or 1). If not, return
; with CF and AH and diskette status 01H (bad command).
; - Drive supports change line? (TODO: necessary? possible DOS 3.2 issue)
;	- if so, reset change line
;		- if failure/active/no disk, set DASD to default unestablished
;		state for CMOS drive type and exit with FDC_ST_TIMEOUT
;		- if success/not active, continue
;	- if not 360K or 720K drive, continue
; - Check that the disk geometry is valid for the drive type according to
; the table below.
; - If the drive type cannot be determined, return with CF and AH and
; diskette status 0CH (unknown media).
; - Set data rate to high bits (MASK FLR) of 8BH FDC_RATE
; - Set media state to BDA as established
; - Return DBT based on the disk geometry input in ES:DI and return with
; no CF and AH diskette status 00H.
;
; Disk-to-format media table:
;
; Input				  Output
; CMOS Type		Trks	Sec	| Rate	Media State
; 1	360K		39	9	| 2		93H		360k in 360k drive
; 2	1.2		39	9	| 1		74H		360k in 1.2 drive
; 2	1.2		79	15	| 0		15H		1.2 in 1.2 drive
; 3	720K		79	9	| 2		97H		720k in 720k drive
; 4	1.44		79	9	| 2		97H		720k in 1.44 drive
; 4	1.44		79	18	| 0		17H		1.44 in 1.44 drive
; 5	2.88		79	9	| 3		D7H		720k in 2.88 drive
; 5	2.88		79	18	| 0		17H		1.44 in 2.88 drive
; 5	2.88		79	36	| 2		97H		2.88 in 2.88 drive
;----------------------------------------------------------------------------;
		ASSUME DS:_BDA
INT_13_18 PROC
	CALL	FD_GET_CMOS				; AL = CMOS type for drive DL
	JC	INT_13_HD_ERR_BADCMD		; return with bad command/CF

;----------------------------------------------------------------------------;
; Get FD table for drive type in AL and check sectors/cyl match
;
INT_13_18_FD:
	CALL	FD_CMOS_TBL				; BX = drive table for CMOS type AL
	MOV	AH, FDC_ST_ERR_MED		; AH = invalid media error
	JC	INT_13_18_EXIT			; CF if error
	CMP	CS:[BX].FDT_SC, CX		; sectors/cyl match?
	JE	INT_13_18_MATCHED

;----------------------------------------------------------------------------;
; No match for sectors/cyl for this CMOS type.
;
	CMP	AL, FDCM_14				; is 1.44 or 2.88?
	JB	INT_13_18_12			; if not, only valid type is 1.2
	DEC	AL
	JNZ	INT_13_18_FD			; retry as 1.44 or 720
	JMP	SHORT INT_13_18_EXIT		; no match, exit with invalid media

;----------------------------------------------------------------------------;
; Can only be 1.2 or invalid 360k/720k
;
INT_13_18_12:
	CMP	AL, FDCM_12				; is 1.2?
	JNE	INT_13_18_EXIT			; AL = 1 or 3, exit with invalid media

;----------------------------------------------------------------------------;
; Drive is CMOS 1.2, check if requested media is 360k
;
	CMP	CX, DBW < 39, 9 >			; is 39/9 DD and CMOS 1.2?
	JNE	INT_13_18_EXIT			; if not, exit with invalid media
	MOV	BX, OFFSET FT_360_12		; else is a 360 in 1.2

;----------------------------------------------------------------------------;
; Drive geometry match found, set media as established and set data rate
;
INT_13_18_MATCHED:
	MOV	AL, CS:[BX]				; AL = new BDA unestablished state byte
	CALL	FD_SET_ESTABLISH			; establish drive, AL = new media state
	CALL	FDC_SET_RATE			; Set rate from BDA byte in AL
	PUSH	CS					; ES = CS
	POP	ES					; (since ES not in stack frame)
	MOV	AH, FDC_ST_OK			; return with success
	LEA	BX, [BX].FDT_DBT			; CS:BX = start of DBT
	MOV	_INT_13_DI, BX			; return start of DBT as DI
INT_13_18_EXIT:
	CMP	AH, FDC_ST_OK+1			; check AH for error (CF = AH < 1)
	CMC   					; invert CF for return (CF = ! CF)
	JMP	INT_13_HD_RET_AH			; return with status in AH and CF
INT_13_18 ENDP

;----------------------------------------------------------------------------;
; INT 13, AH=2-5: HD Setup for FDC read/write operations
;----------------------------------------------------------------------------;
; Input:
;	AL = function number
;	DL = drive number
; Output:
;	CF if disk changed or seek/recal error
;----------------------------------------------------------------------------;
		ASSUME DS:_BDA
INT_13_2_5_HD_SETUP PROC
	;TEST	_FDC_CAP, MASK FHD		; adapter supports HD?
	;JZ	INT_13_2_5_HD_SETUP_EXIT	; skip if not

;----------------------------------------------------------------------------;
; Check for media change
;
			IF PCE_FIX NE 1
	CALL	FD_DISK_CHANGE			; is disk changed?
	JC	INT_13_2_5_HD_SETUP_EXIT	; exit I/O error or changed
			ENDIF

	PUSHX	AX, BX
	CMP	AL, 5					; ZF if format operation
	LAHF						; save format flag

			IF XT_V3_FIX EQ 1
;----------------------------------------------------------------------------;
; Workaround for 5160 clobbering BDA 90h-91h during POST after option ROM init
;
	TEST	_FDC_ST, MASK FLENV		; is establish invalid?
	JZ	XT_V3_FIX_DONE
	PUSH	DX
	CALL	FD_RESET_STATE
	XOR	DL, 1					; toggle second drive
	CALL	FD_RESET_STATE
	POP	DX
	AND	_FDC_ST, NOT MASK FLENV		; clear flag
XT_V3_FIX_DONE:
			ENDIF

;----------------------------------------------------------------------------;
; If not established, detect media and send new specify bytes and data rate.
;
	CALL	FD_GET_STATE			; AL = drive DL state, NZ if est.
	JNZ	INT_13_2_5_HD_EST			; jump if already established

;----------------------------------------------------------------------------;
; Media not established. Detect media on read/write/verify commands only.
;
	SAHF						; ZF if format
	JNE	INT_13_RWV_DET_MEDIA		; jump if not format command

;----------------------------------------------------------------------------;
; Media state is established or format command - set to default media for
; drive type.
;
INT_13_2_5_HD_EST:
	CALL	FDC_SETUP_DRV			; send specify and set rate for new media
	CLC						; CF only on media change
INT_13_2_5_HD_SETUP_DONE:
	POPX	BX, AX
INT_13_2_5_HD_SETUP_EXIT:
	RET

;----------------------------------------------------------------------------;
; If RWV, attempt to determine media and establish the media state if success
; If success, exit since SPECIFY and RATE already set by FD_GET_MEDIA.
;
INT_13_RWV_DET_MEDIA:
	CALL	FD_GET_MEDIA			; detect media and attempt establish
	JMP	INT_13_2_5_HD_SETUP_DONE	; exit with result in CF

INT_13_2_5_HD_SETUP ENDP

;----------------------------------------------------------------------------;
; FD_CHANGE_SUPPORT: Determine if change is supported on drive
;----------------------------------------------------------------------------;
; Input:
;	DS = BDA
;	DL = drive #
; Output:
;	ZF = 0 if no change support, ZF = 1 if change support
;	CF = 0
;----------------------------------------------------------------------------;
FD_CHANGE_SUPPORT PROC
	PUSH	AX
			IF FDC_MAX_DRIVES GT 2
;----------------------------------------------------------------------------;
; Longer version to support 4 drives
;
	MOV	AH, MASK FM1C			; change support mask for drive 1 or 3
	PUSH	DX					; save DL
	SHR	DL, 1					; CF if 1 or 3, ZF if 0 or 1
	JC	FD_DISK_CHANGE_13			; jump if drive 1 or 3
	MOV	AH, MASK FM0C			; change support mask for drive 0 or 2
FD_DISK_CHANGE_13:
	JNZ	FD_DISK_CHANGE_23			; jump if drive 2/3
	MOV	AL, FD_MODE				; get drive 0/1 byte
	JMP	SHORT FD_DISK_CHANGE_CHK
FD_DISK_CHANGE_23:
	MOV	AL, FD2_MODE			; get drive 2/3 byte
FD_DISK_CHANGE_CHK:
	POP	DX					; restore DL

			ELSE
;----------------------------------------------------------------------------;
; Shorter version to support up to 2 drives
;
	MOV	AH, MASK FM1C			; change support mask for drive 1
	TEST	DL, DL				; DL = 0?
	JNZ	FD_DISK_CHANGE_1			; jump if drive 1 
	MOV	AH, MASK FM0C			; change support mask for drive 0
FD_DISK_CHANGE_1: 
	MOV	AL, FD_MODE
			ENDIF

;----------------------------------------------------------------------------;
; Test and invert ZF result
;
	AND	AL, AH				; NZ if change line support
	XOR	AL, AH				; ZF if change line support
	POP	AX
	RET
FD_CHANGE_SUPPORT ENDP

;----------------------------------------------------------------------------;
; FD_SET_MODE_CMOS: Setup BDA drive type in FD_MODE using drive number DL
;----------------------------------------------------------------------------;
; Sets up drive's capabilities during initial boot. This is used to
; simplify conditional tests during operation.
;
; Input:
;	DS = BDA
;	DL = drive #
; Output:
;	AL = FD_MODE bits
;	CF if drive not valid
;----------------------------------------------------------------------------;
FD_SET_MODE_CMOS PROC
	CALL	FD_GET_CMOS				; AL = CMOS type
	JC	FD_SET_MODE_RET
	PUSH	BX
	MOV	BX, OFFSET FD_MODE_CMOS_TBL[-1]	; table 1 based since AL > 0
	XLAT	CS:[BX]
	POP	BX

;----------------------------------------------------------------------------;
; FD_SET_MODE: Set BDA drive type in FD_MODE using AL and DL
;----------------------------------------------------------------------------;
; Input:
;	AL = FD_MODE bits
;	DS = BDA
;	DL = drive # (0-1)
;----------------------------------------------------------------------------;
FD_SET_MODE PROC
	PUSH	AX
	MOV	AH, MASK FM0C OR MASK FM0P OR MASK FM0M OR MASK FM08

			IF FDC_MAX_DRIVES GT 2
;----------------------------------------------------------------------------;
; Longer version to support 4 drives
;
	PUSH	BX
	MOV	BX, OFFSET FD_MODE		; assume drive 0 or 1
	PUSH	DX					; save DL
	SHR	DL, 1					; CF if 1 or 3, ZF if 0 or 1
	POP	DX					; restore DL
	JZ	FD_SET_MODE_01			; jump if 0 or 1
	MOV	BX, OFFSET FD2_MODE		; drive 2 or 3
FD_SET_MODE_01:
	JNC	FD_SET_MODE_NO_SHIFT		; jump if drive 0 or 2
			IF CPU_TYPE EQ CPU_V20 OR CPU_TYPE EQ CPU_186
	SHL	AX, 4
			ELSE
		REPT	4				; shift mode type into
	SHL	AX, 1					; correct nibble
		ENDM
			ENDIF
FD_SET_MODE_NO_SHIFT:
	AND	AL, AH				; only FD_MODE bits
	NOT	AH
	AND	[BX], AH				; clear bits
	OR	[BX], AL				; set bits, CF = 0
	POP	BX

			ELSE
;----------------------------------------------------------------------------;
; Shorter version to support up to 2 drives
;
	CMP	DL, 1					; validate floppy
	JA	FD_SET_MODE_EXIT

;----------------------------------------------------------------------------;
; Shift bits to correct nibble for drive
;
	JNE	FD_SET_MODE_NO_SHIFT		; jump if drive 0
			IF CPU_TYPE EQ CPU_V20 OR CPU_TYPE EQ CPU_186
	SHL	AX, 4
			ELSE
		REPT	4				; shift mode type into
	SHL	AX, 1					; correct nibble
		ENDM
			ENDIF
FD_SET_MODE_NO_SHIFT:
	AND	AL, AH				; only FD_MODE bits
	NOT	AH
	AND	FD_MODE, AH				; clear bits
	OR	FD_MODE, AL				; set bits, CF = 0
			ENDIF

FD_SET_MODE_EXIT:
	POP	AX
FD_SET_MODE_RET:
	RET
FD_SET_MODE ENDP

;----------------------------------------------------------------------------;
; FD Drive mode table
;----------------------------------------------------------------------------;
FD_MODE_CMOS_TBL LABEL BYTE
	DB	FDM_360			; type 1 360 
	DB	FDM_12			; type 2 1.2
	DB	FDM_720			; type 3 720
	DB	FDM_14			; type 4 1.44
	DB	FDM_28			; type 5 2.88

FD_SET_MODE_CMOS ENDP
		ASSUME DS:NOTHING

;----------------------------------------------------------------------------;
; FD_GET_STATE_DRV: Get current media state of a drive
; UNUSED
;----------------------------------------------------------------------------;
; Input:
;	DL = drive index (0 - FDC_MAX_DRIVES)
;	DS = BDA
; Output:
;	AL = FD_MEDIA_ST drive state byte
;	CF if drive number out of range / not valid
;	NZ if media established, ZF if not
;----------------------------------------------------------------------------;
		ASSUME DS:_BDA
;FD_GET_STATE_DRV PROC
;	CMP	DL, FDC_MAX_DRIVES		; is drive # valid?
;	CMC						; CF if not valid
;	JBE	FD_GET_STATE_RET			; exit with CF if invalid

;----------------------------------------------------------------------------;
; FD_GET_STATE: Get current media state of a drive
;----------------------------------------------------------------------------;
; Same as above but bounds not checked
;----------------------------------------------------------------------------;
FD_GET_STATE PROC
	PUSH	BX
	MOV	BX, OFFSET FD_MEDIA_ST
			IF FDC_MAX_DRIVES GT 2
	CMP	DL, 2					; drive 2 or 3?
	JB	FD_GET_STATE_1			; jump if 0 or 1
	MOV	BL, LOW (OFFSET FD2_MEDIA_ST-2) ; set to drive 2 or 3 table
FD_GET_STATE_1:
			ENDIF
	MOV	AL, DL
	XLAT						; AL = state byte
	POP	BX
	TEST	AL, MASK FSE			; is media established?
FD_GET_STATE_RET:
	RET
FD_GET_STATE ENDP
;FD_GET_STATE_DRV ENDP
		ASSUME DS:NOTHING

;----------------------------------------------------------------------------;
; FD_RESET_STATE: Reset current media state of a drive to default unestablished
;----------------------------------------------------------------------------;
; Input:
;	DL = drive index (0 - FDC_MAX_DRIVES)
;	DS = BDA
; Output:
;	AL = new FD_MEDIA_ST byte
;	CS:BX = drive table pointer for drive DL
;	CF if drive not valid
; Clobbers: BX
;----------------------------------------------------------------------------;
		ASSUME DS:_BDA
FD_RESET_STATE PROC
	CALL	FD_CMOS_DRIVE_TBL			; CS:BX = drive table from CMOS type drive DL
	JC	FD_SET_STATE_RET			; exit if drive not valid
	MOV	AL, CS:[BX]				; get unestablished default media type
	;JMP	SHORT FD_SET_STATE_DRV		; necessary?

;----------------------------------------------------------------------------;
; FD_SET_STATE: Set media state of a drive
;----------------------------------------------------------------------------;
; Input:
;	DL = drive index (0 - FDC_MAX_DRIVES)
;	AL = FD_MEDIA_ST drive state byte
;	DS = BDA
; Output:
;	CF if drive not valid
;----------------------------------------------------------------------------;
FD_SET_STATE PROC
	CMP	DL, FDC_MAX_DRIVES		; is drive # valid?
	CMC						; CF if not valid
	JBE	FD_SET_STATE_RET			; exit with CF if invalid

;----------------------------------------------------------------------------;
; FD_SET_STATE_DRV: Same as above but drive bounds not checked
;----------------------------------------------------------------------------;
FD_SET_STATE_DRV PROC
	PUSH	BX
	MOV	BL, DL				; BX = drive table index
	XOR	BH, BH				; zero extend and clear CF
			IF FDC_MAX_DRIVES GT 2
	TEST	DL, 0010B				; is drive 2 or 3?, CF=0
	JZ	FD_SET_STATE_DRV_1		; jump if 0 or 1
	LEA	BX, [FD2_MEDIA_ST-FD_MEDIA_ST-2][BX]	; adjust to drive 2-3 table
FD_SET_STATE_DRV_1:
			ENDIF
	MOV	_FD_MEDIA_ST[BX], AL		; write to BDA
	POP	BX
FD_GET_MEDIA_RET_1:
FD_SET_STATE_RET:
	RET
FD_SET_STATE_DRV ENDP
FD_SET_STATE ENDP
FD_RESET_STATE ENDP
		ASSUME DS:NOTHING

;----------------------------------------------------------------------------;
; FD_SET_ESTABLISH_DRV: Set drive Established drive in DL from current BDA
; media state (UNUSED)
;----------------------------------------------------------------------------;
; Input:
;	DL = drive index (0 - FDC_MAX_DRIVES-1)
; Output:
;	AL = new established media type
;	AH = media type (FSD low three bits)
;----------------------------------------------------------------------------;
;		ASSUME DS:_BDA
;FD_SET_ESTABLISH_DRV PROC
;	CALL	FD_GET_STATE		; get current media state
;	JC	FD_SET_STATE_RET

;----------------------------------------------------------------------------;
; FD_SET_ESTABLISH: Set drive Established drive in DL from state in AL
;----------------------------------------------------------------------------;
; Input:
;	AL = current unestablished media type
;	DL = drive index (0 - FDC_MAX_DRIVES-1)
; Output:
;	AL = new established media byte
;	AH = media type (FSD low three bits)
;----------------------------------------------------------------------------;
FD_SET_ESTABLISH PROC
	MOV	AH, AL			; save state byte
	AND	AH, MASK FSD		; isolate drive type
	CMP	AH, FD360E			; is not established?
	JAE	FD_SET_ESTABLISH_2	; no need to change type
	ADD	AL, FD360E			; increment to established type
FD_SET_ESTABLISH_2:
	OR	AL, MASK FSE		; set established
	JMP	SHORT FD_SET_STATE_DRV
FD_SET_ESTABLISH ENDP
;FD_SET_ESTABLISH_DRV ENDP
		ASSUME DS:NOTHING

;----------------------------------------------------------------------------;
; FD_GET_MEDIA: Read Media and attempt to determine type, set in BDA
;----------------------------------------------------------------------------;
; Input:
;	DL = drive index
; Output:
;	CF if error, FDC_ST_ERR_SEEK if recal/seek failure
;	AH = new media state
;	On success, media state established.
;	On failure, media state unestablished.
;
;----------------------------------------------------------------------------;
; Check drive index and CMOS type. If not valid, assume 360K drive.
; For drive CMOS type, attempt to determine type of media by reading track
; IDs 0 and 10, for all valid media formats supported by drive.
;----------------------------------------------------------------------------;
		ASSUME DS:_BDA
FD_GET_MEDIA PROC
	CALL	FD_GET_CMOS				; AL = CMOS type
	JC	FD_GET_MEDIA_RET_1		; exit if CMOS type invalid or not present
	FD_DEBUG 'GET_MEDIA'

;----------------------------------------------------------------------------;
; Set motor count to maximum so it does not shut off while testing.
;
	CBW						; AH = 0
	MOV	_FD_MOTOR_CT, AH			; set motor count to max
	MOV	AH, FMS360E				; default
	JC	CHECK_360				; assume 360K if CMOS invalid

;----------------------------------------------------------------------------;
; Using CMOS drive type, test currently inserted disk for all valid media types
;
	CMP	AL, FDCM_12				; CMOS 1.2 or 360?
	JB	CHECK_360				; < 2
	JE	CHECK_12				; = 2
	CMP	AL, FDCM_720			; CMOS 720 ?
	JE	CHECK_720				; = 3

			IF FDC_PMODE EQ 1
;----------------------------------------------------------------------------;
; If no PMODE support, CMOS type >=4, use 1.44m then 720k
;
	CMP	AL, FDCM_14				; CMOS 1.44?
	JE	CHECK_14				; = 4
							; fall through for >= 5 CMOS 2.88

;----------------------------------------------------------------------------;
; If CMOS type >=5, try 2.88m, 1.44m then 720k
;
CHECK_28:
	MOV	AH, FMS288E				; start with 2.88 established
	CALL	FD_SETUP_MEDIA			; set rate and try to read media
	JNC	FD_GET_MEDIA_RET
	DEC	AX					; try again as 1.44, CMOS type 4
			ENDIF

;----------------------------------------------------------------------------;
; If CMOS type = 4, Try 1.44m then 720k
;
CHECK_14:
	MOV	AH, FMS144E				; 1.44 established
	CALL	FD_SETUP_MEDIA
	JNC	FD_GET_MEDIA_RET
	DEC	AX					; try again as 720K, CMOS type 3

;----------------------------------------------------------------------------;
; If CMOS type = 3, try 720k
;
CHECK_720:
	MOV	AH, FMS720E				; last try as 720K
	JMP	SHORT FD_SETUP_MEDIA

;----------------------------------------------------------------------------;
; If CMOS type = 2, try 1.2
;
CHECK_12:
	MOV	AH, FMS12E				; try as 1.2
	CALL	FD_SETUP_MEDIA
	JNC	FD_GET_MEDIA_RET
	DEC	AX					; try again as 360, CMOS type 1
	MOV	AH, FMS360_12E			; and 360 in 1.2

;----------------------------------------------------------------------------;
; If CMOS type < 2, try 360k
;
CHECK_360:
							; fall through for FD_SETUP_MEDIA

;----------------------------------------------------------------------------;
; FD_SETUP_MEDIA: Set up and establish drive for media and test if disk is
; readable with current settings.
;----------------------------------------------------------------------------;
; Input:
;	AH = media state
;	DL = drive
;
; Output:
;	BDA media state set established if valid, unestablished if not
;----------------------------------------------------------------------------;
FD_SETUP_MEDIA PROC
	PUSH	AX
	PUSH	BX
	MOV	AL, AH
	CALL	FD_SET_STATE_DRV			; set media state byte AL for drive DL
	CALL	FDC_SETUP_DRV			; send specify and set rate for new media
	POP	BX
	POP	AX

;----------------------------------------------------------------------------;
; FD_TEST_MEDIA: Test if disk is readable with current settings
;----------------------------------------------------------------------------;
; Input:
;	AH = media state
;	DL = drive
;----------------------------------------------------------------------------;
FD_TEST_MEDIA PROC
		IF CPU_TYPE EQ CPU_V20 OR CPU_TYPE EQ CPU_186
	PUSHA
		ELSE
	PUSHX	AX, BX, CX, DX
		ENDIF
	MOV	DH, AH				; DH = established test state
	MOV	CL, _FD_LAST_OP			; save last op status
	CALL	FDC_RECAL_DBL			; seek to track 0 and repeat if needed
	JC	FD_TEST_RECAL_ERR			; exit if recal failed twice

;----------------------------------------------------------------------------;
; Read ID for track 0, head 0 then read track 10 and verify track IDs match.
; If error, disk is likely unformatted or incorrect data rate.
; Repeat three times.
;
	MOV	AH, 3					; retry counter
FD_TEST_MEDIA_LOOP:
	XOR	CH, CH				; check track 0
	CALL	FD_GET_ID				; CF if error, AL=ID track
	JC	FD_TEST_MEDIA_LOOP_END		; error, attempt retry
	CMP	AL, CH				; tracks match?
	JNE	FD_TEST_MEDIA_LOOP_END		; if tracks do not match, retry

	MOV	CH, 10				; check track 10
			IF FD_ENABLE_SS EQ 0
	XOR	DL, 100B				; head 1 (will not work on SS disks)
			ENDIF
	CALL	FD_GET_ID				; CF if error, AL=ID track
	JC	FD_TEST_MEDIA_LOOP_END		; error, attempt retry
	CMP	AL, CH				; tracks match?
	JE	FD_TEST_MEDIA_EXIT		; exit if so

FD_TEST_MEDIA_LOOP_END:
			IF FD_ENABLE_SS EQ 0
	AND	DL, 011B				; head 0
			ENDIF
	DEC	AH
	JNZ	FD_TEST_MEDIA_LOOP

FD_TEST_MEDIA_ERR:
	;MOV	_FD_LAST_OP, FDC_ST_OK		; discard last op status
	MOV	_FD_LAST_OP, CL			; restore last op status
	MOV	AL, DH				; AH = established media type
	CALL	FD_RESET_STATE			; unestablish media type
	STC						; failed 3 times, exit with error

FD_TEST_MEDIA_EXIT:
		IF CPU_TYPE EQ CPU_V20 OR CPU_TYPE EQ CPU_186
	POPA						; restore all registers
		ELSE
	POPX	DX, CX, BX, AX
		ENDIF

FD_GET_MEDIA_RET:
	RET

FD_TEST_RECAL_ERR:
	MOV	CL, FDC_ST_ERR_SEEK		; recal, seek or drive error
	JMP	SHORT FD_TEST_MEDIA_ERR		; reset state and exit

		ASSUME DS:NOTHING
FD_TEST_MEDIA ENDP
FD_SETUP_MEDIA ENDP
FD_GET_MEDIA ENDP

;----------------------------------------------------------------------------;
; Read Media ID from disk
;----------------------------------------------------------------------------;
; Input:
;	CH = track
;	DL = drive index bits 1-0, head bit 2
;	DI = OFFSET FD_LAST_OP
; Output:
;	AL = track number
;	results in FDC_LAST_ST
;	CF if error
;----------------------------------------------------------------------------;
		ASSUME DS:_BDA
FD_GET_ID PROC
	PUSH	AX					; preserve AH
	XOR	AL, AL				; always require recal
	MOV	FD_CAL_ST, AL
	CALL	FDC_SEEK				; seek to track in CH
	JC	FD_GET_ID_ERR	
	MOV	AL, FDC_CMD_RMID			; read Media ID command
	CALL	FDC_SEND 				; send command, CF if error
	JC	FD_GET_ID_ERR
	MOV	AL, DL				; drive index, head 0
	CALL	FDC_SEND 				; send command, CF if error
	CALL	FDC_WAIT_STATUS
FD_GET_ID_ERR:
	POP	AX					; restore AH
	MOV	AL, FDC_LAST_ST.CYL		; AL = track number read
	RET
FD_GET_ID ENDP
		ASSUME DS:NOTHING

;----------------------------------------------------------------------------;
; Set up drive configuration state for media
;----------------------------------------------------------------------------;
; Input:
;	AL = established media state (FD_MEDIA_ST[DL])
;	DL = drive number (0-3) NOT BOUNDS CHECKED
;
; Clobbers: BX
;----------------------------------------------------------------------------;
; 1. Send specify bytes for media state to controller if any are true:
;	- not last drive sent
;	- not still valid
;	- media is established
; 2. If Standard PMODE is required and EPMODE not supported:
;	- send Standard PERPENDICULAR command for drive
;	- set precomp for PMODE or non-PMODE
; 3. Set data rate on FDC and save to BDA
;----------------------------------------------------------------------------;
		ASSUME DS:_BDA
FDC_SETUP_DRV PROC
	PUSH	AX
	MOV	BL, AL				; save state byte

;----------------------------------------------------------------------------;
; Determine if last specify byte sent is still valid
;
FDC_SEND_SPECIFY:
	MOV	AL, FDC_ST				; get last specify-sent drive bit
	TEST	AL, MASK FLSV			; is last specify valid?
	JZ	FDC_SEND_SPECIFY_START		; if not, force re-sending

;----------------------------------------------------------------------------;
; Determine if last specify byte sent is still valid for this drive
;
	AND	AL, MASK FLSD			; isolate drive number
		REPT FLSD
	SHR	AL, 1					; shift into low bits to compare to DL
		ENDM
	CMP	AL, DL
	JE	FDC_SEND_SPECIFY_DONE		; exit if same drive

;----------------------------------------------------------------------------;
; Send Specify bytes to FDC for established media
;
; Note: All media types are the same except for 1.44 and 2.88, so only those
; need to be checked.
;
FDC_SEND_SPECIFY_START:
	FD_DEBUG 'SEND_SPEC'
	MOV	AL, FDC_CMD_SPEC 			; [0] FDC Specify command
	CALL	FDC_SEND 				; send command in AL, CF if error
	CMP	BL, FMS144E				; is established 1.44?
	MOV	AL, SRT_144				; use 1.44 SRT byte (BFH)
	JE	FDC_SPECIFY_SEND
	CMP	BL, FMS288E				; is established 2.88?
	MOV	AL, SRT_288				; use 2.88 SRT byte (AFH)
	JE	FDC_SPECIFY_SEND
	MOV	AL, SRT_STD				; else use standard SRT (DFH)
FDC_SPECIFY_SEND:
	CALL	FDC_SEND				; [1] step rate time, head unload time
	MOV	AL, DBT.HLT_ND			; [2] head load time (01H), DMA mode (ND)
	CALL	FDC_SEND_PARAM			; send from DBT

;----------------------------------------------------------------------------;
; Save specified drive to BDA
;
	MOV	AL, DL				; AL = drive index
		REPT FLSD
	SHL	AL, 1
		ENDM
	AND	_FDC_ST, NOT MASK FLSD		; clear drive bits in BDA
	AND	AL, MASK FLSD			; isolate drive bits (necessary?)
	OR	AL, MASK FLSV			; mark valid bit
	OR	_FDC_ST, AL				; write to BDA

			IF FDC_PMODE EQ 1 AND FDC_SPMODE EQ 1
;----------------------------------------------------------------------------;
; Use standard 82077-compatible PERPENDICULAR command to send GAP2/WMODE bits
;
;----------------------------------------------------------------------------;
; If only standard PMODE is supported and required by media type, it must be
; sent here between drive changes.
;
FDC_SEND_SETUP_SPMODE PROC
	MOV	AL, FDC_CAP				; AL = FDC capabilities
	AND	AL, FDC_FT_PMODE OR FDC_FT_EPMODE	; isolate PMODE and EPMODE
	CMP	AL, FDC_FT_PMODE			; supports pmode, but not EPMODE cmd?
	JNE	FDC_SEND_SPECIFY_DONE		; exit if EPMODE or no PMODE at all

;----------------------------------------------------------------------------;
; Send only if PMODE is required by any drive
;
			IF FDC_MAX_DRIVES EQ 2	; shorter if only 2 drive support
	TEST	_FD_MODE, MASK FM1P OR MASK FM0P
	JZ	FDC_SEND_SPECIFY_DONE		; exit if nether drive requires
			ELSE
	TEST	_FD_MODE, MASK FM1P OR MASK FM0P
	JNZ	FDC_SEND_SPMODE
	TEST	_FD2_MODE, MASK FM1P OR MASK FM0P
	JZ	FDC_SEND_SPECIFY_DONE		; exit if no drives require
			ENDIF

;----------------------------------------------------------------------------;
; Use standard 82077-compatible PERPENDICULAR command to send GAP2/WMODE bits
;
FDC_SEND_SPMODE:
	MOV	AL, FDC_CMD_PMODE
	CALL	FDC_SEND
	MOV	AL, FDC_PERP_CB <>		; default to disabled
	TEST	BL, MASK FSPM			; ZF=0 if pmode needed
	JZ	FDC_SET_PMODE_SEND		; jump and disable pmode

				IF FDC_PMODE_500 EQ 1
;----------------------------------------------------------------------------;
; Check if 500K PMODE is supported. This was rarely (if) ever used on PC.
;
	MOV	AL, BL
	AND	AL, MASK FLR
	CMP	AL, FSR500
	MOV	AL, FDC_PERP_500			; GAP2 and WMODE enabled for 500K/s
	JE	FDC_SET_PMODE_SEND		; jump if 500
				ENDIF			; FDC_PMODE_500 EQ 1

	MOV	AL, FDC_PERP_1K			; GAP2 and WMODE enabled for 1M/s
FDC_SET_PMODE_SEND:
	;FD_DEBUG 'SPMODE'
	CALL	FDC_SEND
	JC	FDC_SEND_SPECIFY_DONE		; exit if error

;----------------------------------------------------------------------------;
; If standard PMODE, disable precomp for PMODE.
;
	MOV	AL, BL				; AL = data rate
	AND	AL, MASK FLR			; isolate data rate
	TEST	BL, MASK FSPM			; ZF=0 if pmode needed
	JZ	FDC_SEND_SPEC_PMODE
	OR	AL, FDC_DSR_W <,,,FDC_PC_PMODE>	; set precomp for pmode
FDC_SEND_SPEC_PMODE:
	PUSH	DX
	MOV	DX, FDC_DSR
	OUT	DX, AL
	POP	DX

FDC_SEND_SETUP_SPMODE ENDP
			ENDIF				; END IF FDC_PMODE EQ 1

FDC_SEND_SPECIFY_DONE:
	POP	AX					; restore AL media state
							; fall through to set rate

;----------------------------------------------------------------------------;
; FDC_SET_RATE: Set data rate on FDC and BDA
;----------------------------------------------------------------------------;
; Input:
;	AL = current media state byte (rate in high two bits)
; Output:
;	ZF if no change, NZ if changed
;	CF = 0
;----------------------------------------------------------------------------;
FDC_SET_RATE PROC
	PUSH	AX
	PUSH	DX
	PUSHF						; save IF

;----------------------------------------------------------------------------;
; Clear BDA last data rate and set to currently established media state rate
;
	XCHG	AX, DX				; DL = new rate
	CLI						; no ints while setting FDC and BDA
	MOV	AL, FD_LR				; last data rate FDC_RATE
	MOV	DH, AL				; DH = last rate
	AND	DX, DBW <MASK FSR, MASK FSR>	; isolate data rates
	CMP	DL, DH				; same rate?
	JE	FDC_SET_RATE_DONE			; if so, do not change (ZF = 1)
	AND	AL, NOT MASK FSR			; clear last rate
	OR	AL, DL				; combine with FDC_RATE
	MOV	FD_LR, AL				; save to BDA

;----------------------------------------------------------------------------;
; Send data rate to FDC
;
	XCHG	AX, DX				; AL = data rate command
	ROL	AL, 1					; move data rate to low two bits
	ROL	AL, 1
	MOV	DX, FDC_CONF			; Rate Configuration Control Register
	OUT	DX, AL				; AL = register value
	INC	AX					; ZF = 0

FDC_SET_RATE_DONE:
	LAHF						; save result flags
	POPF						; restore IF
	SAHF						; restore result flags
	POP	DX
	POP	AX
FDC_SET_RATE_EXIT:
	RET

FDC_SET_RATE ENDP
FDC_SETUP_DRV ENDP

;----------------------------------------------------------------------------;
; FD_GET_DIR: Read DIR register to check disk change signal
;----------------------------------------------------------------------------;
; Input:
;	DL = drive to check
; Output:
;	ZF = 0 if changed
;	ZF = 1 if not changed
;	CF = 0
; AL preserved
;----------------------------------------------------------------------------;
; Note: You must turn on the drive motor bit before you access the DIR 
; register for a selected drive (you do not have to wait for the motor to
; spin up, though). It may also be necessary to read the register five times
; (discard the first 4 values) when changing the selected drive -- because 
; "selecting" sometimes takes a little time.
;
; https://wiki.osdev.org/Floppy_Disk_Controller#DIR_register.2C_Disk_Change_bit
;----------------------------------------------------------------------------;
FD_GET_DIR PROC
	PUSH	AX
	CALL	FDC_MOTOR_ON		; turn on motor for drive DL
	PUSH	DX
	MOV	DX, FDC_IN			; Digital Input Register
			IF IS_TURBO EQ 1
		REPT 5			; read five times if turbo
	IN	AL, DX			; AL = register value
		ENDM
			ELSE
	IN	AL, DX			; AL = register value
			ENDIF
	AND	AL, MASK FCHG		; diskette change latch high?
	POP	DX
	POP	AX
	RET
FD_GET_DIR ENDP

;----------------------------------------------------------------------------;
; FD_DISK_CHANGE: Check if disk in drive DL has changed and clear active 
; line latch.
;----------------------------------------------------------------------------;
; Input:
;	DL = drive index
;	DS = BDA
; Output:
; 	CF=0, ZF=0, FD_LAST_OP=00 if change not supported
;	CF=0, ZF=1, FD_LAST_OP=00 if change supported but not active
;	CF=1, ZF=1, FD_LAST_OP=06 if change supported, active and reset successfully
;	CF=1, ZF=0, FD_LAST_OP=01 if drive not valid in CMOS
;	CF=1, ZF=0, FD_LAST_OP=80 if reset/seek fail
;----------------------------------------------------------------------------;
			ASSUME DS:_BDA
FD_DISK_CHANGE PROC
	PUSHX	AX, CX, DX

;----------------------------------------------------------------------------;
; Check drive bounds
;
	CALL	FD_GET_CMOS				; drive index valid?
	MOV	AH, FDC_ST_BADCMD			; 01
	JC	FD_DISK_CHANGE_RESULT

	MOV	AH, FDC_ST_DISK_NOCHG		; default not change 00

;----------------------------------------------------------------------------;
; Check if drive supports change line
;
	CALL	FD_CHANGE_SUPPORT
	JNZ	FD_DISK_CHANGE_DONE		; return with ZF=0, CF=0

;----------------------------------------------------------------------------;
; Check change line
;
			IF PCE_FIX NE 1
	CALL	FD_GET_DIR				; motor on, DIR register set?
	JZ	FD_DISK_CHANGE_DONE		; if no change, return with CF=0, ZF=1
			ENDIF

;----------------------------------------------------------------------------;
; Disk has been changed
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; Reset state to default
;
	CALL	FD_RESET_STATE			; reset back to default
	MOV	AH, FDC_ST_DISK_NOCHG		; drive not present/valid
	JC	FD_DISK_CHANGE_RESULT		; exit if drive index not valid CF=1

;----------------------------------------------------------------------------;
; Clear motor status flag (FD_MOTOR_ST) for specified drive so motor
; spin-up time is not skipped on next seek operation.
;
	MOV	CL, DL 				; move to CL for shift
	MOV	AL, NOT 1				; create mask for drive run flag
	ROL	AL, CL
	AND	FD_MOTOR_ST, AL			; clear motor on bit
	CALL	FDC_MOTOR_ON

;----------------------------------------------------------------------------;
; Full reset of FDC
;
	PUSHX	AX, DX
	CALL	FDC_RESET				; reset FDC (clobbers CX also)
	POPX	DX, AX
	JC	FD_DISK_CHANGE_RESULT

		IF FDC_TWADDLE EQ 1
;----------------------------------------------------------------------------;
; INCOMPLETE: Check Twaddle support
;
;	CF if not checked (JC)
;	ZF if no twaddle (JZ)
;	NZ and NC if twaddle (JA)
;----------------------------------------------------------------------------;
; twaddle: "Apparently a small number of floppy drives also support one 
; additional way to clear the bit -- something that Linux calls a "twaddle". 
; Simply toggle the drive motor bit on, off, and then on again. When your
; driver tries to clear the Disk Change bit the first time, it can try a
; twaddle, and see if it works, and keep a flag if it does."
;----------------------------------------------------------------------------;
	CALL	FD_GET_CHG_TYPE
	JA	FD_TW					; twaddle supported
	JZ	FD_NO_TW				; not supported
	JC	FD_CHECK_TW				; not yet checked
FD_CHECK_TW:
FD_NO_TW:
FD_TW:
		ENDIF		; END FDC_TWADDLE

;----------------------------------------------------------------------------;
; Seek to track 0 and then 1 to clear change signal
;
	MOV	CH, 1					; seek to track 1
	CALL	FDC_SEEK				; CH = track, DL = drive
	CALL	FDC_RECAL				; seek to track 0

;----------------------------------------------------------------------------;
; read changed line again, if error exit with timeout error
;
	CALL	FD_GET_DIR
	MOV	AH, FDC_ST_TIMEOUT		; timeout error media didn't change
	JNZ	FD_DISK_CHANGE_RESULT		; jump if change line still active

;----------------------------------------------------------------------------;
; set changed flag in last operation
;
	AND	_FDC_ST, NOT MASK FLSV		; force re-send of specify bytes on next op
	MOV	AH, FDC_ST_DISK_CHG		; media changed status

;----------------------------------------------------------------------------;
; CF set, ZF if media changed (success case)
;
FD_DISK_CHANGE_RESULT:
	CMP	AH, FDC_ST_DISK_CHG		; ZF=1 if changed, ZF=0 if timeout or bad cmd
	STC						; changed or error

FD_DISK_CHANGE_DONE:
	MOV	_FD_LAST_OP, AH
	POPX	DX, CX, AX
	RET
FD_DISK_CHANGE ENDP

			IF FDC_PMODE EQ 1
;----------------------------------------------------------------------------;
; Set Enhanced PMODE command (82077AA+)
;----------------------------------------------------------------------------;
; Set perpendicular mode if supported by drive type. This persists until 
; FDC hardware reset.
; TODO: Four drive support
;----------------------------------------------------------------------------;
FDC_SET_EPMODE PROC
	TEST	FDC_CAP, FDC_FT_EPMODE		; controller supports EPMODE cmd?
	JZ	FDC_SET_EPMODE_DONE		; exit if not

;----------------------------------------------------------------------------;
; Determine which drives support pmode
;
	MOV	AL, FD_MODE				; AL = drive capabilities
	AND	AL, MASK FM0P OR MASK FM1P	; isolate pmode bits, AH=0
	JZ	FDC_SET_EPMODE_DONE		; if neither support, skip

	MOV	CH, AL				; CH = D1 bits
	AND	AL, MASK FPN_DC0
		REPT FM1P-FPN_DC1
	SHR	CH, 1					; shift to EPMODE D1 bit
		ENDM
	OR	AL, FDC_PERP_NSC <1>		; enable pmode bit
	OR	CH, AL				; combine drive bits

; TODO: Drive 2-3:
; x3xx x2xx -> xx32 xxxx
; CL	= x3xx x2xx
; CL	= CL SHL 2 -> xxx2 xxxx
; AL	= SHR 1 -> xx3x xxxx
; AL	= AL AND 0010 0000
; OR  CH, CL
; OR  CH, AL

FDC_SET_EPMODE_SEND:
	;FD_DEBUG	'EPMODE'
	MOV	AL, FDC_CMD_PMODE
	CALL	FDC_SEND				; send command byte
	MOV	AL, CH				; AL = pmode byte
	CALL	FDC_SEND				; send pmode data byte
FDC_SET_EPMODE_DONE:
	RET
FDC_SET_EPMODE ENDP
			ENDIF

;----------------------------------------------------------------------------;
; Send FDC CONFIGURE command
;----------------------------------------------------------------------------;
; Input:
;	AL = FDC_CCB control byte 1 (see below)
;	DI = OFFSET FD_LAST_OP
;	DS = BDA
; Output:
;	CF if error
;
; 84218421
; 7       |			- FCCX	unused
;  6      |			- FCEIS	Enable Implied Seeking (1=enable)
;   5     |			- FCEFF	Enable FIFO (1=enable)
;    4    |			- FCPL	POLL
;     3210|			- FCTH	FIFO Threshhold (power on default 0)
;----------------------------------------------------------------------------;
;FDC_CCB RECORD	FCCX:1, FCEIS:1, FCEFF:1, FCPL:1, FCTH:4
;----------------------------------------------------------------------------;
FDC_CONFIGURE PROC
	;FD_DEBUG	'CONFIGURE'
	PUSH	AX
	PUSH	BX
	MOV	BL, AL
	MOV	AL, FDC_CMD_CONFIG
	CALL	FDC_SEND 				; [0] FDC configure command
	JC	FDC_CONFIGURE_RET
	;MOV	AL, FDC_CB < ,0 >			; control byte 0 (always 0)
	MOV	AL, FDC_CCB0 <>			; control byte 0 (always 0)
	CALL	FDC_SEND 				; [1] control byte 0
	JC	FDC_CONFIGURE_RET
	MOV	AL, BL
	;FD_DEBUG					; 0874
	CALL	FDC_SEND				; [2] configure register
	JC	FDC_CONFIGURE_RET
	MOV	AL, FDC_CCB2 < 0 >		; precomp starting track (0-255)
	CALL	FDC_SEND				; [3] precomp
FDC_CONFIGURE_RET:
	POP	BX
	POP	AX
FDC_SEND_RECV_ALL_RET:
	RET
FDC_CONFIGURE ENDP

;----------------------------------------------------------------------------;
; Send UNLOCK command
;----------------------------------------------------------------------------;
;FDC_CONF_UNLOCK PROC
;	MOV	AL, FDC_CMD_UNLOCK
;	JMP	SHORT FDC_SEND_RECV_ALL

;----------------------------------------------------------------------------;
; Send FDC Configuration Control and lock
;----------------------------------------------------------------------------;
; Input:
;	AL = FDC_CCR control byte 1
;	DI = OFFSET FD_LAST_OP
;	DS = BDA
;----------------------------------------------------------------------------;
FDC_CONFIGURE_LOCK PROC
	CALL	FDC_CONFIGURE

;----------------------------------------------------------------------------;
; Send LOCK command
;----------------------------------------------------------------------------;
FDC_CONF_LOCK PROC
	;FD_DEBUG	'LOCK'
	MOV	AL, FDC_CMD_LOCK
							; fall through to FDC_SEND_RECV_ALL
FDC_CONF_LOCK ENDP
FDC_CONFIGURE_LOCK ENDP

;----------------------------------------------------------------------------;
; Send command and receive results from operations that do not issue interrupts
;----------------------------------------------------------------------------;
; Input:
;	AL = command byte
;	DI = FD_LAST_OP
;	DS = BDA
; Output:
;	AL = result
;	AH = status
;	CF if error
;----------------------------------------------------------------------------;
FDC_SEND_RECV_ALL PROC
	CALL	FDC_SEND 				; send command in AL, CF if error
	JC	FDC_SEND_RECV_ALL_RET		; exit if send error
	;CALL	FDC_RECV_ALL			; receive result (not interrupt)
	JMP	FDC_RECV_ALL			; receive result (not interrupt)
	;FD_DEBUG	'FDC_SEND_RECV_ALL'
;FDC_SEND_RECV_ALL_RET:
;	RET
FDC_SEND_RECV_ALL ENDP

;----------------------------------------------------------------------------;
; Test if chip is NSC
;----------------------------------------------------------------------------;
; Output:
;	NZ if NSC
;	ZF otherwise
;	CF if timeout/error
;
; Clobbers: AX
;
; DP8473	90H	10010000		; 0 = CPU to FDC
; PC8477	90H	10010000
; 82072	D0H	11010000		; 1 = FDC to CPU
; 82077AA+	D0H	11010000
;
; Note: FDC may require reset afterwards
;----------------------------------------------------------------------------;
;PUBLIC FDC_TEST_NSC
;FDC_TEST_NSC PROC
;	MOV	AL, FDC_CMD_MODE

;----------------------------------------------------------------------------;
; Test if command is valid
;----------------------------------------------------------------------------;
; Input:
;	AL = command
; Output:
;	NZ if NSC
;	ZF otherwise
;	CF if timeout/error
;
; Clobbers: AX, CX, DX
;
; Controller may require reset if command has additional command bytes
;----------------------------------------------------------------------------;
FDC_TEST_CMD PROC
	CALL	FDC_SEND				; send command to test
	JC	FDC_TEST_CMD_DONE
	XOR	CX, CX				; timeout for FDC
	MOV	DX, FDC_STAT			; DX = 03F4H
FDC_TEST_CMD_LOOP:
	IN	AL, DX
	TEST	AL, MASK FDRR			; wait for DRR to read status
	LOOPZ	FDC_TEST_CMD_LOOP
	STC						; presume error
	JZ	FDC_TEST_CMD_DONE			; timeout error
	AND	AL, MASK FIOD			; ZF if valid, NZ if not
	XOR	AL, MASK FIOD			; NZ if valid, ZF if not, CF=0
	JNZ	FDC_TEST_CMD_DONE			; exit with command possibly incomplete
	LAHF						; save result flags
	XCHG	AX, CX				; save AL/flags
	CALL	FDC_RECV_ALL			; read and clear result phase
	XCHG	AX, CX				; restore AL/flags
	SAHF						; restore result flags
FDC_TEST_CMD_DONE:
	RET
FDC_TEST_CMD ENDP
;FDC_TEST_NSC ENDP

;----------------------------------------------------------------------------;
; Send MODE command with default values
;----------------------------------------------------------------------------;
FDC_NSC_MODE PROC
	MOV	AL, FDC_CMD_MODE
	CALL	FDC_SEND
	;FD_DEBUG 'NSC_MODE'
	JC	FDC_SEND_RECV_ALL_RET
	MOV	AL, FDC_NM_CB1 <>
	CALL	FDC_SEND
	MOV	AL, FDC_NM_CB2 <>
	CALL	FDC_SEND
	MOV	AL, FDC_NM_CB3 <>
	CALL	FDC_SEND
	MOV	AL, FDC_NM_CB4 <>
	JMP	FDC_SEND
	;JMP	SHORT FDC_SEND_RECV_ALL
FDC_NSC_MODE ENDP

;----------------------------------------------------------------------------;
; Send DUMPREG command
;----------------------------------------------------------------------------;
; Input:
;	DI = OFFSET FD_LAST_OP
;	DS = BDA
;----------------------------------------------------------------------------;
FDC_DUMPREG_DEBUG	EQU	1
FDC_DUMPREG PROC
	;FD_DEBUG 'DUMPREG'
	PUSH	AX
	PUSH	DX
	MOV	AL, FDC_CMD_DUMPREG		; [0] FDC dump regs command
	CALL	FDC_SEND 				; send command in AL, CF if error
	JC	FDC_DUMPREG_RET

;----------------------------------------------------------------------------;
; Get first 7 bytes
;
	CALL	FDC_RECV_ALL
			IF FDC_DUMPREG_DEBUG EQ 1
	;FD_DEBUG 'DUMPREG'
			ENDIF
	CMP	AL, 80H				; command error (DUMPREG not supported)
	STC						; CF if not supported
	JE	FDC_DUMPREG_RET

;----------------------------------------------------------------------------;
; Get remaining 3 bytes - Must clear FIFO
;
	CALL	FDC_RECV_ALL
			IF FDC_DUMPREG_DEBUG EQ 1
	;FD_DEBUG 'DUMPREG2'
			ENDIF

FDC_DUMPREG_RET:
	POP	DX
	POP	AX
FDC_DUMPREG_EXIT:
	RET
FDC_DUMPREG ENDP

;----------------------------------------------------------------------------;
; FD_CMOS_DRIVE_TBL: Get the drive table from "CMOS" for drive number
;----------------------------------------------------------------------------;
; Input:
; 	DL = drive index (0 - FDC_MAX_DRIVES-1)
; Output:
;	AL = CMOS type
;	CS:BX = pointer to CMOS drive table entry, on success
;	CF if drive (or CMOS type) not valid
;----------------------------------------------------------------------------;
FD_CMOS_DRIVE_TBL PROC
	CALL	FD_GET_CMOS				; AL = CMOS type of drive in DL
	JC	FD_CMOS_TBL_EXIT			; CF if error

;----------------------------------------------------------------------------;
; FD_CMOS_TBL: Get the drive table for CMOS drive type
;----------------------------------------------------------------------------;
; Input:
;	AL = CMOS type (bounds not checked)
; Output:
;	CS:BX = pointer to CMOS drive table entry
;----------------------------------------------------------------------------;
FD_CMOS_TBL PROC
	MOV	BX, AX				; preserve AX
	CBW						; zero extend AL
			IF CPU_TYPE EQ CPU_V20 OR CPU_TYPE EQ CPU_186
	SHL	AX, 4					; shift FD_TBL to 16 byte record size
			ELSE
		REPT 4
	SHL	AX, 1					; shift FD_TBL to 16 byte record size
		ENDM
			ENDIF
	;ADD	AX, OFFSET FD_TBL[-SIZE FD_TBL_S] ; add offset, 1 based
	ADD	AX, OFFSET FD_TBL_1		; add offset, 1 based
	XCHG	AX, BX				; return in BX
FD_CMOS_TBL_EXIT:
	RET

FD_CMOS_TBL ENDP
FD_CMOS_DRIVE_TBL ENDP

;----------------------------------------------------------------------------;
; DBT Table for CMOS types
; https://www.retrotechnology.com/herbs_stuff/drive.html
; https://www.ardent-tool.com/floppy/Floppy_Programming.html
; Intel_82077SL_AP358, PC8477B datasheets
;----------------------------------------------------------------------------;
; Offset		Type
; [0]			Default unestablished media state
; [1]			Media sectors
; [2]			Media tracks
; [3-13]		Media DBT
; [14]		Media last track (.TRKS)
; [15 bits 7-6]	Media data rate (.RATE)
; [15 bits 5-0]	Drive default FDC_MODE (drive capabilities)
;----------------------------------------------------------------------------;
FD_TBL LABEL BYTE

;----------------------------------------------------------------------------;
; [1] 360K disk/drive
; 250Kb, 40 cyl, 9 sec, SRT: 6ms, HUT: 240ms, SGAP: 42, FGAP: 80 (default)
;
FT_360	DB	FMS360E					; 93H
		DB	9, 39						; 40 cyl, 9 sec
DBT_360	DBT	<SRT_360,,,,,,,,,,,,FSR250 OR FDM_360>

;----------------------------------------------------------------------------;
; [2] 1.2M disk/drive
; 500Kb, 80 cyl, 15 sec, SRT: 3ms, HUT: 120ms, SGAP: 27, FGAP: 84
; 500Kb, 80 cyl, 15 sec, SRT: 3ms, HUT: 120ms, SGAP: 42, FGAP: 80 (Intel)
;
FT_12		DB	FMS12						; 02H
		DB	15, 79					; 80 cyl, 15 sec
DBT_12	DBT	<,,,,15,27,,84,,,,79,FSR500 OR FDM_12>

;----------------------------------------------------------------------------;
; [3] 720K disk/drive
; 250Kb, 80 cyl, 9 sec, SRT: 6ms, HUT: 240ms, SGAP: 42, FGAP: 80
;
FT_720	DB	FMS720E					; 97H
		DB	9, 79						; 80 cyl, 9 sec
DBT_720	DBT	<,,,,,,,,,,,79,FSR250 OR FDM_720>	;

;----------------------------------------------------------------------------;
; [4] 1.44M disk/drive
; 500Kb, 80 cyl, 18 sec, SRT: 5ms, HUT: 240ms, SGAP: 27, FGAP: 108
;
FT_144	DB	FMS144					; 07H
		DB	18, 79					; 80 cyl, 18 sec
DBT_14	DBT	<SRT_144,,,,18,27,,108,,,,79,FSR500 OR FDM_14>

;----------------------------------------------------------------------------;
; [5] 2.88M disk/drive
; 1Mb, 80 cyl, 36 sec, SRT: 3ms, HUT: 120ms, SGAP: 27, FGAP: 83
;
FT_288	DB	FMS288					; C7H
		DB	36, 79					; 80 cyl, 36 sec
DBT_28	DBT	<SRT_288,,,,36,27,,83,,,,79,FSR1000 OR FDM_28>
									
;----------------------------------------------------------------------------;
; [6] 360K disk in 1.2M drive
; 300Kb, 40 cyl, 9 sec, SRT: 5ms, HUT: 200ms, SGAP: 42, FGAP: 80
; 300Kb, 40 cyl, 9 sec, SRT: 5ms, HUT: 200ms, SGAP: 35, FGAP: 80 (alt)
;
FT_360_12	DB	FMS360_12E					; 74H
		DB	9, 39						; 40 cyl, 9 sec
DBT_360_12	DBT	<,,,,,42,,,,,,,FSR300>

FD_TBL_SZ	EQU	($-FD_TBL) / SIZE FD_TBL_S		; number of FD_TBL types

;----------------------------------------------------------------------------;
; DBT Table for CMOS types - adjusted for 1-based index
;
FD_TBL_1	EQU	FD_TBL[-SIZE FD_TBL_S]

		ENDIF		; IF FDC_HD_ENABLE EQ 1

OPTROM	ENDS
		END
