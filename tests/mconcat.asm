; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/mconcat.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; Macro argument concatenation with the apostrophe/single-quote operator (manual
; Ch.4): inside a macro definition, "'" joins a dummy argument with adjacent
; text to form a single symbol.  The manual's own example -- a conditional-
; branch macro -- builds the Z80 relative-jump mnemonic from its condition arg:
;   .DEFINE BR[A,B]=[JR'A B]   then   BR Z,L1  ->  JRZ L1
; Here A is pasted onto JR to form JRZ / JRNZ / JRC.  Byte-for-byte identical on
; both dialects (JRZ=28, JRNZ=20, JRC=38, + the relative displacement).

	.DEFINE	BR[A,B]=[JR'A B]
	BR	Z,L1		; -> JRZ  L1
	BR	NZ,L1		; -> JRNZ L1
	BR	C,L1		; -> JRC  L1
L1:	NOP
	.END
