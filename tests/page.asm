	.PABS
	.LOC	100H
;
;	.PAGE ejects to the top of the next listing page in BOTH dialects (the
;	directive line is suppressed; the form-feed + re-header are normalized
;	away).  ZASM `.PAGE' takes NO operand: an operand is a `Q' error -- the
;	line lists with the `Q' code and a `?' at the operand, then the page
;	ejects.  PASM reads the operand as the page geometry (`.PAGE
;	width[,length]'): the line is suppressed and does NOT eject.  The length
;	(the operand after the comma) sets the lines per page; the width (the
;	first operand) is accepted but not yet honored (no width->wrap yet).
;
	NOP
	.PAGE			;bare: eject (both dialects)
	NOP
	.PAGE	60		;one operand  -- ZASM: `Q'; PASM: width (suppressed)
	NOP
	.PAGE	79,40		;two operands -- ZASM: `Q'; PASM: width,length
	NOP
	.END
