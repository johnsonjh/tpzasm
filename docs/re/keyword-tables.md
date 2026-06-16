# TDL / PSA assembler keyword tables

* `zasm.com` (TDL ZASM `2.21`),
* `pasm.com` (PSA PASM `1.02`),
* `pasm2.com` (PSA PASM `2.00G`).

All three share one keyword-table format.

## Table format

Each keyword is a **10-byte record**:

```
<NAME:4> <00 00> <TYPE:1> <IDX:1> <ATTR:2>
```
* **NAME** = the keyword's first 6 characters packed as two big-endian
  RAD40 words (bytes `[0:2]` and `[2:4]`), 3 chars each.
  * Each word == `c0*1600 + c1*40 + c2`.
  * Alphabet: `0`=pad, `1..10`=`'0'..'9'`, `11..36`=`'A'..'Z'`, `37`=`$`, `39`=`.`
    (letter code = ASCII−'A'+11).
  * Confirmed by Mark Ogden's disassembly and email to me about how TDL stores
    the first 6 chars; round-trip verified; every stored key re-encodes exactly.
* **TYPE/IDX** = the operand-format / encoding class.
* **ATTR** = the opcode / prefix bytes, e.g. `ed57`=`LD A,I`, `cb40`=`BIT 0,B`,
  `ed4a`=`ADC HL,BC`, `dd09`=`ADD IX,BC`, `eda0`/`edb0`=`LDI`/`LDIR`.

Table locations:

* `zasm.com` @ `0x2a02` (239 recs),
* `pasm.com` @ `0x2fba` (242 recs),
* `pasm2.com` @ `0x40c1` (350 recs).

Keyword counts:

* **`zasm.com` `2.21` = 239**,
* **`pasm.com` `1.02` = 242**,
* **`pasm2.com` `2.00G` = 311** (= 242 + 69 `pasm2`-only):
  * The unified `pasm2` table holds the 8080 set, the TDL Z80 extensions,
    the standard Zilog set (pasm2), all directives, the Intel/M80 pseudo-ops
    (`pasm2` `.EPOP`), and operand keywords (`A`..`L`,`M`,`PSW`,`SP`,`X`,`Y`,`$`,`.`).

## `zasm.com` (TDL `2.21`) - 239 keywords

```
  .        .ASCII   .ASCIS   .ASCIZ   .BLKB    .BLKW
  .BLNK.   .BYTE    .DATA.   .DATE    .DEFIN   .END
  .ENTRY   .ERROR   .EXIT    .EXTER   .I8080   .IDENT
  .IF1     .IF2     .IFB     .IFDEF   .IFDIF   .IFE
  .IFG     .IFGE    .IFIDN   .IFL     .IFLE    .IFN
  .IFNB    .IFNDE   .INSER   .INTER   .LADDR   .LALL
  .LCTL    .LIMAG   .LINK    .LIST    .LOC     .LSYM
  .MASYN   .OPSYN   .PABS    .PAGE    .PBIN    .PHEX
  .PREL    .PRGEN   .PRNTX   .PROG.   .PSYM    .RAD40
  .RADIX   .RELOC   .REMAR   .RLIST   .SALL    .SBTTL
  .SLIST   .SYN     .SYSYN   .TIME    .TITLE   .WORD
  .XADDR   .XALL    .XCTL    .XIMAG   .XLINK   .XLIST
  .XPSYM   .XSYM    .Z80     A        ACI      ADC
  ADD      ADI      ANA      ANI      B        BIT
  C        CALL     CC       CCD      CCDR     CCI
  CCIR     CM       CMA      CMC      CMP      CNC
  CNO      CNZ      CO       CP       CPE      CPI
  CPO      CZ       D        DAA      DAD      DADC
  DADX     DADY     DCR      DCX      DI       DJNZ
  DSBC     E        EI       EXAF     EXX      H
  HLT      IM0      IM1      IM2      IN       IND
  INDR     INI      INIR     INP      INR      INX
  JC       JM       JMP      JMPR     JNC      JNO
  JNZ      JO       JP       JPE      JPO      JRC
  JRNC     JRNZ     JRZ      JZ       L        LBCD
  LDA      LDAI     LDAR     LDAX     LDD      LDDR
  LDED     LDI      LDIR     LHLD     LIXD     LIYD
  LSPD     LXI      M        MOV      MVI      NEG
  NOP      ORA      ORI      OUT      OUTD     OUTDR
  OUTI     OUTIR    OUTP     PCHL     PCIX     PCIY
  POP      PSW      PUSH     RAL      RALR     RAR
  RARR     RC       RES      RET      RETI     RETN
  RLC      RLCR     RLD      RM       RNC      RNO
  RNZ      RO       RP       RPE      RPO      RRC
  RRCR     RRD      RST      RZ       SBB      SBCD
  SBI      SDED     SET      SHLD     SIXD     SIYD
  SLAR     SP       SPHL     SPIX     SPIY     SRAR
  SRLR     SSPD     STA      STAI     STAR     STAX
  STC      SUB      SUI      X        XCHG     XRA
  XRI      XTHL     XTIX     XTIY     Y
```

## `pasm.com` (PSA PASM `1.02`) - 242 keywords

```
  .        .ASCII   .ASCIS   .ASCIZ   .BLKB    .BLKW
  .BLNK.   .BYTE    .DATA.   .DATE    .DEFIN   .END
  .ENTRY   .ERROR   .EXIT    .EXTER   .GOTO    .I8080
  .IDENT   .IF1     .IF2     .IFB     .IFDEF   .IFDIF
  .IFE     .IFG     .IFGE    .IFIDN   .IFL     .IFLE
  .IFN     .IFNB    .IFNDE   .INSER   .INTER   .LADDR
  .LALL    .LCTL    .LIMAG   .LINK    .LIST    .LOC
  .LSYM    .MASYN   .OPSYN   .PABS    .PAGE    .PBIN
  .PHEX    .PREL    .PRGEN   .PRNTX   .PROG.   .PROGI
  .PSYM    .RAD40   .RADIX   .RELOC   .REMAR   .RLIST
  .SALL    .SBTTL   .SLIST   .SYN     .SYSYN   .TEMPS
  .TIME    .TITLE   .WORD    .XADDR   .XALL    .XCTL
  .XIMAG   .XLINK   .XLIST   .XPSYM   .XSYM    .Z80
  A        ACI      ADC      ADD      ADI      ANA
  ANI      B        BIT      C        CALL     CC
  CCD      CCDR     CCI      CCIR     CM       CMA
  CMC      CMP      CNC      CNO      CNZ      CO
  CP       CPE      CPI      CPO      CZ       D
  DAA      DAD      DADC     DADX     DADY     DCR
  DCX      DI       DJNZ     DSBC     E        EI
  EXAF     EXX      H        HLT      IM0      IM1
  IM2      IN       IND      INDR     INI      INIR
  INP      INR      INX      JC       JM       JMP
  JMPR     JNC      JNO      JNZ      JO       JP
  JPE      JPO      JRC      JRNC     JRNZ     JRZ
  JZ       L        LBCD     LDA      LDAI     LDAR
  LDAX     LDD      LDDR     LDED     LDI      LDIR
  LHLD     LIXD     LIYD     LSPD     LXI      M
  MOV      MVI      NEG      NOP      ORA      ORI
  OUT      OUTD     OUTDR    OUTI     OUTIR    OUTP
  PCHL     PCIX     PCIY     POP      PSW      PUSH
  RAL      RALR     RAR      RARR     RC       RES
  RET      RETI     RETN     RLC      RLCR     RLD
  RM       RNC      RNO      RNZ      RO       RP
  RPE      RPO      RRC      RRCR     RRD      RST
  RZ       SBB      SBCD     SBI      SDED     SET
  SHLD     SIXD     SIYD     SLAR     SP       SPHL
  SPIX     SPIY     SRAR     SRLR     SSPD     STA
  STAI     STAR     STAX     STC      SUB      SUI
  X        XCHG     XRA      XRI      XTHL     XTIX
  XTIY     Y
```

## `pasm2.com` (PSA PASM `2.00G`) - 311 keywords

```
  $        .        .ASCII   .ASCIS   .ASCIZ   .BLKB
  .BLKW    .BLNK.   .BYTE    .COMME   .CREF    .DATA.
  .DATE    .DEFIN   .END     .ENTRY   .EPOP    .ERROR
  .EXIT    .EXTER   .GOTO    .I8080   .IDENT   .IF1
  .IF2     .IFB     .IFDEF   .IFDIF   .IFE     .IFG
  .IFGE    .IFIDN   .IFL     .IFLE    .IFN     .IFNB
  .IFNDE   .INSER   .INTER   .IOP     .LADDR   .LALL
  .LCTL    .LIBRE   .LIF     .LIMAG   .LINK    .LIST
  .LOC     .LSYM    .MASYN   .OPSYN   .PABS    .PAGE
  .PBIN    .PHEX    .PREL    .PRGEN   .PRNTX   .PROG.
  .PROGI   .PSYM    .RAD40   .RADIX   .RELOC   .REMAR
  .RLIST   .SALL    .SBTTL   .SLIST   .SYN     .SYSYN
  .TEMPS   .TIME    .TITLE   .WORD    .XADDR   .XALL
  .XCTL    .XEPOP   .XIF     .XIMAG   .XLINK   .XLIST
  .XPSYM   .XSYM    .Z80     .ZOP     A        ACI
  ADC      ADD      ADI      ANA      AND      ANI
  ASEG     B        BIT      C        CALL     CC
  CCD      CCDR     CCF      CCI      CCIR     CM
  CMA      CMC      CMP      CNC      CNO      CNZ
  CO       COMMON   COND     CP       CPD      CPDR
  CPE      CPI      CPIR     CPL      CPO      CSEG
  CZ       D        DAA      DAD      DADC     DADX
  DADY     DB       DC       DCR      DCX      DEC
  DEFB     DEFM     DEFS     DEFW     DI       DJNZ
  DS       DSBC     DSEG     DW       E        EI
  ELSE     END      ENDC     ENDIF    ENTRY    EX
  EXAF     EXT      EXTERN   EXTRN    EXX      GLOBAL
  H        HALT     HLT      IF       IFE      IFF
  IFT      IM       IM0      IM1      IM2      IN
  INC      IND      INDR     INI      INIR     INP
  INR      INX      JC       JM       JMP      JMPR
  JNC      JNO      JNZ      JO       JP       JPE
  JPO      JR       JRC      JRNC     JRNZ     JRZ
  JZ       L        LBCD     LD       LDA      LDAI
  LDAR     LDAX     LDD      LDDR     LDED     LDI
  LDIR     LHLD     LIXD     LIYD     LSPD     LXI
  M        MOV      MVI      NEG      NOP      OR
  ORA      ORG      ORI      OTDR     OTIR     OUT
  OUTD     OUTDR    OUTI     OUTIR    OUTP     PAGE
  PCHL     PCIX     PCIY     POP      PSW      PUBLIC
  PUSH     RAL      RALR     RAR      RARR     RC
  RES      RET      RETI     RETN     RL       RLA
  RLC      RLCA     RLCR     RLD      RM       RNC
  RNO      RNZ      RO       RP       RPE      RPO
  RR       RRA      RRC      RRCA     RRCR     RRD
  RST      RZ       SBB      SBC      SBCD     SBI
  SCF      SDED     SET      SHLD     SIXD     SIYD
  SLA      SLAR     SP       SPHL     SPIX     SPIY
  SRA      SRAR     SRL      SRLR     SSPD     STA
  STAI     STAR     STAX     STC      SUB      SUBTTL
  SUI      TITLE    X        XCHG     XOR      XRA
  XRI      XTHL     XTIX     XTIY     Y
```

## Cross-version differences

* **`pasm2`-only (vs `1.02`/`2.21`), 69** = the `2.00G` `.ZOP`/`.EPOP` scope:

  ```
    $        .COMME   .CREF    .EPOP    .IOP     .LIBRE
    .LIF     .XEPOP   .XIF     .ZOP     AND      ASEG
    CCF      COMMON   COND     CPD      CPDR     CPIR
    CPL      CSEG     DB       DC       DEC      DEFB
    DEFM     DEFS     DEFW     DS       DSEG     DW
    ELSE     END      ENDC     ENDIF    ENTRY    EX
    EXT      EXTERN   EXTRN    GLOBAL   HALT     IF
    IFE      IFF      IFT      IM       INC      JR
    LD       OR       ORG      OTDR     OTIR     PAGE
    PUBLIC   RL       RLA      RLCA     RR       RRA
    RRCA     SBC      SCF      SLA      SRA      SRL
    SUBTTL   TITLE    XOR
  ```

* **In `pasm.com` 1.02 but NOT in `zasm.com` 2.21:** [ `.GOTO`, `.PROGI`, `.TEMPS` ]
* **In `zasm.com` 2.21 but NOT in `pasm.com` 1.02:** *None*!

## Coverage

* TPZASM fully covers ZASM 2.21 (`-z`) and PASM 1.02 (`-p`).
* TPZASM accepts these, but neither zasm.com 2.21 nor pasm.com 1.02 has them:
  `.COMMO, .DB, .DC, .DS, .DW, .EXTRN, .NAME, .ORG, .PRINT, .PUBLI, .REQUE, .SUBTT, COMMON, DB, DC, DCS, DEFB, DEFW, DS, DSW, DW, END, EXTRN, ORG, PUBLIC`

> **NOTE:** `DB DW DS DEFB DEFW DS ORG END EXTRN` (and the `.DB/.DW/
> .DS/.ORG` synonyms) are **`pasm2` `.EPOP` / Intel-M80 form**.  They are NOT in
> the real `zasm.com` 2.21 / `pasm.com` 1.02 tables, which only know the dotted
> forms (`.BYTE/.WORD/.BLKB/.LOC/.END`). `zasm.com` flags `ORG` as an `O`
> (unknown-opcode) error; bare `END` triggers `UNEXPECTED END OF INPUT FILE`.
> `TPZASM` currently accepts, so on a source using Intel style the we diverge
> from the originals (it assembles; they error).  Correct fix is to gate these
> synonyms behind the future `pasm2`/`.EPOP` mode. No tests exercise this (yet!)
