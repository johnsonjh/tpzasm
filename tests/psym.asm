; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/psym.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; .PSYM punches the program's global symbol table into the END of the object
; file -- the "&" record(s) the PSA BUG debugger reads -- as name(6) + base(1)
; + value(BE16), four symbols per record, AFTER the EOF record.  (.XPSYM, the
; default, emits none; .PSYM does NOT change the listing.)  The order is: the
; three segment bases (.PROG./.DATA./.BLNK., carrying their sizes), then the
; externals in relocation-base order, then the locally-defined symbols in
; first-definition order; ".." locals are excluded.  Byte-for-byte identical to
; both pasm.com and zasm.com.

	.PSYM
	.EXTERN	EXT1		; external -> in "&" with base >= 4, value 0
	.INTERN	INT1
ZED:	NOP			; defined globals, listed in DEFINITION order
ALF:	NOP			; (ZED before ALF -- not alphabetical)
INT1:	NOP			; an internal is still a defined global here
VAL	=	99H		; an absolute equate (base 0)
..LOC:	NOP			; a "." local -- EXCLUDED from the "&" record
	LXI	H,EXT1
	.END
