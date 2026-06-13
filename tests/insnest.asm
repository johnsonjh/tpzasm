; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/insnest.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; .INSERT allows only ONE level: insnest inserts insnsub, which itself tries to
; .INSERT isub -- a nested .INSERT, which is an "F" error and is NOT performed.
; So isub (022H,033H) is skipped; insnsub emits 044H and the top level 0FFH ->
; object is 44 FF.  (PASM golden; ZASM adds a "Q" to the "F" -- a listing-only
; difference -- but the emitted object is identical.)

	.INSERT	insnsub
	.BYTE	0FFH
	.END
