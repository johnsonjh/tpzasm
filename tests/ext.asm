; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/ext.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; Linkable object: .IDENT module name, external symbols (16-bit via CALL/LXI
; and 8-bit via MVI -> 110/111 codes), .ENTRY/.INTERN producing the @/# records.

	.IDENT	MYMOD
	.EXTERN	EXTSUB,EXTVAR,EXTB
	.ENTRY	START
	.INTERN	HELPER
	.PREL
START:	CALL	EXTSUB
	LXI	H,EXTVAR
	MVI	A,EXTB
	.WORD	HELPER
HELPER:	RET
	.END
