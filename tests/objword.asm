; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/objword.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; Object-output regression: relocatable data that crosses the originals'
; 24-byte record boundary and exercises the relocation control-byte encoding.
; 14 relocatable .WORDs (28 bytes) force a record split mid-run; the 7 absolute
; bytes then leave a single relocatable .WORD straddling a control-byte
; boundary, and the trailing JMP carries a relocatable 16-bit operand.
	.RADIX	16
TBL:	.WORD	TBL,TBL,TBL,TBL,TBL,TBL,TBL,TBL
	.WORD	TBL,TBL,TBL,TBL,TBL,TBL
	.BYTE	1,2,3,4,5,6,7
LAST:	.WORD	LAST
	JMP	TBL
	.END
