; TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/shift.asm
; Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
; SPDX-License-Identifier: MIT-0
;
; Binary-shift operator regression (< left, > right).  The shift count is a
; 16-bit two's-complement value with two properties the manual documents and
; the originals enforce:
;   1. A magnitude of 16 or more shifts every bit out -> 0 (NOT a modulo-16
;      wrap of the count, which would alias 16->0-shift, 17->1, 32->0, etc.).
;   2. A NEGATIVE count (top bit set) reverses the shift direction; its
;      magnitude is the two's complement (so >-1 shifts the OTHER way by 1).
; The right shift is logical (no sign extension): 0FFFFH>1 = 7FFF.
;
; Each .WORD's value is the trailing column of the assembled listing.  Every
; value below was captured byte-exact from PSA PASM 1.02 (orig/pasm.com), TDL
; ZASM 2.21 (orig/zasm.com), AND PSA PASM 2.00G (orig/pasm2.com) under tnylpo;
; all three agree.  See tools/vrel.sh for the live differential.
	.PABS
	.LOC	100H
; -- left shift, positive count: magnitude >= 16 yields 0, not a wrap --
	.WORD	1<0		; 0001
	.WORD	1<1		; 0002
	.WORD	1<2		; 0004
	.WORD	1<14		; 4000
	.WORD	1<15		; 8000  last count with a surviving bit
	.WORD	1<16		; 0000  >=16 -> 0 (wrap would give 0001)
	.WORD	1<17		; 0000  (wrap would give 0002)
	.WORD	1<31		; 0000  (wrap would give 8000)
	.WORD	1<32		; 0000  (wrap would give 0001)
	.WORD	0FFFFH<4	; FFF0  truncated to 16 bits
; -- right shift, positive count: logical (no sign extension) --
	.WORD	8>1		; 0004
	.WORD	8000H>1		; 4000
	.WORD	0FFFFH>1	; 7FFF  logical (arithmetic would give FFFF)
	.WORD	8000H>15	; 0001
	.WORD	8000H>16	; 0000  >=16 -> 0
	.WORD	0FFFFH>16	; 0000  >=16 -> 0
	.WORD	0FFFFH>17	; 0000  >=16 -> 0
; -- negative count reverses direction (manual: 2>-1 == 1<2 == 4) --
	.WORD	2>-1		; 0004  -> 2<1
	.WORD	1<-1		; 0000  -> 1>1
	.WORD	8000H<-1	; 4000  -> 8000H>1
	.WORD	1>-1		; 0002  -> 1<1
	.WORD	1>-15		; 8000  -> 1<15
	.WORD	1>-16		; 0000  -> 1<16, magnitude 16 -> 0
	.WORD	8>-2		; 0020  -> 8<2
	.WORD	8000H<-15	; 0001  -> 8000H>15
	.WORD	8000H<-16	; 0000  -> 8000H>16, magnitude 16 -> 0
	.WORD	1<-16		; 0000  -> 1>16, magnitude 16 -> 0
	.WORD	1<-17		; 0000  -> 1>17, magnitude 17 -> 0
; -- magnitude is a full 16-bit count, not just the low byte --
	.WORD	1<100H		; 0000  count 256 -> 0 (not the low byte)
	.WORD	0FFFFH>100H	; 0000  count 256 -> 0
	.WORD	1<7FFFH		; 0000  largest positive count -> 0
	.WORD	1<8000H		; 0000  -32768: magnitude >=16
	.WORD	1>8000H		; 0000
	.WORD	1<-0FFFFH	; 0002  -0FFFFH == 0001 (positive) -> 1<1
	.END
