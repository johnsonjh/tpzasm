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
#define LOC_STK_DEPTH 32 /* .LOC/.RELOC save-stack depth */
#define MAXTEMPS 256 /* .TEMPS local-array cap (the originals were RAM-bound) */
#define MACRO_NEST_MAX 256 /* artificial macro-expansion recursion cap: the
                            * originals were bounded only by available RAM; we
                            * impose a high but finite limit so a runaway (e.g.
                            * an unconditionally self-recursive macro) fails
                            * cleanly instead of overflowing the C stack */

/*
 * listing-control flag bits (a->lst_ctl); LSTC_DEFAULT
 * reproduces the standard listing exactly, so a source
 * that uses none of these directives is unchanged
 */

#define LSTC_LIST   0x01u /* body listing on        (.LIST / .XLIST) */
#define LSTC_CTL    0x02u /* list control stmts     (.LCTL / .XCTL) */
#define LSTC_SYM    0x04u /* symbol table at .END   (.LSYM / .XSYM) */
#define LSTC_LADDR  0x08u /* 16-bit values swapped  (.LADDR / .XADDR) */
#define LSTC_LIMAGE 0x10u /* list every data byte   (.LIMAGE / .XIMAGE) */
#define LSTC_LALL   0x20u /* list all macro text    (.LALL) */
#define LSTC_SALL   0x40u /* suppress macro text    (.SALL) */
#define LSTC_DEFAULT (LSTC_LIST | LSTC_SYM)
#define LSTC_SAVES 4 /* depth of the .SLIST/.RLIST push-down stack */

/******************************************************************************/

typedef struct
{
  int assemble;
  int if_true;
  int is_else; /* 1 if an else block (which cannot itself take another else) */
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
  int base;        /* active relocation base: 1 .PROG., 2 .DATA., 3 .BLNK. */
  u16 seg_hw[4];   /* per-base high-water (size); [1]=.PROG. [2]=.DATA. ... */
  /* .LOC/.RELOC LIFO stack of (lc, base, reloc-mode) */
  struct
  {
    u16 lc;
    int base;
    int reloc;
  } loc_stk[LOC_STK_DEPTH];
  int loc_sp;
  int next_ebase;  /* next external relocation-base number to assign (>=4) */
  int next_decl;   /* next .INTERN/.ENTRY declaration sequence number      */
  int next_defseq; /* next symbol definition-order number (for `&' .PSYM)   */
  char modname[8]; /* `!' module name (.IDENT), default ".MAIN."          */
  int errors;      /* error count of the CURRENT pass (pass-2 = the total) */
  int errs_hdr;    /* prior-pass error total, shown in the PASM page header */
  int errs_mdef;   /* multiply-defined (`M') count: drives the leading page   */
  int errs_finsert; /* nested-.INSERT (`F') count: also drives the leading pg */
  int count_only;  /* error-counting pre-pass: tally errs_hdr, list nothing   */
  int mdef_page;   /* leading-page pass: list only `M'/`F' (report) lines     */
  char lst_ec[2];  /* up to two error-code letters for this line's column 1 */
  int lst_nec;     /* number of error codes recorded for this line          */
  int lst_qoff[2]; /* per-error `?' marker offsets into the line (one each)  */
  const char *cur_line; /* the source line currently being assembled        */
  int ppos;        /* current parse offset into cur_line, for the `?' marker */
  int eval_undef;  /* the last eval failed on an undefined symbol (-> `U')   */
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
  /*
   * A conditional whose block just closed with a dangling `]' may still take an
   * else `[' that follows across only comment/blank lines (the multi-line
   * `] ... [' else form).  pend_else marks that window open; pend_else_wt is
   * the closed block's if_true (the else takes its inverse) and pend_else_outer
   * the enclosing assemble state at the close.  Any non-comment line that is
   * not the else `[' closes the window.
   */
  int pend_else;
  int pend_else_wt;
  int pend_else_outer;

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
  int obj_org_used;  /* an explicit .LOC/ORG pins the code (.PROG. size 0) */
  int obj_xlink;     /* .XLINK: suppress the !/\\ link records (`;' only)  */
  int obj_psym;      /* .PSYM: append the `&' symbol-table record(s)        */
  int i8080_mode;    /* .I8080: flag a Z80 instruction with the `Z' warning */
  int idx_pfx;       /* an index (IX/IY) prefix was emitted this insn       */
  value_t temps[MAXTEMPS]; /* .TEMPS local array, referenced as `![sub]'    */
  int ntemps;        /* number of .TEMPS elements currently allocated       */
  int mac_argc;      /* `&': arg count of the macro invocation being expanded */
  u16 obj_start;     /* start address from `.END expr' (0 if none) */
  int obj_start_rel; /* relocation base of the start address */

  /*
   * object output records the emitted byte stream in EMISSION order
   * (not ascending address order): the originals write a record at
   * each .LOC/ORG address discontinuity, so a program that revisits
   * an earlier region (e.g. SARGON) interleaves records AND preserves
   * each byte's emission-time value even when a later store overwrites
   * that address.  em_byte[k]/em_rel[k] are the k-th emitted byte and
   * its REL_* class; spans group consecutive emitted bytes into
   * contiguous-address runs.
   */

  u8 *em_byte;      /* emitted byte values, emission order (NULL=no record) */
  u8 *em_rel;       /* REL_ABS/REL_LO/REL_HI per emitted byte */
  u8 *em_tbase;     /* target relocation base of each REL_LO 16-bit datum */
  long em_n;        /* number of emitted bytes recorded */
  long em_cap;
  int em_pending;   /* emit_word: 2 -> next byte REL_LO, then 1 -> REL_HI */
  int em_pend_base; /* target base of the reloc16 emit_word is emitting */
  u16 *span_a;      /* span start addresses */
  u16 *span_n;      /* span lengths */
  u8 *span_seg;     /* active relocation base per span */
  int nspans;
  int span_cap;
  long emit_prev;   /* last address emitted this pass, or -1 */

  /* listing output stream (stderr, or the -l file) */
  FILE *lst;

  /* .TITLE text for the page subtitle (captured in pass 1) */
  char title[64];

  /* macro support */
  unsigned genctr; /* counter for %-generated local labels */
  int macro_depth; /* recursion guard */
  int macro_exit;  /* .EXIT: terminate the current expansion*/
  unsigned scope;  /* local-symbol scope ('..' labels) */

  /* macro call whose parenthesized argument spans several lines */
  int pending;
  int pend_depth;
  int pend_len;
  char pend_op[NAMEBUF];
  char pend_args[1024];
  u16 lc_stmt; /* statement-start LC, for '.' in operands */

  /* listing format (TDL ZASM vs PSA PASM) */
  dialect_t dialect; /* selects the TDL vs PSA listing layout */
  unsigned lst_ctl;  /* listing-control flags (LSTC_*) */
  unsigned lst_save[LSTC_SAVES]; /* .SLIST push-down stack */
  int lst_nsave; /* number of saved entries on that stack */
  int lst_ctlstmt; /* this line is a listing-control statement */
  int lst_kind; /* this line: 0 insn, 1 data bytes, 2 words */
  int lst_opw; /* insn operand width (0/1/2) for value-form */
  long lst_loc; /* LOC-column value: -1 blank, -2 use lc0 */
  long lst_line; /* listing line counter, for pagination */
  int lst_page; /* current listing page number */
  int lst_pagelen; /* lines per page (PASM `.PAGE width,length' 2nd arg); the
                    * width->wrap (1st arg) is not yet implemented */
  int lst_lbase; /* LC relocation base: -1 derive from lc_reloc/base, else # */
  int lst_obase; /* 16-bit insn operand relocation base (0 abs, 1/2/3/ext) */
  u8 wreloc[32]; /* per-.WORD-value relocation base (0 abs, 1/2/3/ext) */

  /*
   * .LIMAGE multi-line byte image: source-line offsets at which the source
   * splits across physical lines (recorded as data is parsed; the source runs
   * one value ahead of the 6-byte / per-word image it sits beside)
   */
  int limg_split[68];
  int limg_ns;

  /*
   * macro-expansion listing: the originals fold the body into
   * the call line and flag continued statements with '+'
   */

  const char *mac_src; /* override source text for this listing line, or NULL */
  int mac_plus; /* place the '+' macro-continuation marker */
  int mac_active; /* inside the outermost macro expansion's listing */
  int lst_suppress; /* assemble a line but emit no listing output */
  /*
   * .SALL macro-collapse: the whole expansion lists as ONE bare call line that
   * carries the first emitting statement's LC + value-form bytes.  sall_call is
   * that call line's source text while a .SALL expansion is in flight (else
   * NULL); sall_done marks the call line already emitted (by the first emitter,
   * possibly deep in a nested macro).  See print_lst and expand_macro.
   */
  const char *sall_call;
  int sall_done;
  int ins_depth; /* .INSERT nesting: inserted lines carry the '@' mark */
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
{ /* symbols use only the Radix-40 set (A-Z 0-9 $ % .); _ ? @ are NOT in it */
  return isalnum (c) || '.' == c || '$' == c || '%' == c;
}

/******************************************************************************/

/*
 * Append one emitted byte (value v, at the current LC) to the object
 * emission log and its containing span.  The byte's REL_* class comes
 * from the pending reloc16 marker that emit_word sets.  Buffers grow on
 * demand; an allocation failure simply drops the record (object output
 * then degrades, never crashes).
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
  else if (3 == a->em_pending)
    {
      cls = REL_EXT8; /* single 8-bit byte relative to an external base */
      a->em_pending = 0;
    }

  if (a->em_n >= a->em_cap) /* grow the emission buffers */
    {
      long nc = a->em_cap * 2;
      u8 *nb = (u8 *)realloc (a->em_byte, (size_t)nc);
      u8 *nr = (u8 *)realloc (a->em_rel, (size_t)nc);
      u8 *nt = (u8 *)realloc (a->em_tbase, (size_t)nc);

      if (NULL != nb)
        a->em_byte = nb;

      if (NULL != nr)
        a->em_rel = nr;

      if (NULL != nt)
        a->em_tbase = nt;

      if (NULL != nb && NULL != nr && NULL != nt)
        a->em_cap = nc;
    }

  if (a->em_n >= a->em_cap)
    return; /* out of memory */

  a->em_byte[a->em_n] = v;
  a->em_rel[a->em_n] = cls;
  /* the target base rides with the low byte of a relocatable datum */
  a->em_tbase[a->em_n]
      = (u8)((REL_LO == cls || REL_EXT8 == cls) ? a->em_pend_base : 0);
  a->em_n++;

  /* span: extend the current run, or open a new one at an address gap OR
   * an active-base change (each ';' record carries a single base; absolute
   * code is base 0, relocatable code its active segment 1/2/3). */
  {
  u8 seg = (u8)(a->lc_reloc ? a->base : 0);
  if (a->nspans > 0 && a->emit_prev >= 0 && (long)a->lc == a->emit_prev + 1
      && a->span_seg[(long)a->nspans - 1] == seg)
    a->span_n[(long)a->nspans - 1]++;
  else
    {
      if (a->nspans >= a->span_cap) /* grow the span arrays */
        {
          int sc = a->span_cap * 2;
          u16 *na = (u16 *)realloc (a->span_a, (size_t)sc * sizeof (u16));
          u16 *nn = (u16 *)realloc (a->span_n, (size_t)sc * sizeof (u16));
          u8 *ng = (u8 *)realloc (a->span_seg, (size_t)sc * sizeof (u8));

          if (NULL != na)
            a->span_a = na;

          if (NULL != nn)
            a->span_n = nn;

          if (NULL != ng)
            a->span_seg = ng;

          if (NULL != na && NULL != nn && NULL != ng)
            a->span_cap = sc;
        }

      if (a->nspans < a->span_cap)
        {
          a->span_a[a->nspans] = a->lc;
          a->span_n[a->nspans] = 1;
          a->span_seg[a->nspans] = seg;
          a->nspans++;
        }
    }
  }

  a->emit_prev = (long)a->lc;
}

/******************************************************************************/

static void
emit (astate *a, u16 v)
{
  /* the per-line byte buffer feeds the listing; the leading multiply-defined
   * report page (mdef_page) needs it too, but emits no object/image */
  if ((2 == a->pass || a->mdef_page) && a->nbytes < (int)sizeof (a->bytes))
    a->bytes[a->nbytes++] = (u8)(v & 0xFFu);

  if (2 == a->pass)
    {
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

  if (a->lc > a->seg_hw[a->base])
    a->seg_hw[a->base] = a->lc;
}

/******************************************************************************/

/*
 * Emit a 16-bit value; when `reloc' is set, flag its two bytes in the
 * emission log so the object emitter encodes a .PROG.-relative 16-bit
 * datum.  The bytes are stored little-endian (Z80 order), as the listing
 * already shows.
 */

static void
emit_word (astate *a, u16 v, int reloc, int base)
{
  if (2 == a->pass && NULL != a->em_byte)
    {
      a->em_pending = (reloc ? 2 : 0);
      a->em_pend_base = (reloc ? base : 0);
    }

  emit (a, (u16)(v & 0xFFu));
  emit (a, (u16)(v >> 8));
}

/******************************************************************************/

static void aerr (astate *a, const char *line, const char *msg); /* forward */

/*
 * Emit one 8-bit operand byte.  An external reference produces a `111' control
 * code (base# + 8-bit value, range -128..255); 8-bit relocation relative to a
 * program segment (1/2/3) is illegal in the dialect and is rejected.
 */

static void
emit_imm8 (astate *a, const char *line, const value_t *v)
{
  if (NULL != v->ext)
    {
      int sv = ((v->value < 0x8000) ? (int)v->value : (int)v->value - 0x10000);

      if (DIALECT_ZASM == a->dialect)
        { /*
           * TDL/ZASM has no 8-bit external relocation (Relocation error); the
           * originals emit the value as an absolute placeholder byte.  PASM
           * does support it (the `111' control code below).
           */
          aerr (a, line, "8-bit external illegal");
          emit (a, (u16)(v->value & 0xFFu));
          return;
        }

      if (sv < -128 || sv > 255)
        aerr (a, line, "8-bit external out of range");

      if (2 == a->pass && NULL != a->em_byte)
        {
          a->em_pending = 3;
          a->em_pend_base = v->base;
        }

      emit (a, (u16)(v->value & 0xFFu));
    }
  else
    {
      if (0 != v->reloc)
        aerr (a, line, "8-bit relocation illegal");

      emit (a, v->value);
    }
}

/******************************************************************************/

/*
 * The originals flag an error with a single letter in listing column 1 (the
 * first two per statement) -- map each diagnostic to its Appendix-C letter.
 * Most operand/argument faults are the broad "A" (argument) class; the rest
 * carry their specific code.
 */

static char
err_letter (const char *msg)
{
  static const struct
  {
    const char *msg;
    char code;
  } map[] = { { "unknown operator", 'O' },
              { "user .ERROR", '*' },
              { "phase error", 'P' },
              { "multiply-defined symbol", 'M' },
              { "8-bit relocation illegal", 'R' },
              { "8-bit external out of range", 'R' },
              { "8-bit external illegal", 'R' },
              { "size must be absolute", 'R' },
              { "z80 instruction in 8080 mode", 'Z' },
              { "nested .INSERT", 'F' },
              { "multiply-defined reference", 'D' },
              { "subscript", 'S' },
              { "extra operand", 'Q' },
              { NULL, 0 } };
  int i;

  for (i = 0; NULL != map[i].msg; i++)
    if (0 == strcmp (msg, map[i].msg))
      return map[i].code;

  return 'A'; /* "argument error": the broad class for operand faults */
}

/******************************************************************************/

static void
aerr (astate *a, const char *line, const char *msg)
{
  if (a->count_only)
    { /*
       * the error-counting pre-pass: tally the total the PASM page header
       * needs (it must be known before the body listing, but an undefined
       * symbol is only detectable once the symbols are all defined).  Also
       * count multiply-defined errors, which get a leading report page.
       */
      a->errs_hdr++;

      /* `M' (multiply-defined) and `F' (nested .INSERT) both get reproduced
       * on the leading report page; tally each so its pass runs only when
       * such an error exists */
      {
        char ec = err_letter (msg);

        if ('M' == ec)
          a->errs_mdef++;
        else if ('F' == ec)
          a->errs_finsert++;
      }

      return;
    }

  if (2 == a->pass || a->mdef_page)
    {
      char code = ((a->eval_undef) ? 'U' : err_letter (msg));

      if (2 == a->pass) /* stderr + the reported total: the body pass only */
        {
          (void)fprintf (stderr, "  *** %c %s: %s\n", code, msg, line);
          a->errors++;
        }

      if (a->lst_nec < 2) /* the listing shows the first two codes per line */
        { /* each error places a `?' at its own parse position (two errors at
           * the same spot therefore render as `??') */
          a->lst_qoff[a->lst_nec] = a->ppos;
          a->lst_ec[a->lst_nec] = code;
          a->lst_nec++;
        }
    }
  /* pass 1 just defines symbols; the header total comes from the count pass */
}

/******************************************************************************/

/*
 * Offset of `p' within the line starting at `base', counted (not subtracted)
 * and clamped so the result provably fits an int -- the originals' lint
 * rejects a ptrdiff_t-to-int conversion.  Used for the `?' error-marker column.
 */

static int
line_off (const char *base, const char *p)
{
  const char *q;
  int n = 0;

  if (NULL == base || NULL == p)
    return 0;

  for (q = base; q != p && n < 4096; q++)
    n++;

  return n;
}

/******************************************************************************/

/* evaluate one expression at *pp, advancing it; pass 1 tolerates undefined */
static int
eval1 (astate *a, const char **pp, value_t *v)
{
  eval_env env;
  const char *endp, *err, *mdefp;
  int rc;

  env.radix = a->radix;
  env.syms = a->syms;
  env.lc = a->lc_stmt;
  env.lc_reloc = a->lc_reloc;
  env.lc_base = a->base;
  env.seg_hw = a->seg_hw; /* live per-segment high-water for .PROG./.DATA. */
  env.undef0 = (1 == a->pass);
  env.scope = a->scope;
  env.ext_next = &a->next_ebase; /* the `SYM#' modifier auto-declares externs */
  env.ext_decl = &a->next_decl;
  /* `![sub]' .TEMPS locals are a PASM feature (temps non-NULL => PASM), legal
   * only inside a macro expansion (tmp_ok); ZASM leaves temps NULL so a `!['
   * there is just the OR operator hitting a bad primary */
  env.temps = ((DIALECT_PASM == a->dialect) ? a->temps : NULL);
  env.ntemps = a->ntemps;
  env.tmp_ok = (a->macro_depth > 0);
  env.mac_argc = a->mac_argc; /* `&' = current macro's argument count */
  rc = expr_eval2 (*pp, &env, v, &endp, &err, &mdefp);

  if (rc)
    { /*
       * keep the partial value expr_eval2 computed (the originals emit it on a
       * bad expression, e.g. `1+' lists as 0001), but drop any relocation so a
       * faulted expression contributes an absolute datum.
       */
      v->reloc = 0;
      v->base = 0;
      v->ext = NULL;
    }

  *pp = endp;

  /* track the parse position for the `?' error marker (offset into the line) */
  a->ppos = line_off (a->cur_line, endp);

  /* an undefined-symbol fault is the 'U' code, not the generic 'A' */
  a->eval_undef = (rc && NULL != err && NULL != strstr (err, "undefined"));

  /*
   * a reference to a multiply-defined symbol is the `D' code, with a `?' just
   * past the symbol (`JMP FOO?', `.WORD FOO?+1').  The first definition's value
   * is still emitted, so this rides alongside the value rather than failing the
   * evaluation -- and may stack with another code (e.g. an 8-bit-reloc `R' on
   * `MVI A,FOO' -> `DR' / `FOO??').  Raise it BEFORE returning so it precedes
   * any code the caller adds, then restore the parse position for that caller.
   */
  if (NULL != mdefp)
    {
      int endp_ppos = a->ppos;

      a->ppos = line_off (a->cur_line, mdefp);
      aerr (a, a->cur_line, "multiply-defined reference");
      a->ppos = endp_ppos;
    }

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
parse_rp (astate *a, const char **pp, int psw, int *pfx)
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

  if (0 != *pfx) /* an IX/IY register pair: an index-prefix instruction */
    a->idx_pfx = 1;

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

  a->idx_pfx = 1; /* index (IX/IY) addressing: an index-prefix instruction */

  p = skipws (p + 1);

  if (')' != *p)
    return -1;

  *pp = p + 1;
  *reg = 6;

  return 0;
}

/******************************************************************************/

/*
 * Encode one machine instruction.  Returns 1 if `mnem`
 * (uppercase) is an instruction, 0 otherwise.  Always emits
 * the instruction's full size so the location counter stays
 * consistent across passes even on operand errors.
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

/* A bare register-name token (for the extra-operand `A' vs `AQ' distinction):
 * the token is exactly a register mnemonic, not the start of a longer name. */
static int
is_reg_token (const char *t)
{
  char w[4];
  int n = 0;

  while (n < 3 && isalpha ((unsigned char)t[n]))
    {
      w[n] = (char)toupper ((unsigned char)t[n]);
      n++;
    }

  w[n] = '\0';

  if (idchar ((unsigned char)t[n])) /* a longer token: not a bare register */
    return 0;

  if (1 == n)
    return (NULL != strchr ("ABCDEHLMXY", w[0]));

  return (0 == strcmp (w, "SP") || 0 == strcmp (w, "PSW"));
}

/*
 * Flag a trailing (extra) operand the originals reject (manual Appendix C),
 * after an instruction's expected operands have parsed cleanly:
 *   - a no-operand instruction with any operand     -> `Q' at the operand
 *   - an extra `,operand' after the operand list    -> `Q' before the comma
 *   - a space-separated trailing register            -> `A' after the token
 *   - a space-separated trailing number/expression   -> `A'+`Q' (`??') at it
 * Each error places its own `?', so the two-error cases render `??'.
 */
static void
flag_extra_operand (astate *a, const char *line, const insn *in,
                    const char *ops, const char *p)
{
  const char *t;

  if (a->lst_nec > 0) /* the operand parse already raised an error: leave it */
    return;

  if (FMT_NONE == in->fmt) /* a no-operand instruction */
    {
      t = skipws (ops);

      if ('\0' != *t && ';' != *t)
        {
          a->ppos = line_off (line, t);
          aerr (a, line, "extra operand"); /* Q */
        }

      return;
    }

  if (',' == *p) /* an extra `,operand' in the list */
    {
      a->ppos = line_off (line, p);
      aerr (a, line, "extra operand"); /* Q */
      return;
    }

  t = skipws (p);

  if ('\0' == *t || ';' == *t)
    return; /* nothing trailing */

  if (is_reg_token (t)) /* a trailing register: `A', marked after the token */
    {
      const char *e = t;

      while (isalpha ((unsigned char)*e))
        e++;

      a->ppos = line_off (line, e);
      aerr (a, line, "extra argument"); /* A (default) */
    }
  else /* a trailing number/expression: `A'+`Q', both before it (`??') */
    {
      a->ppos = line_off (line, t);
      aerr (a, line, "extra argument"); /* A */
      aerr (a, line, "extra operand"); /* Q (same position -> `??') */
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

  a->idx_pfx = 0; /* set if an IX/IY operand emits a DD/FD prefix this insn */

  if (a->i8080_mode && insn_is_z80 (in))
    { /*
       * .I8080 mode: a Z80-extension mnemonic raises the `Z' warning (the
       * instruction is still assembled).  The `?' marks the operand field --
       * the start of the operands, or the end of the line when there are none.
       */
      a->ppos = line_off (line, ops);
      aerr (a, line, "z80 instruction in 8080 mode");
    }

  a->lst_opw = fmt_opw (in->fmt); /* for the value-form listing byte column */
  v.reloc = 0; /* default if no 16-bit operand is evaluated */
  v.base = 0;

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

        emit_imm8 (a, line, &v);
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
        int pfx, rp = parse_rp (a, &p, 0, &pfx);

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
        int pfx, rp = parse_rp (a, &p, 1, &pfx);
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
        int pfx, rp = parse_rp (a, &p, 0, &pfx);
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
        int pfx, rp = parse_rp (a, &p, 0, &pfx);
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

        emit_word (a, v.value, 0 != v.reloc, v.base);
        break;
      }

    case FMT_IMM8:
      emit (a, in->opcode);

      if (eval1 (a, &p, &v))
        aerr (a, line, "bad immediate");

      emit_imm8 (a, line, &v);
      break;

    case FMT_ADDR:
      emit (a, in->opcode);

      if (eval1 (a, &p, &v))
        aerr (a, line, "bad address");

      emit_word (a, v.value, 0 != v.reloc, v.base);
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

      emit_word (a, v.value, 0 != v.reloc, v.base);
      break;

    case FMT_EDHL:
      {
        int pfx, rp = parse_rp (a, &p, 0, &pfx);
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
        p = q + n; /* advance past the register so the trailing-operand check
                    * (flag_extra_operand) does not see it as an extra */
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

        emit_word (a, v.value, 0 != v.reloc, v.base);
        break;
      }

    default:
      return 0;
    }

  /*
   * record the operand's relocation base for the value column.  A 16-bit
   * operand may relocate to any base.  PSA shows an 8-bit RELOCATABLE operand
   * spaced off with its base flag too -- a segment byte `3E 00'' / `3E 00"''
   * (an illegal truncation, also flagged `R') or an external byte `3E 00:NN''
   * -- whereas TDL packs it (`3E00'').  A relative-jump displacement
   * (JMPR/JRx/DJNZ, FMT_REL) is an absolute offset even when its target is
   * relocatable, so it carries no flag (except the pre-existing external edge).
   */
  a->lst_obase
      = ((2 == a->lst_opw && 0 != v.reloc)
             ? (int)v.base
             : ((1 == a->lst_opw && DIALECT_PASM == a->dialect
                 && (v.base >= 4 || (0 != v.reloc && FMT_REL != in->fmt)))
                    ? (int)v.base
                    : 0));

  if (a->i8080_mode && a->idx_pfx && !insn_is_z80 (in))
    { /*
       * an index-register OPERAND (IX/IY) on an otherwise-8080 mnemonic --
       * e.g. PUSH X -- is a Z80 instruction too.  (When the mnemonic itself
       * is a Z80 extension we already warned at the top.)  The `?' here marks
       * the end of the parsed operand.
       */
      a->ppos = line_off (line, p);
      aerr (a, line, "z80 instruction in 8080 mode");
    }

  flag_extra_operand (a, line, in, ops, p);

  return 1;
}

/******************************************************************************/

/* ---- pseudo-ops ---------------------------------------------------- */

/*
 * .LIMAGE bookkeeping: when the byte image of a data statement crosses a
 * `cap'-byte line boundary, record the source offset just past the value that
 * pushed it over (so the listed source runs one value ahead of its bytes).
 * `p' is the current parse pointer into `line'; cap is 6 for bytes/strings or
 * the per-line word capacity for .WORD.
 */

static void
limg_rec (astate *a, const char *line, const char *p, int cap)
{
  if (2 == a->pass && (a->lst_ctl & LSTC_LIMAGE))
    while (a->nbytes > (a->limg_ns + 1) * cap
           && a->limg_ns < (int)(sizeof (a->limg_split) / sizeof (int)))
      a->limg_split[a->limg_ns++] = line_off (line, p);
}

/******************************************************************************/

static void
do_data (astate *a, const char *line, const char *p, int width)
{
  a->lst_kind = ((2 == width) ? 2 : 1); /* listing: words vs bytes */
  a->limg_ns = 0;
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
            a->wreloc[a->nbytes / 2] = (u8)(0 != v.reloc ? v.base : 0);

          if (2 == width)
            emit_word (a, v.value, 0 != v.reloc, v.base);
          else
            emit_imm8 (a, line, &v);
        }

      /* .LIMAGE: record where the source splits across the byte image */
      limg_rec (a, line, p,
                ((2 == width) ? ((DIALECT_PASM == a->dialect) ? 2 : 4) : 6));

      p = skipws (p);

      if (',' == *p)
        p++;
      else if ('\0' != *p && ';' != *p)
        { /*
           * a space-separated trailing operand (no comma): the originals stop
           * here and flag it `AA' (two argument errors, so a `??' marker); the
           * already-emitted items stand.
           */
          a->ppos = line_off (line, p);
          aerr (a, line, "extra argument"); /* `AA': two argument errors at */
          aerr (a, line, "extra argument"); /* the same spot -> a `??' marker */
          break;
        }

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

  if (a->lc > a->seg_hw[a->base])
    a->seg_hw[a->base] = a->lc;
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
  a->limg_ns = 0;

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
              limg_rec (a, line, p, 6); /* .LIMAGE: split per six bytes */
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
          emit_imm8 (a, line, &v);
          started = 1;
          p = q;
          limg_rec (a, line, p, 6);
        }
      else
        { /* bare byte expression */
          value_t v;

          if (eval1 (a, &p, &v))
            aerr (a, line, "bad expression");

          last_lc = a->lc;
          emit_imm8 (a, line, &v);
          started = 1;
          limg_rec (a, line, p, 6);
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
 * .DATE / .TIME : emit an 8-byte ASCII date ("MM/DD/YY") or time
 * ("HH:MM:SS") string at the current location.  The PSA original
 * generates 8 spaces on a host with no clock; we always have one,
 * so we format the real date/time. For reproducible builds and
 * tests we honor SOURCE_DATE_EPOCH.
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
          tmv = gmtime (&t);
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
 * Radix-40 character value, or -1 if the character is not encodable.
 * The PSA set is  ' '=0, '0'-'9'=1-10, 'A'-'Z'=11-36, '$'=37, '%'=38, '.'=39.
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
 * 1600/40/1); at most six characters are used (extra encodable characters
 * are ignored), and a non-encodable character ends the symbol with an error.
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
 * NOTE: .PRGEND (= .PRGEN) is NOT here: it is "library file generation",
 * ending the current module like .END and then beginning a fresh, fully
 * independent module in the same object file.  do_line handles it as a module
 * terminator (like .END); the driver assembles each module as its own two-pass
 * unit so forward references resolve within their module and emits one object
 * record framing per module.
 */

static int
is_noop_dir (const char *op)
{
  static const char *list[]
      = { ".PHEX",   ".PBIN",    ".TITLE",   ".SBTTL", ".SUBTTL", ".REQUEST",
          ".NAME",   "PUBLIC",   ".PUBLIC",  ".PRNTX",
          ".PRINTX", "COMMON",   ".COMMON",  NULL };
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

  while (isalnum ((unsigned char)*p) || '.' == *p || '$' == *p || '%' == *p)
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
 * The originals store pseudo-op names in a six-character-significant table,
 * so a directive whose documented spelling is longer than six characters is
 * also recognized by its first six (e.g. `.DEFIN' == `.DEFINE').  Rewrite
 * such a dot-directive in place to its canonical full name.  Only directives
 * whose canonical spelling exceeds six characters need an entry; the
 * six-character prefixes here are unambiguous, so this never over-matches
 * a distinct op.
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

/*
 * Given S pointing just past a block-opening `[', return the matching `]'
 * (tracking nested brackets) when it lies on this line -- the single-line
 * inline conditional form `.IFx cond,[stmt][else]' -- or NULL when the `['
 * ends the line (the multi-line form, whose body is on the following lines).
 */

static const char *
inline_block_end (const char *s)
{
  int depth = 1;

  for (; '\0' != *s; s++)
    {
      if ('[' == *s)
        depth++;
      else if (']' == *s)
        {
          depth--;

          if (0 == depth)
            return s;
        }
    }

  return NULL;
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
 * Render the byte column the way the originals do: opcode bytes in order,
 * an 8-bit operand concatenated onto them, a 16-bit operand/word as a
 * spaced value field (little-endian bytes shown big-endian), and data
 * as a byte stream.
 */

/*
 * Listing relocation-base flag: .PROG. = ', .DATA. = " (PSA) / * (TDL),
 * .BLNK. = :03, and any external base = :NN (its two-digit base number).
 * Absolute (base 0) has no flag.  Returns a pointer to a static or literal
 * string (single use per call -- the :NN form shares one buffer).
 */

static const char *
seg_flag (int base, dialect_t dialect)
{
  static char buf[8];

  if (base <= 0)
    return "";

  if (1 == base)
    return "'";

  if (2 == base)
    return ((DIALECT_PASM == dialect) ? "\"" : "*");

  (void)xsnprintf (buf, sizeof (buf), ":%02X", base);

  return buf;
}

/******************************************************************************/

static void
lst_bytes (const astate *a, char *col, size_t cap)
{
  int cn = 0, i;

  if (2 == a->lst_kind)
    { /* .WORD: value words + reloc.  TDL shows at most two words; PSA one. */
      int maxw = ((DIALECT_PASM == a->dialect) ? 2 : 4);

      for (i = 0; i + 1 < a->nbytes && i < maxw; i += 2)
        {
          int wb = a->wreloc[i / 2];
          const char *fl = ((wb > 0) ? seg_flag (wb, a->dialect) : " ");
          /*
           * .XADDR (default) shows the 16-bit value; .LADDR shows the bytes in
           * generated (memory) order -- least significant byte first.
           */
          unsigned shown
              = ((a->lst_ctl & LSTC_LADDR)
                     ? (unsigned)((a->bytes[i] << 8) | a->bytes[(long)i + 1])
                     : (unsigned)(a->bytes[i] | (a->bytes[(long)i + 1] << 8)));
          cn += xsnprintf (col + cn, cap - (size_t)cn, "%s%04X%s",
                           (i ? "   " : ""), shown, fl);
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
          if (a->lst_obase > 0) /* 8-bit external: space + byte + base flag */
            cn += xsnprintf (col + cn, cap - (size_t)cn, " %02X%s",
                             (unsigned)a->bytes[nop],
                             seg_flag (a->lst_obase, a->dialect));
          else
            cn += xsnprintf (col + cn, cap - (size_t)cn, "%02X",
                             (unsigned)a->bytes[nop]);
        }
      else if (2 == a->lst_opw && nop + 1 < a->nbytes)
        {
          if (a->lst_ctl & LSTC_LADDR)
            /* .LADDR: the operand's bytes in load (memory) order, packed onto
             * the opcode (CALL 784C -> CD4C78), as the originals list them */
            cn += xsnprintf (
                col + cn, cap - (size_t)cn, "%04X%s",
                (unsigned)((a->bytes[nop] << 8) | a->bytes[(long)nop + 1]),
                seg_flag (a->lst_obase, a->dialect));
          else /* .XADDR (default): the 16-bit value, spaced off the opcode */
            cn += xsnprintf (
                col + cn, cap - (size_t)cn, " %04X%s",
                (unsigned)(a->bytes[nop] | (a->bytes[(long)nop + 1] << 8)),
                seg_flag (a->lst_obase, a->dialect));
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
    { /*
       * end this physical line and start an indented continuation; the
       * originals paginate physical lines, so a continuation that lands on a
       * full page is preceded by a form-feed and heading (a mid-line break)
       */
      int k;

      (void)fputc ('\n', a->lst);
      a->lst_line++;

      if (a->lst_line >= a->lst_pagelen)
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
lst_source (astate *a, const char *s, int col, int wrapw, int indent,
            const int *qoff, int nq)
{
  int si = 0; /* source character index, for the `?' error marker */
  int k;

  for (; '\0' != *s; s++, si++)
    {
      for (k = 0; k < nq; k++) /* a `?' just before each error's position */
        if (si == qoff[k])
          {
            col = lst_wrap (a, col, wrapw, indent);
            (void)fputc ('?', a->lst);
            col++;
          }

      if ('\t' == *s)
        { /*
           * tab stops are 8 columns apart measured FROM the source-field
           * start (`indent'), not from absolute column 0: ZASM's source
           * column (24) is a multiple of 8 so the two coincide, but PASM's
           * (25) is not, and its operands sit one column further right.
           */
          int first = 1;

          do
            {
              int before = col;

              col = lst_wrap (a, col, wrapw, indent);

              /*
               * a tab that crosses the fold MID-expansion is consumed by the
               * fold (the next char starts at the indent); but a tab that
               * begins exactly at the fold folds first, then expands a full
               * tab in on the continuation -- so only break after the first
               * space has been placed.
               */
              if (col != before && !first)
                break;

              first = 0;
              (void)fputc (' ', a->lst);
              col++;
            }
          while (0 != ((col - indent) % 8));
        }
      else
        {
          col = lst_wrap (a, col, wrapw, indent);
          (void)fputc (*s, a->lst);
          col++;
        }
    }

  for (k = 0; k < nq; k++) /* error(s) at the end of the statement text */
    if (si == qoff[k])
      {
        col = lst_wrap (a, col, wrapw, indent);
        (void)fputc ('?', a->lst);
        col++;
      }

  (void)fputc ('\n', a->lst);
  a->lst_line++; /* count this final physical line */
}

/******************************************************************************/

/*
 * .LIMAGE multi-line byte image: list EVERY byte of a data statement, six per
 * line (one word per line for .WORD under PASM), splitting the source across
 * the lines with a `\' continuation marker.  The split offsets were recorded
 * while the data was parsed; the source runs one value ahead of its bytes.
 */

static void
lst_limage (astate *a, u16 lc0, const char *rawline)
{
  int bw = ((DIALECT_PASM == a->dialect) ? 14 : 13);
  int word = (2 == a->lst_kind);
  int cap = (word ? ((DIALECT_PASM == a->dialect) ? 2 : 4) : 6);
  int nlines = a->limg_ns + 1;
  int srclen = (int)strlen (rawline);
  int lbase
      = ((a->lst_lbase >= 0) ? a->lst_lbase : (a->lc_reloc ? a->base : 0));
  const char *lfl = ((lbase > 0) ? seg_flag (lbase, a->dialect) : " ");
  int k;

  for (k = 0; k < nlines; k++)
    {
      long loc = ((long)lc0 + (long)k * cap) & 0xFFFF;
      int b0 = k * cap;
      long bend = (long)b0 + cap; /* widen the sum (op +) to a long */
      int b1 = (int)((bend < a->nbytes) ? bend : a->nbytes);
      int so = ((0 == k) ? 0 : a->limg_split[(long)k - 1]);
      int se = ((k == a->limg_ns) ? srclen : a->limg_split[k]);
      char bf[40];
      int bn = 0, i, col, indent;
      /* TDL lays a multi-word .WORD line's value field over the first two
       * source columns (each word in an 8-column slot); PSA shows one word per
       * line, so it never reaches two words and never overstrikes. */
      int over = (word && DIALECT_PASM != a->dialect && (b1 - b0) >= 4);

      if (a->lst_line >= a->lst_pagelen) /* page full */
        {
          (void)fputc ('\f', a->lst);
          lst_header (a);
        }

      /* the byte (or word) image for this physical line */
      if (word)
        {
          for (i = b0; i < b1 && (i + 1) < a->nbytes
                       && (i + 1) < (int)sizeof (a->bytes);
               i += 2)
            {
              int wi = i / 2;
              int wf = ((wi < (int)sizeof (a->wreloc)) ? a->wreloc[wi] : 0);
              unsigned wv
                  = (unsigned)(a->bytes[i] | (a->bytes[(long)i + 1] << 8));

              if (over) /* each word in an 8-column slot */
                {
                  bn += xsnprintf (bf + bn, sizeof (bf) - (size_t)bn, "%04X%s",
                                   wv,
                                   ((wf > 0) ? seg_flag (wf, a->dialect) : ""));

                  while (bn < 8 && (i + 2) < b1) /* pad all but the last word */
                    bf[bn++] = ' ';
                }
              else
                bn += xsnprintf (bf + bn, sizeof (bf) - (size_t)bn, "%s%04X%s",
                                 ((i > b0) ? "   " : ""), wv,
                                 ((wf > 0) ? seg_flag (wf, a->dialect) : ""));
            }
        }
      else
        {
          for (i = b0; i < b1 && i < (int)sizeof (a->bytes); i++)
            bn += xsnprintf (bf + bn, sizeof (bf) - (size_t)bn, "%02X",
                             (unsigned)a->bytes[i]);
        }

      bf[bn] = '\0';
      indent = 11 + bw;

      if (over)
        { /*
           * the un-padded word field, then pad to the source column two past
           * the normal indent: the value field overstrikes the leading two
           * source columns (the `\t.' lead on line 0, the `\'+comma on a
           * continuation), so no `\' marker is emitted and the source starts
           * two columns in.
           */
          int p;

          (void)fprintf (a->lst, "   %04X%-4s%s", (unsigned)loc, lfl, bf);

          for (p = 11 + bn; p < indent + 2; p++)
            (void)fputc (' ', a->lst);

          col = indent + 2;
        }
      else
        {
          (void)fprintf (a->lst, "   %04X%-4s%-*s", (unsigned)loc, lfl, bw, bf);
          col = indent;

          if (k > 0) /* continuation lines lead with a `\' */
            {
              (void)fputc ('\\', a->lst);
              col++;
            }
        }

      /* the source chunk, tabs expanded (relative to the normal indent); an
       * overstrike drops its leading two columns */
      for (i = so + (over ? ((k > 0) ? 1 : 2) : 0); i < se; i++)
        {
          if ('\t' == rawline[i])
            {
              do
                {
                  (void)fputc (' ', a->lst);
                  col++;
                }
              while (0 != ((col - indent) % 8));
            }
          else
            {
              (void)fputc (rawline[i], a->lst);
              col++;
            }
        }

      if (k < nlines - 1) /* every line but the last ends with a `\' */
        (void)fputc ('\\', a->lst);

      (void)fputc ('\n', a->lst);
      a->lst_line++;
    }
}

/******************************************************************************/

static void
print_lst (astate *a, u16 lc0, const char *rawline)
{
  char col[40];
  int bw = ((DIALECT_PASM == a->dialect) ? 14 : 13); /* byte-field width */
  long loc = ((-2 == a->lst_loc) ? (long)lc0 : a->lst_loc);
  int lbase
      = ((a->lst_lbase < 0) ? (a->lc_reloc ? a->base : 0) : a->lst_lbase);
  const char *lfl = ((lbase > 0) ? seg_flag (lbase, a->dialect) : " ");
  int clen;
  char mark = 0; /* macro '+' / .INSERT '@' continuation marker, or none */
  int sall_render = 0; /* this line IS a .SALL macro-collapse call line */

  if (a->lst_suppress) /* assembling only (e.g. a macro's first body line) */
    return;

  if (a->mdef_page)
    { /*
       * the leading report page lists ONLY the offending statements: a label
       * redefinition (`M') or a nested .INSERT (`F').
       */
      int k, has_lead = 0;

      for (k = 0; k < a->lst_nec; k++)
        if ('M' == a->lst_ec[k] || 'F' == a->lst_ec[k])
          has_lead = 1;

      if (!has_lead)
        return;
    }

  /*
   * listing-control gating: body listing off (.XLIST), or a listing-control
   * statement that does not list itself (default, reset by .LCTL).  An errored
   * statement is always listed, though, even under .XLIST -- the originals
   * never hide a diagnostic.
   */

  if (!(a->lst_ctl & LSTC_LIST) && 0 == a->lst_nec)
    return;

  if (a->lst_ctlstmt && !(a->lst_ctl & LSTC_CTL))
    return;

  if (NULL != a->mac_src) /* macro listing supplies the rendered source */
    rawline = a->mac_src;
  else if (a->mac_active)
    { /*
       * macro-expansion listing detail: .SALL suppresses the whole body,
       * .XALL (default) drops the no-code lines, .LALL lists everything
       */
      if (a->lst_ctl & LSTC_SALL)
        { /*
           * .SALL collapses the expansion to one bare call line carrying the
           * FIRST emitting statement's LC + value-form (possibly from a nested
           * macro -- this fires on the first emitting statement at any depth).
           * Render it here with the invocation as the source; suppress the
           * rest of the body.
           */
          if (NULL != a->sall_call && !a->sall_done && a->nbytes > 0)
            {
              rawline = a->sall_call;
              a->sall_done = 1;
              sall_render = 1;
            }
          else
            return;
        }
      else if (0 == a->nbytes && !(a->lst_ctl & LSTC_LALL))
        return;
    }

  /*
   * inserted-file lines carry '@'; continued macro statements carry '+'
   * (but not the macro call line, which sets mac_src with mac_plus clear)
   */
  if (a->ins_depth > 0)
    mark = '@';
  else if (!sall_render
           && (a->mac_plus || (a->mac_active && NULL == a->mac_src)))
    mark = '+';

  /* .LIMAGE: a data statement whose image spilled past one line is rendered
   * as a multi-line byte image with the source split across the lines */
  if ((a->lst_ctl & LSTC_LIMAGE) && a->limg_ns > 0 && 0 == mark
      && (1 == a->lst_kind || 2 == a->lst_kind))
    {
      lst_limage (a, lc0, rawline);
      return;
    }

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

    /*
     * page full: form-feed + heading before this line's first
     * physical row (continuation rows paginate inside lst_source)
     */

    if (a->lst_line >= a->lst_pagelen)
      {
        (void)fputc ('\f', a->lst);
        lst_header (a);
      }

    {
      /*
       * the error-code letter(s) occupy column 1 (and 2) of the line,
       * overwriting the leading blanks (three before the LC, eleven on a
       * blank-LC line); the rest of the line is unchanged
       */
      char lead[12];
      int lw = ((loc < 0) ? 11 : 3);
      int k;

      /* k < 2 pins the lst_ec[] index for static analyzers (nec is <= 2) */
      for (k = 0; k < lw; k++)
        lead[k] = ((k < a->lst_nec && k < 2) ? a->lst_ec[k] : ' ');

      lead[lw] = '\0';
      (void)fputs (lead, a->lst);
    }

    if (over)
      {
        int p;

        (void)fprintf (a->lst, "%04X%-4s%s", (unsigned)loc, lfl, col);

        for (p = 11 + clen; p < scol; p++)
          (void)fputc (' ', a->lst);
      }
    else if (mark)
      { /* the marker occupies the final byte-field column */
        if (loc < 0)
          (void)fprintf (a->lst, "%-*s%c", bw - 1, col, mark);
        else
          (void)fprintf (a->lst, "%04X%-4s%-*s%c", (unsigned)loc, lfl, bw - 1,
                         col, mark);
      }
    else
      {
        if (loc < 0) /* .END and other blank-LOC lines */
          (void)fprintf (a->lst, "%-*s", bw, col);
        else
          (void)fprintf (a->lst, "%04X%-4s%-*s", (unsigned)loc, lfl, bw, col);
      }

    {
      int wrapw = ((DIALECT_PASM == a->dialect) ? 79 : 72);
      int indent = 11 + bw;
      int rq[2];
      int off = line_off (rawline, src);
      int i;

      rq[0] = -1;
      rq[1] = -1;

      for (i = 0; i < a->lst_nec; i++) /* `?' offsets vs the source field */
        rq[i] = a->lst_qoff[i] - off;

      lst_source (a, src, scol, wrapw, indent, rq, a->lst_nec);
    }
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
    {
      /* PASM puts the error count in the page header (only when nonzero); the
       * line replaces the blank line that otherwise follows "Page N" */
      (void)fprintf (a->lst, "%-71sPage %d\n",
                     "PSA Macro Assembler [C12011-0102 ]", a->lst_page);

      if (a->errs_hdr > 0)
        (void)fprintf (a->lst, " - %d Errors Were Detected *****\n",
                       a->errs_hdr);
      else
        (void)fputc ('\n', a->lst);

      /* the leading multiply-defined report page, and an .XLINK core image,
       * omit the ".MAIN. - title" subtitle (a blank line in its place) */
      if (a->mdef_page || a->obj_xlink)
        (void)fprintf (a->lst, "\n\n\n\n");
      else
        (void)fprintf (a->lst, "%-6.6s - %s\n\n\n\n", a->modname, a->title);
    }
  else if (a->obj_xlink) /* ZASM .XLINK: blank subtitle line */
    (void)fprintf (a->lst, "%-64sPAGE %d\n\n\n\n\n",
                   "TDL Z80 CP/M DISK ASSEMBLER VERSION 2.21", a->lst_page);
  else
    (void)fprintf (a->lst, "%-64sPAGE %d\n%-6.6s - %s\n\n\n\n",
                   "TDL Z80 CP/M DISK ASSEMBLER VERSION 2.21", a->lst_page,
                   a->modname, a->title);

  /* heading line count */
  a->lst_line = ((DIALECT_PASM == a->dialect) ? 9 : 8);
}

/******************************************************************************/

/*
 * Collation rank for the symbol-table sort: the originals order digits, then
 * letters, then the remaining Radix-40 name characters ('$', '%', '.') -- so
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
 * qsort comparator ordering symbols by their .EXTERN/.INTERN/.ENTRY
 * declaration sequence -- the order the originals write the `\'/`#'/`@'
 * records.  (An external's base number is assigned in the same sequence, so
 * this also orders the externals by relocation base.)
 */

static int
cmp_defseq (const void *pa, const void *pb) /* by first-definition order */
{
  int x = (int)(*(symbol *const *)pa)->defseq;
  int y = (int)(*(symbol *const *)pb)->defseq;

  return ((x > y) - (x < y));
}

static int
cmp_decl (const void *pa, const void *pb)
{
  int x = (int)(*(symbol *const *)pa)->decl;
  int y = (int)(*(symbol *const *)pb)->decl;

  return ((x > y) - (x < y));
}

/*
 * Collect the external/internal/entry symbols into objsym arrays (each sized
 * sym_count(t)) for the `\'/`#'/`@' object records, in the originals' emission
 * order.
 */

static void
collect_obj_syms (const symtab *t, objsym *exts, int *nexts, objsym *ints,
                  int *nints, objsym *ents, int *nents)
{
  int total = sym_count (t);
  symbol **all, **es, **is, **ts;
  int ne = 0, ni = 0, nt = 0, i;

  *nexts = 0;
  *nints = 0;
  *nents = 0;

  if (total <= 0)
    return;

  all = (symbol **)malloc ((size_t)total * sizeof (symbol *));
  es = (symbol **)malloc ((size_t)total * sizeof (symbol *));
  is = (symbol **)malloc ((size_t)total * sizeof (symbol *));
  ts = (symbol **)malloc ((size_t)total * sizeof (symbol *));

  if (NULL == all || NULL == es || NULL == is || NULL == ts)
    {
      if (NULL != all)
        FREE (all);
      if (NULL != es)
        FREE (es);
      if (NULL != is)
        FREE (is);
      if (NULL != ts)
        FREE (ts);
      return;
    }

  sym_collect (t, all);

  for (i = 0; i < total; i++)
    {
      if (all[i]->external)
        es[ne++] = all[i];

      if (all[i]->internal && !all[i]->entry)
        is[ni++] = all[i]; /* plain internals (entries form their own group) */

      if (all[i]->entry)
        ts[nt++] = all[i];
    }

  qsort (es, (size_t)ne, sizeof (symbol *), cmp_decl);
  qsort (is, (size_t)ni, sizeof (symbol *), cmp_decl);
  qsort (ts, (size_t)nt, sizeof (symbol *), cmp_decl);

  for (i = 0; i < ne; i++)
    {
      (void)xstrlcpy (exts[i].name, es[i]->name, sizeof (exts[i].name));
      exts[i].base = es[i]->val.base;
      exts[i].value = 0; /* external reference: size 0 */
    }

  for (i = 0; i < ni; i++)
    {
      (void)xstrlcpy (ints[i].name, is[i]->name, sizeof (ints[i].name));
      ints[i].base = is[i]->val.base;
      ints[i].value = is[i]->val.value;
    }

  for (i = 0; i < nt; i++)
    {
      (void)xstrlcpy (ents[i].name, ts[i]->name, sizeof (ents[i].name));
      ents[i].base = ts[i]->val.base;
      ents[i].value = ts[i]->val.value;
    }

  *nexts = ne;
  *nints = ni;
  *nents = nt;
  FREE (all);
  FREE (es);
  FREE (is);
  FREE (ts);
}

/******************************************************************************/

/*
 * Collect ALL global symbols for the `&' .PSYM object record (in the
 * originals' order): the three segment bases (.PROG./.DATA./.BLNK., carrying
 * their sizes) first, then the external references in relocation-base order,
 * then the locally-defined symbols in first-definition order.  Local (`..')
 * symbols are excluded.  `ps' must hold at least 3 + sym_count(t) entries.
 */

static void
collect_psyms (const symtab *t, unsigned progsz, unsigned datasz,
               unsigned blnksz, objsym *ps, int *nps)
{
  static const char *const segn[3] = { ".PROG.", ".DATA.", ".BLNK." };
  unsigned segv[3];
  int total = sym_count (t);
  symbol **all, **es, **ds;
  int n = 0, ne = 0, ndef = 0, i;

  segv[0] = progsz;
  segv[1] = datasz;
  segv[2] = blnksz;

  for (i = 0; i < 3; i++) /* segment bases, always first */
    {
      (void)xstrlcpy (ps[n].name, segn[i], sizeof (ps[n].name));
      ps[n].base = i + 1;
      ps[n].value = (u16)segv[i];
      n++;
    }

  *nps = n;

  if (total <= 0)
    return;

  all = (symbol **)malloc ((size_t)total * sizeof (symbol *));
  es = (symbol **)malloc ((size_t)total * sizeof (symbol *));
  ds = (symbol **)malloc ((size_t)total * sizeof (symbol *));

  if (NULL == all || NULL == es || NULL == ds)
    {
      if (NULL != all)
        FREE (all);
      if (NULL != es)
        FREE (es);
      if (NULL != ds)
        FREE (ds);

      return;
    }

  sym_collect (t, all);

  for (i = 0; i < total; i++)
    {
      if (NULL != strchr (all[i]->name, ':')) /* a `..' local: excluded */
        continue;

      if (all[i]->external)
        es[ne++] = all[i];
      else if (all[i]->defined)
        ds[ndef++] = all[i];
    }

  qsort (es, (size_t)ne, sizeof (symbol *), cmp_decl);     /* base order   */
  qsort (ds, (size_t)ndef, sizeof (symbol *), cmp_defseq); /* def. order   */

  for (i = 0; i < ne; i++)
    {
      (void)xstrlcpy (ps[n].name, es[i]->name, sizeof (ps[n].name));
      ps[n].base = es[i]->val.base;
      ps[n].value = 0; /* external reference: value 0 */
      n++;
    }

  for (i = 0; i < ndef; i++)
    {
      (void)xstrlcpy (ps[n].name, ds[i]->name, sizeof (ps[n].name));
      ps[n].base = ds[i]->val.base;
      ps[n].value = ds[i]->val.value;
      n++;
    }

  *nps = n;
  FREE (all);
  FREE (es);
  FREE (ds);
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
      (void)fprintf (a->lst, "%-71sPage %d\n",
                     "PSA Macro Assembler [C12011-0102 ]", a->lst_page);

      if (a->errs_hdr > 0) /* error count in the header, as on the body pages */
        (void)fprintf (a->lst, " - %d Errors Were Detected *****\n",
                       a->errs_hdr);
      else
        (void)fputc ('\n', a->lst);

      /* an .XLINK core image omits the ".MAIN. - title" subtitle */
      if (a->obj_xlink)
        (void)fprintf (a->lst, "\n+++++ Symbol Table +++++\n\n\n");
      else
        (void)fprintf (a->lst, "%-6.6s - %s\n+++++ Symbol Table +++++\n\n\n",
                       a->modname, a->title);

      a->lst_line = 9;
    }
  else
    {
      if (a->obj_xlink)
        (void)fprintf (a->lst, "%-64sPAGE %d\n\n+++++ SYMBOL TABLE +++++\n\n\n",
                       "TDL Z80 CP/M DISK ASSEMBLER VERSION 2.21",
                       a->lst_page);
      else
        (void)fprintf (a->lst,
                       "%-64sPAGE %d\n%-6.6s - %s\n"
                       "+++++ SYMBOL TABLE +++++\n\n\n",
                       "TDL Z80 CP/M DISK ASSEMBLER VERSION 2.21", a->lst_page,
                       a->modname, a->title);

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

  /* keep defined, external, or referenced-undefined non-local symbols */
  for (i = 0; i < navail; i++)
    if ((all[i]->defined || all[i]->external || all[i]->udef)
        && NULL == strchr (all[i]->name, ':'))
      all[nuser++] = all[i];

  qsort (all, (size_t)nuser, sizeof (symbol *), sym_name_cmp);
  (void)fputc ('\f', a->lst); /* eject to a fresh page */
  lst_symhead (a);
  /* an .XLINK core image has no link info: omit the segment-base rows */
  total = nuser + (a->obj_xlink ? 0 : 3);
  col = 0;

  for (i = 0; i < total; i++)
    {
      const char *name, *flag;
      unsigned val;

      if (i < nuser)
        {
          static char ubuf[12];
          const char *g = seg_flag ((int)all[i]->val.base, a->dialect);
          char tcls = (all[i]->entry
                           ? 'E'
                           : (all[i]->internal
                                  ? 'I'
                                  : (all[i]->external ? 'X' : ' ')));
          char ecls = (all[i]->mdef ? 'M' : (all[i]->udef ? 'U' : ' '));
          int gl = 0;
          name = all[i]->name;
          val = all[i]->val.value;

          /*
           * the relocation-base flag (', ", *, or :NN) left-justified in four
           * columns, then the symbol-type flag (E entry, I internal, X
           * external) and the error flag (M multiply-defined, U undefined) --
           * six columns total, matching the predefined-segment rows below
           */
          while (gl < 4 && '\0' != g[gl])
            {
              ubuf[gl] = g[gl];
              gl++;
            }

          while (gl < 4)
            ubuf[gl++] = ' ';

          ubuf[gl++] = tcls;
          ubuf[gl++] = ecls;
          ubuf[gl] = '\0';
          flag = ubuf;
        }
      else
        {
          /*
           * .PROG. (index 2) carries the program-segment size; the
           * .BLNK./.DATA. rows stay 0000 for this absolute-segment output.
           * An explicit .LOC/ORG pins the code absolutely, so .PROG. then
           * reports size 0 here too -- matching the object `\\' record.
           */

          name = segname[(long)i - nuser];
          val = a->seg_hw[3 - ((long)i - nuser)];

          if (2 == (long)i - nuser && a->obj_org_used) /* pinned .PROG. */
            val = 0;

          flag = segflag[(long)i - nuser];
        }

      (void)fprintf (a->lst, "%-6s %04X%s", name, val & 0xFFFFu, flag);

      if ((col == perline - 1) || (i == total - 1))
        {
          (void)fputc ('\n', a->lst);
          col = 0;
          a->lst_line++;

          if (a->lst_line >= a->lst_pagelen && i < total - 1)
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

  /*
   * an optional DOS/CP-M drive specifier `d:' prefixes the filename; the
   * originals accept it but resolve the file on the source's own disk, so we
   * strip it (a future extended-warnings mode could note the ignored drive).
   */
  if ('\0' != name[0] && ':' == name[1])
    {
      int k = 0;

      while ('\0' != name[(long)k + 2])
        {
          name[k] = name[(long)k + 2];
          k++;
        }

      name[k] = '\0'; /* the `.'-vs-not (dot) test already excluded the `d:' */
    }

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

/* Take ownership of S (a malloc'd macro body line): store it in M's body
 * array, or free it when M is already at the 64-line cap or S is NULL.
 * Routing every dupstr() result through this transfer-of-ownership helper
 * makes the pointer's escape explicit; an older gcc -fanalyzer otherwise
 * reports a spurious leak where the allocation and the array store share
 * one statement. */
static void
macro_addbody (macrodef *m, char *s)
{
  if (NULL == s)
    return;

  if (m->nbody < 64)
    m->body[m->nbody++] = s;
  else
    FREE (s);
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
 *
 * Every body line is malloc'd (dupstr) and handed to macro_addbody(), which
 * stores it in m->body[] or frees it; m itself is malloc'd in do_define() and
 * linked into a->macros (and freed by macro_free_all()).  An older gcc
 * -fanalyzer cannot follow the pointer's escape through the array member and
 * the macro list and reports a spurious leak here; restructuring through the
 * transfer-of-ownership helper did not satisfy it, so suppress that one
 * false positive locally (no leak: see macro_free_all()).
 */

/* -Wanalyzer-malloc-leak is a real-gcc-only option; clang (which also defines
 * __GNUC__) and the gcc-compatible compilers below would reject the pragma
 * under -Werror, so guard it to real gcc. */
#if defined(__GNUC__) && !defined(__clang__) \
    && !(defined(__OPEN64__) || defined(__OPENCC__) || defined(__PCC__))
# pragma GCC diagnostic push
# pragma GCC diagnostic ignored "-Wanalyzer-malloc-leak"
#endif

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
              macro_addbody (m, dupstr (buf));

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
  macro_addbody (m, dupstr (buf));
}

#if defined(__GNUC__) && !defined(__clang__) \
    && !(defined(__OPEN64__) || defined(__OPENCC__) || defined(__PCC__))
# pragma GCC diagnostic pop
#endif

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

  while (isalnum ((unsigned char)*p) || '.' == *p || '$' == *p || '%' == *p)
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

          while (isalnum ((unsigned char)*p) || '.' == *p || '$' == *p
                 || '%' == *p)
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

          while ((isalnum ((unsigned char)*q) || '.' == *q || '$' == *q
                  || '%' == *q)
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
      else if (isalpha ((unsigned char)*in) || '.' == *in || '%' == *in)
        {
          char tok[NAMEBUF];
          int tn = 0, j, pi = -1;

          while ((isalnum ((unsigned char)*in) || '.' == *in || '$' == *in
                  || '%' == *in)
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
              const char *callline, int labeled)
{
  char argbuf[1024];
  char *args[8];
  int nargs = 0, i, j = 0;
  int outer = 0, start = 0;
  int saved_argc;
  const char *p = skipws (argstr);

  if (a->macro_depth > MACRO_NEST_MAX)
    { /* runaway macro recursion: fail cleanly (see MACRO_NEST_MAX) */
      if (2 == a->pass)
        {
          (void)fprintf (stderr,
                         "  *** macro recursion too deep (limit %d)\n",
                         MACRO_NEST_MAX);
          a->errors++;
        }

      return;
    }

  a->macro_depth++;
  saved_argc = a->mac_argc; /* `&' is per-invocation; restore on exit */

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
           * into the expansion (it expands in the listing - a call's trailing
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

  /* `&' = the macro's argument count: the larger of the declared dummy-param
   * count and the number of arguments actually passed */
  a->mac_argc = ((nargs > m->nparams) ? nargs : m->nparams);

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

  if (outer && (a->lst_ctl & LSTC_SALL))
    { /*
       * .SALL: the whole expansion collapses to ONE bare call line.  Assemble
       * every body line (NOT suppressed, so print_lst runs); the first emitting
       * statement -- at any nesting depth -- renders the call line via the
       * sall_call hook in print_lst.  If nothing emits, list the bare call line
       * (its label's LC, or blank when unlabeled), as for any no-code line.
       */
      u16 lc0 = a->lc;
      int bi;

      a->mac_active = 1;
      a->sall_call = callline;
      a->sall_done = 0;

      for (bi = 0; bi < m->nbody && !a->macro_exit; bi++)
        {
          char lnb[512];
          macro_subst (m, args, nargs, m->body[bi], lnb);
          do_line (a, lnb);
        }

      if (2 == a->pass && !a->sall_done)
        {
          a->nbytes = 0;
          a->lst_kind = 0;
          a->lst_loc = (labeled ? (long)lc0 : -1);
          a->lst_lbase = -1;
          a->lst_obase = 0;
          a->lst_nec = 0;
          a->mac_src = callline;
          a->mac_plus = 0;
          print_lst (a, lc0, callline);
          a->mac_src = NULL;
        }

      a->sall_call = NULL;
      a->sall_done = 0;
      a->macro_depth--;
      a->mac_argc = saved_argc;
      a->macro_exit = 0;
      a->mac_active = 0;

      return;
    }

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

      /*
       * A LABELED call line carries the label's address (= lc0) even when
       * body[0] emits nothing -- the originals list the label with its LC, as
       * for any labeled line.  (An UNLABELED empty-body[0] call line stays
       * blank: lst_loc == -1 here; an emitting body[0] already shows lc0 via
       * lst_loc == -2.)  Deriving lst_lbase reproduces the relocation flag.
       */
      if (labeled && -1 == a->lst_loc)
        {
          a->lst_loc = (long)lc0;
          a->lst_lbase = -1;
        }

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
        { /*
           * the body-close: force-list this last line with ']' appended
           * (under .SALL the body text is suppressed, so fall through)
           */
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

  /*
   * .EXIT broke the loop before the last body line, so its trailing ']' was
   * never appended -- emit the body close on its own '+'-marked line, as the
   * originals do.
   */
  if (outer && a->macro_exit && 2 == a->pass && !(a->lst_ctl & LSTC_SALL))
    {
      a->nbytes = 0;
      a->lst_kind = 0;
      a->lst_loc = -1; /* the lone ']' has no location */
      a->lst_lbase = -1;
      a->lst_obase = 0;
      a->lst_nec = 0; /* clears the per-line error codes + `?' offsets */
      a->mac_src = "]";
      a->mac_plus = 1;
      print_lst (a, a->lc, "]");
      a->mac_src = NULL;
      a->mac_plus = 0;
    }

  a->macro_depth--;
  a->mac_argc = saved_argc; /* restore the enclosing invocation's `&' */
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
  s->val.base = 0;
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
  a->lst_opw = 0; /* default: instruction, no operand */
  a->lst_loc = -2; /* default: show the statement LC */
  a->lst_lbase = -1; /* default: LC base from lc_reloc/base */
  a->lst_obase = 0;
  a->lst_ctlstmt = 0; /* set by the listing-control directives */
  a->lst_nec = 0;    /* per-line error codes (col 1) + their `?' offsets */
  a->limg_ns = 0;    /* per-line .LIMAGE source splits (set by do_data) */
  a->cur_line = line; /* base for the parse-position offsets */
  a->ppos = 0;
  a->eval_undef = 0;

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

      /* the originals list each continuation line of the prompt verbatim
       * (blank LC), as the source it is */
      if (2 == a->pass)
        {
          a->lst_loc = -1;
          print_lst (a, a->lc, line);
        }

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
            expand_macro (a, pm, a->pend_args, NULL, 0);
        }

      return;
    }

  lc0 = a->lc;

  /* '.' in operands resolves to the statement start */
  a->lc_stmt = a->lc;

  /* leading block-close ']' and else ']' '[' brackets */
  bp = skipws (line);

  {
    int dang = 0;    /* the last ']' was a dangling true-block close          */
    int dang_wt = 0; /* its if_true (the else, if any, takes the inverse)     */

    /*
     * A conditional whose true block closed on an earlier line (pend_else)
     * takes an else `[' here when this line opens with one (the multi-line
     * `] ... [' else form, comment/blank lines allowed between).  Any other
     * non-comment line closes the window without an else.
     */
    if (a->pend_else)
      {
        if ('[' == *bp)
          {
            if (a->cdepth < MAXCOND)
              {
                a->cstack[a->cdepth].if_true = !a->pend_else_wt;
                a->cstack[a->cdepth].assemble
                    = a->pend_else_outer && !a->pend_else_wt;
                a->cstack[a->cdepth].is_else = 1;
                a->cdepth++;
              }

            a->pend_else = 0;
            bp = skipws (bp + 1);
          }
        else if ('\0' != *bp && ';' != *bp)
          a->pend_else = 0;
      }

    while (']' == *bp)
      {
        int wt = 0, was_else = 0;

        if (a->cdepth > 0)
          {
            wt = a->cstack[(long)a->cdepth - 1].if_true;
            was_else = a->cstack[(long)a->cdepth - 1].is_else;
            a->cdepth--;
          }

        dang = 0;
        bp = skipws (bp + 1);

        if ('[' == *bp) /* `] [' (else): pop the IF frame, push the ELSE */
          {
            int outer = casm (a);

            if (a->cdepth < MAXCOND)
              {
                a->cstack[a->cdepth].if_true = !wt;
                a->cstack[a->cdepth].assemble = outer && !wt;
                a->cstack[a->cdepth].is_else = 1;
                a->cdepth++;
              }

            bp = skipws (bp + 1);
          }
        else if (!was_else)
          { /* a dangling true-block close: an else `[' may still follow */
            dang = 1;
            dang_wt = wt;
          }
      }

    if (dang && ('\0' == *bp || ';' == *bp))
      { /* open the else window: a later `[' (across comments) is the else */
        a->pend_else = 1;
        a->pend_else_wt = dang_wt;
        a->pend_else_outer = casm (a);
      }

    if ('\0' == *bp || ';' == *bp)
      { /*
         * blank or comment-only line (a `]'/`] [' bracket close, a comment, or
         * a blank): the originals list it with a blank LC column, even inside a
         * skipped conditional (tabs expand as usual); print_lst applies any
         * .XLIST / macro-body suppression.
         */
        if (2 == a->pass)
          {
            a->lst_loc = -1;
            print_lst (a, lc0, line);
          }

        return;
      }
  }

  /*
   * `![sub]=expr' : assign a .TEMPS local temporary (PASM, inside a macro).
   * The lexer treats a leading `!' as an operator, so intercept the assignment
   * form here -- only when a `]' is followed by `=' (otherwise fall through).
   */
  if (DIALECT_PASM == a->dialect && a->macro_depth > 0 && '!' == *bp
      && '[' == bp[1])
    {
      const char *pk = bp + 2;

      while ('\0' != *pk && ']' != *pk && ';' != *pk)
        pk++;

      if (']' == *pk && '=' == *skipws (pk + 1))
        {
          const char *p = bp + 2;
          value_t idx, v;
          int sub = -1;

          a->ppos = line_off (line, bp);

          if (!eval1 (a, &p, &idx) && 0 == idx.reloc && NULL == idx.ext)
            sub = (int)idx.value;

          p = skipws (p);

          if (']' == *p)
            p = skipws (p + 1);

          if ('=' == *p) /* `=' or `==' */
            p++;

          if ('=' == *p)
            p++;

          if (!eval1 (a, &p, &v) && sub >= 0 && sub < a->ntemps)
            a->temps[sub] = v;
          else
            aerr (a, line, "subscript");

          if (2 == a->pass)
            {
              a->lst_loc = -1;
              print_lst (a, lc0, line);
            }

          return;
        }
    }

  lex_line (bp, &L);

  /* default `?' position: the operand field (after the op); eval1 advances
   * it as it consumes the expression, so an operand error marks where it
   * stopped */
  a->ppos = line_off (line, L.operands);

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

      if (L.internal && !s->internal)
        { /* `label::' -- declare it internal, like a preceding .INTERN */
          s->internal = 1;
          s->decl = (unsigned short)a->next_decl++;
        }

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
          s->val.base = (a->lc_reloc ? a->base : 0);
          s->val.ext = NULL;

          if (0 == s->defseq) /* record first-definition order for `&' .PSYM */
            s->defseq = (unsigned short)a->next_defseq++;

          s->defined = 1;
          s->seen = (unsigned char)a->pass;
        }
      else if (s->defined)
        { /*
           * the label is already defined in this pass: a Multiply-defined
           * symbol error (the first value is kept).  The `?' marks the label,
           * so point it just past the label name.
           */
          a->ppos = line_off (line, bp) + (int)strlen (L.label);
          aerr (a, line, "multiply-defined symbol");
          s->mdef = 1; /* flagged `M' in the symbol table */
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

      /*
       * single-line inline form `.IFx cond,[stmt][else]': the taken branch's
       * (single) statement is on THIS line, so assemble it inline -- its bytes
       * list on the directive's own line -- and push NO block frame.  Detect it
       * by a `,[' at bracket depth 0 whose `[' has a matching `]' on this line;
       * a `[' that instead ends the line opens the multi-line form handled
       * below.
       */
      {
        const char *bk = NULL;
        const char *b1e;
        const char *s;
        int d = 0;

        for (s = L.operands; '\0' != *s && ';' != *s; s++)
          {
            if ('[' == *s)
              d++;
            else if (']' == *s)
              {
                if (d > 0)
                  d--;
              }
            else if (',' == *s && 0 == d)
              {
                const char *t2 = skipws (s + 1);

                if ('[' == *t2)
                  {
                    bk = t2;
                    break;
                  }
              }
          }

        b1e = ((NULL != bk) ? inline_block_end (bk + 1) : NULL);

        if (NULL != bk && NULL != b1e)
          { /* INLINE: a matching `]' for the first block lies on this line */
            const char *p2 = skipws (b1e + 1);
            const char *b2e
                = (('[' == *p2) ? inline_block_end (p2 + 1) : NULL);
            const char *body = NULL, *body_end = NULL;
            /*
             * No inline else and the line ends after the true block: a
             * multi-line else `[' may still follow (across comment/blank
             * lines), as for the multi-line conditional form.  The else window
             * is armed AFTER assembling the true-block statement below -- the
             * recursive do_line() for that statement would otherwise clear it.
             */
            int arm_else = (NULL == b2e && ('\0' == *p2 || ';' == *p2));

            if (t) /* taken: the true block's statement */
              {
                body = bk + 1;
                body_end = b1e;
              }
            else if (NULL != b2e) /* not taken: the else block, if present */
              {
                body = p2 + 1;
                body_end = b2e;
              }

            if (outer && NULL != body && body_end > body)
              { /*
                 * assemble the single statement, then list THIS directive's
                 * line carrying its bytes (the recursive line's own listing is
                 * suppressed; its `?' error offsets are shifted to the block's
                 * position within this line)
                 */
                char bbuf[512];
                size_t bl = (size_t)line_off (body, body_end);

                if (bl >= sizeof (bbuf))
                  bl = sizeof (bbuf) - 1;

                (void)memcpy (bbuf, body, bl);
                bbuf[bl] = '\0';

                a->lst_suppress = 1;
                do_line (a, bbuf);
                a->lst_suppress = 0;

                if (2 == a->pass)
                  {
                    int boff = line_off (line, body);
                    int i;

                    for (i = 0; i < a->lst_nec; i++)
                      a->lst_qoff[i] += boff;

                    a->cur_line = line;
                    print_lst (a, lc0, line);
                  }
              }
            else if (2 == a->pass)
              { /* not taken (or empty / skipped): list with a blank LC */
                a->lst_loc = -1;
                print_lst (a, lc0, line);
              }

            if (arm_else)
              { /* a later bare `[' is this conditional's else (inverse of t) */
                a->pend_else = 1;
                a->pend_else_wt = t;
                a->pend_else_outer = outer;
              }

            return;
          }
      }

      if (a->cdepth < MAXCOND)
        {
          a->cstack[a->cdepth].if_true = t;
          a->cstack[a->cdepth].assemble = outer && t;
          a->cstack[a->cdepth].is_else = 0;
          a->cdepth++;
        }

      if (2 == a->pass)
        { /*
           * the originals list the conditional directive line itself with a
           * blank LC column -- UNLESS it carries a label (`LBL: .IFx ...'),
           * in which case the label's address (= lc0) is shown, as for any
           * labeled line.
           */
          a->lst_loc = (('\0' != L.label[0]) ? (long)lc0 : -1);
          a->lst_lbase = -1;
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

          if (L.internal && !s->internal)
            { /* `sym=:\'/`sym==:\' -- declare it internal, like .INTERN */
              s->internal = 1;
              s->decl = (unsigned short)a->next_decl++;
            }

          q = skipws (q + 1); /* the prompt string follows */

          if ('\'' == *q)
            { /* echo the prompt, then read */
              const char *p = q + 1;

              if (reading)
                { /*
                   * pass 1 (or undefined): blank line before the prompt;
                   * pass 2 must stay silent (value already cached)
                   */
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

          /* like any `=' assignment, the line lists the value (the answer
           * read, or in pass 2 the value cached from pass 1), not the LC */
          a->lst_loc = (long)s->val.value;
          a->lst_lbase = (0 != s->val.reloc ? s->val.base : 0);

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

          if (L.internal && !s->internal)
            { /* `sym=:'/`sym==:' -- declare it internal, like .INTERN */
              s->internal = 1;
              s->decl = (unsigned short)a->next_decl++;
            }

          if (0 == s->defseq) /* record first-definition order for `&' .PSYM */
            s->defseq = (unsigned short)a->next_defseq++;

          s->val = v;
          s->defined = 1;                   /* claim the name so a later */
          s->seen = (unsigned char)a->pass; /* label keeps this value    */
        }

        a->lst_loc = (long)v.value;     /* listing: '=' shows the value */
        a->lst_lbase = (0 != v.reloc ? v.base : 0); /* the value's base flag */
      }

      if (2 == a->pass)
        print_lst (a, lc0, line);

      return;
    }

  /*
   * label (if any) already defined above.  The originals still list a
   * line with no operator: a label-only line shows its LC, while a blank
   * or comment-only line has no location and blanks the LC column.
   */
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
      if (a->ins_depth > 0)
        { /*
           * only one level of .INSERT is allowed: a nested .INSERT (one is
           * already in progress) is an `F' error, and the nested file is NOT
           * inserted.  Both originals also flag the now-stranded file-name
           * operand `Q' (questionable), so the line carries two codes (`FQ')
           * and two `?' markers (`??') over the file-name field.
           */
          a->ppos = line_off (line, L.operands);
          aerr (a, line, "nested .INSERT"); /* F */
          aerr (a, line, "extra operand");  /* Q (same column -> `??') */

          if (2 == a->pass || a->mdef_page) /* body, or leading report page */
            {
              a->lst_loc = -1;
              print_lst (a, lc0, line);
            }

          return;
        }

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
  else if (opeq (op, ".EXTERN", ".EXTRN") || opeq (op, "EXTRN", NULL))
    { /* declare external symbols; each gets a sequential base number (>=4) */
      const char *q = L.operands;

      for (;;)
        {
          char nm[NAMEBUF];
          q = parse_opname (q, nm);

          if ('\0' != nm[0])
            {
              symbol *s = sym_intern (a->syms, nm);

              if (!s->external)
                {
                  s->external = 1;
                  s->val.value = 0;
                  s->val.reloc = 0;
                  s->val.base = a->next_ebase++;
                  s->val.ext = NULL;
                  s->decl = (unsigned short)a->next_decl++;
                }
            }

          q = skipws (q);

          if (',' == *q)
            q++;
          else
            break;
        }

      a->lst_loc = -1;
    }
  else if (opeq (op, ".ENTRY", NULL) || opeq (op, ".INTERN", NULL))
    { /* mark internal symbols (.ENTRY symbols are also entry points) */
      int is_entry = opeq (op, ".ENTRY", NULL);
      const char *q = L.operands;

      for (;;)
        {
          char nm[NAMEBUF];
          q = parse_opname (q, nm);

          if ('\0' != nm[0])
            {
              symbol *s = sym_intern (a->syms, nm);

              if (!s->internal)
                {
                  s->internal = 1;
                  s->decl = (unsigned short)a->next_decl++;
                }

              if (is_entry)
                s->entry = 1;
            }

          q = skipws (q);

          if (',' == *q)
            q++;
          else
            break;
        }

      a->lst_loc = -1;
    }
  else if (opeq (op, ".IDENT", NULL))
    { /* set the module name carried in the `!' object record */
      char nm[NAMEBUF];
      (void)parse_opname (L.operands, nm);

      if ('\0' != nm[0])
        (void)xstrlcpy (a->modname, nm, sizeof (a->modname));

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
          /* save the current (lc, base, mode) so .RELOC can restore it */
          if (a->loc_sp
              < LOC_STK_DEPTH)
            {
              a->loc_stk[a->loc_sp].lc = a->lc;
              a->loc_stk[a->loc_sp].base = a->base;
              a->loc_stk[a->loc_sp].reloc = a->lc_reloc;
              a->loc_sp++;
            }

          a->lc = v.value;

          if (0 != v.reloc && v.base >= 1 && v.base <= 3)
            { /* switch to the named segment, resuming its high-water */
              a->base = v.base;
              a->lc_reloc = 1;
            }
          else
            {
              /*
               * an absolute origin pins the program: the .PROG. object
               * segment then reports size 0 (the code is absolutely located,
               * not relocatable).  A *relocatable* origin merely switches the
               * active base and does not pin the program.
               */
              a->lc_reloc = 0;
              a->obj_org_used = 1;
            }
        }

      a->lst_loc = (long)a->lc; /* listing shows the LC after ORG */
    }
  else if (opeq (op, ".RELOC", NULL))
    { /* restore the (lc, base, mode) before the immediately preceding .LOC;
       * an empty stack is equivalent to .LOC 0 of .PROG. */
      if (a->loc_sp > 0)
        {
          a->loc_sp--;
          a->lc = a->loc_stk[a->loc_sp].lc;
          a->base = a->loc_stk[a->loc_sp].base;
          a->lc_reloc = a->loc_stk[a->loc_sp].reloc;
        }
      else
        {
          a->lc = 0;
          a->base = 1;
          a->lc_reloc = 1;
        }

      a->lst_loc = (long)a->lc;
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
      a->lst_loc = -1; /* output-mode directive: blank LC in the listing */
    }
  else if (opeq (op, ".PREL", NULL))
    {
      a->lc_reloc = 1;
      a->obj_abs = 0;
      a->lst_loc = -1; /* output-mode directive: blank LC in the listing */
    }
  else if (opeq (op, ".LINK", NULL))
    { /* emit the full link records (the default); an output directive that
       * lists with a blank LC (not a listing-control statement) */
      a->obj_xlink = 0;
      a->lst_loc = -1;
    }
  else if (opeq (op, ".XLINK", NULL))
    { /* relocatable core image: suppress the !/\ link records */
      a->obj_xlink = 1;
      a->lst_loc = -1;
    }
  else if (opeq (op, ".I8080", NULL))
    { /* restrict to the 8080 set: a Z80 instruction now raises a `Z' warning */
      a->i8080_mode = 1;
      a->lst_loc = -1;
    }
  else if (opeq (op, ".Z80", NULL))
    { /* allow the Z80 extensions again (the default) */
      a->i8080_mode = 0;
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
  else if (opeq (op, ".LSYM", NULL))
    { /* enable the symbol-table LISTING */
      a->lst_ctl |= LSTC_SYM;
      a->lst_ctlstmt = 1;
      a->lst_loc = -1;
    }
  else if (opeq (op, ".XSYM", NULL))
    { /* suppress the symbol-table listing at .END */
      a->lst_ctl &= ~LSTC_SYM;
      a->lst_ctlstmt = 1;
      a->lst_loc = -1;
    }
  else if (opeq (op, ".PSYM", NULL))
    { /* punch the global symbol table into the OBJECT (the `&' record), for
       * the PSA BUG debugger -- an output directive (lists with a blank LC),
       * distinct from the .LSYM listing control */
      a->obj_psym = 1;
      a->lst_loc = -1;
    }
  else if (opeq (op, ".XPSYM", NULL))
    { /* suppress the `&' symbol-table object record (the default) */
      a->obj_psym = 0;
      a->lst_loc = -1;
    }
  else if (DIALECT_PASM == a->dialect && opeq (op, ".TEMPS", NULL))
    { /*
       * allocate the local-temporary array referenced as `![sub]' (PASM only;
       * ZASM treats .TEMPS as an unknown op).  Each element is initialized to
       * absolute zero; re-issuing .TEMPS reallocates.
       */
      const char *q = L.operands;
      value_t v;

      if (!eval1 (a, &q, &v))
        {
          int n = (int)v.value; /* v.value is a u16, so always >= 0 */
          int i;

          if (n > MAXTEMPS)
            n = MAXTEMPS;

          a->ntemps = n;

          for (i = 0; i < n; i++)
            {
              a->temps[i].value = 0;
              a->temps[i].reloc = 0;
              a->temps[i].base = 0;
              a->temps[i].ext = NULL;
            }
        }

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
    { /*
       * push the listing-control flags onto the save stack.  Unlike the other
       * control statements, .SLIST lists itself whenever body listing is on
       * (it is not gated by .LCTL), so leave lst_ctlstmt clear.
       */
      if (a->lst_nsave < LSTC_SAVES)
        a->lst_save[a->lst_nsave++] = a->lst_ctl;

      a->lst_loc = -1;
    }
  else if (opeq (op, ".RLIST", NULL))
    { /*
       * restore the listing-control flags from the save stack.  The .RLIST line
       * itself is listed under the PRE-restore flags (the restored flags take
       * effect with the following statement), so list it before restoring.
       */
      a->lst_loc = -1;

      if (2 == a->pass)
        print_lst (a, lc0, line);

      if (a->lst_nsave > 0)
        a->lst_ctl = a->lst_save[--a->lst_nsave];

      return;
    }
  else if (opeq (op, ".TITLE", NULL) || opeq (op, ".SBTTL", NULL)
           || opeq (op, ".SUBTTL", NULL))
    { /*
       * capture the page subtitle (in both passes, so pass 2's page-1
       * heading already has it); the directive is not listed in the body.
       * .SBTTL/.SUBTTL set the subtitle and, like .TITLE, do not self-list
       * (the originals suppress the directive line too).
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
  else if (opeq (op, ".PAGE", NULL))
    {
      const char *pg = skipws (L.operands);

      if ('\0' != *pg && ';' != *pg)
        { /*
           * `.PAGE' with an operand differs by dialect.  ZASM takes NO operand:
           * it flags the operand `Q' (the line lists with the `Q' code + a `?'
           * at the operand), then ejects as for a bare `.PAGE'.  PASM instead
           * reads the operand as the page geometry, `.PAGE width[,length]':
           * the SECOND operand sets the lines-per-page (pagination) and the
           * line is suppressed WITHOUT ejecting.  The first operand (page
           * WIDTH -> column wrap) is not yet honored.
           */
          if (DIALECT_PASM == a->dialect)
            {
              const char *cm = pg;

              while ('\0' != *cm && ';' != *cm && ',' != *cm)
                cm++;

              if (',' == *cm && 2 == a->pass)
                { /* the lines-per-page is the operand after the comma */
                  value_t v;
                  const char *q = skipws (cm + 1);

                  /* the operand is the TOTAL page length; the form-feed fires
                   * after that many lines less the 3-line bottom margin -- the
                   * same convention as the default LST_PAGE (a 66-line page
                   * less 3).  Require it to exceed the margin. */
                  if (!eval1 (a, &q, &v) && 0 == v.reloc && NULL == v.ext
                      && v.value > 3)
                    a->lst_pagelen = (int)v.value - 3;
                }

              return; /* geometry directive: suppressed, no eject */
            }

          a->ppos = line_off (line, pg);
          aerr (a, line, "extra operand"); /* `Q': questionable operand */
          /* a labeled `.PAGE <arg>' shows the label's address (= lc0), like any
           * labeled line; an unlabeled one lists with a blank LOC column */
          a->lst_loc = (('\0' != L.label[0]) ? (long)lc0 : -1);
          a->lst_lbase = -1;

          if (2 == a->pass)
            {
              print_lst (a, lc0, line); /* list the `Q'+`?' line first ... */
              (void)fputc ('\f', a->lst); /* ... then eject like a bare .PAGE */
              lst_header (a);
            }

          return;
        }

      /*
       * bare `.PAGE': skip to the top of the next listing page; the directive
       * itself is not listed (.EJECT is NOT a synonym -- the originals reject
       * it).
       */
      if (2 == a->pass)
        {
          (void)fputc ('\f', a->lst);
          lst_header (a);
        }

      return; /* suppressed from the body listing */
    }
  else if (opeq (op, ".END", "END") || opeq (op, ".PRGEND", NULL))
    {
      /*
       * .END terminates the file; .PRGEND ("library file generation")
       * terminates the current module and the driver then assembles the next
       * one independently into the same object file.  Both end the current
       * module, blank the LOC column, and accept an optional start address.
       */
      const char *p = skipws (L.operands);

      a->ended = 1;
      a->lst_loc = -1; /* no start address: listing blanks the LOC column */

      if ('\0' != *p && ';' != *p) /* `.END expr' sets the module start addr */
        {
          value_t v;

          if (eval1 (a, &p, &v))
            aerr (a, line, "bad start address");
          else
            {
              a->obj_start = v.value;
              a->obj_start_rel = (0 != v.reloc);
              /* the originals list `.END expr' with the start value in the LOC
               * column (with its relocation flag), like an `=' assignment */
              a->lst_loc = (long)v.value;
              a->lst_lbase = (0 != v.reloc ? v.base : 0);
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

      /* folds the call line itself; a label makes it carry the start LC */
      expand_macro (a, mac, L.operands, line, ('\0' != L.label[0]));

      return;
    }
  else
    {
      /*
       * a machine instruction (encode_insn emits it), a listing/output
       * no-op directive, or an unknown operator
       */

      if (!encode_insn (a, line, op, L.operands))
        {
          if (is_noop_dir (op))
            a->lst_loc = -1; /* a listing/output no-op directive (e.g. .PRNTX)
                              * emits nothing: blank its LOC column, as the
                              * originals do, instead of showing the live LC */
          else
            { /*
               * unknown operator (Operation error): the originals flag 'O' and
               * emit a four-byte zero placeholder, advancing the LC.  Done in
               * both passes so the LC stays consistent and the pass-1 count
               * feeds the PASM page header.
               */
              aerr (a, line, "unknown operator");
              emit (a, 0);
              emit (a, 0);
              emit (a, 0);
              emit (a, 0);
            }
        }
    }

  if (2 == a->pass || a->mdef_page)
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

/*
 * Extract the canonical (uppercased, six-char-prefix-resolved) operator of a
 * source line into `op' (NAMEBUF bytes), skipping an optional `label:'.  Used
 * to find .PRGEND / .END module boundaries without dispatching the line.  The
 * .OPSYN alias chain is intentionally not applied here: a module boundary is
 * recognized by its canonical spelling, the form library sources use.
 */

static void
line_op (const char *line, char *op)
{
  line_t L;
  int k;

  lex_line (line, &L);
  op[0] = '\0';

  if ('\0' == L.op[0])
    return;

  for (k = 0; k < NAMEBUF - 1 && '\0' != L.op[k]; k++)
    op[k] = (char)toupper ((unsigned char)L.op[k]);

  op[k] = '\0';
  canon_dir (op);
}

/******************************************************************************/

/* True if `line' is a .PRGEND (= .PRGEN) module-boundary directive. */

static int
line_is_prgend (const char *line)
{
  char op[NAMEBUF];

  line_op (line, op);

  return 0 == strcmp (op, ".PRGEND");
}

/******************************************************************************/

/*
 * Count the independent modules in a source file: one more than the number of
 * .PRGEND boundaries, stopping at the .END file terminator.  A file with no
 * .PRGEND is a single module (returns 1).
 */

static int
count_modules (const char *path)
{
  FILE *f = fopen (path, "r");
  char buf[1024], op[NAMEBUF];
  int n = 1;

  if (NULL == f)
    return 1;

  while (NULL != fgets (buf, (int)sizeof (buf), f))
    {
      line_op (buf, op);

      if (0 == strcmp (op, ".PRGEND"))
        n++;
      else if (0 == strcmp (op, ".END") || 0 == strcmp (op, "END"))
        break;
    }

  (void)fclose (f);

  return n;
}

/******************************************************************************/

/*
 * Assemble one module of a (possibly multi-module) source: read the whole
 * file but dispatch only the lines of module `modidx', skipping earlier
 * modules by counting their .PRGEND boundaries.  do_line ends the target
 * module at its own .PRGEND/.END (setting `ended'), which also stops the read.
 */

static void
process_module (astate *a, const char *path, int modidx)
{
  FILE *f = fopen (path, "r");
  char buf[1024];
  int curmod = 0;

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

      if (curmod == modidx)
        do_line (a, buf);
      else if (line_is_prgend (buf))
        curmod++; /* a skipped module's boundary: advance toward the target */
    }

  (void)fclose (f);
}

/******************************************************************************/

/*
 * Reset the pass-local assembler state at the start of a pass.  The symbol
 * table, the accumulated error count, the listing pagination, and the image
 * extent are preserved by the caller (they span the whole assembly); a new
 * module additionally starts from a fresh symbol table.  Calling this for
 * pass 1 of the first module is a no-op-equivalent reset (macros are already
 * empty).
 */

static void
init_pass (astate *a, int pass)
{
  a->pass = pass;
  a->radix = RADIX_DEFAULT;
  a->lc = 0;
  a->lc_reloc = 1;
  a->base = 1; /* implicit start: .LOC 0 of .PROG. */
  a->next_ebase = 4;
  a->next_decl = 1;
  (void)xstrlcpy (a->modname, ".MAIN.", sizeof (a->modname));
  a->seg_hw[0] = a->seg_hw[1] = a->seg_hw[2] = a->seg_hw[3] = 0;
  a->loc_sp = 0;
  a->obj_abs = 0; /* default .PREL */
  a->obj_org_used = 0;
  a->obj_start = 0;
  a->obj_start_rel = 0;
  a->em_n = 0; /* the emission log/spans are recorded in pass 2 only */
  a->em_pending = 0;
  a->nspans = 0;
  a->emit_prev = -1;
  a->img_any = 0;
  a->ended = 0;
  a->nalias = 0;
  a->cdepth = 0;
  a->pend_else = 0;
  a->in_prompt = 0;
  a->genctr = 0;
  a->macro_depth = 0;
  a->macro_exit = 0;
  a->sall_call = NULL;
  a->sall_done = 0;
  a->scope = 0;
  a->pending = 0;
  a->pend_console = NULL;
  a->lst_ctl = LSTC_DEFAULT;
  a->lst_nsave = 0;
  a->mdef_page = 0;
  a->obj_xlink = 0;
  a->obj_psym = 0; /* default .XPSYM: no `&' symbol-table object record */
  a->next_defseq = 1;
  a->ntemps = 0; /* no .TEMPS local array allocated yet */
  a->mac_argc = 0;
  a->i8080_mode = 0; /* default .Z80: Z80 extensions allowed without warning */
  a->idx_pfx = 0;
  macro_free_all (a);
  a->defining = NULL;
  a->def_started = 0;
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
  a.lst_pagelen = LST_PAGE; /* PASM `.PAGE w,L' overrides this */

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

  /*
   * an image is needed for -o and for any object output (-R/-X); the emission
   * log and spans only for object output.
   */
  a.image = ((NULL != outpath || NULL != relpath || NULL != hexpath)
                ? (u8 *)calloc (65536UL, 1)
                : NULL);
  a.em_byte = NULL;
  a.em_rel = NULL;
  a.em_tbase = NULL;
  a.em_n = 0;
  a.em_cap = 0;
  a.em_pending = 0;
  a.em_pend_base = 0;
  a.span_a = NULL;
  a.span_n = NULL;
  a.span_seg = NULL;
  a.nspans = 0;
  a.span_cap = 0;
  a.emit_prev = -1;

  if (NULL != relpath || NULL != hexpath)
    {
      a.em_cap = 8192;
      a.em_byte = (u8 *)malloc ((size_t)a.em_cap);
      a.em_rel = (u8 *)malloc ((size_t)a.em_cap);
      a.em_tbase = (u8 *)malloc ((size_t)a.em_cap);
      a.span_cap = 1024;
      a.span_a = (u16 *)malloc ((size_t)a.span_cap * sizeof (u16));
      a.span_n = (u16 *)malloc ((size_t)a.span_cap * sizeof (u16));
      a.span_seg = (u8 *)malloc ((size_t)a.span_cap * sizeof (u8));

      if (NULL == a.em_byte || NULL == a.em_rel || NULL == a.em_tbase
          || NULL == a.span_a || NULL == a.span_n || NULL == a.span_seg)
        { /* out of memory: degrade to no object output */
          if (NULL != a.em_byte)
            FREE (a.em_byte);

          if (NULL != a.em_rel)
            FREE (a.em_rel);

          if (NULL != a.em_tbase)
            FREE (a.em_tbase);

          if (NULL != a.span_a)
            FREE (a.span_a);

          if (NULL != a.span_n)
            FREE (a.span_n);

          if (NULL != a.span_seg)
            FREE (a.span_seg);

          a.em_cap = 0;
          a.span_cap = 0;
        }
    }

  a.img_min = 0;
  a.img_max = 0;
  a.errors = 0;

  /*
   * Assemble each independent module as its own two-pass unit so forward
   * references resolve within their module, streaming each module's object
   * record framing into the shared object file(s).  Modules are separated by
   * .PRGEND ("library file generation"); a file with no .PRGEND is a single
   * module, byte-identical to the original single-pass-pair driver.
   */
  {
    int nmod = count_modules (srcpath);
    int modidx;
    FILE *relf = NULL;
    FILE *hexf = NULL;

    if (NULL != relpath)
      {
        relf = obj_open (relpath);

        if (NULL == relf)
          (void)fprintf (stderr, "cannot write '%s'\n", relpath);
      }

    if (NULL != hexpath)
      {
        hexf = obj_open (hexpath);

        if (NULL == hexf)
          (void)fprintf (stderr, "cannot write '%s'\n", hexpath);
      }

    for (modidx = 0; modidx < nmod; modidx++)
      {
        if (modidx > 0)
          { /* a fresh module: discard the previous module's symbol table */
            sym_free (a.syms);
            a.syms = sym_new ();
          }

        init_pass (&a, 1);
        process_module (&a, srcpath, modidx);

        /*
         * error-counting pre-pass (a third pass, distinct number so the
         * label-redefinition `seen' logic still treats it as a fresh pass):
         * with the symbols all defined, this detects every error -- including
         * undefined references, which pass 1 tolerates -- so the PASM page
         * header can show the total before the body listing.  It lists nothing
         * and emits no object/image.
         */
        a.errs_hdr = 0;
        a.errs_mdef = 0;
        a.errs_finsert = 0;
        init_pass (&a, 3);
        a.count_only = 1;
        process_module (&a, srcpath, modidx);
        a.count_only = 0;

        /*
         * Both dialects precede the body listing with a leading report page
         * that lists only the multiply-defined (`M') and nested-.INSERT (`F')
         * statements (pass-1 faults the body would otherwise bury).  Run it
         * only when such errors exist, as its own pass (distinct number 4 so
         * the `seen' redefinition logic treats it as fresh and does not
         * collide with the body pass); it lists just those lines and emits no
         * object/image.  The body pass's own header then begins page 2.
         * (PASM's leading page omits the subtitle; ZASM keeps it -- see
         * lst_header.)
         */
        if ((a.errs_mdef + a.errs_finsert) > 0 && NULL != a.lst)
          {
            init_pass (&a, 4);
            a.mdef_page = 1;
            lst_header (&a);
            process_module (&a, srcpath, modidx);
            a.mdef_page = 0;
          }

        /*
         * the page-1 heading prints the module name and (for .XLINK) omits the
         * subtitle, but neither .IDENT nor .XLINK is seen until pass 2 reads
         * the body -- carry both learned in the prior pass across the pass-2
         * reset so the first heading is correct
         */
        {
          char modsave[8];
          int xlsave = a.obj_xlink;
          (void)xstrlcpy (modsave, a.modname, sizeof (modsave));
          init_pass (&a, 2);
          (void)xstrlcpy (a.modname, modsave, sizeof (a.modname));
          a.obj_xlink = xlsave;
        }
        lst_header (&a);
        process_module (&a, srcpath, modidx);

        /* this module's object records (-R binary REL, -X ASCII REL) */
        if (a.img_any && (NULL != relf || NULL != hexf))
          {
            objspec os;
            int nsym = sym_count (a.syms);
            objsym *exts = (objsym *)malloc ((size_t)(nsym > 0 ? nsym : 1)
                                             * sizeof (objsym));
            objsym *ints = (objsym *)malloc ((size_t)(nsym > 0 ? nsym : 1)
                                             * sizeof (objsym));
            objsym *ents = (objsym *)malloc ((size_t)(nsym > 0 ? nsym : 1)
                                             * sizeof (objsym));
            /* the `&' .PSYM record also lists the 3 segment bases */
            objsym *psyms = (objsym *)malloc (((size_t)nsym + 3)
                                              * sizeof (objsym));

            os.nexts = 0;
            os.nints = 0;
            os.nents = 0;
            os.npsyms = 0;
            os.psym = 0;
            os.psyms = psyms;

            if (NULL != exts && NULL != ints && NULL != ents)
              collect_obj_syms (a.syms, exts, &os.nexts, ints, &os.nints, ents,
                                &os.nents);

            if (a.obj_psym && NULL != psyms)
              {
                collect_psyms (a.syms,
                               (a.obj_org_used ? 0u : (unsigned)a.seg_hw[1]),
                               (unsigned)a.seg_hw[2], (unsigned)a.seg_hw[3],
                               psyms, &os.npsyms);
                os.psym = 1;
              }

            os.modname = a.modname;
            os.exts = exts;
            os.ints = ints;
            os.ents = ents;
            os.em_byte = a.em_byte;
            os.em_rel = a.em_rel;
            os.em_tbase = a.em_tbase;
            os.span_a = a.span_a;
            os.span_n = a.span_n;
            os.span_seg = a.span_seg;
            os.nspans = a.nspans;
            /*
             * .PROG. size = the LC high-water (segment span incl. any trailing
             * reservation).  An explicit .LOC/ORG pins the code absolutely, so
             * the segment then reports size 0, matching the originals.
             */
            os.prog_size = (a.obj_org_used ? 0u : a.seg_hw[1]);
            os.data_size = a.seg_hw[2];
            os.blnk_size = a.seg_hw[3];
            os.abs_mode = a.obj_abs;
            /*
             * data-record base: .PROG.-relative (1) unless an explicit origin
             * pinned the code absolutely (0)
             */
            os.data_base = (a.obj_org_used ? 0 : 1);
            os.start = a.obj_start;
            os.start_reloc = a.obj_start_rel;
            os.emit_progid = (DIALECT_PASM == dialect);
            os.xlink = a.obj_xlink;

            if (NULL != relf)
              {
                os.ascii = 0;
                obj_module (relf, &os);
              }

            if (NULL != hexf)
              {
                os.ascii = 1;
                obj_module (hexf, &os);
              }

            if (NULL != exts)
              FREE (exts);

            if (NULL != ints)
              FREE (ints);

            if (NULL != ents)
              FREE (ents);

            if (NULL != psyms)
              FREE (psyms);
          }

        /*
         * each module lists its own symbol table at its end, on a fresh page
         * (.XSYM/.XPSYM suppress it); for a single-module file this is the
         * one closing table, unchanged from before
         */
        if (a.lst_ctl & LSTC_SYM)
          lst_symtab (&a);
      }

    /* relf/hexf are non-NULL only when relpath/hexpath are; check the paths
     * explicitly anyway so the error message's deref is provably guarded */
    if (NULL != relpath && NULL != relf && 0 != obj_close (relf))
      (void)fprintf (stderr, "cannot write '%s'\n", relpath);

    if (NULL != hexpath && NULL != hexf && 0 != obj_close (hexf))
      (void)fprintf (stderr, "cannot write '%s'\n", hexpath);
  }

  /*
   * Both dialects emit a trailing "N Errors Were Detected *****" line when
   * there are errors (PASM mixed-case, ZASM upper-case; PASM also shows the
   * count in every page header).  With no errors, keep the clone's own
   * "%d error(s)" line (the project listing-compare strips it).
   */
  if (a.errors <= 0)
    (void)fprintf (a.lst, "\n%d error(s)\n", a.errors);
  else if (DIALECT_PASM == dialect)
    (void)fprintf (a.lst, "%d Errors Were Detected *****\n", a.errors);
  else
    (void)fprintf (a.lst, "%d ERRORS WERE DETECTED *****\n", a.errors);

  /* with -l to a real file, also report the count on the console */
  if (NULL != lf)
    (void)fprintf (stderr, "%d error(s)\n", a.errors);

  /*
   * -o absolute image: the object records were already streamed per module
   * above; the in-memory image holds the last module assembled (for the common
   * single-module file, that is the whole program).
   */
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

  if (NULL != a.em_tbase)
    FREE (a.em_tbase); /* cppcheck-suppress doubleFree */

  if (NULL != a.span_a)
    FREE (a.span_a); /* cppcheck-suppress doubleFree */

  if (NULL != a.span_n)
    FREE (a.span_n); /* cppcheck-suppress doubleFree */

  if (NULL != a.span_seg)
    FREE (a.span_seg); /* cppcheck-suppress doubleFree */

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
