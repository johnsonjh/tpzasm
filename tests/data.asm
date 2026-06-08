	.RADIX	16		;hex radix for the rest of the file
COUNT	=	5
TBL:	.BYTE	1,2,3,COUNT	;-> 01 02 03 05
	.WORD	0FFH,1234H	;-> FF 00 34 12
ARR:	.BLKB	4		;reserve 4 bytes (LC 8..0B)
LAST:	.WORD	TBL		;-> 00 00 (TBL is relocatable, value 0)
	.END
