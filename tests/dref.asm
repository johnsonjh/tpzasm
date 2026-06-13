; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/dref.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; The "D" reference flag: a reference to a multiply-defined symbol flags the
; USING line "D" and places a "?" just past the symbol -- "JMP FOO?", and
; inside an expression "FOO?+1" (the "?" sits before the trailing operator).
; FOO is defined twice; the second definition is the "M" (a "?" on the label,
; "FOO?:") and the FIRST value (0000') is kept, so every later reference to FOO
; is "D" but the emitted object is unchanged.  A singly-defined symbol (BAR) is
; not flagged.  The "M" line is also reproduced on the leading report page.
; Byte-for-byte identical on both dialects (object C3 0000' / 21 0000' / 0001').

FOO:	NOP
FOO:	NOP		; M  -> FOO?:
	JMP	FOO	; D  -> JMP   FOO?
	LXI	H,FOO	; D  -> LXI   H,FOO?
	.WORD	FOO+1	; D  -> .WORD FOO?+1
BAR:	NOP
	JMP	BAR	; no error (BAR is singly defined)
	.END
