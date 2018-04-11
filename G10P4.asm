title Network Simulator
; Program 4
; Group 10
; Paul MacLean, Mark Blatnik, Tyler Harclerode
; March 1, 2018

INCLUDE Irvine32.inc

.data

dwordsize	EQU 4
numholder	DWORD 0
decten		BYTE 10
quitflag	BYTE 0
echoflag	BYTE 0
NULL		EQU 0

fileHandle	DWORD 0

;========Node Values========;
n_fixedoffset	EQU 14
n_name			EQU 0
n_numcnx		EQU 1
n_queueptr		EQU 2
n_queuefront	EQU 6
n_queueback		EQU 10

c_cnx_offset	EQU 12
c_cnx_loc		EQU 0
c_cnx_rcv		EQU 4
c_cnx_xmt		EQU 8

;========Node Data========;
NumNodes			BYTE 0
MaxNodes			EQU 6
MaxNodeCNX			EQU 4										;Max Connections per node

packetsize			EQU 8

;========Buffers & Heaps========;
NodeNames			BYTE MaxNodes * (1 + MaxNodeCNX) dup(0)			;List of all node **names**, plus MaxNodeCNX bytes for each node to store the connections.

NodeBuffer			DWORD MaxNodes dup(0)						;List of pointers that point to beginning of each existing node in NodeHeap. For easier indexing through nodes
NodeBufferIndex		BYTE 0										;Index for NodeBuffer. ADD FOUR TO INCREMENT TO NEXT NODE. 

NodeHeap			BYTE MaxNodes * (n_fixedoffset + MaxNodeCNX * c_cnx_offset) dup("h")			;Byte allocation for maximum nodes & relevant data
NodePointer			DWORD 0										;Points to the beginning of a node in the NodeHeap.

maxqueuesize		EQU 80										;Max # of packets a node can hold at any given time.
QueueHeap			BYTE packetsize*maxqueuesize*MaxNodes dup(0)		;Byte allocation for max queues. Each node gets one queue, and points to one queue.

inputmax			EQU 100	
inputbuffer			BYTE inputmax+1 dup(0)							;Keyboard input buffer
inpbufferindex		DWORD 0											;Used to keep track of inputbuffer positions

;========Random Values========;
spacechar		BYTE 20h,0					;Space character
tabchar			BYTE 9h,0					;Tab character
CRchar			BYTE 0Dh					;carriage return
LFchar			BYTE 0Ah					;line feed
UpperMask		BYTE 0DFh					;Mask to make alphabetic characters uppercase
flag			BYTE 0						;boolean flag for certain operations, for when carry flag already is used

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
error_file_nodenameinvalid			BYTE "Invalid node name",0
error_file_dualconnection			BYTE "Invalid format. Node cannot connect to itself",0
error_file_maxnodesdefined			BYTE "Too many nodes declared",0
error_file_maxnodeconnections		BYTE "Too many node connections",0
error_file_cnxredundancy			BYTE "Connection definition redundancy",0
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


DeclareNode PROC										;returns edx holding record of a given node
	PUSH	eax
	PUSH	ebx
	PUSH	ecx
	PUSH	edi
	PUSH	esi

	MOV		flag,0
	MOV		edx,OFFSET NodeNames
	MOV		ecx,SIZEOF NodeNames
	XOR		esi,esi										;esi counts the ith record
	XOR		edi,edi										;edi counts the record offset from NodeNames

	node_checkdeclared:
		CMP		esi,MaxNodes							;if edi (record index) is greater than/equal to MaxNodes, the capacity is hit
		JGE		Fail_CapHit
		CMP		BYTE PTR [edi+edx],NULL					;if the edi'th record of NodeNames is empty, the node is undeclared
		JE		node_undeclared
		CMP		BYTE PTR [edi+edx],al					;if the edi'th record of NodeNames has the name of the node we are adding, it is already declared
		JE		node_declared

		INC		esi
		ADD		edi,MaxNodeCNX+1						;edi is the counter for NodeNames records. Each record holds the node's name, and all connected node names. 
		
		JMP		node_checkdeclared

	node_undeclared:
		ADD		edx,edi
		MOV		BYTE PTR [edx],al
		JMP		Success
	node_declared:
		ADD		edx,edi
		MOV		flag,1
		JMP		Success

	Fail_CapHit:
		STC
		JMP		Done
	Success:
		CLC
		JMP		Done
	Done:
		POP		esi
		POP		edi
		POP		ecx
		POP		ebx
		POP		eax
		ret
DeclareNode ENDP

DeclareNodePair PROC				;al and bl each hold a character that represents a node's name. "Declare" meaning they want a node of name X. This does NOT mean space is allocated for the node.
									;DeclareNodePair sorts given node pairs into NodeNames.
	PUSH	edi
	PUSH	ebx
	PUSH	edx

	MOV		cl,bl					;cl holds NodeB as temp
	MOV		bl,al
	MOV		al,cl					;switch al and  bl. al now holds NodeA name, bl now holds NodeB name

	CALL	DeclareNode				;declare node name in al (NodeA)
	JC		Fail_CapHit
	MOV		edi,edx					;edi holds start address of node declaration

	MOV		al,bl
	CALL	DeclareNode				;declare node name in al (NodeB)
	JC		Fail_CapHit
	
	MOV		al,cl					;al now once again holds NodeA
	MOV		ecx,edi					;ecx holds record of connections for node A, edx holds record of connections for node B


	;Find first available slot in declaration record to insert a connection
	MOV		edi,1							;counter through the record of connections. Start at 2nd slot.


	forA:									;looks through edx (record of NodeA)
		CMP		edi,MaxNodeCNX
		JG		Fail_CapConnections
		CMP		BYTE PTR [edi+ecx],bl
		JE		Fail_ConnectionRedundancy
		CMP		BYTE PTR [edi+ecx],NULL
		JE		connectnodeA
		INC		edi
		JMP		forA

	connectnodeA:
		MOV		BYTE PTR [edi+ecx],bl
		MOV		edi,1						;set counter back to 1, to begin checking second node.

	forB:									;looks through edx (record of NodeB)
		CMP		edi,MaxNodeCNX
		JG		Fail_CapConnections
		CMP		BYTE PTR [edi+edx],NULL
		JE		connectnodeB
		INC		edi
		JMP		forB

	connectnodeB:
		MOV		BYTE PTR [edi+edx],al

	Success:
		CLC
		JMP		Done
	Fail:
		CALL	WriteString
		CALL	Crlf
		STC
		JMP		Done

	Fail_ConnectionRedundancy:
		MOV		edx,OFFSET error_file_cnxredundancy
		JMP		Fail
	Fail_CapConnections:
		MOV		edx,OFFSET error_file_maxnodeconnections
		JMP		Fail
	Fail_CapHit:
		MOV		edx,OFFSET error_file_maxnodesdefined
		JMP		Fail
	Done:
		POP		edx
		POP		ebx
		POP		edi
		ret
DeclareNodePair ENDP

CreateNode PROC
	; Save registers:
	PUSHAD

	; NodePointer will be held in edi
	MOV		edi,NodePointer
    
	; Check for reaching node limit:
	MOV		al,NumNodes
	CMP		al,MaxNodes
	JGE		TooManyNodes                                 ;Post increment of NumNodes means if we have 6 going in, not to proceed

	; Get node name and # of connections:
	MOV		byte ptr [edi + n_name], bl          ;Takes char name of node and places it in NodeHeap
	MOV		byte ptr [edi + n_numcnx], cl        ;Now we have number of connections for the node in NodeHeap

	; Get the queue address for node from QueueHeap:
	MOVSX	eax,NumNodes
	MOV		ebx,maxqueuesize
	MUL		ebx

	MOV		ebx,OFFSET nodeheap
	ADD		eax,OFFSET QueueHeap
	MOV		DWORD PTR [edi + n_queueptr], eax

	;#### Repeat for front & back queue pointer ####
	MOV		DWORD PTR [edi + n_queuefront], eax
	MOV		DWORD PTR [edi + n_queueback], eax
	 
	;#### Store NodePointer in NodeBuffer for easy access ####
	MOVSX	eax,NodeBufferIndex
	ADD		eax,OFFSET NodeBuffer
	MOV		DWORD PTR[eax], edi
	ADD		NodeBufferIndex,dwordsize

	INC  NumNodes						;Update number of nodes created

	;#### Update NodePointer for next Node ####
	MOV		eax, c_cnx_offset				;12 bytes per connection
	MUL		ecx							;Multiply by number of connections for total variable offset from currently created node
	ADD		eax, n_fixedoffset				;Add constant 14 bytes from beginning of node
	ADD		NodePointer,eax				;NodePointer now ready for next node

	JMP  Success

	TooManyNodes:
		MOV  edx, OFFSET error_file_maxnodesdefined
		CALL WriteString
		JMP		Done
	
	Success:
		
	Done:
		POPAD
		ret
CreateNode ENDP

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
		MOV		inpbufferindex,1
		CALL	SkipSpaces
		MOV		inpbufferindex,0
		JC		BackToMenu
		JNC		processfile

	processfile:
		CALL	OpenInputFile								;eax holds file handle

		MOV		edx,OFFSET inputbuffer						;Buffer will be empty by this point
		MOV		ecx,inputmax
		CALL	ClearBuffer
		CALL	ReadFromFile								;Load from file into buffer
		JC		filenotfound
		JNC		parsefile

	parsefile:
		CALL	CloseFile									;eax holds open file handle; data already read, so close it
		MOV		edx,OFFSET NodeNames

		XOR		edi,edi										;Empty buffer counter

		getnextpair:
			XOR		eax,eax
			XOR		ebx,ebx
			XOR		ecx,ecx

			MOV		inpbufferindex,edi							;edi is the counter, but we load the counter into bufferinedex before checking next pairs

			CALL	SkipSpaces
			JC		endoffile

			MOV		edi,inpbufferindex

			MOV		edx,OFFSET inputbuffer
			getfirstnode:
				MOV		al,BYTE PTR [edx+edi]
				CALL	ToUpper
				MOV		bl,al								;bl stores first node letter.
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
			MOV		edx,OFFSET NodeNames
			MOV		edx,OFFSET inputbuffer					;clear input buffer
			MOV		ecx,inputmax
			CALL	ClearBuffer


			;check if network has sub-networks. if so, error.*********************************************************************************


			;Get number of connections
			XOR		ecx,ecx									;ecx holds number of connections
			XOR		edi,edi									;edi is the record offset from NodeNames
			XOR		esi,esi									;esi is the index from within a record
			MOV		edx,OFFSET NodeNames

			getrecordCNX:
				CMP		edi,MaxNodes
				JG		WireNodes
				CMP		BYTE PTR[edx],NULL
				JE		WireNodes
				
				MOV		bl,BYTE PTR[edx]

				MOV		esi,1								;esi steps to each connection from within the record, starting at 1
				XOR		ecx,ecx								;start node's #CNX at 0
				getnumconnections:
					CMP		esi,MaxNodeCNX
					JG		createthisnode
					MOV		al,BYTE PTR [edx+esi]
					CMP		BYTE PTR [edx+esi],NULL
					JE		createthisnode
					INC		ecx
					INC		esi
					JMP		getnumconnections

			steprecord:
				ADD		edx,MaxNodeCNX+1
				INC		edi
				JMP		getrecordCNX

			createthisnode:
				CALL	CreateNode
				JMP		steprecord

			WireNodes:
				MOV		edx,offset NodeBuffer

				;loop through each node address in NodeBuffer. make the connections


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
	MOV		eax,OFFSET NodeHeap
	MOV		NodePointer,OFFSET NodeHeap						;NodePointer points to beginning of the NodeHeap

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
	MOV		ebx,inpbufferindex

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
		MOV		inpbufferindex,ebx
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
