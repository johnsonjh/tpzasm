; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/oprem.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; The '@' remainder operator with IDENTIFIER operands.  '@' is NOT a symbol
; character (it is an operator), so DIVD@MODV must parse as DIVD remainder
; MODV, not as one symbol "DIVD@MODV"; this regresses if '@' creeps back into
; the identifier character set.
DIVD	=	17
MODV	=	5
	.WORD	DIVD@MODV	; 17 @ 5  = 2
	.WORD	100@7		; 100 @ 7 = 2
	.BYTE	DIVD@3		; 17 @ 3  = 2
	.END
