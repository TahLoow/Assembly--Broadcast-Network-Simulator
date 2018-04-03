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

;========Node Values========;
n_constantbytes	EQU 14
n_name		EQU 0
n_numcnx	EQU 1
n_queueptr	EQU 2
n_queueinp	EQU 6
n_queueout	EQU 10

c_cnx_loc	EQU 0
c_cnx_rcv	EQU 4
c_cnx_xmt	EQU 8


;========Node Data========;
NumNodes			BYTE 0
MaxNodes			EQU 8
MaxNodeCNX			EQU 4							;Max Connections per node
NodeConstantAlloc	EQU 14

NodeBuffer			DWORD MaxNodes					;List of node pointers
NodeHeap			BYTE MaxNodes * (n_constantbytes + MaxNodeCNX * NodeConstantAlloc) dup(0)


;========Buffer Values========;
inputmax	EQU 100
inputbuffer	BYTE inputmax+1 dup(0)

;========Random Values========;
spacechar	BYTE 20h,0					;Space character
tabchar		BYTE 9h,0					;Tab character
newlinechar 	BYTE 0ah,0

;========Misc. Strings========;
defaultjobname		BYTE "        "		;Not null-terminated intentionally
emptybuffer			BYTE 8 dup(0)
printspaces			BYTE "	",0			;blah

;========Output messages========;
prompt_loadnodemenu1			BYTE "	1: Load from file",0
prompt_loadnodemenu2			BYTE "	2: Load from keyboard",0
prompt_loadnodemenu3			BYTE "	3: Load from default",0
prompt_loadnodemenu4			BYTE "Please make a selection (1-3):",0
prompt_filepath					BYTE "Please enter a file path: ",0


filename	BYTE "C:\Users\macle\Desktop\TEST.txt"

;========Error messages========;
error_filenotfound				BYTE "File name not found"


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


ClearInputBuffer PROC
	PUSH	ecx
	MOV		edi,0
	MOV		edx,OFFSET inputbuffer

	next:
		MOV		BYTE PTR [edx+edi],0
		INC		edi
		CMP		edi,inputmax
		JLE		next

	POP		ecx
	ret
ClearInputBuffer ENDP

GetNodesFromFile PROC
	prompt:
		MOV		edx,OFFSET prompt_filepath
		CALL	WriteString
		MOV		edx,OFFSET inputbuffer
		MOV		ecx,inputmax
		CALL	ReadString

		CALL	OpenInputFile

		CALL	ClearInputBuffer

		MOV		edx,OFFSET inputbuffer
		MOV		ecx,inputmax
		CALL	ReadFromFile
		JC		filenotfound
		JNC		filefound

	filefound:
		
		JMP		Done
	filenotfound:
		MOV		edx,OFFSET error_filenotfound
		CALL	WriteString
		CALL	Crlf
		JMP		prompt
	Done:
		ret
GetNodesFromFile ENDP

InitializeNodes PROC
	promptloadtype:
		MOV		edx,OFFSET prompt_loadnodemenu1
		CALL	WriteString
		CALL	Crlf
		MOV		edx,OFFSET prompt_loadnodemenu2
		CALL	WriteString
		CALL	Crlf
		MOV		edx,OFFSET prompt_loadnodemenu3
		CALL	WriteString
		CALL	Crlf
		MOV		edx,OFFSET prompt_loadnodemenu4
		CALL	WriteString
		CALL	Crlf

		MOV		edx,OFFSET inputbuffer
		MOV		ecx,inputmax
		CALL	ReadString

		CMP		BYTE PTR [edx],"1"
		JE		selection1
		CMP		BYTE PTR [edx],"2"
		JE		selection2
		CMP		BYTE PTR [edx],"3"
		JE		selection3
		JMP		promptloadtype

	selection1:
		CALL	GetNodesFromFile
		JMP		finalize

	selection2:
		JMP		finalize

	selection3:
		JMP		finalize


	finalize:
		
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
