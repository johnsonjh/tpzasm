; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/varargs.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; The PSA "&" macro variable-argument count (manual Ch.4): inside a macro, "&"
; evaluates to the number of arguments of the current invocation -- the larger
; of the declared dummy-parameter count and the number actually passed.  As a
; binary operator "&" is still AND (it is "&" only at the start of an operand).
; Emits 02 03 05 01.
;
; DIALECT NOTE: assembled with -p (PSA PASM).  "&" as an argument count is a
; PASM feature; TDL ZASM 2.21 rejects it, so it cannot be differentially
; verified on ZASM (where "&" is only the AND operator).

	.DEFINE	P2[A,B]=[
	.BYTE	&		; 2 declared params
]
	.DEFINE	VG=[
	.BYTE	&		; no declared params (true varargs)
]
	P2			; 0 passed, 2 declared -> 02
	P2	1,2,3		; 3 passed > 2 declared  -> 03
	VG	9,8,7,6,5	; 5 passed, 0 declared  -> 05
	.BYTE	5&3		; binary AND still works -> 01
	.END
