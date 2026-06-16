	.TITLE	"GOTO macro-branch test"
	.PABS
	.LOC	100H
;
;	.GOTO mlabel branches within a macro to a macro label (`mlabel>').
;	With a single-line conditional it forms a counted loop -- here the
;	body is emitted ARG3 times (the classic TDL/PSA REPT idiom).
;
	.DEFINE	RPT[ARG1,ARG2,ARG3]=[
I=0
MLABEL>
	.WORD	ARG1
	.BYTE	ARG2
I=I+1
	.IFL	I-ARG3,.GOTO MLABEL
]
	RPT	1234H,56H,3
	.END
