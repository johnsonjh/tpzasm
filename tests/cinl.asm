; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/cinl.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; Single-line inline conditional blocks: "...IFx cond,[stmt][else]" with the
; taken branch's (single) statement on the SAME line as the directive -- as
; opposed to the multi-line form ("[" at end of line, body on the following
; lines, then "]" / "] ["), which the clone already handled.  A taken branch's
; statement assembles inline and its bytes list on the directive's own line;
; an untaken branch with no else emits nothing (blank LC).  The block holds ONE
; statement (more is the "Q" extra-operand case).  Inline and multi-line forms
; nest freely.  Byte-for-byte identical on both dialects.
;
; Object: 00 04 00 14 09 3E 07 1C FF (NOP / else INR B / NOP / INR D / .BYTE 9
; / MVI A,7 / INR E / .BYTE 0FFH); the false/no-else and skipped lines emit
; nothing.

	.IFE	0,[NOP]		; true        -> NOP      (00)
	.IFE	1,[NOP]		; false, none -> (nothing)
	.IFE	1,[NOP][INR B]	; false       -> else INR B (04)
	.IFE	0,[NOP][INR B]	; true        -> NOP      (00)
	.IFN	0,[INR C]	; .IFN 0 false -> (nothing)
	.IFN	5,[INR D]	; .IFN 5 true  -> INR D   (14)
	.IFE	0,[.BYTE 9]	; data-directive body     (09)
	.IFG	5,[MVI A,7]	; two-byte body           (3E 07)
	.IFE	0,[		; multi-line block, with an inline conditional
	.IFE	0,[INR E]	;   nested inside it (assembled -> INR E 1C)
	]
	.IFE	1,[		; skipped multi-line block: the inline
	.IFE	0,[INR H]	;   conditional inside is NOT assembled
	]
	.BYTE	0FFH
	.END
