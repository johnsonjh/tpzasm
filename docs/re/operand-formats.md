# TDL / PSA operand-format classes (TYPE / IDX / ATTR)

Companion to `keyword-tables.md`. Decoded 2026-06-16 from `orig/*.com`.
Each keyword record is `<NAME:4> 00 00 <TYPE> <IDX> <ATTR:2>`.

* **TYPE** = keyword *category* (which dispatch/mnemonic-set).
* **IDX**  = *operand-format class* within the category (or directive handler id).
* **ATTR** = base opcode/prefix byte(s), combined with operand bits per the format.

## TYPE category map

| TYPE | zasm 2.21 | pasm 1.02 | pasm2 2.00G | meaning |
|------|-----------|-----------|-------------|---------|
| `04` | 8080 ops **+ directives** | 8080 ops **+ directives** | 8080 ops only | Intel/8080 base mnemonics; in 1.02/2.21 directives also live here (IDX≥0x14) |
| `11` | registers | registers | registers | operand keywords A/B/C/D/E/H/L/M=code 7/0/1/2/3/4/5/6, +PSW/SP/X/Y/`$`/`.` |
| `14` | TDL Z80 ext | TDL Z80 ext | TDL Z80 ext | TDL Z80 extension mnemonics (ED/CB/DD/FD) |
| `24` | — | — | **directives** | pasm2 moved directives out of `04` into their own category (same IDX/ATTR) |
| `31` | segments | segments | segments | `.PROG.`/`.DATA.`/`.BLNK.` segment symbols |
| `44` | — | — | **Zilog** | standard Zilog mnemonics (`.ZOP`): LD/EX/ADD/ADC/SBC/INC/DEC/JP/CALL/RET/RST/IN/OUT/PUSH/POP + no-op set |
| `54` | — | — | **Zilog ext** | Zilog block/shift/bit/special: EXX/LDI../RLC../BIT/SET/RES/JR/DJNZ/IM |
| `a4` | — | — | **Intel pseudo** | `.EPOP` M80 forms: END/DB/DW/DS/DC/ORG/PAGE/ASEG/CSEG/DSEG/IF/ELSE/ENDIF/COMMON/PUBLIC/ENTRY/EXT/EXTRN/TITLE/SUBTTL |
| `e4` | — | — | **Intel pseudo 2** | DEFB/DEFW/DEFS/DEFM/EXTERN/GLOBAL/COND/ENDC |

> **Cross-version:** the 8080 (`04`) and TDL-ext (`14`) opcode encodings — IDX *and* ATTR — are **byte-identical across all three assemblers**. Only the directive *category tag* differs (`04` in 1.02/2.21 vs `24` in 2.00G); their IDX/ATTR are unchanged.

## 8080 base mnemonics  (TYPE `04`)

| IDX | format | mnemonics |
|-----|--------|-----------|
| `01` | MOV r,r'      op = base \| dst<<3 \| src | MOV |
| `02` | MVI r,db      op = base \| r<<3 ; +imm8 | MVI |
| `03` | INR/DCR r     op = base \| r<<3 | INR,DCR |
| `04` | ALU r         op = base \| r          (ADD..CMP) | ADD,ADC,SUB,SBB,ANA,ORA,XRA,CMP |
| `05` | implied       op = base              (no operand) | SPHL,XCHG,XTHL,DAA,CMA,CMC,STC,NOP,HLT,DI,EI,RLC,RAL,RRC,RAR |
| `07` | immediate     op = base ; +imm8      (ADI..CPI, IN/OUT port) | ADI,ACI,SUI,SBI,ANI,ORI,XRI,CPI,IN,OUT |
| `09` | direct addr   op = base ; +addr16    (LDA/STA/JMP/Jcc/CALL/Ccc) | LDA,STA,LHLD,SHLD,JMP,JNZ,JZ,JNC,JC,JPO,JPE,JP,JM,CALL,CNZ,C |
| `0a` | LXI rp,d16    op = base \| rp<<4 ; +addr16 | LXI |
| `0c` | rp            op = base \| rp<<4      (PUSH/POP/INX/DCX) | PUSH,POP,INX,DCX |
| `11` | RST n         op = base \| n<<3 | RST |
| `13` | rp(B/D/HL)    op = base \| rp<<4      (LDAX/STAX/DAD) | LDAX,STAX,DAD |

## TDL Z80 extension mnemonics  (TYPE `14`)

| IDX | format | mnemonics |
|-----|--------|-----------|
| `05` | implied 1-byte    emit ATTR[0]            (EXAF/EXX/RNO/RO) | EXAF,EXX,RNO,RO |
| `06` | implied 2-byte    emit ATTR (pfx+op)      (LDAI/SPIX/LDI/NEG/IMx/RETI...) | LDAI,LDAR,STAI,STAR,SPIX,SPIY,XTIX,XTIY,LDI,LDIR,LDD,LDDR,CC |
| `09` | direct addr       emit ATTR ; +addr16     (TDL JO/JNO/CO/CNO overflow) | JNO,JO,CNO,CO |
| `0b` | 16-bit load-dir   emit ATTR(pfx+op) ; +addr16 (LBCD/LIXD/SBCD/SIXD...) | LBCD,LDED,LSPD,SBCD,SDED,SSPD,LIXD,LIYD,SIXD,SIYD |
| `0d` | 16-bit reg-add    ATTR \| rp<<4           (DADC/DSBC/DADX/DADY) | DADC,DSBC,DADX,DADY |
| `0e` | CB rot reg        emit CB, base\|r         (RLCR/RALR/SLAR/SRLR...) | RLCR,RALR,RRCR,RARR,SLAR,SRAR,SRLR |
| `0f` | CB bit,r          emit CB, base\|bit<<3\|r  (BIT/SET/RES) | BIT,SET,RES |
| `10` | rel jump          emit base ; +rel8       (JMPR/JRx/DJNZ) | JMPR,JRC,JRNC,JRZ,JRNZ,DJNZ |
| `12` | IN/OUT (C)        emit ED, base\|r<<3      (INP/OUTP) | INP,OUTP |

## pasm2 Zilog mnemonics (TYPE `44`/`54`, `.ZOP` mode)

Higher-level handlers (operand grammar richer than 8080). ATTR may pack two
base opcodes, e.g. `JP`=`c2c3` (`c2`=`JP cc,nn`, `c3`=`JP nn`), `CALL`=`c4cd`,
`INC`=`0403` (`04`=`INC r`, `03`=`INC rp`).

| TYPE/IDX | mnemonics | note |
|----------|-----------|------|
| `44`/`00` | LD | LD (full Z80 LD matrix) |
| `44`/`01` | DAA,CPL,CCF,SCF,NOP,HALT,DI,EI,RLCA,RLA,RRCA,R | no-operand (DAA/CPL/CCF/SCF/NOP/HALT/DI/EI/RLCA/RRCA/RLA/RRA) |
| `44`/`03` | PUSH,POP | PUSH/POP rr |
| `44`/`04` | EX | EX |
| `44`/`05` | ADD | ADD A,r / ADD HL|IX|IY,rr |
| `44`/`06` | ADC,SBC | ADC/SBC A,r / HL,rr |
| `44`/`07` | SUB,AND,OR,XOR,CP | ALU r/n (SUB/AND/OR/XOR/CP) |
| `44`/`08` | INC,DEC | INC/DEC r|rr |
| `44`/`0b` | JP,CALL | JP/CALL [cc,]nn |
| `44`/`0e` | RET | RET [cc] |
| `44`/`0f` | RST | RST n |
| `44`/`11` | IN | IN |
| `44`/`12` | OUT | OUT |
| `54`/`01` | EXX | EXX |
| `54`/`02` | LDI,LDIR,LDD,LDDR,CPI,CPIR,CPD,CPDR,NEG,RLD,RR | block ops LDI/CPI/INI/... (ED) |
| `54`/`09` | RLC,RL,RRC,RR,SLA,SRA,SRL | CB rot r/(HL) |
| `54`/`0a` | BIT,SET,RES | BIT/SET/RES |
| `54`/`0c` | JR | JR [cc,]e |
| `54`/`0d` | DJNZ | DJNZ e |
| `54`/`10` | IM | IM n |

## Directive handlers (TYPE `24` in 2.00G / `04` IDX≥0x14 in 1.02/2.21)

IDX = directive handler; ATTR = a sub-selector flag, e.g. the `.IFE`-family
(IDX `24`) uses ATTR `00..05` to pick the comparison (`.IFE/.IFG/.IFGE/.IFL/
.IFLE/.IFN`); `.IF1`/`.IF2` use ATTR `0000`/`8000`; the listing-control family
(IDX `1d`: `.LALL/.LIST/.XALL/.XLIST/.SALL/.XSYM/.LSYM/...`) uses ATTR as a
bitmask. Full per-directive IDX/ATTR is in `pasm2-records.txt`.

