/*
 * TPZASM: TDL ZASM / PSA PASM compatible assembler - assemble.c
 * Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
 * SPDX-License-Identifier: MIT-0
 * scspell-id: 11597abc-6335-11f1-abca-246e96298730
 */

/******************************************************************************/

/*
 * Pass 1 defines labels/assignments and advances the location counter.
 * Pass 2 evaluates operands and emits bytes, printing a listing.
 *
 * Handles labels, '=' / EQU / SET, the data/control pseudo-ops, and
 * 8080+Z80 machine instructions including index addressing d(X)/d(Y).
 */

/******************************************************************************/

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/******************************************************************************/

#include "asm.h"

/******************************************************************************/

#define MAXCOND 64
#define MAXALIAS 128

/* listing-control flag bits (a->lst_ctl); LSTC_DEFAULT reproduces the standard
 * listing exactly, so a source that uses none of these directives is unchanged.
 */
#define LSTC_LIST   0x01u /* body listing on        (.LIST / .XLIST)        */
#define LSTC_CTL    0x02u /* list control stmts     (.LCTL / .XCTL)         */
#define LSTC_SYM    0x04u /* symbol table at .END   (.LSYM / .XSYM)         */
#define LSTC_LADDR  0x08u /* 16-bit values swapped  (.LADDR / .XADDR)       */
#define LSTC_LIMAGE 0x10u /* list every data byte   (.LIMAGE / .XIMAGE)     */
#define LSTC_LALL   0x20u /* list all macro text    (.LALL)                 */
#define LSTC_SALL   0x40u /* suppress macro text    (.SALL)                 */
#define LSTC_DEFAULT (LSTC_LIST | LSTC_SYM)
#define LSTC_SAVES 4 /* depth of the .SLIST/.RLIST push-down stack */

/******************************************************************************/

typedef struct
{
  int assemble;
  int if_true;
} cframe;

/******************************************************************************/

typedef struct macrodef
{
  char name[NAMEBUF];
  char params[8][NAMEBUF];
  int nparams;
  char *body[64];
  int nbody;
  struct macrodef *next;
} macrodef;

/******************************************************************************/

typedef struct
{
  symtab *syms;
  int pass;
  int radix;
  u16 lc;
  int lc_reloc;
  u16 prog_max; /* high-water LC: the .PROG. segment size */
  int errors;
  int ended;
  u8 bytes[64];
  int nbytes;
  int long_symbols;

  /* .OPSYN aliases: alias_from[i] is a synonym for alias_to[i] */
  char alias_from[MAXALIAS][NAMEBUF];
  char alias_to[MAXALIAS][NAMEBUF];
  int nalias;

  /* conditional ([...]) stack */
  cframe cstack[MAXCOND];
  int cdepth;

  /* macros */
  macrodef *macros;
  macrodef *defining;
  int def_started;
  int def_depth;

  /* directory of the top-level source, for resolving .INSERT */
  char basedir[512];

  /* assembly-time console input (the '\' operator) */
  int in_prompt;

  /* label awaiting a multi-line '\' prompt value */
  symbol *pend_console;

  /* flat output image (NULL unless an image/object output is requested) */
  u8 *image;
  u16 img_min, img_max;
  int img_any;

  int obj_abs;       /* module output mode: 1 = .PABS, 0 = .PREL (default) */
  int obj_org_used;  /* an explicit .LOC/ORG pins the code (.PROG. size 0)  */
  int obj_xlink;     /* .XLINK: suppress the !/\\ link records (`;' only)   */
  u16 obj_start;     /* start address from `.END expr' (0 if none)         */
  int obj_start_rel; /* relocation base of the start address               */

  /* object output records the emitted byte stream in EMISSION order (not
   * ascending address order): the originals write a record at each .LOC/ORG
   * address discontinuity, so a program that revisits an earlier region (e.g.
   * SARGON) interleaves records AND preserves each byte's emission-time value
   * even when a later store overwrites that address.  em_byte[k]/em_rel[k] are
   * the k-th emitted byte and its REL_* class; spans group consecutive emitted
   * bytes into contiguous-address runs. */
  u8 *em_byte;     /* emitted byte values, emission order (NULL = no record) */
  u8 *em_rel;      /* REL_ABS/REL_LO/REL_HI per emitted byte                 */
  long em_n;       /* number of emitted bytes recorded                       */
  long em_cap;
  int em_pending;  /* emit_word: 2 -> next byte REL_LO, then 1 -> REL_HI     */
  u16 *span_a;     /* span start addresses */
  u16 *span_n;     /* span lengths         */
  int nspans;
  int span_cap;
  long emit_prev;  /* last address emitted this pass, or -1 */

  /* listing output stream (stderr, or the -l file) */
  FILE *lst;

  /* .TITLE text for the page subtitle (captured in pass 1) */
  char title[64];

  /* macro support */
  unsigned genctr; /* counter for %-generated local labels */
  int macro_depth; /* recursion guard                      */
  int macro_exit;  /* .EXIT: terminate the current expansion*/
  unsigned scope;  /* local-symbol scope ('..' labels)     */

  /* macro call whose parenthesized argument spans several lines */
  int pending;
  int pend_depth;
  int pend_len;
  char pend_op[NAMEBUF];
  char pend_args[1024];
  u16 lc_stmt; /* statement-start LC, for '.' in operands */

  /* listing format (TDL ZASM vs PSA PASM) */
  dialect_t dialect; /* selects the TDL vs PSA listing layout     */
  unsigned lst_ctl;  /* listing-control flags (LSTC_*)            */
  unsigned lst_save[LSTC_SAVES]; /* .SLIST push-down stack        */
  int lst_nsave;     /* number of saved entries on that stack     */
  int lst_ctlstmt;   /* this line is a listing-control statement  */
  int lst_kind;      /* this line: 0 insn, 1 data bytes, 2 words  */
  int lst_opw;       /* insn operand width (0/1/2) for value-form */
  long lst_loc;      /* LOC-column value: -1 blank, -2 use lc0    */
  long lst_line;     /* listing line counter, for pagination      */
  int lst_page;      /* current listing page number               */
  int lst_lreloc;    /* LC reloc: -1 use lc_reloc, else 0/1 flag  */
  int lst_oreloc;    /* 16-bit insn operand reloc flag (0/1)      */
  u8 wreloc[32];     /* per-.WORD-value reloc flag (' or space)   */

  /* macro-expansion listing: the originals fold the body into the call line
   * and flag continued statements with '+' */
  const char *mac_src; /* override source text for this listing line, or NULL */
  int mac_plus;        /* place the '+' macro-continuation marker            */
  int mac_active;      /* inside the outermost macro expansion's listing     */
  int lst_suppress;    /* assemble a line but emit no listing output         */
  int ins_depth;       /* .INSERT nesting: inserted lines carry the '@' mark */
} astate;

/******************************************************************************/

static const char *
skipws (const char *p)
{
  while (' ' == *p || '\t' == *p)
    p++;

  return p;
}

/******************************************************************************/

static int
idchar (int c)
{
  return isalnum (c) || '_' == c || '?' == c || '@' == c || '.' == c
         || '$' == c || '%' == c;
}

/******************************************************************************/

/*
 * Append one emitted byte (value v, at the current LC) to the object emission
 * log and its containing span.  The byte's REL_* class comes from the pending
 * reloc16 marker that emit_word sets.  Buffers grow on demand; an allocation
 * failure simply drops the record (object output then degrades, never crashes).
 */

static void
em_record (astate *a, u8 v)
{
  u8 cls = REL_ABS;

  if (2 == a->em_pending)
    {
      cls = REL_LO; /* low byte of a relocatable 16-bit value */
      a->em_pending = 1;
    }
  else if (1 == a->em_pending)
    {
      cls = REL_HI; /* high byte */
      a->em_pending = 0;
    }

  if (a->em_n >= a->em_cap) /* grow the emission buffers */
    {
      long nc = a->em_cap * 2;
      u8 *nb = (u8 *)realloc (a->em_byte, (size_t)nc);
      u8 *nr = (u8 *)realloc (a->em_rel, (size_t)nc);

      if (NULL != nb)
        a->em_byte = nb;

      if (NULL != nr)
        a->em_rel = nr;

      if (NULL != nb && NULL != nr)
        a->em_cap = nc;
    }

  if (a->em_n >= a->em_cap)
    return; /* out of memory */

  a->em_byte[a->em_n] = v;
  a->em_rel[a->em_n] = cls;
  a->em_n++;

  /* span: extend the current run, or open a new one at an address gap */
  if (a->nspans > 0 && a->emit_prev >= 0 && (long)a->lc == a->emit_prev + 1)
    a->span_n[(long)a->nspans - 1]++;
  else
    {
      if (a->nspans >= a->span_cap) /* grow the span arrays */
        {
          int sc = a->span_cap * 2;
          u16 *na = (u16 *)realloc (a->span_a, (size_t)sc * sizeof (u16));
          u16 *nn = (u16 *)realloc (a->span_n, (size_t)sc * sizeof (u16));

          if (NULL != na)
            a->span_a = na;

          if (NULL != nn)
            a->span_n = nn;

          if (NULL != na && NULL != nn)
            a->span_cap = sc;
        }

      if (a->nspans < a->span_cap)
        {
          a->span_a[a->nspans] = a->lc;
          a->span_n[a->nspans] = 1;
          a->nspans++;
        }
    }

  a->emit_prev = (long)a->lc;
}

/******************************************************************************/

static void
emit (astate *a, u16 v)
{
  if (2 == a->pass)
    {
      if (a->nbytes < (int)sizeof (a->bytes))
        a->bytes[a->nbytes++] = (u8)(v & 0xFFu);

      if (NULL != a->image)
        {
          a->image[a->lc] = (u8)(v & 0xFFu);

          if (!a->img_any || a->lc < a->img_min)
            a->img_min = a->lc;

          if (!a->img_any || a->lc > a->img_max)
            a->img_max = a->lc;

          a->img_any = 1;
        }

      if (NULL != a->em_byte) /* object output: record in emission order */
        em_record (a, (u8)(v & 0xFFu));
    }

  a->lc = (u16)(a->lc + 1);

  if (a->lc > a->prog_max)
    a->prog_max = a->lc;
}

/******************************************************************************/

/*
 * Emit a 16-bit value; when `reloc' is set, flag its two bytes in the emission
 * log so the object emitter encodes a .PROG.-relative 16-bit datum.  The bytes
 * are stored little-endian (Z80 order), as the listing already shows.
 */

static void
emit_word (astate *a, u16 v, int reloc)
{
  if (2 == a->pass && NULL != a->em_byte)
    a->em_pending = (reloc ? 2 : 0);

  emit (a, (u16)(v & 0xFFu));
  emit (a, (u16)(v >> 8));
}

/******************************************************************************/

static void
aerr (astate *a, const char *line, const char *msg)
{
  if (2 == a->pass)
    (void)fprintf (stderr, "  *** %s: %s\n", msg, line);

  a->errors++;
}

/******************************************************************************/

/* evaluate one expression at *pp, advancing it; pass 1 tolerates undefined */
static int
eval1 (astate *a, const char **pp, value_t *v)
{
  eval_env env;
  const char *endp, *err;
  int rc;

  env.radix = a->radix;
  env.syms = a->syms;
  env.lc = a->lc_stmt;
  env.lc_reloc = a->lc_reloc;
  env.undef0 = (1 == a->pass);
  env.scope = a->scope;
  rc = expr_eval2 (*pp, &env, v, &endp, &err);

  if (rc)
    {
      v->value = 0;
      v->reloc = 0;
      v->ext = NULL;
    }

  *pp = endp;

  return rc;
}

/******************************************************************************/

/* ---- operand helpers ----------------------------------------------- */

/* B C D E H L M A -> 0..7, else -1 */
static int
parse_reg8 (const char **pp)
{
  const char *p = skipws (*pp);
  int r;

  switch (toupper ((unsigned char)*p))
    {
    case 'B':
      r = 0;
      break;

    case 'C':
      r = 1;
      break;

    case 'D':
      r = 2;
      break;

    case 'E':
      r = 3;
      break;

    case 'H':
      r = 4;
      break;

    case 'L':
      r = 5;
      break;

    case 'M':
      r = 6;
      break;

    case 'A':
      r = 7;
      break;

    default:
      return -1;
    }

  if (idchar ((unsigned char)p[1]))
    return -1;

  *pp = p + 1;

  return r;
}

/******************************************************************************/

/* B D H SP/PSW->0..3; X/Y->IX/IY */
static int
parse_rp (const char **pp, int psw, int *pfx)
{
  const char *p = skipws (*pp);
  char t[8];
  int n = 0, code = -1;

  *pfx = 0;

  while (n < 7 && isalpha ((unsigned char)p[n]))
    {
      t[n] = (char)toupper ((unsigned char)p[n]);
      n++;
    }

  t[n] = '\0';

  if (idchar ((unsigned char)p[n]))
    return -1;

  if (0 == strcmp (t, "B"))
    code = 0;
  else if (0 == strcmp (t, "D"))
    code = 1;
  else if (0 == strcmp (t, "H"))
    code = 2;
  else if (!psw && 0 == strcmp (t, "SP"))
    code = 3;
  else if (psw && 0 == strcmp (t, "PSW"))
    code = 3;
  else if (0 == strcmp (t, "X"))
    {
      code = 2;
      *pfx = 0xDD;
    } /* IX */
  else if (0 == strcmp (t, "Y"))
    {
      code = 2;
      *pfx = 0xFD;
    } /* IY */

  if (code >= 0)
    *pp = p + n;

  return code;
}

/******************************************************************************/

static int
comma (const char **pp)
{
  const char *p = skipws (*pp);

  if (',' == *p)
    {
      *pp = p + 1;

      return 1;
    }

  return 0;
}

/******************************************************************************/

/*
 * register / memory / index operand:
 *   B C D E H L M A  -> reg 0..7, pfx 0
 *   d(X)             -> reg 6, pfx DD, disp d
 *   d(Y)             -> reg 6, pfx FD, disp d
 * returns 0 on success, -1 on error.
 */

static int
parse_regop (astate *a, const char **pp, int *reg, int *pfx, u16 *disp)
{
  const char *p = skipws (*pp);
  int c = toupper ((unsigned char)*p);

  *pfx = 0;
  *disp = 0;

  if (('B' == c || 'C' == c || 'D' == c || 'E' == c || 'H' == c || 'L' == c
       || 'M' == c || 'A' == c)
      && !idchar ((unsigned char)p[1]) && '(' != p[1])
    {
      switch (c)
        {
        case 'B':
          *reg = 0;
          break;

        case 'C':
          *reg = 1;
          break;

        case 'D':
          *reg = 2;
          break;

        case 'E':
          *reg = 3;
          break;

        case 'H':
          *reg = 4;
          break;

        case 'L':
          *reg = 5;
          break;

        case 'M':
          *reg = 6;
          break;

        default:
          *reg = 7;
          break;
        }
      *pp = p + 1;
      return 0;
    }

  if ('(' != *p)
    {
      value_t v;

      if (eval1 (a, &p, &v))
        return -1;

      *disp = v.value;
    }

  p = skipws (p);

  if ('(' != *p)
    return -1;

  p = skipws (p + 1);
  c = toupper ((unsigned char)*p);

  if ('X' == c)
    *pfx = 0xDD;
  else if ('Y' == c)
    *pfx = 0xFD;
  else
    return -1;

  p = skipws (p + 1);

  if (')' != *p)
    return -1;

  *pp = p + 1;
  *reg = 6;

  return 0;
}

/******************************************************************************/

/*
 * Encode one machine instruction.  Returns 1 if `mnem` (uppercase) is an
 * instruction, 0 otherwise.  Always emits the instruction's full size so the
 * location counter stays consistent across passes even on operand errors.
 */

static int
fmt_opw (insn_fmt_t fmt)
{
  int f = (int)fmt;

  switch (f)
    {
    case FMT_MVI:
    case FMT_IMM8:
    case FMT_REL:
      return 1;

    case FMT_LXI:
    case FMT_ADDR:
    case FMT_ED16:
    case FMT_IXADDR:
      return 2;

    default:
      return 0;
    }
}

/******************************************************************************/

static int
encode_insn (astate *a, const char *line, const char *mnem, const char *ops)
{
  const insn *in = insn_find (mnem);
  const char *p = ops;
  value_t v;
  int ifmt;

  if (NULL == in)
    return 0;

  a->lst_opw = fmt_opw (in->fmt); /* for the value-form listing byte column */
  v.reloc = 0; /* default if no 16-bit operand is evaluated */

  ifmt = (int)in->fmt;

  switch (ifmt)
    {
    case FMT_NONE:
      emit (a, in->opcode);
      break;

    case FMT_MOV:
      {
        int d, s, dp = 0, sp = 0;
        u16 dd = 0, sd = 0;
        if (parse_regop (a, &p, &d, &dp, &dd) || !comma (&p)
            || parse_regop (a, &p, &s, &sp, &sd))
          {
            aerr (a, line, "MOV r,r");
            emit (a, 0x40);
            break;
          }

        if (6 == d && 6 == s && !dp && !sp)
          aerr (a, line, "MOV M,M invalid");

        if (dp)
          emit (a, (u16)dp);
        else if (sp)
          emit (a, (u16)sp);

        emit (a, (u16)(0x40 | (d << 3) | s));

        if (dp)
          emit (a, dd);
        else if (sp)
          emit (a, sd);

        break;
      }

    case FMT_DST:
      {
        int r, pf = 0;
        u16 ds = 0;

        if (parse_regop (a, &p, &r, &pf, &ds))
          {
            aerr (a, line, "register expected");
            emit (a, in->opcode);
            break;
          }

        if (pf)
          emit (a, (u16)pf);

        emit (a, (u16)(in->opcode | (r << 3)));

        if (pf)
          emit (a, ds);

        break;
      }

    case FMT_MVI:
      {
        int r, pf = 0;
        u16 ds = 0;

        if (parse_regop (a, &p, &r, &pf, &ds) || !comma (&p))
          {
            aerr (a, line, "MVI r,data");
            emit (a, in->opcode);
            emit (a, 0);
            break;
          }

        if (pf)
          emit (a, (u16)pf);

        emit (a, (u16)(in->opcode | (r << 3)));

        if (pf)
          emit (a, ds);

        if (eval1 (a, &p, &v))
          aerr (a, line, "bad immediate");

        emit (a, v.value);
        break;
      }

    case FMT_SRC:
      {
        int r, pf = 0;
        u16 ds = 0;
        if (parse_regop (a, &p, &r, &pf, &ds))
          {
            aerr (a, line, "register expected");
            emit (a, in->opcode);
            break;
          }

        if (pf)
          emit (a, (u16)pf);

        emit (a, (u16)(in->opcode | r));

        if (pf)
          emit (a, ds);

        break;
      }

    case FMT_RP:
      {
        int pfx, rp = parse_rp (&p, 0, &pfx);

        if (rp < 0)
          {
            aerr (a, line, "register pair expected");
            emit (a, in->opcode);
            break;
          }

        if (pfx)
          emit (a, (u16)pfx); /* INX/DCX X/Y -> DD/FD prefix */

        emit (a, (u16)(in->opcode | (rp << 4)));
        break;
      }

    case FMT_PUSHPOP:
      {
        int pfx, rp = parse_rp (&p, 1, &pfx);
        if (rp < 0)
          {
            aerr (a, line, "B/D/H/PSW expected");
            emit (a, in->opcode);
            break;
          }

        if (pfx)
          emit (a, (u16)pfx); /* PUSH/POP X/Y -> DD/FD prefix */

        emit (a, (u16)(in->opcode | (rp << 4)));
        break;
      }

    case FMT_RP2:
      {
        int pfx, rp = parse_rp (&p, 0, &pfx);
        if (rp < 0 || rp > 1 || pfx)
          {
            aerr (a, line, "LDAX/STAX need B or D");

            emit (a, in->opcode);
            break;
          }

        emit (a, (u16)(in->opcode | (rp << 4)));
        break;
      }

    case FMT_LXI:
      {
        int pfx, rp = parse_rp (&p, 0, &pfx);
        if (rp < 0 || !comma (&p))
          {
            aerr (a, line, "LXI rp,data16");
            emit (a, in->opcode);
            emit (a, 0);
            emit (a, 0);
            break;
          }

        if (pfx)
          emit (a, (u16)pfx); /* LXI X/Y,nn -> DD/FD prefix */

        emit (a, (u16)(in->opcode | (rp << 4)));
        if (eval1 (a, &p, &v))
          aerr (a, line, "bad immediate");

        emit_word (a, v.value, 0 != v.reloc);
        break;
      }

    case FMT_IMM8:
      emit (a, in->opcode);

      if (eval1 (a, &p, &v))
        aerr (a, line, "bad immediate");

      emit (a, v.value);
      break;

    case FMT_ADDR:
      emit (a, in->opcode);

      if (eval1 (a, &p, &v))
        aerr (a, line, "bad address");

      emit_word (a, v.value, 0 != v.reloc);
      break;

    case FMT_RST:
      if (eval1 (a, &p, &v))
        aerr (a, line, "bad RST vector");

      if (v.value > 7)
        aerr (a, line, "RST 0-7");

      emit (a, (u16)(in->opcode | ((v.value & 7) << 3)));
      break;

    case FMT_REL:
      {
        u16 d16;
        int d;
        emit (a, in->opcode);

        if (eval1 (a, &p, &v))
          aerr (a, line, "bad jump target");

        d16 = (u16)(v.value - (u16)(a->lc_stmt + 2));
        d = ((d16 < 0x8000) ? (int)d16 : (int)d16 - 0x10000);

        if (2 == a->pass && (d < -128 || d > 127))
          aerr (a, line, "relative jump out of range");

        emit (a, (u16)(d16 & 0xFF));
        break;
      }

    case FMT_ED16:
      emit (a, 0xED);
      emit (a, in->opcode);

      if (eval1 (a, &p, &v))
        aerr (a, line, "bad address");

      emit_word (a, v.value, 0 != v.reloc);
      break;

    case FMT_EDHL:
      {
        int pfx, rp = parse_rp (&p, 0, &pfx);
        if (rp < 0 || pfx)
          {
            aerr (a, line, "register pair expected");
            emit (a, 0xED);
            emit (a, in->opcode);
            break;
          }

        emit (a, 0xED);
        emit (a, (u16)(in->opcode | (rp << 4)));
        break;
      }

    case FMT_ED0:
      emit (a, 0xED);
      emit (a, in->opcode);
      break;

    case FMT_EDDST: /* INP/OUTP r : ED + (opcode | reg<<3) */
      {
        int r = parse_reg8 (&p);
        if (r < 0)
          {
            aerr (a, line, "register expected");
            emit (a, 0xED);
            emit (a, in->opcode);
            break;
          }

        emit (a, 0xED);
        emit (a, (u16)(in->opcode | (r << 3)));
        break;
      }

    case FMT_CBR:
      {
        int r = parse_reg8 (&p);
        if (r < 0)
          {
            aerr (a, line, "register expected");
            emit (a, 0xCB);
            emit (a, in->opcode);
            break;
          }

        emit (a, 0xCB);
        emit (a, (u16)(in->opcode | r));
        break;
      }

    case FMT_CBB:
      {
        value_t b;
        int reg = -1, pf = 0;
        u16 ds = 0;

        if (eval1 (a, &p, &b) || !comma (&p)
            || parse_regop (a, &p, &reg, &pf, &ds))
          {
            aerr (a, line, "bit,reg expected");
            emit (a, 0xCB);
            emit (a, in->opcode);
            break;
          }

        if (pf)
          { /* BIT/SET/RES b,(IX/IY+d) -> pfx CB d op */
            emit (a, (u16)pf);
            emit (a, 0xCB);
            emit (a, ds);
            emit (a, (u16)(in->opcode | ((b.value & 7) << 3) | 6));
          }
        else
          {
            emit (a, 0xCB);
            emit (a, (u16)(in->opcode | ((b.value & 7) << 3) | reg));
          }

        break;
      }

    case FMT_IXP:
      {
        int pf = (('\0' != mnem[0] && 'Y' == mnem[strlen (mnem) - 1]) ? 0xFD
                                                                       : 0xDD);
        emit (a, (u16)pf);
        emit (a, in->opcode);
        break;
      }

    case FMT_IXADD:
      {
        int pf = (('\0' != mnem[0] && 'Y' == mnem[strlen (mnem) - 1]) ? 0xFD
                                                                       : 0xDD);
        const char *q = skipws (p);
        char t[4];
        int n = 0, rp = -1;

        while (n < 3 && isalpha ((unsigned char)q[n]))
          {
            t[n] = (char)toupper ((unsigned char)q[n]);
            n++;
          }

        t[n] = '\0';

        if (0 == strcmp (t, "B"))
          rp = 0;
        else if (0 == strcmp (t, "D"))
          rp = 1;
        else if (0 == strcmp (t, "SP"))
          rp = 3;
        else if ((0xDD == pf && 0 == strcmp (t, "X"))
                 || (0xFD == pf && 0 == strcmp (t, "Y")))
          rp = 2;

        if (rp < 0)
          {
            aerr (a, line, "bad register pair");
            emit (a, (u16)pf);
            emit (a, 0x09);
            break;
          }

        emit (a, (u16)pf);
        emit (a, (u16)(0x09 | (rp << 4)));
        break;
      }

    /* LIXD/LIYD = LD IX/IY,(addr); SIXD/SIYD = LD (addr),IX/IY */
    case FMT_IXADDR:
      {
        int pf = ((NULL != strchr (mnem, 'Y')) ? 0xFD : 0xDD);
        emit (a, (u16)pf);
        emit (a, in->opcode); /* 2A = load, 22 = store */

        if (eval1 (a, &p, &v))
          aerr (a, line, "bad address");

        emit_word (a, v.value, 0 != v.reloc);
        break;
      }

    default:
      return 0;
    }

  a->lst_oreloc = ((2 == a->lst_opw) ? (0 != v.reloc) : 0);

  return 1;
}

/******************************************************************************/

/* ---- pseudo-ops ---------------------------------------------------- */

static void
do_data (astate *a, const char *line, const char *p, int width)
{
  a->lst_kind = ((2 == width) ? 2 : 1); /* listing: words vs bytes */
  for (;;)
    { /* items are  {[r]}n , {[r]}n , ... */
      value_t v;
      long rep = 1, k;
      const char *start;
      p = skipws (p);

      if ('\0' == *p || ';' == *p)
        break;

      start = p;

      if ('[' == *p)
        { /* optional [r] repeat count */
          value_t rv;
          const char *q = p + 1;

          if (eval1 (a, &q, &rv))
            aerr (a, line, "bad repeat count");

          rep = (long)rv.value;
          q = skipws (q);

          if (']' == *q)
            q++;

          p = skipws (q);
        }

      /* emit 0, keep size */
      if (eval1 (a, &p, &v))
        aerr (a, line, "bad expression");

      for (k = 0; k < rep; k++)
        {
          if (2 == a->pass && 2 == width
              && a->nbytes / 2 < (int)sizeof (a->wreloc))
            a->wreloc[a->nbytes / 2] = (u8)(0 != v.reloc ? '\'' : ' ');

          if (2 == width)
            emit_word (a, v.value, 0 != v.reloc);
          else
            emit (a, v.value);
        }

      p = skipws (p);

      if (',' == *p)
        p++;

      if (p == start)
        break; /* safety: no progress */
    }
}

/******************************************************************************/

static void
do_blk (astate *a, const char *line, const char *p, int width)
{
  value_t v;
  long i, n;

  p = skipws (p);
  if (eval1 (a, &p, &v))
    {
      aerr (a, line, "bad reservation size");
      return;
    }

  if (v.reloc || v.ext)
    {
      aerr (a, line, "size must be absolute");
      return;
    }

  n = (long)v.value * width;

  for (i = 0; i < n; i++)
    a->lc = (u16)(a->lc + 1);

  if (a->lc > a->prog_max)
    a->prog_max = a->lc;
}

/******************************************************************************/

/*
 * .ASCII (mode 0) / .ASCIZ (1, trailing NUL) /
 * .ASCIS (2, high bit on last byte).
 * Items are delimited strings ('..' ".." /../), [expr] bytes, or bare byte
 * expressions, each optionally comma-separated (per the PSA manual).
 */

static void
do_ascii (astate *a, const char *line, const char *p, int mode)
{
  int started = 0;
  u16 last_lc = 0;

  a->lst_kind = 1; /* listing: byte stream */

  for (;;)
    {
      const char *start;
      p = skipws (p);

      if ('\0' == *p || ';' == *p)
        break;

      start = p;

      if ('\'' == *p || '"' == *p || '/' == *p)
        { /* delimited string */
          char d = *p;
          p++;

          while ('\0' != *p && *p != d)
            {
              last_lc = a->lc;
              emit (a, (u16)(unsigned char)*p);
              started = 1;
              p++;
            }

          if (*p == d)
            p++;
          else
            {
              aerr (a, line, "unterminated string");
              break;
            }
        }
      else if ('[' == *p)
        { /* [expr] : one byte */
          value_t v;
          const char *q = p + 1;

          if (eval1 (a, &q, &v))
            aerr (a, line, "bad expression");

          q = skipws (q);

          if (']' == *q)
            q++;

          last_lc = a->lc;
          emit (a, v.value);
          started = 1;
          p = q;
        }
      else
        { /* bare byte expression */
          value_t v;

          if (eval1 (a, &p, &v))
            aerr (a, line, "bad expression");

          last_lc = a->lc;
          emit (a, v.value);
          started = 1;
        }

      p = skipws (p);

      if (',' == *p)
        p++;

      if (p == start)
        break; /* safety: no progress */
    }

  if (1 == mode)
    emit (a, 0); /* .ASCIZ */
  else if (2 == mode && started && 2 == a->pass) /* .ASCIS: flag last byte */
    {
      if (NULL != a->image)
        a->image[last_lc] = (u8)(a->image[last_lc] | 0x80u);

      if (a->nbytes > 0)
        a->bytes[(long)a->nbytes - 1]
            = (u8)(a->bytes[(long)a->nbytes - 1] | 0x80u);
    }
}

/******************************************************************************/

/*
 * .DATE / .TIME : emit an 8-byte ASCII date ("MM/DD/YY") or time ("HH:MM:SS")
 * string at the current location.  The PSA original generates 8 spaces on a
 * host with no clock; we always have one, so we format the real date/time.
 * For reproducible builds and tests we honor SOURCE_DATE_EPOCH (a UTC Unix
 * timestamp) when it is set, otherwise the local clock.
 * (https://reproducible-builds.org/docs/source-date-epoch/)
 */

static void
do_datetime (astate *a, int want_time)
{
  char buf[16];
  /* Flawfinder: ignore */ /* False positive CWE-807/CWE-20 */
  const char *epoch = getenv ("SOURCE_DATE_EPOCH");
  const struct tm *tmv = NULL;
  time_t t;
  int i;

  if (NULL != epoch && '\0' != epoch[0])
    {
      char *end = NULL;
      long secs = strtol (epoch, &end, 10);

      if (NULL != end && '\0' == *end && secs >= 0)
        {
          t = (time_t)secs;
          tmv = gmtime (&t); /* SOURCE_DATE_EPOCH is interpreted as UTC */
        }
    }

  if (NULL == tmv)
    {
      t = time (NULL);
      tmv = localtime (&t);
    }

  if (NULL == tmv
      || 0
             == strftime (buf, sizeof (buf),
                          (want_time ? "%H:%M:%S" : "%m/%d/%y"), tmv))
    (void)xstrlcpy (buf, "        ", sizeof (buf)); /* no clock: 8 spaces */

  a->lst_kind = 1; /* listing: byte stream */

  for (i = 0; i < 8; i++)
    emit (a, (u16)(unsigned char)buf[i]);
}

/******************************************************************************/

/*
 * Radix-40 character value, or -1 if the character is not encodable.  The PSA
 * set is  ' '=0, '0'-'9'=1-10, 'A'-'Z'=11-36, '$'=37, '%'=38, '.'=39.
 */

static int
rad40_val (int c)
{
  c = toupper ((unsigned char)c);

  if (' ' == c)
    return 0;

  if (c >= '0' && c <= '9')
    return 1 + (c - '0');

  if (c >= 'A' && c <= 'Z')
    return 11 + (c - 'A');

  if ('$' == c)
    return 37;

  if ('%' == c)
    return 38;

  if ('.' == c)
    return 39;

  return -1;
}

/******************************************************************************/

/*
 * .RAD40 sym{,sym} : pack each symbol into four bytes of Radix-40 characters.
 * Three characters fill each of two big-endian 16-bit words (weights
 * 1600/40/1); at most six characters are used (extra encodable characters are
 * ignored), and a non-encodable character ends the symbol with an error.
 */

static void
do_rad40 (astate *a, const char *line, const char *p)
{
  a->lst_kind = 1; /* listing: byte stream */

  for (;;)
    {
      int ch[6];
      int n = 0, bad = 0, i;
      unsigned long w;

      p = skipws (p);

      if ('\0' == *p || ';' == *p)
        break;

      while ('\0' != *p && ';' != *p && ',' != *p
             && !isspace ((unsigned char)*p))
        {
          int v = rad40_val ((unsigned char)*p);

          if (v < 0)
            {
              bad = 1; /* stop at the first non-encodable character */
              break;
            }

          if (n < 6)
            ch[n++] = v; /* characters past the sixth are ignored */

          p++;
        }

      if (bad)
        {
          aerr (a, line, "bad RAD40 character");

          while ('\0' != *p && ';' != *p && ',' != *p
                 && !isspace ((unsigned char)*p))
            p++; /* swallow the rest of the malformed symbol */
        }

      for (i = n; i < 6; i++)
        ch[i] = 0; /* space-pad the trailing positions */

      w = (unsigned long)ch[0] * 1600UL + (unsigned long)ch[1] * 40UL
          + (unsigned long)ch[2];
      emit (a, (u16)((w >> 8) & 0xFFUL));
      emit (a, (u16)(w & 0xFFUL));

      w = (unsigned long)ch[3] * 1600UL + (unsigned long)ch[4] * 40UL
          + (unsigned long)ch[5];
      emit (a, (u16)((w >> 8) & 0xFFUL));
      emit (a, (u16)(w & 0xFFUL));

      p = skipws (p);

      if (',' == *p)
        p++;
    }
}

/******************************************************************************/

/*
 * listing / output-format directives that emit no bytes (handled for
 * now as no-ops; .PABS/.PREL below do affect the relocation mode).
 *
 * NOTE: .PRGEND (= .PRGEN) is recognized here only.  It is "library file
 * generation" -- it should end the current module like .END and then begin a
 * fresh module in the same object file.  That needs the multi-module / multi-
 * segment object model this single-.PROG.-segment engine does not yet have, so
 * for now a source with .PRGEND assembles as one module instead of several.
 * The segment-base symbols .PROG./.DATA./.BLNK. are likewise not yet resolved
 * (see the README "Future" section).
 */

static int
is_noop_dir (const char *op)
{
  static const char *list[]
      = { ".PHEX",   ".PBIN",    ".PAGE",   ".EJECT",  ".TITLE",  ".SBTTL",
          ".SUBTTL", ".IDENT",   ".REQUEST", ".NAME",  ".RELOC",  ".COMMENT",
          ".I8080",  ".Z80",     ".ENTRY",  ".INTERN", "PUBLIC",  ".PUBLIC",
          ".PRNTX",  ".PRINTX",  ".EXTERN", "EXTRN",   ".EXTRN",  "COMMON",
          ".COMMON", ".PRGEND",  NULL };
  int i;

  for (i = 0; NULL != list[i]; i++)
    if (0 == strcmp (op, list[i]))
      return 1;

  return 0;
}

/******************************************************************************/

static int
opeq (const char *op, const char *x, const char *y)
{
  return 0 == strcmp (op, x) || (NULL != y && 0 == strcmp (op, y));
}

/******************************************************************************/

static const char *
parse_opname (const char *p, char *out)
{
  int n = 0;

  p = skipws (p);

  while (isalnum ((unsigned char)*p) || '.' == *p || '_' == *p || '?' == *p
         || '@' == *p || '$' == *p || '%' == *p)
    {
      if (n < NAMEBUF - 1)
        out[n++] = (char)toupper ((unsigned char)*p);

      p++;
    }

  out[n] = '\0';

  return p;
}

/******************************************************************************/

/* resolve `op` in place through the .OPSYN alias chain */
static void
resolve_alias (const astate *a, char *op)
{
  int depth, i;

  for (depth = 0; depth < 16; depth++)
    {
      int found = 0;

      for (i = 0; i < a->nalias; i++)
        if (0 == strcmp (op, a->alias_from[i]))
          {
            (void)xstrlcpy (op, a->alias_to[i], NAMEBUF);
            found = 1;
            break;
          }

      if (!found)
        return;
    }
}

/******************************************************************************/

/*
 * The originals store pseudo-op names in a six-character-significant table, so
 * a directive whose documented spelling is longer than six characters is also
 * recognized by its first six (e.g. `.DEFIN' == `.DEFINE').  Rewrite such a
 * dot-directive in place to its canonical full name.  Only directives whose
 * canonical spelling exceeds six characters need an entry; the six-character
 * prefixes here are unambiguous, so this never over-matches a distinct op.
 */

static void
canon_dir (char *op)
{
  static const struct
  {
    const char *prefix6; /* first six significant characters */
    const char *canon;   /* canonical full spelling          */
  } tab[] = { { ".DEFIN", ".DEFINE" }, { ".EXTER", ".EXTERN" },
              { ".INSER", ".INSERT" }, { ".INTER", ".INTERN" },
              { ".REMAR", ".REMARK" }, { ".IFNDE", ".IFNDEF" },
              { ".PRGEN", ".PRGEND" }, { NULL, NULL } };
  int i;

  if ('.' != op[0] || strlen (op) < 6)
    return;

  for (i = 0; NULL != tab[i].prefix6; i++)
    if (0 == strncmp (op, tab[i].prefix6, 6))
      {
        (void)xstrlcpy (op, tab[i].canon, NAMEBUF);
        return;
      }
}

/******************************************************************************/

/*
 * Are we currently assembling?
 * (not inside a skipped conditional block)
 */

static int
casm (const astate *a)
{
  int i;

  for (i = 0; i < a->cdepth; i++)
    if (!a->cstack[i].assemble)
      return 0;

  return 1;
}

/******************************************************************************/

static int
is_conditional (const char *op)
{
  return 0 == strcmp (op, ".IFE") || 0 == strcmp (op, ".IFN")
      || 0 == strcmp (op, ".IFL") || 0 == strcmp (op, ".IFLE")
      || 0 == strcmp (op, ".IFG") || 0 == strcmp (op, ".IFGE")
      || 0 == strcmp (op, ".IFDEF") || 0 == strcmp (op, ".IFNDEF")
      || 0 == strcmp (op, ".IFIDN") || 0 == strcmp (op, ".IFDIF")
      || 0 == strcmp (op, ".IFB") || 0 == strcmp (op, ".IFNB")
      || 0 == strcmp (op, ".IF1") || 0 == strcmp (op, ".IF2");
}

/******************************************************************************/

/*
 * Read one string argument: "quoted" or bare
 * (up to space/comma/;)
 */

static const char *
parse_str_arg (const char *p, char *out)
{
  int n = 0;

  p = skipws (p);

  if ('"' == *p)
    {
      p++;

      while ('\0' != *p && '"' != *p && n < 127)
        out[n++] = *p++;

      if ('"' == *p)
        p++;
    }
  else
    while ('\0' != *p && ' ' != *p && '\t' != *p && ',' != *p && ';' != *p
           && n < 127)
      out[n++] = *p++;

  out[n] = '\0';
  return p;
}

/******************************************************************************/

/*
 * .IFIDN/.IFDIF (string compare) and .IFB/.IFNB
 * (blank argument)
 */

/*
 * drop trailing blanks: a macro argument keeps the source whitespace
 * before its comment (so ST16 X,H passes "H\t"), but the string
 * conditionals match the originals by ignoring it
 */

static void
rstrip (char *s)
{
  size_t n = strlen (s);

  while (n > 0 && (' ' == s[n - 1] || '\t' == s[n - 1]))
    s[--n] = '\0';
}

static int
str_cond_test (const char *op, const char *operands)
{
  char s1[128], s2[128];
  const char *p = parse_str_arg (operands, s1);

  rstrip (s1);

  if (0 == strcmp (op, ".IFB"))
    return '\0' == s1[0];

  if (0 == strcmp (op, ".IFNB"))
    return '\0' != s1[0];

  (void)parse_str_arg (p, s2);
  rstrip (s2);

  if (0 == strcmp (op, ".IFIDN"))
    return 0 == strcmp (s1, s2);

  return 0 != strcmp (s1, s2); /* .IFDIF */
}

/******************************************************************************/

static int
cond_test (const char *op, const value_t *v)
{
  int sv = ((v->value < 0x8000) ? (int)v->value : (int)v->value - 0x10000);

  if (0 == strcmp (op, ".IFN"))
    return 0 != v->value;

  if (0 == strcmp (op, ".IFE"))
    return 0 == v->value;

  if (0 == strcmp (op, ".IFG"))
    return sv > 0;

  if (0 == strcmp (op, ".IFGE"))
    return sv >= 0;

  if (0 == strcmp (op, ".IFL"))
    return sv < 0;

  if (0 == strcmp (op, ".IFLE"))
    return sv <= 0;

  return 0;
}

/******************************************************************************/

/*
 * Render the byte column the way the originals do: opcode bytes in order, an
 * 8-bit operand concatenated onto them, a 16-bit operand/word as a spaced
 * value field (little-endian bytes shown big-endian), and data as a byte
 * stream.
 */

static void
lst_bytes (const astate *a, char *col, size_t cap)
{
  int cn = 0, i;

  if (2 == a->lst_kind)
    { /* .WORD: value words + reloc.  TDL shows at most two words; PSA one. */
      int maxw = ((DIALECT_PASM == a->dialect) ? 2 : 4);

      for (i = 0; i + 1 < a->nbytes && i < maxw; i += 2)
        {
          int fl = a->wreloc[i / 2];
          /* .XADDR (default) shows the 16-bit value; .LADDR shows the bytes in
           * generated (memory) order -- least significant byte first. */
          unsigned shown
              = ((a->lst_ctl & LSTC_LADDR)
                     ? (unsigned)((a->bytes[i] << 8) | a->bytes[(long)i + 1])
                     : (unsigned)(a->bytes[i] | (a->bytes[(long)i + 1] << 8)));
          cn += xsnprintf (col + cn, cap - (size_t)cn, "%s%04X%c",
                           (i ? "   " : ""), shown, (fl ? fl : ' '));
        }

      while (cn > 0 && ' ' == col[(long)cn - 1])
        cn--; /* trim trailing pad */
    }
  else if (1 == a->lst_kind)
    { /* data: byte stream (the originals show at most six bytes) */
      for (i = 0; i < a->nbytes && i < 6; i++)
        {
          cn += xsnprintf (col + cn, cap - (size_t)cn, "%02X",
                           (unsigned)a->bytes[i]);
        }
    }
  else
    { /* instruction: opcode + operand */
      int nop = a->nbytes - a->lst_opw; /* opcode byte count */

      if (nop < 0)
        nop = a->nbytes;

      for (i = 0; i < nop && cn < 16; i++)
        {
          cn += xsnprintf (col + cn, cap - (size_t)cn, "%02X",
                           (unsigned)a->bytes[i]);
        }

      if (1 == a->lst_opw && nop < a->nbytes)
        {
          cn += xsnprintf (col + cn, cap - (size_t)cn, "%02X",
                           (unsigned)a->bytes[nop]);
        }
      else if (2 == a->lst_opw && nop + 1 < a->nbytes)
        {
          cn += xsnprintf (
              col + cn, cap - (size_t)cn, " %04X%s",
              (unsigned)(a->bytes[nop] | (a->bytes[(long)nop + 1] << 8)),
              (a->lst_oreloc ? "'" : ""));
        }
    }

  col[cn] = '\0';
}

/******************************************************************************/

/*
 * Content lines per page before the form-feed: a 66-line
 * printer page less a 3-line bottom margin (both dialects)
 */

#define LST_PAGE 63

/******************************************************************************/

static void lst_header (astate *a); /* forward */

/******************************************************************************/

/*
 * At the wrap column, break to an indented continuation line, as the
 * originals do: they fold a listing line at a fixed width (TDL 72, PSA 79)
 * and re-indent the remainder to the source column.  Returns the new column.
 */

static int
lst_wrap (astate *a, int col, int wrapw, int indent)
{
  if (col >= wrapw)
    { /* end this physical line and start an indented continuation; the
       * originals paginate physical lines, so a continuation that lands on a
       * full page is preceded by a form-feed and heading (a mid-line break) */
      int k;

      (void)fputc ('\n', a->lst);
      a->lst_line++;

      if (a->lst_line >= LST_PAGE)
        {
          (void)fputc ('\f', a->lst);
          lst_header (a);
        }

      for (k = 0; k < indent; k++)
        (void)fputc (' ', a->lst);

      return indent;
    }

  return col;
}

/******************************************************************************/

/*
 * Print the source field, expanding tabs to spaces on 8-column tab stops,
 * as the originals do - they emit no tab bytes.  Long lines fold at `wrapw`
 * with the continuation re-indented to `indent` (the source column).
 * `col` is the column already printed.
 */

static void
lst_source (astate *a, const char *s, int col, int wrapw, int indent)
{
  for (; '\0' != *s; s++)
    {
      if ('\t' == *s)
        {
          do
            {
              col = lst_wrap (a, col, wrapw, indent);
              (void)fputc (' ', a->lst);
              col++;
            }
          while (0 != (col % 8));
        }
      else
        {
          col = lst_wrap (a, col, wrapw, indent);
          (void)fputc (*s, a->lst);
          col++;
        }
    }

  (void)fputc ('\n', a->lst);
  a->lst_line++; /* count this final physical line */
}

/******************************************************************************/

static void
print_lst (astate *a, u16 lc0, const char *rawline)
{
  char col[40];
  int bw = ((DIALECT_PASM == a->dialect) ? 14 : 13); /* byte-field width */
  long loc = ((-2 == a->lst_loc) ? (long)lc0 : a->lst_loc);
  int rel = ((a->lst_lreloc < 0) ? (0 != a->lc_reloc) : a->lst_lreloc);
  int clen;
  char mark = 0; /* macro '+' / .INSERT '@' continuation marker, or none */

  if (a->lst_suppress) /* assembling only (e.g. a macro's first body line) */
    return;

  /* listing-control gating: body listing off (.XLIST), or a listing-control
   * statement that does not list itself (default, reset by .LCTL). */
  if (!(a->lst_ctl & LSTC_LIST))
    return;

  if (a->lst_ctlstmt && !(a->lst_ctl & LSTC_CTL))
    return;

  if (NULL != a->mac_src) /* macro listing supplies the rendered source */
    rawline = a->mac_src;
  else if (a->mac_active)
    { /* macro-expansion listing detail: .SALL suppresses the whole body,
       * .XALL (default) drops the no-code lines, .LALL lists everything */
      if (a->lst_ctl & LSTC_SALL)
        return;

      if (0 == a->nbytes && !(a->lst_ctl & LSTC_LALL))
        return;
    }

  /* inserted-file lines carry '@'; continued macro statements carry '+'
   * (but not the macro call line, which sets mac_src with mac_plus clear) */
  if (a->ins_depth > 0)
    mark = '@';
  else if (a->mac_plus || (a->mac_active && NULL == a->mac_src))
    mark = '+';

  col[0] = '\0';

  if (a->nbytes > 0)
    lst_bytes (a, col, sizeof (col));

  clen = (int)strlen (col);

  /*
   * Determine the rendered source field for this line.  The originals build
   * the listing line in a fixed buffer and lay the value field over the
   * source field: a multi-word .WORD line (>=2 value words) runs the value
   * field long enough to overstrike the FIRST TWO source columns -- so a
   * label loses its first two chars and a label-less ".WORD" lists as "WORD"
   * shifted left.  Macro/inserted lines instead carry a +/@ marker.
   */
  {
    int wrapw = ((DIALECT_PASM == a->dialect) ? 79 : 72);
    int indent = 11 + bw;
    /* PSA shows one word, no overstrike: the over-strike quirk is TDL-only */
    int over = (0 == mark && 2 == a->lst_kind && a->nbytes >= 4 && loc >= 0
                && DIALECT_PASM != a->dialect
                && (int)strlen (rawline) >= 2);
    const char *src;
    int scol;

    if (over)
      {
        src = rawline + 2;
        scol = 11 + bw + 2;
      }
    else if (mark)
      {
        src = rawline;
        scol = 11 + bw;
      }
    else
      {
        src = rawline;
        scol = 11 + (clen > bw ? clen : bw);
      }

    /* page full: form-feed + heading before this line's first physical row
     * (continuation rows paginate inside lst_source) */
    if (a->lst_line >= LST_PAGE)
      {
        (void)fputc ('\f', a->lst);
        lst_header (a);
      }

    if (over)
      {
        int p;

        (void)fprintf (a->lst, "   %04X%c   %s", (unsigned)loc,
                       (rel ? '\'' : ' '), col);

        for (p = 11 + clen; p < scol; p++)
          (void)fputc (' ', a->lst);
      }
    else if (mark)
      { /* the marker occupies the final byte-field column */
        if (loc < 0)
          (void)fprintf (a->lst, "           %-*s%c", bw - 1, col, mark);
        else
          (void)fprintf (a->lst, "   %04X%c   %-*s%c", (unsigned)loc,
                         (rel ? '\'' : ' '), bw - 1, col, mark);
      }
    else
      {
        if (loc < 0) /* .END and other blank-LOC lines */
          (void)fprintf (a->lst, "           %-*s", bw, col);
        else
          (void)fprintf (a->lst, "   %04X%c   %-*s", (unsigned)loc,
                         (rel ? '\'' : ' '), bw, col);
      }

    lst_source (a, src, scol, wrapw, indent);
  }
}

/******************************************************************************/

/*
 * Per-page listing heading.  TDL and PSA differ in the title, the PAGE/Page
 * spelling and column, and (PSA) a blank line before the ".MAIN. -" subtitle.
 */

static void
lst_header (astate *a)
{
  a->lst_page++;
  (void)fprintf (a->lst, "\n\n\n");

  if (DIALECT_PASM == a->dialect)
    (void)fprintf (a->lst, "%-71sPage %d\n\n.MAIN. - %s\n\n\n\n",
                   "PSA Macro Assembler [C12011-0102 ]", a->lst_page, a->title);
  else
    (void)fprintf (a->lst, "%-64sPAGE %d\n.MAIN. - %s\n\n\n\n",
                   "TDL Z80 CP/M DISK ASSEMBLER VERSION 2.21", a->lst_page,
                   a->title);

  /* heading line count */
  a->lst_line = ((DIALECT_PASM == a->dialect) ? 9 : 8);
}

/******************************************************************************/

/*
 * Collation rank for the symbol-table sort: the originals order digits, then
 * letters, then the remaining name characters ('.', '?', '@', '$', ...) -- so
 * e.g. P.PEP sorts AFTER PVALUE, not before P1 as plain ASCII would have it.
 */

static int
sym_rank (int c)
{
  c = toupper ((unsigned char)c);

  if (c >= '0' && c <= '9')
    return c - '0'; /* 0..9 */

  if (c >= 'A' && c <= 'Z')
    return 10 + c - 'A'; /* 10..35 */

  return 36 + (unsigned char)c; /* other name chars sort last */
}

static int
sym_name_cmp (const void *pa, const void *pb)
{
  const char *a = (*(symbol *const *)pa)->name;
  const char *b = (*(symbol *const *)pb)->name;

  for (;; a++, b++)
    {
      int ra = (('\0' != *a) ? sym_rank (*a) : -1);
      int rb = (('\0' != *b) ? sym_rank (*b) : -1);

      if (ra != rb)
        return ra - rb;

      if (ra < 0)
        return 0;
    }

#ifdef _CH_
  /*NOTREACHED*/ /* unreachable */
  return 0;
#endif
}

/******************************************************************************/

/*
 * End-of-listing symbol table on a fresh page: each entry is "%-6s %04X" plus
 * a 6-char flag field, 3-per-line (TDL) / 4 (PSA); user symbols sorted
 * alphabe- tically with the .BLNK./.DATA./.PROG. segment entries appended
 * (fixed for absolute output, confirmed by disassembly).
 * The symbol-table page heading, repeated on every table page; sets the line
 * counter so the table paginates on the same 63-line page as the body.
 */

static void
lst_symhead (astate *a)
{
  a->lst_page++;
  (void)fprintf (a->lst, "\n\n\n");

  if (DIALECT_PASM == a->dialect)
    {
      (void)fprintf (
          a->lst, "%-71sPage %d\n\n.MAIN. - %s\n+++++ Symbol Table +++++\n\n\n",
          "PSA Macro Assembler [C12011-0102 ]", a->lst_page, a->title);
      a->lst_line = 9;
    }
  else
    {
      (void)fprintf (a->lst,
                     "%-64sPAGE %d\n.MAIN. - %s\n"
                     "+++++ SYMBOL TABLE +++++\n\n\n",
                     "TDL Z80 CP/M DISK ASSEMBLER VERSION 2.21", a->lst_page,
                     a->title);
      a->lst_line = 8;
    }
}

/******************************************************************************/

static void
lst_symtab (astate *a)
{
  static const char *segname[3] = { ".BLNK.", ".DATA.", ".PROG." };

#ifndef _CH_
  const
#endif
  char *segflag[3];
  symbol **all;
  int total, nuser = 0, navail, i, col, perline;
  segflag[0] = ":03 X ";
  segflag[1] = ((DIALECT_PASM == a->dialect) ? "\"   X " : "*   X ");
  segflag[2] = "'   X ";
  perline = ((DIALECT_PASM == a->dialect) ? 4 : 3);
  navail = sym_count (a->syms);
  all = (symbol **)malloc (sizeof (symbol *)
                           * (size_t)(navail > 0 ? navail : 1));
  if (NULL == all)
    return;

  sym_collect (a->syms, all);

  for (i = 0; i < navail; i++) /* keep defined, non-local symbols */
    if (all[i]->defined && NULL == strchr (all[i]->name, ':'))
      all[nuser++] = all[i];

  qsort (all, (size_t)nuser, sizeof (symbol *), sym_name_cmp);
  (void)fputc ('\f', a->lst); /* eject to a fresh page */
  lst_symhead (a);
  total = nuser + 3;
  col = 0;

  for (i = 0; i < total; i++)
    {
      const char *name, *flag;
      unsigned val;

      if (i < nuser)
        {
          name = all[i]->name;
          val = all[i]->val.value;
          /* relocatable symbols carry a quote after the value */
          flag = ((0 != all[i]->val.reloc) ? "'     " : "      ");
        }
      else
        {
          /*
           * .PROG. (index 2) carries the program-segment size;
           * the .BLNK./.DATA. rows stay 0000 for this absolute-segment output
           */

          name = segname[(long)i - nuser];
          val = ((2 == (long)i - nuser) ? a->prog_max : 0);
          flag = segflag[(long)i - nuser];
        }

      (void)fprintf (a->lst, "%-6s %04X%s", name, val & 0xFFFFu, flag);

      if ((col == perline - 1) || (i == total - 1))
        {
          (void)fputc ('\n', a->lst);
          col = 0;
          a->lst_line++;

          if (a->lst_line >= LST_PAGE && i < total - 1)
            { /* table continues on a new page */
              (void)fputc ('\f', a->lst);
              lst_symhead (a);
            }
        }
      else
        {
          (void)fprintf (a->lst, "   ");
          col++;
        }
    }

  FREE (all);
}

/******************************************************************************/

static void process_file (astate *a, const char *path); /* forward */

/******************************************************************************/

/*
 * .INSERT <file>: process the named file inline (extension defaults
 * to .ASM, resolved relative to the top-level source's directory).
 */

static void
do_insert (astate *a, const char *field)
{
  char name[300], path[1024];
  int n = 0, dot = 0;
  const char *p = skipws (field);

  while ('\0' != *p && ' ' != *p && '\t' != *p && ';' != *p && ',' != *p)
    {
      if ('.' == *p)
        dot = 1;

      if (n < 290)
        name[n++] = (char)tolower ((unsigned char)*p);

      p++;
    }
  name[n] = '\0';

  if (!dot)
    (void)xstrlcat (name, ".asm", sizeof (name));

  if ('\0' != a->basedir[0])
    (void)xsnprintf (path, sizeof (path), "%s/%s", a->basedir, name);
  else
    (void)xstrlcpy (path, name, sizeof (path));

  process_file (a, path);
}

/******************************************************************************/

/* ---- macros: .DEFINE NAME[params] = [body] ------------------------- */

static void do_line (astate *a, const char *line); /* forward */

/******************************************************************************/

static char *
dupstr (const char *s)
{
  size_t n = strlen (s) + 1;
  char *p = (char *)malloc (n);

  if (NULL != p)
    (void)memcpy (p, s, n);

  return p;
}

/******************************************************************************/

static macrodef *
macro_lookup (astate *a, const char *name)
{
  macrodef *m;

  for (m = a->macros; NULL != m; m = m->next)
    if (0 == strcmp (m->name, name))
      return m;

  return NULL;
}

/******************************************************************************/

static void
macro_free_all (astate *a)
{
  macrodef *m, *nx;
  int i;

  for (m = a->macros; NULL != m; m = nx)
    {
      nx = m->next;

      for (i = 0; i < m->nbody; i++)
        FREE (m->body[i]);

      FREE (m);
    }

  a->macros = NULL;
}

/******************************************************************************/

/*
 * accumulate body text (the [...] block) while a->defining is set;
 * the macro is added to the table when the matching ']' closes it.
 */

static void
macro_capture (astate *a, const char *p)
{
  macrodef *m = a->defining;
  char buf[512];
  int n = 0;

  if (!a->def_started)
    {
      p = skipws (p);

      if ('\0' == *p || ';' == *p)
        return;

      if ('[' != *p)
        {
          FREE (m);
          a->defining = NULL;
          return;
        }

      a->def_started = 1;
      a->def_depth = 1;
      p++;
    }

  while ('\0' != *p)
    {
      if ('[' == *p)
        a->def_depth++;
      else if (']' == *p)
        {
          a->def_depth--;

          if (0 == a->def_depth)
            {
              buf[n] = '\0';

              if (m->nbody < 64)
                {
                  m->body[m->nbody] = dupstr (buf);
                  m->nbody++;
                }

              m->next = a->macros;
              a->macros = m;
              a->defining = NULL;
              a->def_started = 0;

              return;
            }
        }

      if (n < 511)
        buf[n++] = *p;

      p++;
    }

  buf[n] = '\0';

  if (m->nbody < 64)
    {
      m->body[m->nbody] = dupstr (buf);
      m->nbody++;
    }
}

/******************************************************************************/

static void
do_define (astate *a, const char *operands)
{
  macrodef *m = (macrodef *)malloc (sizeof (*m));
  const char *p = skipws (operands);
  int n = 0;

  if (NULL == m)
    return;

  m->nparams = 0;
  m->nbody = 0;
  m->next = NULL;

  while (isalnum ((unsigned char)*p) || '_' == *p || '?' == *p || '@' == *p
         || '.' == *p || '$' == *p || '%' == *p)
    {
      if (n < NAMEBUF - 1)
        m->name[n++] = (char)toupper ((unsigned char)*p);

      p++;
    }

  m->name[n] = '\0';
  p = skipws (p);

  if ('[' == *p)
    { /* parameter list */
      p++;

      while ('\0' != *p && ']' != *p && ')' != *p && '=' != *p)
        {
          char *pn = m->params[m->nparams];
          int pi = 0;
          const char *st = p;
          p = skipws (p);

          while (isalnum ((unsigned char)*p) || '_' == *p || '?' == *p
                 || '@' == *p || '.' == *p || '$' == *p || '%' == *p)
            {
              if (pi < NAMEBUF - 1)
                pn[pi++] = *p;

              p++;
            }

          pn[pi] = '\0';

          if (pi > 0 && m->nparams < 7)
            m->nparams++;

          p = skipws (p);

          if (',' == *p)
            p++;

          /* malformed list (e.g. "[a,b)"): bail out */
          if (p == st)
            break;
        }

      if (']' == *p || ')' == *p)
        p++;
    }

  p = skipws (p);

  if ('=' == *p)
    p++;

  p = skipws (p);
  a->defining = m;
  a->def_started = 0;
  a->def_depth = 0;

  if ('\0' != *p && ';' != *p)
    macro_capture (a, p); /* body on same line */
}

/******************************************************************************/

/*
 * substitute parameter tokens with arguments (string literals left verbatim)
 */

static void
macro_subst (const macrodef *m, char *args[], int nargs, const char *in,
             char *out)
{
  int oi = 0;

  while ('\0' != *in && oi < 500)
    {
      if ('\'' == *in)
        { /* concatenation if next token is a param */
          const char *q = in + 1;
          char pk[NAMEBUF];
          int pn = 0, k, isp = 0;

          while ((isalnum ((unsigned char)*q) || '_' == *q || '?' == *q
                  || '@' == *q || '.' == *q || '$' == *q || '%' == *q)
                 && pn < NAMEBUF - 1)
            pk[pn++] = *q++;

          pk[pn] = '\0';

          for (k = 0; k < m->nparams; k++)
            {
              if (ci_eq (pk, m->params[k]))
                {
                  isp = 1;
                  break;
                }
            }

          if (isp)
            {
              in++;
              continue;
            } /* paste: drop the apostrophe */

          /* otherwise a literal 'string' */
          out[oi++] = *in++;

          while ('\0' != *in && '\'' != *in && oi < 500)
            out[oi++] = *in++;

          if ('\'' == *in && oi < 500)
            out[oi++] = *in++;
        }
      else if (isalpha ((unsigned char)*in) || '_' == *in || '?' == *in
               || '@' == *in || '.' == *in || '%' == *in)
        {
          char tok[NAMEBUF];
          int tn = 0, j, pi = -1;

          while ((isalnum ((unsigned char)*in) || '_' == *in || '?' == *in
                  || '@' == *in || '.' == *in || '$' == *in || '%' == *in)
                 && tn < NAMEBUF - 1)
            tok[tn++] = *in++;

          tok[tn] = '\0';

          for (j = 0; j < m->nparams; j++)
            {
              if (ci_eq (tok, m->params[j]))
                {
                  pi = j;
                  break;
                }
            }

          {
            const char *s = ((pi >= 0 && pi < nargs) ? args[pi] : tok);

            while ('\0' != *s && oi < 500)
              out[oi++] = *s++;
          }
        }
      else
        out[oi++] = *in++;
    }

  out[oi] = '\0';
}

/******************************************************************************/

/*
 * net '(' minus ')' depth of a macro argument (parens may span source lines)
 */

static int
paren_depth_of (const char *s)
{
  int d = 0;

  while ('\0' != *s && ';' != *s)
    {
      if ('(' == *s)
        d++;
      else if (')' == *s)
        d--;

      s++;
    }

  return d;
}

/******************************************************************************/

static void
expand_macro (astate *a, const macrodef *m, const char *argstr,
              const char *callline)
{
  char argbuf[1024];
  char *args[8];
  int nargs = 0, i, j = 0;
  int outer = 0, start = 0;
  const char *p = skipws (argstr);

  if (a->macro_depth > 200)
    { /* runaway recursion guard */
      a->errors++;
      return;
    }

  a->macro_depth++;

  if ('[' == *p)
    p = skipws (p + 1); /* optional [arg,arg] bracketed list */

  while ('\0' != *p && ';' != *p && ']' != *p && nargs < 8 && j < 1000)
    {
      args[nargs] = argbuf + j;

      if ('\\' == *p)
        { /* \expr -> decimal value */
          value_t vv;
          const char *ep = p + 1;
          char num[16];
          const char *np;
          (void)eval1 (a, &ep, &vv);
          (void)xsnprintf (num, sizeof (num), "%u", (unsigned)vv.value);

          for (np = num; '\0' != *np && j < 1000; np++)
            argbuf[j++] = *np;

          p = ep;
        }
      else if ('(' == *p)
        { /* (arg): strip one paren level */
          int depth = 1;
          p++;

          while ('\0' != *p && depth > 0)
            {
              if ('(' == *p)
                depth++;
              else if (')' == *p)
                {
                  depth--;

                  if (0 == depth)
                    {
                      p++;
                      break;
                    }
                }

              if (j < 1000)
                argbuf[j++] = *p;

              p++;
            }
        }
      else
        {
          int s = j;

          while ('\0' != *p && ',' != *p && ';' != *p && ']' != *p && j < 1000)
            {
              /*
               * Copy a quoted literal whole so a ',' ']' or ';' inside
               * it (e.g., the ']' in CPIB$ X,']') is not a delimiter
               */

              if ('\'' == *p || '"' == *p)
                {
                  char qc = *p;
                  argbuf[j++] = *p++;

                  while ('\0' != *p && *p != qc && j < 1000)
                    argbuf[j++] = *p++;

                  if (*p == qc && j < 1000)
                    argbuf[j++] = *p++;
                }
              else
                argbuf[j++] = *p++;
            }

          /*
           * Trailing whitespace handling is dialect-specific: TDL carries it
           * into the expansion (it expands in the listing -- a call's trailing
           * tabs push a macro body's ']' to the right), while PSA trims it.
           * Either way it is harmless to the byte stream (the expression
           * scanner skips it).
           */
          if (DIALECT_PASM == a->dialect)
            while (j > s
                   && (' ' == argbuf[(long)j - 1]
                       || '\t' == argbuf[(long)j - 1]))
              j--;
        }

      argbuf[j++] = '\0';
      nargs++;
      p = skipws (p);

      if (',' == *p)
        {
          p++;
          p = skipws (p);
        }
      else
        break;
    }

  /*
   * Macro-expansion listing (pass 2).  The originals fold the body into the
   * call line and flatten nested expansions: only the OUTERMOST macro emits
   * the call line (invocation + body-open '[', carrying the first body line
   * when it emits bytes) and the body-close ']'; statements that emit bytes
   * list with a '+' continuation marker; control-flow inside a macro
   * (conditionals, nested call lines, brackets, skipped lines) is suppressed
   * (driven by mac_active/lst_suppress in print_lst).
   */
  outer = (2 == a->pass && NULL != callline && !a->mac_active && m->nbody > 0);

  if (outer)
    {
      char ln0[512];
      char src[2048];
      u16 lc0;

      a->mac_active = 1;

      /*
       * assemble body line 0 silently: it may emit bytes (folded onto
       * the call line) or merely open a conditional that spans the body
       */

      macro_subst (m, args, nargs, m->body[0], ln0);
      lc0 = a->lc;
      a->lst_suppress = 1;
      do_line (a, ln0);
      a->lst_suppress = 0;

      if (a->lst_ctl & LSTC_SALL)
        (void)xsnprintf (src, sizeof (src), "%s",
                         callline); /* .SALL: the bare call line only */
      else if (a->nbytes > 0)
        (void)xsnprintf (src, sizeof (src), "%s[%s%s", callline, ln0,
                         ((1 == m->nbody) ? "]" : ""));
      else
        (void)xsnprintf (src, sizeof (src), "%s[", callline);

      a->mac_src = src;
      a->mac_plus = 0;
      print_lst (a, lc0, callline);
      a->mac_src = NULL;
      start = 1;
    }

  for (i = start; i < m->nbody; i++)
    {
      char ln[512];

      if (a->macro_exit) /* .EXIT terminated this expansion early */
        break;

      macro_subst (m, args, nargs, m->body[i], ln);

      if (outer && i == m->nbody - 1 && !(a->lst_ctl & LSTC_SALL))
        { /* the body-close: force-list this last line with ']' appended
           * (under .SALL the body text is suppressed, so fall through) */
          char src[600];
          (void)xsnprintf (src, sizeof (src), "%s]", ln);
          a->mac_src = src;
          a->mac_plus = 1;
          do_line (a, ln);
          a->mac_src = NULL;
          a->mac_plus = 0;
        }
      else
        do_line (a, ln);
    }

  a->macro_depth--;
  a->macro_exit = 0; /* the .EXIT (if any) terminated only this expansion */

  if (outer)
    a->mac_active = 0;
}

/******************************************************************************/

/*
 * Read one assembly-time console value for the '\' operator: emit ':' as the
 * original does, read a line from stdin, and define the symbol from it.
 */

static void
console_read (const astate *a, symbol *s)
{
  char ibuf[256];
  long iv = 0;

  (void)fputc (':', stderr);
  (void)fflush (stdout);
  (void)fflush (stderr);

  if (NULL == fgets (ibuf, (int)sizeof (ibuf), stdin))
    {
      /*
       * End of input before every prompt was answered.
       * Abort rather than default to 0 or block forever.
       */

      (void)fprintf (stderr,
          "\nerror: ran out of console responses (no value for '%s'); "
          "supply every answer via a pipe or -r FILE\n", s->name);

      exit (1);
    }

  iv = strtol (ibuf, (char **)NULL, a->radix);
  s->val.value = (u16)iv;
  s->val.reloc = 0;
  s->val.ext = NULL;
  s->defined = 1;
}

/******************************************************************************/

static void
do_line (astate *a, const char *line)
{
  line_t L;
  char op[NAMEBUF];
  const char *bp;
  u16 lc0;
  const macrodef *mac;

  a->nbytes = 0;
  a->lst_kind = 0;
  a->lst_opw = 0;     /* default: instruction, no operand */
  a->lst_loc = -2;    /* default: show the statement LC    */
  a->lst_lreloc = -1; /* default: LC reloc from lc_reloc */
  a->lst_oreloc = 0;
  a->lst_ctlstmt = 0; /* set by the listing-control directives */

  if (a->ended)
    return;

  if (a->defining)
    { /* a .DEFINE body line: the originals list it verbatim, blank LC */
      if (2 == a->pass)
        {
          a->lst_loc = -1;
          print_lst (a, a->lc, line);
        }

      macro_capture (a, line);
      return;
    }

  if (a->in_prompt)
    { /* consuming a multi-line '\' prompt string */
      const char *q = line;

      while ('\0' != *q && '\'' != *q)
        {
          if (NULL != a->pend_console)
            (void)fputc (*q, stderr);

          q++;
        }

      if ('\'' == *q)
        {
          a->in_prompt = 0;

          if (NULL != a->pend_console)
            {
              console_read (a, a->pend_console);
              a->pend_console = NULL;
            }
        }
      else if (NULL != a->pend_console)
        (void)fputc ('\n', stderr);

      return;
    }

  if (a->pending)
    { /* continuing a multi-line macro argument */
      const char *s = line;

      if (a->pend_len < 1022)
        a->pend_args[a->pend_len++] = ' ';

      while ('\0' != *s && ';' != *s && a->pend_len < 1022)
        {
          char c = *s++;

          if ('(' == c)
            a->pend_depth++;
          else if (')' == c)
            a->pend_depth--;

          a->pend_args[a->pend_len++] = c;

          if (a->pend_depth <= 0)
            break;
        }

      if (a->pend_depth <= 0)
        {
          const macrodef *pm = macro_lookup (a, a->pend_op);
          a->pend_args[a->pend_len] = '\0';
          a->pending = 0;

          if (NULL != pm) /* multi-line arg: no single call line to fold */
            expand_macro (a, pm, a->pend_args, NULL);
        }

      return;
    }

  lc0 = a->lc;

  /* '.' in operands resolves to the statement start */
  a->lc_stmt = a->lc;

  /* leading block-close ']' and else ']' '[' brackets */
  bp = skipws (line);

  while (']' == *bp)
    {
      int wt = 0;

      if (a->cdepth > 0)
        {
          wt = a->cstack[(long)a->cdepth - 1].if_true;
          a->cdepth--;
        }

      bp = skipws (bp + 1);

      if ('[' == *bp)
        {
          int outer = casm (a);

          if (a->cdepth < MAXCOND)
            {
              a->cstack[a->cdepth].if_true = !wt;
              a->cstack[a->cdepth].assemble = outer && !wt;
              a->cdepth++;
            }

          bp = skipws (bp + 1);
        }
    }

  if ('\0' == *bp || ';' == *bp)
    { /* blank or comment-only line: the originals still list it, with a
       * blank LC column (tabs in the source expand as usual) */
      if (2 == a->pass && casm (a))
        {
          a->lst_loc = -1;
          print_lst (a, lc0, line);
        }

      return;
    }

  lex_line (bp, &L);

  op[0] = '\0';

  if ('\0' != L.op[0])
    {
      int k;

      for (k = 0; k < NAMEBUF - 1 && '\0' != L.op[k]; k++)
        op[k] = (char)toupper ((unsigned char)L.op[k]);

      op[k] = '\0';
      resolve_alias (a, op);
      canon_dir (op); /* accept the six-char-truncated directive spellings */
    }

  /*
   * Define an address label even when it shares its line with a conditional
   * (e.g. "NEXTLF: IF POLLING, ["), so do it before the conditional dispatch.
   */

  if ('\0' != L.label[0] && !L.assign && casm (a))
    {
      char qn[NAMEBUF + 16];
      const char *dn = L.label;
      symbol *s;

      if ('.' == L.label[0] && '.' == L.label[1])
        { /* local '..' label */
          (void)xsnprintf (qn, sizeof (qn), "%u:%s", a->scope, L.label);
          dn = qn;
        }
      else /* a global label starts a new local scope */
        a->scope++;

      s = sym_intern (a->syms, dn);

      /*
       * TDL/PSA silently keep the FIRST definition of a redefined symbol;
       * only the first time it is seen in a pass do we (re)define it.
       */

      if (s->seen != (unsigned char)a->pass)
        {
          if (2 == a->pass && s->defined && s->val.value != a->lc)
            aerr (a, line, "phase error");

          s->val.value = a->lc;
          s->val.reloc = a->lc_reloc;
          s->val.ext = NULL;
          s->defined = 1;
          s->seen = (unsigned char)a->pass;
        }
    }

  /* conditional directive: evaluate, push a frame; the '[' opens the block */
  if (is_conditional (op))
    {
      int outer = casm (a), t = 0;

      if (outer)
        {
          const char *q = L.operands;
          value_t v;

          if (0 == strcmp (op, ".IFIDN") || 0 == strcmp (op, ".IFDIF")
              || 0 == strcmp (op, ".IFB") || 0 == strcmp (op, ".IFNB"))
            t = str_cond_test (op, q);
          else if (0 == strcmp (op, ".IF1")) /* TRUE on pass 1 */
            t = (1 == a->pass);
          else if (0 == strcmp (op, ".IF2")) /* TRUE on pass 2 (not pass 1) */
            t = (2 == a->pass);
          else if (0 == strcmp (op, ".IFDEF") || 0 == strcmp (op, ".IFNDEF"))
            {
              char nm[NAMEBUF];
              const symbol *s;
              (void)parse_opname (q, nm);
              s = sym_lookup (a->syms, nm);
              t = (NULL != s && s->defined);

              if (0 == strcmp (op, ".IFNDEF"))
                t = !t;
            }
          else if (!eval1 (a, &q, &v))
            t = cond_test (op, &v);
        }

      if (a->cdepth < MAXCOND)
        {
          a->cstack[a->cdepth].if_true = t;
          a->cstack[a->cdepth].assemble = outer && t;
          a->cdepth++;
        }

      if (2 == a->pass)
        { /*
           * the originals list the conditional directive
           * line itself, with a blank LC column
           */
          a->lst_loc = -1;
          print_lst (a, lc0, line);
        }

      return;
    }

  if (!casm (a))
    { /*
       * inside a skipped conditional block: the originals still list
       * the source line, with a blank LC column and no emitted bytes
       */
      if (2 == a->pass)
        {
          a->lst_loc = -1;
          print_lst (a, lc0, line);
        }

      return;
    }

  if (L.assign)
    {
      const char *q = skipws (L.operands);

      if ('\\' == *q)
        { /* '\' console-input operator */
          symbol *s = sym_intern (a->syms, L.label);
          int reading = (1 == a->pass || !s->defined);
          q = skipws (q + 1); /* the prompt string follows */

          if ('\'' == *q)
            { /* echo the prompt, then read */
              const char *p = q + 1;

              if (reading)
                { /* pass 1 (or undefined): blank line before the prompt;
                   * pass 2 must stay silent (value already cached) */
                  (void)fputc ('\n', stderr);
                  (void)fflush (stdout);
                  (void)fflush (stderr);
                }

              while ('\0' != *p && '\'' != *p)
                {
                  if (reading)
                    (void)fputc (*p, stderr);

                  p++;
                }
              if ('\'' == *p)
                { /* prompt complete on this line */
                  (void)fflush (stdout);
                  (void)fflush (stderr);

                  if (reading)
                    console_read (a, s);
                }
              else
                { /* prompt spans following lines */
                  if (reading)
                    {
                      (void)fputc ('\n', stderr);
                      a->pend_console = s;
                    }

                  a->in_prompt = 1;
                }
            }
          else if (reading)
            { /* no prompt text: just read */
              (void)fflush (stdout);
              (void)fflush (stderr);
              console_read (a, s);
            }

          if (2 == a->pass)
            print_lst (a, lc0, line);

          return;
        }

      {
        value_t v;
        const char *qq = L.operands;

        if (eval1 (a, &qq, &v))
          {
            aerr (a, line, "bad assignment");
            return;
          }

        {
          symbol *s = sym_intern (a->syms, L.label);
          s->val = v;
          s->defined = 1;                   /* claim the name so a later */
          s->seen = (unsigned char)a->pass; /* label keeps this value    */
        }

        a->lst_loc = (long)v.value;     /* listing: '=' shows the value */
        a->lst_lreloc = (0 != v.reloc); /* and the value's reloc flag   */
      }

      if (2 == a->pass)
        print_lst (a, lc0, line);

      return;
    }

  /* label (if any) already defined above.  The originals still list a
   * line with no operator: a label-only line shows its LC, while a blank
   * or comment-only line has no location and blanks the LC column. */
  if ('\0' == op[0])
    {
      if (2 == a->pass)
        {
          if ('\0' == L.label[0])
            a->lst_loc = -1;

          print_lst (a, lc0, line);
        }

      return;
    }

  if (opeq (op, ".INSERT", NULL))
    {
      if (2 == a->pass)
        { /*
           * the .INSERT directive lists with a blank LC, and
           * the inserted file's lines carry the '@' marker
           */
          a->lst_loc = -1;
          print_lst (a, lc0, line);
        }

      a->ins_depth++;
      do_insert (a, L.operands);
      a->ins_depth--;
      return;
    }
  else if (opeq (op, ".OPSYN", ".SYN") || opeq (op, ".SYSYN", ".MASYN"))
    {
      /*
       * synonym definition (.SYN/.OPSYN/.SYSYN/.MASYN: `sym1,sym2' makes sym2
       * a synonym for sym1).  The four differ only in which symbol class the
       * original searches; we resolve them all through one alias table.
       */
      char e1[NAMEBUF], e2[NAMEBUF];
      const char *q = parse_opname (L.operands, e1);
      q = skipws (q);

      if (',' == *q)
        q++;

      (void)parse_opname (q, e2);

      if ('\0' != e1[0] && '\0' != e2[0] && a->nalias < MAXALIAS)
        {
          /* alias_from/alias_to elements are each char[NAMEBUF] */
          (void)xstrlcpy (a->alias_from[a->nalias], e2, NAMEBUF);
          (void)xstrlcpy (a->alias_to[a->nalias], e1, NAMEBUF);

          a->nalias++;
        }

      a->lst_loc = -1; /* a synonym has no location: blank the LOC column */
    }
  else if (opeq (op, ".ERROR", NULL))
    { /* force a user assembly error; the line text carries the message */
      aerr (a, line, "user .ERROR");
      a->lst_loc = -1;
    }
  else if (opeq (op, ".REMARK", NULL))
    /* a remark listed in the source body; emits no bytes */
    a->lst_loc = -1;
  else if (opeq (op, ".EXIT", NULL))
    { /* terminate the current macro expansion early */
      if (a->macro_depth > 0)
        a->macro_exit = 1;

      a->lst_loc = -1;
    }
  else if (opeq (op, ".DEFINE", NULL))
    {
      do_define (a, L.operands);
      a->lst_loc = -1; /* .DEFINE has no location: blank the LOC column */
    }
  else if (opeq (op, ".BYTE", ".DB") || opeq (op, "DB", "DEFB"))
    do_data (a, line, L.operands, 1);
  else if (opeq (op, ".WORD", ".DW") || opeq (op, "DW", "DEFW"))
    do_data (a, line, L.operands, 2);
  else if (opeq (op, ".BLKB", ".DS") || opeq (op, "DS", NULL))
    do_blk (a, line, L.operands, 1);
  else if (opeq (op, ".BLKW", "DSW"))
    do_blk (a, line, L.operands, 2);
  else if (opeq (op, ".ASCII", ".DC") || opeq (op, "DC", NULL))
    do_ascii (a, line, L.operands, 0);
  else if (opeq (op, ".ASCIZ", NULL))
    do_ascii (a, line, L.operands, 1);
  else if (opeq (op, ".ASCIS", "DCS"))
    do_ascii (a, line, L.operands, 2);
  else if (opeq (op, ".DATE", NULL))
    do_datetime (a, 0);
  else if (opeq (op, ".TIME", NULL))
    do_datetime (a, 1);
  else if (opeq (op, ".RAD40", NULL))
    do_rad40 (a, line, L.operands);
  else if (opeq (op, ".LOC", "ORG") || opeq (op, ".ORG", NULL))
    {
      value_t v;
      const char *p = L.operands;

      if (eval1 (a, &p, &v))
        aerr (a, line, "bad ORG");
      else
        {
          a->lc = v.value;
          a->lc_reloc = (0 != v.reloc);
        }

      /* an explicit origin pins the program: the .PROG. object segment then
       * reports size 0 (the code is absolutely located, not relocatable) */
      a->obj_org_used = 1;
      a->lst_loc = (long)a->lc; /* listing shows the LC after ORG */
    }
  else if (opeq (op, ".RADIX", NULL))
    {
      value_t v;
      const char *p = L.operands;
      int saved = a->radix;

      a->radix = 10; /* the .RADIX argument is always read in decimal */

      if (eval1 (a, &p, &v))
        {
          aerr (a, line, "bad .RADIX");
          a->radix = saved;
        }
      else if (2 == v.value || 8 == v.value || 10 == v.value || 16 == v.value)
        a->radix = (int)v.value;
      else
        {
          aerr (a, line, "bad radix");
          a->radix = saved;
        }

      a->lst_loc = -1; /* .RADIX has no location: blank the LOC column */
    }
  else if (opeq (op, ".PABS", NULL))
    {
      a->lc_reloc = 0;
      a->obj_abs = 1; /* absolute object output (Intel-hex `:' records) */
    }
  else if (opeq (op, ".PREL", NULL))
    {
      a->lc_reloc = 1;
      a->obj_abs = 0;
    }
  else if (opeq (op, ".LINK", NULL))
    { /* emit the full link records (the default) */
      a->obj_xlink = 0;
      a->lst_ctlstmt = 1;
      a->lst_loc = -1;
    }
  else if (opeq (op, ".XLINK", NULL))
    { /* relocatable core image: suppress the !/\ link records */
      a->obj_xlink = 1;
      a->lst_ctlstmt = 1;
      a->lst_loc = -1;
    }
  else if (opeq (op, ".LIST", NULL))
    {
      a->lst_ctl |= LSTC_LIST;
      a->lst_ctlstmt = 1;
      a->lst_loc = -1;
    }
  else if (opeq (op, ".XLIST", NULL))
    {
      a->lst_ctl &= ~LSTC_LIST;
      a->lst_ctlstmt = 1;
      a->lst_loc = -1;
    }
  else if (opeq (op, ".LCTL", NULL))
    {
      a->lst_ctl |= LSTC_CTL;
      a->lst_ctlstmt = 1;
      a->lst_loc = -1;
    }
  else if (opeq (op, ".XCTL", NULL))
    {
      a->lst_ctl &= ~LSTC_CTL;
      a->lst_ctlstmt = 1;
      a->lst_loc = -1;
    }
  else if (opeq (op, ".LSYM", NULL) || opeq (op, ".PSYM", NULL))
    { /* enable the symbol-table listing (.LSYM local, .PSYM public) */
      a->lst_ctl |= LSTC_SYM;
      a->lst_ctlstmt = 1;
      a->lst_loc = -1;
    }
  else if (opeq (op, ".XSYM", NULL) || opeq (op, ".XPSYM", NULL))
    { /* suppress the symbol-table listing at .END */
      a->lst_ctl &= ~LSTC_SYM;
      a->lst_ctlstmt = 1;
      a->lst_loc = -1;
    }
  else if (opeq (op, ".LADDR", NULL))
    {
      a->lst_ctl |= LSTC_LADDR;
      a->lst_ctlstmt = 1;
      a->lst_loc = -1;
    }
  else if (opeq (op, ".XADDR", NULL))
    {
      a->lst_ctl &= ~LSTC_LADDR;
      a->lst_ctlstmt = 1;
      a->lst_loc = -1;
    }
  else if (opeq (op, ".LIMAGE", ".LIMAG"))
    {
      a->lst_ctl |= LSTC_LIMAGE;
      a->lst_ctlstmt = 1;
      a->lst_loc = -1;
    }
  else if (opeq (op, ".XIMAGE", ".XIMAG"))
    {
      a->lst_ctl &= ~LSTC_LIMAGE;
      a->lst_ctlstmt = 1;
      a->lst_loc = -1;
    }
  else if (opeq (op, ".LALL", NULL))
    { /* list all macro expansion text */
      a->lst_ctl |= LSTC_LALL;
      a->lst_ctl &= ~LSTC_SALL;
      a->lst_ctlstmt = 1;
      a->lst_loc = -1;
    }
  else if (opeq (op, ".XALL", NULL))
    { /* list only the code-generating macro lines (the default) */
      a->lst_ctl &= ~(LSTC_LALL | LSTC_SALL);
      a->lst_ctlstmt = 1;
      a->lst_loc = -1;
    }
  else if (opeq (op, ".SALL", NULL))
    { /* suppress all macro expansion text */
      a->lst_ctl |= LSTC_SALL;
      a->lst_ctl &= ~LSTC_LALL;
      a->lst_ctlstmt = 1;
      a->lst_loc = -1;
    }
  else if (opeq (op, ".SLIST", NULL))
    { /* push the listing-control flags onto the save stack.  Unlike the other
       * control statements, .SLIST lists itself whenever body listing is on
       * (it is not gated by .LCTL), so leave lst_ctlstmt clear. */
      if (a->lst_nsave < LSTC_SAVES)
        a->lst_save[a->lst_nsave++] = a->lst_ctl;

      a->lst_loc = -1;
    }
  else if (opeq (op, ".RLIST", NULL))
    { /* restore the listing-control flags from the save stack.  The .RLIST line
       * itself is listed under the PRE-restore flags (the restored flags take
       * effect with the following statement), so list it before restoring. */
      a->lst_loc = -1;

      if (2 == a->pass)
        print_lst (a, lc0, line);

      if (a->lst_nsave > 0)
        a->lst_ctl = a->lst_save[--a->lst_nsave];

      return;
    }
  else if (opeq (op, ".TITLE", NULL))
    { /*
       * capture the page subtitle (in both passes, so pass 2's page-1
       * heading already has it); the directive is not listed in the body
       */
      const char *p = skipws (L.operands);
      char quote = (('\'' == *p || '"' == *p) ? *p : '\0');
      int n = 0;

      if ('\0' != quote)
        p++;

      while ('\0' != *p && n < (int)sizeof (a->title) - 1)
        {
          if ('\0' != quote ? (*p == quote) : (';' == *p))
            break;

          a->title[n++] = *p++;
        }

      while (n > 0
             && (' ' == a->title[(long)n - 1]
                 || '\t' == a->title[(long)n - 1]))
        n--; /* trim trailing blanks (unquoted form) */

      a->title[n] = '\0';
      return; /* suppressed from the body listing */
    }
  else if (opeq (op, ".END", "END"))
    {
      const char *p = skipws (L.operands);

      a->ended = 1;
      a->lst_loc = -1; /* listing blanks the LOC column */

      if ('\0' != *p && ';' != *p) /* `.END expr' sets the module start addr */
        {
          value_t v;

          if (eval1 (a, &p, &v))
            aerr (a, line, "bad start address");
          else
            {
              a->obj_start = v.value;
              a->obj_start_rel = (0 != v.reloc);
            }
        }
    }
  else if (NULL != (mac = macro_lookup (a, op)))
    {
      /*
       * a user macro overrides a built-in mnemonic (e.g. 808macro
       * redefines JRZ/JMPR/... as the absolute 8080 jumps)
       */

      /* parenthesized arg spans lines */
      if (paren_depth_of (L.operands) > 0)
        {
          int i = 0;
          const char *o = L.operands;

          if (2 == a->pass) /* deferred expansion can't fold the call line */
            print_lst (a, lc0, line);

          (void)strncpy (a->pend_op, op, NAMEBUF - 1);
          a->pend_op[NAMEBUF - 1] = '\0';

          while (i < 1022 && '\0' != o[i] && ';' != o[i])
            {
              a->pend_args[i] = o[i];
              i++;
            }

          a->pend_len = i;
          a->pend_depth = paren_depth_of (L.operands);
          a->pending = 1;

          return;
        }

      expand_macro (a, mac, L.operands, line); /* folds the call line itself */

      return;
    }
  else
    {
      /*
       * a machine instruction (encode_insn emits it), a listing/output
       * no-op directive, or -- in pass 2 -- an unknown operator
       */

      if (!encode_insn (a, line, op, L.operands) && !is_noop_dir (op)
          && 2 == a->pass)
        aerr (a, line, "unknown operator");
    }

  if (2 == a->pass)
    print_lst (a, lc0, line);
}

/******************************************************************************/

static void
process_file (astate *a, const char *path)
{
  FILE *f;
  char buf[1024];

  f = fopen (path, "r");

  if (NULL == f)
    {
      (void)fprintf (stderr, "cannot open '%s'\n", path);
      a->errors++;
      return;
    }

  while (NULL != fgets (buf, (int)sizeof (buf), f) && !a->ended)
    {
      size_t n = strlen (buf);

      while (n > 0 && ('\n' == buf[n - 1] || '\r' == buf[n - 1]))
        {
          buf[--n] = '\0';
        }
      do_line (a, buf);
    }

  (void)fclose (f);
}

/******************************************************************************/

int
asm_source (const char *path, dialect_t dialect, const char *outpath,
            const char *lstpath, const char *relpath, const char *hexpath,
            int pad, int long_symbols)
{
  astate a;
  const char *slash, *base;
  char srcpath[1024];
  FILE *tf, *lf = NULL;

  /* zero-init without a partial-aggregate warning */
  (void)memset (&a, 0, sizeof (a));

  /* Print the dialect herald, as the originals do. */
  if (DIALECT_PASM == dialect)
    (void)fprintf (stderr, "\n%s\n",
                   "PSA Macro Assembler [C12011-0102 ] (Compatible)");
  else
    (void)fprintf (stderr, "\n%s\n",
                   "TDL Z80 CP/M DISK ASSEMBLER VERSION 2.21 (COMPATIBLE)");

  (void)fprintf (
      stderr, "%s\n",
      "Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>");

  /* Default source extension to .asm when none was given (CP/M FCB rule) */
  base = strrchr (path, '/');
  base = ((NULL != base) ? base + 1 : path);

  if (NULL == strchr (base, '.') && strlen (path) + 4 < sizeof (srcpath))
    {
      (void)xsnprintf (srcpath, sizeof (srcpath), "%s.asm", path);
    }
  else
    {
      (void)strncpy (srcpath, path, sizeof (srcpath) - 1);
      srcpath[sizeof (srcpath) - 1] = '\0';
    }

  a.syms = sym_new ();
  a.dialect = dialect;
  a.long_symbols = long_symbols;
  a.lst_page = 0;
  a.lst_line = 0;

  /*
   * Map the console pseudo-devices to the real streams, so an explicit
   * -l /dev/stderr or -l /dev/stdout does not double-report: a fresh FILE*
   * from fopen("/dev/stderr") would not compare equal to stderr.
   */

  if (NULL == lstpath || 0 == strcmp (lstpath, "/dev/stderr"))
    a.lst = stderr;
  else if (0 == strcmp (lstpath, "/dev/stdout"))
    a.lst = stdout;
  else
    {
      lf = fopen (lstpath, "w");

      if (NULL == lf)
        a.lst = stderr;
      else
        a.lst = lf;
    }

  tf = fopen (srcpath, "r"); /* check once, not once per pass */

  if (NULL == tf)
    {
      (void)fprintf (stderr, "cannot open '%s'\n", srcpath);

      if (NULL != lf)
        (void)fclose (lf);

      sym_free (a.syms);
      return 1;
    }

  (void)fclose (tf);

  a.basedir[0] = '\0';
  slash = strrchr (srcpath, '/');

  if (NULL != slash)
    {
      size_t dl = 0;
      const char *t;

      for (t = srcpath; t != slash; t++)
        dl++;

      if (dl < sizeof (a.basedir))
        {
          (void)memcpy (a.basedir, srcpath, dl);
          a.basedir[dl] = '\0';
        }
    }

  /* an image is needed for -o and for any object output (-R/-X); the emission
   * log and spans only for object output. */
  a.image = ((NULL != outpath || NULL != relpath || NULL != hexpath)
                ? (u8 *)calloc (65536UL, 1)
                : NULL);
  a.em_byte = NULL;
  a.em_rel = NULL;
  a.em_n = 0;
  a.em_cap = 0;
  a.em_pending = 0;
  a.span_a = NULL;
  a.span_n = NULL;
  a.nspans = 0;
  a.span_cap = 0;
  a.emit_prev = -1;

  if (NULL != relpath || NULL != hexpath)
    {
      a.em_cap = 8192;
      a.em_byte = (u8 *)malloc ((size_t)a.em_cap);
      a.em_rel = (u8 *)malloc ((size_t)a.em_cap);
      a.span_cap = 1024;
      a.span_a = (u16 *)malloc ((size_t)a.span_cap * sizeof (u16));
      a.span_n = (u16 *)malloc ((size_t)a.span_cap * sizeof (u16));

      if (NULL == a.em_byte || NULL == a.em_rel || NULL == a.span_a
          || NULL == a.span_n)
        { /* out of memory: degrade to no object output */
          if (NULL != a.em_byte)
            FREE (a.em_byte);

          if (NULL != a.em_rel)
            FREE (a.em_rel);

          if (NULL != a.span_a)
            FREE (a.span_a);

          if (NULL != a.span_n)
            FREE (a.span_n);

          a.em_cap = 0;
          a.span_cap = 0;
        }
    }

  a.img_any = 0;
  a.img_min = 0;
  a.img_max = 0;
  a.obj_abs = 0; /* default .PREL */
  a.obj_org_used = 0;
  a.obj_start = 0;
  a.obj_start_rel = 0;

  a.pass = 1;
  a.radix = RADIX_DEFAULT;
  a.lc = 0;
  a.lc_reloc = 1;
  a.errors = 0;
  a.ended = 0;
  a.nalias = 0;
  a.cdepth = 0;
  a.macros = NULL;
  a.defining = NULL;
  a.def_started = 0;
  a.in_prompt = 0;
  a.genctr = 0;
  a.macro_depth = 0;
  a.macro_exit = 0;
  a.scope = 0;
  a.pending = 0;
  a.pend_console = NULL;
  a.lst_ctl = LSTC_DEFAULT;
  a.lst_nsave = 0;
  a.obj_xlink = 0;

  process_file (&a, srcpath);

  a.pass = 2;
  a.radix = RADIX_DEFAULT;
  a.lc = 0;
  a.lc_reloc = 1;
  a.prog_max = 0;
  a.obj_abs = 0;
  a.obj_org_used = 0;
  a.obj_start = 0;
  a.obj_start_rel = 0;
  a.em_n = 0; /* the emission log/spans are recorded in pass 2 only */
  a.em_pending = 0;
  a.nspans = 0;
  a.emit_prev = -1;
  a.ended = 0;
  a.nalias = 0;
  a.cdepth = 0;
  a.in_prompt = 0;
  a.img_any = 0;
  a.genctr = 0;
  a.macro_depth = 0;
  a.macro_exit = 0;
  a.scope = 0;
  a.pending = 0;
  a.pend_console = NULL;
  a.lst_ctl = LSTC_DEFAULT;
  a.lst_nsave = 0;
  a.obj_xlink = 0;
  macro_free_all (&a);
  a.defining = NULL;
  a.def_started = 0;
  lst_header (&a);

  process_file (&a, srcpath);

  if (a.lst_ctl & LSTC_SYM) /* .XSYM/.XPSYM suppress the symbol-table listing */
    lst_symtab (&a);

  (void)fprintf (a.lst, "\n%d error(s)\n", a.errors);

  /* with -l to a real file, also report the count on the console */
  if (NULL != lf)
    (void)fprintf (stderr, "%d error(s)\n", a.errors);

  if (NULL != a.image)
    {
      if (a.img_any && NULL != outpath)
        {
          FILE *of = fopen (outpath, "wb");

          if (NULL != of)
            {
              long i;

              for (i = (long)a.img_min; i <= (long)a.img_max; i++)
                (void)fputc (a.image[i], of);

              if (pad) /* pad up to a 128-byte CP/M record boundary */
                {
                  long size = (long)a.img_max - (long)a.img_min + 1;
                  long full = ((size + 127) / 128) * 128;

                  for (i = size; i < full; i++)
                    (void)fputc (0x1A, of);
                }

              (void)fclose (of);
            }
        }

      /* object output (-R binary REL, -X ASCII REL); both reuse one emitter */
      if (a.img_any && (NULL != relpath || NULL != hexpath))
        {
          objspec os;

          os.em_byte = a.em_byte;
          os.em_rel = a.em_rel;
          os.span_a = a.span_a;
          os.span_n = a.span_n;
          os.nspans = a.nspans;
          /* .PROG. size = the LC high-water (segment span incl. any trailing
           * reservation).  An explicit .LOC/ORG pins the code absolutely, so
           * the segment then reports size 0, matching the originals. */
          os.prog_size = (a.obj_org_used ? 0u : a.prog_max);
          os.data_size = 0;
          os.blnk_size = 0;
          os.abs_mode = a.obj_abs;
          /* data-record base: .PROG.-relative (1) unless an explicit origin
           * pinned the code absolutely (0) */
          os.data_base = (a.obj_org_used ? 0 : 1);
          os.start = a.obj_start;
          os.start_reloc = a.obj_start_rel;
          os.emit_progid = (DIALECT_PASM == dialect);
          os.xlink = a.obj_xlink;

          if (NULL != relpath)
            {
              os.ascii = 0;

              if (0 != obj_write (relpath, &os))
                (void)fprintf (stderr, "cannot write '%s'\n", relpath);
            }

          if (NULL != hexpath)
            {
              os.ascii = 1;

              if (0 != obj_write (hexpath, &os))
                (void)fprintf (stderr, "cannot write '%s'\n", hexpath);
            }
        }

      FREE (a.image);
    }

  /*
   * on any OOM-degrade path above these were freed and
   * NULLed, so the guarded FREEs here are no-ops; old
   * cppcheck doubleFree warning is a false positive
   */

  if (NULL != a.em_byte)
    FREE (a.em_byte); /* cppcheck-suppress doubleFree */

  if (NULL != a.em_rel)
    FREE (a.em_rel); /* cppcheck-suppress doubleFree */

  if (NULL != a.span_a)
    FREE (a.span_a); /* cppcheck-suppress doubleFree */

  if (NULL != a.span_n)
    FREE (a.span_n); /* cppcheck-suppress doubleFree */

  {
    int e = a.errors;

    if (NULL != lf)
      (void)fclose (lf);

    macro_free_all (&a);
    sym_free (a.syms);

    return e;
  }
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
