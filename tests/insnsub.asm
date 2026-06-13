; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/insnsub.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; Inserted by tests/insnest.asm; its own .INSERT is the nested (illegal) one.

	.INSERT	isub
	.BYTE	044H
