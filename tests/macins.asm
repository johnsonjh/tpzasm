	.radix	16
	.define	MVIB$[X,Y] = [MVI	A,Y
	STA	X]
	.loc	100h
	.insert	MACINSUB
	.end
