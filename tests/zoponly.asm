; .ZOP without .EPOP: Zilog mnemonics with the TDL dotted pseudo-ops
	.PABS
	.PHEX
	.XLINK
	.ZOP
	.LOC	100H
START:	LD	A,5
	LD	HL,DATA
	LD	B,(HL)
	INC	HL
	CP	10H
	JR	NZ,START
	CALL	SUBR
	RET
SUBR:	PUSH	BC
	LD	C,A
	ADD	A,B
	POP	BC
	RET
DATA:	.BYTE	1,2,3
	.WORD	1234H
	.ASCII	"hi"
	.END
