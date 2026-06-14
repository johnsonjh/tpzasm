	.RADIX	16
	.PABS
	.LOC	100H
;
;	.SALL macro-collapse: the whole expansion lists as ONE bare call line
;	carrying the FIRST emitting statement's LC + value-form bytes (the rest
;	of the body is suppressed).  The first emitter may be deep in a nested
;	macro, and the value-form follows the statement kind.
;
	.SALL
	.DEFINE	LDEDM[S] = [
	XCHG
	LHLD	S
	XCHG
	]
	.DEFINE	LD16[R,S] = [
	.IFIDN	"R"  "D",  [
	LDEDM	S
	]
	]
	.DEFINE	M2[X] = [
	MVI	A,X
	NOP
	]
	.DEFINE	M3[X] = [
	LXI	H,X
	NOP
	]
	.DEFINE	MW[X] = [
	.WORD	X
	NOP
	]
	.DEFINE	NONE[X] = [
	.IFIDN	"X"  "ZZ",  [
	NOP
	]
	]
N1:	LD16	D,1234H		;nested: first byte EB (XCHG) deep in LDEDM
	LD16	D,5678H		;same, unlabeled
A1:	M2	5		;first stmt MVI A,X -> 3E05 value-form
A2:	M3	9ABCH		;first stmt LXI H,X -> 21 9ABC value-form
A3:	MW	0DEF0H		;first stmt .WORD X -> word value-form
E1:	NONE	ZZ		;labeled, expansion emits NOP -> call line LC + byte
	NONE	1		;unlabeled, expansion emits nothing -> blank
	.END
