;----------------------------------------------------------------------------;
; GLaDISK (Gizmo Linkage and Dynamic Information Storage Keeper)
; Copyright (c) 2024, 640KB and contributors
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; INT 13H stack frame
;
_INT_13_DS	EQU	[BP][8]
_INT_13_DI	EQU	[BP][6]
_INT_13_DX	EQU	[BP][4]
_INT_13_DH	EQU	_INT_13_DX[1]
_INT_13_DL	EQU	_INT_13_DX[0]
_INT_13_CX	EQU	[BP][2]
_INT_13_CH	EQU	_INT_13_CX[1]
_INT_13_CL	EQU	_INT_13_CX[0]
_INT_13_BX	EQU	[BP][0]
_INT_13_BH	EQU	_INT_13_BX[1]
_INT_13_BL	EQU	_INT_13_BX[0]

;----------------------------------------------------------------------------;
; Addressing for BDA data in INT 13H functions. DI is set to FD_LAST_OP for
; memory operations for shorter instructions sizes.
;
_FD_LAST_OP		EQU	BYTE PTR [DI]				; FD_LAST_OP
_FD_MOTOR_ST	EQU	_FD_LAST_OP[FD_MOTOR_ST-FD_LAST_OP]	; FD_MOTOR_ST
_FD_MOTOR_CT	EQU	_FD_LAST_OP[FD_MOTOR_CT-FD_LAST_OP]	; FD_MOTOR_CT
_FD_CAL_ST		EQU	_FD_LAST_OP[FD_CAL_ST-FD_LAST_OP]	; FD_CAL_ST
_FD_TRACK		EQU	_FD_LAST_OP[FD_TRACK-FD_LAST_OP]	; FD_TRACK
_FD_MEDIA_ST	EQU	_FD_LAST_OP[FD_MEDIA_ST-FD_LAST_OP]	; FD_MEDIA_ST
_FD_LR		EQU	_FD_LAST_OP[FD_LR-FD_LAST_OP]		; FD_LR
_FD_MODE		EQU	_FD_LAST_OP[FD_MODE-FD_LAST_OP]	; FD_MODE
_FD2_MODE		EQU	_FD_LAST_OP[FD2_MODE-FD_LAST_OP]	; FD2_MODE
_FDC_CAP		EQU	_FD_LAST_OP[FDC_CAP-FD_LAST_OP]	; FDC_CAP
_FD_TIMER		EQU	_FD_LAST_OP[TIMER-FD_LAST_OP]		; TIMER
_FDC_ST		EQU	_FD_LAST_OP[FDC_ST-FD_LAST_OP]	; FDC_ST
_FDC_LAST_ST	EQU	[DI][FDC_LAST_ST-FD_LAST_OP]		; FDC_LAST_ST
