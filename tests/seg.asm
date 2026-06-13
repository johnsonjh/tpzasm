; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/seg.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; Multi-segment object: .PROG. code referencing .DATA. data and back,
; exercising the cross-base 110 control code and the per-segment record base.

	.PREL
START:	LXI	H,BUF
	MOV	A,M
	RET
	.LOC	.DATA.
BUF:	.BLKB	4
PTR:	.WORD	START
	.LOC	.PROG.
	.WORD	BUF
	.WORD	.DATA.
	.END
