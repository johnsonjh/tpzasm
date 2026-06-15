; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/macparam.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; Memory-hygiene fixture for .DEFINE parameter parsing (not an object/listing
; parity fixture).  It drives the do_define() dummy-list paths that the macro
; engine stores with malloc'd strings, including the ones a naive commit order
; leaks: an empty parameter slot (the leading comma below), parameters past the
; 7-dummy cap (P8/P9/PA overrun the kept slots), and PARAM()/PARAM(x) defaults.
; Run under valgrind / LeakSanitizer (see .lint.sh) it must report no leaks.
	.PABS
	.LOC	100H
	.DEFINE	BIG[P1,P2,P3(),P4(9),P5,P6,P7,P8,P9,PA] [
	NOP
	]
	.DEFINE	GAP[,Q1,] [
	NOP
	]
	BIG
	GAP
	.END
