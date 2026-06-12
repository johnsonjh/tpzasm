; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/datetime.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; .DATE / .TIME emit eight ASCII bytes each ("MM/DD/YY" and "HH:MM:SS").
; tests/test_datetime.sh pins SOURCE_DATE_EPOCH and checks the exact bytes;
; this source just places the two directives at a known absolute address.

	.PABS
	.LOC	100H
	.DATE
	.TIME
	.END
