	.RADIX	16
; Z80 index addressing d(X)/d(Y) + index register ops
	MOV	A,5(X)
	MOV	5(X),A
	MOV	B,3(Y)
	MOV	7(Y),C
	MVI	5(X),0AAH
	ADD	5(X)
	SUB	2(Y)
	ANA	0(X)
	CMP	1(Y)
	INR	5(Y)
	DCR	0(X)
	PCIX
	PCIY
	SPIX
	SPIY
	XTIX
	XTIY
	DADX	B
	DADX	X
	DADY	D
	DADY	SP
	.END
