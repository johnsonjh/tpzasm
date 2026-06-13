; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/laddr.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; .LADDR lists a 16-bit value in LOAD (memory) order rather than as the value
; (.XADDR, the default): a 16-bit instruction operand is packed onto the opcode
; in the order its bytes occupy memory -- "CALL SUB" with SUB at 010F lists
; "CD0F01", not "CD 010F".  (VEDIT-PLUS builds with .LADDR throughout; the
; standalone corpus is otherwise .XADDR, so this is the only .LADDR coverage.)
; The directive is listing-only; the emitted object is unchanged, and it is
; byte-for-byte identical on both dialects.

	.PABS
	.LADDR
	.LOC	100H
START:	CALL	SUB		; CD0F01  (SUB = 010F, memory order 0F 01)
	JMP	START		; C30001
	LXI	H,START		; 210001
	LDA	SUB		; 3A0F01
	SHLD	START		; 220001
SUB:	RET
	.END
