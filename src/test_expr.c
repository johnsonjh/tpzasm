/*
 * TPZASM: TDL ZASM / PSA PASM compatible assembler - test_expr.c
 * Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
 * SPDX-License-Identifier: MIT-0
 * scspell-id: 6191fc20-6335-11f1-8e95-246e96298730
 */

/******************************************************************************/

/*
 * self-tests for the expression evaluator and relocation algebra.
 * Expected values are from the PSA/TDL manual semantics.
 */

/******************************************************************************/

#include "asm.h"

/******************************************************************************/

#include <stdio.h>
#include <string.h>

/******************************************************************************/

#ifdef __ORACLE_LINT__
# include "platform.h"
#endif

/******************************************************************************/

int allow_long_symbols;

/******************************************************************************/

static int fails = 0;
static eval_env ENV;

/******************************************************************************/

static void
check (const char *expr, int radix, u16 ev, long er)
{
  value_t v;
  const char *err;
  eval_env e = ENV;
  int rc;

  allow_long_symbols = 0;
  e.radix = radix;

  rc = expr_eval (expr, &e, &v, &err);
  if (rc && (!err || !strstr (err, "questionable number")))
    {
      (void)printf ("FAIL  %-12s -> ERROR (%s)\n", expr, err);
      fails++;
    }
  else if (v.value != ev || v.reloc != er || NULL != v.ext
           || v.base != (0 != er ? 1 : 0))
    {
      (void)printf ("FAIL  %-12s = %u r%ld b%d%s, want %u r%ld b%d\n", expr,
                    v.value, v.reloc, v.base, (v.ext ? " EXT" : ""), ev, er,
                    (0 != er ? 1 : 0));
      fails++;
    }
  else
    (void)printf ("ok    %-12s = %u (0x%04X) r%ld b%d%s\n", expr, v.value,
                  v.value, v.reloc, v.base,
                  (rc ? " (Q)" : ""));
}

/******************************************************************************/

/* like check(), but asserts an explicit relocation base (for .DATA./.BLNK.) */
static void
check_seg (const char *expr, u16 ev, long er, int base)
{
  value_t v;
  const char *err;
  eval_env e = ENV;

  e.radix = 10;

  if (expr_eval (expr, &e, &v, &err))
    {
      (void)printf ("FAIL  %-12s -> ERROR (%s)\n", expr, err);
      fails++;
    }
  else if (v.value != ev || v.reloc != er || v.base != base || NULL != v.ext)
    {
      (void)printf ("FAIL  %-12s = %u r%ld b%d, want %u r%ld b%d\n", expr,
                    v.value, v.reloc, v.base, ev, er, base);
      fails++;
    }
  else
    (void)printf ("ok    %-12s = %u (0x%04X) r%ld b%d\n", expr, v.value,
                  v.value, v.reloc, v.base);
}

/******************************************************************************/

static void
check_ext (const char *expr, u16 ev, const char *extname)
{
  value_t v;
  const char *err;
  eval_env e = ENV;

  e.radix = 10;

  if (expr_eval (expr, &e, &v, &err))
    {
      (void)printf ("FAIL  %-12s -> ERROR (%s)\n", expr, err);
      fails++;
    }
  else if (v.value != ev || NULL == v.ext
           || 0 != strcmp (v.ext->name, extname))
    {
      (void)printf ("FAIL  %-12s external mismatch\n", expr);
      fails++;
    }
  else
    (void)printf ("ok    %-12s = %u ext %s\n", expr, v.value, extname);
}

/******************************************************************************/

static void
check_err (const char *expr)
{
  value_t v;
  const char *err;
  eval_env e = ENV;

  e.radix = 10;

  if (expr_eval (expr, &e, &v, &err))
    (void)printf ("ok    %-12s -> rejected (%s)\n", expr, err);
  else
    {
      (void)printf ("FAIL  %-12s should be illegal, got %u r%ld\n", expr,
                    v.value, v.reloc);
      fails++;
    }
}

/******************************************************************************/

int
main (void)
{
#ifdef __ORACLE_LINT__
# ifdef HAVE_SYSARCH
  /*LINTED: E_FUNC_SET_NOT_USED*/
  const char *arch = sysarch (); /* cppcheck-suppress unreadVariable */
# endif
#endif

  symtab *t = sym_new ();
  symbol *s;

  /*
   * Synthetic symbols for the relocation algebra.  Their names deliberately
   * avoid the register letters (B C D E H L M A SP PSW X Y), which the
   * assembler reserves as predefined register values -- a register name can
   * never be a user symbol (see reg_sym_val in expr.c), so it would shadow any
   * injected entry of the same name.
   */
  s = sym_intern (t, "SYMX"); /* .PROG.-relative (base 1) */
  s->defined = 1;
  s->val.value = 0x100;
  s->val.reloc = 1;
  s->val.base = 1;
  s = sym_intern (t, "SYMY");
  s->defined = 1;
  s->val.value = 0x200;
  s->val.reloc = 1;
  s->val.base = 1;
  s = sym_intern (t, "SYMZ");
  s->defined = 1;
  s->val.value = 0x300;
  s->val.reloc = 1;
  s->val.base = 1;
  s = sym_intern (t, "D1"); /* .DATA.-relative (base 2) */
  s->defined = 1;
  s->val.value = 0x80;
  s->val.reloc = 1;
  s->val.base = 2;
  s = sym_intern (t, "D2");
  s->defined = 1;
  s->val.value = 0x90;
  s->val.reloc = 1;
  s->val.base = 2;
  s = sym_intern (t, "BK"); /* .BLNK.-relative (base 3) */
  s->defined = 1;
  s->val.value = 0x10;
  s->val.reloc = 1;
  s->val.base = 3;
  s = sym_intern (t, "ABSA");
  s->defined = 1;
  s->val.value = 5;
  s = sym_intern (t, "ABSB");
  s->defined = 1;
  s->val.value = 3;
  s = sym_intern (t, "EXTE");
  s->external = 1; /* external, undefined */

  ENV.radix = 10;
  ENV.syms = t;
  ENV.lc = 0x40;
  ENV.lc_reloc = 1;
  ENV.lc_base = 1;
  ENV.seg_hw = NULL;
  ENV.undef0 = 0;
  ENV.scope = 0;

  /* constants */
  check ("0",      10, 0,    0);
  check ("0FFH",   10, 255,  0);
  check ("1010B",  10, 10,   0);
  check ("2+3*4",  10, 14,   0);
  check ("2*3&6",  10, 4,    0);
  check ("1<2+3",  10, 7,    0);
  check ("100H-1", 10, 255,  0);
  check ("10",     16, 0x10, 0);


  /*
   * Number parsing quirks (bug-for-bug compat): premature stop on first
   * out-of-range "digit" (unless it triggers a valid suffix), with
   * suffix rules, fallback only when the bad digit would be valid in
   * "ambient" radix, dot handling, case insensitivity, and garbage
   * alphanum acceptance.  This table is intended to be exhaustive over
   * the key permutations of radices, suffix letters (B/D/H/O/Q) in
   * trailing/internal positions, dots, leading zeros, etc.
   */

  check ("100B101B",     10, 4,  0);
  check ("7Q6Q",         10, 7,  0);
  check ("9D8D",         10, 9,  0);
  check ("9.8.",         10, 9,  0);
  check ("0AHCH",        10, 10, 0);
  check ("19DABZUW1234", 10, 19, 0);
  check ("100B101",      2,  4,  0);
  check ("7Q6",          8,  7,  0);
  check ("9D8",          10, 9,  0);
  check ("0AHC",         16, 10, 0);

  /* more trailing suffix per radix */
  check ("101B", 10, 5,   0);
  check ("101b", 10, 5,   0);
  check ("77Q",  10, 63,  0);
  check ("77q",  10, 63,  0);
  check ("0FFH", 10, 255, 0);
  check ("0ffh", 10, 255, 0);
  check ("12D",  10, 12,  0);
  check ("12d",  10, 12,  0);

  /* internal bad under default, value = prefix before first bad */
  check ("100B1", 10, 100, 0); /* no trailing suffix; B internal -> "100"=100 */
  check ("19DAB", 10, 19,  0); /* stops before D ->19 */
  check ("19D",   10, 19,  0);

  /* rad-specific from report + perms */
  check ("100B101", 2, 4,  0);
  check ("10102",   2, 10, 0); /* under rad2: "1010" (trunc before 2) = 10 */
  check ("1010",    2, 10, 0);
  check ("77Q8",    8, 63, 0);
  check ("77O",     8, 63, 0);

  /* fallback vs keep-suffixed-rad */
  check ("0BD",  10, 0,    0);
  check ("0BDH", 10, 0xbd, 0);
  check ("0BD",  16, 0xbd, 0);
  check ("0BDH", 16, 0xbd, 0);

  /* dots permutations */
  check ("12.",    10, 12, 0);
  check ("1.2",    10, 1,  0);
  check ("5.",     10, 5,  0);
  check ("1.2.3.", 10, 1,  0);

  /* high-radix ending B/D without H (guard + omit-H rule) */
  check ("0AB",    16, 0xab, 0);
  check ("0ABH",   16, 0xab, 0);
  check ("0AHB",   16, 10,   0);
  check ("01BH1B", 16, 0x1b, 0);

  /* other letters inside (non-suffix) cause early stop */
  check ("1A2", 10, 1,    0);
  check ("1G",  10, 1,    0);
  check ("0F1", 16, 0xf1, 0); /* "0F1" all valid under 16 */
  check ("0G1", 16, 0,    0);

  /* 0 and edge */
  check ("0B",  10, 0,  0);
  check ("0H",  10, 0,  0);
  check ("0",   16, 0,  0);
  check ("10H", 10, 16, 0);

  /* lowercase full */
  check ("100b101b", 10, 4,    0);
  check ("0ahch",    10, 10,   0);
  check ("2+3*4",    10, 14,   0);
  check ("2*3&6",    10, 4,    0);
  check ("1<2+3",    10, 7,    0);
  check ("100H-1",   10, 255,  0);
  check ("10",       16, 0x10, 0);

  /* TDL/PSA logical operators: ^ XOR, # unary NOT, & AND, ! OR, < > shifts */
  check ("5^3",  10, 6,      0); /* exclusive OR                    */
  check ("#5",   10, 0xFFFA, 0); /* unary NOT (one's complement)    */
  check ("#0",   10, 0xFFFF, 0);
  check ("#5+1", 10, 0xFFFB, 0); /* # binds tighter than + : (#5)+1 */
  check ("1+#0", 10, 0x0000, 0); /* 1 + 0xFFFF, truncated           */
  check ("5^#0", 10, 0xFFFA, 0); /* 5 XOR 0xFFFF                    */
  check ("5!2",  10, 7,      0); /* inclusive OR                    */
  check ("5&3",  10, 1,      0); /* AND                             */

  /*
   * Binary shifts < > (level 3).  The count is a 16-bit two's-complement
   * value: a magnitude of 16 or more shifts every bit out (-> 0, NOT a
   * modulo-16 wrap of the count) and a negative count reverses the shift
   * direction (manual "Binary Shifting": 2>-1 == 1<2 == 4).  The right shift
   * is logical (no sign extension).  Every value byte-exact vs PASM 1.02,
   * ZASM 2.21, and PASM 2.00G; see tests/shift.asm for info.
   */
  check ("1<0",         10, 0x0001, 0);
  check ("1<1",         10, 0x0002, 0);
  check ("1<2",         10, 0x0004, 0);
  check ("1<14",        10, 0x4000, 0);
  check ("1<15",        10, 0x8000, 0);
  check ("1<16",        10, 0x0000, 0); /* >=16 -> 0 (wrap would give 1) */
  check ("1<17",        10, 0x0000, 0); /* (wrap would give 2) */
  check ("1<31",        10, 0x0000, 0);
  check ("1<32",        10, 0x0000, 0); /* (wrap would give 1) */
  check ("0FFFFH<4",    10, 0xFFF0, 0); /* truncated to 16 bits */
  check ("8>1",         10, 0x0004, 0);
  check ("8000H>1",     10, 0x4000, 0);
  check ("0FFFFH>1",    10, 0x7FFF, 0); /* logical (arith. would give FFFF) */
  check ("8000H>15",    10, 0x0001, 0);
  check ("8000H>16",    10, 0x0000, 0); /* >=16 -> 0 */
  check ("0FFFFH>16",   10, 0x0000, 0);
  check ("0FFFFH>17",   10, 0x0000, 0);
  check ("2>-1",        10, 0x0004, 0); /* negative reverses dir: 2<1 */
  check ("1<-1",        10, 0x0000, 0); /* 1>1 */
  check ("8000H<-1",    10, 0x4000, 0); /* 8000H>1 */
  check ("1>-1",        10, 0x0002, 0); /* 1<1 */
  check ("1>-15",       10, 0x8000, 0); /* 1<15 */
  check ("1>-16",       10, 0x0000, 0); /* 1<16: magnitude 16 -> 0 */
  check ("8>-2",        10, 0x0020, 0); /* 8<2 */
  check ("8000H<-15",   10, 0x0001, 0);
  check ("8000H<-16",   10, 0x0000, 0); /* magnitude 16 -> 0 */
  check ("1<-16",       10, 0x0000, 0); /* 1>16 -> 0 */
  check ("1<-17",       10, 0x0000, 0);
  check ("1<100H",      10, 0x0000, 0); /* count 256 -> 0 (full 16-bit) */
  check ("0FFFFH>100H", 10, 0x0000, 0);
  check ("1<7FFFH",     10, 0x0000, 0); /* largest positive count -> 0 */
  check ("1<8000H",     10, 0x0000, 0); /* -32768: magnitude >= 16 -> 0 */
  check ("1>8000H",     10, 0x0000, 0);
  check ("1<-0FFFFH",   10, 0x0002, 0); /* -0FFFFH == 1 (positive): 1<1 */

  /* ^X radix prefix: the number must begin with a numeral (^H0FF, not ^HFF) */
  check ("^H0FF", 10, 0x00FF, 0);
  check ("^B101", 10, 5,      0);
  check ("^O17",  10, 15,     0);

  /* symbols + relocation (manual worked examples) */
  check ("SYMX",             10, 0x100,  1);
  check ("SYMX+SYMY-SYMZ",   10, 0x000,  1); /* relocatable */
  check ("SYMX-SYMZ",        10, 0xFE00, 0); /* absolute    */
  check ("SYMX+7",           10, 0x107,  1);
  check ("3*SYMX-SYMY-SYMZ", 10, 0xFE00, 1); /* 0x300-0x200-0x300, reloc 1 */
  check ("ABSA+ABSB",        10, 8,      0);
  check (".",                10, 0x40,   1); /* location counter */
  check (".+2",              10, 0x42,   1);

  /* multi-segment relocation bases (.DATA. base 2, .BLNK. base 3) */
  check_seg ("D1",           0x80, 1,      2); /* .DATA.-relative          */
  check_seg ("D1+5",         0x85, 1,      2); /* .DATA. + constant        */
  check ("D1-D2",            10,   0xFFF0, 0); /* same base cancels -> abs */
  check_seg ("BK+1",         0x11, 1,      3); /* .BLNK.-relative          */
  check_seg ("SYMX+(D1-D2)", 0xF0, 1,      1); /* T+(V-W): base 1 result   */

  /* predefined base symbols resolve to the live per-segment high-water */
  {
    static const u16 hw [4] = { 0, 0x10, 0x20, 0x30 };
    value_t v;
    const char *err;
    eval_env e = ENV;
    e.radix = 10;
    e.seg_hw = hw;

    if (expr_eval (".DATA.+2", &e, &v, &err) || 0x22 != v.value || 1 != v.reloc
        || 2 != v.base || NULL != v.ext)
      {
        (void)printf ("FAIL  .DATA.+2 base symbol\n");
        fails++;
      }
    else
      (void)printf ("ok    .DATA.+2 = 0x%04X r%ld b%d\n", v.value, v.reloc,
                    v.base);
  }

  /* externals (additive only) */
  check_ext ("EXTE",   0, "EXTE");
  check_ext ("EXTE+5", 5, "EXTE");
  check_ext ("5+EXTE", 5, "EXTE");

  /* illegal combinations */
  check_err ("SYMX+SYMY"); /* reloc coeff 2                                */
  check_err ("-SYMX");     /* reloc coeff -1                               */
  check_err ("SYMX*SYMY"); /* two relocatables multiplied                  */
  check_err ("SYMX/2");    /* relocatable divided                          */
  check_err ("SYMX&1");    /* relocatable logical                          */
  check_err ("EXTE*2");    /* external in multiply                         */
  check_err ("EXTE+SYMX"); /* external with relocatable                    */
  check_err ("EXTE-EXTE"); /* two externals                                */
  check_err ("D1+SYMX");   /* different relocation bases (.DATA. + .PROG.) */
  check_err ("D1-SYMX");   /* different relocation bases                   */
  check_err ("BK+SYMX");   /* different relocation bases (.BLNK. + .PROG.) */
  check_err ("2*D1");      /* relocatable coefficient 2                    */

  {
    symbol *buf [64];
    value_t v2;
    const char *endp2, *err2;
    int n = sym_count (t);
    sym_collect (t, buf);

    if (9 != n || NULL == buf [0])
      {
        (void)printf ("FAIL  sym_count/collect (n=%d)\n", n);
        fails++;
      }
    else if (expr_eval2 ("1+2;", &ENV, &v2, &endp2, &err2, NULL)
             || 3 != v2.value || ';' != *endp2)
      {
        (void)printf ("FAIL  expr_eval2\n");
        fails++;
      }
    else
      (void)printf ("ok    sym/eval2 API  = 9 syms, eval2 ok\n");
  }

  sym_free (t);

  (void)printf ("\n%s (%d failure%s)\n",
                (fails ? "TESTS FAILED" : "ALL TESTS PASSED"), fails,
                (1 == fails ? "" : "s"));

  return (fails ? 1 : 0);
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
