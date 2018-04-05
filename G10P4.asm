;title Assembly Program 2
;Paul MacLean, Mark Blatnik, DaNell Griffin
;January 19, 2018

INCLUDE Irvine32.inc

.data

maxjobs			EQU 10

priorityoffset	EQU 0
statusoffset	EQU	4
runtimeoffset	EQU	8		
starttimeoffset	EQU	12
nameoffset		EQU 16

namecharmax		EQU 8

.code

main PROC

	MOV		edx,OFFSET Menu1
	CALL	WriteString
	CALL	Crlf
	MOV		edx,OFFSET Menu2
	CALL	WriteString
	CALL	Crlf
	MOV		edx,OFFSET Menu3
	CALL	WriteString
	CALL	Crlf
	MOV		edx,OFFSET Menu4
	CALL	WriteString
	CALL	Crlf
	MOV		edx,OFFSET Menu5
	CALL	WriteString
	CALL	Crlf
	MOV		edx,OFFSET Menu6
	CALL	WriteString
	CALL	Crlf
	MOV		edx,OFFSET Menu7
	CALL	WriteString
	CALL	Crlf

	engineloop:
		CALL	Crlf
		MOV		edx,OFFSET InputPrompt
		CALL	WriteString

		MOV		edx, OFFSET inputstring
		MOV		ecx, inputmax
		CALL	ReadString

		CALL	processString
		CMP		quitflag,0
		JE		engineloop

	exit
main ENDP



pushit PROC	;pushes whatever is in edx to the stack
	PUSH	ecx
	XOR		ecx, ecx						;Clear ecx

	ADD		sindex, 4						;add 2 bytes to the index
	MOV		cl, sindex						;move index into lower portion of exc
	MOV		sdword PTR[mystack+ecx], edx		;move dx into the new slot

	POP		ecx
	ret
pushit ENDP

popit PROC	;pops whatever is the top of this stack. No prerequisites.
	PUSH	ecx
	XOR		ecx, ecx						;Clear ecx
	
	MOV		cl, sindex						;move index into lower portion of exc
	MOV		sdword PTR[mystack+ecx], 0		;move dx into the new slot
	SUB		sindex, 4						;add 2 bytes to the index

	POP		ecx
	ret
popit ENDP



getnumber PROC
	MOV		numholder,0		;We are starting a new number set, so start with 0.
	XOR		edx,edx			;clear edx in case of overload. We don't care about edx up to this point.
	CMP		sindex,28		;max bytes the array can hold
	JGE		stackfull

	JMP		numdetectloop

	stackfull:
		MOV		edx,OFFSET error_stackfull
		CALL	WriteString
		ret

	numoutofrange:
		MOV		edx,OFFSET error_outofrange
		CALL	WriteString
		ret

	negate:
		NEG		edx
		JMP		finalnum

	numdetectloop:				;post-test loop.
		CALL	charisnumber
		CMP		dl,1
		JNE		endnumdetect	;char is non-numeric, end loop

		SUB		bl,48			;bl now holds the number conversion of the character
			
			PUSH	eax			;save eax (#chars) as it will be overwritten

		MOV		eax,numholder
		MUL		decten			;multiply eax by 10
		ADD		eax,ebx			;add new number to ecx
		MOV		numholder,eax

			POP		eax				;restore eax
			
		MOV		bl, BYTE PTR inputstring[edi]
		INC		edi									;increment edi

		CMP		edi, eax			;compare iterator and max characters
		JG		endnumdetect		;if iterator is greater than # characters, end loop
		JMP		numdetectloop

	endnumdetect:	;check numnegative to negate
		MOV			edx,numholder

		CMP			negflag,1		;if negative flag, negate
		JE			negate
		
		finalnum:
			CMP			numholder,-32768		;Check the new number to see if it's valid. If not, end. 
			JL			numoutofrange
			CMP			numholder,32767
			JG			numoutofrange

			CALL		pushit
	ret
getnumber ENDP

charisnumber PROC	;bl holds the character. afterwards, edx holds 1 if numeric, 0 if non-numeric
	XOR		edx,edx
	MOV		dl,1

	JMP check

	isnotnum:
		MOV		dl,0
		ret

	check:
		CMP		bl,"0"
		JL		isnotnum
		CMP		bl,"9"
		JG		isnotnum
		ret
charisnumber ENDP

crunchbegin PROC			;puts the top of the stack into ebx, second into eax. a-d registers will be destroyed.
	XOR		eax,eax
	XOR		ebx,ebx			
	XOR		ecx,ecx
	XOR		edx,edx

	sufficientelements:
		MOV		cl,sindex						;ecx holds sindex
		MOV		ebx,sdword PTR[mystack+ecx]		;ebx holds top
		MOV		sdword PTR[mystack+ecx],0		;clear out the top of the array
		SUB		cl,4							;shift down the index by one
		MOV		eax,sdword PTR[mystack+ecx]		;ebx holds second-to-top
		ret
crunchbegin ENDP

crunchend PROC				;puts eax into top of stack
	JC		carryerror
	MOV		sdword PTR[mystack+ecx],eax		;store the resultant into the new top
	MOV		sindex,cl						;save the new index properly
	ret

	carryerror:
		MOV		edx,OFFSET error_overflow
		CALL	WriteString
		CALL	Crlf
		ADD		cl,4
		MOV		sdword PTR[mystack+ecx],ebx
		ret
crunchend ENDP

processString PROC
	PUSH	edi
	MOV		quitflag,0							;Carry flag as a 0 means we keep asking for input. "q" input sets the flag to stop the loop
	XOR		ebx, ebx			;we will be using ebx, so clear it out (no save)
	MOV		edi,0				;edi is the loop iterator, starts at 0
	MOV		negflag,0

	JMP		continuecharloop		;Start the loop to go through each character

	;############			OUTPUT/ERRORS
	displaytop:
		MOV		edx,OFFSET stackdisplaymsg
		CALL	WriteString

		MOV		cl, sindex						;move index into lower portion of exc
		MOV		eax,sdword PTR[mystack+ecx]		;move dx into the new slot
		CWD

		CALL	WriteInt
		JMP		leavecharloop
	displaycleared:
		MOV		edx,OFFSET stackclearedmsg
		CALL	WriteString
		CALL	Crlf
		JMP		charloopdone
	insufficientelementserror:
		MOV		edx,OFFSET error_insufficientelements
		CALL	WriteString
		CALL	Crlf
		JMP		charloopdone
	nonnumbererror:
		MOV		edx,OFFSET error_invalidinput
		CALL	WriteString
		CALL	Crlf
		JMP		charloopdone



	closeout:
		MOV		quitflag,1
		JMP		charloopdone
	doexchange:
		CMP		sindex,4
		JL		insufficientelementserror

		XOR		ecx,ecx

		MOV		cl,sindex
		MOV		sdword PTR[mystack+ecx],eax
		SUB		cl,4
		MOV		sdword PTR[mystack+ecx],ebx

		JMP		charloopdone
	donegate:
		MOV		cl,sindex
		MOV		ebx,sdword PTR[mystack+ecx]		;ebx holds top
		NEG		ebx
		MOV		sdword PTR[mystack+ecx],ebx
		JMP		charloopdone
	dorollup:									;Move all elements up starting from the top. move top element to 0th index.
		XOR		ecx,ecx
		MOV		cl,sindex							;ecx is the current index

		rolluploop:
			CMP		cl,-4
			JLE		rolluploopdone

			MOV		ebx,sdword PTR[mystack+ecx]
			ADD		cl,4
			MOV		sdword PTR[mystack+ecx],ebx

			SUB		cl,8
			JMP		rolluploop

		rolluploopdone:
			MOV		cl,sindex
			ADD		cl,4
			MOV		ebx,sdword PTR[mystack+ecx]
			MOV		sdword PTR[mystack+ecx],0
			MOV		sdword PTR[mystack],ebx

			JMP		charloopdone
	dorolldown:									;Move lowest element to the top, roll all down
		XOR		ecx,ecx
		MOV		cl,sindex							;ecx is the current index
		ADD		cl,4								;ecx is the nth+1 index

		MOV		ebx,sdword PTR[mystack]
		MOV		sdword PTR[mystack+ecx],ebx			;put the first element into the nth+1 index

		MOV		cl,0

		rolldownloop:
			CMP		cl,sindex
			JG		rolldownloopdone

			ADD		cl,4
			MOV		ebx,sdword PTR[mystack+ecx]
			SUB		cl,4
			MOV		sdword PTR[mystack+ecx],ebx

			ADD		cl,4
			JMP		rolldownloop

		rolldownloopdone:
			MOV		cl,sindex
			ADD		cl,4
			MOV		sdword PTR[mystack+ecx],0

			JMP		charloopdone


		JMP		charloopdone
	doviewstack:
		MOV		ecx,0

		viewforloop:
			CMP		cl,sindex
			JG		charloopdone

			MOV		eax,sdword PTR[mystack+ecx]		;move dx into the new slot
			CWD
			CALL	WriteInt
			CALL	Crlf

			ADD		ecx,4
			JMP		viewforloop
	doclearstack:
		MOV		ecx,0

		clearforloop:
			CMP		cl,sindex
			JG		endclearforloop
			MOV		sdword PTR[mystack+ecx],0
			ADD		ecx,4
			JMP		clearforloop
			
		endclearforloop:
			MOV		sindex,-4
			JMP		displaycleared
			JMP		charloopdone
	doadd:
		CMP		sindex,4			;check for minimum of elements (2)
		JL		insufficientelementserror

		CALL	crunchbegin
		ADD		eax,ebx							;Add top to second-to-top
		CALL	crunchend

		JMP		charloopdone
	domult:
		CMP		sindex,4			;check for minimum of elements (2)
		JL		insufficientelementserror

		CALL	crunchbegin
		MUL		ebx						;multiply ebx into eax, store into eax
		CALL	crunchend

		JMP		charloopdone
	dodiv:
		CMP		sindex,4			;check for minimum of elements (2)
		JL		insufficientelementserror

		CALL	crunchbegin
		DIV		ebx						;divide eax by ebx, store into eax
		CALL	crunchend

		JMP		charloopdone
	dosub:
		CMP		sindex,4			;check for minimum of elements (2)
		JL		insufficientelementserror

		CALL	crunchbegin
		SUB		eax,ebx							;Subtract top from second
		clc
		CALL	crunchend

		JMP		charloopdone
	checksign:
		PUSH	ebx

		MOV		bl, BYTE PTR inputstring[edi]
		
		CALL	charisnumber
		CMP		dl,1			;check if char after minus is a number
		JE		numbersfollow	;if is a number...
		JMP		loneneg			;else...

		numbersfollow:
			MOV		negflag,1
			POP		ebx
			JMP		continuecharloop
		loneneg:

			POP		ebx
			JMP		dosub
			JMP		charloopdone
	dopushnumber:			;Do not destroy eax. Continue off of edi.
		CALL	getnumber
		JMP		charloopdone





	continuecharloop:
		CMP		edi, eax			;compare iterator and max characters
		JGE		charloopdone		;if iterator is greater/equal to # characters, end loop

		MOV		bl, BYTE PTR inputstring[edi]			;bl holds the edi'th character of the inputstring.
		INC		edi										;increment edi
		OR		bl, 20h									;make the character lower, so we only need to check for lowercase input

		CMP		bl,Spacechar		;SPACE CHAR
		JE		continuecharloop
		CMP		bl,Tabchar			;TAB CHAR
		JE		continuecharloop
		CMP		bl,"q"			;QUIT
		JE		closeout
		CMP		bl,"x"			;EXCHANGE
		JE		doexchange
		CMP		bl,"n"			;NEGATE
		JE		donegate
		CMP		bl,"u"			;ROLL UP
		JE		dorollup
		CMP		bl,"d"			;ROLL DOWN
		JE		dorolldown
		CMP		bl,"v"			;VIEW
		JE		doviewstack
		CMP		bl,"c"			;CLEAR
		JE		doclearstack
		CMP		bl,"+"			;ADD
		JE		doadd
		CMP		bl,"*"			;MULTIPLY
		JE		domult
		CMP		bl,"/"			;DIVIDE
		JE		dodiv
		CMP		bl,"-"			;MINUS SIGN
		JE		checksign

		CALL	charisnumber
		CMP		dl,1
		JE		dopushnumber	;POSSIBLE NUMBER

		JMP		nonnumbererror	;NON NUMBER


	charloopdone:
		CMP		sindex,0
		JGE		displaytop

		leavecharloop:
			MOV		edi,0		;clean up edi
			POP		edi
			ret

processString ENDP



END main ; name of start up procedure



