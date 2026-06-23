; titles.asm - TITLE/SBTTL drop <space, delimited format
	.RADIX 10
	.TITLE "A"		; short
	.SBTTL "SUB"
	.TITLE "ABC	DEF" ; drop -> ABCDEF
	.BYTE 0
	.END
