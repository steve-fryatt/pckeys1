; Copyright 1996-2013, Stephen Fryatt (info@stevefryatt.org.uk)
;
; This file is part of PCKeys:
;
;   http://www.stevefryatt.org.uk/software/
;
; Licensed under the EUPL, Version 1.2 only (the "Licence");
; You may not use this work except in compliance with the
; Licence.
;
; You may obtain a copy of the Licence at:
;
;   http://joinup.ec.europa.eu/software/page/eupl
;
; Unless required by applicable law or agreed to in
; writing, software distributed under the Licence is
; distributed on an "AS IS" basis, WITHOUT WARRANTIES
; OR CONDITIONS OF ANY KIND, either express or implied.
;
; See the Licence for the specific language governing
; permissions and limitations under the Licence.

; PCKeys.s
;
; PCKeys Module Source
;
; REM 26/32 bit neutral

;version$="1.10"
;save_as$="PCKeys"

	GET	$Include/SWINames

; ---------------------------------------------------------------------------------------------------------------------
; Set up the Module Workspace

			^	0
WS_OnOffFlag		#	4
WS_LastKey		#	4

WS_Size			*	@

; ======================================================================================================================
; Module Header

	AREA	Module,CODE,READONLY
	ENTRY

ModuleHeader
	DCD	0
	DCD	InitCode
	DCD	FinalCode
	DCD	0
	DCD	TitleString
	DCD	HelpString
	DCD	CommandTable
	DCD	0
	DCD	0
	DCD	0
	DCD	0
	DCD	0				; MessageTrans file
	DCD	ModuleFlags			; Offset to module flags

; ======================================================================================================================

ModuleFlags
	DCD	1				; 32-bit compatible

; ==================================================================================================

InitCode
	STMFD	R13!,{R0-R2,R14}

; Claim 8 bytes of workspace to store the current states in

	MOV	R0,#6
	MOV	R3,#WS_Size
	SWI	XOS_Module
	BVS	InitExit
	STR	R2,[R12]

; Store the default settings in memory.
; Bit 0 - PCKeys setting (On)
; Bit 1 - Desktop State  (On)

	MOV	R0,#2_11
	STR	R0,[R2,#WS_OnOffFlag]

; Claim InsV to trap keypresses.  Pass workspace pointer in R12 (already in R2).

	MOV	R0,#&14 ; InsV
	ADR	R1,InsV
	SWI	XOS_Claim
	BVS	InitExit

; Claim EventV to trap keydown.  Pass workspace pointer in R12 (already in R2).

	MOV	R0,#&10				; EventV
	ADR	R1,EventV
	SWI	XOS_Claim
	BVS	InitExit

; Install code to check desktop state every second

	MOV	R0,#100
	ADR	R1,CheckDesktopState
	SWI	XOS_CallEvery

; Switch on Keypress events.

	MOV	R0,#14
	MOV	R1,#11
	SWI	XOS_Byte

InitExit
	LDMFD	R13!,{R0-R2,PC}

; ==================================================================================================

FinalCode
	STMFD	R13!,{R0-R2,R14}
	LDR	R12,[R12]

; Release claim to InsV.

	MOV	R0,#&14				; InsV
	ADR	R1,InsV
	MOV	R2,R12
	SWI	XOS_Release

; Release claim to EventV.

	MOV	R0,#&10				; EventV
	ADR	R1,EventV
	MOV	R2,R12
	SWI	XOS_Release

; Remove desktop check code.

	ADR	R0,CheckDesktopState
	MOV	R1,R2
	SWI	XOS_RemoveTickerEvent

; Turn off keypress events.

	MOV	R0,#13
	MOV	R1,#11
	SWI	XOS_Byte

; Release the workspace.

	TEQ	R12,#0
	BEQ	FinalExit
	MOV	R0,#7
	MOV	R2,R12
	SWI	XOS_Module

FinalExit
	LDMFD	R13!,{R0-R2,PC}

; ==================================================================================================

CheckDesktopState
	STMFD	R13!,{R0-R12,R14}

	MOV	R0,#3				; Check the current state of the
	SWI	Wimp_ReadSysInfo		; Desktop and set the status flag
	LDR	R1,[R12,#WS_OnOffFlag]		; appropriately.
	BIC	R1,R1,#2_10
	ORR	R1,R1,R0,LSL #1
	STR	R1,[R12,#WS_OnOffFlag]

	LDMFD	R13!,{R0-R12,PC}

; ==================================================================================================

EventV

; Check if the key down event ocurred and, if so, store the code away for future use.

	TEQ	R0,#11
	TEQEQ	R1,#1
	STREQ	R2,[R12,#WS_LastKey]

	MOV	PC,R14

; ==================================================================================================

InsV

; Check that the buffer is the keyboard buffer.  If not, exit

	TEQ	R1,#0
	MOVNE	PC,R14

	STMFD	R13!,{R2,R14}

; Check that PC Keyboard Emulation is on and that we are in the Desktop.

	LDR	R2,[R12,#WS_OnOffFlag]
	TEQ	R2,#2_11
	BNE	InsVExit

; Do the keypress substitution.  See page 1-892 in the PRMs for the codes...

	TEQ	R0,#127				; Delete...
	MOVEQ	R0,#&8B				; ...to Copy (delete forwards)
	BEQ	InsVExit

	TEQ	R0,#30				; Home...
	MOVEQ	R0,#&AC				; ...to Ctrl-Left (start of line)
	BEQ	InsVExit

	TEQ	R0,#&8B				; Copy...
	MOVEQ	R0,#&AD				; ...to Ctrl-Right (end of line)
	BEQ	InsVExit

	TEQ	R0,#8				; Backspace...
	BNE	InsVExit			; ...if not, end, otherwise...

	LDR	R2,[R12,#WS_LastKey]		; ...what was the last key pressed...
	TEQ	R2,#&1E				; ...if it was Backspace, not Ctrl-H, change it...
	MOVEQ	R0,#127				; ...to Delete (to work with terminal emulators etc.)

InsVExit
	LDMFD	R13!,{R2,PC}

; ==================================================================================================

TitleString
	DCB	"PCKeys",0
	ALIGN


HelpString
	DCB	"PC Keyboard",9,$BuildVersion," (",$BuildDate,") ",169," Stephen Fryatt, 1996-",$BuildDate:RIGHT:4,0
	ALIGN

; ==================================================================================================

CommandTable
	DCB	"PCKeys"			; The PCKeys Command
	DCB	0				;  It takes one optional parameter
	ALIGN					;  which is either ON or OFF
	DCD	CommandPCKeys			;  to turn emulation on or off.
	DCD	&00010000			;  with no parameter, it shows
	DCD	CommandPCKeysMsgSyntax		;  the current state.
	DCD	CommandPCKeysMsgHelp

	DCD	0

; ==================================================================================================

CommandPCKeys
	STMFD	R13!,{R0-R2,R14}
	LDR	R12,[R12]

	CMP	R1,#0				; Is there a parameter
	BGT	PCKeysOneParam

PCKeysNoParam
	SWI	OS_WriteS			; Display first part of message
	DCB	"PC Keyboard emulation is ",0
	ALIGN

	LDR	R0,[R12,#WS_OnOffFlag]		; Load ON/OFF flag and display
	AND	R0,R0,#2_01			; remainder of message.
	CMP	R0,#1
	ADREQ	R0,TextOn
	ADRNE	R0,TextOff
	SWI	OS_Write0
	SWI	OS_NewLine

	B	PCKeysExit

PCKeysOneParam
	ADR	R1,TextOn			; Switch user flag on
	BL	Compare
	LDREQ	R2,[R12,#WS_OnOffFlag]
	ORREQ	R2,R2,#2_01
	STREQ	R2,[R12,#WS_OnOffFlag]
	BEQ	PCKeysExit

	ADR	R1,TextOff			; Switch user flag off
	BL	Compare
	LDREQ	R2,[R12,#WS_OnOffFlag]
	BICEQ	R2,R2,#2_01
	STREQ	R2,[R12,#WS_OnOffFlag]
	BEQ	PCKeysExit

PCKeysSyntaxError
	ADR	R0,CommandPCKeysMsgSyntax	; It was not a valid argument
	SWI	OS_Write0
	SWI	OS_NewLine

PCKeysExit
	LDMFD	R13!,{R0-R2,PC}

; --------------------------------------------------------------------------------------------------

TextOn
	DCB	"ON",0

TextOff
	DCB	"OFF",0
	ALIGN

CommandPCKeysMsgHelp
	DCB	"*PCKeys switches PC keyboard emulation on and off, "
	DCB	"or returns the current state."
	DCB	13
	DCB	10
CommandPCKeysMsgSyntax
	DCB	"Syntax: *PCKeys [ON|OFF]"
	DCB	0
	ALIGN

; ==================================================================================================

Compare
	STMFD	R13!,{R0-R3,R14}		; Compare two strings pointed to by
						; R0 and R1 (R0 is case insensitive,
CompareLoop					; R1 is upper case).
	LDRB	R2,[R0],#1
	LDRB	R3,[R1],#1			; Load two chars and turn one from
	CMP	R2,#"a"				; R0 to upper case
	BLT	CompareUpperCase
	CMP	R2,#"z"
	BGT	CompareUpperCase
	SUB	R2,R2,#32

CompareUpperCase
	CMP	R2,#32				; If First string has terminated, check
	BLE	CompareZero			; that second has too
	CMP	R2,R3				; Otherwise, check that first = second
	BNE	CompareExit

CompareZero
	CMP	R3,#0				; Check that second has terminated.
	BNE	CompareLoop

CompareExit
	LDMFD	R13!,{R0-R3,PC}			; Return with result in Z flag (EQ/NE)

	END

