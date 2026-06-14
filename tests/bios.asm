  	.title	'DMS/3, DMS/4 HiNet and CP/M BIOS   ----   vers  245'
	.ident	cbios
;
version	=	1	; CP/M version number
revision=	445	; DMS revision number
patch	=	' '	; Patch ID (normally blank)
mod	=	00	; internal use only
			; 00 for all released vers

SEL	=	SELECT	; Programmers' ref. only
FOPT	=	FOXopt	; Programmers' ref. only
CV	=	CPMver	; Programmers' ref. only

LSTbyt	=	LASTbyt	; Last mem. loc. used.
			; LSTbyt may be deleted --
			; for programmers ref. only.
;
;	last revised 18may83 jlw
;
;---------------
;		TABLE OF CONTENTS		   PAGE
;	(page numbers from master option, use as guide)
;
; modification log				      3
; instructions for generating operating system	     10
; conditional assembly options			     12
; addresses of bios,bdos,ccp, and important tables   16
; important constants				     18
; port definitions and standard CPM entry points     22
; interupt vectors				     23
; non standard jump vectors			     24
; floppy,hard,and net command and status tables	     26
; type ahead buffer				     29
; buffer and command status			     30
; cold boot code				     32
; assign a hard disk partition			     47
; disk parameter tables				     50
; cold boot messages and SIO command strings	     52
; warm boot					     54
; conin,conout,const,list,reader,punch		     59
; type ahead code for various ports		     62
; SELDSK select disk drive			     72
; SETTRK set track				     76
; HOME,SEEK, DELAY				     77
; READ and WRITE disk				     79
; floppy disk reads and writes			     81
; hard disk reads and writes			     92
; network reads,writes,spools and locks		     99
; master polling				    106
; context switch routines			    110
; login new user				    111
; process local user request			    115
; process remote user request			    117
; hinet read-write-assign			    121
; mimic routines				    123
; record locking routines			    124
; spooling routines				    127
; spooling utilities				    134
; spooling interupt driver			    136
; master utility routines send,receive user etc	    139
; hinet station boot - phase 2			    144
; hinet station boot - phase 1			    146
; relocated bootstrap code			    147
; SENDNET					    152
; RECNET					    154
; SDLC interupts				    157
; psuedo numbers, network messages and commands	    161
; sio and dma commands for network activity	    163
; process a timer interupt			    165
; process a front panel interupt		    168
; PRTMSG print a message			    169
; lock the DMA chip				    170
; handle an i/o error				    171
; CPMMAP get current disk map			    175
; default logical to physical disk maps 1.4	    177
; default logical to physical disk maps 2.2	    178
; default floppy disk parameter blocks - 8 inch	    180
; default floppy disk parameter blocks - 5 inch	    182
; sector translation, check and allocation vectors  184
; default custom printer driver			    185

	.page
	.sbttl	'Modification log'
	.prntx	'here we go'
;----------
; DMS/3, DMS/4 CP/M BIOS
;
; Written by Peter Kavaler  July-December 1980,
;  with assistance from Robert Kavaler
;
; Written by Marc de Groot  January 1982-
; Modified by joel wittenberg from 24aug82 on-
; Update history:
;
; 1.40 (09/01/80) Initial release
; 1.41  (10/01)   Added S/L bit to pre-comp
;       	  Network always at 500 Khz
;       	  Network disk shared by master
; 1.42            Clear DD buffer at offMOTOR
;		  LOGIN code added to master
; 1.421 (10/20)   SENDNET timing problem fixed
; 1.422 (10/22)   Floppy sharing added
;		  Harddisk ASSIGN added
; 1.423 (10/28)   IOBYTE added
;		  Centronix supported
;		  ASSIGN names added
;		  User names added
; 1.424 (11/04)   Changed floppy head settle times
; 1.425 (11/10)   ADDS printer supported
;		  User name table lookup added
;		  Master BIOS expanded by 1K
; 1.426 (11/11)   Added default configuration table
;		  Added boot from floppy drive 1
; 1.427 (11/24)   Added boot from hard disk
;		  Master does real warmboot
;		  Floppy and hard status in fixed loc
; 1.428 (12/04)   Master user must login
; 		  Retry SECT, MADR errors
;		  Fixed 850 bug (headno missing)
; 1.429 (12/09)   Allowed DSC/4 on network
;		  Added hard disk timeout
;		  Handle CNTL-P with ADDS AUX port
; 1.430 (12/17)   Floppy network master can warmboot
;		  Remove ASSIGN code from BIOS
;		  Hertz rate in high core
; 1.431 (01/14)   Make compatible with CP/M 2.201
;		  Optional seek rate 3ms for 850
;		  Add hog protocol to network
;		  More extensive WHO info
; 1.432 (01/23)   Change network bootstrap procedure
;		  Add record locking
;		  User dependent IOBYTE
; 1.433 (04/01)	  Transmit extra flags in front of msg
;		  Allow local user to talk on net
;		  Fix onMOTOR drive switch bug
;		  Add THS and more hard error msgs
; 1.434 (05/01)   Use DMA for hard disk
;		  Return CPU to local user during DMA
;		  Fix backspace bugs in ED and WORDSTAR
;		  Add 1K network read buffer
;		  Add mimicry
;		  Allow floppy defaults in user table
;		  Remove net code from flop or hardboot
;		  Add flop and hard code to net boot
; 1.435	(05/15)	  Implement CP/M 2.2 network
;		  Combine CP/M 1.4 and 2.2 BIOS
; 1.436	(06/12)	  Increase timint stack to 16 words
;		  Flush read buffer on record lock
;		  Clear up timing problems in net
; 1.437 (08/14)   Default type-ahead buffer for USER
;		  New parallel port interface
;		  No HALT error on master boot
;		  Ask for date, time on master boot
;		  Print spooling
;		  Diablo print driver (as CUSTOM dev)
;		  Add unassignments
; 1.437A          Fix INT problem on master
;		  Fix msg intercept on master
;		  Add NOP to RECfirst
; 		  Print user error message in hex
;
; (01/18/82)	Marc de Groot started maintenance of
;		the BIOS.
;
; 1.437B	FIXED A BUG IN THE LOGIN RANDOM DELAY
;		TO PREVENT THE DELAY COUNTER FROM
;		BEING ZERO.
;
; 1.437C	Added turnkey boot of remote stations
;		to the station boot code. Putting the
;		PROM serial # in the USERS table as a
;		user name ( with no password ) will
;		cause the machine with that serial no.
;		to auto-boot.
;
; 1.438		Added type-ahead to port 3.
;
; 1.438A(02/08)	Type ahead working on both input and
;		output for port 3.
;
; 1.438B(02/10)	Moved the HiNet stn code down 1 page
;		to accomodate the port 3 type-ahead.
;		Port 3 type-ahead does not assemble
;		for the HiNet master.
;
; 1.438C(02/11)	Added poll-prime capability.
;
; 1.438D(02/19)	CP/M warm boot now re-initializes the
;		SETppa jump and the INTERUPT jump.
;
; 1.438E(03/03)	X-ON/X-OFF protocol added to serial
;		print spooling.
;
; 1.438F(03/08)	Attempted fix for the LOCKdma bug added.
;
; 1.438G(03/11) LOCKdma rewritten. #-of-retries bug
;		fixed. Timer interrupt routine
;		shortened. DI and EI added to floppy
;		RESULT routine.
;
; 1.438H(03/11) Took serial port 1 out of list of
;		possible CONIN/CONOUT assignments,
;		and replaced it with parallel port 1
;		for the Fox.
;
; 1.438I(03/13)	Made PHASE 2 of the net boot code
;		a fixed length for LOGINFOX.
;
; 1.438J(03/17)	Fixed the parallel input status routine
;		to return 0FFh if char ready.
;
; 1.438K(03/19)	Pointed the PHASE 1 boot code at the
;		PROM input/output routines. The PROM
;		is shut off after PHASE 1 executes;
;		not before.
;
; 1.438L(03/24)	1.438K contained a common net boot for
;		the FOX and DSC/3 and 4. Somehow the
;		net disk-write operation was
;		affected. This rev has the common
;		net boot and also works correctly.
;
; 1.438M(03/31)	Shut off assembly of port 3 typeahead
;		for stand-alone floppy boot systems.
;
; 1.438N(04/05)	Set loadset to 7800h. FOXopt added.
;		Numerous changes made for 5 inch disks.
;		SYNC error deleted; made re-tryable.
;		SEEK error deleted; made re-tryable.
;		Default disk table conditionally as-
;		sembles 5 or 8 inch floppy defs. ac-
;		cording to FOXopt.
;
; 1.438O(04/12)	Began conversion to dual size floppy
;		capability for network station code.
;		cpmMAP, ASSdef, and ASSIGN changed.
;		Note! Most changes only implemented for
;		CP/M 2.2 on experimental basis.
;	(04/19)	Changed SELDSK, SECTRAN, HARDprep, READ,
;		WRITE, SEEK, Network, and HOME to agree
;		with new cpmMAP and iobMAP routines.
;	(04/20)	Changed ASSIGN again and goSPOOL.
;	(04/22)	Changed ASSdef, and the station code
;		booted. NOTE: the system has only been
;		tested as HiNet station code under 2.2
;	(04/28)	Errors were found in the poll-prime
;		protocol. Proper initialization of the
;		poll-prime addr added to WBOOT.
;
; 1.438P(05/03)	Added MINIopt and changed FOXopt to
;		agree with existing cond. assy. style
;		for implementing various media types.
;		Note that FLOPopt is for 8 inch and
;		MINIopt is for 5 inch. FOXopt is for
;		FOX specific stuff only (init IOBYTE,
;		etc.)
;	(05/04)	Added MINIboot and started converting
;		code that suffers when both FLOPopt and
;		MINIopt are selected.
;	(05/06) Added set5 and set8 to change the max
;		number of sectors and gap length when
;		changing disks.
;	(05/10)	Modified ASSIGN to set MEDIUM to NET.
;
; 1.438Q(05/10)	Started modifying code to make stand-
;		alone systems work properly.
;	(05/12)	Changed ASSdef to set both the media
;		type and the unit no. to 0FFh if
;		the drive is unassigned. (Previously
;		set only unit no. to 0FFh.)
;
; 1.438R(05/13)	Started fix for poll-prime. Poll-prime
;		ack now 'V' instead of being the same
;		as pollack ('A').
;
; 1.438S(05/20)	Various experimental changes made to
;		fix poll-prime.
;	(05/24)	Fixed problem of setting bit 4 in
;		RECstat when a poll-prime comes.
;
; 1.438T(05/23)	Rewrote REClast to finally fix the
;		poll-prime problem.
;
; 1.438U(05/26)	Began changes to fit the expanded
;		stand-alone floppy-boot system on an 8"
;		disk. Eliminate the user printer driver
;		from the stand-alone code.
;
; 1.438V(06/02)	Fixed assembly error in stand-alone
;		harddisk version. Result buffer print
;		only assembled if TESTopt = 0.
;
; 1.438X(06/14)	Fix for strange net read error.
;		Added code to print the err code
;		returned printed by the hard disk
;		controller.
;	(06/16)	Changes for mult. hard disks put into
;		HARDr,HARDw,HARDrd,HARDwr.
;
; 1.438Y(06/16)	Continued changes for multiple HDs.
;
; 1.438Z(06/17)	Repointed cpmMAP at DSKBOOT+2. Changed
;		calls to ASSIGN.
;
; 1.439 (06/18)	Got the master BIOS to boot. Added
;		HDstat.
;
; 1.439A (6/23) Attempted to fix HDstat.
;
; 1.439C (6/30)	Fixed HDstat for network station.
;
; 1.439D(07/02)	Changed the floppy gap length for mini
;		floppies if FOXopt=0. The net station
;		BIOS still runs at half speed for some
;		reason.
;
; 1.439E(07/06)	Added code for HDstat network requests.
;		Nhdstat,NEThdstat added. HDC errors now
;		all print HDSK error, along with an
;		error code.
; 1.440A(07/13)	Moved the BIOS down to 0EF00h for the
;		8 inch stand-alone code. Corresponding
;		changes were made in FBOOT.ASM
;
; 1.440B(07/14)	Fixed HDstat for local HD on net stn.
;		Moved cold boot code from floppy rd
;		buffer to the check/allocation
;		vector buffer if floppy boot.
;
; 1.440C(07/15)	The cold boot for floppy boot is now
;		at rdbuffer-200h, which moves it into
;		the check/allocation vector area. The
;		equates do not insure the code ends up
;		in the vectors, so care must be taken
;		when moving the check/alloc vector
;		area. It is now necessary to move the
;		BIOS high mem constants down with DDT.
;		(See 'instructions for generating
;		operating system').
;
; 1.440D(07/16)	Int enable for port 3 in CBOOT now
;		dependent on AH3opt, not AHEADopt
;
;
; 1.441 (07/17) All versions working except for HD
;		stand-alone. HD stand-alone does not
;		recover from the CCP cmd. S: <ret>
;		properly. It logs to C: with another
;		MP/M user number. USER 0 restores it.
;		Changed the BIOS length value so 100h
;		added only for 8 inch stand alone
;		instead of all non MINIopt configs.
;
; 1.441A(07/22)	Added code to allow stand-alone stns
;		to execute one cmd line on cold boot.
;
; 1.441B(07/22)	Put floppy specify in SELDSK.
;
; 1.441C(07/26)	Added HiNet date/time protocol.
;		Moved the station code down 1
;		page, to 0DE00h.
;
; 1.441D(07/27)	Fixed IOERR to print the HD and floppy
;		result buffers more cleanly.
;	(07/29)	No retries on HDSK error; IOERR waits
;		for one key press and warm boots.
;
; 1.441E(07/30)	HiNet station code now works in
;		diskless stations.
;
; 1.441f(8/3/82) Hard disk select waits for status
;		return from firmware.
;
; 1.441g(8/3/82) Hard disk select status receive is
;		done with inline code instead of a
;		call to reshard.
;	--RELEASED--
;
; 1.441i(8/23/82) Spool code makes use of volume info.
;		Source changed to agree with ddt
;		patches which created version 1.441h.
;	--RELEASED--
;
; 1.441j(8/24/82) Maintenance now being done by
;		joel wittenberg...
;		No more fatal HDerr on boot when
;		prtspool is on vol<>0 and prtspool
;		partition is > corresponding vol0 part.
;
; 1.441k(8/26/82) Prtspool now ok on any vol, any unit
;
; 1.442b(9/09/82)	Floppy, hard disk, and net
;		error handling improved; now keeping
;		floppy retry cnt in memory; IOERR
;		returns to caller, not to callers'
;		caller (1 level too far). REHOME
;		not performed unless failed op had a
;		track error. NRDYerr added, others
;		now work correctly.
;		   	NETerrs now save the callers'
;		address and print the user's number
;		and the MASTbuffer contents.
;			Hard disk errors now call
;		NETerr (if on the master), print
;		the HARDstat buffer contents,
;		and either continue or query the
;		master user depending upon
;		MODE bit 7 (prev not used).
;			Changed stat boot phase 1 to
;		relocate ram before setting int vector.
;			Moved station BIOS code down
;		one page, so CPM2cf.com must now be
;		used. Added check for too large a
;		code segment - it and the bios offsets
;		are currently correct for hard master
;		or station only. 5 inch disk drivers
;		not fully updated.
;
; 1.442c(13/09/82)	Removed bogus, non-functional
;		typeahead OUTPUT buffer for port3,
;		replaced it with the standard port
;		output code.
;
; 1.442d(14/09/82)	One change in SIO programming
;		req'd to make new port3 code work.
;		Changed retry function in floppy driver
;		to restart drive motor(for 5 inch).
;		Also changed default mode byte to
;		inhibit user mss. Changed HALTerr.
;
; 1.442e(14/09/82)	Changed HALTerr again just
;		a bit so that warm boot by operator
;		will still have exec'd a RETI.
;
; 1.442f(21/09/82)	Slight changes to error
;		messages and flop err mask; just
;		for consistency with prev versions.
;		Functionally no different.
;
; 1.442g(27/09/82)	NRDYerr given only for
;		current disk. Hard disks no longer
;		check dir entries on warm boot
;	--RELEASED--
;
; 1.442h(06/10/82)	BIOS is 100h larger if it is
;		stand alone floppy boot. FOX parallel
;		port now usable for printer if no
;		hard disk is installed (station only-
;		use 2411 for stand-alone). Bios is too
;		large for any stand-alone boot.
;
; 1.442i 12/10/82	Master now checks for CRC and
;		ovr err on net xmissions; net errs now
;		show user name and no. NETerr now
;		callable from station code. HD errs
;		always show user name, no. and cmd
;		buffer. Missing a poll no longer
;		affects freq of polling.
;			Hard disks check dir entries
;		again-potential problem otherwise
;		with mult users on the same partition.
;			Because of all this the bios is
;		once again moved down one page.
;		CPM2ce.com for master.
;
; 1.442j 22/10/82	Net error handling much better:
;		Same comments as (i) but all working.
;		Still no checks to insure that length
;		of rcv'd message is correct. Stat login
;		ignores backspace and delete
;	-- TOM LEWIS (england) has this code --
; 1.442k 10nov82	Changed '*** waiting' message
;		time to 8 seconds
;
; bios244  11mar83	Changed error handling (Kenny
;		found some problems). Changed REClast
;		and NETio  to insure that a poll was
;		rcv'd. SENDnet no longer polls the
;		SIO to find end of transmission.
;		This fixes the intermittent failure
;		to turn off the SIO.
;			Changed RECfirst to alter
;		timing.
;			Added check in REClast to
;		store actual rcv'd data length in
;		rcvDMAlen. All routines which call
;		RECnet for a data block will check
;		that the correct len was rcv'd.
;		Also all checks for using dma now
;		check actual len not just LSB.
;			REClast also uses a local
;		stack, carefully placed at end of
;		boot phase 2 code - stack loc must
;		be ok during running mast, running
;		station, and booting station.
;			DMANRdone deleted - int.
;		vectors to REClast instead.
;			PRNTint has bigger stack
;		and disables further printer ints
;		until done to cure intermittent
;		crashes.
;			FOX and 5000 stations now
;		have default typeahead buffers at
;		cold boot.
;			Master will poll users and
;		count them down to 224, then poll
;		less frequently (cur once every 32
;		poll cycles) to avoid premature
;		logouts.
;			Changed errPRINT and IOerr
;		to print out meanings of err bytes
;		and the actual type of net error.
;			Master console now polled
;		in timer int to avoid intermittent
;		timing problem.
;			Bug in HD drivers fixed -
;		error in read would still expect
;		data but HD ctlr won't send data
;		so bios would hang.
;			All this done after major
;		changes made for DMS-15 but NOT in
;		this version (so these fixes are
;		retro-fitted).
;
; b244a12  06apr83	HD controller now sends a
;		special error code upon a select
;		if a prev auto flush had failed.
;		Master will detect this, display
;		the error and resubmit the select
;		(it wasn't really in error).
;			Flop spec cmd now sends
;		right step rate. ONmotor delays
;		36 mSecs for 8 inch, 180 mSecs
;		for 5 inch. Step settle delay
;		installed.
;			Over run errors now call
;		DMAFdone to strobe the terminal
;		count pin.
;			Stations now send the
;		prom serial# (bin) when loging in
;		and check for correct # on res-
;		ponse due to SIO not telling us
;		about multiple logins. 86 stats
;		don't send ser# or check for it.
;
; b244a14 		RecLast does ei later, ckPOLL
;		exits to begRET, RECbegin does di,ei
;
; b244a15 28apr83	Various exper. changes to
;		flop drivers to help performance and
;		error recovery
;
; b244b  03may83	Most changes look good -
;		adding a few more. Also changes to
;		Fox/5000 conin to use 1/2 dup port
;		as full dup
; b244c  04may83	FDC term cnt mod still needed.
;		PreComp on 5 inch was wrong - changed.
; b244d  10may83	Inserted di in sendnet after 1/2
;		msec delay to prevent time critical code
;		from being interrupted. Manifested error as
;		CRC errors displayed on master.
;
; b245	18may83		Same code as b244d, changed login
;		version prompt.
;
;	---	RELEASED	---
;
;----------
;
; CP/M version number is always 2
CPMver	==	2
	.page
	.sbttl	'instructions for generating operating system'
;----------
; Six different standard versions of CP/M 1.4 can be
; generated by assembling this BIOS, depending upon
; which conditional assembly options are chosen.
; The procedure for generating a complete operating
; system for each case is outlined below.
;
;	     Stand-alone system
;	     ------------------
; Floppy boot		     Harddisk boot
; -----------		     -------------
; A>ddt cpmF3.com	     A>ddt cpmF3.com
; -iflop1.hex		     -ma00 1f00 100
; -r2C00		     -ihard1.hex
; -ifboot1.hex		     -r2700
; -r7900		     -^C
; -^C			     A>save 38 hardcpm1.com
; A>sysgen		     A>wrun0 hardcpm1.com 1 35
;			     A>wrun0 hardboot.com 2 1
;
;              Network master
;	       --------------
; Floppy network	     Harddisk network
; --------------	     ----------------
; A>ddt cpmEF.com	     A>ddt cpmDB.com
; -ifmast1.hex		     -ma00 1f00 100
; -r3000		     -imast1.hex
; -ifbootm.hex		     -r4300
; -r7900		     -^C
; -^C			     A>save 66 master1.com
; A>save 47 fmaster.com	     A>wrun0 master1.com 5 7D
; A>sysgen		     A>wrun0 mastboot.com 2 1
;
;	       Network station
;	       ---------------
; Floppy network	     Harddisk network
; --------------	     ----------------
; A>ddt cpmF8.com	     A>ddt cpmEA.com
; -ifslave.hex     	     -ma00 1f00 100
; -r3000		     -islave1.hex
; -^C			     -r3000
; A>save 47 fstation.com     -^C
; A>sysgen		     A>save 47 station1.com
; 			     A>wrun0 station1.com 2 23
;----------
	.page
;----------
; Five different standard versions of CP/M 2.2 can be
; generated by assembling this BIOS, depending upon
; which conditional assembly options are chosen.
; The procedure for generating a complete operating
; system for each case is outlined below.
;
;	     Stand-alone system
;	     ------------------
; 	flop stand alones are too large to boot!
;
; Floppy boot		     Harddisk boot
; -----------		     -------------
; A>ddt cpm2EF.com	     A>ddt cpm2EA.com
; -iflop2.hex		     -ma00 2000 100
; -r3100		     -ihard2.hex
; -ifboot2.hex		     -r3100
; -r7900		     -^C
; -m30F0 30FF 2FF0	     A>save 48 hardcpm2.com
; -^C			     A>wrun0 hardcpm2.com 1 21
; A>sysgen		     A>wrun0 hardboot.com 2 1
;
; Mini boot
; ---------
; A>ddt cpm2F0.com
; -iflop2.hex
; -r3000
; -ifboot2.hex
; -r7900
; -^C
; A>sysgen
;
;  	      Network system -- 244g15 and later
;	      --------------
; Network master	     Network station
; --------------	     ---------------
; A>ddt cpm2cc.com	     A>ddt cpm2Dc.com
; -ma00 2000 100	     -ma00 2000 100
; -imast2.hex		     -islave2.hex
; -r5300		     -r3f00
; -^C			     -^C
; A>save 82 master2.com	     A>save 62 station2.com
; A>wrun0 master2.com 5 5d   A>wrun0 station2.com 2 05
; A>wrun0 mastboot.com 2 1
;----------
	.page
	.prntx	'bios for CP/M vers 2.2'
	.sbttl	'conditional assembly options'
;----------
; CP/M 1.4 conditional assembly options:
;
	.ife	CPMver-1,[
;
BACKopt	==	0	; backspace handled in BIOS
SELECT	=\ "
Enter 1 for stand-alone system
      2 for network master
      3 for network station 	select"
;
	.ife	SELECT-1,[
FLOPboot=\ "
Enter 0 for floppy boot
      1 for harddisk boot 	select"
HARDboot==	1-FLOPboot
NETboot	==	1
MASTopt	==	1
FLOPopt	==	0
NETopt	==	1
HARDopt	==	0
FLOPshar==	1
HARDshar==	1
	]
;
	.ife	SELECT-2,[
FLOPboot==	1
NETboot	==	0
HARDboot==	1
MASTopt	==	0
FLOPopt ==	0
NETopt  ==	0
FLOPshar=\ "
Enter 0 for floppy network
      1 for harddisk network 	select"
HARDshar==	1-FLOPshar
HARDopt	==	HARDshar
	]
;
	.ife	SELECT-3,[
FLOPboot==	1
NETboot	==	0
HARDboot==	1
MASTopt	==	1
FLOPopt	==	0
NETopt	==	0
FLOPshar=\ "
Enter 0 for floppy network
      1 for harddisk network 	select"
HARDshar==	1-FLOPshar
HARDopt	==	HARDshar
	]
	]
	.page
;----------
; CP/M 2.2 conditional assembly options:
;
	.ife	CPMver-2,[
version	=	2		; new version number
revision=	revision-200	; new revision number
;
BACKopt	==	1	; backspace handled by BIOS
SELECT	=\ '
Enter 1 for stand-alone system
      2 for network master
      3 for network station 	select  '
;
	.ife	SELECT-1,[
HARDboot=\ '
Enter 0 for harddisk boot
      1 for floppy boot		select  '
	.ife	HARDboot, [
MINIopt	==	1
	]
	.ifn	HARDboot, [
MINIopt=\ '
Enter 0 for 5 inch disks
      1 for 8 inch disks	select  '
	]
MINIboot==	(1-HARDboot)!(MINIopt)
FLOPopt	==	1-MINIopt
FLOPboot==	(1-HARDboot)!(1-MINIopt)
NETboot	==	1
MASTopt	==	1
NETopt	==	1
HARDopt	==	0
FLOPshar==	1
HARDshar==	1
	]
;
	.ife	SELECT-2,[
MINIopt=\ '
Enter 0 for 5 inch disks
      1 for 8 inch disks	select  '
MINIboot==	1
FLOPboot==	1
NETboot	==	0
HARDboot==	1
MASTopt	==	0
FLOPopt ==	1-MINIopt
NETopt  ==	0
FLOPshar==	1
HARDshar==	0
HARDopt	==	0
	]
;
	.ife	SELECT-3,[
MINIboot==	1
FLOPboot==	1
NETboot	==	0
HARDboot==	1
MASTopt	==	1
NETopt	==	0
HARDopt	==	0
FLOPopt	==	0
MINIopt	==	0
FLOPshar==	1
HARDshar==	0
	]
	]
	.page
;----------
; Misc. conditional assembly options (0 to select):
;
FOXopt	==	MINIopt!(1-FLOPopt)
AHEADopt==	1-FOXopt	; console type-ahead

	.ifn	SELECT-1,[
AH3opt	==	(MASTopt-1)!AHEADopt!NETopt
EXECopt	==	1
		]

	.ife	SELECT-1,[
AH3opt	==	1
EXECopt	==	0
		]

TIMERopt==	0	; real-time clock interrupts
TESTopt	==	1	; Used by IOERR
;
; Network station 1K read buffering option
	.ife	SELECT-3, [BUFFopt == HARDshar]
			  [BUFFopt == 1]
;
; ADDS AUX port printer option
	.ife	SELECT-3, [ADDSopt == 0]
			  [ADDSopt == 1]
;
; Network spooler option
	.ife	NETopt,   [SPOOLopt== 0]
			  [SPOOLopt== 1]
;
; Front-panel interrupt option
	.ife	MASTopt,  [FRONTopt== 1]
			  [FRONTopt== 0]
	.pabs
	.phex
	.page
	.sbttl	'addresses of bios,bdos,ccp and important tables'
;----------
; Addresses of BIOS, BDOS, CCP, and important tables:
	.ife	CPMver-1,[
lenBIOS	=	500h 	; length of BIOS kernal
lenBDOS	==	0D00h	; length of BDOS
lenCCP	==	800h	; length of CCP
	]
	.ife	CPMver-2,[
lenBIOS	=	800h	; length of BIOS kernal
lenBDOS	==	0E00h	; length of BDOS
lenCCP	==	800h	; length of CCP
;
; Extra mem for alloc and check vects (CP/M 2.2 only)
	.ife	HARDboot,     [lenBIOS = lenBIOS+600h]
	.ife	NETboot,      [lenBIOS = lenBIOS+600h]
	]
; Extra mem for disk device drivers
	.ife	FLOPop&MINIop,[lenBIOS = lenBIOS+600h]
	.ife	FLOPop!MINIop,[lenBIOS = lenBIOS+300h]
	.ife	FLOPboot!(SELECT-1),[
			       lenBIOS = lenBIOS+100h]
	.ife	MINIopt!(SELECT-1),[
			       lenBIOS = lenBIOS+100h]
	.ife	FLOPopt!(SELECT-1),[
			       lenBIOS = lenBIOS+100h]
	.ife	HARDopt,      [lenBIOS = lenBIOS+200h]
	.ife	NETopt,       [lenBIOS = lenBIOS+500h]
	.ife	BUFFopt,      [lenBIOS = lenBIOS+400h]
	.ife	SPOOLopt,     [lenBIOS = lenBIOS+100h]
	.ife	MASTop!HARDsh,[lenBIOS = lenBIOS+1800h]
	.ife	MASTop!FLOPsh,[lenBIOS = lenBIOS+200h]
;
; Extra mem for port 3 type-ahead
	.ife	AH3opt,		[lenBIOS = lenBIOS+100h]
;
; Extra mem for cold boot code
	.ife	MASTopt,      [lenBOOT = 800h]
	.ifn	MASTopt,      [lenBOOT = 400h]
;
; Important CP/M addresses
lenCPM	==	lenCCP+lenBDOS
BIOS	==	64*1024-lenBIOS	; address of BIOS
BDOS	==	BIOS-lenBDOS+6	; address of BDOS
CPM	==	BIOS-lenCPM	; address of CCP
TPA	==	100h	; transient program area
wrBUFF	==	0FF00h	; floppy write buffer
rdBUFF	==	0FE00h	; floppy read buffer
netBUFF ==	0FA00h	; network read buffer
;
; Table addresses for hard disk network master
.ife	MASTopt!HARDshar,[numusr   == 32
		  	  USERlist == 0FC00h
		  	  numlock  == 32
		  	  LOCKlist == 0FA00h
		  	  MASTbuf  == 0F600h
			  SPOOLlist== 0F500h
		  	  MASTstac == 0F500h]
;
; Table addresses for floppy disk network master
.ife	MASTopt!FLOPshar,[numusr   == 4
		  	  USERlist == 0FDC0h
		  	  MASTbuf  == 0FD40h
		  	  MASTstac == 0FD40h]
	.page
	.sbttl	'important constants'
;----------
; Important constants
; Control characters
cntlC	==	03h	; <control-C>
cntlP	==	10h	; <control-P>
cntlQ	==	11h	; <control-Q>
cntlS	==	13h	; <control-S>
cntlZ	==	1Ah	; <control-Z>
cr	==	0Dh	; <return>
lf	==	0Ah	; <linefeed>
bell	==	07h	; <bell>
backsp	==	08h	; <backspace>
aTAB	==	09h	; <tab>
rubout	==	7Fh	; <rubout>

;----------
; Device types
SD	==	0<5	; single density map
DD	==	1<5	; double density map
HARD	==	2<5	; hard disk map
NET	==	3<5	; network map
MINI1	==	4<5	; 1 sided mini map
MINI2	==	5<5	; 2 sided mini map

;----------
; Transmit and receive bits
RxRDY	==	0	; receiver ready bit
TxRDY	==	2	; transmitter ready bit

;----------
; Floppy-related constants
RETRY	==	10	; number of I/O error retries
onprecmp==	22	; track to turn on part precomp
maxprec	==	59	; track to turn on full precomp
sect5	==	16	; sectors per trk, 5 inch
sect8SD	==	26	; sectors per trk, 8 inch SD
sect8DD	==	26	; sectors per trk, 8 inch DD
gap5	==	32	; gap for specify, 5 inch
gap8SD	==	7	; gap for specify, 8 inch SD
gap8DD	==	14	; gap for specify, 8 inch DD
stp5	==	0DFh	; Mini step rate 6 ms (1/2 speed clock)
stp8	==	8Fh	; Shugart 800 step rate 8 ms
stp8DS	==	0DFh	; Shugart 850 step rate 3 ms
WBlen5	==	(sect5-1)*256	; Warm boot len, 5 inch
WBlen8	==	(sect8SD-2)*128	; Warm boot len, 8 inch
	.page

;----------
; Timing constants
loadset		==	1E00h	; head load settle time (36/50 mSec)
wait4motor 	==	loadset*4; 5" motor on delay (180/250 mSec)
StepSettle	==	loadset/4; head step settle time (~15 mSec)
unloadHEAD 	==   	62	; unload head if inactive 1 sec
$halfms 	==	50h	; 1/2 ms delay in SENDNET
$1ms		==	10h	; 1ms delay in RECNET
$16ms		==	100h	; 16ms delay in RECNET
$1sec		==	4000h	; 1sec delay in RECNET
$4sec		==	0	; 4sec delay in RECNET
wakeup  	==  	1	; wakeup net master this often
sendboot	==      62	; freq of boot broadcast
sendlog		==	20	; freq of login poll
	.page
;----------
; BIOS low-memory contents:
ticks	==	40h	; 1/60ths \
secs	==	41h	; seconds  \  Time since
mins	==	42h	; minutes   \  cold boot
hrs	==	43h	; hours     /
month	==	44h	; month    /
day	==	45h	; day     /  Set by SETTIME
year	==	46h	; year   /
NETusr	==	47h	; network user number
ticsec	==	48h	; ticks per second
LOCKstat==	49h	; HiNet lock status
LOCKadr	==	4Ah	; address of HiNet lock
RTRYflop==	4ch	; current floppy err retry cnt
			; init to RETRY+1
errFLOP	==	4DH	; floppy errors since cold boot
			; (master only)
Mode	==	4Eh	; system mode bits
errNET	==	4Fh	; network or hard disk
			; errors since cold boot


;----------
; BIOS high-memory contents:
	.loc	0FFF0h
DEFmode:.byte	0c5h	; default mode bits
FLOPmdl:.byte	0	; 0 for Shugart 800, 1 for 850
hertz:	.byte	62	; clock hertz rate
baud1:	.byte	45h,2	; port 1 default 500K baud
baud23: .byte	45h,13	; ports 2,3 default 9600 baud
IOBYTE:
	.ife	FOXopt,[
	.byte	56h	; default IOBYTE, Fox
	][
	.byte	54h	; default IOBYTE, DSC/3 or 4
	]
COLDbas:
	.ife	FLOPboot&MINIboot,[.word BIOS ]
	.ife	NETboot&HARDboot, [.word CBOOT]
CPMbase:.word	CPM	; CP/M base address
	.byte	version*10+revision/100
	.byte	revision@100
serial:	.word	0	; PROM serial number
.page
;----------
; Mode bits
;
; Single user, floppy boot only
modeTRY	==	0	; 0 = dont retry floppy errors
			; 1 = retry floppy errors
; HiNet Master only
modeMSG	==	1	; 0 = don't print USER messages
			; 1 = print USER error messages
modeSPL	==	2	; 0 = automatic spool mode
			; 1 = manual spool mode
modePRT ==	3	; 0 = spool on serial printer
			; 1 = spool on parallel printer
modeWAIT==	4	; 0 = ready when spooling done
			; 1 = wait when spooling done
modeEXEC==	5	; 0 = Don't do cmd on warm boot
			; 1 = Execute cmd on warm boot
modeCLDX==	6	; 0 = NOT cold boot
			; 1 = Just cold booted
modeCONT==	7	; 0 = auto continue on HDSKerrs
			; 1 = query master if HDSKerrs
	.reloc
	.page
	.sbttl	'port definitions and standard CPM entry points'
;----------
; Port definitions:
DMA	==	38h
enaDMA	==	87h	; enable DMA
rstDMA	==	0c3h	; reset DMA
CTC0	==	30h	; CTC channel 0 (port 0)
CTC1	==	31h	; CTC channel 1 (port 1)
CTC2	==	32h	; CTC channel 2 (ports 2,3)
CTC3	==	33h	; CTC channel 3 (clock)
SIO1AC	==	2Ah	; SIO-1 channel A, control
SIO1AD	==	28h	; SIO-1 channel A, data -port 0
SIO1BC	==	2Bh	; SIO-1 channel B, control
SIO1BD	==	29h	; SIO-1 channel B, data -port 1
SIO2AC	==	22h	; SIO-2 channel A, control
SIO2AD	==	20h	; SIO-2 channel A, data -port 2
SIO2BC	==	23h	; SIO-2 channel B, control
SIO2BD	==	21h	; SIO-2 channel B, data -port 3
rstEOM	==	0d0h	; reset SIO underrun flag
rstCHAN	==	18h	; reset SIO channel
PIOAC	==	0Ah	; PIO channel A, control
PIOAD	==	08h	; PIO channel A, data
PIOBC	==	0Bh	; PIO channel B, control
PIOBD	==	09h	; PIO channel B, data
HARDP	==	01h	; Hard disk parallel port
CENTP	==	02h	; Centronix parallel port
FLOPP	==	18h	; Floppy DMA channel
FLOPSR	==	10h	; Floppy status register
FLOPDR	==	11h	; Floppy data register
SETMAP	==	03h	; Set memory map register
STOPFLOP==	03h	; Stop floppy controller
OFFPROM ==	02h	; De-activate DSC/3 PROM
ONMAP	==	00h	; Activate DSC/4 memory map
PPSTROBE==	00h	; Parallel port 2 strobe
timeout	==	07h	; Net dead test bit,true low
crc$ovr	==	60h	; crc and ovrun error mask
pollRCV	==	00h	; REClast found poll
;----------
; Standard CP/M entry points
	.loc	BIOS
	jmp	CBOOT	; cold boot
	jmp	WBOOT	; warm boot
	jmp	CONST	; console status
	jmp	CONIN	; console input
	jmp	CONOUT	; console output
	jmp	LIST	; list output
	jmp	PUNCH	; punch output
	jmp	READER	; reader input
	jmp	HOME	; home drive
	jmp	SELDSK	; select drive
	jmp	SETTRK	; select track
	jmp	SETSEC	; select sector
	jmp	SETDMA	; set DMA address
	jmp	READ	; read disk
	jmp	WRITE	; write disk
	.ife	CPMver-2,[
	jmp	LISTST	; list status
	jmp	SECTRAN	; sector translate
	]
	.page
	.sbttl	'interrupt vectors'
;----------
; Interrupt vectors
	.loc	BIOS+40h ; vectors stored at fixed loc.
vectors:
SIO1vect:
		.word	INTerr	; port 1
		.word	INTerr
  .ife	NETopt,[.word RECfirst; SDLC first char
		.word REClast ; SDLC last char]
  .ifn	NETopt,[.word INTerr
		.word INTerr]
		.word	INTerr	; port 0
		.word	INTerr
.ifn	MASTop,[
  .ife	AHEADo,[.word PORTint ; receiver ready
		.word PORTint ; parity error]
  .ifn	AHEADo,[.word INTerr
		.word INTerr]
		]	; end ' not MASTER '
.ife	MASTop,[.word INTerr
		.word INTerr]
		; mast console polled in timer int
CTCvect:
	.word	INTerr
	.word	INTerr
	.word	INTerr
	.ife	TIMERo,[.word TIMERint; real-time clk]
	.ifn	TIMERo,[.word INTerr]
DMAvect:
	.word	INTerr	; whoever uses DMA sets this up
PIOvect:
	.ife	FRONTo,[.word FRONTint; front-panel]
	.ife	MASTop,[.word PRNTint ; parallel print]
	.page
	.sbttl	'non standard jump vectors'
;----------
; Non-standard jump vectors:
	.loc	BIOS+5Dh ; vectors stored at fixed loc.
;----------
; For network system:
	.ife	NETopt,[
	jmp	clrDDbuf; flush floppy write buffer
	jmp	NETlock	; HiNet lock
	jmp	CPMMAP	; logical to physical map
	jmp	NETunloc; HiNet unlock
	jmp	SETBYT	; set I/O byte count
	rst	0	; --- not used ---
	.word	NETmsg	; point to net command
			; (used by ASSIGN)
	jmp	SENDnet	; send a block on the net
	jmp	RECnet	; receive a block from the net
	.ifn	MASTopt,[
	jmp	NACKpoll ; don't ack polls
	jmp	ACKpoll	 ; ack polls
	jmp	PORTUout; user printer driver
	jmp	SETppa	; set poll-prime addr
	jmp	RECtime	; Set RECNET timeout
			]
	.ife	MASTopt,[
LOCALcal:jmp	INTERCEPT; do local net request
LOCALtim:jmp	INTERUPT ; do local timer int
	jmp	PORTUout; user printer driver
	jmp	CALLerr	; no SETppa in the master
	jmp	CALLerr	; no RECtime in the master
			]
	]
.page
;----------
; For stand-alone system:
	.ifn	NETopt,[
	jmp	clrDDbuf; flush floppy write buffer
	jmp	CALLerr	; --- not used ---
	jmp	CPMMAP	; logical to physical map
	jmp	CALLerr	; --- not used ---
	jmp	SETBYT	; set I/O byte count
	rst	0	; --- not used ---
	.word	.	; --- not used ---
	jmp	CALLerr	; --- not used ---
	jmp	CALLerr	; --- not used ---
	jmp	CALLerr	; --- not used ---
	jmp	CALLerr	; --- not used ---
	jmp	PORTUout; user printer driver
	jmp	CALLerr	; no SETppa
	jmp	CALLerr	; no RECtime
	]
	.ife	HARDopt,[
	jmp	HDstat	; HD subsystem status
	]
	.ifn	HARDopt,[jmp CALLerr]
	.ife	NETopt,[
	jmp	NEThdstat; Status of master's HD
	]
	.ifn	NETopt,[jmp CALLerr]
	.page
	.sbttl	'floppy,hard and net command and status tables'
; Floppy disk controller command and status
	.ife	FLOPopt&MINIopt,[
rdSDFLOP==	6	; read single density floppy
wrSDFLOP==	5	; write single density floppy
rdDDFLOP==	6+40h	; read double density floppy
wrDDflop==	5+40h	; write double density floppy
FLOPcom:.byte	0	; readFLOP or writeFLOP here
FLOPdsk:.byte	0       ; curDSK
FLOPtrk:.byte   0       ; curTRK
FLOPsid:.byte	0	; head address
FLOPsec:.byte	0       ; curSEC
FLOPden:.byte	00h	; 128 byte sector
	.ife	FOXopt,[
MAXsec:	.byte	sect5	; last sec number, 5 inch
FLOPgap:.byte	gap5	; gap length, 5 inch
	.byte	0	; sector size, 5 inch
	]
	.ifn	FOXopt,[
MAXsec:	.byte	sect8SD	; last sec number, 8 inch SD
FLOPgap:.byte	gap8SD	; gap length, 8 inch SD
	.byte	128	; sector size, 8 inch SD
	]
FLOPstat:.blkb	7	; floppy controller status
	]
;----------
; Harddisk controller command and status
  .ife	HARDopt,[
readHARD	==	11h	; read a sector
writeHARD	==	12h	; write a sector
selHARD		==	13h	; select a unit
read1HARD	==	15h	; read 1K
assnHARD	==	17h	; assign a unit
statHARD	==	18h	; Get HD subsystem status
hdFLUSHerr	==	31h	; error on auto flush
HARDcom:	.byte	0	; hard disk command
HARDdsk:
HARDsec:	.byte	0	; sector or drive number
HARDtrk:	.word	0	; track number
		.byte	0,0	; -not used-
		.byte	RETRY	; retry count
		.byte	0	; -not used-
HARDstat:
		.blkb	8	; harddisk controller status
	]
.page
;----------
; Network station command and status
	.ife	NETopt,[
NETmsg:	.byte	0	; response byte
NETcom: .byte	0	; command byte
NETdtn:	.byte	0	; destination
NETsrc:	.byte	0	; source
NETdesc:
NETdsk:	.byte	0	; drive number
NETtrk:	.word	0	; track number
NETsec:	.byte	0	; sector number
NETvol:	.byte	0	; volume number
NETdma:	.word	0	; DMA address
	.loc	NETcom+1
NETnam:	.blkb	8	; unit name
NETpsw:	.blkb	6	; unit password
NETassn	==	NETnam	; put unit assignment here
lencom	==	15	; length of HiNet command
	]
	.page
;----------
; More interrupt vectors
;
	.loc	(.+10h)&0FFF0h	; Locate on 16 byte boundary
SIO2vect:
  .ife	AHEADopt,[
	.ife	AH3opt,  [
	.word	INTerr	; Port 3, out -- polled
	.word	INTerr
	.word	P3int	; Port 3, in
	.word	P3int
	]
	.ifn	AH3opt,  [
	.word	INTerr
	.word	INTerr
	.word	INTerr
	.word	INTerr
	]
	]
;
  .ifn	AHEADopt,[
	.word	INTerr	; Port 3 out
	.word	INTerr
	.word	INTerr	; Port 3 in
	.word	INTerr
	]
			; Port 2 output
;
	.ife	MASTopt,[.word PRNTint; transmit ready
			 .word PRNTerr; ext st change]
	.ifn	MASTopt,[.word INTerr
			 .word INTerr]
			; Port 2 input
	.word	INTerr
	.word	INTerr
	.page
	.sbttl	'type ahead buffer'
;
;----------
; Type-ahead buffer
; This implementation assumes that the buffers start
; on a (typeahead+1) byte boundary.
;
typeahead ==	31	; type-ahead length
;
  .ife	AHEADopt & AH3opt,[
	.loc	(.+typeahead)&(#typeahead)
	]
;
  .ife	AHEADopt,[
PORT0buf:.blkb	typeahead+1	; Port 0 input
	]
;
	.ife	AH3opt,[
PRT3buf:.blkb	typeahead+1	; Port 3 input
	]
;
; Port 0 input typeahead pointers
  .ife	AHEADopt,[
nxtin:	.byte	0	; next input char
nxtout:	.byte	typeahead ; next output char
	]
;
	.ife	AH3opt,[
;
; Port 3 input typeahead pointers
nxt3in:	.byte	0
nxt3out:.byte	typeahead
	]
	.page
	.sbttl	'buffer and command status'
;----------
; Network master command and status
	.ife	MASTopt,[
MASTsnd:.byte	0	; message sent to user
MASTcom:.byte	0	; command or message from user
MASTdtn:.byte	0	; destination
MASTsrc:.byte	0	; source

MASTdesc:
MASTdsk:.byte	0	; disk
MASTtrk:.word	0	; track
MASTsec:.byte	0	; sector
MASTvol:.byte	0	; HD drive (volume) #
MASTdma:.word	0	; DMA address

	.loc	MASTsnd
LOGresp:.blkb	1	; login request response
LOGnum:	.blkb	1	; login user's net number
LOGclk:	.blkb	7	; login time for user

	.loc	MASTcom
MASTnum:.blkb	1	; user number
MASTtim:.blkb	7	; login time

	.loc	MASTcom+1
MASTnam:.blkb	8	; user name
MASTpsw:.blkb	6	; user password

	.loc	MASTcom
LOGcom:	.byte	0	; sent but not presently used
LOGname:.blkb	8	; login user's name
LOGpsw:	.blkb	6	; login user's password
LOGprom:.word	0	; user prom number in binary
	]	; end ' MASTopt '

;----------
; Current floppy buffer information
	.ife	FLOPopt&MINIopt,[
iobDESC:
iobDSK:	.byte	0FFh	; disk   for I/O operation
iobTRK:	.byte	0FFh	; track  for I/O operation
iobPSEC:.byte	0	; sector for I/O operation
iobSEC:	.byte	0	; sector for I/O operation(log)
;
rdbDESC:
rdbDSK:	.byte	0FFh	; disk   of read buffer
rdbTRK:	.byte	0FFh	; track  of read buffer
rdbPSEC:.byte	0	; sector of read buffer (phys)
;
wrbDESC:
wrbDSK:	.byte	0FFh	; disk   of write buffer
wrbTRK:	.byte	0FFh	; track  of write buffer
wrbPSEC:.byte	0	; sector of write buffer (phys)
wrbSEC:	.byte	0	; sector of write buffer (log)
	]
;----------
; Current network buffer information
	.ife	BUFFopt,[
netbDSK:.byte	0FFh	; disk in buffer
netbTRK:.word	0FFFFh	; track in buffer
netbSEC:.byte	0FFh	; sector in buffer
netbVOL:.byte	0FFh	; volume in buffer
	]
.page
;----------
; Current network spool information
	.ife	SPOOLopt,[
SPOOLdsk:.byte	0	; spool disk
SPOOLtrk:.word	0	; spool track
SPOOLsec:.byte	0	; spool sector
SPOOLvol:.byte	0	; spool volume
	]
;----------
; Current CP/M information
cpmDESC:
cpmDSK:	.byte	0FFh	; disk   from CPM
cpmTRK:	.word	0	; track  from CPM
cpmSEC:	.byte	0	; sector from CPM
cpmVOL:	.byte	0	; volume for NET r/w
cpmDMA: .word	80h	; DMA address from CPM
cpmBYT:	.word	80h	; LENGTH of transfer from CPM
	.page
	.sbttl	'cold boot code'
	.prntx	'made it to cold boot code'
;----------
; The cold boot code is stored in one of two places,
; depending upon the boot device:
;
; If booting a floppy disk system or a floppy network
; master, the cold boot code is overlaid with the
; check/allocation vector buffers.
;
; If booting a hard disk system or a network system
; the cold boot code is located below the BIOS.
;
	.ife	FLOPboot&MINIboot,[.loc rdbuffer-200h]
	.ife	NETboot&HARDboot, [.loc BIOS-lenBOOT]
	.ife	MASTopt!FLOPshar, [.loc rdbuffer]
;----------
; Prepare for interrupts
CBOOT:
	di
	lxi	SP,80h
	mvi	A,(vectors>8)&0FFh
	stai		; setup interrupt register
	im2
;----------
; If floppy and BIOS < 0F000h, move the
; high memory constants to where they belong
	.ife	FLOPboot,[
	.ifg	0F000h-BIOS,[
;
; ..srce is the addr of the high mem constants
..srce	=	0FFF0h-(0F000h-BIOS)
;
	lxi	H,..srce
	lxi	D,0FFF0h
	lxi	B,10h	; 16 bytes to move
	ldir
	]
	]
;----------
; Initialize serial no, IOBYTE, drive, error count
	sixd	serial	; store serial number
	lda	IOBYTE
	sta	3	; initialize IOBYTE
	sub	A
	sta	4	; active drive = 0
	sta	errNET
	sta	errFLOP	; init err cnts to 0
	lda	DEFmode
	sta	Mode	; default mode bits
	lda	hertz
	sta	ticsec	; ticks per second
;----------
; Initialize timer and network user number
	.ife	MINIboot&FLOPboot&HARDboot&MASTopt,[
	lxi	H,ticks
	mvi	B,7
init0:	mvi	M,0	; set to zero
	inx	H
	djnz	init0
	mvi	A,0FFh	; default network user number
	sta	NETusr
	]
;----------
; Print CP/M message
	.ifn	SELECT-3,[
	lxi	H,CPMmsg
	call	PRTMSG
	]
;----------
; Initialize port 1
	lxi	H,baud1
	lxi	B,2<8+CTC1
	outir		; set baud rate for port 1
	lda	baud1+1
	cpi	2	; if 500Khz, then RS-422
	jrz	..port2	; so don't initialize RS-232
	lxi	H,rs232
	lxi	B,rs232$<8+SIO1BC
	outir		; program SIO for port 1
;----------
; Initialize port 2
..port2:
	lxi	H,baud23
	lxi	B,2<8+CTC2
	outir		; set baud rates for ports 2,3
	lxi	H,rs232
	lxi	B,rs232$<8+SIO2AC
	outir		; program SIO for port 2
;----------
; Initialize port 3
	lxi	H,rs232
	lxi	B,rs232$<8+SIO2BC
	outir		; program SIO for port 3
;----------
; Initialize SIO interrupt vectors
	mvi	A,2
	out	SIO1BC
	mvi	A,SIO1vect&0FFh
	out	SIO1BC	; setup SIO-1 vectors
	mvi	A,2
	out	SIO2BC
	mvi	A,SIO2vect&0FFh
	out	SIO2BC	; setup SIO-2 vectors
;----------
; Specify floppy seek rate
  .ife	FLOPopt&MINIopt,[
	in	FLOPSR
	cpi	80h	; check whether floppy exists
	jrnz	..noflop; skip specify if no floppy
;
	lda	FLOPmdl
	ora	A	; seek rate 8ms for Shugart 800
	jrz	..specify
;
	mvi	A,stp8DS; seek rate 3ms for Shugart 850
	sta	specFLOP+1
..specify:
	lxi	H,specFLOP
	call	COMMAND	; specify floppy facts
..noflop:
	]
;----------
; If timer-option has been selected, enable
; real-time interrupts
	.ife	TIMERopt,[
	lda	hertz
	cpi	62
	jrz	..62hz
;
; External user-selectable hertz rate
	mvi	A,0C5h	; enable real-time interrupts
	out	CTC3
	mvi	A,1	; interrupt at power hertz rate
	out	CTC3
	jmpr	..ok
;
; Internal fixed hertz rate (62 hertz)
..62hz: mvi	A,0A5h	; enable real-time interrupts
	out	CTC3
	mvi	A,252	; interrupt at 4Mhz/(256*252)
	out	CTC3
..ok:	mvi	A,CTCvect&0FFh ; interrupt vector
	out	CTC0	; must send to channel zero
	]
;----------
; If front-panel option has been selected, enable
; front-panel interrupts
	.ife	FRONTopt,[
	mvi	A,PIOvect&0FFh ; interrupt vector
	out	PIOAC
	mvi	A,10110111b ; enable interrupts
	out	PIOAC
	mvi	A,01111111b ; front-panel/HLT
	out	PIOAC
	]
;----------
; If type-ahead option selected, enable receiver ints

  .ife	AHEADopt,[
			; Initialize port 0
	mvi	A,11h	; write SIO register 1
	out	SIO1AC

  .ife	MASTop,[mvi	a,0]	; no receive ints
	       [mvi	a,18h]	; enable rcver ints

	out	SIO1AC
;
; Initialize port 1
	mvi	A,11h	; write to channel B
	out	SIO1BC
	mvi	A,00000100b ; status affects vector
	out	SIO1BC
	]
;
; Initialize port 3 for type-ahead
	.ife	AH3opt,[
	mvi	A,11h	; write SIO register 1
	out	SIO2BC
	mvi	A,00011100b ; enable Rx interrupt
			    ; no Tx interrupt
	out	SIO2BC
	]
	ei		; interrupts OK now
	.page
;-----------------------------------------------------
;  M A S T E R   I N I T I A L I Z A T I O N
;-----------------------------------------------------
; If master option has been selected, clear various
; tables, then wait for local user to login
	.ife	MASTopt,[
;
; Restart master if front-panel int during cold boot
	mvi	A,0C3h
	sta	30h	; setup jump to goMAST
	lxi	H,goMAST
	shld	31h
;
; Clear user name list
	lxi	D,USERlist
	mvi	B,numusr
..init:
	push	B
	lxi	H,inituser
	lxi	B,16
	ldir
	pop	B
	djnz	..init
	sub	A
	sta	userlist; dont touch local user
	sta	NETusr
;
; Clear lock list
	.ife	HARDshar,[
	lxi	H,locklist
	mvi	M,0FFh
	lxi	D,locklist+1
	lxi	B,16*numlock-1
	ldir
;
; Clear spool list
	lxi	H,SPOOLlist
	mvi	M,0E5h
	lxi	D,SPOOLlist+1
	lxi	B,16*lenSPOOL
	ldir
;
; Check whether another master is already on the net
ckmast:	mvi	A,11111001b ; receive anyone's message
	sta	RECable
	lxi	H,1000h ; throw away net junk
	lxi	B,1000h	; of course, its never this big
	lxi	D,$1sec
	call	RECNET
	bit	timeout,A	; test timeout bit
	mvi	A,11111101b ; restore receiver control
	sta	RECable
	jz	goSPOOL	; jump if net is idle
;
; Ask whether mimic mode should be entered
	lxi	H,BUSYmsg
	call	PRTMSG	; first tell user net is busy
..ask:	lxi	H,MIMask
	call	PRTMSG	; ask for mimic mode
	lxi	H,BOOTnam
	mvi	E,1
	call	INMSG
	lxi	H,crlf
	call	PRTMSG
	lda	BOOTnam
	cpi	'M'	; type 'M' to start mimicking
	jrnz	..ask
;
; Wait for a poll or a write request
mimicry:
	lxi	H,MASTcom
	lxi	B,lencom
	lxi	D,$4sec
	mvi	A,MIMICusr
	call	RECNET
	bit	timeout,A
	cz	MIMerr	; timeout
;
	ani	crc$ovr	; crc or ovrun err
	cnz	MIMerr
;
	lda	MASTcom
	cpi	poll	; check for poll
	jrz	..ack
;
	cpi	writeNET; check for write request
	jrz	..write
;
	cpi	spoolNET; check for spool request
	jrz	..write
;
	call	MIMerr	; bad message

; Answer a poll
..ack:
	mvi	A,pollack
	mvi	E,$halfms
	call	SENDMSG	; acknowledge the poll
	mvi	C,'.'	; print '.' so that everyone
	call	FORCEout; knows that we're mimicking
	jmpr	mimicry
;
; Process a write request
..write:
	mvi	A,mesack
	mvi	E,$halfms
	call	SENDMSG	; acknowledge message receipt
	lxi	H,MASTbuf
	lxi	B,128
	lxi	D,$16ms
	mvi	A,MIMICusr
	call	RECNET	; get sector to be written
	call	ckRECstat
	jrnc	..0good

..fail:
	mvi	e,$halfms ; 1/2 ms delay
	mvi	a,nack	; let master know that
	call	sendmsg	; something went wrong
	call	MIMerr

..0good:
	call	qDMAlen	; rcv'd data len error
	jrnz	..fail
;
	lxi	H,MASTbuf
	call	MMwrite	; write data to disk
	mvi	A,datack
	mvi	E,0	; no delay
	call	SENDMSG	; acknowledge that data is OK
	jmp	mimicry
;
; Handle a mimicry error (print message and address)
MIMerr:
	lxi	H,MIMmsg
	call	PRTMSG	; print message
	pop	h	; get caller's adr
	call	prtCALLadr; compute caller's adr
; don't restore return adr, just jump back to mimicry
; this code not implemented yet because it requires
; net protocol changes
;	mvi	e,$halfms ; 1/2 ms delay
;	mvi	a,nack	; let master know that
;	call	sendmsg	; something went wrong
	jmp	mimicry
;
; Mimicry messages
BUSYmsg:.ascii	[cr][lf]"Another HiNet Master "
	.asciz	"is active."[cr][lf]
MIMask:	.asciz	'Enter "M" to mimic. '
MIMmsg:	.asciz	[bell][cr][lf]"*** MIMC error at "
	]
;----------
; Open SPOOL partition
goSPOOL:
  .ife	SPOOLopt,[
	lxi	H,DSKdef
	call	ASSIGN
	cpi	0FFh	; unit number in A
	jrz	goMAST	; jump if no spool partition
	sta	SPLdsk	; spool partition number
	mov	A,D
	sta	SPLvol	; HD drive (volume) number
	mov	B,C	; size byte (1-5)
	sub	A
	stc
..rot:	ral		; convert (1-5) to (1-16)
	djnz	..rot
	cpi	32
	jz	SPOLerr	; don't allow 8Mbyte spool area
	sta	SPLsiz	; spool partition size (1-16)
;
; Read initial spool job table from spool partition
	lda	SPLvol
	mov	B,A	; B is volume number
	lda	SPLdsk	; partition (unit) number
	lxi	D,0	; track
	mvi	C,1	; sector
	lxi	H,SPOOLlist
	call	HARDr
;
	lda	SPLvol	; HD drive (volume) number
	mov	B,A	; B has volume no. for HARDr
	lda	SPLdsk	; partition (unit) number
	lxi	D,0	; track
	mvi	C,2	; sector
	lxi	H,SPOOLlist+128
	call	HARDr
;
; If master started spooling, kill spool job
	lxi	D,(0<8)!SPLstart
	call	JOBmatch
	jrnz	..1
;
; If master was spooling, kill spool job
	lxi	D,(0<8)!SPLspool
	call	JOBmatch
	jrz	..2
..1:	mvi	M,SPLabort ; kill spool job
;
; If any spool job was printing, set to waiting
..2:	lxi	D,(0FFh<8)!SPLprint
	call	JOBmatch
	jrz	..3
	mvi	M,SPLready; set status to "ready"
;
; Enable serial printer interrupts
..3:	mvi	A,11h
	out	SIO2AC
	mvi	A,00000011b; enable transmitter int
	out	SIO2AC
;
; Enable parallel printer interrupts
	mvi	A,PIOvect&0FFh
	out	PIOAC
	mvi	A,00010111b
	out	PIOAC	; allow int on PIO-A bit 6 low
	mvi	A,10111111b
	out	PIOAC
	]
;-----------
; It's OK to wake the master now
goMAST:
	lxi	SP,80h
	mvi	A,wakeupMAST
	sta	timeMAST
	sub	A
	sta	upMAST
;
; Ask for date
	.ife	HARDshar,[
..daterr:
	lxi	H,DATEmsg
	call	PRTMSG
	lxi	H,BOOTdate
	mvi	M,cr
	mvi	E,1	; echo string
	call	INMSG
	mvi	M,cr
	lxi	H,BOOTdate
	mov	A,M
	cpi	cr	; abort if RETURN
	jz	ASKlog
	call	getnum	; get month
	cpi	1
	jrc	..daterr
	cpi	13
	jrnc	..daterr
	sta	BOOTdate+month
	mov	A,M	; check delimiter
	cpi	'/'
	jrnz	..daterr
	inx	H
	call	getnum	; get day
	cpi	1
	jrc	..daterr
	cpi	32
	jrnc	..daterr
	sta	BOOTdate+day
	mov	A,M	; check delimiter
	cpi	'/'
	jrnz	..daterr
	inx	H
	call	getnum	; get year
	cpi	80
	jrc	..daterr
	cpi	100
	jrnc	..daterr
	sta	BOOTdate+year
	mov	A,M	; check for RETURN at end
	cpi	cr
	jrnz	..daterr
;
; Ask for time
..timerr:
	lxi	H,TIMEmsg
	call	PRTMSG
	lxi	H,BOOTdate
	mvi	M,cr
	mvi	E,1
	call	INMSG
	mvi	M,cr
	lxi	H,BOOTdate
	call	getnum	; get hours
	cpi	24
	jrnc	..timerr
	sta	BOOTdate+hrs
	mov	A,M	; check delimiter
	cpi	':'
	jrnz	..timerr
	inx	H
	call	getnum	; get minutes
	cpi	60
	jrnc	..timer
	sta	BOOTdate+mins
	mov	A,M	; check for RETURN at end
	cpi	cr
	jrnz	..timerr
	sub	A
	sta	BOOTdate+secs
	di
	lxi	H,BOOTdate+secs
	lxi	D,secs
	lxi	B,6
	ldir		; set time
	ei
;
; Ask master user for his login name
ASKlog:
	lxi	H,LOGmsg
	call	PRTMSG
..askname:
	call	askname
	mvi	A,loginNET
	sta	NETcom
	call	NETreq
	lda	NETassn
	ora	A	; A = 0 if login accepted
	jrz	..logged
	mvi	C,bell	; ring bell if login denied
	call	outchr
	jmpr	..askname
..logged:
	]
	]
	.page
;----------
; Initialize type-ahead buffer
  .ife	HARDshar!AHEADopt,[
	di
	lda	INLENdef
	ani	typeahead
	sta	nxtin	; number of chars
	mvi	A,typeahead
	sta	nxtout
	lxi	H,INBUFdef
	lxi	D,PORT0buf
	lxi	B,typeahead
	ldir		; type-ahead chars
	ei
	]
;----------
; Assign default disks on hard disk network
	.ife	HARDshar,[
	lxi	H,DSK0def
	mvi	C,0
	call	ASSdef	; CP/M 'A' drive
	lxi	H,DSK0def+8
	mvi	C,1
	call	ASSdef	; CP/M 'B' drive
	lxi	H,DSK0def+16
	mvi	C,2
	call	ASSdef	; CP/M 'C' drive
	lxi	H,DSK0def+24
	mvi	C,3
	call	ASSdef	; CP/M 'D' drive
	lda	IOBdef
	sta	3	; default IOBYTE
	]
;----------
; Assign default disks on hard disk stand-alone system
	.ife	HARDboot,[
	mvi	C,0FFh
	call	SELDSK
	call	HOME
	mvi	C,121	; first sector of alloc table
	call	SETSEC
	lxi	B,DSK0def
	call	SETDMA
	call	READ	; read beginning of alloc table
	lxi	H,DSK0def+17
	mvi	C,0
	call	ASSdef	; CP/M 'A' drive
	lxi	H,DSK0def+33
	mvi	C,1
	call	ASSdef	; CP/M 'B' drive
	lxi	H,DSK0def+49
	mvi	C,2
	call	ASSdef	; CP/M 'C' drive
	lxi	H,DSK0def+65
	mvi	C,3
	call	ASSdef	; CP/M 'D' drive
	]
;----------
; Jump to the warm-boot entry point
	lxi	H,WBOOT
	push	H
	reti		; clear mysterious interrupt
;----------
; Assign default disk partitions
;
; Regs in:   HL = pointer to partition name
;	     C  = unit number
; Regs out:  none
; Destroyed: A, BC, DE, HL
	.ife	HARDshar&HARDboot,[
ASSdef:
	push	B
	push	H
	call	SELDSK; needed for calling CPMMAP
	pop	H
	push	H
	lxi	D,DSKdef
	lxi	B,8
	ldir		; put disk name in safe place
	lxi	H,DSKdef
	call	ASSIGN; returns unit in B, size in C
	cpi	0FFh
	jrnz	..assign ; jump if assign successful
;
; Check for floppy assignment
	.ife	HARDshar,[
	lda	DSKdef	; density indicator
	cpi	'S'	; single density
	mvi	C,SDtab
	jrz	..flop
	cpi	'D'	; double density
	mvi	C,DDtab
	jrz	..flop
	cpi	'M'	; mini floppy, double sided
	mvi	C,Mtab
	jrnz	..ret
..flop:	lda	DSKdef+1; unit number (0-7)
	sui	'0'
	jrc	..ret
	cpi	8
	jrnc	..ret	; A is unit #
	mov	B,A	; save unit # in B
	]
	.ifn	HARDshar,[
	jmpr	..ret	; don't bother if hard boot
	]
;
; Process network, hard disk, or floppy assignment
..assign:
	.ife	CPMver-1,[
	call	CPMMAP	; get pointer to disk map
	mov	M,B	; overwrite map byte
	inx	H
	xchg		; DE = address of disk map
	dcr	C
	mov	A,C	; A = 0,1,2,3,4,5,or 6
	rlc
	rlc
	rlc
	mov	C,A	; C = 0,8,16,24,32,40,or 48
	mvi	B,0
	lxi	H,DSKtab
	dad	B	; compute disk table address
	lxi	B,8
	ldir		; overwrite disk map
;
; Move partition name into BIOS
	pop	H
	pop	B
	xchg
	mvi	A,27	; compute address of name
	sub	C
	mvi	B,0
	mov	C,A	; subtract unitno from 27
	dad	B
	xchg
	lxi	B,8	; move 8 bytes
	ldir
	ret
	]
	.ife	CPMver-2,[
	mov	A,D
	sta	VOLUME	; save the HD volume #
	call	CPMMAP	; get pointer to unit #
	push	H	; save addr of unit #
	mov	M,B	; overwrite unit #
	dcx	H	; point at media type
;
; Check if 8 inch single density
	mvi	A,SDtab
	cmp	C
	jrnz	..med1
	mvi	M,SD
	jmpr	..DPB
;
; Check if 8 inch double density
..med1:
	mvi	A,DDtab
	cmp	C
	jrnz	..med2
	mvi	M,DD
	jmpr	..DPB
;
; Check if 2-sided mini
..med2:
	mvi	A,Mtab
	cmp	C
	jrnz	..med3
	mvi	M,MINI2
	jmpr	..DPB
;
;
..med3:
			; code for 1-sided mini here
;
; Get media type and HD volume # from
; last ASSIGN if not floppy
	lda	MEDIUM
	mov	M,A	; store in media type byte
	dcx	H	; point at volume number
	lda	VOLUME
	mov	M,A	; store in volume # byte
	inx	H	; point at media type
;
; Compute DPB addr and put it in DE
..DPB:
	inx	H	; point at unit #
	inx	H	; point at DPB base
	xchg		; DE = address of DPB
;
; Compute offset into tbl of ASSIGNable devices
	dcr	C
	mov	A,C	; A = 0,1,2,3,4,5,6,or 7
	rlc
	rlc
	rlc
	rlc
	sub	C
	mov	C,A	; C = 0,15,30,45,60,75,90,105
	mvi	B,0
;
; Compute tbl addr and overwrite the DPB
	lxi	H,DSKtab
	dad	B	; compute disk table address
	lxi	B,15
	ldir		; overwrite disk map
;
; Move partition name into BIOS
	pop	H	; HL is addr of DPB
	lxi	D,10	; get ready to subtract
	ora	A	; reset carry
	dsbc	D	; compute destination of name
	pop	D	; get source of name
	pop	B	; throw away unit number
	xchg
	lxi	B,8	; move the name
	ldir
	ret
	]
;
; Can't assign, so set map byte to "unassigned"
; by setting media type and unit no. to 0FFh.
..ret:	pop	H
	pop	B
	call	CPMMAP
	mvi	M,0FFh	; unit number marked
	dcx	H
	mvi	M,0FFh	; media type marked
	ret
	.page
	.sbttl	'assign a hard disk partition'
;----------
; ASSIGN a hard disk partition
;  Regs in:  HL = address of partition name
;  Regs out: B = unit number
;	     C = size
;	     D = volume no
;	     E = control byte
;	     A = same as B
;  Regs destroyed:
;	     DE
;
upmast:	.byte	0FFh	; 0 if master is active
MEDIUM:	.byte	0	; mass storage medium last
			; ASSIGNed. =NET, HARD, SD,
			; DD, MINI1, MINI2
VOLUME:	.byte	0	; If MEDIUM=HARD or NET then
			; VOLUME= the HD volume #
;
; If network master, then let the BIOS handle it
ASSIGN:
	.ife	MASTopt,[
	lda	upMAST
	ora	A	; if master not up yet,
	jrnz	..hdass	;  then assign directly
	lxi	D,NETnam
	lxi	B,14
	ldir
	mvi	A,assnNET
	sta	NETcom	; set command byte last
	call	NETreq	; wait for master to wakeup
	lbcd	NETassn	; B = unitno, C = size
	lded	NETassn + 2; D = volume,E = control
	mov	A,B	; unitno in A as well
	push	H
	lxi	H,MEDIUM; point at media type
	mvi	M,NET	; Net partition assignment
	pop	H
	ret
	]
;----------
; If network station, then assign thru network
	.ife	(1-MASTopt)!NETboot,[
;
; Move partition name to net command area
..request:
	lxi	D,BOOTnam; setup command in boot area
	lxi	B,14
	ldir
;
; Wait for the master to poll
	mvi	A,assnNET
	sta	BOOTcom
..poll:	lxi	H,BOOTmsg
	lxi	B,1
	lda	NETusr
	call	RECNET
	bit	timeout,a
	jrz	..poll
;
	bit	pollRCV,a
	jrz	..poll	; wait for valid poll
;
	ani	crc$ovr	; crc or ovrun err
	jrnz	..poll
;
; Send assign request
	lxi	H,BOOTcom; send assign request
	lxi	B,15
	sub	A
	call	SENDNET
;
; Get response from master
..getresp:
	lxi	H,BOOTassn
	lxi	B,4
	lda	NETusr
	call	RECNET
	bit	timeout,a
	jrz	..retry
;
	ani	crc$ovr	; crc or ovrun err
	jrz	..success

..retry:
	lxi	h,DSKdef
	jmpr	..request
;
..success:
	lbcd	BOOTassn    ; B = unitno,C = size
	lded	BOOTassn + 2; D = volume,E = control
;
; Store the mass storage media type in RAM
	mvi	A,NET
	sta	MEDIUM
;
; Put the unit number in Acc
	mov	A,B
	ret
	]
;----------
; If booting from harddisk, assign directly
	.ife	HARDboot&MASTopt,[
..hdass:
	push	H
	mvi	A,assnHARD
	call	CMDHARD	; send assign command to disk
	pop	H
	lxi	B,14
	call	SENDHARD; send partition name and psw
	call	RESHARD	; get unit number and size
	lbcd	HARDstat
	lded	HARDstat + 2 ;D=volume, E = control
	mvi	A,HARD
	sta	MEDIUM	; mark this ASSIGN as HARD
	mov	A,B
	ret
	]
;----------
; Scratch areas
DSK0def	==	TPA	; default disk names
IOBdef	==	TPA+32	; default IOBYTE
INLENdef==	TPA+33	; length of type-ahead buffer
INBUFdef==	TPA+34	; default type-ahead buffer
;
DSKdef: .ascii	"PRTSPOOL" ; assignment work area
	.byte	0,0,0,0,0,0; ignore password
;---------
	.ife	MASTopt,[
;
; Twiddle thumb(s) while waiting for hard disk int
BURN.SP:.word	0
	.word	BURNcpu
BURNcpu:jmpr	.
;----------
; Get 2 digit number from input buffer
;  Regs in:  HL = address of input buffer
getnum:
	call	getdig	; get first digit
	cpi	0FFh
	rz		; return if illegal digit
	rlc
	mov	B,A
	rlc
	rlc
	add	B	; muliply first digit by 10
	mov	B,A
	call	getdig
	cpi	0FFh
	rz		; return if illegal digit
	add	B
	ret
;----------
; Get 1 digit from input buffer
getdig:
	mov	A,M
	inx	H
	sui	'0'
	jrc	..numerr
	cpi	10
	rc
..numerr:
	mvi	A,0FFh
	ret
	]
	.page
	.sbttl	'disk parameter tables'
;----------
; CP/M 1.4 disk parameter table
	.ife	CPMver-1,[
DSKtab:	.byte	128, 63,  3,  7,255,0C0h, 0, 0Ch
	.byte	128, 95,  4, 15,255,0C0h, 0, 0Ch
	.byte	128,127,  5, 31,255,080h, 0, 0Ch
	.byte	128,191,  6, 63,255,080h, 0, 0Ch
	.byte	128,254,  7,127,255,080h, 0, 0Ch
	.ife	HARDshar,[
SDtab	==	6
	.byte	 26, 63,  3,  7,242,0C0h, 2, 4Eh
DDtab	==	7
	.byte	 52,127,  4, 15,242,0C0h, 2, 0Ch
	]
	]
;----------
; CP/M 2.2 disk parameter table
	.ife	CPMver-2,[
DSKtab:
; 256K
	.word	128	; sectors per track
	.byte	3,7,0	; blk shift, blk and ext mask
	.word	255	; number of blocks - 1
	.word	63	; maximum directory number
	.byte	0C0h,0	; bits indicate directory blks
	.word   16	; check vector size
	.word	0	; number of op sys tracks
; 512K
	.word	128	; sectors per track
	.byte	4,15,0	; blk shift, blk and ext mask
	.word	255	; number of blocks - 1
	.word	127	; maximum directory number
	.byte	0C0h,0	; bits indicate directory blks
	.word   32	; check vector size
	.word	0	; number of op sys tracks
; 1M
	.word	128	; sectors per track
	.byte	4,15,0	; blk shift, blk and ext mask
	.word	511	; number of blocks - 1
	.word	255	; maximum directory number
	.byte	0F0h,0	; bits indicate directory blks
	.word	64	; check vector size
	.word	0	; number of op sys tracks
; 2M
	.word	128	; sectors per track
	.byte	4,15,0	; blk shift, blk and ext mask
	.word	1023	; number of blocks - 1
	.word	511	; maximum directory number
	.byte	0FFh,0	; bits indicate directory blks
	.word	128	; check vector size
	.word	0	; number of op sys tracks
; 4M
	.word	128	; sectors per track
	.byte	4,15,0	; blk shift, blk and ext mask
	.word	2047	; number of blocks - 1
	.word	1023	; maximum directory number
	.word	0FFFFh	; bits indicate directory blks
	.word	256	; check vector size
 	.word	0	; number of op sys tracks
; 8M
	.word	128	; sectors per track
	.byte	5,31,1	; blk shift, blk and ext mask
	.word	2047	; number of blocks - 1
	.word	1023	; maximum directory number
	.byte	0FFh,0	; bits indicate directory blks
	.word	256	; check vector size
	.word	0	; number of op sys tracks
;
SDtab	==	7
	.word	26	; sectors per track
	.byte	3,7,0	; blk shift, blk and ext mask
	.word	242	; number of blocks - 1
	.word	63	; maximum directory number
	.byte	0C0h,0	; bits indicate directory blks
	.word	16	; check vector size
	.word	2	; number of op sys tracks
DDtab	==	8
	.word	52	; sectors per track
	.byte	4,15,0	; blk shift, blk and ext mask
	.word	242	; number of blocks - 1
	.word	127	; maximum directory number
	.byte	0C0h,0	; bits indicate directory blks
	.word	32	; check vector size
	.word	2	; number of op sys tracks
Mtab	==	9
	.word	32	; sectors per track
	.byte	5,31,0	; blk shift, blk and ext mask
	.word	156	; number of blocks - 1
	.word	127	; maximum directory number
	.byte	080h,0	; bits indicate directory blks
	.word	32	; check vector size
	.word	3	; number of op sys tracks
	]	; CPMver-2
	]
	.page
	.sbttl	'cold boot messages and SIO command strings'
;----------
; CP/M cold-boot message
CPMmsg:
.ife	MASTopt,[.ascii	[cr][lf]'HiNet Master  ']
.ifn	MASTopt,[.ascii	[cr][lf]'CP/M  ']
	.byte	version+'0','.',revision/100+'0'
	.byte	(revision@100)/10+'0'
	.byte	(revision@100)@10+'0'
	.byte	patch
	.ife	MASTopt,[
crlf:	.ascii 	[cr][lf]
	]
	.byte	0
	.ife	MASTopt!HARDshar,[
DATEmsg:.asciz	[cr][lf]'Enter Date  MM/DD/YY - '
TIMEmsg:.asciz	[cr][lf]'Enter Time  HH:MM - '
LOGmsg:	.asciz	[cr][lf][lf]'Login please ... '
	]
	.ife	MASTopt,[
inituser:.ascii [0]'Unknown        '
	]
;----------
; SIO command strings
rs232:
	.byte	    18h	      ; channel reset
	.byte	14h,01001100b ; x16 clock, 2 stop bits
	.byte	 3,11100001b ; receiver enable
	.byte	 5,11101010b ; transmitter enable
	.byte	11h,00000100b; no interrupts
rs232$	==	.-rs232
;----------
; Floppy specify command
	.ife	FLOPopt&MINIopt,[
specFLOP:.byte	3	; specify command
	]
	.ife	MINIopt!(1-FLOPopt),[
	.byte	stp5
	]
	.ife	FLOPopt!(1-MINIopt),[
	.byte	stp8
	]
	.ife	FLOPopt!MINIopt,[
	.byte	stp8
	]
			; 35ms delay after head load
	.byte	02h	; 10ms delay after seek
	.byte	endcom
;----------
; Network login command	goes here
BOOTcom	==	8000h
BOOTnam	==	BOOTcom+1
BOOTpsw	==	BOOTnam+8
BOOTprom==	BOOTpsw+6
BOOTmsg	==	BOOTprom
BOOTassn==	BOOTnam
BOOTdate==	BOOTcom

BOOTresp==	BOOTcom+32
BOOTnum	==	BOOTresp+1
BOOTclk	==	BOOTnum+1
BOOTver	==	BOOTnum+15
	.reloc
	.page
	.sbttl	'warm boot'
	.prntx	'made it to warm boot'
;----------
; Warm boot
WBOOT:
	lxi	SP,80h	; setup a stack pointer
	mvi	A,(vectors>8)&0FFh
	stai		; setup interrupt register
	im2
	ei		; enable interrupts
	mvi	A,0C3h	; setup jump to WBOOT at 0,1,2
	sta	0
	lxi	H,BIOS+3
	shld	1
	sta	30h	; setup jump to WBOOT at 30-32
	shld	31h
	sta	5	; setup jump to BDOS at 5,6,7
	lxi	H,BDOS
	shld	6
	.ife	FLOPopt,[
	lda	Mode
	bit	modeCLDX,A
	jrz	..notcld
	lda	FLOPmdl
	ora	A
	jrz	..not850
	lda	stp8DS	; Shugart 850 (double-sided)
			; step rate
	sta	DS8flag ; Floppy specify cmd. flag
..not850:
..notcld:
	]
	.ife	MASTopt,[
	lxi	H,INTERUPT
	shld	LOCALtime+1	; Init INTERUPT jump
	]
	.ifn	MASTopt,[
	.ife	NETopt, [
	lxi	H,SETppa
	shld	BIOS+7Fh; Init SETppa jump
	lxi	H,PPAdefault
	shld	PPAadr	; Init poll-prime addr
	lxi	H,$4sec
	shld	Rtime	; Init RECNET timeout
	]
	]
;----------
; Warm boot from floppy
	.ife	FLOPboot&MINIboot,[
	call	RESULT	; flush floppy controller
	call	clrDDbf	; flush double-density buffer
	mvi	C,0FFh
	call	SELDSK	; select boot disk
	call	HOME	; home boot drive
	mvi	C,3	; start at sector 3
	call	SETSEC
	lxi	B,CPM
	call	SETDMA	; start at base of CP/M
	.ife	MINIboot,[lxi B,WBlen5]
	.ife	FLOPboot,[lxi B,WBlen8]
	call	SETBYT
	call	READ
	lxi	B,1
	call	SETTRK	; move to track 1
	mvi	C,1
	call	SETSEC	; start at sector 1
	.ife	MINIboot,[lxi B,CPM+WBlen5]
	.ife	FLOPboot,[lxi B,CPM+WBlen8]
	call	SETDMA
	.ife	MINIboot,[lxi B,lenCPM-WBlen5]
	.ife	FLOPboot,[lxi B,lenCPM-WBlen8]
	call	SETBYT
	call	READ
	lxi	B,128	; default DMA length
	call	SETBYT
;
	]		; Next comes jump to CCP
;
;----------
; Warm boot from hard disk
	.ife	HARDboot,[
	.ife	FLOPopt&MINIopt,[
	call	clrDDbuf
	]
	mvi	C,0FFh
	call	SELDSK	; select boot disk
	lxi	B,1
	call	SETTRK	; track 1
..nsect	==	(lenBOOT-CPM)/128
	mvi	C,129-..nsect
	call	SETSEC	; beginning sector
	lxi	B,128
	call	SETBYT
	lxi	H,CPM
	mvi	B,lenCPM/128
	call	READBLK
;
	]		; Next comes jump to CCP
;
;----------
; Warm boot from harddisk network
  .ife	HARDshar,[
    .ifn	MASTopt,[call ACKpoll]
    .ifn	MASTopt,[
	lxi	H,SETppa
	shld	BIOS+7Fh; Init SETppa jump
	]		; end ' not MASTopt '

	mvi	A,clrlockNET
	sta	NETcom
	call	NETreq	; clear all active locks

    .ife	SPOOLopt,[
	lda	SPOOLdsk
	ora	A	; check whether spooling active
	jrz	..ok	; jump if not active
;
	lxi	H,SPLmsg
	call	PRTMSG	; print spool message
	mvi	C,cntlZ
	call	PORTNout; flush spool buffer
..ok:
	]		; end ' SPOOLopt '

    .ife	FLOPopt&MINIopt,[
	mvi	C,0FFh
	call	SELDSK	; select boot disk
..nsect	==	(lenBOOT-CPM)/128

      .ife	MASTopt,[
	.ifg	..nsect-128, [..track == 5
			      ..sect  == 1-..nsect]
			     [..track == 6
		    	      ..sect  == 129-..nsect]
	]

      .ifn	MASTopt,     [..track == 2
			      ..sect  == 129-..nsect]
	lxi	B,..track
	call	SETTRK
	mvi	C,..sect
	call	SETSEC
	lxi	B,128
	call	SETBYT
	lxi	H,CPM
	mvi	B,lenCPM/128 ; read CP/M
	call	READBLK
	]			; FLOPopt&MINIopt
	]			; HARDshar
;----------
; Warm boot from floppy network
	.ife	FLOPshar,[
	.ifn	MASTopt,[call ACKpoll]
	.ife	MASTopt,[ mvi C,0]; master on drive 0
	.ifn	MASTopt,[ mvi C,1]; slave on drive 1
	call	SELDSK
	call	HOME
	mvi	C,3
	call	SETSEC
	lxi	B,128
	call	SETBYT
	lxi	H,CPM
	mvi	B,24	; read 24 sectors from track 0
	call	READBLK
	lxi	B,1
	call	SETTRK
	mvi	C,1
	call	SETSEC
	mvi	B,lenCPM/128-24; read rest of CP/M
	call	READBLK
;
	]
;
;---------------
; Jump to console command processor (CCP)
	lda	4
	mov	C,A	; get current disk number
;
	.ife	EXECopt, [
	lxi	H,CPM	; This entry executes CCP buff
	]
;
	lda	Mode
	bit	modeCLDX,A ; This bit says we are
			   ; cold booting
	jrz	..nocold
	res	modeCLDX,A ; Reset it now
	sta	Mode
;
	.ife	EXECopt, [
	jmpr	..exec	; Do cmd. if CLDX bit set
	]
;
..nocold:
;
	.ife	EXECopt, [
	bit	modeEXEC,A ; Check flag bit
	jrnz	..exec
	inx	H
	inx	H
	inx	H	; Point at no-exec entry pt.
..exec:
	pchl		; Jump to CCP
	]
;
	.ifn	EXECopt, [
	jmp	CPM	; This jump always executes
			; the CCP console buffer
			; contents. WBOOT must enter
			; the CCP here for cold-boot
			; initialization.
	]
;
;----------
; Read consecutive sectors from a disk
;  Regs in:   HL = DMA address
;	      B  = number of sectors to read
;  Regs out:  none
;  Destroyed: A, BC, DE, HL
	.ife	HARDboot&NETboot,[
READBLK:
	push	B	; save sector count
	shld	cpmDMA
	call	READ	; read one sector
	lxi	H,cpmSEC
	inr	M	; increment sector number
	mvi	A,129
	cmp	M	; check for sector too big
	jrnz	..ok
	mvi	M,1	; reset to sector 1
	lxi	H,cpmTRK
	inr	M	; increment track number
..ok:	lhld	cpmDMA
	lxi	D,128
	dad	D	; increment DMA address
	pop	B	; restore sector count
	djnz	READBLK
	ret
	]
	.page
	.sbttl	'conin,conout,const,list,reader,punch'
;----------
; IOBYTE implementation:
;
;	     LST:  PUN: RDR: CON:
;           ----------------------
; Defaults: | 010 | 1 |  01 | 00 |
;           ----------------------
;----------
; Console status
CONST:
	.ife	MASTopt,[
	call	WAITspool; wait for spool message
	]
	call	doCONIO
	.word	PORT0st	; TTY:	(default)
	.word	PORT2st	; CRT:
	.word	PAR1st	; BAT:
	.word	PRT3st	; UC1:
;----------
; Console input
	.ife	BACKopt, [inchar: .byte 0]
CONIN:
	.ife	BACKopt,[
	call	..conin
	sta	inchar	; save input character
	cpi	backsp
	rnz
	mvi	A,rubout; convert ^H to rubout
	ret
	]
..conin:
	.ife	MASTopt,[
	call	WAITspool; wait for spool message
	]
	call	doCONIO
	.word	PORT0in	; TTY:	(default)
	.word	PORT2in	; CRT:
	.word	PAR1in	; BAT:
	.word	PRT3in	; UC1:
;----------
; Console output
;
; The following silly code is needed so that backspace
; is handled properly with CP/M 1.4.  The code isn't
; needed for CP/M 2.2.
CONOUT:
	.ife	BACKopt,[
	mov	A,C	; ignore rubouts
	cpi	rubout	; (necessary for ED input mode)
	rz
	lda	inchar  ; check if input char was ^H
	cpi	backsp
	jrnz	FORCEout
	sub	A
	sta	inchar	; forget previous input char
	mov	A,C
	sui	20h	; echo control chars
	jrc	FORCEout	; (necessary for WORDSTAR)
	mvi	C,backsp
	call	FORCEout
	mvi	C,' '	; wipe out previous char
	call	FORCEout
	mvi	C,backsp; backspace onto blank
	]
FORCEout:
	.ife	MASTopt,[
	call	WAITspool; wait for spool message
	]
	call	doCONIO
	.word	PORT0out; TTY:	(default)
	.word	PORT2out; CRT:
	.word	PAR1out; BAT:
	.word	PRT3out; UC1:
;----------
; List output
LIST:
	lda	3
	rlc
	rlc
	rlc
	ani	7	; allow 8 LST: assignments
	call	DISPATCH

  .ife	ADDSopt,[.word PORTAout]
		[.word PORT0out]

	.word	PRT3out
	.word	PORT2out; CRT:	(default)
	.word	PORT1out
	.word	PORTPout; LPT:

  .ifn	(SELECT-2),[.word par1fox]
		   [.word CALLerr]

	.word	PORTUout; UL1:

  .ife	SPOOLopt,[.word PORTNout]
 		 [.word CALLerr]

;----------
; List status
	.ife	CPMver-2,[
LISTST:
	sub	A	; indicates not ready
	ret
	]
;----------
; Punch output
PUNCH:
	lda	3
	rrc
	rrc
	rrc
	rrc
	ani	1	; allow 2 PUN: assignments
	call	DISPATCH
	.word	PORT0out; TTY:
	.word	PRT3out; PTP:	(default)
;----------
; Reader input
READER:
	lda	3
	rrc
	rrc
	ani	1	; allow 2 RDR: assignments
	call	DISPATCH
	.word	PORT0in	; TTY:
	.word	PRT3in	; PTR:	(default)
;----------
; I/O dispatch routines
doCONIO:
	lda	3
	ani	3	; allow 4 CON: assignments
DISPATCH:
	rlc
	xthl
	mov	E,A
	mvi	D,0
	dad	D
	mov	A,M	; get jump vector
	inx	H
	mov	H,M
	mov	L,A
	xthl
	ret		; go to appropriate routine
	.page
	.sbttl	'type ahead code for various ports'

  .ife	AHEADopt,[
    .ifn	MASTopt,[
;----------
; Port 0 interrupt
PORT.SP:.word	0	; user's SP
	.byte	76h,76h,76h,76h,76h,76h,76h,76h
	.byte	76h,76h,76h,76h,76h,76h,76h,76h
PORTstack:
PORTint:
	push	PSW
    .ife	MASTopt,[
	lda	LOCALflag
	ora	A
	jrz	..saveregs
	]
	ei
..saveregs:
	sspd	PORT.SP	; save user registers
	lxi	SP,PORTstack
	push	H
	push	D
	push	B
	in	SIO1AD	; get the character
	ani	7Fh	; mask out parity bit
	mov	C,A
	lhld	nxtin	; L = nxtin, H = nxtout
	mov	A,L
	cmp	H	; check for nxtin=nxtout
	jrz	..full  ; if yes, buffer is full
	mvi	H,0
	lxi	D,PORT0buf
	dad	D	; point to next spot in buffer
	mov	M,C	; store char in buffer
	inr	A	; increment nxtin
	ani	typeahead ; use modulo arithmetic
	sta	nxtin	; save new value of nxtin
	jmpr	..ret
..full:
	mvi	C,bell	; ring bell if buffer full
	call	FORCEout
..ret:
	pop	B
	pop	D
	pop	H
	lspd	PORT.SP
	pop	PSW
	ei
	reti
	]	; end ' not master '

  .ife	MASTopt,[
getCHAR:
	in	SIO1AD	; get the character
	ani	7Fh	; mask out parity bit
	mov	C,A
	lhld	nxtin	; L = nxtin, H = nxtout
	mov	A,L
	cmp	H	; check for nxtin=nxtout
	ret

plusBUF:
	mvi	H,0
	lxi	D,PORT0buf
	dad	D	; point to next spot in buffer
	mov	M,C	; store char in buffer
	inr	A	; increment nxtin
	ani	typeahead ; use modulo arithmetic
	sta	nxtin	; save new value of nxtin
	ret
	]	; end ' MASTopt '
		; console polled in timer interrupt

;----------
; Port 0 status - type-ahead option
PORT0st:
	ei		; make sure interrupts enabled
	lhld	nxtin	; L = nxtin, H = nxtout
	mov	A,H
	inr	A	; increment nxtout
	ani	typeahead ; use modulo arithmetic
	mov	B,A	; save nxtout+1 for CONIN
	sub	L	; zero if nxtout+1=nxtin
	rz		; return if no char available
	mvi	A,0FFh	; CP/M wants A = 0FFh if yes
	ret
;----------
; Port 0 input - type-ahead option
PORT0in:
	call	port0st	; wait for character
	jrz	PORT0in
	mov	L,B	; add nxtout+1 to PORT0buf
	mvi	H,0
	lxi	D,PORT0buf
	dad	D	; point to char in buffer
	mov	A,M	; get the character
	lxi	H,nxtout
	mov	M,B	; update the nxtout pointer
	]
  .ifn	AHEADopt,[
;----------
; Console status
PORT0st:
	in	SIO1AC	; check port 0 status
	ani	1<RxRDY	; check for receiver ready
	rz
	mvi	A,0FFh	; CP/M wants A = 0FFh if yes
	ret
;----------
; Console input
PORT0in:
	call	PORT0st
	jrz	PORT0in
	in	SIO1AD	; read the character
	ani	7Fh	; mask out the parity bit
	]
;----------
; If network station, then intercept cntl-P
; and turn on ADDS AUX port
	.ife	ADDSopt,[
	cpi	cntlP
	rnz
	mov	B,A	; save input character
	lda	3	; check IOBYTE for LST device
	ani	0E0h
	mov	A,B	; restore input character
	rnz		; return if not AUX port
	lda	cntlPflg
	ora	A
	cma		; switch cntl-P flag
	sta	cntlPflg
	jrnz	..offAUX
	mvi	C,12h	; turn on AUX port
	call	AUXon
	jmpr	..ret
..offAUX:
	mvi	C,14h	; turn off AUX port
	call	AUXoff
..ret:	mvi	A,cntlP	; return cntl-P to BDOS
	]
	ret
;----------
; Port 0 output
PORT0out:
	.ife	ADDSopt,[
	lda	3	; check IOBYTE for LST device
	ani	0E0h
	jrnz	PORT0force; jump if not AUX port
	lda	cntlPflg; if cntl-P active, then
	ora	A	;  output char immediately
	jrnz	PORT0force
	lda	prntflg
	ora	A
	jrz	PORT0force; jump if print flag off
AUXoff:
	push	B
	mvi	C,1Bh	; send all chars to CRT
	call	PORT0force
	mvi	C,34h
	call	PORT0force
	pop	B
	sub	A	; turn off print flag
	sta	prntflg
	mvi	A,3
	out	SIO1AC
	mvi	A,0C1h
	out	SIO1AC	; turn off auto-enables
	]
PORT0force:
	in	SIO1AC
	ani	1<TxRDY
	jrz	PORT0force
	mov	A,C
	out	SIO1AD
	ret
	.ifn	NETopt,[
;-------
; Port 1 status
PORT1st:
	in	SIO1BC
	ani	1<RxRDY
	rz
	mvi	A,0FFh
	ret
;----------
; Port 1 input
PORT1in:
	call	PORT1st
	jrz	PORT1in
	in	SIO1BD
	ani	7Fh
	ret
;----------
; Port 1 output
PORT1out:
	in	SIO1BC
	ani	1<TxRDY
	jrz	PORT1out
	mov	A,C
	out	SIO1BD
	ret
	]
	.ife	NETopt,[
;----------
; Port 1 not available on network station
PORT1st:
PORT1in:
PORT1out:
	jmp	CALLerr
	]
;----------
; Port 2 status
PORT2st:
	in	SIO2AC
	ani	1<RxRDY
	rz
	mvi	A,0FFh
	ret
;----------
; Port 2 input
PORT2in:
	call	PORT2st
	jrz	PORT2in
	in	SIO2AD
	ani	7Fh
	ret
;----------
; Port 2 output
PORT2out:
	.ife	MASTopt,[
	lda	SPLdsk	; if spooler is active, then
	ora	A	; don't allow direct printing
	jnz	CALLerr
	]
	in	SIO2AC
	ani	1<TxRDY
	jrz	PORT2out
	mov	A,C
	out	SIO2AD
	ret
;
	.ife	AH3opt,[
;----------
; Port 3 interrupt
PRT3.sp:
	.word	0	; user's SP
	.byte	76h,76h,76h,76h,76h,76h,76h,76h
	.byte	76h,76h,76h,76h,76h,76h,76h,76h
P3stack:		; Interrupt stack pointer
P3int:
	push	PSW
  .ife	MASTopt,[
	lda	LOCALflag
	ora	A
	jrz	..saveregs
	]
	ei
..saveregs:
	sspd	PRT3.SP	; save user registers
	lxi	SP,P3stack
	push	H
	push	D
	push	B
	in	SIO2BD	; get the character
	mov	C,A
	lhld	nxt3in	; L = nxtin, H = nxtout
	mov	A,L
	cmp	H	; check for nxtin=nxtout
	jrz	..full  ; if yes, buffer is full
	mvi	H,0
	lxi	D,PRT3buf
	dad	D	; point to next spot in buffer
	mov	M,C	; store char in buffer
	inr	A	; increment nxtin
	ani	typeahead ; use modulo arithmetic
	sta	nxt3in	; save new value of nxtin
	jmpr	..ret
..full:
	mvi	C,bell	; ring bell if buffer full
	call	FORCEout
..ret:
	pop	B
	pop	D
	pop	H
	lspd	PRT3.SP
	pop	PSW
	ei
	reti
;----------
; Port 3 status - type-ahead option
PRT3st:
	ei		; make sure interrupts enabled
	lhld	nxt3in	; L = nxtin, H = nxtout
	mov	A,H
	inr	A	; increment nxtout
	ani	typeahead ; use modulo arithmetic
	mov	B,A	; save nxtout+1 for CONIN
	sub	L	; zero if nxtout+1=nxtin
	rz		; return if no char available
	mvi	A,0FFh	; CP/M wants A = 0FFh if yes
	ret
;----------
; Port 3 input - type-ahead option
PRT3in:
	call	PRT3st	; wait for character
	jrz	PRT3in
	mov	L,B	; add nxt3out+1 to PRT3buf
	mvi	H,0
	lxi	D,PRT3buf
	dad	D	; point to char in buffer
	mov	A,M	; get the character
	lxi	H,nxt3out
	mov	M,B	; update the nxt3out pointer
	ret
	]
	.ifn	AH3opt,[
;----------
; Port 3 status
PRT3st:
	in	SIO2BC
	ani	1<RxRDY
	rz
	mvi	A,0FFh
	ret
;----------
; Port 3 input
PRT3in:
	call	PRT3st
	jrz	PRT3in
	in	SIO2BD
	ret
	]
;
;----------
; Port 3 output
PRT3out:
	in	SIO2BC
	ani	1<TxRDY
	jrz	PRT3out
	mov	A,C
	out	SIO2BD
	ret
;
;----------
; Parallel Port 1 status
PAR1st:		; fox stations will use port0buf
		; for typeahead
  .ife	select-3,[
	call	port0st
	jrz	..ckPAR
;
	mvi	a,0ffh
	ret
	]

..ckPAR:
	in	PIOAD
	ani	40h	; Rx data rdy bit
	rz
;
	mvi	A,0FFh
	ret
;
;----------
; Parallel Port 1 input
PAR1in:
  .ife	select-3,[
	call	port0st
	jrz	..parIN
;
	call	port0in
	ret
	]

..parIN:
	call	PAR1st	; Check Rx status
	jrz	..parIN	; Loop until ready
;
..ckOUT:
	in	PIOAD	; crt controller must
	ani	20h	; take outCHAR before
	jrnz	..ckOUT	; bios will take inCHAR
;
	in	OFFPROM	; Same as DSC/3 PROM-OFF port
	ret
;
;----------
; Parallel Port 1 output
PAR1out:
	in	PIOAD
	ani	20h	; Check Tx status
	jrnz	PAR1out	; Loop if busy
	mov	A,C	; Put the char in the Acc
	out	OFFPROM	; Output the char
	ret
;
;----------
; List output on Centronix printer
PORTPout:
	.ife	MASTopt,[
	lda	SPLdsk	; if spooler is active, then
	ora	A	; don't allow direct printing
	jnz	CALLerr
	]
	in	PIOAD
	bit	6,A
	jrnz	PORTPout
	mov	A,C
	out	CENTP
	in	PPSTROBE
	ret
;-----------------------------
; List output on FOX hard disk parallel port
; no local HD allowed on FOX for this opt.
;
.ifn	(SELECT-2),[
par1fox:
	in	PIOAD
	bit	3,a	; data buffer full bit
	jrnz	par1fox
	bit	4,a	; printer busy bit
	jrnz	par1fox
	mov	a,c
	out	HARDP
	out	PPSTROBE; data valid strobe
	ret
	]	; end of 'if not master'
;----------
; List output on ADDS printer
	.ife	ADDSopt,[
PORTAout:
	lda	cntlPflg
	ora	A
	rnz		; return if cntl-P active
	lda	prntflg
	ora	A
	jnz	PORT0force; jump if printer flag on
	push	B
	mvi	C,1Bh	; send all chars to AUX port
	call	PORT0force
	mvi	C,33h
	call	PORT0force
	pop	B
	mvi	A,0FFh	; turn on printer flag
	sta	prntflg
AUXon:
	mvi	A,3
	out	SIO1AC	; turn on auto-enables
	mvi	A,0E1h
	out	SIO1AC
	jmp	PORT0force
prntflg:.byte	0	; print flag (off initially)
cntlPflg:.byte	0	; cntl-P flag(off initially)
	]

  .ife	SPOOLopt,[
;----------
; Print using HiNet spooler
PORTNout:
	lda	SPOOLdsk
	ora	A	; check if already spooling
	jrnz	..ok	; jump if yes
;
; Start a new spool job
	push	B
..newjob:
	call	NETstart; start spool job
	pop	B
	lda	SPOOLdsk
	ora	A	; error if no spool partition
	jz	SPOLerr	;  or no room in spool table
;
; Spool character
..ok:	lxi	H,SPOOLbuf
	lda	nxtNin
	mvi	D,0
	mov	E,A
	dad	D	; address in buffer
	mov	M,C	; stuff char in buffer
;
; Flush buffer and/or spool file if full
	push	B	; save char
	inr	A	; update buffer pointer
	cpi	lenNbuf
	jrnz	..cntlZ	; jump if buffer not full
	call	NETspool; flush buffer
	jrz	..cntlZ	; jump if file not full
	call	NETstop	; flush file
	jmpr	..newjob; try to open new file
..cntlZ:
	pop	B	; restore char
	sta	nxtNin	; save new buffer pointer
	mov	A,C
	cpi	cntlZ
	rnz		; return if not cntlZ
;
; Terminate spool job
	call	NETspool; flush spool buffer
	call	NETstop	; terminate spool job
	sub	A
	sta	nxtNin	; reset buffer ptr
	sta	SPOOLdsk; not spooling anymore
	ret
;----------
; Spool buffer
;
SPLmsg:	.asciz	[cr][lf]"Spooled"
lenNbuf	==	128	; length of spool buffer
SPOOLbuf:.blkb	lenNbuf	; spool buffer
nxtNin:	.byte	0	; spool buffer pointer
	]
	.page
	.sbttl	'SELDSK select disk drive'
;----------
; Select disk drive
SELDSK:
	.ife	CPMver-1,[
	mov	A,C
	cpi	0FFh	; check for boot disk
	jrz	..ok
	ani	03h	; mask out disk number
..ok:	sta	cpmDSK	; save current disk number
	call	cpmMAP	; get pointer to disk map
	inx	H	; point to overlay string
	lxi	D,BDOS+34h ; address in CP/M to overlay
	lxi	B,7	; number of bytes to overlay
	ldir
	mvi	E,15h	; overlay CP/M instruction
	mov	A,M	;  at BDOS+15h
	stax	D	; instr is 'MOV C,M' or 'INR C'
	ret
	]
	.ife	CPMver-2,[
	mov	A,C
	cpi	0FFh	; check for boot disk
	jrz	..ok
	cpi	4	; check for bad disk selection
	jrc	..ok
	lxi	H,0	; return HL = 0 to CP/M
	ret
..ok:	sta	cpmDSK	; save current disk number
	call	cpmMAP	; get pointer to disk map
;
	.ife	FLOPopt&MINIopt,[
	push	H
	push	D
	push	PSW
	dcx	H
	mov	A,M
;
	.ife	FLOPopt,[
	cpi	SD
	cz	set8SD
	cpi	DD
	cz	set8DD
	]
;
	.ife	MINIopt,[
	cpi	MINI1
	cz	set5
	cpi	MINI2
	cz	set5
	]
;
	pop	PSW
	pop	D
	pop	H
	]
;
	xchg		; return pointer to DPB
	ret
	]
	.page
	.sbttl	'Floppy specify routines for SELDSK'
;----------
; Set max sector for 8 inch SD
	.ife	FLOPopt,[
set8SD:
	push	PSW
	mvi	A,sect8SD
	sta	MAXsec
	mvi	A,gap8SD
	sta	FLOPgap
	lda	DS8flag
	call	SPEC
	pop	PSW
	ret
	]
;
;----------
; Set max sector for 8 inch DD
	.ife	FLOPopt,[
set8DD:
	push	PSW
	mvi	A,sect8DD
	sta	MAXsec
	mvi	A,gap8DD
	sta	FLOPgap
	lda	DS8flag
	call	SPEC
	pop	PSW
	ret
	]
;
;----------
; Set 5 inch params
	.ife	MINIopt,[
set5:
	push	PSW
	mvi	A,sect5
	sta	MAXsec
	mvi	A,gap5
	sta	FLOPgap
	mvi	A,stp5
	call	SPEC
	pop	PSW
	ret
	]
;
;----------
; Specify floppy cmd.
; entry>	a = step rate
  .ife	FLOPopt&MINIopt,[
SPEC:
	push	H
	push	D
	push	B
	mov	b,a	; save step rate
	in	FLOPSR
	cpi	80h
	jrnz	..ret	; return if no floppy
;
	mov	a,b	; restore step rate
	sta	spFLOP+1
	lxi	H,spFLOP
	call	COMMAND
..ret:
	pop	B
	pop	D
	pop	H
	ret
;
spFLOP:
	.byte	03h	; specify command
	.byte	stp8	; step rate
	.byte	02h	; use dma
	.byte	0FFh
	]		; end ' either floppy '

  .ife	FLOPopt,[
DS8flag:.byte	stp8	; Changed by CBOOT if
			; Shugart 850
	]		; end ' if 8 inch '
;
	.page
	.sbttl	'SETTRK set track'
;----------
; Set track
SETTRK:
	.ife	CPMver-1,[
	mov	A,C
	sta	cpmTRK	; save current track number
	]
	.ife	CPMver-2,[
	sbcd	cpmTRK	; save current track number
	]
	ret
;----------
; Set sector
SETSEC:
	mov	A,C
	sta	cpmSEC	; save current sector number
	ret
;----------
; Set DMA address
SETDMA:
	sbcd	cpmDMA	; save current DMA address
	ret
;----------
; Set DMA size
SETBYT:
	sbcd	cpmBYT	; save current DMA size
	ret
;----------
; Sector translate
	.ife	CPMver-2,[
SECTRAN:
	push	D	; save translation table ptr
	call	cpmMAP	; get current map byte
	dcx	H	; point at disk media type
	mov	A,M	; put it in A
	pop	H	; restore translation table ptr
	cpi	SD	; is it single density
	jrz	..sd	; jump if current disk is SD
	mov	H,B	; otherwise, compute sector+1
	mov	L,C
	inx	H
	ret
..sd:	dad	B	; single density translation
	mov	L,M
	mvi	H,0
	ret
	]
	.page
	.sbttl	'HOME,SEEK, DELAY'
;----------
; Home to track 0
HOME:	lxi	H,0
	shld	cpmTRK	; set track to 0
	.ife	FLOPopt&MINIopt,[
	call	cpmMAP
	dcx	H
	mov	A,M
;
	.ife	FLOPopt,[
	cpi	SD
	jrz	..flop
	cpi	DD
	jrz	..flop
	]
;
	.ife	MINIopt,[
	cpi	MINI2
	jrz	..flop
	]
;
	ret		; return if not floppy
..flop:			; arrive here if floppy
;----------
; Recalibrate a drive
reHOME:
	lda	cpmDSK
	sta	iobDSK	; iob is used in iobMAP
	lxi	H,homeFLOP+1
;----------
; Seek a track (used by HOME and READ/WRITE)
SEEK:	push	H	; save adr of current command
	call	iobMAP	; get current disk map
	pop	H
	mov	M,A	; store unit# into cur command
	dcx	H	; point to beg of curr command
	push	H	; in case of NRDYerr
	call	onMOTOR	; turn on the drive motor
	mvi	c,0	; flag for same track test
..seek:
	call	COMMAND
..sense:
	lxi	H,IsenseFLOP
	call	COMMAND	; sense interrupt status
	call	RESULT
	lda	FLOPstat; get first result byte
	mov	B,A	; save status byte
	ani	03
	push	b
	mov	c,a
	call	iobmap
	ani	03
	cmp	c
	pop	b
	jrnz	..sense
;
	mov	a,b
	ani	48h	; bit 7=0,6=1,3=1 --
	cpi	48h	; seek terminated
			; due to NRDY err
	jrz	NRDYerr	; NRDYerr is on curr drive
;
	mov	A,B
	bit	5,A	; check seek-done bit (st0,b5)
	jrnz	..skDONE
;
	inr	c
	jmpr	..sense
;
..skDONE:
	pop	H	; clean up stack
	ani	0D0h	; check if seek ok
	jrnz	..skERR	; Jump if seek error
;
	mov	a,c
	ora	a
	jrz	..idle
;
	lxi	b,StepSettle
	call	delay

..idle:
	call	idleMOTOR ; turn off motor in 1 second
	ret

..skERR:
	lda	Mode
	bit	0,a
	jrnz	reHome
;
	pop	b
	call	idleMOTOR
	mvi	a,0ffh
	ret
;
;----------
; Delay loop (delay count in BC)
DELAY:	dcx	B
	mov	A,B
	ora	C
	jrnz	DELAY
	]
	ret
;
NRDYerr:call	IOERR
	pop	H	; SEEK will save HL again
	inx	H
	jmp	SEEK
;
;
		.page
	.sbttl	'READ and WRITE disk'
;----------
; Read disk
READ:
	call	cpmMAP	; determine device type
	cpi	0FFh
	jz	CALLerr	; error if unassigned
	dcx	H	; point at device byte
	mov	A,M	; put it in Acc
;
	.ife	FLOPopt,[
	cpi	SD	; check for single density
	jz	SDrd	; SD if 8 inch disks
	cpi	DD	; check for double density
	jz	DDrd
	]
;
	.ife	MINIopt,[
	cpi	MINI2	; check if 2-sided floppy
	jz	M2rd
	]
;
	.ife	NETopt,[
	cpi	NET	; check for network
 	jz	NETrd
	]
;
	.ife	HARDopt,[
	cpi	HARD	; check for hard disk
 	jz	HARDrd
	]
;
	jmp	CALLerr ; if none of the above - error
;----------
; Write disk
WRITE:	call	cpmMAP	; determine device type
	cpi	0FFh
	jz	CALLerr	; error if unassigned
	dcx	H	; point at device type
	mov	A,M	; put it in Acc
;
	.ife	FLOPopt,[
	cpi	SD	; check for single density
	jz	SDwr	; SD 8 inch
	cpi	DD	; check for double density
	jz	DDwr
	]
;
	.ife	MINIopt,[
	cpi	MINI2	; check for 2-sided floppy
	jz	M2wr
	]
;
	.ife	NETopt,[
	cpi	NET	; check for network
 	jz	NETwr
	]
;
	.ife	HARDopt,[
	cpi	HARD	; check for hard disk
 	jz	HARDwr
	]
;
	jmp	CALLerr ; if none of the above - error
	.page
	.sbttl	'floppy disk reads and writes'
	.ife	FLOPopt&MINIopt,[
	.ife	FLOPopt,[
;----------
; Single Density read
SDrd:
	lxi	D,7Dh<8+readDMA ; set up params
	mvi	B,rdSDFLOP
	jmp	SDfloppy
;---------
; Single Density write
SDwr:
	lxi	D,79h<8+writeDMA ; set up params
	mvi	B,wrSDFLOP
;----------
; Single Density Floppy (Read and Write common)
SDfloppy:
	lhld	cpmDMA	; set DMA address
	shld	DMAFadr
	lhld	cpmBYT  ; set DMA size
	dcx	H	; DMA wants size - 1
	shld	DMAFsize
	mvi	A,0	; set FLOPPY density
	sta	FLOPden
	lhld	cpmDESC	; iobDESC <- cpmDESC (3)
	shld	iobDESC
	lda	cpmSEC
	sta	iobPSEC	; physical sector is cpmSEC
	jmp	Floppy
	]
;----------
; Double Density read
;
	.ife	FLOPopt,[
DDrd:
	lda	cpmTRK	; track 0 DD is SD
	ora	A
	jrz	SDrd
	jmpr	rd5or8
	]
;
	.ife	MINIopt,[
M2rd:			; Entry point for 2-sided mini
	]
;
rd5or8:
	lda	cpmBYT	; 256+ byte read operation
	ora	A	; (low byte = 0)
	jz	DDrdspec
	lded	cpmDESC ; is sector in wrbuffer
	lhld	wrbDESC
	ora	A
	dsbc	D
	jrnz	..1
	lda	cpmSEC
	mov	B,A
	lda	wrbSEC
	sub	B
	jrnz	..1	; if not then read from disc
	lded	cpmDMA	; else just get it from wrbuf
	lxi	H,wrbuffer
	lxi	B,128
	ldir
	ret
;
..1:	call	convIC	; set up iobDESC
	call	DDrdflop ; read the disc
	push	PSW	; save I/O status
	lda	iobSEC	; move 128 byte block from
	rrc		; get rightmost bit
	lxi	H,rdbuffer ; set rdbuffer high or low
	jrc	..2	; depending on leftmost bit
	lxi	H,rdbuffer+128
..2:	lded	cpmDMA	; move rdbuffer to curDMA
	lxi	B,128
	ldir
	pop	PSW	; restore I/O status
	ret
;----------
; Double Density write
DDwr:
	.ife	FLOPopt,[
	lda	cpmTRK	; track 0 DD is SD
	ora	A
	jz	SDwr
	jmpr	wr5or8
	]
;
	.ife	MINIopt,[
M2wr:			; Entry for double-sided mini
	]
;
wr5or8:
	lda	cpmBYT	; check for 256+ byte operation
	ora	A
	jz	DDwrspec
	lda	cpmSEC	; check for high-low sector
	rrc
	jrnc	DDwrhigh
DDwrlow:
	call	clrDDbf	; flush wrbuffer
	call	convIC	; wrbDESC <- cpmDESC
	lhld	iobDESC	; through iobDESC
	shld	wrbDESC
	lhld	iobDESC+2
	shld	wrbDESC+2
	lhld	cpmDMA	; write 128 bytes to low wrb
	lxi	D,wrbuffer
	lxi	B,128
	ldir
	sub	A	; return A = 0
	ret
DDwrhigh:
	call	convIC  ; iob is now cpm
	lxi	H,wrbDESC ; is low already in buffer
	call	cmpIOB
	jrz	..1
	call	clrDDbf	; if not flush wrbuffer
	call	convIC	; read low wrbuffer from disc
	call	DDrdflop ; for read-modify-write
	lxi	H,rdbuffer ; modify low 128 bytes
	lxi	D,wrbuffer
	lxi	B,128
	ldir
..1:	lhld	cpmDMA	; move in upper 128 bytes
	lxi	D,wrbuffer+128
	lxi	B,128
	ldir
	call	DDwrflop ; write out the buffer
	ret
;
;----------
; Flush (clear) the Double Density wrbuffer
clrDDbf:
	lda	wrbPSEC	; is buffer full
	ora	A
	rz		; return if empty
	lxi	H,wrbDESC ; otherwise read-modify-write
	lxi	D,iobDESC ; first set iobDESC
	ldi
	ldi
	ldi
	call	DDrdflop ; read
	lxi	H,rdbuffer+128 ; modify
	lxi	D,wrbuffer+128
	lxi	B,128
	ldir
	call	DDwrflop ; write
	ret
;----------
; Compare 3 bytes, (HL) and iobDESC
cmpIOB:
	lda	iobDSK	; test DISK byte
	cmp	M
	rnz
	lda	iobTRK	; test TRACK byte
	inx	H
	cmp	M
	rnz
	lda	iobPSEC	; compare physical sector
	inx	H
	cmp	M
	ret
;----------
; Move cpmDESC to iobDESC and convert PSEC for DD
convIC:
	lhld	cpmDESC	; two bytes at a time
	shld	iobDESC
	lda	cpmSEC	; store sector
	sta	iobSEC
	adi	1	; and calculate PSEC
	srlr	A
	sta	iobPSEC ; and store it
	ret
;----------
; Double Density special 256+ byte read
DDrdspec:
	lxi	D,7Dh<8+readDMA ; load r/w params
	mvi	B,rdDDFLOP
	jmpr	DDspec
;----------
; Double Density special 256+ byte write
DDwrspec:
	lxi	D,79h<8+writeDMA ; load r/w params
	mvi	B,wrDDFLOP
;
; Double Density special 256+ byte read/write
DDspec:
	lhld	cpmBYT	; set DMA size
	dcx	H	; DMA wants size - 1
	shld	DMAFsize
	lhld	cpmDMA	; set DMA address
	shld	DMAFadr
	call	convIC	; set up iobDESC
	jmpr	DDsflop	; jump to middle of DDfloppy
;----------
; Special read double density for buffer
DDrdflop:
	lxi	H,rdbDESC ; is buffer in memory
	call	cmpIOB
	jrnz	..1
	mvi	A,0	; if so, return 0
	ret
..1:	lxi	H,iobDESC ; otherwise load rdbDESC
	lxi	D,rdbDESC ; with iob to reflect new
	ldi		  ; rdbuffer
	ldi
	ldi
	lxi	D,7Dh<8+readDMA ; set up params
	mvi	B,rdDDFLOP ; for double density read
	lxi	H,rdbuffer ; set DMA address
	shld	DMAFadr
	jmpr	DDfloppy
DDwrflop:
	lxi	H,rdbDESC ; is rdbuffer the same as
	call	cmpIOB	  ; wrbuffer
	jrnz	..1
	lxi	H,wrbuffer ; if so update rdbuffer
	lxi	D,rdbuffer
	lxi	B,256
	ldir
..1:	lxi	H,0
	shld	wrbPSEC	; set wrbuffer empty
	lxi	D,79h<8+writeDMA ; load params for
	mvi	B,wrDDFLOP ; double density write
	lxi	H,wrbuffer ; set DMA address at wrbuf
	shld	DMAFadr
;----------
; Double Density Floppy (Read and Write common)
DDfloppy:
	lxi	H,255	; set DMA size
	shld	DMAFsize
DDsflop:mvi	A,1	; set FLOPPY density
	sta	FLOPden
;----------
; Floppy read/write -  single/double density
;
; Setup the DMA chip
Floppy:
	mov	A,E
	sta	DMAFc2	; read/write command
	mov	A,D
	sta	DMAFc1	; read/write command also
;
; Setup the floppy read/write command
	mov	A,B
	sta	FLOPcom	; read/write command
	lda	iobPSEC	; set sector number
	sta	FLOPsec

; Normally, retry 10 times before printing error msg
	lxi	H,RTRYflop
	mvi	M,RETRY+1; 10 retries on any error

; If using FDTEST, don't retry errors
	lda	Mode
	bit	ModeTRY,A
	jrnz	tryf
;
	mvi	M,1	; 0 retries on any error
tryf:
;
	.ife	FLOPopt!MINIopt,[
	call	iobMAP
	dcx	H
	mov	A,M	; media type in Acc
	cpi	SD
	jrz	..trf8
	cpi	DD
	jrz	..trf8
	cpi	MINI1
	jrz	..trf5
	cpi	MINI2
	jrz	..trf5
	]
;
	.ife	FLOPopt,[
..trf8:
	call	IOBmap	; get current disk map
	sta	FLOPdsk	; drive number
	rrc
	rrc
	ani	1
	sta	FLOPsid	; side number
	lda	iobTRK	; track number
	sta	FLOPtrk
	]
;
	.ife	MINIopt,[
..trf5:
	mvi	B,0	; init for later
	lda	IOBtrk	; get track #
	mov	C,A	; track # in C
	cpi	80
	jrc	..side0	; side 0 if track < 80
	inr	B	; make it side 1
	mvi	A,159
	sub	C	; compute phys trk #
	mov	C,A	; put it in C
..side0:
	sbcd	FLOPtrk	; store this mess at FLOPtrk
	call	IOBmap
	ani	3	; drive # in A
	mov	C,A	; store in C
	mov	A,B
	add	A
	add	A	; A <- B * 4
	ora	C	; drive is 0-3 or 4-7
	sta	FLOPdsk	; store it
	]
;
; Seek for I/O track
begRTRY:
	lxi	H,seekFLOP+2 ; move track into command
	lda	FLOPtrk	; Get track for next operation
	mov	M,A
	dcx	H
	call	SEEK	; go to tracks 1-76
;
; Set up the DMA chip
begDMA:	call	lockDMA	; reserve the DMA chip
	lxi	H,DMAFdone
	shld	DMAvect	; setup the DMA vector
	sub	A
	out	PIOAD	; multiplex floppy to DMA
	lxi	H,DMAFprog
	lxi	B,DMAF$<8+DMA
	outir		; program the DMA chip
;
; Execute the floppy command
 	lxi	H,FLOPcom
	mvi	a,0ffh
	sta	FLOPbusy; floppy is busy
	call	COMMAND
	ei		; interrupts OK now
	call	RESULT
	lda	FLOPbusy
	ora	A	; dont reset DMA if int occured
	jrz	..noERR
;
	di		; no interrupts allowed
	mvi	A,0C3h	; reset DMA so that errors
	out	DMA	;  are handled OK
	sub	A
	sta	lockbyte; unlock the DMA chip
	sta	FLOPbusy
	ei		; allow interrupts again
..noERR:
	call	idleMOTOR; don't need motor anymore
	lda	FLOPstat; get first result byte
	ani	0C0h	; mask out top 2 bits
	rz		; return to CP/M if no errors
;
; Check for recoverable errors
	lxi	H,RTRYflop	; floppy err retry cnt
	lxi	B,FLOPstat+3	; point to THS
	lda	FLOPstat+2
	bit	5,A
	jrz	chkTRAC
	dcr	M
DATAerr:cz	IOERR	; data CRC error (st2,b5)
	jmp	retryf
chkTRAC:bit	4,A
	jrz	chkMADR
	dcr	M
TRACerr:cz	IOERR	; on wrong track (st2,b4)
	call	reHOME	; rehome disk and try again
	jmp	retryf
chkMADR:bit	0,A
	jrz	chkID
	dcr	M
MADRerr:cz	IOERR	; missing or deleted data
			; address mark (st2,b0)
	jmp	retryf
chkID:	lda	FLOPstat+1
	bit	5,A
	jrz	chkSECT
	dcr	M
IDerr:	cz	IOERR	; ID CRC error (st1,b5)
	jmp	retryf
chkSECT:bit	2,A
	jrz	chkENDT
	dcr	M
SECTerr:cz	IOERR	; cannot find sector (st1,b2)
	jmp	retryf
chkENDT:bit	7,A
	jrz	chkDENS
	dcr	M
ENDTerr:cz	IOERR	; read beyond end-of-track
			; (st1,b7)
	jmp	retryf
chkDENS:bit	0,A
	jrz	chkORUN
	dcr	M
DENSerr:cz	IOERR	; missing ID address mark
			; (st1,b0)
	jmp	retryf
;
; Non-recoverable errors
chkORUN:bit	4,A
	jrz	chkPROT
ORUNerr:call	IOERR	; overrun -DMA failure (st1,b4)
	jmp	retryf
chkPROT:bit	1,A
	jrz	WHATerr
PROTerr:call	IOERR	; write-protected (st1,b1)
	jmp	retryf
WHATerr:call	IOERR	; unknown error
	jmp	retryf
;
;-------
; Recalibrate and retry if any error encountered
retryf:	lxi	H,errFLOP
	inr	M		; incr flop err cnt
	jmp	begRTRY		; re-execute failed cmd
;
;----------
; Handle the transfer-done interrupt from the DMA chip
FLOPbusy:.byte	0	; 0FFh if busy, 0 if not busy
DMAFdone:
	push	PSW
	in	STOPFLOP; reset the floppy chip
	mvi	A,0C3h
	out	DMA	; reset the DMA chip
	sub	A
	sta	lockbyte; unlock the DMA chip
	sta	FLOPbusy; floppy not busy anymore
	pop	PSW
	ei
	ret
;----------
; Send a command to the floppy controller
;  Regs in:   HL = address of command string
;  Regs out:  none
;  Destroyed: A, HL
COMMAND:
	mov	D,H
	mov	E,L	; Copy HL to DE
	mvi	A,endcom
	sta	FLOPstat; mark end of floppy command
..1:
	mov	A,M
	cpi	endcom
	rz		; return if end-of-command
	call	WAITDR
	jrnc	..2	; Jump if no 'SYNC' error
	call	RESULT	; SYNC err - clear result reg.
	xchg		; Put cmd. start addr. in HL
	jmpr	COMMAND	; Restart cmd. sequence
..2:
	mov	A,M
	out	FLOPDR	; send a byte to controller
	inx	H	; point to next byte
	jmpr	..1
;----------
; Collect a result from the floppy controller
;  Regs in:   none
;  Regs out:  none
;  Destroyed: A, HL
RESULT:
	lxi	H,FLOPstat
..stat:
	call	WAITDR	; wait for first status byte
	rnc		; return if no status bytes
;
	in	FLOPDR	; get a result byte
	mov	M,A	; store it away
	inx	H
	adi	0	; NEC says wait min 12 uSec
	adi	0	; to poll 765 status
	jmpr	..stat

;----------
; Wait until floppy data register is ready
;  Regs in:   none
;  Regs out:  A = status register, shifted left by 1
WAITDR:
	in	FLOPSR
	rlc
	jrnc	WAITDR
	rlc
	ret
;
;----------
; onMOTOR - turn on a drive motor and pre-compensate
;  Regs in:   A = drive number
;  Regs out:  none
;  Destroyed: A, BC
;
; PreComp is determined as follows:
;	qComp	=	bit 5  > H to use PreComp
;	S/L*	=	bit 4  > H to use small PreComp
;	LCT	=	FDC    > H to use low current
;				 -toggles at track 42
;
;     Track	qComp	S/L*	LCT
;     -----	---------------------
;   000 - 021  |  L   |	 H   |	 L   |	no preComp
;   022 - 058  |  H   |  H   |  L/H  |  62.5 / 125 uSec
;   059 - 079  |  H   |  L   |   H   |	250    uSec
;   080 - 100  |  H   |  L   |   H   |  250    uSec
;   101 - 137  |  H   |  H   |  H/L  |  125  / 62.5 uSec
;   138 - 159  |  L   |  H   |   L   |  no preComp

curMOTOR:.byte	0FFh	; current drive

onMOTOR:
	push	PSW	; save new drive number
	mov	B,A
	res	5,b	; init to no preComp
	set	4,b	; default to small
;
	lda	iobTRK	; turn on preComp if track
	cpi	OnPreCmp; is greater than 21
	jrc	..LdHead
;
	cpi	160-OnPreCmp	; and less than 138
	jrnc	..LdHead
;
	set	5,B	; bit 5 = preComp
;
	cpi	maxprec	; reset S/L* bit if track
	jrc	..LdHead; is greater than 58
;
	cpi	160-MaxPrec
	jrnc	..LdHead; and less than 101
;
	res	4,b	; bit 4 = S/L*
..LdHead:
	set	2,B	; bit 2 = head load
	di		; disallow timer interrupt
	lda	timeMOTOR
	mov	C,A
	mov	A,B
	out	PIOBD
	sub	A	; force motor on until idle
	sta	timeMOTOR
	ei		; interrupts OK now
	pop	PSW	; get new drive number
	mov	B,A
	lda	curMOTOR; get old drive number
	cmp	B
	jrnz	..delay	; force delay if old <> new
;
	mov	A,C	; if old time is zero, then
	ora	A	; do head load/motor on delay
	rnz

..delay:
	mov	A,B
	sta	curMOTOR; save current drive number
	push	h
	push	d
	call	cpmMAP	; get drive type
	dcx	h
	mov	a,m
	pop	d
	pop	h
	cpi	MINI2
	lxi	b,wait4motor	; 180 mSec delay for 5"
	jz	delay		; motor to hit speed
;
	lxi	B,loadset	; 36 mSec delay for
	jmp	DELAY		; 8" head load settle
;
;----------
; idleMOTOR - the motor can be turned off now
idleMOTOR:
	mvi	A,unloadHEAD ; wait 60 clock ticks,
	sta	timeMOTOR;  then turn off the motor
	ret
;----------
; offMOTOR - turn off all drive motors
;
; This routine is called from TIMERint.  It is called
;  when the floppy motor counter reaches zero.
offMOTOR:
	call	clrDDbuf; clear double density buffer
	mvi	A,0
	out	PIOBD	; unload the head
	ret
;----------
; Floppy controller commands
endcom	==	0FFh	; command terminator
homeFLOP:
	.byte	7	; recalibrate command
	.byte	0	; curDSK
	.byte	endcom
seekFLOP:
	.byte	15	; seek command
	.byte	0	; curDSK
	.byte	0	; curTRK
	.byte	endcom
IsenseFLOP:
	.byte	8	; sense interrupt status
	.byte	endcom
;
;----------
; DMA command
DMAFprog:
	.byte	0C3h	; master reset		2D
	.byte	0C7h	; reset port A		2D
	.byte	0CBh	; reset port B		2D
DMAFc1: .byte	0	; filled by Floppy	1A
DMAFadr:.word	0	; filled by Floppy
DMAFsiz:.word	0	; filled by Floppy
	.byte	14h	; port A inc, memory    1B
	.byte	28h	; port B fixed, I/O	1B
	.byte	95h	; byte mode		2B
	.byte	FLOPP 	; port B
	.byte	12h	; interrupt at end of block
	.byte	DMAvect&0FFh ; interrupt vector
	.byte	9Ah	; stop at end of block
	.byte	0CFh	; load starting address 2C
DMAFc2: .byte	0	; filled by Floppy 	2D
	.byte	0CFh	; load starting address 1A
	.byte	0ABh	; enable interrupts	2D
	.byte	87h	; enable DMA		2D
DMAF$	==	.-DMAFprog
	]
	.page
	.sbttl	'hard disk reads and writes'
	.prntx	'made it to hard disk r/w'
	.ife	HARDopt,[
;----------
; Hard disk read
HARDrd:
	.ifn	MASTopt, [call HARDprep]
	.ife	MASTopt, [jmp  CALLerr ]
;
; Regs in: HL = DMA address
;	   DE = track number     (0-511)
;	   B  = HD volume number (0-3)
;	   C  = sector number	 (1-128)
;	   A  = unit number (0-63)
;
HARDr:	push	H	; save DMA address
	call	HARDrw
	mvi	A,readHARD
	call	CMDhard	; send read command
	call	REShard ; get result status
	pop	H
	rnz		; ret if error
;
	lxi	B,128
	call	REChard	; get data bytes
	xra	a
	ret
;----------
; Hard disk read 1K
;
; Regs in: HL = DMA address
;	   DE = track number     (0-511)
;	   B  = HD volume number (0-3)
;	   C  = sector number	 (1-128)
;	   A  = unit number (0-63)
;
HARD1:	push	H	; save DMA address
	call	HARDrw
	mvi	A,read1HARD
	call	CMDhard	; send read command
	call	REShard ; get result status
	pop	H
	rnz		; ret if error
;
	lxi	B,1024
	call	REChard	; get data bytes
	xra	a
	ret
;----------
; Hard disk write
HARDwr:
	.ifn	MASTopt, [call HARDprep]
	.ife	MASTopt, [jmp  CALLerr ]
;
; Regs in: HL = DMA address
;	   DE = track number     (0-511)
;	   B  = HD volume number (0-3)
;	   C  = sector number	 (1-128)
;	   A  = unit number (0-63)
;
HARDw:	push	H	; save DMA address
	call	HARDrw
	mvi	A,writeHARD
	call	CMDhard	; send write command
	pop	H
	lxi	B,128
	call	SENDhard; send data bytes
	call	REShard	; get result status
	ret
;----------
; Prepare hard disk parameters
	.ifn	MASTopt,[
HARDprep:
	call	cpmMAP
	mov	D,A	; store unit # in D
	dcx	H
	dcx	H
	mov	B,M	; volume # in B
	lda	cpmSEC
	mov	C,A	; sector number in C
	mov	A,D	; put unit # back in A
	lded	cpmTRK	; get track number
	lhld	cpmDMA	; get DMA address
	ret
	]
;----------
; Read/write common code
HARDrw:
	sta	HARDdsk	; store unit number
	push	B	; save volume and sector
	push	D	; save track
	mov	A,B	; put volume # in A
	sta	HARDcom+2; store in cmd. string
	mvi	A,'M'	; 'M' for multi HD feature
	sta	HARDcom+6; store in cmd. string
SendSelect:
	mvi	A,selHARD
	call	CMDhard	; select the unit
;
;	go get status from hard disk controller
;	do this in line as only 8 bytes being read
;	note: this code provides no timeout since
;	on first select after cold boot it may take
;	several seconds for the hard disk controller
;	to respond
;
	lxi	h,hardstat	;block recieve address
	mvi	b,8		;block length
	mvi	c,hardp		;hdc data port
selloop:
	in	pioad		;status port
	bit	4,a		;data ready bit
	jrz	selloop		;nothing yet
;
	ini			;read a byte
	jrnz	selloop		;test if done
;
	dcx	h		;adr of error type byte
	lxi	b,hardstat+1	;tell ioerr it's a HD error
	mov	a,m
	ora	a
HSELerr:cnz	ioerr	;error did occur(note label is
			;for ioerr deciphering of error
			;origination

	lda	hardSTAT+7	; check for controller
	cpi	hdFLUSHerr	; error on prev flush
	jrz	SendSelect

	pop	D	; restore track
	pop	B	; restore sector
	lxi	H,HARDsec
	mov	M,C	; hard disk sector
	inx	H
	mov	M,E	; hard disk track (low byte)
	inx	H
	mov	M,D	; hard disk track (high byte)
	ret
;----------
; Get hard disk subsystem status
;  Regs in:	HL = block address
;		on return block has 8 byte hard disk
;		command status followed by 128 byte
;		volume information block
;  Regs out:	none
;  Destroyed:	A, BC, DE, HL
HDstat:
;
; If master, request thru local user
	.ife	MASTopt,[
	sbcd	HSTadr	; Store block addr
	mvi	a,hdstNET
	sta	netCOM
	jmp	netREQ	;return from there
	]
;
; If not master, enter directly below
MMhdstat:
	push	B	; save block address
	mvi	A,statHARD ; Cmd in Acc
	call	cmdHARD	; Send cmd to HD subsystem
	pop	H	; Get ready to rcve block
	push	H	; Save addr once again
	lxi	B,8	; block length
	call	RECHARD	; Get 8 byte block
	pop	H	; Get the block addr
	lxi	D,7
	dad	D	; HL points at status byte
	sub	A
	ora	M	; Test status byte for zero
	rnz		; No more if non-zero
	inx	H	; Point past 8 byte block
	lxi	B,128
	call	RECHARD	; Get the 128 byte block
	ret
;
;
HSTadr:
	.word	0FFFFh	; Storage for HDstat
			; block address
;
;----------
; Transmit a block to the hard disk
;  Regs in:   HL = block address
;             BC = byte count
;  Regs out:  none
;  Destroyed: A, BC, DE, HL
SENDHARD:
	.ifn	MASTopt,[
	mov	B,C	; assume less than 256 bytes
	mvi	C,HARDP
..1:	in	PIOAD
	bit	3,A
	jrnz	..1
	outi		; shove'em one at a time
	jrnz	..1
	ret
	]
	.ife	MASTopt,[
	shld	DMAHSadr  ; DMA address
	dcx	B
	sbcd	DMAHSsize ; DMA length
	lxi	H,DMAHdone
	shld	DMAvect	  ; DMA interrupt vector
	mvi	A,4
	out	PIOAD	; multiplex hard disk to DMA
	lxi	H,DMAHSprog
	lxi	B,DMAH$<8+DMA
	di		; no ints until local user ok
	outir		; let the DMA fly
	jmpr	GOlocal
	]
;----------
; Receive a block from the hard disk
;  Regs in:   HL = block address
;	      BC = byte count
;  Regs out:  none
;  Destroyed: A, BC, DE, HL
RECHARD:
	.ifn	MASTopt,[
	mov	B,C	; assume less than 256 bytes
	mvi	C,HARDP
..1:	in	PIOAD
	bit	4,A
	jrz	..1
	ini		; grap'em one at a time
	jrnz	..1
	ret
	]
	.ife	MASTopt,[
	shld	DMAHRadr  ; DMA address
	dcx	B
	sbcd	DMAHRsize ; DMA length
	lxi	H,DMAHdone
	shld	DMAvect   ; DMA interrupt vector
	mvi	A,5
	out	PIOAD	; multiplex hard disk to DMA
	lxi	H,DMAHRprog
	lxi	B,DMAH$<8+DMA
	di		; no ints until local user ok
	outir
;----------
; Option to assemble local user code
LOCALopt==	0
	.ife	LOCALopt,[
;----------
; Give the CPU to the local user until DMA done
GOlocal:
	jmp	retUSER
;---------
; Return here when DMA is done
DMAHdone:
	call	saveUSER
	mvi	A,0C3h
	out	DMA	; turn off DMA
	ei
 	ret		; return to caller
	]
	.ifn	LOCALopt,[
;----------
; Hang until DMA done
GOlocal:
	sub	A
	sta	DMAflag
	ei
..wait:	lda	DMAflag
	ora	A
	jrz	..wait
	ret
DMAflag:.byte	0
;----------
; Process DMA interrupt
DMAHdone:
	push	PSW
	mvi	A,0C3h
	out	DMA
	sta	DMAflag
	pop	PSW
	ei
	ret
	]
	]
;----------
; Send a command to the hard disk
;  Regs in:   A = command byte
;  Regs out:  none
;  Destroyed: A, BC, HL
cmdHARD:
	sta	HARDcom
	lxi	B,0	; keep activity count
..1:	in	HARDP	; clear status
	mvi	A,51h	; "request to send"
	out	HARDP
..2:	dcx	B	; timeout if no (or bad) disk
	mov	A,B
	ora	C
	jrnz	..3	; jump if we're still OK
	dcr	A	; clear zero flag
	jmp	begHDSKerr	; harddisk is dead
..3:	in	PIOAD	; wait for HDC send
	bit	4,A
	jrz	..2
	in	HARDP	; check if "clear to send"
	cpi	52h
	jrnz	..1	; if not, retry
	lxi	H,HARDcom ; send the command
	lxi	B,8
	jmp	SENDHARD
;----------
; Receive status info from the hard disk
;  Regs in:   none
;  Regs out:  A = error status
;  Destroyed: A, BC, HL
RESHARD:
	lxi	H,HARDstat
	lxi	B,8
	call	RECHARD
	lda	HARDstat+7
	ora	A
	rz
begHDSKerr:
	lxi	B,HARDstat+1	; point to THS
HDSKerr:call	IOERR	; HDC error
	mvi	A,0ffh
	ora	A
	ret		; This ret ought to be
			; changed to something
			; better
;----------
; DMA commands
	.ife	MASTopt,[
DMAHSprog:
	.byte	0C3h	; master reset		     2D
	.byte	0C7h	; reset port A		     2D
	.byte	0CBh	; reset port B		     2D
	.byte	79h	; write
DMAHSadr:.word	0	; filled by SENDNET or RECstart
DMAHSsiz:.word	0	; filled by SENDNET or RECstart
	.byte	14h	; port A inc, memory	     1B
	.byte	28h	; port B fixed, I/O	     1B
	.byte	95h	; byte mode		     2B
	.byte	HARDP	; port B
	.byte	12h	; interrupt at end of block
	.byte	DMAvect&0FFh ; interrupt vector
	.byte	92h	; active low
	.byte	0CFh	; load starting address      2C
	.byte	5	; write
	.byte	0CFh	; load starting address	     1A
	.byte	0ABh	; enable interrupts	     2D
	.byte	87h	; start DMA
DMAH$	==	.-DMAHSprog
	]
;
DMAHRprog:
	.byte	0C3h	; master reset		     2D
	.byte	0C7h	; reset port A		     2D
	.byte	0CBh	; reset port B		     2D
	.byte	7Dh	; read
DMAHRadr:.word	0	; filled by SENDNET or RECstart
DMAHRsiz:.word	0	; filled by SENDNET or RECstart
	.byte	14h	; port A inc, memory	     1B
	.byte	28h	; port B fixed, I/O	     1B
	.byte	95h	; byte mode		     2B
	.byte	HARDP	; port B
	.byte	12h	; interrupt at end of block
	.byte	DMAvect&0FFh ; interrupt vector
	.byte	9Ah	; active high
	.byte	0CFh	; load starting address      2C
	.byte	1	; read
	.byte	0CFh	; load starting address	     1A
	.byte	0ABh	; enable interrupts	     2D
	.byte	87h	; start DMA
	]
	]
	.page
	.sbttl	'network reads ,writes,spools and locks'
	.ife	NETopt,[

;----------
; DMA xfer length check
qDMAlen:
	lhld	rcvDMAlen	; set by DMARdone
	lbcd	DMANRsize	; set by RECnet
	ora	a		; clear carry
	dsbc	b		; should be equal
	ret
;
;----------
; Network read
NETrd:
	.ife	BUFFopt, [mvi C,read1NET]
	.ifn	BUFFopt, [mvi C,readNET]
	jmpr	Network
;----------
; Network write
NETwr:
	mvi	C,writeNET
;----------
; Network read/write
Network:
	.ife	FLOPshar,[
	mov	A,C
	lxi	H,cpmDSK
	lxi	D,NETdsk
	lxi	B,6
	ldir		; set disk, track, sect, DMA
	sta	NETcom	; set command byte
	]
	.ife	HARDshar,[
	call	cpmMAP	; unit # returned in Acc
	sta	NETdsk	; set disk
	dcx	H
	dcx	H
	mov	A,M	; Get volume #
	sta	cpmVOL	; Set volume
	mov	A,C
	lxi	H,cpmTRK
	lxi	D,NETtrk
	lxi	B,6
	ldir		; set trk, sec, vol, DMAadr
	sta	NETcom	; set command byte
	]
;----------
; See if desired sector is in local network buffer
	.ife	BUFFopt,[
	lxi	H,netbDSK
	lxi	D,NETdsk
	ldax	D
	cmp	M	; compare disk
	jrnz	..force	; jump if not equal
	inx	H
	inx	D
	ldax	D
	cmp	M	; compare track	(low byte)
	jrnz	..force	; jump if not equal
	inx	H
	inx	D
	ldax	D
	cmp	M	; compare track (high byte)
	jrnz	..force
	inx	H
	inx	D
	ldax	D
	dcr	A	; convert sector to 1K boundary
	ani	0F8h
	ori	1
	cmp	M	; compare sector
	jrnz	..force	; Jump if not equal
	inx	H
	inx	D
	ldax	D
	cmp	M	; Compare volume #
	jrz	..inbuff; Jump if everything matches
;----------
; Sector not in buffer, so force read at 1K boundary
..force:
	lda	NETcom
	cpi	writeNET; see if command is a write
	jz	NETreq	; don't mess with writes
	lda	NETsec
	dcr	A	; For example:
	ani	0F8h	;  sectors 1-8 map to 1
	ori	1	;  sectors 9-16 map to 9
	sta	NETsec
	lxi	H,NETdsk
	lxi	D,netbDSK
	lxi	B,5	; move dsk, trk, sec, vol
	ldir		; update buffer info
	jmp	NETreq
;----------
; Sector in buffer, so block move it in or out
..inbuff:
	call	FINDsect
	lda	NETcom
	sui	read1NET; see if command is a read
	jrz	..move
	xchg		; switch HL and DE if write
..move:	ldir		; move to or from user area
	rz		; we're done if we're reading
	]
	jmpr	NETreq	; process the I/O request

  .ife	SPOOLopt,[
;----------
; Start spool job
NETstart:
	mvi	A,startNET
	sta	NETcom
	jmpr	NETreq
;----------
; Stop spool job
NETstop:
	mvi	A,stopNET
	sta	NETcom
	jmpr	NETreq
;----------
; Spool 128 bytes
NETspool:
	lxi	H,SPOOLsec
	mov	A,M
	cpi	128	; check for last sect on track
	jrnz	..write
	lxi	H,SPOOLtrk
	mov	A,M
	inr	A
	ani	0Fh	; check for track too big
	jrnz	..notbig
	inr	A	; return error code
	ret
..notbig:
	inr	M	; inc track
	lxi	H,SPOOLsec
	mvi	M,0	; reset sector
..write:
	inr	M	; inc sector
	lxi	H,SPOOLdsk
	lxi	D,NETdsk
	lxi	B,5
	ldir	 	;set net disk,track,sect,vol
	lxi	H,SPOOLbuf
	shld	NETdma	; set net DMA address
	mvi	A,spoolNET
	sta	NETcom	; write 128 bytes to spool dsk
	jmpr	NETreq
	]
;----------
; Network lock
NETlock:
	.ife	BUFFopt,[
	mvi	A,0FFh
	sta	netbDSK	; flush read buffer
	]
	mvi	A,lockNET
	jmpr	Lockwork
;----------
; Network unlock
NETunlock:
	mvi	A,unlockNET
;----------
; Network lock/unlock
lenlock	==	13	; maximum lock length
Lockwork:
	lhld	LOCKadr	; point to lock string
	lxi	D,NETcom+1
	lxi	B,lenlock+1
	ldir		; move lock to network command
	sta	NETcom
	jmpr	NETreq
;----------
; Network HD volume status request
NEThdstat:
	sbcd	HSTadr	; Store addr
	mvi	A,hdstNET
	sta	NETcom
;----------
; Wait for a poll
NETreq:
	.ife	MASTopt,[
..wait:	lda	NETcom	; wait for master to wake up
	ora	A	;  and process the command
	jrnz	..wait
	ret
	]
	.ifn	MASTopt,[
	call	lockDMA	; reserve the DMA chip
	mvi	a,0
	sta	tOUTcnt	; reset time-outs cnt
Npoll:	call	NACKpoll
	bit	timeout,A ; check for time-out
	jrnz	NetIO
;
	lda	tOUTcnt	; wait for two timeouts
	inr	a	; together before
	cpi	2	; telling user
	jrnz	..nomess
;
	lxi	H,Nwait
	call	PRTMSG	; tell user we timed out
	mvi	a,0	; reset time-outs cnt
..nomess:
	sta	tOUTcnt
Nretry:	call	ACKpoll	; prepare for another poll
	jmpr	Npoll	; wait some more

Nwait:	.asciz	[cr][lf]'*** Waiting'
tOUTcnt:.byte	0	; count of how many time-outs
			; in a row were rcv'd

;----------
; Process the current network command
NetIO:
	bit	pollRCV,a
	jrz	Nretry	; must have received a poll
;			  to continue w/request
	ani	crc$ovr	; crc or ovrun err
	jrz	..ok
;
	call	errPRINT; inc err cnt & disp err
	jmpr	Nretry

..ok:
	lda	NETcom	; get command
	sui	writeNET
	jrc	..bad	; illegal command
	cpi	..lentab
	jrnc	..bad	; illegal command
	call	DISPATCH
..table:
	.word	Nwrite	; write
	.word	..bad	; login
	.word	Nstart	; start spool
	.word	Nread	; read 1K
	.word	Nstop	; stop spool
	.word	..bad	; assign
	.word	..bad	; hog
	.word	Nlock	; lock
	.word	Nunlock	; unlock
	.word	Nclrlock; clear locks
	.word	Nspool	; spool
	.word	Nhdstat	; master HD volume status
..lentab=	(.-..table)/2

..bad:	call	ERRprint; illegal command
	jmp	NETret
;
;----------
; Get a data block from the master
Nread:
	call	SENDCMD
	.ife	BUFFopt,[
	lxi	H,netBUFF; data address
	lxi	B,1024
	]
	.ifn	BUFFopt,[
	lhld	NETdma	; data address
	lxi	B,128
	]
	lda	NETusr
	call	RECNET  ; receive data from master
	call	ckRECstat
	jrnz	..0good
;
	call	NETerr	; timeout
	jmp	Nretry

..0good:
	jrc	..fail	; carry set = crc or ovr err
;
	call	qDMAlen
	jrz	..1good

..fail:
	mvi	a,nack
	call	SENDmsg
	call	netERR	; DMA len is bad
	jmp	Nretry
;
..1good:
	mvi	A,datack
	call	SENDMSG	; acknowledge reception
	.ife	BUFFopt,[
	call	FINDsect; find address of sect in buff
	ldir		; move it to user area
	]
	jmp	NETret
;----------
; Send a sector to the master
Nspool:
Nwrite:
	call	SENDCMD
	call	RECMSG	; wait for request-received ack
	call	ckRECstat
	jrnc	..good
;
..fail:
	call	NETerr	; timeout, crc or ovr error
	jmp	Nretry

..good:
	lda	NETmsg	; get rcv'd message
	cpi	mesack
	jrnz	..fail
;
	lhld	NETdma	; data address
	lxi	B,128
	sub	A
	call	SENDNET	; send data to master
	call	RECMSG	; wait for data-received ack
	call	ckRECstat
	jrnc	..1good
;
	call	NETerr
	jmp	Nretry
;
..1good:
	lda	NETmsg	; get rcv'd message
	cpi	datack
	jz	NETret
;
	call	NETerr	; error if not acked
	jmp	Nretry

  .ife	SPOOLopt,[
;----------
; Start spool job
Nstart:
	call	SENDCMD
	lxi	H,SPOOLdsk
	lxi	B,5
	lda	NETusr
	call	RECNET	; get spool disk,track,sec,vol
	call	ckRECstat
	jrc	..fail
;
	call	qDMAlen
	jz	NETret

..fail:
	call	NETerr	; dma len bad
	jmp	Nretry
;
;----------
; Stop spool job
Nstop:
	call	SENDCMD
	call	RECMSG	;
	call	ckRECstat
	jrnc	..0good
;
	call	NETerr	; timeout,crc, or ovr error
	jmp	Nretry
;
..0good:
	lda	NETmsg	; get rcv'd message
	cpi	mesack
	jrz	NETret
;
	call	NETerr	; not mesack
	jmp	Nretry
	]
;
;----------
; Send a lock/unlock request to the master
	.ife	HARDshar,[
Nlock:
Nunlock:
	call	SENDCMD
	call	RECMSG	; get status
	call	ckRECstat
	jrnc	..good
;
	call	NETerr
	jmp	Nretry
;
..good:
	lda	NETmsg
	sta	LOCKstat; store status for user
	jmpr	NETret
;----------
; Send a clear-locks request to the master
Nclrlock:
	call	SENDCMD
	jmpr	NETret
;----------
; Request and receive master HD volume status
Nhdstat:
	call	SENDCMD
	lhld	HSTadr	; Rcve data addr
	lxi	B,88h	; 8 + 128  bytes
	lda	NETusr	; Our user number
	call	RECNET	; Rcve the data
	call	ckRECstat
	jrnz	..0good
;
	call	NETerr	; timeout
	jmp	Nretry

..0good:
	jrnc	..1good

..fail:
	mvi	a,nack
	call	sendMSG	; neg acknowledge
	call	NETerr	; crc or overrun err
	jmp	Nretry
;
..1good:
	call	qDMAlen
	jrnz	..fail
;
	mvi	A,HSTack
	call	SENDMSG	; Ack reception
	]
;----------
; Resume answering polls, then return to caller
NETret: call	ACKpoll	; answer polls again
	sub	A	; CP/M wants A = 0
	sta	lockbyte; release the DMA chip
	ret
;
;----------
; Send command to network master
SENDCMD:
	lxi	H,NETcom
	lxi	B,lencom
	sub	A
	jmp	SENDNET
	]
;----------
; Locate current sector in network buffer
;  Regs in:   none
;  Regs out:  HL = address of sector in buffer
;	      DE = CP/M DMA address
;	      BC = number of bytes in sector (ie, 128)
	.ife	BUFFopt,[
FINDsect:
	lda	cpmSEC	; get sector number
	dcr	A
	ani	7	; compute buff no (0-7)
	mov	D,A
	mvi	E,0
	srlr	D
	rarr	E
	lxi	H,netBUFF
	dad	D	; compute buffer address
	lded	cpmDMA
	lxi	B,128
	ret
	]
	.page
	.sbttl	'master polling'
	.prntx	'made it to master'
  .ife	MASTopt,[
;------------------------------------------------------
;  H I N E T   M A S T E R
;------------------------------------------------------
MASTusr:.byte	numusr-1; user being polled now
deadusr:.byte	numusr	; "dead" user number
boottim:.byte	1	; boot broadcast counter
logtime:.byte	1	; login poll counter

slowPOLL	==	224	; start slow polling
pollSKIP	==	32	; slow poll counter
	; log down count table - change pollSKIP
	; value to alter time till logout occurs.
	; change slowPOLL value to change time to
	; start the slow poll sequence.
slowTBL:
	.byte	pollSKIP,pollSKIP,pollSKIP,pollSKIP
	.byte	pollSKIP,pollSKIP,pollSKIP,pollSKIP
	.byte	pollSKIP,pollSKIP,pollSKIP,pollSKIP
	.byte	pollSKIP,pollSKIP,pollSKIP,pollSKIP
	.byte	pollSKIP,pollSKIP,pollSKIP,pollSKIP
	.byte	pollSKIP,pollSKIP,pollSKIP,pollSKIP
	.byte	pollSKIP,pollSKIP,pollSKIP,pollSKIP
	.byte	pollSKIP,pollSKIP,pollSKIP,pollSKIP

MASTER:
; Save user registers and lock DMA chip
	call	saveUSER
	lxi	SP,MASTstack-6
	call	lockDMA	; reserve the DMA chip
;
; Don't allow parallel port ints while polling
    .ife	SPOOLopt,[
	mvi	A,00000011b
	out	PIOAC
	]
	ei		; interrupts OK now
;------------
; Poll each active user (poll bad users each 1/2 sec)
	lda	MASTusr
	ora	a
	jrnz	nxtusr
;
	mvi	a,numusr-1
nxtusr:
	sta	MASTusr	; store current user number
	call	curUSR	; get current activity counter
	mov	A,M
	ora	A	; don't poll if status = 0
	jrz	nxtpoll
;
	cpi	slowPOLL
	jrnc	..poll	; poll every time only till 223
;
	lda	MASTusr
	mov	c,a
	mvi	b,0
	lxi	h,slowTBL
	dad	b	; table loc for logdown count
	dcr	m
	jrnz	nxtpoll	; poll only every 32nd time
;
	mvi	m,pollSKIP	; init table
..poll:
	call	serOFF	; disable serial printer ints
	ei		; ints ok now
	mvi	A,poll	; poll the current user
	mvi	E,0	; no delay
	call	SENDUSR
	call	RECCMD	; wait for a response
	jrnc	ACKed
	call	curUSR
;----------
; Logout this user if countdown = 0
..nack:
	dcr	M	; countdown for logout
	.ife	HARDshar,[
	jrnz	nxtpoll
	call	MMclrlock; clear locks (if any)
	call	MMabort	 ; abort spool job (if any)
	]
	jmpr	nxtpoll
;----------
; Poll was acknowledged with pollack or request
ACKed:
	call	curUSR
	mvi	M,0FFh	; keep user logged in
	cpi	pollack
	jrz	nxtpoll	; check for poll acknowledge
;----------
; Process HiNet request
	call	savereq	; update entry in WHO table
	sui	whoNET
	jrc	..bad
	cpi	..lentab
	jrnc	..bad
	call	..dispatch
	jmpr	nxtpoll	; ret's to here if no error
..dispatch:
	call	DISPATCH
..table:
	.word	Mwho	; who
	.word	Mread	; read
	.word	Mwrite	; write
	.word	..bad0	; login
	.word	Mstart	; start spool
	.word	Mread1	; read 1K
	.word	Mstop	; stop spool
	.word	Massign	; assign
	.word	Mhog	; hog
	.word	Mlock	; lock
	.word	Munlock	; unlock
	.word	Mclrlock; clear locks
	.word	Mspool	; spool
	.word	Mhdstat	; hard disk status
	.word	Mdattim	; date/time
..lentab=	(.-..table)/2

;----------
; Give local user a shot at processing the request
..bad0:
	pop	h	  ; balance the stack
..bad:
	lxi	H,MASTcom ; HL = message address
	lda	MASTusr	  ; A = user number
	call	LOCALcall ; call user thru jump vector
			  ; initially INTERCEPT
	ora	A
	jrz	nxtpoll	; if no error, continue
;
	call	NETerr 	; illegal request

;----------
; Poll next user, if any remain
nxtpoll:
	call	ckPRTon	; maybe enable print ints
	lda	MASTusr
	dcr	A	; decrement user number
	jnz	nxtusr
;---------
; Poll one "dead" user per pass
	lda	deadusr
	dcr	A
	jrnz	..poll
	mvi	A,numusr-1
..poll:	sta	deadusr
	sta	MASTusr
	call	curUSR
	mov	A,M
	ora	A
	jrnz	..local	; don't poll if active
	mvi	A,poll
	mvi	E,0	; no delay
	call	SENDUSR
	call	RECCMD	; get command from net user
	jnc	ACKed	; process request, if any
;----------
; See if the local user has anything for us to do
..local:
	sub	A
	sta	MASTusr	; set local user number
	lda	NETcom	; check local user's command
	ora	A
	jrz	clrreq	; jump if nothing to do
	lxi	H,NETcom; get local user's command
	lxi	D,MASTcom
	lxi	B,lencom
	ldir
	lxi	H,userlist
	call	savereq	; update entry in WHO table
	sui	whoNET
	jrc	..bad
	cpi	..lentab
	jrnc	..bad
	call	..dispatch
	jmpr	clrreq	; ret here if no error
..dispatch:
	call	DISPATCH
..table:
	.word	..bad0	; who
	.word	Lread	; read
	.word	Lwrite	; write
	.word	Llogin	; login
	.word	Lstart	; start spool
	.word	..bad0	; read 1K
	.word	Lstop	; stop spool
	.word	Lassign	; assign
	.word	..bad0	; hog
	.word	Llock	; lock
	.word	Lunlock	; unlock
	.word	Lclrlock; clear locks
	.word	Lspool	; spool
	.word	Lhdstat	; hard disk volume status
	.word	..bad0	; date/time request
..lentab=	(.-..table)/2

..bad0:	pop	h	; balance stack
..bad:	call	NETerr 	; should NEVER come here

clrreq:
	sub	A	; clear local user's request
	sta	NETcom
;----------
; Broadcast the bootstrap code once per second
	lxi	H,boottime
	dcr	M	; broadcast if counter = 0
	jrnz	..poll
	mvi	M,sendBOOT
	lxi	H,NET1strap
	lxi	B,len1strap
	mvi	E,0	; no delay
	mvi	A,BOOTusr; pseudo user number
	call	SENDNET
;----------
; Poll mimic and login pseudo users every 1/3 sec
..poll:
	lxi	H,logtime
	dcr	M	; poll if counter = 0
	jrnz	..spool
	mvi	M,sendlog
	call	CHKmimic; poll mimic
	call	CHKlogin; check for new logins
;----------
; Check spooling
..spool:
	call	CHKspool
;----------
; Return control to local user for average 1/120 sec
	di		; no ints until user running
	sub	A	; unlock the DMA chip
	sta	lockbyte
MASTret:
	mvi	A,wakeupMAST; delay a bit before
	sta	timeMAST    ; calling MASTER again
	jmpr	retUSER

INTERCEPT:
	mvi	A,0FFh	; come here if local user
	ret		; not intercepting net calls

	.page
	.sbttl	'context switch routines'
;-----------------------------------------------------
;  C O N T E X T   S W I T C H   R O U T I N E S
;-----------------------------------------------------
USER.SP:.word	BURN.SP
MAST.SP:.word	0
LOCALflag:.byte	0	; 0 if in local user, 1 if mast
;----------
; Save user registers
saveUSER:
	xthl
	sspd	USER.SP
	lxi	SP,MASTstack
	push	D
	push	B
	push	PSW
	lspd	MAST.SP
	mvi	A,0FFh
	sta	LOCALflag
	pchl
;----------
; Restore user registers
retUSER:
	sub	A
	sta	LOCALflag
	sspd	MAST.SP
	in	PIOAD
	ani	80h	; return to user if no INT
	jrz	..ret
..wait:
	in	PIOAD
	ani	80h	; wait until INT released
	jrnz	..wait
	lxi	SP,MASTstack-6
	pop	PSW
	pop	B
	pop	D
	lspd	USER.SP
	pop	H
	ei
	jmp	30h	; go to DDT when INT released
..ret:
	lxi	SP,MASTstack-6
	pop	PSW
	pop	B
	pop	D
	lspd	USER.SP
	pop	H
	ei
	ret
	.page
	.sbttl	'login new user'
;-----------------------------------------------------
; L O G I N   N E W   U S E R
;-----------------------------------------------------
prevusr:.byte	numusr-1; start scanning at begin
;
; Poll login user - if answered, then log'im in
CHKlogin:
	mvi	A,poll
	mvi	E,0	; no delay
	lxi	b,1	; one byte
	call	SENDLUSR; poll "login" user
;
	lxi	H,LOGcom
	lxi	B,lencom+2	; send serial#
	lxi	D,$1ms
	sub	A
	call	RECNET	; wait for response
	call	ckRECstat
	jrnc	..ack	; no xmission error

; Nobody (or everybody!) wants to login
..logerr:
	mvi	A,lognack
	mvi	e,$halfms
	lxi	b,1
	call	SENDLUSR; prospective logins must retry
	ret
;
; Check user name and password
..ack:
  .ife	HARDshar,[
	call	chkusr
	ora	A
	jrnz	..deny
;
; User name ok, so move defaults to NET2strap
	lxi	H,MASTbuf
	lxi	D,DSKSdef
	lxi	B,lendef
	ldir
	]
;
; Find room in the current user list
	lda	prevusr	; start scanning at last login
..look:	inr	A
	cpi	numusr
	jrnz	..ok
;
	mvi	A,1	; restart scan at beginning
..ok:	push	PSW
	sta	MASTusr
	call	curUSR	; point to userlist entry
	mov	A,M
	ora	A	; if zero, then available
	jrz	..found
;
	pop	PSW
	lxi	H,prevusr
	cmp	M	; see if all entries checked
	jrnz	..look	; jump if not all checked
;
; Deny login if name not found or no room in list
..deny:	mvi	A,logdeny
	mvi	e,0
	lxi	b,lencom+3
	call	SENDLUSR
	ret
;
; Put user in table, and send number and login time
..found:
	pop	PSW
	sta	prevusr	; save current user number
	call	newuser	; put user in table
	lxi	H,ticks
	lxi	D,LOGclk
	lxi	B,7
	ldir		; login time
	mvi	a,LOGack
	mvi	e,0	; no delay
	lxi	B,lencom+3
	call	SENDLUSR
;
; Give the user the rest of the bootstrap code
	lxi	H,NET2strap
	lxi	B,len2strap
	lda	MASTnum
	mvi	E,$halfms*2 ; extra delay for DSC/4
	call	SENDNET
	ret
;
	.ife	HARDshar,[
;----------
; Check user table for name and password
;  Regs out:   A = 0 if name found
;	       A not 0 if name not found
chkusr:
	lxi	H,MASTnam; move user name to safe place
	lxi	D,usernam
	lxi	B,14
	ldir
	sub	A	; read user table from disk 0
	sta	MASTvol	; HD drive 0
	sta	MASTdsk	; unit 0
	lxi	H,3	; start at track 3
	shld	MASTtrk
	mvi	A,1	; sector 1
	sta	MASTsec
;
; Search next sector for match with user name
..nsect:lxi	H,MASTbuf
	call	MMread	; read sector
	lxi	H,MASTbuf
..nname:lxi	D,usernam
	lxi	B,14<8	; compare 14 chars
..cmp14:ldax	D
	cmp	M
	jrz	..equal	; jump if chars are equal
	mvi	C,1	; set no-match flag
..equal:inx	H
	inx	D
	djnz	..cmp14	; check all 14 chars
	mov	A,C
	ora	A
	jrz	..match	; if C = 0, then match found
	inx	H
	inx	H	; move to next name in table
	mov	A,L
	cpi	(MASTbuf+128)&0FFh
	jrnz	..nname
;
; No match found, so search next sector of table
	lda	MASTsec
	cpi	16	; search 16 sectors (128 names)
	rz		; deny login if name not found
	inr	A
	sta	MASTsec
	jmpr	..nsect
;
; Get default configuration table from track 4
..match:lda	MASTsec	; A = 1,2,3,...16
	dcr	A
	rlc
	rlc
	rlc
	mov	B,A	; B = 0,8,16,...120
	mov	A,L
	adi	(MASTbuf&0FFh)+2 ; A = 16,32,48,...128
	rrc
	rrc
	rrc
	rrc		; A = 1,2,3,...8
	add	B	; A = 1,2,3,...128
	sta	MASTsec	; read from sector 1,2,3,...128
	lxi	H,4	; track 4
	shld	MASTtrk
	sub	A
	sta	MASTvol	; table is on drive 0
	lxi	H,MASTbuf
	call	MMread	; get default configuration
	sub	A	; A = 0 means name OK
	ret
usernam:.blkb	14
	]
;----------
; Assign the user a position in the user table
;  Regs in:  HL = pointer to available table entry
;	     A  = user number
newuser:
	mvi	M,0FFh	; log 'im
	sta	LOGnum	; give userno to user
	.ife	HARDshar,[
	inx	H
	xchg
	lxi	H,usernam
	lxi	B,8
	ldir		; save user name
	lxi	H,secs
	lxi	B,3
	ldir		; save login time
	]
	ret
	.page
	.sbttl	'process local user request'
;------------------------------------------------------
; P R O C E S S   L O C A L   U S E R   R E Q U E S T
;------------------------------------------------------
Lread:
	lhld	NETdma  ; read directly into user area
	call	MMread
	ret
;----------
Lwrite:
	lhld	NETdma  ; write directly from user area
	call	MMwrite
	ret
;----------
	.ife	HARDshar,[
Lassign:
	lxi	H,MASTnam; point to name and password
	call	MMassign
	sbcd	NETassn	; store assignment value
	sded	NETassn+2
	ret
;----------
Llogin:
	lxi	H,BOOTnam
	lxi	D,MASTnam
	lxi	B,14
	ldir
	call	chkusr
	sta	NETassn	; A = 0 if ok
	lxi	H,MASTbuf
	lxi	D,DSK0def
	lxi	B,lendef
	ldir
	sub	A
	call	curUSR
	jmp	newuser	; enter name in user table
;----------
  .ife	SPOOLopt,[
Lstart:
	call	MMstart
	lxi	H,SPL$dsk
	lxi	D,SPOOLdsk
	lxi	B,5
	ldir	; return spool dsk, track, sect,vol
	ret
;----------
Lstop:
	call	MMstop
	ret
;----------
Lspool:
	call	Lwrite
	call	MMspool
	ret
;----------
Lhdstat:
	lbcd	HSTadr	; Get HD status block addr
	call	MMhdstat
	ret
	]
;----------
Llock:
	call	MMlock
	sta	LOCKstat; store status for user
	ret
;----------
Lunlock:
	call	MMunlock
	sta	LOCKstat; store status for user
	ret
;----------
Lclrlock:
	call	MMclrlock
	ret
	]
	.page
	.sbttl	'process remote user request'
;------------------------------------------------------
; P R O C E S S   R E M O T E   U S E R   R E Q U E S T
;------------------------------------------------------
; Process a read request
Mread:
	lxi	H,MASTbuf
	call	MMread	; read sector from disk
	lxi	H,MASTbuf
	lxi	B,128
	lda	MASTusr
	mvi	E,0	; no delay necessary
	call	SENDNET	; send data to user
	lxi	D,$1ms
	call	RECUSR	; receive ack from user
	jrnc	..good
;
	call	NETerr
	ret

..good:
	cpi	datack
	cnz	NETerr
	ret
;----------
; Process a write request
Mwrite:
	mvi	A,mesack
	mvi	E,$halfms
	call	SENDUSR	; ack reception of command
	lxi	H,MASTbuf
	lxi	B,128
	lxi	D,$16ms
	sub	A
	call	RECNET	; receive data from user
	call	ckRECstat
	jrnc	..0good

..fail:
	mvi	a,nack
	mvi	e,$halfms
	call	sendUSR
	call	netERR
	ret

..0good:
	call	qDMAlen
	jrnz	..fail

..1good:
	mvi	A,datack
	mvi	E,$halfms
	call	SENDUSR	; ack data
	lxi	H,MASTbuf
	call	MMwrite	; write the data to the disk
	ret
	.ife	HARDshar,[
;----------
; Process a read 1K request
Mread1:
	lxi	H,MASTbuf
	call	MMrd1	; read sector from disk
	lxi	H,MASTbuf
	lxi	B,1024
	mvi	E,0	; no delay necessary
	lda	MASTusr
	call	SENDNET	; send data to user
	lxi	D,$1ms
	call	RECUSR	; receive ack from user
	jrnc	..good
;
	call	NETerr
	ret

..good:
	cpi	datack
	cnz	NETerr
	ret
;
;----------
; Process a hog request
Mhog:
	mvi	A,hogack; tell user he can hog the net
	mvi	E,$halfms
	call	SENDUSR	; for at most 1/60th sec
	lxi	D,$16ms
	call	RECUSR
	cc	NETerr	; error if user has pigged out
	ret
;----------
; Process an assign request
Massign:
	lxi	H,MASTnam
	call	MMassign; let MASTas do the work
	lxi	H,HARDstat
	lxi	B,4
	mvi	E,0	; no delay necessary
	lda	MASTusr
	call	SENDNET	; send results to user
	ret
;----------
; Process a who request
Mwho:
	lxi	H,USERlist
	lxi	B,numusr*16
	mvi	E,$halfms
	lda	MASTusr
	call	SENDNET	; send user table
	lxi	H,SPOOLlist
	lxi	B,lenSPOOL*16
	mvi	E,$halfms*2 ; extra delay for DSC/4
	lda	MASTusr
	call	SENDNET	; send spool table
	ret
  .ife	SPOOLopt,[
;----------
; Process a spool start request
Mstart:
	call	MMstart
	lxi	H,SPL$dsk
	lxi	B,5
	mvi	E,0	; no delay necessary
	lda	MASTusr
	call	SENDNET	;send spool disk,trk,sect,vol
	ret
;----------
; Process a spool stop request
Mstop:
	call	MMstop
	mvi	A,mesack
	mvi	E,0	; no delay necessary
	call	SENDUSR	; ack request
	ret
;----------
; Process a spool request
Mspool:
	call	Mwrite
	jmp	MMspool
	]
;----------
; Process a lock request
Mlock:
	call	MMlock
	mvi	E,$halfms
	call	SENDUSR	; send status to user
	ret
;----------
; Process an unlock request
Munlock:
	call	MMunlock
	mvi	E,$halfms
	call	SENDUSR	; send status to user
	ret
;----------
; Process a clear-lock request
Mclrlock:
	call	MMclrlock
	ret
;----------
; Process a hard disk volume status request
Mhdstat:
	lxi	B,MASTbuf
	call	MMhdstat
	lxi	H,MASTbuf
	lxi	B,88h	; 8 bytes + 128 bytes
	mvi	E,0
	lda	MASTusr
	call	SENDNET
	lxi	D,$1ms
	call	RECUSR
	jrnc	..good
;
	call	NETerr 	; if error
	ret

..good:
	cpi	HSTack	; Hard STatus ACK
	cnz	NETerr 	; Jump if not ACKed
	ret
;----------
; Process a date/time request
Mdattim:
	lxi	H,ticks	; Base of date/time data
	lxi	B,7	; Length of the block
	mvi	E,0	; No time delay
	lda	MASTusr	; REquesting user number
	call	SENDNET
	mvi	E,$1ms	; Give user 1 ms to reply
	call	RECUSR
	jrnc	..good
;
	call	NETerr
	ret

..good:
	cpi	DTMack	; Check if ack character
	cnz	NETerr 	; Error if not ack
	ret
	]
	.page
	.sbttl	'hinet read-write-assign'
	.prntx	'made it to hinet read-write-assign'
;-----------------------------------------------------
;  H I N E T  R E A D - W R I T E - A S S I G N
;-----------------------------------------------------
; Master disk read
;  Regs in:   HL = buffer address
;  Regs out:  none
;  Destroyed: A, BC, DE, HL
MMread:
	.ife	FLOPshar,[
	call	saveMAST
	call	DDrd	; read double-density
	jmpr	restMAST
	]
	.ife	HARDshar,[
	lda	MASTsec
	mov	C,A	; sector number
	lda	MASTvol
	mov	B,A	; HD drive (volume) number
	lded	MASTtrk	; track number
	lda	MASTdsk	; unit number
	jmp	HARDr	; let HARDr do the rest
;----------
; Master disk read 1K
MMrd1:
	lda	MASTsec
	mov	C,A	; sector number
	lda	MASTvol
	mov	B,A	; HD drive (volume) number
	lded	MASTtrk	; track number
	lda	MASTdsk	; unit number
	jmp	HARD1	; let HARD1 do the rest
	]
;----------
; Master disk write
;  Regs in:   HL = buffer address
;  Regs out:  none
;  Destroyed: A, BC, DE, HL
MMwrite:
	.ife	HARDshar,[
	lda	MASTsec
	mov	C,A	; sector number
	lda	MASTvol
	mov	B,A	; HD drive (volume) number
	lded	MASTtrk	; track number
	lda	MASTdsk	; unit number
	push	H
	call	HARDw	; let HARDw do the work
	pop	H
	jmp	MIMIC	; mimic the write
	]
	.ife	FLOPshar,[
	call	saveMAST
	call	DDwr
	jmpr	restMAST
;
; Save master user's parameters
saveMAST:
	shld	MASTdma	; store buffer address
	lxi	H,cpmDESC
	lxi	D,saveDESC
	lxi	B,6
	ldir		; save master user's parameters
	lxi	H,mastDESC
	lxi	D,cpmDESC
	lxi	B,6
	ldir		; replace with slave's params
	ret
;
; Restore master user's parameters
restMAST:
	lxi	H,saveDESC
	lxi	D,cpmDESC
	lxi	B,6
	ldir
	ret
saveDESC:.blkb	6
	]
;----------
; Assign hard disk partition
;  Regs in:   HL = address of unit name and password
;  Regs out:  BC = unit and size
;	      DE = control byte and volume no
MMassign:
	.ife	HARDshar,[
	push	H	; save address of name
	mvi	A,assnHARD
	call	CMDhard	; send command to hard disk
	pop	H
	lxi	B,14
	call	SENDHARD; send name and password
	call	RESHARD	; get disk assignment
	lbcd	HARDstat; B = unit, C = size
	lded	HARDstat+2; D = volume, E = control
	ret
	]
	.page
	.sbttl	'mimic routines'
;-----------------------------------------------------
;  M I M I C   R O U T I N E S
;-----------------------------------------------------
; Poll mimic user every 1/3 sec
CHKmimic:
	.ife	HARDshar,[
	lxi	H,MASTsnd
	mvi	M,poll
	lxi	B,1
	mvi	E,0	; no delay necessary
	mvi	A,MIMICusr
	call	SENDNET	; poll mimic pseudo user
	lxi	D,$1ms
	call	RECUSR	; wait for an answer
	lda	MIMstat
	jrc	..no	; jump if timeout
	mvi	A,8	; poll up to 8 times in 4 secs
..no:	ora	A	;  before calling it quits
	rz
	dcr	A
	sta	MIMstat
	ret
;----------
; Mimic hard disk writes if mimicker is active
MIMIC:
	lda	MIMstat
	ora	A
	rz		; return if mimicker not active
;
..req:	push	H	; save DMA address
	lxi	H,MASTcom
	lxi	B,lencom
	mvi	E,0	; no delay necessary
	mvi	A,MIMICusr
	call	SENDNET	; send write req to mimicker
	lxi	D,$1ms
	call	RECUSR	; get ack
	jrnc	..good
;
	call	NETerr
	pop	h
	jmpr	..req
;
..good:
	pop	H	; resave DMA adr in
	push	h	; case of error
	lxi	B,128
	mvi	E,$halfms
	mvi	A,MIMICusr
	call	SENDNET	; send data to mimicker
	lxi	D,$1sec
	call	RECUSR	; get ack
	pop	h	; balance the stack
	rnc
;
	push	h	; save the DMA adr
	call	NETerr 	; error if no answer in time
	pop	h	; get DMA adr
	jmpr	..req
;
MIMstat:.byte	0	; mimicker status (0 if dead)
	]

	.page
	.sbttl	'record locking routines'
	.ife	HARDshar,[
;-------------------------------------------------
;  R E C O R D   L O C K I N G   R O U T I N E S
;-------------------------------------------------
;
; Process a network lock request
;  Regs out: A = lock status
MMlock:
	call	LOOKlock; search table for lock
	ora	A
	jrnz	..newlock; jump if not found
	mvi	A,lockdeny; found, so deny the request
	ret
..newlock:
	lxi	H,locklist; check free space in table
	lxi	D,16
	mvi	B,numlock
..look:	mov	A,M	; see if entry in use
	cpi	0FFh
	jrz	..store	; jump if its available
	dad	D
	djnz	..look
	mvi	A,locknack; no space available
	ret
..store:
	lda	MASTusr
	mov	M,A	; save user number
	inx	H
	lxi	D,MASTcom+1
	lxi	B,lenlock
	xchg
	ldir		; move lock to locklist
	mvi	A,lockack; acknowledge
	ret
;----------
; Process an unlock request
;  Regs out: A = lock status
MMunlock:
	call	LOOKlock
	ora	A
	jrz	..oldlock; jump if lock found
	mvi	A,locknack; lock not found, so error
	ret
..oldlock:
	mvi	M,0FFh	; clear the lock
	mvi	A,lockack
	ret
;----------
; Search the lock table for match with lock string
;  Regs out: A  = 0    if match found
;	     A  = 0FFh if not match found
;	     HL = address of match
LOOKlock:
;
; Check for lock string too short or too long
	lda	MASTcom+1
	ora	A	; error if length = 0
	jrz	..error
	cpi	lenlock+1; error if length > lenlock
	jrc	..ok
..error:pop	H	; pop return address
	mvi	A,locknack
	ret
;
; Fill lock string with blanks
..ok:	lxi	H,MASTcom+2
	lxi	D,MASTcom+1
	mvi	B,0
	mov	C,A
	ldir		; shift to left by one
	mov	C,A
	mvi	A,lenlock
	sub	C
	jrz	..start
	xchg
..bfill:mvi	M,' '
	inx	H
	dcr	A
	jrnz	..bfill
;
; Start searching at the beginning of the locklist
..start:lxi	H,locklist
	mvi	C,numlock
;
; Check whether entry is in use
..look:	mvi	B,lenlock
	mov	A,M	; see if entry is in use
	inx	H
	cpi	0FFh
	jrz	..noteq	; jump if not in use
	lxi	D,MASTcom+1
;
; Compare strings
..cmp:	ldax	D	; compare lock string
	cmp	M	; with table entry
	jrnz	..noteq
	inx	H
	inx	D
	djnz	..cmp
;
; Match found, so compute address of match and return
	lxi	H,locklist+numlock*16
	slar	C
	ralr	B
	slar	C
	ralr	B
	slar	C
	ralr	B
	slar	C
	ralr	B	; multiply BC by 16
	dsbc	B	; compute address of match
	sub	A	; match found
	ret
;
; Match not found, so continue search to end of table
..noteq:mvi	D,0
	mov	E,B
	inx	D
	inx	D
	dad	D	; compute address of next entry
	dcr	C
	jrnz	..look
	mvi	A,0FFh	; match not found
	ret
;----------
; Clear current user's locks from locklist
MMclrlock:
	lda	MASTusr
	lxi	H,locklist
	lxi	D,16
	mvi	B,numlock
..loop:	cmp	M	; check for match with userno
	jrnz	..repeat
	mvi	M,0FFh	; if match, then delete entry
..repeat:dad	D
	djnz	..loop	; check all entries
	ret
	]

.page
.sbttl	'spooling routines'
.prntx	'made it to spooling routines'

  .ife	SPOOLopt,[
;--------------------------------------------------
;  S P O O L I N G   R O U T I N E S
;--------------------------------------------------
;
; The spool table contains up to 8 entries.
; Each entry is 16 bytes long.  Each entry contains
; the following information:
;
; SPLstat==	0	; status of spool job
;			;  VALUES ARE:
SPLstart==	0	; start spooling
SPLspool==	1	; spooling
SPLready==	2	; ready to print
SPLprint==	3	; printing
SPLdone	==	4	; stop print (ctrlZ found)
SPLwait ==	5	; waiting to print
SPLabort==	0E5h	; abort job
;
; SPLusr==	1	; user number
; SPLscs==	2	; sec when job started
; SPLmins==	3	; min when job started
; SPLhrs==	4	; hour when job started
; SPLtrk ==	5-6	; current spool track
; SPLsec ==	7	; current spool sector
; SPLnam==	8-15	; user name
;
lenSPOOL==	16	; length of a spool table entry
;
; The following info is filled in by cold boot code
SPLdsk:	.byte	0	; spool partition number
SPLsiz: .byte	0	; spool partition size (1-16)
SPLvol:	.byte	0	; spool HD drive (volume, 0-3)
;
; The following info is sent to user when spool started
SPL$dsk:.byte	0	; spool disk
SPL$trk:.word	0	; spool track
SPL$sec:.byte	0	; spool sector
SPL$vol:.byte	0	; spool volume
;
; Print job info
PRINTjob:.word	0	; job being printed
PRINTtrk:.word	0	; track being printed
PRINTsec:.byte	0	; sector being printed
lenSbuf	==	128	; length of print spool buffer
PRNTbuf:.blkb	128	; print buffer
nxtSout:.byte	lenSbuf+1; ptr to next print char
SPLman: .byte	0	; 0 normally
			; non-zero if waiting for entry
SPLprep:.asciz	" Ready to print "
SPLask: .asciz	[cr][lf]"Enter *, S, P, W, or RETURN: "
	.page
;----------
; Start a spooling job
MMstart:
	lxi	D,(0FFh<8)!SPLabort
	call	JOBmatch
	jrnz	..ok
	sub	A	; no room, so ...
	sta	SPL$dsk	; deny spool request
	ret
..ok:
	lda	SPLvol
	sta	SPL$vol	; set spool volume no.
	lda	SPLdsk
	sta	SPL$dsk	; set spool disk no
	sded	SPL$trk	; set beginning track no
	mvi	A,2	; spooling really begins at 3
	sta	SPL$sec	; set beginning sector no
	lda	MASTusr
	inx	H
	mov	M,A  	; spool user number
	dcx	H
	push	H	; save spool table address
	lxi	B,8
	dad	B	; point to area for name
	push	H
	call	curUSR
	inx	H	; HL = name in user table
	pop	D	; DE = name in spool table
	ldir		; move name
	pop	H	; restore spool table address
	mvi	A,SPLstart; set status to "start spool"
	jmp	SPLupdate
;----------
; Stop a spooling job
MMstop:
	call	FNDspool; find current spool job
	rz		; return if none (ie, error)
	lda	Mode
	bit	ModeWAIT,A
	jrnz	..wait
	mvi	A,SPLready; set status to "ready"
	jmp	SPLupdate
..wait:	mvi	A,SPLwait ; set status to "wait"
	jmp	SPLupdate
;----------
; Spool 128 bytes
MMspool:
	lxi	H,MASTtrk
	lxi	D,SPL$trk
	lxi	B,3
	ldir		; update current spool trk, sec
	call	FNDspool; find current spool job
	rz		; return if none (ie, error)
	mvi	A,SPLspool; set status to "spooling"
	jmp	SPLupdate
;----------
; Abort spool job
MMabort:
	call	FNDspool; find current spool job
	rz		; don't bother if none
	mvi	A,SPLabort; status is "job aborted"
	jmp	SPLupdate
;----------
; ok2prnt indicates whether X-ON or X-OFF
; were returned by a serial printer to stop
; and restart print.
ok2prnt:
	.byte	0FFh	; Initialized to allow print
;
;----------
; The following code is invoked once per master pass
;
; Process user response to query if manual-print mode
CHKspool:
	lda	SPLman
	ora	A	; jump if we're not waiting for
	jrz	..act	;  a response to "Print" msg
;
	call	CONST
	ora	A
	rz		; return if no response yet
;
	call	CONIN	; get response
	push	PSW
	mov	C,A
	call	FORCEout; echo response
	pop	PSW
	cpi	cr
	jrz	..entered
;
	sta	SPLman	; save selection byte
	ret

..entered:
	mvi	C,lf
	call	FORCEout
	lxi	H,SPLman
	mov	A,M	; get selection byte
	mvi	M,0	; allow local user console I/O
	cpi	'a'
	jrc	..chkopt
;
	sui	'a'-'A'	; convert lower to upper case
..chkopt:
	lxi	H,Mode
	cpi	'P'	; print on parallel port
	jrz	..parallel
;
	cpi	'S'	; print on serial port
	jrz	..serial
;
	lhld	PRINTjob
	cpi	'W'	; wait (ie, suspend printout)
	jrz	..wait
;
	cpi	'*'	; abort this printout
	jz	..endjob
;
	cpi	cr	; cycle to next job
	jrz	..cycle
	jmp	..reprompt; error, so re-ask question

;----------
..parallel:
	set	ModePRT,M ; select parallel printer
	jmp	..print
;----------
..serial:
	res	ModePRT,M ; select serial printer
	jmp	..print
;----------
..wait:
	mvi	A,SPLwait
	call	SPLupdate ; set status to "waiting"
	jmp	..newjob
;----------
; Cycle through all ready print jobs
..cycle:
	lxi	D,lenSPOOL
	dad	D	; look at next table entry
	mov	A,L
	ora	A
	jrnz	..ok	; jump if not at end of table
;
	lxi	H,SPOOLlist
..ok:	mov	A,M	; check if job is ready
	cpi	SPLready
	jrnz	..cycle	; if not, continue scanning
;
	call	JOBfound; job is ready, so do it
	jmp	..nxtjob

;----------
; If no print job active, check for new job
..act:
	lhld	PRINTjob
	mov	A,H
	ora	L
	jz	..newjob
;
; If cntlZ found or SPOOL ABORT, then terminate print
	mov	A,M
	cpi	SPLdone
	jrnz	..chkrdy
;
	call	PRNToff	; turn off print interrupts
	jmp	..endjob

; If SPOOL RETRY, then put print job on ready queue
..chkrdy:
	cpi	SPLready
	jrnz	..chkbuf
;
	call	PRNToff	; turn off print interrupts
	jmp	..newjob

;----------
; Check if buffer is empty.  This indicates that
; the current print job needs to be supplied with a
; new sector. If the buffer isn't empty, print now.
..chkbuf:
	lda	nxtSout
	cpi	lenSbuf+1
	jrz	..newsect; service this or next job
;
; If parallel printer, print chars until buff flushed
;		       or printer busy
	lda	Mode
	bit	ModePRT,A
	jrnz	..par	; Jump if parallel
;
	lda	ok2prnt
	ora	A
	rnz		; Return if already printing
;
	call	PORT2st
	rz		; Return if no char ready
;
	call	PORT2in	; Clear Rx buffer, assume X-ON
	mvi	A,0FFh
	sta	ok2prnt	; Allow print again
	jmpr	..STprint ; Jump to re-start print

..par:
	in	PIOAD	; get transmitter status
	bit	6,A
	jrz	..prtchar; parallel printer ready
;
	mvi	A,10010111b
	out	PIOAC	; turn on parallel print ints
	mvi	A,10111111b
	out	PIOAC
	ret

..prtchar:
	call	PRINTchar; print next char
	jrnz	..chkbuf; repeat until all buff printed
			; or parallel port isn't ready
	jmpr	..endjob; cntl-Z found, so end of job

;----------
; Print next sector
..newsect:
	lxi	H,PRINTsec
	mov	A,M
	cpi	128	; check for last sect on trk
	jrnz	..read
;
	lxi	H,PRINTtrk
	mov	A,M
	inr	A
	ani	0Fh	; check for spool file too big
	jrz	..endjob; terminate if file too big
;
	inr	M	; inc track
	lxi	H,PRINTsec
	mvi	M,0
..read:
	inr	M	; inc sector
	lded	PRINTtrk; track
	mov	C,M	; sector
	lda	SPLvol
	mov	B,A	; HD drive (volume)
	lda	SPLdsk	; disk
	lxi	H,PRNTbuf
	call	HARDr	; read next sect into buff
	sub	A
	sta	nxtSout

;----------
; Activate printer (parallel or serial)
..print:
	lhld	PRINTjob
	mvi	A,SPLprint
	call	SPLupdate ; update spool table
	lda	Mode
	bit	ModePRT,A
	rnz		; don't do anything if parallel

..STprint:
	call	serON	; turn on serial interrupts
	call	PRINTchar; print first char
	rnz		; return if not cntl-Z
;
	call	PRNToff	; turn off serial interrupts
;----------
; Abort current job
..endjob:
	lhld	PRINTjob
	mvi	A,SPLabort
	call	SPLupdate

;----------
; Search for new print job
..newjob:
	lxi	D,(0FFh<8)!SPLready
	call	JOBmatch
..nxtjob:
	shld	PRINTjob
	rz		; no job waiting
;
	sded	PRINTtrk; set beginning track, sect
	mvi	A,3
	sta	PRINTsec

;----------
; Read first sector, and check for forms info
	mov	C,A	; sector
	lda	SPLvol	; HD drive (volume)
	mov	B,A
	lda	SPLdsk	; disk
	lxi	H,PRNTbuf
	call	HARDr	; read first sector
	sub	A
	sta	nxtSout	; reset buffer pointer
	lxi	H,PRNTbuf
	mov	A,M
	cpi	'('	; check for begin of form info
	jrnz	..chkmode ; jump if not found
;
	mvi	B,lenSbuf-3
..look:	inx	H
	mov	A,M
	cpi	')'	; check for end of form info
	jrz	..found
;
	djnz	..look
	jmpr	..chkmode ; jump if not found

..found:
	mvi	A,lenSbuf-1
	sub	B
	sta	nxtSout	; don't print form info
	jmpr	..reprompt; if forms info, manual prt

;----------
; If manual-print option selected, print message
..chkmode:
	lda	Mode
	bit	ModeSPL,A
	jrz	..print	; start immed. if autoprint
;
; Print "*** USERNAME Ready to print"
..reprompt:
	mvi	A,cr
	sta	SPLman	; turn off local user con I/O
	lxi	h,msgSTAR+1
	call	PRTMSG	; print "*** "
	lhld	PRINTjob
	lxi	B,8
	dad	B	; point to name in spool table
	mvi	B,8
	call	PRTSTR	; print user name
	lxi	H,SPLprep
	call	PRTMSG	; print "Ready to print"
;
; Print forms information, if any
	lda	nxtSout
	ora	A
	jrz	..ask	; jump if no forms info
;
	mov	B,A
	lxi	H,PRNTbuf
	call	PRTSTR	; print forms info
;
; Print "Enter *, S, P, W, or RETURN: "
..ask:
	lxi	H,SPLask
	call	PRTMSG
	ret

.page
.sbttl	'spooling utilities'
;-----------------------------------------------------
;  S P O O L I N G   U T I L I T I E S
;-----------------------------------------------------
; Force local user to wait for console I/O if spooler
; is in manual mode, and waiting to print
WAITspool:
	lda	LOCALflag
	ora	A
	rnz		; allow console I/O if master
;
	lda	SPLman
	ora	A	; wait until console is free
	jrnz	WAITspool
	ret
;----------
; Find active spooling job for current user
FNDspool:
	lda	MASTusr
	mov	D,A	; user number
	mvi	E,SPLspool; search for "spooling" job
	call	JOBmatch
	rnz
;
	lda	MASTusr
	mov	D,A	; user number
	mvi	E,SPLstart; search for "starting" job
;----------
; Search spool job table for match with userno and stat
;  Regs in:  E = status (0,1,2,3,4,or E5)
;	     D = user number (ignore if 0FFh)
;  Regs out: HL= pointer to matching entry
;	     DE = beginning track
;	     (HL = 0 and Z flag set if no match found)
JOBmatch:
	lda	SPLsiz
	ora	A
	jrz	..notfnd
;
	mov	B,A	; each entry = 256K
	lxi	H,SPOOLlist
..search:
	mov	A,E
	cmp	M	; compare status byte
	inx	H
	jrnz	..nomatch ; jump if no match
;
	mov	A,D
	cpi	0FFh	; ignore userno if 0FFh
	jrz	..found
;
	cmp	M
	jrz	..found

..nomatch:
	push	D
	lxi	D,lenSPOOL-1
	dad	D
	pop	D
	djnz	..search

..notfnd:
	lxi	H,1	; no match found
..found:
	dcx	H
JOBfound:
	mvi	D,0
	mov	E,L	; compute 1st track no
	mov	A,H
	ora	L	; set Z flag if HL = 0
	ret
;----------
; Update spool job table
;  Regs in:  HL = pointer to current job table entry
;	     A  = status byte
SPLupdate:
	mov	M,A	; set status byte
	xchg
	inx	D
	inx	D
	lxi	H,secs
	lxi	B,3
	ldir		; set sec, min, hr
	cpi	SPLready; update trk, sect
	jrnc	..1	;  only if starting, spooling.
;
	lxi	H,SPL$trk
	lxi	B,3
	ldir
..1:	cpi	SPLspool; update job table on disk
	rz		;  only if starting, ready,
;
	cpi	SPLprint;	   or aborting.
	rz
;
	mvi	A,writeNET
	sta	MASTcom
	lda	SPLdsk
	sta	MASTdsk
	lda	SPLvol
	sta	mastvol	;set up with spool volume
	lxi	H,0
	shld	MASTtrk
	mvi	A,1
	sta	MASTsec
	lxi	H,SPOOLlist
	call	MMwrite	; update spool table on disk
	mvi	A,2
	sta	MASTsec
	lxi	H,SPOOLlist+128
	jmp	MMwrite

.page
.sbttl	'spooling interupt driver'
;-----------------------------------------------------
;  S P O O L I N G   I N T E R R U P T   D R I V E R
;-----------------------------------------------------
; Process a printer interrupt
PRNT.SP:.word	0
	.byte	76h,76h,76h,76h,76h,76h,76h,76h
	.byte	76h,76h,76h,76h,76h,76h,76h,76h
	.byte	76h,76h,76h,76h,76h,76h,76h,76h
	.byte	76h,76h,76h,76h,76h,76h,76h,76h
PRNTstack:
PRNTint:
	push	psw
	call	disPRINT	; no other print int
	lda	LOCALflag	; 0 = local user active
	ora	a
	jrz	..saveregs
;
	ei
..saveregs:
	sspd	PRNT.SP
	lxi	sp,PRNTstack
	push	h
	push	d
;
	lda	ok2prnt	; zero means don't print
	ora	A
	jrz	..ret
;
	lda	nxtSout
	cpi	lenSbuf+1 ; check for end-of-buff
	jrz	..endbuf; jump if end-of-buffer
;
	call	PRINTchar; get next char from buffer
	jrnz	..ret	; jump if not cntl-Z
;
	lhld	PRINTjob
	mvi	M,SPLdone ; cntl-Z found

; End of buffer, so turn off transmitter ints
..endbuf:
	lda	Mode
	bit	ModePRT,A; check type of printer
	jrz	..offser
;
	mvi	A,00000011b
	out	PIOAC	; disable parallel ints
	jmpr	..ret

..offser:
	mvi	A,28h	; reset pending serial int
	out	SIO2AC	; because no char was sent
..ret:
	pop	d
	pop	h
	di
	call	serON	; serial only, parallel
	lspd	PRNT.SP	; on done in ..chkbuf
	pop	psw
	ei
	reti

;----------
; Handle external status interrupt from printer
PRNTerr:
	push	PSW
	mvi	A,10h
	out	SIO2AC	; reset ext status int
	pop	PSW
	ei
	reti

;----------
; disable serial or parallel ints
disPRINT:
	lda	Mode
	bit	ModePRT,a
	jrz	serOFF
;
	mvi	a,3
	out	pioAC
	ret

;----------
; Turn off printer interrupts
PRNToff:
	call	serOFF
	ei		; serOFF disables ints
	mvi	A,lenSbuf+1; force buffer empty
	sta	nxtSout
	ret

;-----------
; disable serial print ints
serOFF:
	di	; can't have serial prt int here
	mvi	a,11h
	out	sio2ac
	xra	a
	out	sio2ac
	ret	; ei done in caller when desired

;----------
; check to see if we want to enable printer ints
; this is because we've turned them off during
; polling to avoid conflicts with recFIRST ints.
; don't do anything if we are spooling
; on a parallel printer
ckPRTon:
	lda	Mode
	bit	ModePRT,a
	rnz		; parallel printer
;
	lhld	PRINTjob
	mov	a,h
	ora	l
	rz		; job not available
;
	mov	a,m
	cpi	SPLprint
	rnz		; job not printing
;
	lda	ok2prnt
	ora	a
	rz		; printer busy
;
	lda	nxtSout
	cpi	lenSbuf+1
	rz		; buffer empty
;
	di
	call	serON	; enable printer ints
	in	sio2ac
	bit	TxRdy,a	; dont send char if
	jrz	..enaEND; sio xmit buf is full
;
	call	PRINTchar; print next char
	jnz	..enaEND; char not a ctl-z
;
	lhld	PRINTjob
	mvi	m,SPLdone ; set job to done
..enaEND:
	ei
	ret

;----------
; Turn on printer interrupts
serON:
	mvi	A,11h
	out	SIO2AC
	mvi	A,00000011b
	out	SIO2AC
	ret

;----------
; Print next char and process cntlZ if found
;  Regs out:  Z flag set if cntlZ found
;	      If Z flag set, HL = job pointer
PRINTchar:
	lxi	H,Mode
	bit	MODEprt,M
	jrnz	..pnt	; Jump if parallel
;
	call	PORT2st	; Check if char present
	jrz	..pnt	; Jump if no char
;
	call	PORT2in	; Get char
	cpi	cntlS	; Check if X-OFF
	jrnz	..pnt	; Jump if not
;
	sub	A
	sta	ok2prnt	; Indicate no print
	call	serOFF	; shut off serial prnt ints
	ei
	jmpr	..git	; Do ret with Z flag reset

..pnt:
	lxi	h,nxtSout
	mov	e,m
	inr	m
	lxi	H,PRNTbuf
	mvi	D,0
	dad	D
	mov	A,M	; get next char to print
	cpi	cntlZ
	rz		; return if cntl-Z
;
; Print one character
	lxi	H,Mode
	bit	ModePRT,M
	jrz	..outser
;
	out	CENTP	; print character
	in	PPSTROBE
	ret

..outser:
	out	SIO2AD	; print character
..git:
	ori	1	; reset Z flag
	ret
	]

	.page
	.sbttl	'master utility routines send,receive user etc'
;--------------------------------------------------
;  M A S T E R   U T I L I T Y   R O U T I N E S
;--------------------------------------------------
;
; Send a message to a network user
;  Regs in:   A = message to be sent
;  Regs out:  none
;  Destroyed: A, BC, DE, HL
SENDUSR:
	lxi	H,MASTsnd
	mov	M,A
	lxi	B,1
	lda	MASTusr
	jmp	SENDNET
;----------
; Send a message to the user who is trying to login
;  Regs in:   A = message to be sent
;  Regs out:  none
;  Destroyed: A, BC, DE, HL
SENDLUSR:
	lxi	H,LOGresp
	mov	M,A
	mvi	A,LOGusr
	jmp	SENDNET
;----------
; Receive a message from a network user
;  Regs in:   DE = timeout counter
;  Regs out:  A  = message received
;	      carry flag set if user timed-out
;  	      or crc or overrrun error
;  Destroyed: A, BC, DE, HL
RECUSR:
	lxi	H,MASTsnd
	lxi	B,1
	sub	A
	call	RECNET
	call	ckRECstat
	jrnc	..end	; no error
	jrz	..end	; no err mss for dead user
;
	call	NETerr
	stc		; set carry if crc error
..end:	lda	MASTsnd
	ret
;----------
; Receive a command from a network user
;  Regs out:  A  = first byte of command
;	      carry flag set if user timed-out
;  	      or crc or ovrun err
;  Destroyed: A, BC, DE, HL
RECCMD:
	lxi	H,MASTcom
	lxi	B,lencom
	lxi	D,$1ms
	sub	A
	call	RECNET
	call	ckRECstat
	jrnc	..end	; no error
	jrz	..end	; no err mss for dead user
;
	call	neterr
	stc		; ret carry set for err
..end:	lda	MASTcom
	ret
;----------
; Get the user list pointer for the current user
;  Regs in:   none
;  Regs out:  HL = pointer to activity counter
;  Destroyed: DE
curUSR:
	lxi	D,userlist
	lhld	MASTusr	; L = current user number
	mvi	H,0
	dad	H	; multiply HL by 16
	dad	H
	dad	H
	dad	H
	dad	D	; compute address of activity
	ret
;----------
; Save time of most recent HiNet request
;  Regs in:  HL = pointer to user table entry
savereq:
	.ife	HARDshar,[
	lxi	D,12	; point to time in WHO table
	dad	D
	xchg
	lxi	H,secs	; get time from low core
	lxi	B,3	; save secs, mins, hrs
	ldir
	stax	D	; store request for WHO command
	]
	ret
	]	; end of ' if MASTopt '

;-----------------------------------
; check the status of a net xmission
; entry>	a = RECstat
; exit>		timeout	= Z set,   C set
;		crc$ovr	= Z reset, C set
;		no err	= Z reset, C reset
ckRECstat:
	stc
	bit	timeout,a
	rz

	ani	crc$ovr	; crc or ovrrun error
	jrz	..good
;
	stc		; <ani> resets carry
	ret		; set it for error

..good:
	mvi	a,0ffh
	ora	a
	ret
;
;----------
; Handle a network error - print an error message
Spaces:	.asciz	'    '
Umsg:	.asciz	[cr][lf]'*** User '
Nmsg:	.asciz	' Net error at '
Lmsg:	.asciz	'LATE'
Cmsg:	.asciz	'CRC'
Omsg:	.asciz	'OVR'
Smsg:	.asciz	'SYNC'
Mhdr:	.asciz	[cr][lf]'MAST'
Nhdr:	.asciz	[cr][lf]'NET '
nDESC:	.ascii	'buf: '
	.ascii	'Mst Usr To  Frm Dsk Track   '
	.asciz	'Sec Vol DMAadr'

NETerr:
	push	psw
	lda	Mode
	bit	ModeMSG,A ; print user error messages
	jrz	..noprint ; only if mode bit is set
;
	pop	psw	; ERRprint saves the flags
	jmpr	ERRprint; incr the error count and
			; provides a ret function
..noprint:
	lxi	h,errNET
	inr	m	; incr error count
	pop	psw	; restore flags
	ret
;
;--------
ERRprint:
	exaf		; save the flags
	lxi	H,Umsg
	call	PRTMSG	; print "*** User "

.ife	MASTopt,[lda	MASTusr]
		[lda	NETusr ]
	call	PRTBYT	; print user number in hex

.ife	MASTopt,[
	mvi	c,' '
	call	forceout; print a space
	call	curUSR
	inx	h	; adr of name field in who tbl
	mvi	b,8
	call	PRTSTR	; print users name
	]		; end of 'if MASTopt'

	lxi	h,Spaces
	call	prtMSG

; determine error type. Sequence of checks is:
;	a)	late
;	b)	over run
;	c)	crc
;	d)	sync 	(presumed if none of above)
;
; over run is tested before crc just in case
; an ovr error might also trigger a crc error

	lda	RECstat	; get REClast error byte
	rlc		; test for time-out
	jrc	..qOVR	; bit 7 is reset if error
;
	lxi	h,Lmsg	; print 'LATE'
	jmpr	..Eprint

..qOVR:
	bit	6,a	; ovr bit rotated 1 bit left
	jrz	..qCRC	; ovr bit set upon error
;
	lxi	h,Omsg	; print 'OVR'
	jmpr	..Eprint

..qCRC:
	lxi	h,Smsg	; rdy to print 'SYNC'
	rlc		; test for CRC error
	jrnc	..Eprint; crc bit set upon error
;
	lxi	h,Cmsg	; print 'CRC'
..Eprint:
	call	prtMSG
	lxi	h,Nmsg	; print ' NET error at '
	call	prtMSG

	pop	h	; get caller's adr
	call	prtCALLadr; print caller's adr
	push	h	; restore ret adr

.ife	Mastopt,[lxi	H,Mhdr]	; print 'MAST'
		[lxi	h,Nhdr]	; print 'NET '
	call	prtmsg

	lxi	h,nDESC
	call	prtMSG	; print error header
	lxi	h,blanks; and line up buffer dump
	call	prtMSG

.ife	MASTopt,[lxi	H,MASTsnd]; Mast buffer
		[lxi	H,NETmsg] ; else net buffer
	mvi	B,11
	call	PRBUFF	;print command buffer
;
	lxi	H,errNET
	inr	M	; increment error count
	exaf		; restore the flags
	ret


	.page
;----------
; Input a string from the console
;  Regs in:   HL = pointer to string
;	      E  = 0 means don't echo string
;		   1 means echo string
;
.ife	MASTopt,[
INMSG:
	mov	D,L	; remember start of string
..nxtchr:
	push	H
	push	D
	call	CONIN	; if master, do normal CONIN
	pop	D
	pop	H
	ani	7Fh	; mask out parity bit
..ok:	cpi	cr
	rz
	mov	C,A
	bit	0,E
	jrz	..save	; jump to avoid echo
	cpi	rubout
	jrz	..back
	cpi	backsp
	jrnz	..echo	; jump to echo
..back:	mov	A,D
	cmp	L
	jrz	..nxtchr; don't backspace too far
	dcx	H
	mvi	M,' '	; overwrite char with blank
	push	h	; the input save addr
	lxi	H,BACKmsg
	call	OUTMSG	; Output to console: BS, SP, BS
	pop	h	; Restore the addr.
	jmpr	..nxtchr
;
..echo:	call	outchr	; echo the char
	mov	A,C
..save:
	cpi	'a'	; convert lower to upper case
	jm	..store
	cpi	'z'+1
	jp	..store
	sui	'a'-'A'
..store:
	mov	M,A
	inx	H
	jmpr	..nxtchr
;
;----------
; Output a character to the console
;  Regs in:  C = character
outchr: in	SIO1AC
	ani	1<TxRDY
	jrz	outchr
	mov	A,C
	out	SIO1AD
	ret
;----------
; Output a string to the console
;  Regs in:   HL = pointer to string
OUTMSG:	mov	A,M
	ora	A	; string ended by zero byte
	rz
	mov	C,A
	call	outchr
	inx	H
	jmpr	OUTMSG
;
;----------
; Ask for user name and password
askname:
	call	INITname; Blank the user name and psw
	lxi	H,NAMEmsg
	call	OUTMSG	; PROM string out rtne.
	lxi	H,BOOTnam
	mvi	E,1	; echo chars
	call	INMSG	; get name
	lxi	H,PSWmsg
	call	OUTMSG	; PROM string out rtne.
	lxi	H,BOOTpsw
	mvi	E,0	; don't echo chars
	call	INMSG	; get password
	mvi	C,cr	; PROM crlf rtne.
	call	outchr
	mvi	C,lf
	jmpr	outchr
	.page
	.sbttl	'hinet station boot - phase 2'
	.prntx	'made it to boot phase 2'
;------------------------------------------------------
; H I N E T   S T A T I O N   B O O T  -  P H A S E  2
;------------------------------------------------------
; Read cold boot code and BIOS into low core;
; then move them to high core and execute cold boot.
;
;	    partitions,IOBYTE,nxtin,type-ahead
lendef	==	32	+1	+1	+31
off2set	==	.-TPA
NET2strap:
DSKSdef:.blkb	lendef	; default disk configuration
;
; Store the current time
	lxi	H,BOOTclk; store current time
	lxi	D,ticks
	lxi	B,7
	ldir
;
; Get the BIOS from the net.
..cboot:
	lxi	D,$4sec
	call	RECMSG
	lda	RECstat	; check rec status
	bit	timeout,a
	jrz	..cboot	; retry if timeout
	ani	crc$ovr
	jrnz	..cboot	; or crc or overrun
	lda	NETmsg	; get net cmd
	cpi	poll	; wait for poll
	jrnz	..cboot
	lxi	H,BOOTrd-off2set
	lxi	B,lencom
	mvi	E,$halfms
	sub	A
	call	SENDNET	; send read request to master
;
; Read CBOOT and BIOS backwards
..boot$bios:
	lhld	BOOTadr-off2set
	.ife	HARDshar, [lxi B,1024]
	.ife	FLOPshar, [lxi B,128]
	ora	A
	dsbc	B
	shld	BOOTadr-off2set	; update DMA address
	lxi	D,$4sec
        lda	NETusr
	call	RECNET		; get BIOS chunk
	bit	timeout,a
	jrz	..bioserr
	ani	crc$ovr
	jrnz	..bioserr
	mvi	E,$halfms
	mvi	A,datack
	call	SENDMSG		; acknowledge reception
;
; Prepare for next sector
	lda	BOOTsec-off2set
	.ife	HARDshar, [sui 8]
	.ife	FLOPshar, [dcr A]
	sta	BOOTsec-off2set	; update sector number
	lhld	COLDbas-8000h
	res	7,H
	lded	BOOTadr-off2set
	ora	A
	dsbc	D	; check if entire BIOS in core
	jrc	..cboot	; if not, jump to read more
;
; Relocate CBOOT and BIOS to high core
	lxi	H,0
	lded	COLDbas-8000h
	dsbc	D
	mov	B,H
	mov	C,L
	mov	H,D
	mov	L,E
	res	7,H
	ldir		; use block move
;
; Jump to the cold boot code (its right below the BIOS)
	lhld	COLDbas
	pchl
;
..bioserr:
	mvi	e,$halfms
	mvi	a,nack
	call	sendmsg
.ife	hardshar, [lxi	b,1024]
.ife	flopshar, [lxi	b,128]
	lhld	bootadr-off2set
	dad	b	; reset dma adr
	shld	bootadr-off2set
	jmp	..cboot
;
;----------
; Boot commands
	.ife	HARDshar,[
BOOTrd:	.byte	read1NET; read 1K at a time
	.byte	0	; destination
	.byte	0	; source
	.byte	0	; disk
	.word	2	; track
BOOTsec:.byte	123	; sector
	]
	.ife	FLOPshar,[
BOOTrd:	.byte	readNET	; read 128 bytes at a time
	.byte	0	; destination
	.byte	0	; source
	.byte	1	; disk
	.word	1	; track
BOOTsec:.byte	52	; sector
	]
BOOTadr:.word	8000h	; BIOS load address

	]	; end ' MASTopt '
;-----------------------
; put here so running master will be happy
; and booting station will also be happy
; and running station will be happy

	.byte	76h,76h,76h,76h,76h,76h,76h,76h
	.byte	76h,76h,76h,76h,76h,76h,76h,76h
	.byte	76h,76h,76h,76h,76h,76h,76h,76h
	.byte	76h,76h,76h,76h,76h,76h,76h,76h
RECstck:

  .ife	MASTopt,[
			; restart master code
	.page
	.sbttl	'hinet station boot - phase 1'
;
;------------------------------------------------------
; H I N E T   S T A T I O N   B O O T  -  P H A S E  1
;------------------------------------------------------
; The following code is broadcast on the network
; once per second.  To log in, a slave must load
; this program into location 9000h, and execute it.
;
off1set	==	.-9000h	; bootstrap executes at 9000h
len1strap==	380h	; length expected by PROM
len2strap==	200h	; len expected by LOGINFOX
;
NET1strap:		; Setup DSC/4 memmap, keep
			; pages 0 and 9 in local mem
	lixd	3FEh	; get serial number
	lxi	H,memmap-off1set
	lxi	B,0<8+SETMAP
..map:	outi
	mvi	A,11h
	add	B
	mov	B,A
	jrnz	..map
	in	ONMAP	; activate DSC/4 memory map
;
; move PROM to RAM before setting int vector (avoids ram trash bug)
	lxi	H,0		; move from 0000H
	lxi	D,0a000H	; to 0a000H (ram)
	lxi	B,1000H		; 4K bytes
	push	H		; 0000h is currently
	push	D		; boot PROM
	push	B
	ldir
	pop	B		; and back from
	pop	H		; 0a000h to
	pop	D		; 0000H
	in	OFFPROM		; after disabling PROM
	ldir			; at bank 0
;
; Move remainder of boot code to high core
	lxi	H,9000h
	lxi	D,NET1strap
	lxi	B,len1strap
	ldir
	jmp	BOOT	; execute rest of bootstrap
;
; DSC/4 memory map
memmap:	.byte	0FFh, 000h, 0F1h, 0F2h ; pages F,0,1,2
	.byte	0F3h, 0F4h, 0F5h, 0F6h ; pages 3,4,5,6
	.byte	0F7h, 0F8h, 000h, 0FAh ; pages 7,8,9,A
	.byte	0FBh, 0FCh, 0FDh, 0FEh ; pages B,C,D,E
;
HiNETmsg:
	.ascii	[cr][lf]'HiNet '
	.byte	version+'0','.',revision/100+'0'
	.byte	(revision@100)/10+'0'
	.byte	(revision@100)@10+'0'
	.byte	patch
	.ife	HARDshar,[
	.asciz	[cr][lf]'Login please'
NAMEmsg:.asciz	[cr][lf]'Name: '
PSWmsg:	.asciz	[cr][lf]'Password: '
	]
	.ife	FLOPshar,[.byte 0]
	.page
	.sbttl	'relocated bootstrap code'
;----------
; Relocated bootstrap code
BOOT:
	lxi	B,90h<8+SETMAP
	mvi	A,0F9h
	outp	A
	lxi	SP,9800h; setup a stack
	mvi	A,(vectors>8)&0FFh
	stai		; setup interrupt register
	im2
	mvi	A,45h	; set counter mode
	out	CTC1
	mvi	A,2	; 2 = 1Mhz/baudrate
	out	CTC1
;
; Set the user number addr
	lxi	H,Nbootusr
	shld	USRadr
;
;Try to log in with the PROM serial # as user name
;(Turnkey login procedure)
	call	cvSER	;Convert serial # to ASCII...
			;and store at BOOTnam
	lhld	USRadr	;Addr of addr of user number
	mvi	M,LOGusr; Store login user number
..tlagn:
	call	..poll	;wait for poll then log in
;
; Tell the user that the HiNet is up
..notTK:
	lxi	H,HiNETmsg
	rst	3	; PROM string output rtne.
..askname:
	.ife	HARDshar,[call asknm2]
;
; Try to log in with user name supplied from console
..ologin:		;Original login procedure
	call	..poll
	mvi	A,bell	;..poll rets only on error
	rst	2	;PROM char out rtne.
	jmpr	..askname
;
; Wait for poll of user 253; then request login
..poll:
	lxi	D,$4sec
	call	RECMSG	; no error checks here
	bit	timeout,a
	jrz	..poll
;
	ani	crc$ovr
	jrnz	..poll
;
	lda	NETmsg
	cpi	poll
	jrnz	..poll
;
	lxi	H,BOOTcom
	lxi	B,lencom+2
	mvi	E,$halfms
	sub	A
	call	SENDNET
;
; Get response to login request
..logresp:
	lxi	H,BOOTresp
	lxi	B,lencom+3
	lxi	D,$4sec
	mvi	A,LOGusr
	call	RECNET
	bit	timeout,a
	jrz	..poll
;
	ani	crc$ovr
	jnz	..poll
;
	lhld	BOOTprom
	lded	BOOTver
	ora	a
	dsbc	d
	jrnz	..retry
;
	lda	BOOTresp
	cpi	logack
	jrz	..login	;Jump if we're logged in
;
	cpi	logdeny
	rz		;return if not valid name

..retry:
	call	..delay	;Random delay if someone
			;else tried to log in
	jmpr	..poll	;Jump to try again
	ret
;
; Delay random period of time, then retry
..delay:ldar		; use refresh register
	ani	7	; (its a good random seed)
	inr	A	; Make it non-zero
	mov	B,A
..outer:lxi	H,0	; delay about 400ms per pass
..inner:dcx	H
	mov	A,H
	ora	L
	jrnz	..inner
	djnz	..outer	; low 3 bits of R = pass count
	ret

..login:
; Turn off PROM
;	OFFPROM now done at BOOT: to avoid mem trash
	lxi	B,00h<8+SETMAP
	mvi	A,0F0h
	outp	A
	lxi	SP,80h	; Set up a new stack
	lxi	H,NETusr
	shld	USRadr	; Set addr of user number
;
; Get user number
	lda	BOOTnum	; get user number
	sta	NETusr	; store it for BIOS
;
; Get the rest of the bootstrap code
	lxi	H,TPA
	lxi	B,len2strap
	lxi	D,$4sec
	call	RECNET
	bit	timeout,A
	jz	boot	; restart boot process
;
	jmp	TPA+lendef; jmp to phase 2
;
; Convert the lo nybble of reg. A to an ASCII hex digit
; Regs. in: A contains value to convert.
; Regs. out: A contains ASCII digit.
; Destroyed: A
cvDIG:
	ani	0fh	;Leave only the 4 LSB
	adi	30h
	cpi	3ah
	rc		;Return if char is 0 thru 9
	adi	07h	;Convert to A thru F otherwise
	ret
;
; Convert a byte in A to 2 ASCII hex digits in HL.
; L is the 1st char (MSD), H is the 2nd (LSD).
; Regs. in: A is the char.
; Regs. out:HL contains ASCII digits.
; Regs. destroyed: A, HL
byt2asc:
	push	psw	;save the byte
	call	cvDIG	;convert the lo nybble
	mov	H,A	;store the ASCII digit in H
	pop	psw	;get the byte back
	rar
	rar
	rar
	rar		;shift hi nybble to lo nybble
	call	cvDIG	;convert the nybble
	mov	L,A	;put it in L
	ret		;return
;
; 	Convert the PROM serial number
;	to a 4 byte ASCII string in the login string.
; Regs. in : none
; Regs. out: none
; Regs. destroyed: A, HL
cvSER:
	call	INITname  ;Blank user name and psw
	push	X	  ;PROM serial # is in IX
	pop	H		;Get it in HL
	shld	BOOTprom
	push	H		;Save it back on stack
	mov	a,l 	;convert the 1ST byte to ASCII
	call	byt2asc		;do it
	shld	BOOTnam	 ;store it in the login string
	pop	h		;restore the serial #
	mov	a,h
	call	byt2asc	 ;convert the 2ND byte to ASCII
	shld	BOOTnam+2    ;store in the login string
	ret

  .ife	HARDshar,[
INITname:		;Initialize user name and psw
	lxi	h,0
	shld	BOOTver	; init boot prom ser#
	lxi	H,BOOTnam
	mvi	M,' '	; fill name and psw with blanks
	lxi	D,BOOTnam+1
	lxi	B,13
	ldir
	ret
;
;----------
; Ask for user name and password
asknm2:
	call	INITname ; Blank the user name and psw
	lxi	H,NAMEmsg
	rst	3	; PROM string out rtne.
	lxi	H,BOOTnam
	mvi	E,1	; echo chars
	call	INMSG2	; get name
	lxi	H,PSWmsg
	rst	3	; PROM string out rtne.
	lxi	H,BOOTpsw
	mvi	E,0	; don't echo chars
	call	INMSG2	; get password
	rst	4	; PROM crlf rtne.
	ret
;----------
; Input a string from the console
;  Regs in:   HL = pointer to string
;	      E  = 0 means don't echo string
;		   1 means echo string
; modified to shorten bootstrap, 20 oct 82
; and again, 10feb83 and again, 09mar83
; now backspace and delete count
INMSG2:
	rst	1
	ani	7fh	; strip top bit
	cpi	cr
	rz		; end upon <cr>

..convert:
	cpi	'a'	; convert to
	jm	..store	; uppercase
	cpi	'z'+1
	jp	..store
	sui	'a'-'A'

..store:
	mov	m,a
	inx	h	; incr buff ptr
	bit	0,e
	jrnz	inmsg2

..erase:
	push	h
	lxi	h,backmsg
	rst	3	; output
	pop	h	; bs,space,bs
	jmpr	inmsg2
;
	backmsg:
		.byte	08h,20h,08h,0
		; erase last char (prom echo)
	]
	]		; end of MASTER code

	.page
	.sbttl	'SENDNET'
    .ife	NETopt,[

;----------
; Send a message to the master
;  Regs in:   A = message to be sent
;  Regs out:  none
;  Destroyed: A, BC, DE, HL
SENDMSG:
	lxi	H,NETmsg
	mov	M,A
	lxi	B,1
	sub	A	; master number = 0
			; fall thru to SENDnet
;----------
; Transmit a block on the network
;  Regs in:   HL = block address
;   	      BC = byte count
;	      E  = delay time (master only)
;	      A  = user number
;  Regs out:  none
;  Destroyed: A, BC, DE, HL
; SendNet is extremely time-critical, particularly
; for DSC-4's, so modify it at your own risk.
SENDNET:

  .ifn	MASTopt,[mvi   e,$halfms]  ; delay 1/2 msec

	inr	E	; delay so that receiver has
..spin:	dcr	E	; time to prepare for message
	jrnz	..spin

	mov	D,A	; save user number
	shld	DMANSadr; store block address
	dcx	B	; DMA chip wants real size - 1
	sbcd	DMANSsize
	mov	A,C
	ora	B
	di		; prevents int of
			; time critical code
	jrz	..notDMA

; send a data block using DMA
..useDMA:
	lxi	H,DMATdone; setup the DMA vector
	shld	DMAvect
	mvi	A,1	; multiplex SIO1B to DMA
	out	PIOAD

	lxi	H,DMANSprog; program the DMA chip
	lxi	B,DMAN$<8+DMA
	outir

	lxi	H,SENDprog
	lxi	B,SEND$<8+SIO1BC
	outir

	mvi	b,9
	djnz	.	; force 3 leading flags

	lxi	h,sDMAflag
	mvi	m,0	; reset dma done flag
	mov	a,d
	di
	out	sio1bd	; send user number
	mvi	a,enaDMA
	out	DMA	; enable dma chip
	mvi	a,rstEOM
	out	sio1bc	; reset underrun flag (SIO)
	ei
..testDONE:
	mov	a,m	; DMATdone sets sDMAflag
	ora	a
	jrz	..testDONE
	jmpr	..fin

; send one data byte so no need to use DMA
..notDMA:
	lxi	H,SENDprog
	lxi	B,SEND$<8+SIO1BC
	outir

	mvi	b,9
	djnz	.	; force 3 leading flags

	lbcd	DMANSadr
	ldax	b
	mov	e,a	; get message byte
	mvi	c,sio1bd
	di
	outp	D	; send userno
	mvi	a,rstEOM
	out	sio1bc	; reset under run flag
..wait:
	in	sio1bc
	bit	TxRdy,a
	jrz	..wait
;
	outp	E	; send message byte

; Handle the end of the transmission
..fin:
	mvi	B,20h	; force CRC bytes
	djnz	.	; and min 3 closing flags

	mvi	A,rstCHANNEL
	out	SIO1BC	; reset the SIO chip
	ei
	ret
;
;---------------
; RECtime sets the timeout interval for RECNET
; Only assembled for a HiNet station
; Regs in:	BC = timeout constant
; Regs out:	none
; Destroyed:	none

  .ifn	MASTopt,[
RECtime:
	sbcd	Rtime
	ret
Rtime:
	.word	$4sec
	]

	.page
	.sbttl	'RECNET'
;----------
; Receive a message from the master
;  Regs in:   none
;  Regs out:  A = xmission err status
;  NETmsg = receive message char
;  Destroyed: BC, DE, HL
RECMSG:
	lhld	USRadr
	mov	a,m	; get user number
	lxi	H,NETmsg
	lxi	B,1
			; fall thru to RECnet

;----------
; Receive a block from the network
;  Regs in:   HL = block address
;	      BC = maximum byte count
;	      DE = timeout count (master only)
;	      A  = user number
;  Regs out:  A  = error status
;		   bit 7 reset 	= time-out
;		   bit 6 set	= CRC error
;		   bit 5 set	= receiver overrun
;		   bit 0 set	= poll only rcv'd
;  Destroyed: A, BC, DE, HL
RECNET:
	call	RECbegin  ; program the SIO chip

;----------
; Wait for next poll from network and don't ack
; ENTRY>	none
; EXIT>		see RECnet
;  Destroyed: BC, HL
NACKpoll:
	ei		  ; make sure SIO can interrupt
	lxi	H,ACKflag ; point to ack/nack status
	mvi	M,1	  ; don't ack polls (REClast)
	lxi	h,RECstat ; point to receiver status
	mvi	m,60h	  ; init RECstat to errors

  .ifn	MASTopt,[
	lded	Rtime	 ; if slave, timeout is 4 sec
	]
;
; Wait for block received from network cable
..wait:	mvi	B,8	; inner loop count
..loop:	mov	A,M	; check receiver status
	bit	4,A
	rnz		; return if block received
	djnz	..loop
;
	dcx	D	; decrement timeout count
	mov	A,E
	ora	D
	jrnz	..wait	; fall through if timeout
;
	di		; prevent real SIO int
	call	REClast	; pretend we received a block
	res	pollRCV,m ; no valid poll rcv'd
	mov	a,m	; return error status
	ret

;----------
; Program the SIO to acknowledge polls from the master
;  Regs in:   none
;  Regs out:  none
ACKpoll:
	sub	A	; acknowledge polls
	sta	ACKflag

;---------------------
; starts the poll acking sequence
begACK:
	lxi	h,NETmsg; put poll here
	lxi	b,1	; receive one byte
	lda	NETusr	; addressed to us

;----------
; Program the SIO chip to receive a block
RECbegin:
	sta	RECadr	; station address
	shld	DMANRadr; DMA address
	dcx	B
	sbcd	DMANRsize; DMA rcv len = real len-1
	mov	A,C
	ora	B
	di		; no ints while prog vects
	jrz	..prog
;
; Receive more than one byte
	lxi	H,REClast; setup the DMA vector
	shld	DMAvect
	mvi	A,1	; multiplex SIO1B to DMA
	out	PIOAD
	lxi	H,DMANRprog; program the DMA chip
	lxi	B,DMAN$<8+DMA
	outir
..prog:
	lxi	H,RECfirst; setup interrupt vectors
	shld	SIO1vect+4
	lxi	H,REClast
	shld	SIO1vect+6
	lxi	H,RECprog; program the SIO chip
	lxi	B,REC$<8+SIO1BC
	outir
	ei		; make sure interrupts enabled
	ret

;
; USRadr is necessary because of the decision to use
; the PROM console routines for CONIN and CONOUT in
; the net boot, i. e. if the PROM is enabled,
; location 47h (NETusr) is unavailable.
; USRadr is initialized to NETusr because it
; assembles with station code as well.
;			24MAR82MdG
;
USRadr:
	.word	NETusr

Nbootusr:
	.byte	0	; User number is here
			; during net boot
ACKflag:
	.byte	0	; ACKPOLL/NACKPOLL flag

sDMAflag:
	.byte	0	; 0 = DMA not done

rcvDMAlen:
	.word	0	; actual rcv'd block length

RECstat:
	.byte	60h	; rcv status - init to timeout,
			; crc & ovr err - no poll rcv'd
REC.SP:
	.word	0	; SP before interrupt


	.page
	.sbttl	'SDLC interupts'

;----------
; SDLC receive interrupt on first char
RECfirst:
	push	PSW
	push	h
	in	SIO1BD	; flush user number
	lhld	DMANRsize; if len = 0, don't use DMA
	mov	a,l
	ora	h
	jrz	..noDMA
;
; use the dma chip to receive a block of data
	mvi	A,enaDMA; enable DMA
	out	DMA
	jmpr	..ret

..noDMA:
	in	sio1bd	; get message byte
	lhld	DMANRadr; get buffer address
	mov	m,a	; put message into buffer
	dad	h	; done for timing
	in	sio1bd	; flush first crc byte

..ret:
	pop	h
	pop	PSW
	ei
	reti

;----------
; SDLC receive interrupt on last char
REClast:

	sspd	REC.SP
	lxi	SP,RECstck
	push	D
	push	PSW
	push	h
	push	b

	lxi	h,1<8+rstCHAN
	in	sio1bd	; flush 1st crc byte if dma
			; 2nd if not dma
	mvi	c,sio1bc; hinet control port
	outp	h	; get ready to read reg 1
	inp	a	; read receive status
	outp	l	; reset sio1b channel
	ani	0e0h	; mask relevant bits
	set	4,a	; no timeout
	sta	RECstat
;
	lhld	DMANRsize; if len = 0, don't use DMA
	mov	a,l
	ora	h
	jrz	..pastDMA
;
	lxi	h,ckDMAlen	; program the DMA chip
	lxi	b,DMAlen$<8+DMA	; to send actual rcv'd
	outir			; data length

	lxi	h,rcvDMAlen	; store actual rcv'd
	lxi	b,2<8+DMA	; data length at
	inir			; rcvDMAlen

	mvi	A,rstDMA	; reset the DMA chip
	out	DMA

..pastDMA:
    .ifn	MASTopt,[
	lhld	PPAadr
	mov	A,M	; Get PP status byte
	cpi	2
	jrz	..PPblk	; Jump if we got data blk

..ckSIZE:
; If DMA size > 0, msg was neither a valid
; poll nor a valid poll-prime
	lhld	DMANRsize
	mov	a,l	; Non-zero if data block
	ora	h
	jrnz	..ret

; Check if msg. was a poll-prime
	lhld	DMANRadr
	mov	a,m	; Get msg. byte
	cpi	POLLpr
	jrnz	..ckPOLL; jump if not poll-prime

..isPRIME:
; Reset bit used by RECNET
	lxi	h,RECstat
	res	4,m
;
; Check if accepting poll-primes
	lhld	PPAadr
	mov	A,M	; Get poll-prime status
	cpi	1
	jrnz	..begRET; Jump if ignoring poll-primes
;
; Update status byte
	mvi	M,2	; Still pointing at PP status

; Send poll-prime acknowledge
	lxi	H,NETmsg
	mvi	M,PPack	; sending poll-prime ack
	lxi	B,1	; Msg. length
	mvi	A,PPusr	; PP ack pseudo-user number
	call	SENDNET
;
; Call RECbegin to rcve. PP data block
	lhld	PPAadr
	lxi	D,3
	dad	D	; Point to PP data area
	lxi	B,PPmlen; PP msg. length
	lda	NETusr	; Our user number
	call	RECbegin; Reprogram the SIO
	jmpr	..ret

..ckPOLL:
; insure we received a poll
	cpi	poll	; if poll, should we ack
	jrnz	..begRET; ensure SIO is programmed

; Check to ack poll
..qACK:
	lxi	h,RECstat
	set	pollRCV,m ; flag for poll rcv'd
	lda	ACKflag
	ani	1
	jrnz	..ret	; Jump if no pollack wanted
;
; Ack the poll
	lda	flopBUSY
	ora	a
	jrnz	..skipACK
;
	mvi	A,pollack
	call	SENDMSG

..skipACK:
	call	ACKpoll
	jmpr	..ret

..PPblk:
; Update PP status
	lhld	PPAadr
	lda	RECstat
	res	4,a	; Pretend no poll rcvd
	ori	3	; Indicate PP data blk rcvd
	sta	RECstat
	mov	M,A	; Store PP status
;
; Reprogram SIO for polls
..begRET:
	call	begACK
..ret:
	]		; end ' not MASTopt '

	pop	b
	pop	h
	pop	PSW
	pop	D
	lspd	REC.SP
	ei		; ints ok now
	reti
;
;----------
; DMA transmit complete interrupt
DMATdone:
	push	psw
	mvi	A,rstDMA; reset the DMA chip
	out	DMA	; and IEO line
	sta	sDMAflag
	pop	psw
	ret

.page
.sbttl	'psuedo numbers, network messages and commands'
;
;---------------
; Pseudo-user numbers
BOOTusr	==	254	; boot pseudo user number
LOGusr	==	253	; login pseudo user number
MIMICusr==	252	; mimic pseudo user number
PPusr	==	251	; poll-prime pseudo user number
;
;----------
; Network messages and commands
poll	==	'P'	; poll from master
POLLpr	==	'U'	; poll-prime from user
pollack	==	'A'	; poll-received ack
PPack	==	'V'	; poll-prime-received ack
datack	==	'D'	; data received ack
mesack	==	'M'	; message received ack
nack	==	'N'	; negative acknowledge
logack	==	'L'	; login acknowledge
lognack ==	'N'	; login conflict
logdeny	==	'D'	; login denied
lockack	==	0	; lock acknowledge
locknack==	2	; lock error
lockdeny==	1	; lock denied
hogack	==	'H'	; hog acknowledge
hogdeny	==	'D'	; hog denied
HSTack	==	'S'	; HD status rcve ack
DTMack	==	'T'	; date/time rcve ack
whoNET	==	10h	; who command
readNET	==	11h	; read command
writeNET==	12h	; write command
loginNET==	13h	; login command
startNET==	14h	; start spool command
read1NET==	15h	; read 1K command
stopNET ==	16h	; stop spool command
assnNET	==	17h	; assign command
hogNET  ==	18h	; hog command
lockNET	==	19h	; lock command
unlockNE==	1Ah	; unlock command
clrlockN==	1Bh	; clearlocks command
spoolNET==	1Ch	; spool command
hdstNET	==	1DH	; hard disk volume status cmd
dttmNET	==	1Eh	; date/time status
;------------------------------------------------
; Network protocols:
;
;		MASTER	   SLAVE
;               ------     -----
; Poll:   	poll   -->
;		       <-- pollack
; -----------------------------------------------
; Write:	poll   -->
;		       <-- writeNET
;		mesack -->
;		       <-- DATA
;		datack -->
; -----------------------------------------------
; Read:		poll   -->
;		       <-- readNET
;		DATA   -->
;		       <-- datack
; -----------------------------------------------
; Login:	poll   -->
;		       <-- loginNET
;		logack -->
;	       (logdeny)
; -----------------------------------------------
; Assign:       poll   -->
;		       <-- assignNET
;		DATA   -->
;------------------------------------------------
; Hog:		poll   -->
;		       <-- hogNET
;		hogack -->
;	       (hogdeny).
;		       <-- pollack
;------------------------------------------------
	.page
	.sbttl	'sio and dma commands for network activity'
	.prntx	'made it to sio and dma commands'
; SIO commands
SENDprog:
	.byte	    00011000b ; channel reset
	.byte	14h,00100000b ; SDLC mode
	.byte	  3,00100000b ; auto enables
	.byte	11h,11000100b ; no interrupts
	.byte	  5,11101011b ; transmitter enable
	.byte	    10000000b ; reset CRC generator
SEND$	==	.-SENDprog
;
RECprog:
	.byte	    00011000b ; channel reset
	.byte	  4,00100000b ; SDLC mode
	.byte	  2,SIO1vect&0FFh ; interrupt vector
	.byte	    01000000b ; reset crc check
	.byte	15h,10000000b ; transmit disable
	.byte	  3,11111100b ; receiver info
	.byte	6
RECadr:	.byte	0	      ; user number
	.byte	  7,01111110b ; flag byte
	.byte	11h,11101100b ; interrupt on first byte
	.byte	23h
RECable:.byte	    11111101b ; enable receiver
REC$	==	.-RECprog
;----------
; DMA commands
DMANSprog:
	.byte	0C3h	; master reset		     2D
	.byte	0C7h	; reset port A		     2D
	.byte	0CBh	; reset port B		     2D
	.byte	79h	; write
DMANSadr:.word	0	; filled by SENDNET or RECstart
DMANSsiz:.word	0	; filled by SENDNET or RECstart
	.byte	14h	; port A inc, memory	     1B
	.byte	28h	; port B fixed, I/O	     1B
	.byte	95h	; byte mode		     2B
	.byte	SIO1BD	; port B
	.byte	12h	; interrupt at end of block
	.byte	DMAvect&0FFh ; interrupt vector
	.byte	92h	; stop at end of block
	.byte	0CFh	; load starting address      2C
	.byte	writeDMA; write
	.byte	0CFh	; load starting address	     1A
	.byte	0ABh	; enable interrupts	     2D
DMAN$	==	.-DMANSprog
	]
;
DMANRprog:
	.byte	0C3h	; master reset		     2D
	.byte	0C7h	; reset port A		     2D
	.byte	0CBh	; reset port B		     2D
	.byte	7Dh	; read
DMANRadr:.word	0	; filled by SENDNET or RECstart
DMANRsiz:.word	0	; filled by SENDNET or RECstart
	.byte	14h	; port A inc, memory	     1B
	.byte	28h	; port B fixed, I/O	     1B
	.byte	95h	; byte mode		     2B
	.byte	SIO1BD	; port B
	.byte	12h	; interrupt at end of block
	.byte	DMAvect&0FFh ; interrupt vector
	.byte	92h	; stop at end of block
	.byte	0CFh	; load starting address      2C
	.byte	readDMA	; read
	.byte	0CFh	; load starting address	     1A
	.byte	0ABh	; enable interrupts	     2D

ckDMAlen:
	.byte	0bbh	; set read status mask	     2D
	.byte	06h	; read the byte counter	     2D
	.byte	0a7h	; initiate read sequence     2D
DMAlen$	==	.-ckDMAlen
	]

	.page
	.sbttl	'process a timer interupt'
	.ife	TIMERopt,[
;----------
; Process a timer interrupt
;
TIME.SP:.word	0
	.byte	76h,76h,76h,76h,76h,76h,76h,76h
	.byte	76h,76h,76h,76h,76h,76h,76h,76h
	.byte	76h,76h,76h,76h,76h,76h,76h,76h
	.byte	76h,76h,76h,76h,76h,76h,76h,76h
TIMEstack:
TIMERint:
	push	PSW
  .ife	MASTopt,[
	lda	LOCALflag
	ora	A
	jrz	..saveregs
	]
	ei
..saveregs:
	sspd	TIME.SP
	lxi	SP,TIMEstack
	push	H
	push	D
	push	B
;
.ife	MASTopt,[
	; check for char from master console
	; but not if local user while
	; waiting for spool selection

	lda	LOCALflag
	ora	a		; nonzero then master
	jrnz	..ckSIO
;
	lda	SPLman		; local user so see if
	ora	a		; waiting for spool info
	jrnz	..uptime

..ckSIO:
	in	sio1ac
	bit	0,a
	jrz	..uptime

..charIN:
	call	getCHAR		; also see if buf is full
	jrnz	..putCHAR 	; if not full, save char
;
	mvi	C,bell	; ring bell if buffer full
	call	FORCEout
	jmpr	..uptime

..putCHAR:
	call	plusBUF
	]	; end ' MASTopt '

; Update fractions of a second
..uptime:
	lxi	H,ticks
	lda	ticsec	; 60 for U.S., 50 for Europe
	inr	M
	cmp	M
	jrnz	..timeout
;
	mvi	M,0
	inx	H
;
; Jump to local user once per second
	.ife	MASTopt,[
	call	LOCALtime
	lxi	H,secs
	]
;
; Update seconds
	mvi	A,60
	inr	M
	cmp	M
	jrnz	..timeout
	mvi	M,0
	inx	H
;
; Update minutes
	inr	M
	sub	M
	jrnz	..timeout
	mov	M,A
	inx	H
;
; Update hours
	mvi	A,24
	inr	M
	sub	M
	jrnz	..timeout
	mov	M,A
;
; Update days
	inx	H
	inx	H
	inr	M
;
; Decrement each active down-counter, and call each
; time-out routine whose counter has reached zero.
..timeout:
	lda	lockbyte
	ora	A
	jrnz	..ret
	lxi	H,counters
;
; Unload the floppy disk head after 1 seconds
; of inactivity
	.ife	FLOPopt&MINIopt,[
	mov	A,M
	ora	A
	jrz	..1
	dcr	M
	jrnz	..1
..offm: call	offMOTOR; also flush buffer
	jmpr	..ret
..1:	inx	H
	]
;
; Invoke the network master every 1/60 second
	.ife	MASTopt,[
	mov	A,M
	ora	A
	jrz	..ret
	dcr	M
	jrnz	..ret
..mast:	pop	B
	pop	D
	lspd	TIME.SP
	pop	PSW
	lxi	H,MASTER
	push	H
	lhld	TIMEstack-2; restore HL
	reti		; goto network master code
	]
;
; Restore the user's registers and return
..ret:
	pop	B
	pop	D
	pop	H
	lspd	TIME.SP
	pop	PSW
	ei
	reti
;
; Come here once per second
;
.ife	MASTopt,[
INTERUPT:
	ret
	]
;
; Event down-counters are stored here
counters:
;
	.ife	FLOPopt&MINIopt,[
timeMOTOR:
	.byte	0
	]
;
	.ife	MASTopt, [timeMAST:  .byte 0]
	]	; end of 'timeropt'
;
	.page
	.sbttl	'process a front panel interupt'
	.ife	FRONTopt,[
;----------
; On a front-panel interrupt, jump to location 30h.
; This will cause a warm boot if the CCP is running,
; or will return to DDT if it is running.  Any program
; can intercept front-panel interrupts by changing
; the jump intruction at location 30h.
FRONTint:
	in	PIOAD	; read interrupt status
	ani	80h	; if not high, then must be HLT
	jrz	HALTerr	; cause getting here clears HLT
	lxi	H,..1	; but if front panel int. then
	push	H	; switch is still depressed
	ei
	reti
..1:	pop	H	; HL = address of interrupt
	rst	6
;
; If a HALT intruction is executed, print an error
; message and resume at the next instruction
HALTmsg:.asciz	[bell][cr][lf]'*** HALT inst. at '
HALTerr:
	lxi	H,HALTmsg
	call	PRTMSG	; print 'HALT inst ' message
	pop	H	; get HALT ret address
	push	H	; save ret adr
	dcx	H	; compute address of HLT instr
	mov	A,H
	push	H
	call	PRTBYT	; print high byte
	pop	H
	mov	A,L
	call	PRTBYT	; print low byte
	lxi	H,waituser
	push	H	; insure that if oper. warm
	ei		; boots that RETI has been
	reti		; exec'd (for peripherals)
	]
	.page
	.sbttl	'PRTMSG print a message'
;----------
; Print a variable length message
;  Regs in:   HL = address of message (ended by null)
PRTMSG:
	mov	A,M	; get a byte
	ora	A	; if null, then return
	rz
	mov	C,A	; put it where CONOUT wants it
	call	FORCEout; output the byte
	inx	H	; point to next byte
	jmpr	PRTMSG
;----------
; Print a fixed length message
;  Regs in:  HL = address of message
; 	     B  = length of message
PRTSTR:
	mov	C,M	; get a byte
	call	FORCEout; print it
	inx	H	; point to next byte
	djnz	PRTSTR	; loop until all bytes printed
	ret
;----------
; Print a byte in hex format
;  Regs in:  A = byte to be printed
PRTBYT:
	push	PSW
	rrc
	rrc
	rrc
	rrc
	call	..nib	; print upper nibble
	pop	PSW	; print lower nibble
..nib:	ani	0Fh
	adi	'0'	; convert 0-9 to hex
	cpi	'9'+1
	jrc	..out
	adi	'A'-('9'+1); convert 10-15 to hex
..out:	mov	C,A
	jmp	FORCEout
	.page
	.sbttl	'lock the DMA chip'
;----------
; Lock the DMA chip (prevent anyone else from using
;		     it until current user is finished)
readDMA	==	1	; read using DMA
writeDMA==	5	; write using DMA
lockbyte:.byte	0	; initially unlocked
DIerr:	.byte	0	; # of occurrences of early INTS
lockDMA:
	ei
	nop
	di		; Allow an int to happen
	lda	lockbyte
	ora	A
	jrnz	lockDMA	; Loop if DMA in use
	cma
	sta	lockbyte; Lock the DMA for calling rtne.

; .ifn	MASTopt,[ ei ]	; Enable on station only

	ret

	.page
	.sbttl	'handle an i/o error'
;----------
; Handle an I/O error
;
msgSTAR:	.asciz	[bell][cr][lf]'*** '
msgERR:		.asciz	' error'
msgHDC:		.ascii	[cr][lf]'HDC buf: '
		.ascii	'Cmd Sec Track   Na  Na  Cnt '
		.asciz	'Na  Status'
msgFDC:		.ascii	[cr][lf]'FDC buf: '
		.ascii	'Cmd Dsk Trk Hd  Sec Den Max '
		.asciz	'Gap Len Status'
msgRTRY:	.ascii	[cr][lf]'key <ctl-c> to abort '
		.asciz	'or <cr> to retry:'
msgCONT:	.ascii  [cr][lf]'cold boot or '
		.asciz	'key <cr> to continue:'
blanks:		.asciz	[cr][lf]'       '

; Print a four-letter error code, and then wait
; for the user to type <return> or <control-C>.
IOERR:
	pop	D	; get return address
	push	D	; save return adr
	push	B	; save pointer to THS
	dcx	D	; compute adr of caller
	dcx	D
	dcx	D
;
; Search the error table for the address of the caller
	lxi	H,errtab
	mvi	B,numerr
findadr:
	mov	A,M	; get lower byte of address
	cmp	E
	inx	H
	mov	A,M	; get upper byte of address
	inx	H	; point to ASCII string
	jrnz	..1	; jump if no match
;
	cmp	D
	jrz	foundadr; jump if match

..1:	inx	H	; pointer to next address
	inx	H
	inx	H
	inx	H
	djnz	findadr	; check next address, if any
;
; If the retry count in low core equals zero,
; then the error code number will be returned in RA.
; FDTEST sets the retry count to 0, so that errors
; can be automatically intercepted and diagnosed.
foundadr:
	.ife	FLOPboot&MINIboot,[
	lda	Mode
	bit	ModeTRY,A
	jrnz	prterr  ; if not zero, ask the user
;
	pop	B	; throw away THS address
	lxi	D,errtab-4
	dsbc	D	; compute offset from "errtab"
	mov	A,L
	rrc		; divide by 2
	ret		; return 3, 6, 9, ...
	]
;
; Print an error message
prterr:
	push	H
	lxi	H,msgSTAR; print "*** " header mss
	call	PRTMSG
	pop	H
	mvi	B,4
	call	PRTSTR	; print a four-letter code
	lxi	H,msgERR
	call	PRTMSG	; print " error "

; Check if floppy or HD error
  .ife	FLOPopt&MINIopt,[
	pop	H
	push	h
	lxi	d,FLOPstat+3
	ora	a
	dsbc	d
	pop	h
	jrz	..fd
;
    .ifn	HARDopt,[
	jmpr	waituser
	]
;
    .ife	HARDopt,[
	lxi	D,HARDstat+1
	ora	A	; reset carry
	dsbc	D
	jrnz	waituser

..hd:
	; display cmd buffer and user
  .ife	NETopt,	[call	errPRINT]

	; Print hard disk status buffer
	lxi	H,msgHDC	; print "HDC buf: "
	call	prtmsg		; and error desc
	lxi	h,blanks
	call	prtMSG		; line up buffer
	lxi	H,HARDcom
	mvi	B,16
	call	PRBUFF	; display HARDcom buffer
..HDuser:
	lda	MODE
	bit	modeCONT,A
	rz
;
	lxi	H,msgCONT
	call	PRTMSG	; print "cold boot, depress <cr>
			; to continue" etc
	call	CONIN
	sui	cr	; wait for <cr>
	jrnz	..HDuser
	ret
	]		; end ' HARDopt '
;
	.ife	FLOPopt&MINIopt,[
..fd:
	lxi	H,msgFDC; print 'FDC buf: '
	call	prtMSG	; and error desc
	lxi	h,blanks
	call	prtMSG	; line up buffer
;
; Print floppy status buffer
	lxi	H,FLOPcom
	mvi	B,16
	call	prBUFF	; print FLOPcom buffer
	lxi	H,RTRYflop
	mvi	M,retry+1 ; re-init RTRYflop
	jmpr	waituser
	]
prBUFF:
	push	B
	push	H
	mvi	C,' '
	call	FORCEout
	mvi	C,' '
	call	FORCEout
	pop	H
	pop	B
	mov	A,M
	call	PRTBYT
	inx	H
	djnz	prBUFF
	ret
;
; Wait for the user to hit <return> or <control-C>
waituser:
	lxi	h,msgRTRY
	call	PRTMSG	; print "key <ctl-c> etc."
	call	CONIN
	cpi	cntlC
	jz	0
	sui	cr
	rz
	jmpr	waituser
;
; Error code table
errtab:
	.ife	FLOPopt&MINIopt,[
	.word	NRDYerr	; drive not ready
	.ascii	'NRDY'
	.word	DATAerr	; DATA CRC error
	.ascii	'DATA'
	.word	TRACerr	; head positioned on wrong trck
	.ascii	'TRAC'
	.word	ENDTerr	; access beyond end-of-track
	.ascii	'ENDT'
	.word	IDerr	; ID CRC error
	.ascii	' ID '
	.word	ORUNerr	; FDC not serviced in time
	.ascii	'ORUN'
	.word	SECTerr	; sector cannot be found
	.ascii	'SECT'
	.word	PROTerr	; disk write-protected
	.ascii	'PROT'
	.word	DENSerr	; missing ID address mark
	.ascii	'DENS'
	.word	MADRerr ; missing DATA address mark
	.ascii	'MADR'
	]
	.ife	HARDopt,[
	.word	HDSKerr ; hard disk ctrlr. error
	.ascii	'HDSK'
	.word	HSELerr	; hard disk select error
	.ascii	'HSEL'
	]
numerr	==	(.-errtab)/6
	.ascii	'I/O '	; default error code
;----------
; Handle an unexpected interrupt
saveHL.int:	.word	0
INTmsg:
	.asciz	[bell][cr][lf]'*** INT error at '

INTerr:
	shld	saveHL.int
	pop	h	; get return adr
;
	push	D	; save all regs
	push	B
	push	PSW
	push	h	; save ret adr
;
	lxi	H,INTmsg
	call	PRTMSG	; print '*** INT error at '
	pop	h	; get return adr
	push	h	; save real return adr
	inx	h	; prtCALLadr prints the
	inx	h	; caller, we want the return
	inx	h	; so inx by 3
	call	prtCALLadr; print int ret adr
	pop	h	; get the real return adr
;
	pop	PSW
	pop	B
	pop	D

	push	H	; restore ret adr
	lhld	saveHL.int
	ei
	reti
;----------
; Handle an invalid BIOS call
CALLmsg:.asciz	[bell][cr][lf]'*** CALL error at '
CALLerr:
	lxi	H,CALLmsg
	call	PRTMSG	; print '*** CALL error at '
	pop	h	; get return adr
	call	prtCALLadr; print caller's adr
	push	h	; restore ret adr
	jmp	waituser
;----------
; Handle a spooling error
  .ife	SPOOLopt,[
SPOLmsg:.asciz	[bell][cr][lf]'*** SPOOL error'
SPOLerr:
	lxi	H,SPOLmsg
	call	PRTMSG
	jmp	waituser
	]
;
; hl=caller's return adr; computes caller's adr,
; prints adr and returns adr unchanged in hl
prtCALLadr:
	push	h	; save orig. call adr
	dcx	h
	dcx	h
	dcx	h	; compute calling adr
	mov	a,h
	push	h	; save for low byte
	call	prtbyt	; print high byte
	pop	h
	mov	a,l
	call	prtbyt
	pop	h	; hl = ret adr
	ret		;
;
.page
	.sbttl	'CPMMAP get current disk map'
	.prntx	'made it to cpmmap'
;----------
; Get current disk map
; cpmMAP returns in HL the addr of the disk drive #
; or the partition unit #. This addr is also one
; less than the addr of the DPB for this drive or
; partition, if SELDSK has not been called with a
; drive # of 0FFh. 0FFh returns in HL a pointer to
; the warm boot device drive/partition #.
;
;  Regs in:   none
;  Regs out:  HL = pointer to unit # (DPBaddr-1)
;	      DE = pointer to DPH
;	      A  = unit number
;
cpmMAP:
	lda	cpmDSK	; get current disk number
	jmpr	map1
iobMAP:
	lda	iobDSK	; get current flop disk #
map1:	cpi	0FFh	; check for boot disk
	jrnz	map2
	lxi	H,DSKBOOT+2; return boot unit addr
	mov	A,M	; return unit # in A
	ret
map2:
	.ife	CPMver-1,[
	mov	D,A
	rlc
	rlc
	rlc
	add	D	; A = disk number * 9
	mvi	H,0
	mov	L,A
	lxi	D,DSKMAP
	dad	D	; point to map of current disk
	mov	A,M	; get first map entry
	ret
	]
	.ife	CPMver-2,[
	rlc
	rlc
	rlc
	rlc		; A = disk number * 16
	mvi	H,0
	mov	L,A	; HL <- disk # * 16
	lxi	D,DSKMAP; Disk param header array
	dad	D	; HL = addr of DPH
	push	H	; save addr of DPH
	lxi	D,10
	dad	D	; point to DPB addr
	mov	E,M
	inx	H
	mov	D,M
	dcx	D	; DE <- DPB addr - 1
	ldax	D	; get map byte
	pop	H	; restore DPH addr
	xchg
	ret
	]
	.page
	.sbttl	'default logical to physical disk maps 1.4'
	.ife	CPMver-1,[
;----------
; Default logical to physical disk maps
;
;  (1) physical device and unit number
;  (2) sectors per track
;  (3) maximum directory number
;  (4) logarithm of sectors per block (3 means 2**3)
;  (5) sectors per block - 1
;  (6) number of blocks - 1
;  (7) bits indicate blocks for directory
;  (8) number of operating system tracks
;  (9) 4Eh for CP/M sector mapping, 0C0h otherwise
;
;----------
; Warm boot disk
DSKBOOT:
	.ife	FLOPboot, [
	.byte	DD	; media type
	.byte	0	; unit #
	]
	.ife	HARDboot, [
	.byte	HARD
	.byte	0
	]
	.ife	HARDshar, [
	.byte	NET
	.byte	0
	]
	.ife	FLOPshar, [
	.byte	0FFh	; not used
	.byte	0
	]
;----------
; Drives A to D
DSKMAP:
	.ifn	FLOPshar,[
; (floppy system)  (1),(2),(3),(4),(5),(6),(7),(8),(9)
DSK0:	.byte	DD  +0, 52,127,  4, 15,242,0C0h, 2, 0Ch
DSK1:	.byte	DD  +1, 52,127,  4, 15,242,0C0h, 2, 0Ch
DSK2:	.byte	SD  +1, 26, 63,  3,  7,242,0C0h, 2, 4Eh
DSK3:	.byte	DD  +1, 52,127,  4, 15,242,0C0h, 2, 0Ch
;
DSKnam:	.blkb	32	; disk names
	]
	.ife	FLOPshar,[
; (floppy network) (1),(2),(3),(4),(5),(6),(7),(8),(9)
DSK0:	.byte	NET +0, 52,127,  4, 15,242,0C0h, 2, 0Ch
DSK1:	.byte	NET +1, 52,127,  4, 15,242,0C0h, 2, 0Ch
DSK2:	.byte	NET +4, 52,127,  4, 15,242,0C0h, 2, 0Ch
DSK3:	.byte	NET +5, 52,127,  4, 15,242,0C0h, 2, 0Ch
	]
	]
	.page
	.sbttl	'default logical to physical disk maps 2.2'
	.ife	CPMver-2,[
;----------
; Default logical to physical disk maps
;
;----------
; Warm boot disk
; In the def below, 0<8 is the unit #,
; and the byte whose symbolic name appears
; is the disk media type.
;
DSKBOOT:
	.ife	FLOPboot, [
	.byte	0	; HD drive (volume)
	.byte	DD	; media type
	.byte	0	; unit #
	]
	.ife	HARDboot, [
	.byte	0
	.byte	HARD
	.byte	0
	]
	.ife	HARDshar, [
	.byte	0
	.byte	NET
	.byte	0
	]
	.ife	FLOPshar, [
	.byte	0
	.byte	0FFh	; not used
	.byte	0
	]
	.ife	MINIboot, [
	.byte	0
	.byte	MINI2
	.byte	0
	]
;----------
; Drives A to D
DSKMAP:
DSK0:
	.word	sectab	; sector translate table
	.byte	0,0,0,0,0,0 ; scratch area
	.word	dirbuf	; directory buffer
	.word	DSKpb0	; disk parameter block
	.word	check0	; check vector
	.word	alloc0	; allocation vector
DSK1:
	.word	sectab	; sector translate table
	.byte	0,0,0,0,0,0 ; scratch area
	.word	dirbuf	; directory buffer
	.word	DSKpb1	; disk parameter block
	.word	check1	; check vector
	.word	alloc1	; allocation vector
DSK2:
	.word	sectab	; sector translate table
	.byte	0,0,0,0,0,0 ; scratch area
	.word	dirbuf	; directory buffer
	.word	DSKpb2	; disk parameter block
	.word	check2	; check vector
	.word	alloc2	; allocation vector
DSK3:
	.word	sectab	; sector translate table
	.byte	0,0,0,0,0,0 ; scratch area
	.word	dirbuf	; directory buffer
	.word	DSKpb3	; disk parameter block
	.word	check3	; check vector
	.word	alloc3	; allocation vector
	.page
	.sbttl	'default floppy disk parameter blocks - 8 inch'
;----------
; Default floppy disk parameter blocks - 8 inch
;----------
	.ife	FLOPopt,[
	.word	lencv0	; max check vector
	.word	lenav0	; max alloc vector
	.blkb	8	; disk name
	.byte	0	; HD drive number
	.byte	DD	; Media type
	.byte	0	; Unit or drive number
DSKpb0:	.word	52	; sectors per track
	.byte	4,15,0	; blk shift, blk and ext mask
	.word	242	; number of blocks - 1
	.word	127	; maximum directory entry
	.byte	0C0h,0	; bits indicate directory blks
	.word	32	; check vector size
	.word	2	; number of op sys tracks
;----------
	.word	lencv1	; max check vector
	.word	lenav1	; max alloc vector
	.blkb	8	; disk name
	.byte	0	; HD drive number
	.byte	DD	; Media type
	.byte	1	; Unit or drive number
DSKpb1:	.word	52	; sectors per track
	.byte	4,15,0	; blk shift, blk and ext mask
	.word	242	; number of blocks - 1
	.word	127	; maximum directory entry
	.byte	0C0h,0	; bits indicate directory blks
	.word	32	; check vector size
	.word	2	; number of op sys tracks
;----------
	.word	lencv2	; max check vector
	.word	lenav2	; max alloc vector
	.blkb	8	; disk name
	.byte	0	; HD drive number
	.byte	SD	; Media type
	.byte	1	; Unit or drive number
DSKpb2:	.word	26	; sectors per track
	.byte	3,7,0	; blk shift, blk and ext mask
	.word	242	; number of blocks - 1
	.word	63	; maximum directory entry
	.byte	0C0h,0	; bits indicate directory blks
	.word	16	; check vector size
	.word	2	; number of op sys tracks
;----------
	.word	lencv3	; max check vector
	.word	lenav3	; max alloc vector
	.blkb	8	; disk name
	.byte	0	; HD drive number
	.byte	DD	; Media type
	.byte	1	; Unit or drive number
DSKpb3:	.word	52	; sectors per track
	.byte	4,15,0	; blk shift, blk and ext mask
	.word	242	; number of blocks - 1
	.word	127	; maximum directory entry
	.byte	0C0h,0	; bits indicate directory blks
	.word	32	; check vector size
	.word	2	; number of op sys tracks
	]
	.page
	.sbttl	'default floppy disk parameter blocks - 5 inch'
;----------
; Default floppy disk parameter blocks - 5 inch
;----------
	.ife	(1-FLOPopt)!MINIopt,[
	.word	lencv0	; max check vector
	.word	lenav0	; max alloc vector
	.blkb	8	; disk name
	.byte	0	; HD drive number
	.byte	MINI2	; Media type
	.byte	0	; Unit or drive number
DSKpb0:	.word	32	; sectors per track
	.byte	5,31,0	; blk shift, blk and ext mask
	.word	156	; number of blocks - 1
	.word	127	; maximum directory entry
	.byte	080h,0	; bits indicate directory blks
	.word	32	; check vector size
	.word	3	; number of op sys tracks
;----------
	.word	lencv1	; max check vector
	.word	lenav1	; max alloc vector
	.blkb	8	; disk name
	.byte	0	; HD drive number
	.byte	MINI2	; Media type
	.byte	1	; Unit or drive number
DSKpb1:	.word	32	; sectors per track
	.byte	5,31,0	; blk shift, blk and ext mask
	.word	156	; number of blocks - 1
	.word	127	; maximum directory entry
	.byte	080h,0	; bits indicate directory blks
	.word	32	; check vector size
	.word	3	; number of op sys tracks
;----------
	.word	lencv2	; max check vector
	.word	lenav2	; max alloc vector
	.blkb	8	; disk name
	.byte	0	; HD drive number
	.byte	MINI2	; Media type
	.byte	0	; Unit or drive number
DSKpb2:	.word	32	; sectors per track
	.byte	5,31,0	; blk shift, blk and ext mask
	.word	156	; number of blocks - 1
	.word	127	; maximum directory entry
	.byte	080h,0	; bits indicate directory blks
	.word	32	; check vector size
	.word	3	; number of op sys tracks
;----------
	.word	lencv3	; max check vector
	.word	lenav3	; max alloc vector
	.blkb	8	; disk name
	.byte	0	; HD drive number
	.byte	MINI2	; Media type
	.byte	1	; Unit or drive number
DSKpb3:	.word	32	; sectors per track
	.byte	5,31,0	; blk shift, blk and ext mask
	.word	156	; number of blocks - 1
	.word	127	; maximum directory entry
	.byte	080h,0	; bits indicate directory blks
	.word	32	; check vector size
	.word	3	; number of op sys tracks
	]
;----------
	.page
	.sbttl	'sector translation, check and allocation vectors'
;----------
; Sector translation table for single density floppy
sectab:	.byte	1,7,13,19,25,5,11,17,23,3,9,15,21
	.byte	2,8,14,20,26,6,12,18,24,4,10,16,22
;----------
; Size of check and allocation vectors
	.ife	FLOPboot&MINIboot,[
lencv0	==	32	; max 128 directory entries
lenav0	==	32	; max 256 blocks
lencv1	==	32	; max 128 directory entries
lenav1	==	32	; max 256 blocks
lencv2	==	32	; max 128 directory entries
lenav2	==	32	; max 256 blocks
lencv3	==	256	; max 1024 directory entries
lenav3	==	256	; max 2048 blocks
	]
	.ife	HARDboot&NETboot,[
lencv0	==	256	; max 1024 directory entries
lenav0	==	256	; max 2048 blocks
lencv1	==	256	; max 1024 directory entries
lenav1	==	256	; max 2048 blocks
lencv2	==	256	; max 1024 directory entries
lenav2	==	256	; max 2048 blocks
lencv3	==	256	; max 1024 directory entries
lenav3	==	256	; max 2048 blocks
	]
;
; Storage for check and alloc vectors
check0: .blkb	lencv0
alloc0: .blkb	lenav0
check1: .blkb	lencv1
alloc1: .blkb	lenav1
check2: .blkb	lencv2
alloc2: .blkb	lenav2
check3: .blkb	lencv3
alloc3: .blkb	lenav3
;
; Storage for directory
dirbuf:	.blkb	128	; directory buffer
	]
	.page
	.sbttl	'default custom printer driver'
;----------
; Default custom printer driver
;
; Diablo printer driver (compatible with any printer
;			 which uses XON/XOFF protocol)
PORTUout:
	.ifn	SELECT-1, [
	lxi	H,..flag
	in	SIO2AC	; see if printer trying to
	ani	1<RxRDY	;  tell us something
	jrz	..chkstat
	in	SIO2AD	; should be cntlS or cntlQ
	ani	7Fh
	cpi	cntlQ
	jrnz	..chkcntl
	mvi	M,0FFh	; its OK to send
..chkcntl:
	cpi	cntlS
	jrnz	..chkstat
	mvi	M,0	; its not OK to send
..chkstat:
	in	SIO2AC
	ani	1<TxRDY	; see if transmitter ready
	ana	M	;  and also cntlQ active
	jrz	PORTUout; retry if not
	mov	A,C
	out	SIO2AD	; print char
	]		; SELECT-1
	ret
;
	.ifn	SELECT-1, [
..flag:	.byte	0FFh	; initially OK to send
	]		; SELECT-1
;
; Set the address of the poll-prime data structure
; Return the last address set in HL.
	.ifn	MASTopt,[
	.ife	NETopt, [
SETppa:
	lhld	PPAadr
	sbcd	PPAadr
	ret
;
; Poll-prime related data areas and equates
PPmlen	==	129	; poll-prime msg. length
			; 1st byte is the srce user number
PPAadr:	.word	PPAdefault
PPAdefault:
	.byte	0	; Default is to ignore
			; poll-prime commands.
	]		; NETopt
	]		; MASTopt

;
  .ife	MASTopt,[
	.byte	76h,76h,76h,76h,76h,76h,76h,76h
	.byte	76h,76h,76h,76h,76h,76h,76h,76h
	.byte	76h,76h,76h,76h,76h,76h,76h,76h
	.byte	76h,76h,76h,76h,76h,76h,76h,76h
	]	; masters' stack

; ensure that the master stack has at least 32 bytes
; so MASTstac-LASTbyt > 0 says stack is ok


LASTbyt	==	. - 1	; Last memory location used

	.ife	MASTopt!HARDshare,[
		.ifg	MASTstac-LASTbyt,[
		.prntx "code length is ok for hard master"
		] [
		.prntx "code is TOO LONG for hard master"
		]
	]
	.ife	FLOPop!MINIop,[
		.ifg	netBUFF-LASTbyt,[
		.prntx "code length is ok for station"
		] [
		.prntx "code is TOO LONG for station"
		]
	]
	.ife	(SELECT-1)!MINIopt,[
		.ifg	rdBUFF-LASTbyt,[
		.prntx "code length is ok for FOX stand alone boot"
		][
		.prntx "code is TOO LONG for FOX stand alone boot"
		]
	]
	.ife	(SELECT-1)!FLOPopt,[
		.ifg	rdBUFF-LASTbyt,[
		.prntx "code length is ok for 8 inch stand alone boot"
		][
		.prntx "code is TOO LONG for 8 inch stand alone boot"
		]
	]
	.ife	MASTopt,[
	  .ifg	len1strap-(TIME.SP-Net1strap),[
		.prntx	'boot phase 1 length is ok'
		][
		.prntx	'boot phase 1 length is TOO LONG'
		]
	]
.end
