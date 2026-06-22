/*
 * TPZASM: TDL ZASM / PSA PASM compatible assembler - insn.c
 * Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
 * SPDX-License-Identifier: MIT-0
 * scspell-id: 40d3e73c-6335-11f1-9c34-246e96298730
 */

/******************************************************************************/

/*
 * 8080/Z80 instruction table (TDL/Intel mnemonics).
 */

/******************************************************************************/

#include <string.h>

/******************************************************************************/

#include "asm.h"

/******************************************************************************/

static const insn TAB[] = {
  /* no operand */
  { "NOP",  0x00, FMT_NONE },
  { "RLC",  0x07, FMT_NONE },
  { "RRC",  0x0F, FMT_NONE },
  { "RAL",  0x17, FMT_NONE },
  { "RAR",  0x1F, FMT_NONE },
  { "DAA",  0x27, FMT_NONE },
  { "CMA",  0x2F, FMT_NONE },
  { "STC",  0x37, FMT_NONE },
  { "CMC",  0x3F, FMT_NONE },
  { "HLT",  0x76, FMT_NONE },
  { "RET",  0xC9, FMT_NONE },
  { "XCHG", 0xEB, FMT_NONE },
  { "XTHL", 0xE3, FMT_NONE },
  { "SPHL", 0xF9, FMT_NONE },
  { "PCHL", 0xE9, FMT_NONE },
  { "DI",   0xF3, FMT_NONE },
  { "EI",   0xFB, FMT_NONE },
  { "RNZ",  0xC0, FMT_NONE },
  { "RZ",   0xC8, FMT_NONE },
  { "RNC",  0xD0, FMT_NONE },
  { "RC",   0xD8, FMT_NONE },
  { "RPO",  0xE0, FMT_NONE },
  { "RPE",  0xE8, FMT_NONE },
  { "RP",   0xF0, FMT_NONE },
  { "RM",   0xF8, FMT_NONE },

  /* parity flag read as overflow: RNO/RO alias RPO/RPE (same P/V flag) */
  { "RNO",  0xE0, FMT_NONE },
  { "RO",   0xE8, FMT_NONE },

  /* register moves / single register */
  { "MOV", 0x40, FMT_MOV },
  { "INR", 0x04, FMT_DST },
  { "DCR", 0x05, FMT_DST },
  { "MVI", 0x06, FMT_MVI },
  { "ADD", 0x80, FMT_SRC },
  { "ADC", 0x88, FMT_SRC },
  { "SUB", 0x90, FMT_SRC },
  { "SBB", 0x98, FMT_SRC },
  { "ANA", 0xA0, FMT_SRC },
  { "XRA", 0xA8, FMT_SRC },
  { "ORA", 0xB0, FMT_SRC },
  { "CMP", 0xB8, FMT_SRC },

  /* register pair */
  { "LXI",  0x01, FMT_LXI     },
  { "INX",  0x03, FMT_RP      },
  { "DCX",  0x0B, FMT_RP      },
  { "DAD",  0x09, FMT_RP      },
  { "PUSH", 0xC5, FMT_PUSHPOP },
  { "POP",  0xC1, FMT_PUSHPOP },
  { "LDAX", 0x0A, FMT_RP2     },
  { "STAX", 0x02, FMT_RP2     },

  /* immediate 8 */
  { "ADI", 0xC6, FMT_IMM8 },
  { "ACI", 0xCE, FMT_IMM8 },
  { "SUI", 0xD6, FMT_IMM8 },
  { "SBI", 0xDE, FMT_IMM8 },
  { "ANI", 0xE6, FMT_IMM8 },
  { "XRI", 0xEE, FMT_IMM8 },
  { "ORI", 0xF6, FMT_IMM8 },
  { "CPI", 0xFE, FMT_IMM8 },
  { "IN",  0xDB, FMT_IMM8 },
  { "OUT", 0xD3, FMT_IMM8 },

  /* address 16 */
  { "LDA",  0x3A, FMT_ADDR },
  { "STA",  0x32, FMT_ADDR },
  { "LHLD", 0x2A, FMT_ADDR },
  { "SHLD", 0x22, FMT_ADDR },
  { "JMP",  0xC3, FMT_ADDR },
  { "JNZ",  0xC2, FMT_ADDR },
  { "JZ",   0xCA, FMT_ADDR },
  { "JNC",  0xD2, FMT_ADDR },
  { "JC",   0xDA, FMT_ADDR },
  { "JPO",  0xE2, FMT_ADDR },
  { "JPE",  0xEA, FMT_ADDR },
  { "JP",   0xF2, FMT_ADDR },
  { "JM",   0xFA, FMT_ADDR },
  { "JNO",  0xE2, FMT_ADDR }, /* overflow alias of JPO (P/V flag) */
  { "JO",   0xEA, FMT_ADDR }, /* overflow alias of JPE (P/V flag) */
  { "CALL", 0xCD, FMT_ADDR },
  { "CNZ",  0xC4, FMT_ADDR },
  { "CZ",   0xCC, FMT_ADDR },
  { "CNC",  0xD4, FMT_ADDR },
  { "CC",   0xDC, FMT_ADDR },
  { "CPO",  0xE4, FMT_ADDR },
  { "CPE",  0xEC, FMT_ADDR },
  { "CP",   0xF4, FMT_ADDR },
  { "CM",   0xFC, FMT_ADDR },
  { "CNO",  0xE4, FMT_ADDR }, /* overflow alias of CPO (P/V flag) */
  { "CO",   0xEC, FMT_ADDR }, /* overflow alias of CPE (P/V flag) */

  /* restart */
  { "RST", 0xC7, FMT_RST },

  /* ---- Z80 extensions (TDL mnemonics, verified) ---- */
  { "EXX", 0xD9, FMT_NONE },

  /* relative jumps: opcode + signed displacement */
  { "JMPR", 0x18, FMT_REL },
  { "JRZ",  0x28, FMT_REL },
  { "JRNZ", 0x20, FMT_REL },
  { "JRC",  0x38, FMT_REL },
  { "JRNC", 0x30, FMT_REL },
  { "DJNZ", 0x10, FMT_REL },

  /* 16-bit load/store : ED + opcode + addr16 */
  { "LBCD", 0x4B, FMT_ED16 },
  { "LDED", 0x5B, FMT_ED16 },
  { "LSPD", 0x7B, FMT_ED16 },
  { "SBCD", 0x43, FMT_ED16 },
  { "SDED", 0x53, FMT_ED16 },
  { "SSPD", 0x73, FMT_ED16 },

  /* ADC/SBC HL,rr : ED + (opcode | rp<<4) */
  { "DADC", 0x4A, FMT_EDHL },
  { "DSBC", 0x42, FMT_EDHL },

  /* ED no-operand */
  { "NEG",  0x44, FMT_ED0 },
  { "LDIR", 0xB0, FMT_ED0 },
  { "LDDR", 0xB8, FMT_ED0 },
  { "RETI", 0x4D, FMT_ED0 },
  { "RETN", 0x45, FMT_ED0 },

  /* block move/compare/io, interrupt mode, I/R loads, decimal rotates */
  { "LDI",   0xA0, FMT_ED0  },
  { "LDD",   0xA8, FMT_ED0  },
  { "CCI",   0xA1, FMT_ED0  },
  { "CCD",   0xA9, FMT_ED0  },
  { "CCIR",  0xB1, FMT_ED0  },
  { "CCDR",  0xB9, FMT_ED0  },
  { "INI",   0xA2, FMT_ED0  },
  { "INIR",  0xB2, FMT_ED0  },
  { "IND",   0xAA, FMT_ED0  },
  { "INDR",  0xBA, FMT_ED0  },
  { "OUTI",  0xA3, FMT_ED0  },
  { "OUTIR", 0xB3, FMT_ED0  },
  { "OUTD",  0xAB, FMT_ED0  },
  { "OUTDR", 0xBB, FMT_ED0  },
  { "IM0",   0x46, FMT_ED0  },
  { "IM1",   0x56, FMT_ED0  },
  { "IM2",   0x5E, FMT_ED0  },
  { "LDAI",  0x57, FMT_ED0  },
  { "STAI",  0x47, FMT_ED0  },
  { "LDAR",  0x5F, FMT_ED0  },
  { "STAR",  0x4F, FMT_ED0  },
  { "RLD",   0x6F, FMT_ED0  },
  { "RRD",   0x67, FMT_ED0  },
  { "EXAF",  0x08, FMT_NONE },

  /* Z80 register I/O via (C): ED + (base | reg<<3) */
  { "INP",  0x40, FMT_EDDST }, /* IN  r,(C) */
  { "OUTP", 0x41, FMT_EDDST }, /* OUT (C),r */

  /* CB rotates/shifts (register/M form): CB + (base | reg) */
  { "RLCR", 0x00, FMT_CBR },
  { "RRCR", 0x08, FMT_CBR },
  { "RALR", 0x10, FMT_CBR },
  { "RARR", 0x18, FMT_CBR },
  { "SLAR", 0x20, FMT_CBR },
  { "SRAR", 0x28, FMT_CBR },
  { "SRLR", 0x38, FMT_CBR },

  /* CB bit ops: CB + (base | bit<<3 | reg) */
  { "BIT", 0x40, FMT_CBB },
  { "RES", 0x80, FMT_CBB },
  { "SET", 0xC0, FMT_CBB },

  /* index register ops (DD/FD prefix from the X/Y suffix) */
  { "PCIX", 0xE9, FMT_IXP   },
  { "PCIY", 0xE9, FMT_IXP   },
  { "SPIX", 0xF9, FMT_IXP   },
  { "SPIY", 0xF9, FMT_IXP   },
  { "XTIX", 0xE3, FMT_IXP   },
  { "XTIY", 0xE3, FMT_IXP   },
  { "DADX", 0x09, FMT_IXADD },
  { "DADY", 0x09, FMT_IXADD },

  /* LIXD/LIYD: LD IX/IY,(addr); SIXD/SIYD: LD (addr),IX/IY */
  { "LIXD", 0x2A, FMT_IXADDR },
  { "LIYD", 0x2A, FMT_IXADDR },
  { "SIXD", 0x22, FMT_IXADDR },
  { "SIYD", 0x22, FMT_IXADDR },

  { NULL, 0, FMT_NONE }
};

/******************************************************************************/

const insn *
insn_find (const char *upname)
{
  const insn *p;

  for (p = TAB; NULL != p->name; p++)
    if (0 == strcmp (p->name, upname))
      return p;

  return NULL;
}

/******************************************************************************/

/*
 * Whether a mnemonic is a Z80 extension (not part of the 8080 set), so the
 * assembler can flag the `Z' warning when it is used under .I8080.  Every Z80
 * opcode here uses one of the Z80-only encoding formats, except EXX and EXAF
 * which share the 8080's no-operand form but are Z80 instructions.  (Index-
 * register OPERANDS on an otherwise-8080 mnemonic -- e.g. PUSH X -- are Z80
 * too, but that is detected from the operand, in encode_insn, not here.)
 */

int
insn_is_z80 (const insn *in)
{
  if (NULL == in)
    return 0;

  switch ((int)in->fmt) /* (int) cast: switch on the value, not the enum type */
    {
    case FMT_REL:
    case FMT_ED16:
    case FMT_EDHL:
    case FMT_ED0:
    case FMT_EDDST:
    case FMT_CBR:
    case FMT_CBB:
    case FMT_IXP:
    case FMT_IXADD:
    case FMT_IXADDR:
      return 1;

    case FMT_NONE:
      return (0xD9 == in->opcode || 0x08 == in->opcode); /* EXX, EXAF */

    default:
      return 0;
    }
}

/******************************************************************************/

/*
 * The numeric value of a mnemonic used as an expression operand: the TDL/PSA
 * assemblers let an instruction name stand for its opcode template bytes (all
 * operand fields zero), read as a little-endian integer.  So `MVI A,JMP' is
 * `MVI A,0C3H', `.WORD LDIR' is 0B0EDH (ED B0 in memory order), `.WORD BIT' is
 * 040CBH (CB 40), and `.WORD PCIX' is 0E9DDH (DD E9).  A defined symbol of the
 * same name takes precedence; this is only consulted when the name is not a
 * symbol (see ev_primary in expr.c).
 */

u16
insn_value (const insn *in)
{
  unsigned int pfx = 0;

  if (NULL == in)
    return 0;

  switch ((int)in->fmt) /* (int) cast: switch on the value, not the enum type */
    {
    case FMT_ED16:
    case FMT_EDHL:
    case FMT_ED0:
    case FMT_EDDST:
      pfx = 0xED;

      break;

    case FMT_CBR:
    case FMT_CBB:
      pfx = 0xCB;

      break;

    case FMT_IXP:
    case FMT_IXADD:
    case FMT_IXADDR:
      /* index prefix from the mnemonic's register letter: X -> DD, Y -> FD */
      pfx = (NULL != strchr (in->name, 'Y') ? 0xFD : 0xDD);

      break;

    default:
      break;
    }

  if (0 != pfx)
    return (u16)(pfx | ((unsigned int)in->opcode << 8));

  return (u16)in->opcode;
}

/******************************************************************************/

/*
 * Local Variables:
 * mode: c
 * indent-tabs-mode: nil
 * tab-width: 2
 * c-basic-offset: 2
 * fill-column: 80
 * eval: (setq-local display-fill-column-indicator-column 80)
 * eval: (display-fill-column-indicator-mode 1)
 * End:
 */

/******************************************************************************/
/* vim: set ft=c ts=2 sw=2 tw=0 ai expandtab cc=80 : */
/******************************************************************************/
