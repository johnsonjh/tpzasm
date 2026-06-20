; PASM 2.00G `.ZOP' standard Zilog Z80 + `.EPOP' Intel/M80 dialect sweep.
; Exercises the full documented Zilog mnemonic set (the LD matrix, ALU r/n/
; (HL)/(IX+d), 16-bit arithmetic, INC/DEC, PUSH/POP incl. AF and IX/IY, EX/EXX,
; the CB rotates/shifts and BIT/SET/RES, every ED block op, IM/RST/IN/OUT, and
; the conditional/unconditional JP/JR/CALL/RET + DJNZ) onto the canonical Z80
; encodings.  Byte-exact OBJECT vs orig/pasm2.com (only pasm2.com builds it;
; pasm.com 1.02 / zasm.com 2.21 reject the Zilog set and Intel pseudo-ops).
	.EPOP
	.ZOP
	.PABS
	.PHEX
	.XLINK
	ASEG
	ORG	100H
; --- 8-bit loads ---
	LD	A,B
	LD	C,(HL)
	LD	(HL),E
	LD	A,(IX+5)
	LD	(IY-3),D
	LD	B,42
	LD	(HL),99
	LD	(IX+1),7
	LD	A,(BC)
	LD	A,(DE)
	LD	(BC),A
	LD	(DE),A
	LD	A,(1234H)
	LD	(5678H),A
	LD	A,I
	LD	A,R
	LD	I,A
	LD	R,A
; --- 16-bit loads ---
	LD	BC,1234H
	LD	DE,5678H
	LD	HL,9ABCH
	LD	SP,0DEF0H
	LD	IX,1111H
	LD	IY,2222H
	LD	HL,(3000H)
	LD	BC,(3002H)
	LD	DE,(3004H)
	LD	SP,(3006H)
	LD	IX,(3008H)
	LD	IY,(300AH)
	LD	(4000H),HL
	LD	(4002H),BC
	LD	(4004H),DE
	LD	(4006H),SP
	LD	(4008H),IX
	LD	(400AH),IY
	LD	SP,HL
	LD	SP,IX
	LD	SP,IY
; --- ALU A,r/n/(HL)/(IX+d) ---
	ADD	A,B
	ADD	A,(HL)
	ADD	A,(IX+2)
	ADD	A,55
	ADC	A,C
	ADC	A,99
	SUB	D
	SUB	(HL)
	SUB	(IY+4)
	SUB	7
	SBC	A,E
	SBC	A,(HL)
	AND	H
	AND	0FH
	OR	L
	OR	80H
	XOR	A
	XOR	55H
	CP	B
	CP	(HL)
	CP	0FFH
; --- 16-bit arith ---
	ADD	HL,BC
	ADD	HL,DE
	ADD	HL,HL
	ADD	HL,SP
	ADD	IX,BC
	ADD	IX,IX
	ADD	IY,SP
	ADC	HL,BC
	ADC	HL,SP
	SBC	HL,DE
	SBC	HL,HL
; --- INC/DEC ---
	INC	A
	INC	(HL)
	INC	(IX+3)
	INC	BC
	INC	IX
	DEC	E
	DEC	(HL)
	DEC	(IY-1)
	DEC	HL
	DEC	IY
; --- stack ---
	PUSH	BC
	PUSH	DE
	PUSH	HL
	PUSH	AF
	PUSH	IX
	PUSH	IY
	POP	BC
	POP	AF
	POP	IY
; --- exchange ---
	EX	DE,HL
	EX	AF,AF'
	EX	(SP),HL
	EX	(SP),IX
	EX	(SP),IY
	EXX
; --- rotates/shifts (accumulator + CB) ---
	RLCA
	RRCA
	RLA
	RRA
	RLC	B
	RLC	(HL)
	RLC	(IX+0)
	RRC	C
	RL	D
	RR	E
	SLA	H
	SRA	L
	SRL	A
	SRL	(IY+2)
; --- bit ops ---
	BIT	0,B
	BIT	7,(HL)
	BIT	3,(IX+1)
	SET	1,C
	SET	5,(IY-2)
	RES	2,D
	RES	6,(HL)
; --- block ops ---
	LDI
	LDIR
	LDD
	LDDR
	CPI
	CPIR
	CPD
	CPDR
	INI
	INIR
	IND
	INDR
	OUTI
	OTIR
	OUTD
	OTDR
; --- misc ED ---
	NEG
	IM	0
	IM	1
	IM	2
	RETI
	RETN
	RLD
	RRD
; --- accumulator/flag ops ---
	DAA
	CPL
	CCF
	SCF
	NOP
	HALT
	DI
	EI
; --- I/O ---
	IN	A,(80H)
	IN	B,(C)
	OUT	(81H),A
	OUT	(C),D
; --- RST ---
	RST	0
	RST	8
	RST	10H
	RST	38H
; --- jumps/calls/returns ---
TGT:	JP	TGT
	JP	NZ,TGT
	JP	Z,TGT
	JP	C,TGT
	JP	PE,TGT
	JP	M,TGT
	JP	(HL)
	JP	(IX)
	JP	(IY)
	CALL	TGT
	CALL	NC,TGT
	CALL	PO,TGT
	RET
	RET	Z
	RET	NC
	JR	TGT
	JR	NZ,TGT
	JR	C,TGT
	DJNZ	TGT
	.END
