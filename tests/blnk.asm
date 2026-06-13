; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/blnk.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; .BLNK. blank-common segment: reservation plus a cross-base reference,
; exercising the :03 base flag and the .BLNK. segment size in the \\ record.

	.PREL
	.LOC	.BLNK.
CELL:	.BLKB	2
	.LOC	.PROG.
	.WORD	CELL
	.WORD	.BLNK.
	.END
