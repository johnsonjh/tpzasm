	.radix	16
;
;	.SALL collapse is BYPASSED under .XLIST: with body listing off the
;	per-macro collapse call line is not emitted, so a force-listed bad
;	body statement renders through the ordinary fold path, as the
;	originals do -- a non-first body line as a '+' continuation, a first
;	body line folded inline onto the call line.  (DUP is multiply-defined,
;	so both macro bodies reference a bad symbol.)
;
	.SALL
	.DEFINE	MVIB$[X,Y] = [MVI	A,Y
	STA	X]
	.DEFINE	BEQ$[X] = [JZ	X]
	.LOC	100H
DUP	=	200H
DUP:	NOP
	.XLIST
	MVIB$	DUP,0
	BEQ$	DUP
	.LIST
	.END
