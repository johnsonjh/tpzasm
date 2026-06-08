	.RADIX	16
	.OPSYN	.IFN,IF			;IF means "if nonzero"
	.OPSYN	.IFE,IFNOT		;IFNOT means "if zero"
ONE	=	1
ZERO	=	0
	IF	ONE, [
	.BYTE	0AAH			;assembled (ONE nonzero)
	]
	IF	ZERO, [
	.BYTE	0BBH			;skipped
	]
	IFNOT	ZERO, [
	.BYTE	0CCH			;assembled (ZERO is zero)
	]
	.IFN	ONE-1, [
	.BYTE	0DDH			;skipped (ONE-1 == 0)
	] [
	.BYTE	0EEH			;assembled (else)
	]
	.IFE	ZERO, [
	.BYTE	011H			;assembled
	IF	ONE, [
	.BYTE	022H			;assembled (nested)
	]
	]
	.END
