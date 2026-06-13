; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/dinsert.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; .INSERT with a drive specifier: "A:" is accepted but ignored (the file is
; resolved on the source disk).  .INSERT also defaults the .ASM extension.
; Inserts isub.asm (.BYTE 022H,033H), then emits 0FFH -> 22 33 FF.

	.INSERT	A:isub
	.BYTE	0FFH
	.END
