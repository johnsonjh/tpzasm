; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/xlink.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; .XLINK: emit a relocatable core image -- suppress every link record (the '!'
; module-id, '@' entry-point, '\' segment/external, '#' internal-symbol) and
; emit ONLY the ';' relocation/data records and the EOF.  Even though this
; module names itself (.IDENT), declares an external (.EXTERN), an entry
; (.ENTRY) and an internal (.INTERN) -- all of which would normally produce
; their own records -- under .XLINK the object is just the ';' data stream.

	.IDENT	XLMOD
	.EXTERN	EXTSUB
	.ENTRY	START
	.INTERN	HELPER
	.XLINK
	.PREL
START:	CALL	EXTSUB
	LXI	H,HELPER
HELPER:	RET
	.END
