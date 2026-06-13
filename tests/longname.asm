; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/longname.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; Default 6-character-significant symbol truncation (the Radix-40 rule: a
; symbol may be longer than six characters, but only the first six are used).
; LONGENTRY -> LONGEN, LONGINTERN -> LONGIN, LIBFILE -> LIBFIL, the macro
; LONGMACRO -> LONGMA; the references and the .ENTRY/.INTERN records all
; resolve via the truncated names, so the object is byte-identical to the
; originals.  The clone's non-standard -L option keeps long names in full
; (never the default).  NOTE: identifiers use only the Radix-40 set
; (A-Z 0-9 $ % .); underscore is NOT a symbol character in either dialect.
	.IDENT	LIBFILE
	.ENTRY	LONGENTRY
	.INTERN	LONGINTERN
	.DEFINE	LONGMACRO = [INR A]
LONGENTRY: LONGMACRO
	LXI	H,LONGINTERN
	JMP	LONGENTRY
LONGINTERN: .WORD	LONGENTRY
	RET
	.END
