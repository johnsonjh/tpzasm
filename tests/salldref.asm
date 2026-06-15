	.radix	16
	.define	MVIB$[X,Y] = [MVI	A,Y
	STA	X]
	.sall
	.loc	100h
DUP	=	200h
DUP:	nop
	MVIB$	DUP,0
	.end
