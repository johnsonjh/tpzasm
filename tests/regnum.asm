	.RADIX	10
; Registers-as-numbers and the index-addressing quirks that Mark Ogden
; identified in TDL ZASM (and which carried over to PSA PASM) during his
; disassembly work.  Every line here is byte-exact against BOTH originals in
; BOTH dialects (object via tools/vrel.sh + tests/golden, listing via
; tests/test_listing.sh).
;
;   1) a register operand may be written as a NUMBER: MOV 1,2 == MOV C,D,
;      because the register letters B C D E H L M A are predefined values
;      0..7 and the register field is just an expression (low three bits).
;   2) the index form d(reg) recognizes X (IX, prefix DD) and Y (IY, prefix
;      FD); it ALSO accepts H, intended to mean M (the HL pointer), but the
;      code emits a 0 prefix byte + a displacement byte -- so INR 0(H) is the
;      three bytes 00 34 00 rather than the one byte 34 of INR M.
;   3) because the displacement is an expression too, a register name used as
;      a displacement is its value: INR B(X) == INR 0(X), INR C(X) == INR 1(X).

; --- 1) registers written as numbers --------------------------------------
	MOV	C,D		; 4A  (reference)
	MOV	1,2		; 4A  == MOV C,D
	MOV	0,7		; 47  == MOV B,A
	MOV	7,0		; 78  == MOV A,B
	MVI	1,55H		; 0E 55  == MVI C,55H
	INR	1		; 0C  == INR C
	DCR	6		; 35  == DCR M
	ADD	2		; 82  == ADD D
	RLCR	1		; CB 01  == RLCR C
	INP	1		; ED 48  == INP C

; --- 2) the d(H) == M index bug -------------------------------------------
	INR	M		; 34  INC (HL), the intended meaning
	INR	0(H)		; 00 34 00  the bug: a 0 prefix + 0 displacement
	DCR	0(H)		; 00 35 00
	MOV	A,0(H)		; 00 7E 00
	INR	5(X)		; DD 34 05  a genuine index (IX+5)
	INR	5(Y)		; FD 34 05  a genuine index (IY+5)

; --- 3) a register / expression as the index displacement -----------------
	INR	0(X)		; DD 34 00  (reference)
	INR	B(X)		; DD 34 00  == INR 0(X)  (B == 0)
	INR	C(X)		; DD 34 01  == INR 1(X)  (C == 1)
	INR	M(X)		; DD 34 06  == INR 6(X)  (M == 6)
	INR	(X)		; 24  == INR H: bare (X) is the expression X (== 4)

; --- the register letters are ordinary expression values ------------------
	.WORD	B,C,D,E,H,L,M,A	; 0 1 2 3 4 5 6 7

; --- bug-compatible error recovery: flagged, but the bytes still match -----
	INR	0(B)		; XQ  bad index register -> 00 34 00 (prefix 0)
	INR	0(SP)		; XQ  bad index register -> 00 34 00
	MOV	8,0		; Q   value > 7 -> masked to 0: 40 == MOV B,B
	.END
