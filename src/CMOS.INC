
;----------------------------------------------------------------------------;
; AT CMOS index registers
;----------------------------------------------------------------------------;
; https://web.archive.org/web/20111209041013/http://www-ivs.cs.uni-magdeburg.de/~zbrog/asm/cmos.html
; https://web.archive.org/web/20160314084340/https://www.bioscentral.com/misc/cmosmap.htm
;----------------------------------------------------------------------------;
AT_CMOS STRUC
CM_SEC	DB	?		; 00H RTC seconds
CM_SEC_AL	DB	?		; 01H RTC seconds alarm
CM_MIN	DB	?		; 02H RTC minutes
CM_MIN_AL	DB	?		; 03H RTC minutes alarm
CM_HOUR	DB	?		; 04H RTC hours
CM_HOUR_AL	DB	?		; 05H RTC hours alarm
CM_WEEKDAY	DB	?		; 06H RTC day of week
CM_DAY	DB	?		; 07H RTC day of month
CM_MONTH	DB	?		; 08H RTC month
CM_YEAR	DB	?		; 09H RTC year
CM_RTC_A	DB	?		; 0AH RTC Status Register A
CM_RTC_B	DB	?		; 0BH RTC Status Register B
CM_RTC_C	DB	?		; 0CH RTC Status register C (read only)
CM_RTC_D	DB	?		; 0DH RTC Status register D (read only)
CM_DIAG	DB	?		; 0EH Diagnostic status byte
CM_SD_ST	DB	?		; 0FH CMOS Shutdown Status
CM_FD		DB	?		; 10H Floppy Disk Drive Types (drives 0-1)
CM_SYS_CFG	DB	?		; 11H System Configuration Settings
CM_HD		DB	?		; 12H Hard Disk Types
CM_TYP	DB	?		; 13H Typematic
CM_EQ		DB	?		; 14H Installed Equipment
CM_MEM	DW	?		; 15-16H Base Memory Installed
CM_MEM_EXT	DW	?		; 17-18H Extended Memory Installd
CM_HD0	DB	?		; 19H Hard Disk 0 Extended Type
CM_HD1	DB	?		; 1AH Hard Disk 0 Extended Type
CM_HD0_CYL	DW	?		; 1BH User Defined Disk 0 - Cylinders
CM_HD0_HD	DB	?		; 1DH User Defined Disk 0 - Heads
CM_HD0_WPC	DW	?		; 1EH User Defined Disk 0 - Write precomp cyl
CM_HD0_CB	DB	?		; 20H User Defined Disk 0 - Control byte
CM_HD0_LZ	DW	?		; 21H User Defined Disk 0 - Landing Zone
CM_HD0_SEC	DB	?		; 23H User Defined Disk 0 - Sectors/track
CM_HD1_CYL	DW	?		; 24H User Defined Disk 1 - Cylinders
CM_HD1_HD	DB	?		; 26H User Defined Disk 1 - Heads
CM_HD1_WPC	DW	?		; 27H User Defined Disk 1 - Write precomp cyl
CM_HD1_CB	DB	?		; 29H User Defined Disk 1 - Control byte
CM_HD1_LZ	DW	?		; 2AH User Defined Disk 1 - Landing Zone
CM_HD1_SEC	DB	?		; 2CH User Defined Disk 1 - Sectors/track
CM_SYS_FL	DB	?		; 2DH System Operational Flags
CM_CHKSUM	DW	?		; 2EH CMOS Checksum (10H-2DH)
CM_MEM_EXT2	DW	?		; 30H Actual Extended Memory
CM_CENT	DB	?		; 32H Century (BCD)
AT_CMOS ENDS

;----------------------------------------------------------------------------;
; RTC Status Register A (0AH)
;----------------------------------------------------------------------------;
; Defaults:
;  0	 		- UIP:   Update in progress
;   010		- ASDIV: stage divider (010 = 32.768kHz)
;      0110		- ARSB:  Rate selection Bits (0110 = 1.024kHz)
;----------------------------------------------------------------------------;
CM_REG_A	RECORD	UIP:1, ASDIV:3=010b, ARSB:4=0110b

;----------------------------------------------------------------------------;
; CD_DIAG 0EH Diagnostic status byte
;----------------------------------------------------------------------------;
; 84218421
; 7       |		- CD_RTC_OK	RTC power status (0=not lost power, 1=has lost power)
;  6      |		- CD_CHK_OK	CMOS checksum status (0=good, 1=invalid)
;   5     |		- CD_PC_OK	POST config okay (0=valid, 1=invalid)
;    4    |		- CD_MSZ_OK	Memory size (0=matches config, 1=does not match)
;     3   |		- CD_FDC_OK	Fixed disk init (0=good, 1=error)
;      2  |		- CD_TM_OK	RTC Time status (0=time valid, 1=time invalid)
;       10|		- CD_RES1	reserved
;----------------------------------------------------------------------------;
AT_CMOS_DIAG RECORD	CD_RTC_OK:1,CD_CHK_OK:1,CD_PC_OK:1,CD_MSZ_OK:1,CD_FDC_OK:1,CD_TM_OK:1,CD_RES1:2