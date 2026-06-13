; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/intern.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; Internal-definition delimiters (manual Ch.1): appending a ':' to a definition
; declares the symbol internal (available to other modules), exactly as a
; ".INTERN sym" would.  The forms are the colon-suffixed definition operators:
;   label::    ==  .INTERN label  +  label:
;   sym=:v     ==  .INTERN sym     +  sym = v
;   sym==:v    ==  .INTERN sym     +  sym == v
; Each emits the internal-symbol ('#') object record and the listing 'I' flag.
; Byte-for-byte identical object to the explicit .INTERN form, both dialects.

AAA::	NOP			; internal label
BBB=:	5			; internal equate
CCC==:	6			; internal equate (== form)
	LXI	H,AAA
	CALL	BBB
	.END
