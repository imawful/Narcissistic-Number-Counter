; *****************************************************************
;  Name: Kevin Barrios
;  NSHE ID: 2001697903
;  Section: 
;  Assignment: 12
;  Description: Write an assembly language program provide a
;				count of the Narcissistic numbers between 0 and
;				some user provided limit. In order to improve performance, the program
;				should use threads to perform computations in
;				parallel.

; -----
;  Narcissistic Numbers
;	0, 1, 2, 3, 4, 5,
;	6, 7, 8, 9, 153,
;	370, 371, 407, 1634, 8208,
;	9474, 54748, 92727, 93084, 548834,
;	1741725, 4210818, 9800817, 9926315, 24678050,
;	24678051, 88593477, 146511208, 472335975, 534494836,
;	912985153, 4679307774, 32164049650, 32164049651

; ***************************************************************

section	.data

; -----
;  Define standard constants.

LF		equ	10			; line feed
NULL		equ	0			; end of string
ESC		equ	27			; escape key

TRUE		equ	1
FALSE		equ	0

SUCCESS		equ	0			; Successful operation
NOSUCCESS	equ	1			; Unsuccessful operation

STDIN		equ	0			; standard input
STDOUT		equ	1			; standard output
STDERR		equ	2			; standard error

SYS_read	equ	0			; call code for read
SYS_write	equ	1			; call code for write
SYS_open	equ	2			; call code for file open
SYS_close	equ	3			; call code for file close
SYS_fork	equ	57			; call code for fork
SYS_exit	equ	60			; call code for terminate
SYS_creat	equ	85			; call code for file open/create
SYS_time	equ	201			; call code for get time

; -----
;  Globals (used by threads)

currentIndex	dq	0
myLock		dq	0
BLOCK_SIZE	dq	1000

; -----
;  Local variables for thread function(s).

msgThread1	db	" ...Thread starting...", LF, NULL

; -----
;  Local variables for getUserArgs function

LIMITMIN	equ	1000
LIMITMAX	equ	4000000000

errUsage	db	"Usgae: ./narCounter -t <1|2|3|4|5|6> ",
		db	"-l <septNumber>", LF, NULL
errOptions	db	"Error, invalid command line options."
		db	LF, NULL
errLSpec	db	"Error, invalid limit specifier."
		db	LF, NULL
errLValue	db	"Error, limit out of range."
		db	LF, NULL
errTSpec	db	"Error, invalid thread count specifier."
		db	LF, NULL
errTValue	db	"Error, thread count out of range."
		db	LF, NULL
		
; -----
;  Local variables for sept2int function

qSeven		dq	7
tmpNum		dq	0

; ***************************************************************

section	.text

; ******************************************************************
;  Thread function, numberTypeCounter()
;	Detemrine if narcissisticCount for all numbers between
;	1 and userLimit (gloabally available)

; -----
;  Arguments:
;	N/A (global variable accessed)
;  Returns:
;	N/A (global variable accessed)

common	userLimit	1:8
common	narcissisticCount	1:8
common	narcissisticNumbers	100:8
global narcissisticNumberCounter
narcissisticNumberCounter:
	push rbx 
	push r11 
	push r12 
	push r13 
	push r14 
	push r15
;currentIndex	dq	0
;myLock		dq	0
;BLOCK_SIZE	dq	1000
	; print thread starting message 
	mov rdi, msgThread1
	call printString
	

_getNextBlock: 
	call spinLock
	mov rbx, qword[currentIndex]
	mov rsi, qword[BLOCK_SIZE]
	add qword[currentIndex], rsi
	mov r9, qword[currentIndex]
	call spinUnlock
	mov rsi, 0
	;if current index > user limit end func
	cmp rbx, qword[userLimit] ; r9 is the starting index + blocksize
	ja _endThreadFunc
_threadLoop: ; ***rbx=index****
	mov r13, 0 ; running sum
	;while current index is < userLimit
	cmp rbx, r9
	ja _getNextBlock
	mov r14, 0 ; digit count 
	mov rax, rbx 
_MiniLoop:
	cmp rax, 0
	je _endMini
	mov r15, 10 
	mov rdx, 0
	;cqo
	div r15 
	mov r10, rdx 
	inc r14 ; digit count 
	push r10 ; pushes the single digit onto stack
	jmp _MiniLoop
_endMini:
	; pop for how ever many digits there are 
	; r14 = num of digits
	mov r12, 0
_wholenumLoop: ; main loop that gives me sum of each to digit to length power
	cmp r12, r14
	je _endWholeNum ; loops for number of digits
	pop r10 
	mov rax, r10
	mov rcx, r14
	cmp rcx, 1 ; if digit count is 1 just skip the power and add to sum 
	je _skipDec
	dec rcx ; offset my loop for correct power 
_pow: ; digit to power of digit count 
	mul r10
	loop _pow 
	mov r10, rax
; r10 has the power of first digit
; add to running sum 
; loop back 
_skipDec:
	add r13, r10 
	inc r12
	jmp _wholenumLoop 
_endWholeNum:
	; qword[rbp-8] holds running sum
	; check if running sum == starting number 
	; if true inc narcissitic count 
	; otherwise next number 
	mov r12, r13
	cmp r12, rbx 
	jne _notNarc
_isNarc:
	call spinLock
	mov r10, qword[narcissisticCount]
	mov qword[narcissisticNumbers+(r10*8)], r12
	inc qword[narcissisticCount]
	call spinUnlock
_notNarc: 
	inc rbx 
	jmp _threadLoop

_endThreadFunc:
	pop r15 
	pop r14 
	pop r13 
	pop r12 
	pop r11 
	pop rbx 
	;mov rsp, rbp
	;pop rbp 
ret  







; ******************************************************************
;  Mutex lock
;	checks lock (shared gloabl variable)
;		if unlocked, sets lock
;		if locked, lops to recheck until lock is free

global	spinLock
spinLock:
	mov	rax, 1			; Set the EAX register to 1.

lock	xchg	rax, qword [myLock]	; Atomically swap the RAX register with
					;  the lock variable.
					; This will always store 1 to the lock, leaving
					;  the previous value in the RAX register.

	test	rax, rax	        ; Test RAX with itself. Among other things, this will
					;  set the processor's Zero Flag if RAX is 0.
					; If RAX is 0, then the lock was unlocked and
					;  we just locked it.
					; Otherwise, RAX is 1 and we didn't acquire the lock.

	jnz	spinLock		; Jump back to the MOV instruction if the Zero Flag is
					;  not set; the lock was previously locked, and so
					; we need to spin until it becomes unlocked.
	ret

; ******************************************************************
;  Mutex unlock
;	unlock the lock (shared global variable)

global	spinUnlock
spinUnlock:
	mov	rax, 0			; Set the RAX register to 0.

	xchg	rax, qword [myLock]	; Atomically swap the RAX register with
					;  the lock variable.
	ret

; ******************************************************************
;  Function getUserArgs()
;	Get, check, convert, verify range, and return the
;	sequential/parallel option and the limit.

;  Example HLL call:
;	stat = getUserArgs(argc, argv, &parFlag, &numberLimit)

;  This routine performs all error checking, conversion of ASCII/septenary
;  to integer, verifies legal range.
;  For errors, applicable message is displayed and FALSE is returned.
;  For good data, all values are returned via addresses with TRUE returned.

;  Command line format (fixed order):
;	-t <1|2|3|4|5|6> -l <septNumber>

; -----
;  Arguments:
;	1) ARGC, value - rdi
;	2) ARGV, address - rsi
;	3) thread count (dword), address - edx
;	4) user limit (qword), address - rcx

global getUserArgs
getUserArgs:
	
	push rbp
	mov rbp,rsp 
	sub rsp, 20
	push rbx 
	push r11 
	push r12 
	push r13 
	push r14 
	push r15 

	;copy address' to stack variables
	mov qword[rbp-8], rsi 
	mov dword[rbp-12], edx
	mov qword[rbp-20], rcx 
	;copy argc to r11
	mov r11, rdi 
	;check for usage 
	cmp r11, 1 
	jne _notone 
_argcisone:
	mov rdi, errUsage
	call printString
	mov rax, FALSE 
	jmp _endArgFunc
_notone:
	; argc must be 5 
	cmp r11, 5
	je _validArgc
_invalidArgc:
	mov rdi, errOptions
	call printString
	mov rax, FALSE
	jmp _endArgFunc
_validArgc:
	;get argv in r11
	mov r11, qword[rbp-8] 
	mov r12, 0 ; reset flag 
_tspecCheck:
	; check that argv[1] is -t 
	mov rbx, qword[r11+(8*1)] ; rbx = argv[1]
	cmp byte[rbx], '-'
	jne _tspecErr
	cmp byte[rbx+1], 't'
	jne _tspecErr 
	cmp byte[rbx+2], NULL
	jne _tspecErr 
	mov r12, 1 ; when r12 = 1 (no errors)
_tspecErr:
	cmp r12, 1 
	je _notspecErr
	mov rdi, errTSpec
	call printString
	mov rax, FALSE 
	jmp _endArgFunc
_notspecErr:
	; check next specifier 
	mov r12, 0 ; reset flag
_LspecCheck:
	; check that argv[3] is -l 
	mov rbx, qword[r11+(8*3)] ; rbx = argv[3]
	cmp byte[rbx], '-'
	jne _LspecErr
	cmp byte[rbx+1], 'l'
	jne _LspecErr
	cmp byte[rbx+2], NULL
	jne _LspecErr
	mov r12, 1
_LspecErr:
	cmp r12, 1
	je _nolspecErr
	mov rdi, errLSpec
	call printString
	mov rax, FALSE
	jmp _endArgFunc
_nolspecErr:
	mov r12, 0 ; reset flag 
_threadCheck:
	; check that argv[2] is 1-6 
	mov rbx, qword[r11+(8*2)]
	; going to check if less than 1 or greater than 6
	cmp byte[rbx], '1' 
	jb _threadErr 
	cmp byte[rbx], '6'
	ja _threadErr 
	cmp byte[rbx+1], NULL 
	jne _threadErr 
	mov r14, 0 
	mov r14b, byte[rbx]
	sub r14b, 0x30 ; save thread count in r14 
	mov qword[rdx], r14 ; return thread count via ref
	mov r12, 1 
_threadErr:
	cmp r12, 1 
	je _nothreadErr
	mov rdi, errTValue
	call printString
	mov rax, FALSE
	jmp _endArgFunc
_nothreadErr:
	mov r12, 0 ; reset flag 
_limitCheck:
	; last argv to check is argv[4] seeing
	; if the number is a valid sept num and 
	; is between limitmin and limitmax

	mov rdi, qword[r11+(8*4)]
	mov rsi, tmpNum 
	call aSept2int
	cmp rax, TRUE 
	je _validSeptNum
_notValidSept:
	mov rdi, errLValue
	call printString
	mov rax, FALSE 
	jmp _endArgFunc
_validSeptNum:
	mov r11, qword[tmpNum] ;ehhh
	;check if r11 is in the limit range 
	cmp r11, LIMITMIN
	jb _notValidSept
	cmp r11, LIMITMAX
	ja _notValidSept

	;if alls well then we have a valid sept num 
	; all checks have now passed so we return true
	; and return the user limit 
	mov rcx, 0
	mov rax, TRUE 
	mov rcx, qword[rbp-20] ; copy back address to rcx
	mov qword[rcx], r11    ; set address value to our user limit(decimal)
_endArgFunc:
	pop r15 
	pop r14
	pop r13
	pop r12 
	pop r11 
	pop rbx 
	mov rsp,rbp 
	pop rbp 
ret








; ******************************************************************
;  Function: Check and convert ASCII/septenary to integer.

;  Example HLL Call:
;	bool = aSept2int(septStr, &num);
global aSept2int
aSept2int:
	push rbp 
	mov rbp,rsp 
	sub rsp, 8
	push r10
	push r11 
	push r12 
	push r13 
    push r14 
    push r15 
	push rbx 

	mov qword[rbp-8], rsi 

	mov r13, 0 ; index for loop
	;check all digits are 0-6 before calling asept2int
	; rdi has string
_digitCheckLoop:
	cmp byte[rdi+r13], NULL
	je _LcheckDone
	cmp byte[rdi+r13], '0' 
	jb _limitErr ; error if digit < 0 
	cmp byte[rdi+r13], '6'
	ja _limitErr ; error if digit > 6
	inc r13
	jmp _digitCheckLoop
_limitErr:
	mov rax, FALSE
	jmp _endseptoint
_LcheckDone:

    ;rdi = argv[x]
    mov r13, 0 ; digit count 
    mov r14, 0 ; index 
;first get digit count of number 
_getDigits:
    cmp byte[rdi+r14], NULL 
    je _countDone 
    inc r13 
    inc r14 
    jmp _getDigits 
_countDone:
    ;next get correct power of 7 to multiply digit with
    mov r14, 0  ; index 
    mov r15, 0  ; running sum 
    ;r13 = digit count (from prev loop)
    mov r11, 0  ; single digit from sept number
_septoint:
;firstcheckNULL
    cmp byte[rdi+r14], NULL 
    je _conversionDone 
    dec r13 ; digitcount - 1 (to get correct place value)
    mov rax, 1 ; for 7 to power of n
    mov rcx, r13 ; n
_mul7loop:
    cmp rcx, 0
    je _nomul 
    mov r10, 7
    mul r10 
    loop _mul7loop
_nomul:  ; rax holding what to mul digit with
         ; multiply digit with proper place value digit
    mov r11b, byte[rdi+r14]
    sub r11b, 0x30 ; ascii to dec int
    mul r11 ; (7^n) * digit
    add r15, rax ; running sum
    inc r14 ; index++
    jmp _septoint
_conversionDone:
	mov rsi, qword[rbp-8]
    mov qword[rsi], r15 ; return base10 num 
	mov rax, TRUE 
_endseptoint:

	pop rbx 
    pop r15 
    pop r14 
    pop r13 
	pop r12 
	pop r11 
	pop r10 
	mov rsp, rbp 
	pop rbp 
ret 








; ******************************************************************
;  Generic function to display a string to the screen.
;  String must be NULL terminated.
;  Algorithm:
;	Count characters in string (excluding NULL)
;	Use syscall to output characters

;  Arguments:
;	1) address, string
;  Returns:
;	nothing

global	printString
printString:
	push	rbx

; -----
;  Count characters in string.

	mov	rbx, rdi			; str addr
	mov	rdx, 0
strCountLoop:
	cmp	byte [rbx], NULL
	je	strCountDone
	inc	rbx
	inc	rdx
	jmp	strCountLoop
strCountDone:

	cmp	rdx, 0
	je	prtDone

; -----
;  Call OS to output string.

	mov	rax, SYS_write			; system code for write()
	mov	rsi, rdi			; address of characters to write
	mov	rdi, STDOUT			; file descriptor for standard in
						; EDX=count to write, set above
	syscall					; system call

; -----
;  String printed, return to calling routine.

prtDone:
	pop	rbx
	ret

; ******************************************************************

