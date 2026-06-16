	.TITLE	"PROGID program-id record test"
	.PROGID	SPELL,1,1
	.PREL
;
;	.PROGID id,ver,rev fills the PASM `+' program-identification
;	object record: the 6-char id, an 8-bit version and revision.
;	ZASM omits the `+' record entirely, so this exercises PASM.
;
START:	LXI	H,MSG
	JMP	START
MSG:	.BYTE	"SPELL",CR,LF,0
CR	=	0DH
LF	=	0AH
	.END
