; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/cond2.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; The signed-comparison and symbol-test conditionals beyond IF/IFNOT, each with
; both its true branch and its else branch taken: .IFG / .IFGE / .IFL / .IFLE
; (compared against zero, signed -- -1 == 0FFFFH counts as < 0) and the symbol
; tests .IFDEF / .IFNDEF.  The taken branches emit 01..08 in order; the else
; byte 0FFH must never appear.  Identical on both dialects.
; (The blank-argument tests .IFB / .IFNB are macro-argument conditionals and
; are exercised inside a macro in tests/macarg.asm, not here.)

	.RADIX	16
POS	=	5
NEG	=	-1
ZERO	=	0
DEFD	=	1
	.IFG	POS, [		; 5 > 0  -> true
	.BYTE	1
	]
	.IFG	ZERO, [		; 0 > 0  -> false (else)
	.BYTE	0FFH
	] [
	.BYTE	2
	]
	.IFGE	ZERO, [		; 0 >= 0 -> true
	.BYTE	3
	]
	.IFL	NEG, [		; -1 < 0 -> true (signed)
	.BYTE	4
	]
	.IFL	POS, [		; 5 < 0  -> false (else)
	.BYTE	0FFH
	] [
	.BYTE	5
	]
	.IFLE	ZERO, [		; 0 <= 0 -> true
	.BYTE	6
	]
	.IFDEF	DEFD, [		; defined -> true
	.BYTE	7
	]
	.IFNDEF	NOTDEF, [	; undefined -> true
	.BYTE	8
	]
	.END
