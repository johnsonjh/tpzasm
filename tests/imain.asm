	.RADIX	16
	.OPSYN	.IFN,IF
FLAG	=	1
	.BYTE	011H
	.INSERT	isub		;-> 22 33
	.BYTE	044H
	IF	FLAG, [
	.INSERT	isub2		;-> 55  (FLAG true)
	]
	IF	FLAG-1, [
	.INSERT	isub2		;skipped (FLAG-1 == 0)
	]
	.END
