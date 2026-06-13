; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/ifbnb.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; The blank-argument conditionals .IFB (true if the argument is blank) and
; .IFNB (true if non-blank) -- the last two of the 14 conditional forms -- each
; with both branches taken.  Emits 01 02 03 04, never the else byte 0FFH.
;
; DIALECT NOTE: assembled with -p (PSA PASM), which handles .IFB/.IFNB cleanly.
; TDL ZASM 2.21's .IFB/.IFNB are buggy -- zasm.com mis-evaluates .IFB X / .IFNB
; X (and aborts outright on some single-line forms) -- so they cannot be
; differentially verified against the ZASM oracle.  The clone gives the sane
; (PASM) result on both dialects rather than reproducing ZASM's defect.

	.IFB	, [		; blank     -> true  -> 01
	.BYTE	1
	] [
	.BYTE	0FFH
	]
	.IFB	X, [		; non-blank -> false -> else 02
	.BYTE	0FFH
	] [
	.BYTE	2
	]
	.IFNB	X, [		; non-blank -> true  -> 03
	.BYTE	3
	]
	.IFNB	, [		; blank     -> false -> else 04
	.BYTE	0FFH
	] [
	.BYTE	4
	]
	.END
