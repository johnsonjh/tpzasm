	.RADIX	16
;
;	.LALL (list-all) does NOT flatten a macro expansion: every nesting
;	level lists its own call line (invocation + body-open '[') and its
;	body-close ']', and every body line lists with a '+' marker -- EXCEPT
;	a ';;' double-semi comment, whose text the originals suppress (it
;	lists as a blank '+' line).  A single ';' comment lists verbatim.
;
	.LALL
	.DEFINE	INNER[] = [
	NOP
	]
	.DEFINE	OUTER[] = [
;;	this double-semi comment lists BLANK
	INNER
	RET
	]
	.DEFINE	A[] = [
	NOP
	]
	.DEFINE	B[] = [
	A
;	this single-semi comment lists verbatim
	INR	C
	]
	.DEFINE	C3[] = [
	B
	RET
	]
	.LOC	100H
	OUTER			;two-level nest + a ';;' comment
	C3			;three-level nest + a ';' comment
	.END
