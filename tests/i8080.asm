; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/i8080.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; .I8080 / .Z80 mode.  Under .I8080 the assembler still assembles a Z80
; instruction (the bytes are unchanged) but flags it with the "Z" warning
; (z80-in-8080); .Z80 (the default) allows the Z80 extensions silently.  Both a
; Z80 mnemonic (EXX, LDIR, BIT, INP, DADX, LIXD, DADC) and an index-register
; operand on an 8080 mnemonic (PUSH X) are Z80; a plain 8080 instruction (PUSH
; B, MOV, JMP) is not.  This fixture pins the object output (the warning does
; not change the emitted bytes); the "Z" listing flag is verified against the
; originals separately.

	.I8080
	EXX			; Z (Z80, shares 8080 no-operand form)
	EXAF			; Z
	LDIR			; Z
	BIT	0,A		; Z
	INP	A		; Z
	DADX	B		; Z
	LIXD	100H		; Z
	PUSH	X		; Z (index operand on an 8080 mnemonic)
	PUSH	B		; no warning (8080)
	DADC	B		; Z
	MOV	A,B		; no warning (8080)
	JMP	0		; no warning (8080)
	.Z80
	LDIR			; no warning (.Z80 mode)
	.END
