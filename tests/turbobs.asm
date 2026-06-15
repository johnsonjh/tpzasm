	.title	"High Bios For Turbo-ROM"
	.sbttl	"Macros and Constants"
	.setwid	120


	.phex
	.xlink

;******************************************************
;	UNIVERSAL HIGH-BIOS FOR TURBO ROM
;
;	Copyright 1985 (c), Plu*Perfect Systems
;		    P.O. Box 1494
;             Idyllwild, California 92349
;
;******************************************************

	.remark	"
This code is provided for the use of owners of the
Advent Products Turbo ROM (Kaypro versions).  It
relies heavily on the presence of the Turbo ROM
and will not work without it"

;**********************************************
;fill memory up to address with nulls
	.define	PADBYT[addr]=[
	.ifg	(addr - .),[
	nop
	PADBYT	addr
	]
	]


	.define	XENTRY[name]=[
;;Macro to generate ROM entry points
xcount	=	xcount+3
name	=	xcount
	]


;Define ROM entry points 
xcount	=	0
xstart	==	xcount		;Restart Computer
	.slist
	.sall
	XENTRY	xdskrst		;(de-activate HOST buffer)
	XENTRY	xcrtnit		;initialise video driver
	XENTRY	xdevnit		;(initialise unit record hardware)
	XENTRY	xhome		;(de-activate HOST buffer only if not written)
	XENTRY	xseldsk		;Select disk for next access
	XENTRY	xsettrk		;Set track for next disk access
	XENTRY	xsetsec		;Set sector for next disk access
	XENTRY	xsetdma		;Set DMA Address for next disk access
	XENTRY	xread		;Read Sector
	XENTRY	xwrite		;Write Sector
	XENTRY	xsctrn		;Sector Translation (Dummy)
	XENTRY	xdskon		;Trun on Floppy motors
	XENTRY	xdskoff		;Turn off/deselect drives and flush deblocking
	XENTRY	xcrtsta		;Standard Keyboard input status
	XENTRY	xcrtin		;Standard Keyboard input
	XENTRY	xkbdout		;Keyboard Serial output (Use with Caution)
	XENTRY	xttysta		;TTY input status
	XENTRY	xttyin		;get char from TTY
	XENTRY	xttyout		;send (C) to TTY
	XENTRY	xlptsta		;Centronics output status
	XENTRY	xlptout		;send (C) to Centronics
	XENTRY	xttosta		;TTY output status
	XENTRY	xcrtout		;send (C) to video screen
	XENTRY	xtmsec		;delay (A) ten millseconds
	XENTRY	xul1sta		;User List input status
	XENTRY	xul1in		;User List input
	XENTRY	xul1out		;User List output
	XENTRY	xul1ost		;User List output status
	XENTRY	xldsys		;reload system
	XENTRY	xgetscr		;return next screen char
	XENTRY	xdefcur		;set cursor to (A)
	XENTRY	xmsec		;delay (A) msec
	.rlist

sioAcommand	=	06H	;TTY command port
sioBcommand	=	07H	;Keyboard command port
sioBstatus	=	07H	;keyboard status port
sioBdata	=	05H	;Keyboard data
sioCcommand	=	0EH	;UL1 command port

bauda		=	0	;tty baud rate
baudb		=	8	;serial printer (84 only)

topmem		=	0
romid		=	topmem - 8	;start of ROM identifing sequence
vecptr		=	topmem - 16	;pointer to base of interrupt vectors
hrdptr		=	topmem - 20	;pointer to winchester parameters

beldly		=	40		;delay before sending bell to keyboard
CR		=	0DH
LF		=	0AH

	.sbttl	"Load Parameter Sector (Config. Tables)"
	.page
;**********************************************
;load parameter sector	(standard Kaypro)
;This sector is loaded by the Turbo Rom into the
;CP/M directory buffer where it remains through the
;cold boot.  It also contains the configuration information.
;************************************************

syssiz	=\	"Enter System Size (K) - (0 generates relocatable version)"

	.ifg	syssiz,[
	.pabs
	.loc	(syssiz*2 - 3)*512 - 1600H - 200H
	]


ldparm:	jmpr	ldparm		;ID and safety
	.word	bootcd		;start loading
	.word	bootcd		;cold boot entry
	.word	syssct		;number of sectors to load
;------------------------------------------
;sign-on message, placed here so relocator can patch in
;displayable system size

sign:	.byte	01AH,07		;clear screen and ring bell
	.ifg	syssiz,[
	.byte	30H + syssiz/10, 30H + syssiz@10
	.ascii	'.00'
	]
	[
	.ascii	'00.00'		;patched by relocator
	]
	.ascii	"K CP/M"
	.ascii	" - TURBO-BIOS$"
	.ascii	"          "
;------------------------------------------
;offsets from start of code to other configurable parameters
;that are set by TURBO CONFIG program
	.word	schar	- bootcd	;screen dump trigger
	.word	iflag	- bootcd	;interrupt flag (& func keys)
	.word	motcns	- bootcd	;motor off time constant
	.word	rbtdrv	- bootcd	;warm boot drive
	.word	wptr0	- bootcd	;pointer to warm boot message 
	.word	wptr1	- bootcd	;pointer  "    "     "   "
;------------------------------------------
;Configuration Data Structure

;miscellaneous options

iiobyt:	.byte	81H		;initial I/O byte

curs83:	.byte	7FH + 80H	;83 cursor (flashing block)
curs84:	.byte	01100000B ! 00000000B
				;84 cursor (slow flashing block)
clk84:	.byte	0		;84 machine clock entry in rom
				;(0 is no clock)

typena:	.byte	0		;use type ahead console
clkmsk:	.byte	0		;enable keyclicks

;Floppy disk time constants
fflag:	.byte	0	;flag whether replacement constants valid
ftime:	.byte	6,50,25	;floppy 0 (step rate,head load,head settle)
	.byte	6,50,25	;floppy 1
	.byte	6,50,25	;floppy 2
	.byte	6,50,25	;floppy 3


;Serial Ports

; Device initialization tables
; Note order of registers taken from Osborne.

devtab:

;SIOB	keyboard device
	.byte	sioBcommand,	00000010B	;select WR2
	.byte	sioBcommand
;----------------------------------------------------------------------
ivect:	.byte	0				;patched in by init code
;-----------------------------------------------------------------------

;BAUDA
	.byte	bauda,		5		;default to 300


;SIOA	tty device
	.byte	sioAcommand,	00010100B	;select WR4 & reset ext stat
	.byte	sioAcommand,	01000100B	;x16, async 1 stop,no parity

	.byte	sioAcommand,	00010011B	;select WR3 & reset ext stat
	.byte	sioAcommand,	11100001B	;rx 8 bits,yes hshak,enab rx

	.byte	sioAcommand,	00000101B	;select WR5
	.byte	sioAcommand,	11101000B	;tx 8 bits,DTR assert,enab tx

	.byte	sioAcommand,	00000001B	;select WR1
	.byte	sioAcommand,	00000000B	;disable interrupts


ilen83	=	(. - devtab)/2

;BAUDB
	.byte	baudb,		5		;default to 300

;sioC	ul1 serial printer device
	.byte	sioCcommand,	00010100B	;select WR4 & reset ext stat
	.byte	sioCcommand,	01000100B	;x16, async 1 stop,no parity

	.byte	sioCcommand,	00010011B	;select WR3 & reset ext stat
	.byte	sioCcommand,	11100001B	;rx 8 bits,yes hshak,enab rx

	.byte	sioCcommand,	00000101B	;select WR5
	.byte	sioCcommand,	11101000B	;tx 8 bits,DTR assert,enab tx

	.byte	sioCcommand,	00000001B	;select WR1
	.byte	sioCcommand,	00000000B	;disable interrupts

ilen84	=	(. - devtab)/2


;warm boot message printed by BDOS string printer
;DateStamper install moves this
wmsg0:	.ascii	[0DH][0AH]'Warm Boot$'
wmsglen	=	. - wmsg0
prmlen	=	. - ldparm

	.ifg	prmlen - 80H,[
	.prntx	"Parameter Sector Overflow"
	]
;-------------------------------------------
	.sbttl	"Cold Boot Initialization Code"
	.page
;start of actual Cold Boot Code (note that ROM is switched in
	.loc	ldparm + 80H
bootcd:	
;must initially set up stack to use during boot, put just below
;start of code
	lxi	sp,bootcd

;verify presence of Turbo Rom
	lxi	h,romid		;start of ID sequence
	push	h
	xra	a
	mvi	b,8
..chks:	add	m		;checksum
	inx	h
	djnz	..chks
	pop	h
	jrnz	xrom		;jump if wrong ROM
	lxi	d,sig
	mvi	b,3
..csig:	ldax	d		;now check signature
	cmp	m
	jrnz	xrom
	inx	h
	inx	d
	djnz	..csig
	jmpr	romok
;*********************************
sig:	.ascii	'PPS'		;signature in ROM
;*********************************
;message for wrong ROM detected
emsg:	.ascii	[1AH][07H]"Requires TURBO ROM!"
elen	=	. - emsg
;*********************************
;use direct ROM calls to video output routine
xrom:	lxi	h,emsg	
	mvi	b,elen
..loop:	mov	c,m
	inx	h
	push	h
	push	b
	call	xcrtout
	pop	b
	pop	h
	djnz	..loop
..hang:	di
	hlt
;**************************************
;find DIRBUF to get initialization tables
romok:	mvi	c,0		;select drive 0 to get DPH ptr
	mvi	e,1		;don't bother redetermining
	call	xseldsk		;direct ROM call
	lxi	d,8
	dad	d		;now have pointer to pointer
	mov	e,m
	inx	h
	mov	d,m
	push	d
	pop	x		;index register points to buffer

;*********************************
;initialise timer interrupts in case they are later
;enabled

	lhld	vecptr		;get pointer to interrupt vector base
				;poke low order to write register 2

	mov	a,h		;set up CPU interrupt vector
	stai
	im2			;make sure in Mode 2

	mov	(ivect - ldparm)(x),l
	lxi	d,timer		;note that tx interrupt is base
	mov	m,e
	inx	h
	mov	m,d		;put vector in place

;initialise any unit record devices
;find which machine
	lda	0FFFBH		;get version byte
	rlc			;move machine bit to cy
	push	psw		;save machine
	push	x
	pop	h
	lxi	d,devtab - ldparm
	dad	d		
	xchg			;table in DE
	pop	psw
	push	psw		;get cy
	mvi	a,ilen83
	jrnc	..do83
	mvi	a,ilen84
..do83:	mvi	l,xdevnit	;rom device initialize
	call	calrom		;use ROM function (switch in RAM)

;now do other config options like cursor, bell, keyboard type-ahead
;interrupt motor turn off, motor deselect time constant, screen dump
;character
;-----------------
;cursor definition
	pop	psw		;get back machine
	mov	a,(curs83 - ldparm)(x)
	jrnc	..cu83
	;for 84 must set up display clock address
	mov	a,(clk84 - ldparm)(x)
	sta	0FFE6H		;entry point in high memory
	mov	a,(curs84 - ldparm)(x)
..cu83:	mvi	l,xdefcur
	call	calrom		;define the cursor
;-----------------
;keyboard type ahead and key clicks
	lhld	hrdptr		;get pointer to hard disk area
	;point to type ahead flag
	dcx	h
	mov	a,(typena - ldparm)(x)
	mov	m,a

	dcx	h		;point to ROM bell character
	mov	a,(clkmsk - ldparm)(x)
	sta	txchar		;set bell used by interrupt time out
	sta	click0
	ora	m
	mov	m,a		;set ROM character


	;move floppy timing
	mov	a,(fflag - ldparm)(x)
	ora	a		;test if floppy timing data valid
	jrz	..nflp
	lhld	hrdptr
	lxi	d,16		;offset to high memory area
	dad	d		;point to destination
	xchg
	push	d

	push	x
	pop	h
	lxi	d,ftime - ldparm
	dad	d
	pop	d
	lxi	b,12
	ldir			;move 12 time constants

	;move warm boot message into position
..nflp:	push	x
	pop	h
	lxi	d,(wmsg0 - ldparm)
	dad	d
wptr1	=	. + 1		;for patching by DateStamper Install
	lxi	d,wmsg
	lxi	b,wmsglen
	ldir

;*****************************************************
;Note ROM calls above switched RAM back on exit so we can set up
;page zero

;set up initial IOBYTE and Logged on drive
	lxi	h,3
	mov	a,(iiobyt - ldparm)(x)	;get initial IOBYTE
	mov	m,a
	inx	h
	mvi	m,0			;start with A0:

;now set rest of page zero
	mvi	a,jmp
	sta	0
	sta	bdos		;set up BIOS/BDOS jumps
	lxi	h,cboot+3
	shld	1		;BIOS wm boot ptr
	lxi	h,ccpentry + 0806H
	shld	bdos+1		;BDOS ptr

;**********************************************************************
;now print sign on message (can use BDOS as everything else is set up)
	push	x
	pop	h
	lxi	d,(sign - ldparm)
	dad	d
	xchg			;point to message
	mvi	c,9
	call	bdos
;**********************************************************************
;set up drive to pass to CCP, if extra init code added then this
;function must be preserved
	xra	a
	mov	c,a		;always set up correct drive
endcode:
;pad rest of sector with NOP so we fall through to CCP,  additional
;init code could be patched in here

	.slist
	.sall
	PADBYT	ldparm+512	;fill rest of sector with NOP
	.rlist
;----------------------------------------------
;start of command processor, on sector boundary
ccpsct	=	4

	.loc	ldparm + 128*ccpsct
ccpentry:

;compute space remaining on previous sector
spare	=	ccpentry - endcode
;***********************************************
; fix BDOS reset disk function in case we are
;installing on top of Plu*Perfect Systems enhancements
;because ROM now handles new logins correctly

bdoslc	=	ccpentry + 0800H

	.loc	bdoslc + 0C83H
	lxi	h,0000


;***********************************************

	.sbttl	"BIOS Proper"
	.page

	.loc	ccpentry + 1600H
cboot:	jmp	boot
	jmp	wboot
	jmp	consta
	jmp	conin
	jmp	conout
	jmp	list
	jmp	punch
	jmp	reader
	jmp	home
	jmp	seldsk
	jmp	settrk
	jmp	setsec
	jmp	setdma
	jmp	read
	jmp	write
	jmp	listst
	jmp	sectrn

;*********************************************
iflag:	.byte	0		;motor interrupt flag
bsflag:	.byte	0		;flags used by BIOS
				;bit 7 (raw/decoded function keys)
				;bit 6 (foreign language Kaypros only)
				;bit 5 (foreign language Kaypros only)
				;bit 4 (foreign language Kaypros only)
				;bit 3  unused
				;bit 2  unused
				;bit 1  unused
				;bit 0  Write Safe flag (Old ROMs only)
;********************************************
;standard Kaypro layout of function keys (Pre - Universal ROM)
akeys:	.byte	0BH,0AH,08H,0CH	;standard ADM 3A cursor keys
keypad:	.ascii	'0123456789-,'	;numeric keypad normal definition
	.byte	0DH
	.ascii	'.'
;********************************************************
;motor delay used in count down offset preserved
;(any program can zero this if it wants control of motor)

mcnter:	.word	0		;interrupt version only uses
				;first byte
;********************************************
;TRUE cold boot entry which cause system restart
;NOTE -- this is different from Kaypro Use
;
boot:	mvi	l,xstart
xcalrm:	jmp	calrom
;*******************************************
iobyte		=	3	;page zero address
cdrive		=	4	;page zero address
bdos		=	5	;page zero address

wboot:	lxi	sp,0100H	;make sure we have good stack
rbtdrv	=	. + 1		;location to patch for different boot
	mvi	a,0		;default is to reboot from A
	lxi	d,ccpentry	;location to load at
				;number of sectors and starting sector
	lxi	b,(1600H/80H)*256 + ccpsct
	mvi	l,57H		;ROM warm boot entry
	call	calrom
	mvi	a,jmp
	sta	0
	sta	bdos		;set up BIOS/BDOS jumps
	lxi	h,cboot+3
	shld	1		;BIOS wm boot ptr
	lxi	h,ccpentry + 0806H
	shld	bdos+1		;BDOS ptr

wptr0	=	. + 1		;for patching by DateStamper Install
	lxi	d,wmsg		;pointer to warm boot message
	mvi	c,9
	call	bdos		;use bdos string printer

	lxi	h,bsflag	;point at BIOS flag
	res	7,m		;make sure function keys not 'raw'

	lda	cdrive
	mov	c,a		;get logged in drive/user
	jmp	ccpentry + 3
;******************************************
;console status
consta:	lda	iflag
	ora	a		;test if using interrupts
	jrnz	..ncnt		;skip if we are
;-----------------------------------------
;CONSTAT polling motor count down
	lxi	h,mcnter + 1
	ora	m		;test for count down (high byte only)
	jrz	..ncnt
	dcx	h
	dcr	m		;decrement low byte
	jrnz	..ncnt
	inx	h
	dcr	m
	cz	motoff
;------------------------------------------
..ncnt:	lda	iobyte		
	rrc			;test for CRT/TTY
	mvi	l,xttysta
	jrnc	xcalrm		;No buffering from TTY

bufclr	=	. + 1
	mvi	a,0		;buffer clear flag
	ora	a
	rnz			;return if not


	mvi	l,xcrtsta	;go see if anything new
	call	calrom
	rz			;return if no character

;else fetch it
	mvi	l,xcrtin
	call	calrom
;******************************************
;Check for Screen Dump pressed
	mov	c,a		;save character
schar	=	. + 1		;location of trigger character
	mvi	a,0		;get screen dump flag (00 = no)
	ora	a
	jrz	putchr		;save character
	cmp	c		;actual trigger character
	jrnz	putchr
;----------------------------------------
;Screen Dump Function	(we don't have room to speed up short lines)
;first home the dump cursor
	mvi	c,0FFH
..loop:	mvi	l,xgetscr	;screen dump ROM entry
	call	calrom
	push	psw		;save character
	mov	a,l		;test for end of line
	ani	07FH		;mask column
	jrnz	..not0		;jump if not column zero
	mvi	c,CR		;start new line
	call	list
	mvi	c,LF
	call	list
..not0:	pop	psw		;get character
	jrz	endscr		;dump ends with zero return
	mvi	c,' '		;skip greek/foreign characters
	cmp	c
	jrc	..grph
	mov	c,a		;get character to print
..grph:	call	list		;send it to the printer
	jmpr	..loop
endscr:	xra	a		;return with status false
	ret
;------------------------
putchr:	mov	a,c
	sta	bufchr		;store character in buffer
	xra	a
	dcr	a
	sta	bufclr		;set flag
	ret			;set non zero
;*****************************************
;console input
conin:	call	consta
	jrz	conin		;loop out of ROM
	lda	iobyte
	rrc
	jnc	reader		;no screen dump or
				;function keys with TTY

bufchr	=	. + 1		;one character look-ahead where constat
				;places character
	mvi	a,0
	lxi	h,bufclr
	mvi	m,0		;clear buffer flag
;now must map any function keys
mapfnc:	ora	a
	rp			;if no high bit then return
	lxi	h,bsflag	;see if we are to map
	bit	7,m
	rnz			;return raw function if set
	lxi	h,akeys		;point to mapping table
	ani	1FH		;crunch hi bits
	add	l
	mov	l,a		;get offset, (always in first page)
	mov	a,m
	ret
;****************************************
;console output
conout:	lda	iobyte
	rrc
	jrnc	punch		;Send to TTY
;must trap bell character if interrupt timer being used
crtout:	mvi	l,xcrtout
	lda	iflag		;are we using interrupts
	ora	a
	jrz	calrom
	lda	mcnter		;is motor still running
	ora	a
	jrz	calrom
	mov	a,c
	cpi	7		;test for bell
	jrnz	calrom
	lxi	h,txchar
	set	2,m		;set bell bit
	ret

;*****************************************
;list device
list:	call	listst		;loop till ready in hi memory
	jrz	list
	lda	iobyte
	ani	0C0H		;isolate list device 
	jrz	punch
	rlc
	rlc
	dcr	a		;test for CRT
	jrz	crtout
	dcr	a
	mvi	l,xlptout
	jrz	calrom
	mvi	l,xul1out
	jmpr	calrom
;*************************************
;sector translation routine
sectrn:	mvi	l,xsctrn
	jmpr	calrom
;************************************
;turn off floppy motor and deselect hard disk
motoff:	mvi	l,xdskoff
	jmpr	calrom		;jump to ROM
;****************************************
;punch device (always TTY)
punch:	mvi	l,xttyout

;******************************************
;main entry to ROM
calrom:	push	psw		;save A

;disable SIO status interrupts
	lda	iflag
	ora	a
	jrz	..skip
	di			;make sure we are not hit
	mvi	a,1		;select write reg 1
	out	sioBcommand
	xra	a		;disable all interrupts
	out	sioBcommand
	ei
..skip:	pop	psw
	call	0FFFCH		;fixed ROM entry point
	push	h
	push	psw
;check if motor counter needs reset
	lda	iflag
	ora	a
	jrz	notint
	lxi	h,mcnter	;point to current motor counter (lo byte only
				;used by interrupt counter)
	ana	m		;test for zero
	jrz	notint

;now reinitialize SIO status interrupts
	di
	in	sioBstatus	;check if buffer empty
	bit	2,a
	jrz	nempty
	dcr	m		;decrement count
	jrnz	not0
	inr	m		;make sure we are non zero
				;only time-out in actual interrupt routine
click0	=	. + 1
not0:	mvi	a,0
	out	sioBdata	;restart timer

nempty:	mvi	a,1
	out	sioBcommand	;select register 1
	mvi	a,00000110B	;enable vectord TX empty interrupts
	out	sioBcommand
	ei
notint:	pop	psw
	pop	h
	ret

;****************************************
;reader device (always TTY)
reader:	mvi	l,xttyin
	jmpr	calrom
;****************************************
;home selected disk drive
home:	mvi	l,xhome
	jmpr	calrom
;****************************************
;select disk
seldsk:	mvi	l,xseldsk
	jmpr	calrom
;***************************************
;set desired track
settrk:	mvi	l,xsettrk
	jmpr	calrom
;***************************************
;set desired sector
setsec:	mvi	l,xsetsec
	jmpr	calrom
;***************************************
;set DMA address for transfer of next sector
setdma:	mvi	l,xsetdma
	jmpr	calrom
;***************************************
;read specified sector
read:	mvi	b,xread

;common read/write entry
motcns	=	. + 1
stime:	lxi	h,7FFFH		;reset motor off timer
	shld	mcnter
	mov	l,b		;get function set up
	jmpr	calrom
;***************************************
;write specified sector
write:	mvi	b,xwrite
	jmpr	stime
;**************************************
;list output status
listst:	lda	iobyte
	ani	0C0H		;mask out list bits
	mvi	l,xttosta
	jrz	calrom		;TTY used
	rlc
	rlc			;moveinto low bits
	dcr	a		;test for CRT, always ready
	jrz	..true
	dcr	a
	mvi	l,xlptsta
	jrz	calrom		;use Centronics
	mvi	l,xul1ost
	jmpr	calrom
..true:	dcr	a
	ret			;always ready
;************************************
;Interrupt driven motor/deselect timer
;
;This interrupt driven timer uses the Keyboard TX buffer empty
;which interrupts at 30 HZ rate.  If IFLAG enabled then type-ahead
;keyboard must also be enabled, so that occassional framing errors
;generated by keyboard firmware bug can be corrected.  Note that
;some very early SMK keyboards with 8749 (cf 8049 in later) have
;serious bug that makes operation with interrupts impossible,
;symptoms of this problem are ^@'s appearing on console when a
;key is pressed.  Maximum timing delay is 8.3 seconds.
;-------------------------------------------------
timer:	sspd	timstk		;save current stack
	lxi	sp,timstk	;set up new local stack
	push	psw
	push	h
	lxi	h,mcnter	;point to counter
	dcr	m		;decrement
	cz	motoff		;deselect and flush if needed
txchar	=	.+1		;clicks and bell
	mvi	a,0		;character to send to keyboard
	bit	2,a		;is bell bit set
	jrz	..nbel		;skip if no bell
	mvi	h,beldly	;need to delay
..lp:	dcr	l
	jrnz	..lp
	dcr	h
	jrnz	..lp		;delay befor bell
..nbel:	out	sioBdata	;send character
	res	2,a		;clear bell bit
	sta	txchar
	pop	h		;Note motoff saves additional reg. used
	pop	psw
	lspd	timstk		;get back old stack pointer
	ei
	reti
;***********************************************************
;compute total length of system in sectors for bootloader
syssct	=	(. - bootcd)/128
	.ifg	((.- bootcd)@128),[
syssct	=	syssct + 1
	]
;****************************************************
;check for overall system length -- we require 4 sectors spare
;possible installation of Plu*Perfect DateStamper

	.ifg	. - cboot - 4*128,[
	.prntx	"BIOS too long"
	]

;***********************************************************
	.loc	cboot + 4*128
wmsg:	.blkb	12

	.loc	cboot + 4*128 + 64 
;interrupt stack compatible with Plu*Perfect DateStamper
timstk:	.blkw	2		;word to save stack during int.


	.end
