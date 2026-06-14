.TITLE	"PABS relocation-mode audit"
.I8080
.PABS
.PHEX
;
; under .PABS the location counter is still RELOCATABLE (.PROG.) until a
; .LOC sets an absolute origin -- .PABS only selects absolute OBJECT output
	.LOC	1000H		; absolute origin
	NOP
	NOP
	.RELOC			; restore the relocatable .PROG. position
	.LOC	2000H		; absolute again
	MVI	A,5
	.RELOC
	.LOC	3000H
	JMP	0
	.END
