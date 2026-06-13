; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/temps.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; .TEMPS local temporary variables (PSA PASM, manual Ch.3/4): .TEMPS n allocates
; an n-element local array, referenced as "![sub]"; each element starts at
; absolute zero and may be assigned and read.  They are valid only inside a
; macro expansion.  Here the macro uses two temps as scratch arithmetic
; variables; it emits 05 06 0C.
;
; DIALECT NOTE: assembled with -p (PSA PASM).  .TEMPS/![sub] is a PASM feature;
; TDL ZASM 2.21 has no such facility (zasm.com flags .TEMPS as an unknown op and
; ![sub] as an error), so it cannot be differentially verified on ZASM.

	.DEFINE	SCRATCH=[
	.TEMPS	2
	![0]=5
	.BYTE	![0]		; -> 05
	![0]=![0]+1
	.BYTE	![0]		; -> 06
	![1]=![0]*2
	.BYTE	![1]		; -> 0C
]
	SCRATCH
	.END
