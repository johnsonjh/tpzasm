; PASM 2.00G .ZOP/.EPOP macros: pasm2 has NO M80 MACRO/ENDM -- only the TDL
; .DEFINE mechanism -- so this exercises .DEFINE bodies built from Zilog
; mnemonics (verified: pasm2.com and the clone both reject MACRO/ENDM as `O').
	.EPOP
	.ZOP
	.PABS
	.PHEX
	.XLINK
	ASEG
	ORG	100H
	.DEFINE	LDPR[R,V]=[
	LD	R,V
]
	.DEFINE	SAVE=[
	PUSH	AF
	PUSH	BC
	PUSH	DE
	PUSH	HL
]
	.DEFINE	ADDN[N]=[
	ADD	A,N
]
START:	LDPR	HL,1234H
	LDPR	BC,5678H
	LDPR	SP,0FF00H
	SAVE
	ADDN	5
	ADDN	10H
	LDPR	IX,0BEEFH
	.END
