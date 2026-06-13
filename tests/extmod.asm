; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/extmod.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; The "#" inline external-symbol modifier: a "#" appended to a symbol declares
; it external, exactly as a preceding .EXTERN would (manual Ch.1).  Here FOO,
; BAR and BAZ are never declared with .EXTERN -- the "#" on first use declares
; them, in encounter order, and later bare references resolve to the same
; externals.  The object output is byte-for-byte identical to the equivalent
; explicit ".EXTERN FOO,BAR,BAZ" program.

	.IDENT	EXTMOD
	.PREL
	LXI	H,FOO#		; 16-bit external reference, FOO declared here
	CALL	BAR#		; BAR declared
	.WORD	BAZ#		; BAZ declared (data)
	LXI	D,FOO		; bare reference resolves to the same external
	MVI	A,BAR		; 8-bit external reference (110/111 code)
	.END
