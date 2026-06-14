	.PABS
	.LOC	100H
;
;	A conditional directive (.IFx) that carries a LABEL lists with the
;	label's address in the LOC column -- like any labeled line -- even
;	though a label-less conditional lists with a blank LOC column.  This
;	holds whether the condition is taken or not (the label is defined at
;	the current LC regardless).  (VEDIT: `NEXTLF: IF POLLING, [...'.)
;
START:	NOP
T1:	.IFE	0,[		;labeled, taken -> T1's LC shown
	NOP
	]
	NOP
F1:	.IFE	1,[		;labeled, NOT taken -> F1's LC shown
	NOP
	]
	NOP
	.IFE	0,[		;label-less -> blank LOC
	NOP
	]
	.END
