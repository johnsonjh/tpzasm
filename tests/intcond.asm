; PASM 2.00G .EPOP Intel/M80 pseudo-ops: TITLE/SUBTTL/PAGE page headings and
; the IF/IFT/IFE/IFF/COND + ELSE + ENDIF/ENDC conditionals.  Unlike the TDL
; bracket conditionals these carry NO `[...]' block -- the frame stays open
; until ENDIF/ENDC, and `IF 0' skips its body.  NOT .XLINK (and NOP-padded):
; pasm2's .XLINK object writer drops content past the first 128-byte record
; for mid-sized objects -- a pasm2 bug, see docs/re/pasm2-bugs.md.
	.EPOP
	.ZOP
	.PABS
	.PHEX
	ASEG
	ORG	100H
	TITLE	'intel conditional test'
	SUBTTL	'IF / ELSE / ENDIF / COND'
	PAGE	96,84
	LD	A,1
	IF	1
	LD	A,2		; assembled
	ENDIF
	IF	0
	LD	A,3		; skipped
	ENDIF
	IFE	0
	LD	B,4		; assembled (IFE 0 == true)
	ENDIF
	IFF	1
	LD	B,5		; skipped (IFF 1 == false)
	ENDIF
	IF	1
	LD	C,6		; assembled
	ELSE
	LD	C,7		; skipped
	ENDIF
	IF	0
	LD	D,8		; skipped
	ELSE
	LD	D,9		; assembled
	ENDIF
	COND	1
	LD	E,10
	ENDC
	IFT	5
	LD	H,11		; assembled (IFT nonzero == true)
	ENDIF
; nested conditionals
	IF	1
	IF	0
	LD	L,12		; skipped (inner false)
	ELSE
	LD	L,13		; assembled
	ENDIF
	ENDIF
; M80 data directives: DEFM (define message, like DB) and DEFS (define space)
	DEFM	"hello"
	DEFS	3
	DEFB	0AAH
	DEFW	1234H
; NOP padding (clears pasm2's small-object flush bug; not .XLINK here)
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	.END
