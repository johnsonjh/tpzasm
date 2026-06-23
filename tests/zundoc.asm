; Test undocumented XH/XL/YH/YL (IXH/IXL/IYH/IYL) in .ZOP mode.
; Built specially with: asm -g -L -a '.ZOP' -a '.EPOP'
	.EPOP
	.ZOP
	.PABS
	.PHEX
	.XLINK
	ASEG
	ORG	100H
; --- X/IX variants (DD prefix) ---
	LD	A,XH
	LD	A,IXH
	LD	B,XL
	LD	B,IXL
	LD	XH,C
	LD	IXH,D
	LD	XL,E
	LD	A,42
	LD	XH,A
	LD	A,XL
	ADD	A,XH
	ADD	A,IXL
	SUB	XL
	INC	XH
	DEC	IXL
; --- Y/IY variants (FD prefix) ---
	LD	A,YH
	LD	A,IYH
	LD	C,YL
	LD	C,IYL
	LD	YH,B
	LD	IYH,E
	LD	YL,D
	LD	A,99H
	LD	YH,A
	LD	A,YL
	ADD	A,YH
	ADD	A,IYL
	SUB	YL
	INC	YH
	DEC	IYL
	.END
