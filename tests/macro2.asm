	.RADIX	16
	.DEFINE	REPT[N,X] = [
	.IFN	N, [
	X
	REPT	\N-1,(X)
	]
	]
	REPT	3,(.BYTE 0AAH)
	.IFIDN	"B" "B", [
	.BYTE	011H
	]
	.IFDIF	"B" "C", [
	.BYTE	022H
	]
	.END
