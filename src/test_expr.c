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

int allow_long_symbols;

/******************************************************************************/

#include <stdio.h>
#include <string.h>

/******************************************************************************/

#include "asm.h"
#include "platform.h"

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

  allow_long_symbols = 0;
  e.radix = radix;

  if (expr_eval (expr, &e, &v, &err))
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
    (void)printf ("ok    %-12s = %u (0x%04X) r%ld b%d\n", expr, v.value,
                  v.value, v.reloc, v.base);
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
  /*LINTED: E_FUNC_SET_NOT_USED*/
  const char *arch = sysarch (); /* cppcheck-suppress unreadVariable */
#endif

  symtab *t = sym_new ();
  symbol *s;

  s = sym_intern (t, "X"); /* .PROG.-relative (base 1) */
  s->defined = 1;
  s->val.value = 0x100;
  s->val.reloc = 1;
  s->val.base = 1;
  s = sym_intern (t, "Y");
  s->defined = 1;
  s->val.value = 0x200;
  s->val.reloc = 1;
  s->val.base = 1;
  s = sym_intern (t, "Z");
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
  s = sym_intern (t, "A");
  s->defined = 1;
  s->val.value = 5;
  s = sym_intern (t, "B");
  s->defined = 1;
  s->val.value = 3;
  s = sym_intern (t, "E");
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
  check ("0", 10, 0, 0);
  check ("0FFH", 10, 255, 0);
  check ("1010B", 10, 10, 0);
  check ("2+3*4", 10, 14, 0);
  check ("2*3&6", 10, 4, 0);
  check ("1<2+3", 10, 7, 0);
  check ("100H-1", 10, 255, 0);
  check ("10", 16, 0x10, 0);

  /* TDL/PSA logical operators: ^ XOR, # unary NOT, & AND, ! OR, < > shifts */
  check ("5^3", 10, 6, 0);     /* exclusive OR                     */
  check ("#5", 10, 0xFFFA, 0); /* unary NOT (one's complement)     */
  check ("#0", 10, 0xFFFF, 0);
  check ("#5+1", 10, 0xFFFB, 0); /* # binds tighter than + : (#5)+1 */
  check ("1+#0", 10, 0x0000, 0); /* 1 + 0xFFFF, truncated           */
  check ("5^#0", 10, 0xFFFA, 0); /* 5 XOR 0xFFFF                     */
  check ("5!2", 10, 7, 0);       /* inclusive OR                     */
  check ("5&3", 10, 1, 0);       /* AND                              */

  /* ^X radix prefix: the number must begin with a numeral (^H0FF, not ^HFF) */
  check ("^H0FF", 10, 0x00FF, 0);
  check ("^B101", 10, 5, 0);
  check ("^O17", 10, 15, 0);

  /* symbols + relocation (manual worked examples) */
  check ("X", 10, 0x100, 1);
  check ("X+Y-Z", 10, 0x000, 1); /* relocatable */
  check ("X-Z", 10, 0xFE00, 0);  /* absolute    */
  check ("X+7", 10, 0x107, 1);
  check ("3*X-Y-Z", 10, 0xFE00, 1); /* 0x300-0x200-0x300, reloc 3-1-1=1 */
  check ("A+B", 10, 8, 0);
  check (".", 10, 0x40, 1); /* location counter */
  check (".+2", 10, 0x42, 1);

  /* multi-segment relocation bases (.DATA. base 2, .BLNK. base 3) */
  check_seg ("D1", 0x80, 1, 2);     /* .DATA.-relative          */
  check_seg ("D1+5", 0x85, 1, 2);   /* .DATA. + constant        */
  check ("D1-D2", 10, 0xFFF0, 0);   /* same base cancels -> abs */
  check_seg ("BK+1", 0x11, 1, 3);   /* .BLNK.-relative          */
  check_seg ("X+(D1-D2)", 0xF0, 1, 1); /* T+(V-W): base 1 result */

  /* predefined base symbols resolve to the live per-segment high-water */
  {
    static const u16 hw[4] = { 0, 0x10, 0x20, 0x30 };
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
  check_ext ("E", 0, "E");
  check_ext ("E+5", 5, "E");
  check_ext ("5+E", 5, "E");

  /* illegal combinations */
  check_err ("X+Y"); /* reloc coeff 2 */
  check_err ("-X");  /* reloc coeff -1 */
  check_err ("X*Y"); /* two relocatables multiplied */
  check_err ("X/2"); /* relocatable divided */
  check_err ("X&1"); /* relocatable logical */
  check_err ("E*2"); /* external in multiply */
  check_err ("E+X"); /* external with relocatable */
  check_err ("E-E"); /* two externals */
  check_err ("D1+X"); /* different relocation bases (.DATA. + .PROG.) */
  check_err ("D1-X"); /* different relocation bases */
  check_err ("BK+X"); /* different relocation bases (.BLNK. + .PROG.) */
  check_err ("2*D1"); /* relocatable coefficient 2 */

  {
    symbol *buf[64];
    value_t v2;
    const char *endp2, *err2;
    int n = sym_count (t);
    sym_collect (t, buf);

    if (9 != n || NULL == buf[0])
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
