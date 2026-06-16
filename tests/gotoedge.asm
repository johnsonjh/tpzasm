	.TITLE	"GOTO edge and error cases"
	.PABS
	.LOC	100H
;
;	forward branch: .GOTO skips over the FFH, emitting AAH only
;
	.DEFINE	FWD[]=[
	.GOTO	SK
	.BYTE	0FFH
SK>
	.BYTE	0AAH
]
	FWD
;
;	duplicate labels: the search finds the FIRST `DL>'
;
	.DEFINE	DUP[N]=[
J=0
DL>
	.BYTE	1
DL>
	.BYTE	2
J=J+1
	.IFL	J-N,.GOTO DL
]
	DUP	2
;
;	the label match is case-insensitive (.GOTO lc -> LC>)
;
	.DEFINE	CASE[]=[
	.GOTO	lc
	.BYTE	33H
LC>
	.BYTE	44H
]
	CASE
;
;	error: undefined label is `U', the branch is abandoned
;
	.DEFINE	UND[]=[
	.BYTE	11H
	.GOTO	NOPE
	.BYTE	22H
]
	UND
;
;	error: a missing operand is `Q'
;
	.DEFINE	MISS[]=[
ML>
	.GOTO
	.BYTE	55H
]
	MISS
;
;	error: .GOTO outside any macro is `QQ'
;
	.GOTO	FOO
	.BYTE	77H
	.END
