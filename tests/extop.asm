; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/extop.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; Extra (trailing) operands -- the per-format Appendix-C diagnostics, identical
; on both dialects.  A no-operand instruction with an operand, and an extra
; ",operand" in a list, are "Q" (questionable); a space-separated trailing
; number is "AQ" on an instruction and "AA" on a data directive; a
; space-separated trailing register is "A".  Each error places its own "?", so
; two errors at one spot render "??".  The valid leading operands still assemble
; (NOP=00, MVI A,5=3E05, JMP 1=C3 0001, INR B=04, .BYTE 1=01, .WORD 1,2=0001).

	NOP	X		; Q  -> NOP  ?X
	MVI	A,5,6		; Q  -> MVI  A,5?,6
	JMP	1 2		; AQ -> JMP  1 ??2
	INR	B C		; A  -> INR  B C?
	.BYTE	1 2		; AA -> .BYTE 1 ??2  (only 01 emitted)
	.WORD	1,2 3		; AA -> .WORD 1,2 ??3
	.END
