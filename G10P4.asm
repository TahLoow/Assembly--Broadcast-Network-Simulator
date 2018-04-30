title Network Simulator
; Program 4
; Group 10
; Paul MacLean, Mark Blatnik, Tyler Harclerode
; March 1, 2018

INCLUDE Irvine32.inc

.data

true			EQU 1
false			EQU 0
dwordsize		EQU 4
numholder		DWORD 0
decten			BYTE 10
quitflag		BYTE 0
echoflag		BYTE 0
NULL			EQU 0
networktime		WORD 0
NodeSentFlag	BYTE 0
GlobalSentFlag	BYTE 0

NumCreated		BYTE 0
PacketsReached_Hops		WORD 0
PacketsReached	WORD 0
UniquePackets	WORD 1

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

pack_size			EQU 8
pack_dest			EQU 0
pack_source			EQU 1
pack_sender			EQU 2 
pack_rcvtime		EQU 4
pack_ttl			EQU 6

;========Node Data========;
NumNodes			BYTE 0
MaxNodes			EQU 10
MaxNodeCNX			EQU 9										;Max Connections per node

;========Buffers & Heaps========;
NodeNamesSize		EQU MaxNodes * (1 + MaxNodeCNX)
NodeNames			BYTE NodeNamesSize+1 dup(0)			;List of all node **names**, plus MaxNodeCNX bytes for each node to store the connections.

NodeBuffer			DWORD MaxNodes dup(0)						;List of pointers that point to beginning of each existing node in NodeHeap. For easier indexing through nodes
NodeIndex			BYTE 0										;Index for NodeBuffer. 

TestVar				BYTE "^"
RCVXMTBuffer		BYTE pack_size*MaxNodes*2 dup(0)			;allocation for RCV and XMT buffers
PacketPointer		DWORD 0

NodeHeap			BYTE MaxNodes * (n_fixedoffset + MaxNodeCNX * c_cnx_offset) dup(0)			;Byte allocation for maximum nodes & relevant data
CNXIndex			DWORD 0
CNXPointer			DWORD 0
NodePointer			DWORD 0										;Points to the beginning of a node in the NodeHeap.

maxqueuesize		EQU 80										;Max # of packets a node can hold at any given time.
QueueHeap			BYTE pack_size*maxqueuesize*MaxNodes dup(0)		;Byte allocation for max queues. Each node gets one queue, and points to one queue.

inputmax			EQU 100	
inputbuffer			BYTE inputmax+1 dup(0)							;Keyboard input buffer
inpbufferindex		DWORD 0											;Used to keep track of inputbuffer positions



v_stackmax		EQU 150
v_stackcount	BYTE 0
v_stack			BYTE v_stackmax dup(0)
v_nodesvisited	BYTE MaxNodes dup(0)
v_numvisited	DWORD 0


packetdefaultTTL	EQU 6
defaultpacket		BYTE pack_size dup(0)
emptypacket			BYTE pack_size dup(0)
TotalPackets		BYTE 0

;========Random Values========;
spacechar		BYTE 20h,0					;Space character
tabchar			BYTE 9h,0					;Tab character
CRchar			BYTE 0Dh					;carriage return
LFchar			BYTE 0Ah					;line feed
UpperMask		BYTE 0DFh					;Mask to make alphabetic characters uppercase
flag			BYTE 0						;boolean flag for certain operations, for when carry flag already is used

;========Misc. Strings========;
quitchar			BYTE "*"
DefaultNetwork		BYTE "ab bc cd ea df ce bf fe",0

;========Output messages========;
prompt_maxnodes					BYTE "The maximum Nodes for a network are ",0
prompt_maxcnx					BYTE ". The maximum connections for any given node is ",0
prompt_loadnodemenu1			BYTE "	1: Load from file",0
prompt_loadnodemenu2			BYTE "	2: Load from keyboard",0
prompt_loadnodemenu3			BYTE "	3: Load from default",0
prompt_loadnodemenu4			BYTE "Please make a selection (1-3): ",0
prompt_filepath					BYTE "Please enter a file path, or type ""*"" to exit to menu: ",0
prompt_keyboard					BYTE "Please enter a node network format: ",0
prompt_source					BYTE "Please enter a source node (A,B,etc):",0
prompt_destination				BYTE "Please enter a destination node:",0
prompt_echo						BYTE "Enter '1' (without quotes) for echo, or '2' (without quotes) for no echo: ",0

out_timeis				BYTE "Time is ",0
out_xmt_processing		BYTE "	Processing outgoing queue of node ",0
out_xmt_sending			BYTE "		Preparing to send message to node ",0
out_xmt_sent			BYTE "			The message was sent",0
out_xmt_notsent			BYTE "			The message was not sent due to echo",0
out_xmt_attime			BYTE "		At time ",0
out_xmt_messagefrom		BYTE " a message came from ",0


out_rcv_processing		BYTE "	Processing receiving buffer of node ",0
out_rcv_receiving		BYTE "		Message received from node ",0
out_rcv_reached			BYTE "		Message has reached destination",0

out_thereare			BYTE "		There are ",0
out_tabs				BYTE "		",0
out_newmessages			BYTE " new messages generated",0
out_activemessages		BYTE " active messages",0

out_numreached			BYTE "Total packets reached: ",0
out_numgenerated		BYTE "Total packets generated: ",0
out_timeofextinction	BYTE "Total time until all packets died: ",0

out_test1				BYTE "Node: ",0
out_test2				Byte "	CNX: ",0

 
filename	BYTE "C:\Users\macle\Desktop\TEST.txt"

;========Error messages========;
error_file_notfound					BYTE "File name not found",0
error_file_nodenameinvalid			BYTE "Invalid node name",0
error_file_dualconnection			BYTE "Invalid format. Node cannot connect to itself",0
error_file_maxnodesdefined			BYTE "Too many nodes declared",0
error_file_maxnodeconnections		BYTE "Too many node connections",0
error_file_cnxredundancy			BYTE "Connection definition redundancy",0
error_invalidinput					BYTE "That input is invalid, please try again.",0
error_nodenonexistant				BYTE "There is no node by that name, please try again.",0
error_validation_networknotwhole	BYTE "Described network not whole",0
.code


;===========Procedure Descriptions===========;
;SkipSpaces:
;	Description:		Skips whitespace characters in bufferindex from bufferindex onwards. 
;	Preconditions:		None
;	Postconditions:		bufferindex directs towards non-whitespace character. If character is null-terminator, sets carry



main PROC
	CALL	InitializeNodes
	CALL	GetSettings

	CALL	DisplayNetwork

	Engine:
		MOV		edx,OFFSET NodeHeap
		CALL	TransmitMessages
		CALL	UpdateTime
		;CALL	PrintAllBuffers					;debug
		CALL	RecieveMessages
		CMP		GlobalSentFlag,true
		JNE		Done

		CMP		quitflag,0						;check quit flag
		JNE		Done
		JMP		Engine
		
		
	Done:
		CALL		Crlf
		CALL		Crlf
		MOV			edx,OFFSET out_numreached
		CALL		WriteString
		MOVSX		eax,PacketsReached
		CALL		WriteDec
		CALL		Crlf

		MOV			edx,OFFSET out_numgenerated
		CALL		WriteString
		MOVSX		eax,UniquePackets
		CALL		WriteDec
		CALL		Crlf

		MOV			edx,OFFSET out_timeofextinction
		CALL		WriteString
		MOVSX		eax,networktime
		CALL		WriteDec
		CALL		Crlf

		MOV			edx,OFFSET inputbuffer
		MOV			ecx,1
		CALL		ReadString
		exit
main ENDP


PrintAllBuffers PROC
	CALL	Crlf
	MOV		NodeIndex,-1
	NodeLoop:
		CALL	GetNextNode
		JC		AllChecked

		MOV		CNXIndex,-1
		CNXLoop:
			CALL	GetNextNodeConnection
			JC		NodeLoop

			MOV		edx,CNXPointer
			ADD		edx,c_cnx_rcv
			MOV		edx,DWORD PTR[edx]

			CMP		BYTE PTR[edx],0
			JE		CNXLoop

			MOV		ecx,3
			ok:
				MOV		al,BYTE PTR[edx]
				CALL	WriteChar
				INC		edx
				DEC		ecx
				CMP		ecx,0
				JG		ok

			MOV		ax,WORD PTR[edx+1]
			CALL	WriteDec
			MOV		ax,WORD PTR[edx+3]
			CALL	WriteDec

			CALL	Crlf
			JMP		CNXLoop

	AllChecked:
		MOV		eax,"	"
		CALL	WriteChar
		MOV		ax,UniquePackets
		MOVSX	eax,UniquePackets
		CALL	WriteDec
		CALL	Crlf
		ret
PrintAllBuffers ENDP

UpdateTime PROC
	INC		networktime
	ret
UpdateTime ENDP

TransmitMessages PROC
	MOV		edx,OFFSET out_timeis
	CALL	WriteString
	MOVSX	eax,networktime
	CALL	WriteDec
	CALL	Crlf

	MOV		NodeSentFlag,false
	MOV		GlobalSentFlag,false

	MOV		NodeIndex,-1
	NodeLoop:
		CALL	GetNextNode
		JC		AllChecked

		MOV		NodeSentFlag,false

		MOV		edx,OFFSET out_xmt_processing
		CALL	WriteString
		MOV		eax,[NodePointer]
		ADD		eax,n_name
		MOVSX	eax,BYTE PTR[eax]
		CALL	WriteChar
		CALL	Crlf

		CALL	PeekQueue											;Get first value in queue into PacketPointer
		JC		NextNode											;Queue is empty
		MOV		esi,PacketPointer									;Store packet address into esi

		;;;;;;													;AtTimeMessageFrom printouts
		MOV		edx,OFFSET out_xmt_attime
		CALL	WriteString
		MOVSX	eax,WORD PTR[esi+pack_rcvtime]
		CALL	WriteDec
		MOV		edx,OFFSET out_xmt_messagefrom
		CALL	WriteString
		MOVSX	eax,WORD PTR[esi+pack_sender]
		CALL	WriteChar
		CALL	Crlf

		MOV		NumCreated,0
		MOV		CNXIndex,-1
		CNXLoop:
			CALL	GetNextNodeConnection
			JC		CheckDequeue
			
			MOV		eax,CNXPointer+c_cnx_loc						;eax holds the connection's address
			MOV		eax,DWORD PTR[eax]
			MOVSX	eax,BYTE PTR[eax+n_name]								;al holds the connection's name
				
			MOV		edx,OFFSET out_xmt_sending						;print "Sending" message
			CALL	WriteString
			CALL	WriteChar
			CALL	Crlf

			CMP		echoflag,true				;check for echo
			JE		DoSend

			CMP		BYTE PTR[esi+pack_sender],al					;if echo is false, and the lastsender != the connection, send the node
			JNE		DoSend

			MOV		edx,OFFSET out_xmt_notsent						;message not sent due to echo
			CALL	WriteString
			CALL	Crlf
			JMP		NextConnection									;check next connection

			DoSend:
				MOV		NodeSentFlag,true
				MOV		GlobalSentFlag,true

				MOV		eax,NodePointer
				ADD		eax,n_name
				MOVSX	eax,BYTE PTR[eax]
				MOV		BYTE PTR[esi+pack_sender],al				;update sender

				;esi holds the message we send
				MOV		edi,CNXPointer					;edi holds the xmt buffer
				ADD		edi,c_cnx_xmt
				MOV		edi,[edi]

				MOV		ecx,pack_size
				CLD

				PUSH	esi
				REP		MOVSB
				POP		esi

				MOV		edx,OFFSET out_xmt_sent
				CALL	WriteString
				CALL	Crlf

				INC		NumCreated
				JMP		NextConnection

			NextConnection:
				JMP		CNXLoop

		CheckDequeue:
			CMP		NodeSentFlag,true				;if a message was sent, dequeue
			JNE		NextNode				;else, go to next node
			
			CALL	DeQueue
			DEC		UniquePackets			;packet removed from queue, so decrement

			MOV		edx,OFFSET out_tabs
			CALL	WriteString
			MOVSX	eax,NumCreated
			CALL	WriteDec
			MOV		edx,OFFSET out_newmessages
			CALL	WriteString
			CALL	Crlf

			JMP		NextNode

		NextNode:
			JMP		NodeLoop

	AllChecked:
		ret
TransmitMessages ENDP

RecieveMessages PROC
	MOV		edx,OFFSET out_timeis
	CALL	WriteString
	MOVSX	eax,networktime
	CALL	WriteDec
	CALL	Crlf

	MOV		NodeIndex,-1
	NodeLoop:
		CALL	GetNextNode
		JC		AllChecked

		MOV		edx,OFFSET out_rcv_processing
		CALL	WriteString
		MOV		ebx,[NodePointer]
		MOV		al,BYTE PTR[ebx+n_name]
		CALL	WriteChar
		CALL	Crlf
		
		MOV		CNXIndex,-1
		CNXLoop:
			CALL	GetNextNodeConnection
			JC		NextNode

			MOV		esi,CNXPointer
			ADD		esi,c_cnx_rcv
			MOV		esi,DWORD PTR[esi]
			MOV		PacketPointer,esi

			MOV		bl,BYTE PTR[esi]								;check first byte of recieving buffer
			CMP		bl,0
			JE		NextConnection									;if byte 0 of buffer is 0, we have no message

			MOV		bl,BYTE PTR[esi+pack_dest]
			CMP		al,bl
			JE		PacketReached

			MOV		edx,OFFSET out_rcv_receiving
			CALL	WriteString
			MOV		al,BYTE PTR[esi+pack_sender]
			CALL	WriteChar
			CALL	Crlf

			DEC		WORD PTR[esi+pack_ttl]				;decrement packet's time to live
			CMP		WORD PTR[esi+pack_ttl],0			;see if it's dead
			JLE		Kill								;kill if so

			JMP		AddPacket

			AddPacket:
				MOV		bx,networktime
				DEC		bx
				MOV		WORD PTR[esi+pack_rcvtime],bx
				INC		UniquePackets
				CALL	EnQueue
				JMP		NextConnection

			PacketReached:
				INC		PacketsReached
				INC		UniquePackets
				MOV		cx,packetdefaultTTL
				SUB		cx,WORD PTR[esi+pack_ttl]
				ADD		PacketsReached_Hops,cx

				MOV		edx,OFFSET out_rcv_reached
				CALL	WriteString
				CALL	Crlf

				JMP		Kill

			Kill:
				CALL	ClearMessage
				JMP		NextConnection

			NextConnection:
				JMP		CNXLoop

		ClearMessage:
			CALL	DeQueue
			JMP		NextNode

		NextNode:
			JMP		NodeLoop
			
	AllChecked:
		ret
RecieveMessages ENDP



;#############################################			Queue/Packet Procedures

PeekQueue PROC
	MOV		esi,NodePointer
	ADD		esi,n_queuefront
	MOV		esi,DWORD PTR[esi]
	MOV		PacketPointer,esi
	CALL	MessageExists							;esi holds address of message
	JC		Empty
	JMP		Success

	Success:
		CLC
		JMP		Done
	Empty:
		STC
		JMP		Done
	Done:
		ret
PeekQueue ENDP


IsQueueEmpty PROC
	MOV		eax,PacketPointer
	PUSH	eax
	CALL	GetQueueInfo						;EDI holds next value, EAX holds address of queue, EBX holds Back pointer, ECX holds Front pointer

	MOV		PacketPointer,ecx
	CALL	MessageExists
	JC		Empty
	JMP		NotEmpty

	NotEmpty:
		CLC
		JMP		Done
	Empty:
		STC
		JMP		Done
	Done:
		POP		eax
		MOV		PacketPointer,eax
		ret
IsQueueEmpty ENDP

IsQueueFull PROC
	CALL	GetQueueInfo						;EDI holds next value, EAX holds address of queue, EBX holds Back pointer, ECX holds Front pointer
	CMP		edi,ecx								;if back+1 == front, full
	JE		Full
	JMP		NotFull

	NotFull:
		CLC
		JMP		Done
	Full:
		STC
		JMP		Done
	Done:
		ret
IsQueueFull ENDP

EnQueue PROC									;Moves packet from PacketPointer into the queue of NodePointer. Deletes from PacketPointer.
	CALL	IsQueueFull
	JC		QueueFull

	CALL	IsQueueEmpty
	JC		QueueEmpty
	JMP		Goldilocks

	QueueEmpty:
		MOV		edi,ecx
		JMP		Paste

	Goldilocks:
		MOV		ebx,NodePointer
		ADD		ebx,n_queueback
		MOV		DWORD PTR[ebx],edi				;node's back pointer is now relocated
		JMP		Paste

	Paste:
		MOV		esi,PacketPointer
		MOV		ecx,pack_size
		CLD
		REP		MOVSB

		CALL	ClearMessage

		JMP		Success

	Success:
		CLC
		JMP		Done
	QueueFull:
		STC
		JMP		Done
	Done:
		ret
EnQueue ENDP

DeQueue PROC
	CALL	IsQueueEmpty
	JC		IsEmpty
	JMP		NotEmpty

	NotEmpty:
		CALL	ClearMessage					;ecx preserved in this procedure

		PUSH	ecx
		MOV		esi,OFFSET emptypacket
		MOV		edi,ecx							;ecx holds back of queue
		MOV		ecx,pack_size
		CLD
		REP		MOVSB

		MoveFront:
			POP		ecx

			CMP		ebx,ecx
			JE		Done

			ADD		ecx,pack_size
			ADD		eax,maxqueuesize
			CMP		ecx,eax
			JGE		Wrap
			JMP		UpdatePointer
			Wrap:
				MOV		ecx,eax
				JMP		UpdatePointer

		UpdatePointer:
			MOV		eax,NodePointer
			ADD		eax,n_queuefront
			MOV		DWORD PTR[eax],ecx
			JMP		Done

	IsEmpty:
		STC
		JMP		Done
	Done:
		ret
DeQueue ENDP

GetQueueInfo PROC								;returns: EDI holding next value in the queue, EAX holds address of queue, EBX holds Back pointer, ECX holds Front pointer
	MOV		eax,NodePointer
	ADD		eax,n_queueptr
	MOV		eax,DWORD PTR[eax]					;eax holds address of the queue
	
	MOV		ebx,NodePointer
	ADD		ebx,n_queueback						;ebx holds address of where node's back pointer is stored
	MOV		ebx,DWORD PTR[ebx]					;edi holds back pointer

	MOV		edi,ebx
	ADD		edi,pack_size						;edi holds next location in the queue
		PUSH	eax
	ADD		eax,maxqueuesize
	CMP		edi,eax								;see if edi is too far out
	JGE		Wrap
	POP		eax
	JMP		Done

	Wrap:
		POP		eax
		MOV		edi,eax
		JMP		Done

	Done:
		MOV		ecx,NodePointer
		ADD		ecx,n_queuefront
		MOV		ecx,DWORD PTR[ecx]

		ret
GetQueueInfo ENDP

ClearMessage PROC
	PUSH	esi
	PUSH	edi
	PUSH	ecx

	MOV		esi,OFFSET emptypacket
	MOV		edi,PacketPointer
	MOV		ecx,pack_size
	CLD
	REP		MOVSB

	POP		ecx
	POP		edi
	POP		ecx
	ret
ClearMessage ENDP

MessageExists PROC														;edi holds an address of what should hold a message. Sets carry if no message. Moves message address into EDI
	PUSH	edx
	MOV		edx,PacketPointer
	CMP		BYTE PTR[edx],0
	JE		NonExistant
	JMP		Existant

	Existant:
		CLC
		JMP		Done
	NonExistant:
		STC
		JMP		Done
	Done:
		POP		edx
		ret
MessageExists ENDP





;#############################################			Settings Procedures



Settings_GetNodeInput PROC
	CALL	WriteString

	MOV		edx,OFFSET inputbuffer
	MOV		ecx,inputmax
	CALL	ClearBuffer
	CALL	ReadString							;get
	MOV		inpbufferindex,0
	CALL	SkipSpaces							;skip leading spaces

	ADD		edx,inpbufferindex
	MOV		al,BYTE PTR[edx]					;al holds first character (node name)
	INC		inpbufferindex						;when we call SkipSpaces from this new value, it would start *after* the node name
	ret
Settings_GetNodeInput ENDP

Settings_AffirmNodeName PROC						;Checks if the input in the inputbuffer is valid. al holds node's name
	CALL	SkipSpaces							;check if al is only character
	JNC		InvalidError						;if not, try again

	CALL	GetNodeOfName						;Check if node name exists
	JC		NodeNotFoundError
	JMP		Success

	InvalidError:
		CALL	InvalidInput
		STC
		JMP		Done
	NodeNotFoundError:
		CALL	NodeNonexistant
		STC
		JMP		Done
	Success:
		CLC
		JMP		Done
	Done:
		ret
Settings_AffirmNodeName ENDP

GetSettings PROC
	GetSource:
		MOV		edx,OFFSET prompt_source			;Write prompt
		CALL	Settings_GetNodeInput

		CALL	Settings_AffirmNodeName
		JC		GetSource							;al holds capital name of node
		JMP		SetSource
	SetSource:
		MOV		BYTE PTR[defaultpacket+pack_source],al			;source goes into the source portion of the packet
		MOV		BYTE PTR[defaultpacket+pack_sender],al			;source goes into the sender portion of the packet
		JMP		GetDestination

	GetDestination:
		MOV		edx,OFFSET prompt_destination		;Write prompt
		CALL	Settings_GetNodeInput

		CALL	Settings_AffirmNodeName				;al holds capital name of node
		JC		GetDestination
		JMP		SetDest
	SetDest:
		MOV		BYTE PTR[defaultpacket+pack_dest],al			;move the destination into the destination portion of the packet
		JMP		GetEcho

	GetEcho:
		MOV		edx, OFFSET prompt_echo
		CALL	WriteString

		MOV		edx,OFFSET inputbuffer
		MOV		ecx,inputmax
		CALL	ClearBuffer
		CALL	ReadString							;get

		MOV		inpbufferindex,0
		CALL	SkipSpaces							;skip leading spaces
		ADD		edx,inpbufferindex
		MOV		al,BYTE PTR[edx]					;al holds first character (node name)
		
		CMP		al,"1"
		JE		SetEchoTrue
		CMP		al,"2"
		JE		SetTTL
		JMP		GetEcho

		SetEchoTrue:
			MOV		echoflag,true
			JMP		SetTTL

	SetTTL:
		MOV		DWORD PTR[defaultpacket+pack_ttl],packetdefaultTTL				;move default packet time to live into packet
		JMP		PlacePacket

	PlacePacket:
		MOV		al,BYTE PTR[defaultpacket+pack_source]					;al holds name of source node
		CALL	GetNodeOfName											;NodePointer holds address of source node

		MOV		PacketPointer,OFFSET DefaultPacket
		CALL	EnQueue

		JMP		Done

	D_InvalidError:
		CALL	InvalidInput
		JMP		GetDestination
	D_NodeNotFoundError:
		CALL	NodeNonexistant
		JMP		GetSource

	Done:
		ret
GetSettings ENDP















DisplayNetwork PROC
	MOV		NodeIndex,-1												;NodeIndex starts at -1 (start at 1st node)
	NodeLoop:
		CALL	GetNextNode												;Get next node, place the address into NodePointer
		JC		AllChecked												;Carry flag if we looped through all nodes, exit procedure

		MOV		edx,OFFSET out_test1									;print things
		CALL	WriteString
		MOV		ebx,[NodePointer]
		MOV		al,BYTE PTR[ebx+n_name]
		CALL	WriteChar
		CALL	Crlf

		MOV		CNXIndex,-1													;edi counts the connections for the given node, starts at 0
		CNXLoop:
			CALL	GetNextNodeConnection								;get edi'th connection, place address into CNXPointer
			JC		NextNode											;carry flag if all connections of the connection have been looped

			MOV		edx,OFFSET out_test2								;print things
			CALL	WriteString
			MOV		edx,DWORD PTR[CNXPointer+c_cnx_loc]
			MOV		edx,[edx]
			MOV		al,BYTE PTR[edx+n_name]
			CALL	WriteChar
			CALL	Crlf

			JMP		CNXLoop												;check for next connection

		NextNode:
			CALL	Crlf
			JMP		NodeLoop											;go to the next node

	AllChecked:
		ret
DisplayNetwork ENDP

ConfigureNetwork PROC
	PUSHAD

	MOV		edx,OFFSET NodeNames

	CALL	DeclareNodes
	JC			Fail
	CALL	ValidateNetworkUnity
	JC			Fail
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
		MOV		ecx,NodeNamesSize
		MOV		edi,OFFSET NodeNames
		Clear:
			MOV		BYTE PTR[edi],0
			INC		edi
			DEC		ecx
			CMP		ecx,0
			JG		Clear

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
		MOV		edx,OFFSET prompt_maxnodes
		CALL	WriteString
		MOV		eax,MaxNodes
		CALL	WriteDec
		MOV		edx,OFFSET prompt_maxcnx
		CALL	WriteString
		MOV		eax,MaxNodeCnx
		CALL	WriteDec
		CALL	Crlf
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
	MOV		edx,OFFSET prompt_keyboard
	CALL	WriteString
	CALL	Crlf
	MOV		edx,OFFSET inputbuffer
	MOV		ecx,inputmax
	CALL	ReadString

	Done:
		ret
GetFormatFromKeyboard ENDP


Validation_Push PROC						;al holds node name, pushes to the stack
	PUSH	ecx

	MOV		ecx,OFFSET v_nodesvisited
	ADD		ecx,v_numvisited
	MOV		BYTE PTR[ecx],al
	INC		v_numvisited

	INC		v_stackcount			;increment the index
	MOVSX	ecx, v_stackcount		;move index into exc
	ADD		ecx,OFFSET v_stack
	MOV		BYTE PTR[ecx], al				;move character into the new slot

	POP		ecx
	ret
Validation_Push ENDP

Validation_Pop PROC	;pops whatever is the top of this stack. No prerequisites.
	PUSH	ecx

	MOVSX	ecx,v_stackcount			;move index into lower portion of exc
	ADD		ecx,OFFSET v_stack
	MOV		BYTE PTR[ecx], 0			;move dx into the new slot
	DEC		v_stackcount

	POP		ecx
	ret
Validation_Pop ENDP

Validation_Peek PROC
	PUSH	ecx

	MOVSX	ecx,v_stackcount			;move index into lower portion of exc
	ADD		ecx,OFFSET v_stack
	MOVSX	eax,BYTE PTR[ecx]

	POP		ecx
	ret
Validation_Peek ENDP

Validation_NodeVisited PROC
	PUSH	eax
	PUSH	ecx
	PUSH	esi

	MOV		esi,OFFSET v_nodesvisited
	MOV		al,BYTE PTR[edi]		;al holds name of node
	MOV		ecx,MaxNodeCNX			;ecx steps through connections
	CheckVisited:
		MOV		bl,BYTE PTR[esi]
		CMP		bl,al
		JE		Visited

		CMP		bl,0
		JE		NotVisited

		INC		esi
		DEC		ecx
		CMP		ecx,0
		JLE		NotVisited
		JMP		CheckVisited

	Visited:
		STC
		JMP		Done
	NotVisited:
		CLC
		JMP		Done
	Done:
		POP		esi
		POP		ecx
		POP		eax
		ret
Validation_NodeVisited ENDP

ValidateNetworkUnity PROC
	MOV		v_numvisited,0

	MOV		edi,OFFSET NodeNames
	MOV		al,BYTE PTR[edi]
	CALL	Validation_Push
	
	MyWhile:
		CMP		v_stackcount,0
		JE		Finale

		CALL	Validation_Peek

		MOV		edi,OFFSET NodeNames
		GetNodeRecord:
			CMP		BYTE PTR[edi],0
			JE		ConnectionsComplete

			CMP		al,BYTE PTR[edi]
			JE		ScanNode
			ADD		edi,MaxNodeCNX+1

			JMP		GetNodeRecord

		ScanNode:
			CNXLoop:
				INC		edi
				MOV		al,BYTE PTR[edi]

				CMP		al,0
				JE		ConnectionsComplete

				CALL	Validation_NodeVisited
				JC		NextCNX
				CALL	Validation_Push
				JMP		MyWhile

			NextCNX:
				JMP		CNXLoop

		ConnectionsComplete:
			CALL	Validation_Pop
			JMP		MyWhile

	;check if all nodes are tagged

	Finale:
		MOV		edi,OFFSET NodeNames
		foreach:
			CMP		BYTE PTR[edi],0
			JE		Success

			MOV		al,BYTE PTR[edi]
			CALL	Validation_NodeVisited
			JNC		Fail
			ADD		edi,MaxNodeCNX+1

			JMP		foreach

	Success:
		CLC
		JMP		Done
	Fail:
		MOV		edi,OFFSET v_nodesvisited
		MOV		ecx,MaxNodes
		Clear:
			MOV		BYTE PTR[edi],0
			INC		edi
			DEC		ecx
			CMP		ecx,0
			JG		Clear

		MOV		edx,OFFSET error_validation_networknotwhole
		CALL	WriteString
		STC		
		JMP		Done
	Done:
		ret
ValidateNetworkUnity ENDP







LinkRCVXMTs PROC
	PUSHAD

	MOV		NodeIndex,-1							;After all nodes have been created, set the NodeIndex to the beginning
	MOV		ebx,OFFSET NodeNames
	MOV		eax,OFFSET RCVXMTBuffer
	SUB		eax,pack_size							;eax holds RCVXMTBuffer-pack_size. This is because the loop increments eax by pack_size first.

	;Make XMTs for all first

	XMT_NextNode:
		CALL	GetNextNode
		JC		XMT_Complete

		MOV		CNXIndex,-1
		XMT_GetConnections:
			CALL	GetNextNodeConnection
			JC		XMT_NextNode

			ADD		eax,pack_size

			MOV		ebx,CNXPointer					;ebx holds a connection
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

		CMP		al,46h
		JE		STOP
		JMP		GO
		STOP:
			NOP

		GO:

		MOV		CNXIndex,-1								;edi increments for each connection
		RCV_GetConnections:
			CALL	GetNextNodeConnection				;get the edi'th connection
			JC		RCV_NextNode						;if the edi'th connection is max, go to the next Node

			MOV		edx,NodePointer						;edx saves the NodePointer, as it gets overwritten in RCV_GetConnections

			MOV		ebx,CNXPointer					;ebx stores NodeConnection
			PUSH	ebx									;preserve Node Connection
			MOV		ebx,DWORD PTR [ebx]					;ebx now holds the Node that NodeConnection points to
			MOV		NodePointer,ebx						;NodePointer holds NodeConnection's pointer (Node address destroyed, needs to be restored)

			CALL	GetConnectionOfName					;search for a connection in NodeConnection's pointer's Connections to find a node of name al (Node)
			JC		Fail
			
			MOV		ecx,CNXPointer					;CNXPointer now points to a connection that stores the XMT that acts as this NodeConnection's RCV
			MOV		ecx,DWORD PTR [ecx+c_cnx_xmt]		;ecx holds the shared XMT/RCV.

			POP		ebx									;restore the connection
			MOV		CNXPointer,ebx					;Restore CNXPointer. This is because GetNextNodeConnection, after the re-loop, will build off of this

			MOV		DWORD PTR [ebx+c_cnx_rcv],ecx		;Move the RCV address into the RCV slot of ThisConnection

			MOV		NodePointer,edx						;Restore Node address

			JMP		RCV_GetConnections

	Success:
		CLC
		JMP		Done
	Fail:
		POP		ebx
		STC
		JMP		Done
	Done:
		POPAD
		ret
LinkRCVXMTs ENDP

LinkConnections PROC
	PUSHAD
	MOV		edx,OFFSET NodeHeap
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
		
		MOV		CNXIndex,-1
		EachConnection:
			CALL	GetNextNodeConnection
			JC		NextNode

			MOV		eax,NodePointer						;GetNodeOfName below will overwrite the node that we are making connections for. So we preserve it
			PUSH	eax

			MOV		edi,CNXIndex
			MOV		al,BYTE PTR [NodeNames+esi+edi+1]
			CALL	GetNodeOfName						;Overwrite NodePointer to now point to the node that the connection is supposed to

			MOV		ebx,CNXPointer					;ecx points to the beginning of connections for the current node
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

	;al holds node A
	;bl holds node B
	;ecx holds record for node A
	;edx holds record for node B


	forA:									;looks through edx (record of NodeA)
		CMP		edi,MaxNodeCNX
		JG		Fail_CapConnections
		CMP		bl,BYTE PTR [edi+ecx]		;if NodeA name == i'th connection name then we have a redundancy
		JE		Fail_ConnectionRedundancy	;error out
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
		CMP		al,BYTE PTR[edi+edx]
		JE		Fail_ConnectionRedundancy
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
	MOV		DWORD PTR [edi + n_queueback], eax			;at the beginning, the back must be a DWORD behind the front.
	 
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















GetNextNodeConnection PROC							;Uses CNXIndex as a counter for connections from the NodePointer. CNXIndex MUST be between -1 and MaxNodeCNX
													;CNXPointer points to the CNXIndex+1'th connection of node in NodePointer
	PUSHAD
	
	MOV		edx,DWORD PTR [NodePointer]				;edx now holds mem address of the node
	MOVSX	ecx,BYTE PTR [edx+n_numcnx]				;ecx holds num connections in node held in NodePointer

	INC		CNXIndex
	CMP		CNXIndex,ecx						;see if connection counter is greater than num connections in node
	JGE		MaxCNX									;if CNXIndex exceeds max nodes, we get outta there
	JL		GetConnection
	

	GetConnection:
		MOV		eax,c_cnx_offset					;eax holds byte size of a connection
		MOV		edi,CNXIndex

		PUSH	edx									;MUL overwrites edx, so preserve it
		MUL		edi									;eax now holds #bytes offset from beginning of connections to the CNXIndex'th connection.
		POP		edx

		ADD		edx,n_fixedoffset					;edx now points to the beginning of the connections of node N
		ADD		eax,edx								;eax points to edi'th connection
		MOV		CNXPointer,eax
		JMP		Success

	Success:
		CLC
		JMP		Done

	MaxCNX:
		STC
		JMP		Done

	Done:
		POPAD
		ret
GetNextNodeConnection ENDP

GetConnectionOfName PROC
	PUSHAD
	MOV		edi,CNXIndex

	MOV		CNXIndex,-1

	Next:
		CALL	GetNextNodeConnection
		JC		Fail

		MOV		ebx,DWORD PTR[CNXPointer+c_cnx_loc]
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
		MOV		CNXIndex,edi
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

	CALL	ToUpper

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

InvalidInput PROC
	PUSH	edx
	MOV		edx,OFFSET error_invalidinput
	CALL	WriteString
	CALL	Crlf
	POP		edx
	ret
InvalidInput ENDP

NodeNonexistant PROC
	PUSH	edx
	MOV		edx,OFFSET error_nodenonexistant
	CALL	WriteString
	CALL	Crlf
	POP		edx
	ret
NodeNonexistant ENDP


END main
