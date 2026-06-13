; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/limage.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; .LIMAGE multi-line byte image: list EVERY byte of a data statement (six per
; line; one word per line for .WORD under PASM), splitting the source across
; the physical lines with a `\` continuation marker.  .XIMAGE returns to the
; normal capped display.  The object output is unaffected by the listing mode.
	.LIMAGE
	.BYTE	1,2,3,4,5,6,7,8,9,10,11,12,13,14
	.WORD	100H,200H,300H,400H,500H
	.ASCII	/ABCDEFGHIJKLMN/
	.XIMAGE
	.BYTE	21,22,23,24,25,26,27,28
	.END
