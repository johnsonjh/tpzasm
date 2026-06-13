; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/macnest.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; Macro nesting (manual Ch.4): a macro may be DEFINED inside another macro.  The
; inner macro is not available until the outer macro has been called; once it
; has, the inner macro may be called by any statement.  Here OUTER emits its
; argument and defines INNER; after a single OUTER call, INNER is callable and
; adds 10H to its argument.  Emits 01 12 14.  Byte-for-byte identical on both
; dialects.  (Calling OUTER twice would redefine INNER -- a multiply-defined
; 'M' error -- so OUTER is called once.)

	.DEFINE	OUTER[V]=[
	.BYTE	V
	.DEFINE	INNER[W]=[.BYTE W+10H]
]
	OUTER	1		; -> 01, and defines INNER
	INNER	2		; -> 12  (INNER now callable)
	INNER	4		; -> 14
	.END
