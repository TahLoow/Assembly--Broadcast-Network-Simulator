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
NumNodes			BYTE 0
MaxNodes			EQU 8
MaxNodeCNX			EQU 4							;Max Connections per node
NodeConstantAlloc		EQU 14

NodeBuffer			DWORD MaxNodes						;
NodeHeap			BYTE MaxNodes * MaxNodeCNX * NodeConstantAlloc		;This may be right ayyyyyy


;========Node Offsets========;
n_constantbytes	EQU 14
n_name		EQU 0
n_numcnx	EQU 1
n_queueptr	EQU 2
n_queueinp	EQU 6
n_queueout	EQU 10

c_cnx_loc	EQU 0
c_cnx_rcv	EQU 4
c_cnx_xmt	EQU 8

;========Random Values========;
spacechar	BYTE 20h,0					;Space character
tabchar		BYTE 9h,0					;Tab character
newlinechar 	BYTE 0ah,0

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
