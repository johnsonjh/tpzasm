.TITLE	"quote-handling audit"
.SBTTL	'single and double and slash'
.I8080
.PABS
.PHEX
.XLINK
	.LOC	100H
;
; character constants in expressions: ' and " are interchangeable,
; and each can quote the other (CPI "'" / CPI '"')
	MVI	A,'A'
	MVI	A,"A"
	CPI	"'"
	CPI	'"'
	LXI	H,'AB'
	LXI	H,"AB"
;
; single-byte char items under each delimiter
	.BYTE	'A'
	.BYTE	"A"
	.BYTE	'A',"B",'C'
;
; .WORD char value, either quote
	.WORD	'AB'
	.WORD	"AB"
;
; .ASCII / .ASCIZ / .ASCIS strings under each delimiter
	.ASCII	'hello'
	.ASCII	"hello"
	.ASCII	/hello/
	.ASCIZ	"world"
	.ASCIS	'last'
;
; blank-argument conditional: '' and "" are both the empty string
	.IFB	'',[.BYTE 0AAH]
	.IFB	"",[.BYTE 0BBH]
	.END
