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
NodeIndex			BYTE 0										;Index for NodeBuffer. ADD FOUR TO INCREMENT TO NEXT NODE. 

TestVar				BYTE "^"
RCVXMTBuffer		BYTE packetsize*MaxNodes*2 dup(0)			;allocation for RCV and XMT buffers
RCVXMTOffset		SBYTE 0

NodeHeap			BYTE MaxNodes * (n_fixedoffset + MaxNodeCNX * c_cnx_offset) dup(0)			;Byte allocation for maximum nodes & relevant data
NodeCNXPointer		DWORD 0
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
DefaultNetwork		BYTE "ab bc cd df fe ea ec bf",0

;========Output messages========;
prompt_loadnodemenu1			BYTE "	1: Load from file",0
prompt_loadnodemenu2			BYTE "	2: Load from keyboard",0
prompt_loadnodemenu3			BYTE "	3: Load from default",0
prompt_loadnodemenu4			BYTE "Please make a selection (1-3): ",0
prompt_filepath					BYTE "Please enter a file path, or type ""*"" to exit to menu: ",0

out_time			BYTE "Time is ",0
out_outgoing		BYTE "Processing outgoing queue of",0
out_attime			BYTE "At time ",0	
out_messagefrom		BYTE "a message came from ",0
out_thereare		BYTE "There are ",0
out_newmessages		BYTE "new messages ",0
out_messagegenerated	BYTE "a message is generated ",0

 
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



ConfigureNetwork PROC
	PUSHAD

	MOV		edx,OFFSET NodeNames

	CALL	DeclareNodes
	JC			Fail

	;check if network has sub-networks. if so, error.*********************************************************************************

	CALL	SetNumConnections
	JC			Fail
	CALL	LinkConnections
	JC			Fail
	CALL	LinkRCVXMTs
	JC			Fail

	Success:
		CLC
		JMP		Done
	Fail:													;Fail indicates bad data/processing. Go back to menu
		CALL Crlf
		CALL Crlf
		STC
		JMP		Done
	Done:
		POPAD
		ret
ConfigureNetwork ENDP

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
		CALL	ClearBuffer

		MOV		edx,OFFSET inputbuffer
		MOV		ecx,inputmax
		CALL	ReadString

		MOV		bl,BYTE PTR [edx]

		CALL	ClearBuffer

		CMP		bl,"1"
		JE		selection1
		CMP		bl,"2"
		JE		selection2
		CMP		bl,"3"
		JE		selection3
		JMP		promptloadtype

	selection1:
		CALL	GetFormatFromFile
		JC		promptloadtype
		JMP		finalize

	selection2:
		CALL	GetFormatFromKeyboard
		JC		promptloadtype
		JMP		finalize

	selection3:
		MOV		esi,OFFSET DefaultNetwork
		MOV		edi,OFFSET inputbuffer
		MOV		ecx,SIZEOF DefaultNetwork
		REP		movsb
		JMP		finalize


	finalize:
		CALL	ConfigureNetwork								;ConfigureNetwork formats all nodes based on the InputBuffer
		JC		promptloadtype
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









GetFormatFromFile PROC
	promptforpath:
		MOV		edx,OFFSET prompt_filepath
		CALL	WriteString
		MOV		edx,OFFSET inputbuffer
		MOV		ecx,inputmax
		CALL	ReadString

		MOV		al,BYTE PTR [inputbuffer]
		CMP		al,quitchar
		JE		checkemptybuffer
		JNE		processfile

		checkemptybuffer:									;used only after a quit character is detected, to indicate sole intention to exit to menu
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

		CALL	CloseFile									;eax holds open file handle; data held in inputbuffer, so close it
		JMP		Success
		
	filenotfound:
		MOV		edx,OFFSET error_file_notfound
		CALL	WriteString
		JMP		promptforpath
		
	BackToMenu:
		STC
		JMP		Done
	Success:
		CLC
		JMP		Done
	Done:
		ret
GetFormatFromFile ENDP

GetFormatFromKeyboard PROC
	
	Done:
		ret
GetFormatFromKeyboard ENDP







LinkRCVXMTs PROC
	PUSHAD

	MOV		NodeIndex,-1							;After all nodes have been created, set the NodeIndex to the beginning
	MOV		ebx,OFFSET NodeNames
	MOV		eax,OFFSET RCVXMTBuffer
	SUB		eax,packetsize							;eax holds RCVXMTBuffer-packetsize. This is because the loop increments eax by packetsize first.

	;Make XMTs for all first

	XMT_NextNode:
		CALL	GetNextNode
		JC		XMT_Complete

		MOV		edi,0
		XMT_GetConnections:
			CALL	GetNextNodeConnection
			JC		XMT_NextNode

			ADD		eax,packetsize

			MOV		ebx,NodeCNXPointer					;ebx holds a connection
			MOV		DWORD PTR [ebx+c_cnx_xmt],eax		;move a delegated XMT buffer (eax) into connection's XMT slot

			JMP		XMT_GetConnections

	XMT_Complete:
		MOV		NodeIndex,-1
		JMP		RCV_NextNode

	;Loop again to redirect for all RCVs
	RCV_NextNode:										;Complex algorithm
		CALL	GetNextNode								;Loop through each node
		JC		Success									;If all nodes looped, linking is complete

		MOV		edx,NodePointer							;edx holds NodePointer for line below
		MOV		al,BYTE PTR [edx+n_name]				;Store the name of the current node into al

		MOV		edi,0									;edi increments for each connection
		RCV_GetConnections:
			CALL	GetNextNodeConnection				;get the edi'th connection
			JC		RCV_NextNode						;if the edi'th connection is max, go to the next Node

			MOV		edx,NodePointer						;edx saves the NodePointer, as it gets overwritten in RCV_GetConnections

			MOV		ebx,NodeCNXPointer					;ebx stores NodeConnection
			PUSH	ebx									;preserve Node Connection
			MOV		ebx,DWORD PTR [ebx]					;ebx now holds the Node that NodeConnection points to
			MOV		NodePointer,ebx						;NodePointer holds NodeConnection's pointer (Node address destroyed, needs to be restored)

			CALL	GetConnectionOfName					;search for a connection in NodeConnection's pointer's Connections to find a node of name al (Node)
			JC		Fail
			
			MOV		ecx,NodeCNXPointer					;NodeCNXPointer now points to a connection that stores the XMT that acts as this NodeConnection's RCV
			MOV		ecx,DWORD PTR [ecx+c_cnx_xmt]		;ecx holds the shared XMT/RCV.

			POP		ebx									;restore the connection
			MOV		NodeCNXPointer,ebx					;Restore NodeCNXPointer. This is because GetNextNodeConnection, after the re-loop, will build off of this

			MOV		DWORD PTR [ebx+c_cnx_rcv],ecx		;Move the RCV address into the RCV slot of ThisConnection

			MOV		NodePointer,edx						;Restore Node address

			JMP		RCV_GetConnections

	Success:
		CLC
		JMP		Done
	Fail:
		STC
		JMP		Done
	Done:
		POPAD
		ret
LinkRCVXMTs ENDP

LinkConnections PROC
	PUSHAD
	MOV		edx,OFFSET NodeNames
	XOR		ecx,ecx									;ecx holds number of connections for a given node
	XOR		esi,esi									;esi is the record offset from NodeNames

	EachNode:
		MOV		bl,BYTE PTR [NodeNames+esi]
		CMP		bl,NULL
		JE		Success
		CMP		esi,SIZEOF NodeNames
		JGE		Success

		MOV		al,bl									;NodeRecord Node name
		CALL	GetNodeOfName
		JC		Success
		
		MOV		edi,0
		EachConnection:
			CALL	GetNextNodeConnection
			JC		NextNode

			MOV		eax,NodePointer						;GetNodeOfName below will overwrite the node that we are making connections for. So we preserve it
			PUSH	eax

			MOV		al,BYTE PTR [NodeNames+esi+edi]
			CALL	GetNodeOfName						;Overwrite NodePointer to now point to the node that the connection is supposed to

			MOV		ebx,NodeCNXPointer					;ecx points to the beginning of connections for the current node
			MOV		ecx,NodePointer						;ecx points to the address of current nodes' current connection's node (ooooooooof)

			MOV		DWORD PTR [ebx+c_cnx_loc],ecx		;ecx is the address of the given connection's node

			POP		eax
			MOV		NodePointer,eax

			JMP		EachConnection

		NextNode:
			ADD		esi,MaxNodeCNX+1
			JMP		EachNode

	Success:
		CLC
		JMP		Done
	Fail:
		STC
		JMP		Done
	Done:
		POPAD
		ret
LinkConnections ENDP

SetNumConnections PROC
	PUSHAD

		;Get number of connections
	XOR		ecx,ecx									;ecx holds number of connections for a given node
	XOR		edi,edi									;edi is the index within NodeNames. Used to see if we have exceeded MaxNodes
	MOV		edx,OFFSET NodeNames

	getrecordCNX:
		CMP		edi,MaxNodes
		JGE		Success
		CMP		BYTE PTR[edx],NULL
		JE		Success

		XOR		ecx,ecx								;ecx counts each connection from within the record
		getnumconnections:
			CMP		ecx,MaxNodeCNX					;if ecx has hit our maxnumber of nodes, create the node
			JGE		createthisnode
			CMP		BYTE PTR [edx+ecx+1],NULL		;+1 offset because the first character in the record is the origin node, the rest are connections. We are counting just the connections
			JE		createthisnode
			INC		ecx
			JMP		getnumconnections

	createthisnode:
		MOV		bl,BYTE PTR [edx]
		CALL	CreateNode
		JMP		steprecord
		
	steprecord:
		ADD		edx,MaxNodeCNX+1
		INC		edi									;go to next node record
		JMP		getrecordCNX

	
	Success:
		CLC
		JMP		Done

	Fail:
		STC
		JMP		Done

	Done:
		POPAD
		ret
SetNumConnections ENDP






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

	MOV		cl,al

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

DeclareNodes PROC
	PUSHAD

	XOR		edi,edi											;Empty buffer counter
	CMP		BYTE PTR[inputbuffer],NULL
	JE		nodenameinvalid

	getnextpair:
		XOR		eax,eax
		XOR		ebx,ebx
		XOR		ecx,ecx

		MOV		inpbufferindex,edi							;edi is the counter, but we load the counter into bufferinedex before checking next pairs

		CALL	SkipSpaces
		JC		Success

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

			CALL	SwapAlBl
			MOV		cl,bl
			CALL	DeclareNodePair
			JC		Fail

			JMP		getnextpair


	nodeletterssame:
		MOV		edx,OFFSET error_file_dualconnection
		CALL	WriteString
		JMP		Fail

	nodenameinvalid:
		MOV		edx,OFFSET error_file_nodenameinvalid
		CALL	WriteString
		JMP		Fail

	Success:
		CLC
		JMP		Done

	Fail:
		STC
		JMP		Done
	Done:
		POPAD
		ret
DeclareNodes ENDP










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
	MOV		eax,dwordsize
	MUL		NodeIndex							;eax now holds NodeIndex * 4, which is the record offset to the next address in NodeBuffer
	ADD		eax,OFFSET NodeBuffer
	MOV		DWORD PTR[eax], edi
	INC		NodeIndex

	INC  NumNodes								;Update number of nodes created

	;#### Update NodePointer for next Node ####
	MOV		eax, c_cnx_offset					;12 bytes per connection
	MUL		ecx									;Multiply by number of connections for total variable offset from currently created node
	ADD		eax, n_fixedoffset					;Add constant 14 bytes from beginning of node
	ADD		NodePointer,eax						;NodePointer now ready for next node

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

GetNextNodeConnection PROC							;Edi MUST be between 0 and MaxNodeCNX
													;NodeCNXPointer points to the edi+1'th connection of node in NodePointer
	PUSH	eax
	PUSH	ecx
	PUSH	edx
	
	MOV		edx,DWORD PTR [NodePointer]				;edx now holds mem address of the node
	MOVSX	ecx,BYTE PTR [edx+n_numcnx]				;ecx holds num connections in node held in NodePointer
	CMP		edi,ecx									;see if connection counter is greater than num connections in node
	JGE		MaxCNX									;if edi exceeds max nodes, we get outta there
	JL		GetConnection

	GetConnection:
		ADD		edx,n_fixedoffset					;edx now points to the beginning of the connections of node N
		MOV		eax,c_cnx_offset					;eax holds byte size of a connection

		PUSH	edx									;MUL overwrites edx, so preserve it
		MUL		edi									;eax now holds #bytes offset from beginning of connections.
		POP		edx

		INC		edi									;increment our node counter
		
		ADD		eax,edx								;eax points to edi'th connection
		MOV		NodeCNXPointer,eax
		JMP		Success

	Success:
		CLC
		JMP		Done

	MaxCNX:
		STC
		JMP		Done

	Done:
		POP		edx
		POP		ecx
		POP		eax
		ret
GetNextNodeConnection ENDP

GetConnectionOfName PROC
	PUSHAD
	
	XOR		edi,edi

	Next:
		CALL	GetNextNodeConnection
		JC		Fail

		MOV		ebx,DWORD PTR[NodeCNXPointer+c_cnx_loc]
		MOV		ebx,DWORD PTR[ebx]
		CMP		BYTE PTR[ebx+n_name],al
		JE		Success
		JMP		Next

	Success:
		CLC
		JMP		Done
	Fail:
		STC
		JMP		Done
	Done:
		POPAD
		ret
GetConnectionOfName ENDP

GetCurrentNode PROC
	PUSH	eax

	MOV		eax,dwordsize				;move dwordsize(4) into eax
	MUL		NodeIndex					;multiply NodeIndex into eax, eax is now the offset from NodeBuffer
	ADD		eax,OFFSET NodeBuffer		;
	MOV		eax,DWORD PTR [eax]			;
	MOV		NodePointer,eax

	POP		eax
	ret
GetCurrentNode ENDP

GetNextNode PROC
	PUSH	eax

	INC		NodeIndex
	MOV		al,NumNodes
	CMP		NodeIndex,al
	JGE		Wrap

	NoWrap:
		CALL	GetCurrentNode
		CLC
		JMP		Done

	Wrap:
		MOV		NodeIndex,0
		CALL	GetCurrentNode
		STC
		JMP		Done

	Done:
		POP		eax
		ret
GetNextNode ENDP

GetNodeOfName PROC										;al holds comparison name. Index through addresses in NodeBuffer
	PUSH	edi
	PUSH	ebx
	PUSH	edx

	MOV		NodeIndex,-1

	checknode:
		CALL	GetNextNode
		JC		NotFound

		MOV		ebx,NodePointer
		MOV		bl,BYTE PTR [ebx+n_name]
		CMP		al,bl
		JE		Found

		JMP		checknode

	Found:
		CLC
		JMP		Done

	NotFound:
		STC
		JMP		Done

	Done:
		POP		edx
		POP		ebx
		POP		edi
		ret
GetNodeOfName ENDP










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
	CMP		al,"A"
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

SwapAlBl PROC
	PUSH	ecx

	MOV		cl,bl					;cl holds NodeB as temp
	MOV		bl,al
	MOV		al,cl					;switch al and  bl. al now holds NodeA name, bl now holds NodeB name

	POP	ecx
	ret
SwapAlBl ENDP







END main
