	.TITLE	'SMOKE'
;
; Minimal smoke test for the oracle harness (TDL/PSA dialect).
; Relocatable by default (.PREL); the .WORD reference to START forces a
; relocation entry, so the object output exercises real relocation.
;
FIVE	=	5
START:	MVI	A,FIVE
	LXI	H,MSG
	JMP	START
MSG:	.ASCII	'HI'
	.WORD	START
	.END
