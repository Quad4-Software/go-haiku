// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// System calls and other sys.stuff for 386 Haiku (libc / SysV ABI).

#include "go_asm.h"
#include "go_tls.h"
#include "textflag.h"

// This is needed by asm_386.s
TEXT runtime·settls(SB),NOSPLIT,$0
	RET

// void libc_miniterrno(void *(*_errnop)(void));
//
// Set the TLS errno pointer in M.
//
// Called using runtime·asmcgocall from minit.
// NOT USING GO CALLING CONVENTION.
// First C ABI arg is at 4(SP) after CALL.
TEXT runtime·miniterrno(SB),NOSPLIT,$0
	MOVL	4(SP), AX
	CALL	AX
	get_tls(CX)
	MOVL	g(CX), BX
	MOVL	g_m(BX), BX
	MOVL	AX, (m_mOS+mOS_perrno)(BX)
	RET

// pipe(3c) wrapper that returns fds in AX, DX.
// NOT USING GO CALLING CONVENTION.
TEXT runtime·pipe1(SB),NOSPLIT,$0
	SUBL	$24, SP
	LEAL	8(SP), AX
	MOVL	AX, 0(SP)
	LEAL	libc_pipe(SB), AX
	CALL	AX
	MOVL	8(SP), AX
	MOVL	12(SP), DX
	ADDL	$24, SP
	RET

// Call a library function with SysV i386 calling conventions.
// Args are passed on the stack. Called by runtime·asmcgocall.
// First C ABI argument (libcall*) is at 4(SP).
// NOT USING GO CALLING CONVENTION.
TEXT runtime·asmsysvicall6(SB),NOSPLIT,$0
	MOVL	4(SP), DI
	MOVL	libcall_fn(DI), AX
	MOVL	libcall_args(DI), BX
	MOVL	libcall_n(DI), CX

	get_tls(SI)
	MOVL	g(SI), DX
	CMPL	DX, $0
	JEQ	skiperrno1
	MOVL	g_m(DX), DX
	MOVL	(m_mOS+mOS_perrno)(DX), DX
	CMPL	DX, $0
	JEQ	skiperrno1
	MOVL	$0, 0(DX)

skiperrno1:
	// Reserve stack for up to 6 args (keep 16-byte aligned).
	SUBL	$32, SP
	CMPL	BX, $0
	JEQ	skipargs
	CMPL	CX, $0
	JEQ	skipargs
	MOVL	0(BX), DX
	MOVL	DX, 0(SP)
	CMPL	CX, $1
	JEQ	skipargs
	MOVL	4(BX), DX
	MOVL	DX, 4(SP)
	CMPL	CX, $2
	JEQ	skipargs
	MOVL	8(BX), DX
	MOVL	DX, 8(SP)
	CMPL	CX, $3
	JEQ	skipargs
	MOVL	12(BX), DX
	MOVL	DX, 12(SP)
	CMPL	CX, $4
	JEQ	skipargs
	MOVL	16(BX), DX
	MOVL	DX, 16(SP)
	CMPL	CX, $5
	JEQ	skipargs
	MOVL	20(BX), DX
	MOVL	DX, 20(SP)

skipargs:
	CALL	AX

	ADDL	$32, SP
	MOVL	4(SP), DI
	MOVL	AX, libcall_r1(DI)
	MOVL	DX, libcall_r2(DI)

	get_tls(SI)
	MOVL	g(SI), BX
	CMPL	BX, $0
	JEQ	skiperrno2
	MOVL	g_m(BX), BX
	MOVL	(m_mOS+mOS_perrno)(BX), AX
	CMPL	AX, $0
	JEQ	skiperrno2
	MOVL	0(AX), AX
	MOVL	AX, libcall_err(DI)

skiperrno2:
	RET

// uint32 tstart_sysvicall(M *newm);
// First C ABI arg at 4(SP).
TEXT runtime·tstart_sysvicall(SB),NOSPLIT,$0
	MOVL	4(SP), DI
	MOVL	m_g0(DI), DX

	get_tls(BX)
	MOVL	DX, g(BX)
	MOVL	DI, g_m(DX)

	MOVL	SP, AX
	MOVL	AX, (g_stack+stack_hi)(DX)
	SUBL	$(0x100000), AX
	MOVL	AX, (g_stack+stack_lo)(DX)
	ADDL	$const_stackGuard, AX
	MOVL	AX, g_stackguard0(DX)
	MOVL	AX, g_stackguard1(DX)

	CLD
	CALL	runtime·stackcheck(SB)
	CALL	runtime·mstart(SB)

	XORL	AX, AX
	RET

// Called from libc signal trampoline. Preserve callee-saved regs.
TEXT runtime·sigtramp(SB),NOSPLIT|TOPFRAME,$0
	SUBL	$128, SP

	MOVL	BX, 16(SP)
	MOVL	BP, 20(SP)
	MOVL	SI, 24(SP)
	MOVL	DI, 28(SP)

	get_tls(BX)
	MOVL	g(BX), AX
	CMPL	AX, $0
	JNE	allgood
	MOVL	132(SP), DX
	MOVL	DX, 0(SP)
	MOVL	$runtime·badsignal(SB), AX
	CALL	AX
	JMP	exit

allgood:
	MOVL	AX, 32(SP)

	MOVL	g_m(AX), BP
	LEAL	(m_mOS+mOS_libcall)(BP), SI
	MOVL	libcall_fn(SI), DX
	MOVL	DX, 36(SP)
	MOVL	libcall_args(SI), DX
	MOVL	DX, 40(SP)
	MOVL	libcall_n(SI), DX
	MOVL	DX, 44(SP)
	MOVL	libcall_r1(SI), DX
	MOVL	DX, 48(SP)
	MOVL	libcall_r2(SI), DX
	MOVL	DX, 52(SP)

	LEAL	(m_mOS+mOS_scratch)(BP), SI
	MOVL	0(SI), DX
	MOVL	DX, 56(SP)
	MOVL	4(SI), DX
	MOVL	DX, 60(SP)
	MOVL	8(SI), DX
	MOVL	DX, 64(SP)
	MOVL	12(SI), DX
	MOVL	DX, 68(SP)
	MOVL	16(SI), DX
	MOVL	DX, 72(SP)
	MOVL	20(SI), DX
	MOVL	DX, 76(SP)

	MOVL	(m_mOS+mOS_perrno)(BP), SI
	MOVL	0(SI), DX
	MOVL	DX, 80(SP)

	MOVL	m_gsignal(BP), BP
	MOVL	BP, g(BX)

	// sighandler(signo, info, ctxt, gp)
	MOVL	132(SP), DX
	MOVL	DX, 0(SP)
	MOVL	136(SP), DX
	MOVL	DX, 4(SP)
	MOVL	140(SP), DX
	MOVL	DX, 8(SP)
	MOVL	32(SP), DX
	MOVL	DX, 12(SP)
	CALL	runtime·sighandler(SB)

	get_tls(BX)
	MOVL	g(BX), BP
	MOVL	g_m(BP), BP

	LEAL	(m_mOS+mOS_libcall)(BP), SI
	MOVL	36(SP), DX
	MOVL	DX, libcall_fn(SI)
	MOVL	40(SP), DX
	MOVL	DX, libcall_args(SI)
	MOVL	44(SP), DX
	MOVL	DX, libcall_n(SI)
	MOVL	48(SP), DX
	MOVL	DX, libcall_r1(SI)
	MOVL	52(SP), DX
	MOVL	DX, libcall_r2(SI)

	LEAL	(m_mOS+mOS_scratch)(BP), SI
	MOVL	56(SP), DX
	MOVL	DX, 0(SI)
	MOVL	60(SP), DX
	MOVL	DX, 4(SI)
	MOVL	64(SP), DX
	MOVL	DX, 8(SI)
	MOVL	68(SP), DX
	MOVL	DX, 12(SI)
	MOVL	72(SP), DX
	MOVL	DX, 16(SI)
	MOVL	76(SP), DX
	MOVL	DX, 20(SI)

	MOVL	(m_mOS+mOS_perrno)(BP), SI
	MOVL	80(SP), DX
	MOVL	DX, 0(SI)

	MOVL	32(SP), DX
	MOVL	DX, g(BX)

exit:
	MOVL	16(SP), BX
	MOVL	20(SP), BP
	MOVL	24(SP), SI
	MOVL	28(SP), DI
	ADDL	$128, SP
	RET

TEXT runtime·usleep1(SB),NOSPLIT,$0-4
	MOVL	usec+0(FP), BX
	MOVL	$runtime·usleep2(SB), AX

	get_tls(CX)
	CMPL	CX, $0
	JE	usleep1_noswitch
	MOVL	g(CX), DX
	CMPL	DX, $0
	JE	usleep1_noswitch
	MOVL	g_m(DX), DX
	CMPL	DX, $0
	JE	usleep1_noswitch

	MOVL	m_g0(DX), SI
	CMPL	g(CX), SI
	JNE	usleep1_switch
	MOVL	BX, 0(SP)
	CALL	AX
	RET

usleep1_switch:
	MOVL	(g_sched+gobuf_sp)(SI), SI
	MOVL	SP, -4(SI)
	LEAL	-4(SI), SP
	MOVL	BX, 0(SP)
	CALL	AX
	MOVL	0(SP), SP
	RET

usleep1_noswitch:
	MOVL	BX, 0(SP)
	CALL	AX
	RET

// Runs on OS stack. usec is at 4(SP) (C ABI after CALL).
TEXT runtime·usleep2(SB),NOSPLIT,$0
	MOVL	4(SP), DX
	SUBL	$16, SP
	MOVL	DX, 0(SP)
	LEAL	libc_usleep(SB), AX
	CALL	AX
	ADDL	$16, SP
	RET

TEXT runtime·osyield1(SB),NOSPLIT,$0
	LEAL	libc_sched_yield(SB), AX
	CALL	AX
	RET
