title Multitasking Operating System Simulator
; Program 3
; Group 10
; Paul MacLean, Mark Blatnik, Tyler Harclerode
; March 1, 2018

INCLUDE Irvine32.inc

.data

numholder	DWORD 0
decten		BYTE 10
quitflag	BYTE 0
echoflag	BYTE 0

;========Node Data========;
MaxNodes			EQU 8
MaxNodeCNX			EQU 4
NodeConstantAlloc	EQU 14

NodeHeap			BYTE MaxNodes * MaxNodeCNX * NodeConstantAlloc		;This may be right ayyyyyy


;========Node Offsets========;
;j_length	EQU 14		;Jobs are 14 bytes ea.
;j_name		EQU 0		;Job name (8 bytes alloc)
;j_pri		EQU 8		;Job priority (1 byte alloc)
;j_state		EQU 9		;Job state (1 byte alloc)
;j_loadtime	EQU 10		;Job load-in time (2 bytes alloc)
;j_runtime	EQU 12		;Job run time (1 byte alloc)
;j_timerem	EQU 13		;Job time remaining (1 byte alloc)

;j_avail			EQU -1
;j_hold			EQU 0
;j_run			EQU 1


j_statecheck	BYTE -1
spacechar	BYTE 20h,0					;Space character
tabchar		BYTE 9h,0					;Tab character
newlinechar BYTE 0ah,0

;========Misc. Strings========;
defaultjobname		BYTE "        "		;Not null-terminated intentionally
emptybuffer			BYTE 8 dup(0)
printspaces			BYTE "	",0			;blah

;========Output messages========;
example				BYTE "help!",0

;========Error messages========;



.code


;===========Procedure Descriptions===========;



main PROC
	CALL	InitializeNodes

	Engine:
		CALL	TransmitMessages
		CALL	UpdateTime
		CALL	RecieveMessages

		CMP		quitflag,0						;check quit flag
		JE		Engine

	exit
main ENDP


InitializeNodes PROC
	ret
InitializeNodes ENDP


UpdateTime PROC
	ret
UpdateTime ENDP

TransmitMessages PROC
	ret
TransmitMessages ENDP

RecieveMessages PROC
	ret
RecieveMessages ENDP



END main
