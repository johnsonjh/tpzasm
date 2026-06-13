; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/prgend.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; .PRGEND "library file generation": two fully INDEPENDENT modules in one
; object file.  Each module is its own two-pass unit -- forward references
; resolve per module, and module 1's macro/symbols are UNDEFINED in module 2
; (module 2 redefines the same macro name with a different body, and reuses the
; label spellings, which only assembles cleanly if the symbol table was reset).
	.IDENT	MODONE
	.ENTRY	START
	.INTERN	HELPER
	.DEFINE	LOAD[X] =
	[MVI	A,X]
START:	LOAD	1
	LXI	H,FWD
	JMP	FWD
HELPER:	.WORD	START
FWD:	RET
	.PRGEND
	.IDENT	MODTWO
	.ENTRY	START
	.INTERN	HELPER
	.DEFINE	LOAD[X] =
	[MVI	B,X]
START:	LOAD	2
	LXI	H,FWD
	JMP	FWD
HELPER:	.WORD	START
FWD:	RET
	.END
