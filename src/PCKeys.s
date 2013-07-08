REM >PCKeysSrc
REM
REM PC Keyboard Module
REM (c) Stephen Fryatt, 1996
REM
REM Needs ExtBasAsn to assemble.
REM 26/32 bit neutral

version$="1.10"
save_as$="PCKeys"

LIBRARY "<Reporter$Dir>.AsmLib"

PRINT "Assemble debug? (Y/N)"
REPEAT
 g%=GET
UNTIL (g% AND &DF)=ASC("Y") OR (g% AND &DF)=ASC("N")
debug%=((g% AND &DF)=ASC("Y"))

ON ERROR PRINT REPORT$+" at line "+STR$(ERL) : END

REM --------------------------------------------------------------------------------------------------------------------
REM Set up workspace

workspace_size%=0 : REM This is updated.

on_off_flag=FNworkspace(workspace_size%,4)
last_key=FNworkspace(workspace_size%,4)

REM --------------------------------------------------------------------------------------------------------------------

DIM time% 5, date% 256
?time%=3
SYS "OS_Word",14,time%
SYS "Territory_ConvertDateAndTime",-1,time%,date%,255,"(%dy %m3 %ce%yr)" TO ,date_end%
?date_end%=13

REM --------------------------------------------------------------------------------------------------------------------

code_space%=10000
DIM code code_space%

pass_flags%=%11100

IF debug% THEN PROCReportInit(200)

FORpass%=pass_flags% TO pass_flags% OR %10 STEP %10
L%=code+code_space%
O%=code
P%=0

IF debug% THEN PROCReportStart(pass%)
[OPT pass%
EXT 1
          EQUD      0
          EQUD      init
          EQUD      finish
          EQUD      0
          EQUD      title
          EQUD      help
          EQUD      table
          EQUD      0
          EQUD      0
          EQUD      0
          EQUD      0
          EQUD      0                   ; MessageTrans file
          EQUD      module_flags        ; Offset to module flags

; ======================================================================================================================

.module_flags
          EQUD      1                   ; 32-bit compatible

; ==================================================================================================

.init
          STMFD     R13!,{R0-R2,R14}

; Claim 8 bytes of workspace to store the current states in

          MOV       R0,#6
          MOV       R3,#workspace_size%
          SWI       "XOS_Module"
          BVS       init_exit
          STR       R2,[R12]

; Store the default settings in memory.
; Bit 0 - PCKeys setting (On)
; Bit 1 - Desktop State  (On)

          MOV       R0,#%11
          STR       R0,[R2,#on_off_flag]

; Claim InsV to trap keypresses.  Pass workspace pointer in R12 (already in R2).

          MOV       R0,#&14 ; InsV
          ADR       R1,InsV
          SWI       "XOS_Claim"
          BVS       init_exit

; Claim EventV to trap keydown.  Pass workspace pointer in R12 (already in R2).

          MOV       R0,#&10 ; EventV
          ADR       R1,EventV
          SWI       "XOS_Claim"
          BVS       init_exit

; Install code to check desktop state every second

          MOV       R0,#100
          ADR       R1,check_desktop_state
          SWI       "XOS_CallEvery"

; Switch on Keypress events.

          MOV       R0,#14
          MOV       R1,#11
          SWI       "XOS_Byte"

.init_exit
          LDMFD     R13!,{R0-R2,PC}

; ==================================================================================================

.finish
          STMFD     R13!,{R0-R2,R14}
          LDR       R12,[R12]

; Release claim to InsV.

          MOV       R0,#&14 ; InsV
          ADR       R1,InsV
          MOV       R2,R12
          SWI       "XOS_Release"

; Release claim to EventV.

          MOV       R0,#&10 ; EventV
          ADR       R1,EventV
          MOV       R2,R12
          SWI       "XOS_Release"

; Remove desktop check code.

          ADR       R0,check_desktop_state
          MOV       R1,R2
          SWI       "XOS_RemoveTickerEvent"

; Turn off keypress events.

          MOV       R0,#13
          MOV       R1,#11
          SWI       "XOS_Byte"

; Release the workspace.

          TEQ       R12,#0
          BEQ       final_exit
          MOV       R0,#7
          MOV       R2,R12
          SWI       "XOS_Module"

.final_exit
          LDMFD     R13!,{R0-R2,PC}

; ==================================================================================================

.check_desktop_state
          STMFD     R13!,{R0-R12,R14}

          MOV       R0,#3                         ; Check the current state of the
          SWI       "Wimp_ReadSysInfo"            ; Desktop and set the status flag
          LDR       R1,[R12,#on_off_flag]                ; appropriately.
          BIC       R1,R1,#%10
          ORR       R1,R1,R0,LSL #1
          STR       R1,[R12,#on_off_flag]

          LDMFD     R13!,{R0-R12,PC}

; ==================================================================================================

.EventV

; Check if the key down event ocurred and, if so, store the code away for future use.

          TEQ       R0,#11
          TEQEQ     R1,#1
          STREQ     R2,[R12,#last_key]

          MOV       PC,R14

; ==================================================================================================

.InsV

; Check that the buffer is the keyboard buffer.  If not, exit

          TEQ       R1,#0
          MOVNE     PC,R14

          STMFD     R13!,{R2,R14}

; Check that PC Keyboard Emulation is on and that we are in the Desktop.

          LDR       R2,[R12,#on_off_flag]
          TEQ       R2,#%11
          BNE       done

; Do the keypress substitution.  See page 1-892 in the PRMs for the codes...

          TEQ       R0,#127  ; Delete...
          MOVEQ     R0,#&8B  ; ...to Copy (delete forwards)
          BEQ       done

          TEQ       R0,#30   ; Home...
          MOVEQ     R0,#&AC  ; ...to Ctrl-Left (start of line)
          BEQ       done

          TEQ       R0,#&8B  ; Copy...
          MOVEQ     R0,#&AD  ; ...to Ctrl-Right (end of line)
          BEQ       done

          TEQ       R0,#8    ; Backspace...
          BNE       done     ; ...if not, end, otherwise...

          LDR       R2,[R12,#last_key] ; ...what was the last key pressed...
          TEQ       R2,#&1E  ; ...if it was Backspace, not Ctrl-H, change it...
          MOVEQ     R0,#127  ; ...to Delete (to work with terminal emulators etc.)

.done
          LDMFD     R13!,{R2,PC}

; ==================================================================================================

.title
          EQUZ      "PCKeys"
          ALIGN

.help
          EQUS      "PC Keyboard"
          EQUB      9
          EQUS      version$
          EQUS      " "
          EQUS      $date%
          EQUZ      " © Stephen Fryatt, 1996"
          ALIGN

; ==================================================================================================

.table
          EQUS      "PCKeys"                      ; The PCKeys Command
          EQUB      0                             ;  It takes one optional parameter
          ALIGN                                   ;  which is either ON or OFF
          EQUD      PCKeys_code                   ;  to turn emulation on or off.
          EQUD      &00010000                     ;  with no parameter, it shows
          EQUD      PCKeys_syntax                 ;  the current state.
          EQUD      PCKeys_help

          EQUD      0

; ==================================================================================================

.PCKeys_code
          STMFD     R13!,{R0-R2,R14}
          LDR       R12,[R12]

          CMP       R1,#0                         ; Is there a parameter
          BGT       PCKeys_one_param

.PCKeys_no_param
          SWI       "OS_WriteS"                   ; Display first part of message
          EQUS      "PC Keyboard emulation is "
          EQUB      0
          ALIGN

          LDR       R0,[R12,#on_off_flag]         ; Load ON/OFF flag and display
          AND       R0,R0,#%01                    ; remainder of message.
          CMP       R0,#1
          ADREQ     R0,on
          ADRNE     R0,off
          SWI       "OS_Write0"
          SWI       "OS_NewLine"

          B         PCKeys_code_exit

.PCKeys_one_param
          ADR       R1,on                         ; Switch user flag on
          BL        compare
          LDREQ     R2,[R12,#on_off_flag]
          ORREQ     R2,R2,#%01
          STREQ     R2,[R12,#on_off_flag]
          BEQ       PCKeys_code_exit

          ADR       R1,off                        ; Switch user flag off
          BL        compare
          LDREQ     R2,[R12,#on_off_flag]
          BICEQ     R2,R2,#%01
          STREQ     R2,[R12,#on_off_flag]
          BEQ       PCKeys_code_exit

.PCKeys_syntax_error
          ADR       R0,PCKeys_syntax              ; It was not a valid argument
          SWI       "OS_Write0"
          SWI       "OS_NewLine"

.PCKeys_code_exit
          LDMFD     R13!,{R0-R2,PC}

; --------------------------------------------------------------------------------------------------

.on
          EQUS      "ON"                          ; ON text
          EQUB      0
.off
          EQUS      "OFF"                         ; OFF text
          EQUB      0
          ALIGN

.PCKeys_help
          EQUS      "*PCKeys switches PC keyboard emulation on and off, "
          EQUS      "or returns the current state."
          EQUB      13
          EQUB      10
.PCKeys_syntax
          EQUS      "Syntax: *PCKeys [ON|OFF]"
          EQUB      0
          ALIGN

; ==================================================================================================

.compare
          STMFD     R13!,{R0-R3,R14}              ; Compare two strings pointed to by
                                                  ; R0 and R1 (R0 is case insensitive,
.compare_loop                                     ; R1 is upper case).
          LDRB      R2,[R0],#1
          LDRB      R3,[R1],#1                    ; Load two chars and turn one from
          CMP       R2,#ASC("a")                  ; R0 to upper case
          BLT       compare_upper_case
          CMP       R2,#ASC("z")
          BGT       compare_upper_case
          SUB       R2,R2,#32

.compare_upper_case
          CMP       R2,#32                        ; If First string has terminated, check
          BLE       compare_zero                  ; that second has too
          CMP       R2,R3                         ; Otherwise, check that first = second
          BNE       compare_exit

.compare_zero
          CMP       R3,#0                         ; Check that second has terminated.
          BNE       compare_loop

.compare_exit
          LDMFD     R13!,{R0-R3,PC}               ; Return with result in Z flag (EQ/NE)
]
IF debug% THEN
[OPT pass%
          FNReportGen
]
ENDIF
NEXT

SYS "OS_File",10,"<Basic$Dir>."+save_as$,&FFA,,code,O%
END



DEF FNworkspace(RETURN size%,dim%)
LOCAL ptr%
ptr%=size%
size%+=dim%
=ptr%
