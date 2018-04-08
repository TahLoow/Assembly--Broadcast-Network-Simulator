title Network Simulator
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
NULL		EQU 0

fileHandle	DWORD 0

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
MaxNodeCNX			EQU 4										;Max Connections per node
NodeConstantAlloc	EQU 14

NodeNames			BYTE MaxNodes * MaxNodeCNX dup(0)			;List of all node names, plus MaxNodeCNX bytes for each node to store the connection names from given node.
NodeBuffer			DWORD MaxNodes								;List of node pointers
NodeHeap			BYTE MaxNodes * (n_constantbytes + MaxNodeCNX * NodeConstantAlloc) dup(0)


;========Buffer Values========;
inputmax	EQU 100
inputbuffer	BYTE inputmax+1 dup(0)
bufferindex	DWORD 0

;========Random Values========;
spacechar		BYTE 20h,0					;Space character
tabchar			BYTE 9h,0					;Tab character
CRchar			BYTE 0Dh					;carriage return
LFchar			BYTE 0Ah					;line feed
UpperMask		BYTE 0DFh					;Mask to make alphabetic characters uppercase


;========Misc. Strings========;
quitchar			BYTE "*"

;========Output messages========;
prompt_loadnodemenu1			BYTE "	1: Load from file",0
prompt_loadnodemenu2			BYTE "	2: Load from keyboard",0
prompt_loadnodemenu3			BYTE "	3: Load from default",0
prompt_loadnodemenu4			BYTE "Please make a selection (1-3): ",0
prompt_filepath					BYTE "Please enter a file path, or type ""*"" to exit to menu: ",0


filename	BYTE "C:\Users\macle\Desktop\TEST.txt"

;========Error messages========;
error_file_notfound					BYTE "File name not found",0
error_file_nodenameinvalid			BYTE "Invalid node name invalid",0
error_file_dualconnection			BYTE "Invalid format. Node cannot connect to itself",0
error_file_maxnodesdefined			BYTE "Too many nodes declared",0
.code


;===========Procedure Descriptions===========;
;SkipSpaces:
;	Description:		Skips whitespace characters in bufferindex from bufferindex onwards. 
;	Preconditions:		None
;	Postconditions:		bufferindex directs towards non-whitespace character. If character is null-terminator, sets carry



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

DeclareNode PROC
	PUSHA

	MOV		edx,OFFSET NodeNames
	MOV		ecx,SIZEOF NodeNames
	XOR		edi,edi

	node_checkdeclared:
		CMP		BYTE PTR [edi+edx],al
		JE		node_declared
		CMP		BYTE PTR [edi+edx],NULL		;we know that the node is undeclared if the edi'th record of NodeNames is empty.
		JE		node_undeclared

		ADD		edi,MaxNodeCNX						;edi is the counter for NodeNames records. Each record holds the node's name, and all connected node names. 
		
		MOV		cl,SIZEOF NodeNames
		CMP		edi,ebx
		JGE		Fail_CapHit
		JMP		node_checkdeclared

	node_undeclared:
		MOV		BYTE PTR [edi+edx],al
		JMP		Success
	node_declared:
		JMP		Success

	
	Fail_CapHit:
		STC
		JMP		Done
	Success:
		CLC
		JMP		Done
	Done:
		POPA
		ret
DeclareNode ENDP


DeclareNodePair PROC				;al and bl each hold a character that represents a node's name. "Declare" meaning they want a node of name X. This does NOT mean space is allocated for the node.
									;DeclareNodePair sorts given node pairs into NodeNames.
	PUSH	edi
	PUSH	ebx
	PUSH	edx

	MOV		cl,al					;cl holds node a as temp

	CALL	DeclareNode
	JC		Fail_CapHit

	MOV		al,cl
	CALL	DeclareNode
	JC		Fail_CapHit

	Success:
		CLC
		JMP		Done
	Fail_CapHit:
		MOV		edx,OFFSET error_file_maxnodesdefined
		CALL	WriteString
		CALL	Crlf
		STC
		JMP		Done
	Done:
		POP		edx
		POP		ebx
		POP		edi
		ret
DeclareNodePair ENDP

GetNodesFromFile PROC
	prompt:
		MOV		edx,OFFSET prompt_filepath
		CALL	WriteString
		MOV		edx,OFFSET inputbuffer
		MOV		ecx,inputmax
		CALL	ReadString

		MOV		al,BYTE PTR [inputbuffer]
		CMP		al,quitchar
		JE		checkemptybuffer
		JNE		processfile

	checkemptybuffer:
		MOV		bufferindex,1
		CALL	SkipSpaces
		MOV		bufferindex,0
		JC		BackToMenu
		JNC		processfile

	processfile:
		CALL	OpenInputFile								;eax holds file handle

		MOV		edx,OFFSET inputbuffer						;Buffer will be empty by this point
		MOV		ecx,inputmax
		CALL	ReadFromFile								;Load from file into buffer
		JC		filenotfound
		JNC		parsefile

	parsefile:
		CALL	CloseFile									;eax holds open file handle; data already read, so close it

		XOR		edi,edi										;Empty buffer counter

		getnextpair:
			XOR		eax,eax
			XOR		ebx,ebx
			XOR		ecx,ecx

			MOV		bufferindex,edi							;edi is the counter, but we load the counter into bufferinedex before checking next pairs

			CALL	SkipSpaces
			JC		endoffile

			MOV		edx,OFFSET inputbuffer
			getfirstnode:
				MOV		al,BYTE PTR [edx+edi]
				CALL	ToUpper
				MOV		bl,al								;cl stores first node letter.
				CALL	IsAlphaChar
				JNC		nodenameinvalid

			getsecondnode: 
				INC		edi

				MOV		al,BYTE PTR [edx+edi]
				CALL	ToUpper
				CMP		al,bl
				JE		nodeletterssame
				CALL	IsAlphaChar
				JNC		nodenameinvalid

				INC		edi									;bufferindex now points to the character after the pair of nodes

				CALL	DeclareNodePair
				JC		BackToMenu

				JMP		getnextpair

		endoffile:
			
			;look through NodeNames, make sure every node in the network is used

			JMP		Loadsuccessful
	nodenameinvalid:
		MOV		edx,OFFSET error_file_nodenameinvalid
		CALL	WriteString
		JMP		BackToMenu
	nodeletterssame:
		MOV		edx,OFFSET error_file_dualconnection
		CALL	WriteString
		JMP		BackToMenu
	filenotfound:
		MOV		edx,OFFSET error_file_notfound
		CALL	WriteString
		CALL	Crlf
		JMP		prompt
		
	BackToMenu:
		CALL	Crlf
		CALL	Crlf
		STC
		JMP		Done
	Loadsuccessful:
		CLC
		JMP		Done
	Done:
		ret
GetNodesFromFile ENDP

GetNodesFromKeyboard PROC
	
	Done:
		ret
GetNodesFromKeyboard ENDP

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
		JC		promptloadtype
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









SkipSpaces PROC								;skips spaces in inputbuffer
	PUSH	eax
	PUSH	ebx

	XOR		ebx,ebx
	MOV		ebx,bufferindex

	CheckSpace:
		MOV		al,BYTE PTR [inputbuffer+ebx]

		CMP		al,0
		JE		EndOfBuffer

		CALL	IsSpaceChar
		JNC		CharFound

		INC		bl
		JMP		CheckSpace

	EndOfBuffer:
		STC
		JMP		Done
	CharFound:
		CLC
		JMP		Done
	Done:
		MOV		bufferindex,ebx
		POP		ebx
		POP		eax
		ret
SkipSpaces ENDP

ClearBuffer PROC									;edx holds buffer, ecx holds sizeof buffer
	MOV		edi,0

	next:
		MOV		BYTE PTR [edx+edi],0
		INC		edi
		CMP		edi,inputmax
		JLE		next

	ret
ClearBuffer ENDP









ToUpper PROC
	CMP		al,"a"
	JL		Done
	CMP		al,"z"
	JG		Done
	AND		al,UpperMask

	Done:
		ret
ToUpper ENDP

IsAlphaChar PROC
	CMP		al,"0"
	JL		notalphanumeric
	CMP		al,"Z"
	JG		notalphanumeric
	STC
	JMP		Done

	notalphanumeric:
		CLC

	Done:
		ret
IsAlphaChar ENDP

IsSpaceChar PROC
	CMP		al,spacechar
	JE		IsSpace
	CMP		al,tabchar
	JE		IsSpace
	CMP		al,CRchar
	JE		IsSpace
	CMP		al,LFchar
	JE		IsSpace

	CLC
	JMP		Done

	IsSpace:
		STC
		JMP		Done

	Done:
		ret
IsSpaceChar ENDP









END main
