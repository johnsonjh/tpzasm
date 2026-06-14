.TITLE	"conditional block + local + dollar-symbol audit"
.I8080
.PABS
.PHEX
	.LOC	100H
;
; symbols may start with '$' (an ordinary Radix-40 char, not the LC)
$delay	==	50H
$2ms	==	20H
	MVI	A,$delay
	MVI	B,$2ms
;
; multi-line conditional block: '[' opens, body ends 'stmt]' on a later line
	.IFE	0,[
	.BYTE	0AAH]
;
; a block whose CLOSE ']' sits after a comment still closes it
	.IFE	0,[.BYTE 0BBH
	.BYTE	0CCH ; trailing comment then close ]
	.BYTE	0DDH		; outside the block again
;
; the FIRST statement may share the .IFx line (leading stmt, body continues)
	.IFN	0,[.BYTE 0EEH
	.BYTE	0FFH]
;
; a skipped multi-line block must not swallow the block that follows it
	.IFE	1,[.BYTE 11H
	.BYTE	22H]
	.IFE	0,[.BYTE 33H
	.BYTE	44H]
;
; a '..local' EQUATE resolves in an expression, like a '..local:' label
..count	==	7
	MVI	C,80H-..count
	.WORD	..count]	; bracketed data + trailing close (no AA flag)
;
; a .ascii string whose close quote abuts an inline `]`: ZASM (zasm.com)
; drops its last char, PASM keeps it -- sources pad an extra char to suit ZASM
	.IFN	1,[.ASCII 'OK ']
	.BYTE	99H
	.END
