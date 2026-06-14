	.RADIX	16
	.PABS
	.LOC	100H
;
;	Macro call-line LC: an empty-body[0] macro (the `[' ends the .DEFINE
;	line) carries the expansion's start LC on its call line IFF the first
;	non-empty body statement DIRECTLY emits; it is blank when that statement
;	is a conditional/directive (the emit happens inside it).
;
	.DEFINE	LD16[R,S] = [
	.IFIDN	"R"  "D",  [
	LDED	S
	]
	]
	.DEFINE	SIMPLE[X] = [
	PUSH	H
	POP	H
	]
	.DEFINE	WDIR[V] = [
	.WORD	V
	NOP
	]
	.DEFINE	OUTER[X] = [
	PUSH	H
	LD16	D,X
	POP	H
	]
S1:	SIMPLE	1		;body[1]=PUSH H emits -> call line shows LC
	NOP
W1:	WDIR	1234H		;body[1]=.WORD emits -> call line shows LC
	NOP
L1:	LD16	D,5678H		;body[1]=.IFIDN (cond) -> call line blank
	NOP
O1:	OUTER	9ABCH		;empty body[0], body[1]=PUSH H, nested LD16
	.END
