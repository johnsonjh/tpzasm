; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/newkw.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; Coverage for the keyword set Mark Ogden documented: the Z80 register-I/O and
; block-I/O instructions, the parity-as-overflow jump/call/return aliases, the
; .RAD40 radix-40 data directive, the .SYN synonym family, .EXIT/.IF1/.IF2, and
; the six-character-truncated directive spellings.  Object output is verified
; byte-for-byte against PSA PASM 1.02 (orig/pasm.com) via tools/vrel.sh.
;
; .DATE/.TIME are intentionally excluded here: their bytes depend on the clock
; (or SOURCE_DATE_EPOCH), so they are exercised separately, not in the golden.

	.PABS
	.LOC	100H

; ---- Z80 register I/O via (C): INP r / OUTP r (ED 40|r<<3 / ED 41|r<<3) ----
	INP	B
	INP	C
	INP	D
	INP	E
	INP	H
	INP	L
	INP	M
	INP	A
	OUTP	B
	OUTP	C
	OUTP	D
	OUTP	E
	OUTP	H
	OUTP	L
	OUTP	M
	OUTP	A

; ---- block I/O (ED-prefixed) ----
	INI
	INIR
	IND
	INDR
	OUTI
	OUTIR
	OUTD
	OUTDR

; ---- parity flag read as overflow: aliases of the JPO/JPE/.. opcodes ----
	JO	1234H
	JNO	5678H
	CO	9ABCH
	CNO	0DEF0H
	RO
	RNO

; ---- .RAD40 radix-40 packed symbols (4 bytes each) ----
	.RAD40	A
	.RAD40	Z
	.RAD40	ABCDEF
	.RAD40	HELLO,WORLD
	.RAD40	A$,B%,C.

; ---- .SYN synonym family (treated as .OPSYN), .EXIT, .IF1/.IF2 ----
	.SYN	.BYTE,EMIT
	EMIT	0AAH
	.DEFINE	EXTST =
	[.BYTE	0BBH
	.EXIT
	.BYTE	0CCH]
	EXTST
	.IF1	,[
	.BYTE	011H
	]
	.IF2	,[
	.BYTE	022H
	]

; ---- six-character-truncated directive spellings ----
	.DEFIN	TRUNC[X] =
	[.BYTE	X]
	TRUNC	033H
	.IFNDE	NOPE, [
	.BYTE	044H
	]
	.END
