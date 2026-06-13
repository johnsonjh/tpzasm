/*
 * TPZASM: TDL ZASM / PSA PASM compatible assembler - expr.c
 * Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
 * SPDX-License-Identifier: MIT-0
 * scspell-id: 1b70129a-6335-11f1-80c5-246e96298730
 */

/******************************************************************************/

/*
 * Expression evaluator with relocation; Grammar/precedence per PSA/TDL
 * documentation "Numbers" / "Arithmetic and Logical Operations".
 * Relocation algebra per "Addressing and Relocation" section.
 */

/******************************************************************************/

#include <ctype.h>

/******************************************************************************/

#include "asm.h"

/******************************************************************************/

#define IDBUF 64

/******************************************************************************/

#ifdef _CH_
# undef skipws
# define skipws expr_skipws
# undef idstart
# define idstart expr_idstart
# undef idchar
# define idchar expr_idchar
#endif

/******************************************************************************/

typedef struct
{
  const char *p;
  int err;
  const char *msg;
  const eval_env *env;
} ectx;

/******************************************************************************/

static void
efail (ectx *e, const char *m)
{
  if (!e->err)
    {
      e->err = 1;
      e->msg = m;
    }
}

/******************************************************************************/

static void
skipws (ectx *e)
{
  while (' ' == *e->p || '\t' == *e->p)
    e->p++;
}

/******************************************************************************/

static value_t
mkabs (u16 v)
{
  value_t r;

  r.value = v;
  r.reloc = 0;
  r.base = 0;
  r.ext = NULL;

  return r;
}

/******************************************************************************/

static int
digit_val (int c)
{
  if (c >= '0' && c <= '9')
    return c - '0';

  if (c >= 'A' && c <= 'F')
    return c - 'A' + 10;

  if (c >= 'a' && c <= 'f')
    return c - 'a' + 10;

  return -1;
}

/******************************************************************************/

static u16
scan_number (ectx *e)
{
  const char *p = e->p;
  char buf[80];
  int n = 0, radix = e->env->radix, ndig, i;
  unsigned long val = 0;

  while (isalnum ((unsigned char)*p))
    {
      if (n < (int)sizeof (buf) - 1)
        buf[n++] = *p;

      p++;
    }

  buf[n] = '\0';
  ndig = n;

  if ('.' == *p)
    {
      radix = 10;
      p++;
    }
  else if (n > 0)
    {
      switch (buf[(long)n - 1])
        {
        case 'H':
        case 'h':
          radix = 16;
          ndig = n - 1;
          break;

        case 'B':
        case 'b':
          if (e->env->radix <= 11) /* 'B' is a digit at radix 12+ (hex) */
            {
              radix = 2;
              ndig = n - 1;
            }
          break;

        case 'O':
        case 'o':
        case 'Q':
        case 'q':
          radix = 8;
          ndig = n - 1;
          break;

        case 'D':
        case 'd':
          if (e->env->radix <= 13) /* 'D' is a digit at radix 14+ (hex) */
            {
              radix = 10;
              ndig = n - 1;
            }
          break;

        default:
          break;
        }
    }

  if (ndig <= 0)
    {
      efail (e, "malformed number");

      return 0;
    }

  /*
   * If a stripped radix suffix yields invalid digits, the trailing letter
   * was actually a digit of the current radix (e.g. 0BD = 0xBD in radix 16,
   * not a decimal "0B" with a 'D' suffix).  Fall back to the current radix.
   */

  if (ndig < n)
    {
      int ok = 1;

      for (i = 0; i < ndig; i++)
        {
          int d = digit_val ((unsigned char)buf[i]);

          if (d < 0 || d >= radix)
            {
              ok = 0;
              break;
            }
        }

      if (!ok)
        {
          radix = e->env->radix;
          ndig = n;
        }
    }

  for (i = 0; i < ndig; i++)
    {
      int d = digit_val ((unsigned char)buf[i]);

      if (d < 0 || d >= radix)
        {
          efail (e, "bad digit for radix");

          return 0;
        }

      val = val * (unsigned long)radix + (unsigned long)d;
    }

  e->p = p;

  return (u16)val;
}

/******************************************************************************/

static int
idstart (int c)
{ /* symbols use only the Radix-40 set (A-Z 0-9 $ % .); _ ? @ are NOT in it
     -- '_' flags a macro subscript reference, '@' is the remainder operator */
  return isalpha (c) || '.' == c || '%' == c;
}

/******************************************************************************/

static int
idchar (int c)
{
  return isalnum (c) || '.' == c || '$' == c || '%' == c;
}

/******************************************************************************/

static value_t ev_addsub (ectx *e); /* forward */

/******************************************************************************/

static value_t
ev_primary (ectx *e)
{
  skipws (e);
  if ('^' == *e->p)
    { /* TDL ^H/^D/^O/^B radix prefix */
      int c = toupper ((unsigned char)e->p[1]), rdx = 0;

      if ('H' == c)
        rdx = 16;
      else if ('D' == c)
        rdx = 10;
      else if ('O' == c || 'Q' == c)
        rdx = 8;
      else if ('B' == c)
        rdx = 2;

      if (rdx && isdigit ((unsigned char)e->p[2]))
        { /* a number in the prefixed radix -- must begin with a numeral */
          unsigned long v = 0;
          e->p += 2;

          while (isalnum ((unsigned char)*e->p))
            {
              int d = digit_val ((unsigned char)*e->p);

              if (d < 0 || d >= rdx)
                {
                  efail (e, "bad digit for radix");
                  break;
                }

              v = v * (unsigned long)rdx + (unsigned long)d;
              e->p++;
            }

          return mkabs ((u16)v);
        }

      if (rdx)
        { /*
           * a radix prefix not followed by a numeral: the originals require a
           * number to begin with a digit, so the prefix is consumed and what
           * follows parses as an ordinary symbol (e.g. `^HF' -> symbol `F',
           * `^H0FF' is the way to write hex FF).
           */
          e->p += 2;
        }
    }

  if ('!' == *e->p && '[' == e->p[1] && NULL != e->env->temps)
    { /*
       * `![sub]' -- a PSA .TEMPS local temporary.  Legal only inside a macro
       * (tmp_ok); the subscript must be an absolute value in [0, ntemps).  An
       * illegal use or out-of-range subscript is a Subscript (`S') error.
       */
      value_t idx;
      int sub;

      e->p += 2; /* consume "![" */
      idx = ev_addsub (e);
      skipws (e);

      if (']' == *e->p)
        e->p++;
      else
        efail (e, "missing ']'");

      sub = (int)idx.value; /* idx.value is a u16, so always >= 0 */

      if (!e->env->tmp_ok || 0 != idx.reloc || NULL != idx.ext
          || sub >= e->env->ntemps)
        {
          efail (e, "subscript");

          return mkabs (0);
        }

      return e->env->temps[sub];
    }

  if ('\'' == *e->p)
    { /* character constant 'A' / 'AB' */
      u16 val = 0;
      e->p++;

      while ('\0' != *e->p && '\'' != *e->p)
        {
          val = (u16)((val << 8) | (unsigned char)*e->p);
          e->p++;
        }

      if ('\'' == *e->p)
        e->p++;
      else
        efail (e, "unterminated character constant");

      return mkabs (val);
    }

  if ('(' == *e->p)
    {
      value_t v;
      e->p++;
      v = ev_addsub (e);
      skipws (e);

      if (')' == *e->p)
        e->p++;
      else
        efail (e, "missing ')'");

      return v;
    }

  if (isdigit ((unsigned char)*e->p))
    return mkabs (scan_number (e));

  if (idstart ((unsigned char)*e->p))
    {
      char name[IDBUF];
      int n = 0;
      symbol *s;

      while (idchar ((unsigned char)*e->p))
        {
          if (n < IDBUF - 1)
            name[n++] = *e->p;

          e->p++;
        }

      name[n] = '\0';

      if ('.' == name[0] && '\0' == name[1])
        { /* location counter */
          value_t r;
          r.value = e->env->lc;
          r.reloc = e->env->lc_reloc;
          r.base = (e->env->lc_reloc ? e->env->lc_base : 0);
          r.ext = NULL;

          return r;
        }

      if (ci_eq (name, ".PROG.") || ci_eq (name, ".DATA.")
          || ci_eq (name, ".BLNK."))
        { /* predefined segment base: value = the segment's live high-water */
          value_t r;
          int b = (ci_eq (name, ".PROG.") ? 1 : (ci_eq (name, ".DATA.") ? 2
                                                                        : 3));
          r.value = (e->env->seg_hw ? e->env->seg_hw[b] : 0);
          r.reloc = 1;
          r.base = b;
          r.ext = NULL;

          return r;
        }

      if ('.' == name[0] && '.' == name[1])
        { /* local: scope-qualify */
          char qn[IDBUF + 16];
          (void)xsnprintf (qn, sizeof (qn), "%u:%s", e->env->scope, name);
          s = (e->env->syms ? sym_lookup (e->env->syms, qn) : NULL);
        }
      else
        s = (e->env->syms ? sym_lookup (e->env->syms, name) : NULL);

      if ('#' == *e->p && '.' != name[0] && NULL != e->env->syms)
        { /*
           * the `SYM#' symbol modifier: declare SYM external, exactly as a
           * preceding `.EXTERN SYM' would (the originals assign an external
           * base number on first encounter, in declaration order).  Consume
           * the `#'; the existing external branch below then resolves it.
           */
          e->p++;

          if (NULL == s)
            s = sym_intern (e->env->syms, name);

          if (NULL != s && !s->external && !s->defined
              && NULL != e->env->ext_next)
            {
              s->external = 1;
              s->val.value = 0;
              s->val.reloc = 0;
              s->val.base = (*e->env->ext_next)++;
              s->val.ext = NULL;
              s->udef = 0;

              if (NULL != e->env->ext_decl)
                s->decl = (unsigned short)(*e->env->ext_decl)++;
            }
        }

      if (NULL != s && s->external)
        { /* external symbol: relative to its assigned external base (>=4) */
          value_t r;
          r.value = 0;
          r.reloc = 1;
          r.base = s->val.base;
          r.ext = s;

          return r;
        }

      if (NULL == s || !s->defined)
        {
          if (e->env->undef0)
            return mkabs (0); /* pass-1 tolerance */

          /*
           * a genuinely undefined reference: record it in the symbol table so
           * the listing can show it with the `U' flag, as the originals do.
           */
          if (NULL != e->env->syms)
            {
              symbol *u;

              if ('.' == name[0] && '.' == name[1])
                {
                  char qn[IDBUF + 16];
                  (void)xsnprintf (qn, sizeof (qn), "%u:%s", e->env->scope,
                                   name);
                  u = sym_intern (e->env->syms, qn);
                }
              else
                u = sym_intern (e->env->syms, name);

              if (NULL != u)
                u->udef = 1;
            }

          efail (e, "undefined symbol");

          return mkabs (0);
        }

      return s->val;
    }

  efail (e, "expected a value");

  return mkabs (0);
}

/******************************************************************************/

static value_t
ev_unary (ectx *e)
{
  skipws (e);

  if ('-' == *e->p)
    {
      value_t v;
      e->p++;
      v = ev_unary (e);

      if (v.ext)
        efail (e, "external negated");

      v.value = (u16)(0u - v.value);
      v.reloc = -v.reloc;

      return v;
    }

  if ('+' == *e->p)
    {
      e->p++;

      return ev_unary (e);
    }

  if ('#' == *e->p)
    { /* logical unary NOT (one's complement); absolute operand only */
      value_t v;
      e->p++;
      v = ev_unary (e);

      if (v.ext || 0 != v.reloc)
        {
          efail (e, "relocatable value in division/logical/shift");

          return mkabs (0);
        }

      return mkabs ((u16)(~v.value));
    }

  return ev_primary (e);
}

/******************************************************************************/

/* / @ & ! ^ < > : both operands must be absolute */
static value_t
v_absop (ectx *e, value_t a, value_t b, int op)
{
  u16 x = a.value, y = b.value, v = 0;

  if (a.ext || b.ext || 0 != a.reloc || 0 != b.reloc)
    {
      efail (e, "relocatable value in division/logical/shift");

      return mkabs (0);
    }

  switch (op)
    {
    case '/':
      if (0 == y)
        {
          efail (e, "divide by zero");

          return mkabs (0);
        }

      v = (u16)(x / y);
      break;

    case '@':
      if (0 == y)
        {
          efail (e, "remainder by zero");

          return mkabs (0);
        }

      v = (u16)(x % y);
      break;

    case '&':
      v = (u16)(x & y);
      break;

    case '!':
      v = (u16)(x | y);
      break;

    case '^':
      v = (u16)(x ^ y);
      break;

    case '<':
      v = (u16)(x << (y & 15));
      break;

    case '>':
      v = (u16)(x >> (y & 15));
      break;

    default:
      break;
    }

  return mkabs (v);
}

/******************************************************************************/

static value_t
ev_shift (ectx *e) /* level 3 */
{
  value_t v = ev_unary (e);

  for (;;)
    {
      int op;
      value_t r;
      skipws (e);

      if ('<' == *e->p)
        op = '<';
      else if ('>' == *e->p)
        op = '>';
      else
        return v;

      e->p++;
      r = ev_unary (e);
      v = v_absop (e, v, r, op);
    }

#ifdef _CH_
  /*NOTREACHED*/ /* unreachable */
  return v;
#endif
}

/******************************************************************************/

static value_t
ev_logical (ectx *e) /* level 4: & ! ^ */
{
  value_t v = ev_shift (e);

  for (;;)
    {
      int op;
      value_t r;
      skipws (e);

      if ('&' == *e->p)
        op = '&';
      else if ('!' == *e->p)
        op = '!';
      else if ('^' == *e->p)
        op = '^';
      else
        return v;

      e->p++;
      r = ev_shift (e);
      v = v_absop (e, v, r, op);
    }

#ifdef _CH_
  /*NOTREACHED*/ /* unreachable */
  return v;
#endif
}

/******************************************************************************/

static value_t
v_mul (ectx *e, value_t a, value_t b)
{
  value_t r = mkabs (0);

  if (a.ext || b.ext)
    {
      efail (e, "external in multiply");

      return r;
    }

  if (0 != a.reloc && 0 != b.reloc)
    {
      efail (e, "two relocatables multiplied");

      return r;
    }

  r.value = (u16)(a.value * b.value);
  r.reloc = (long)a.value * b.reloc + (long)b.value * a.reloc;
  /* the (at most one) relocatable operand carries the base into the product */
  r.base = ((0 != r.reloc) ? (a.reloc ? a.base : b.base) : 0);
  r.ext = NULL;

  return r;
}

/******************************************************************************/

static value_t
ev_muldiv (ectx *e) /* level 5 */
{
  value_t v = ev_logical (e);

  for (;;)
    {
      value_t r;
      skipws (e);

      if ('*' == *e->p)
        {
          e->p++;
          r = ev_logical (e);
          v = v_mul (e, v, r);
        }
      else if ('/' == *e->p)
        {
          e->p++;
          r = ev_logical (e);
          v = v_absop (e, v, r, '/');
        }
      else
        return v;
    }

#ifdef _CH_
  /*NOTREACHED*/ /* unreachable */
  return v;
#endif
}

/******************************************************************************/

static value_t
ev_rem (ectx *e) /* level 6 */
{
  value_t v = ev_muldiv (e);

  for (;;)
    {
      skipws (e);

      if ('@' == *e->p)
        {
          value_t r;
          e->p++;
          r = ev_muldiv (e);
          v = v_absop (e, v, r, '@');
        }
      else
        return v;
    }

#ifdef _CH_
  /*NOTREACHED*/ /* unreachable */
  return v;
#endif
}

/******************************************************************************/

static value_t
v_addsub (ectx *e, value_t a, value_t b, int sub)
{
  value_t r;
  long bn = (sub ? -b.reloc : b.reloc);

  if (a.ext && b.ext)
    efail (e, "two externals combined");

  if (sub && b.ext)
    efail (e, "external subtracted");

  if ((a.ext && 0 != b.reloc) || (b.ext && 0 != a.reloc))
    efail (e, "external with relocatable");

  /* two relocatable operands must share a base; the only legal mixed-base
   * combination is one that cancels (same base, opposite coefficients). */
  if (0 != a.reloc && 0 != b.reloc && a.base != b.base)
    efail (e, "different relocation bases");

  r.ext = (a.ext ? a.ext : b.ext);
  r.reloc = a.reloc + bn;
  r.base = ((0 == r.reloc) ? 0 : (a.reloc ? a.base : b.base));
  r.value = (u16)(sub ? a.value - b.value : a.value + b.value);

  return r;
}

/******************************************************************************/

static value_t
ev_addsub (ectx *e) /* level 7 (entry) */
{
  value_t v = ev_rem (e);

  for (;;)
    {
      value_t r;
      skipws (e);

      if ('+' == *e->p)
        {
          e->p++;
          r = ev_rem (e);
          v = v_addsub (e, v, r, 0);
        }
      else if ('-' == *e->p)
        {
          e->p++;
          r = ev_rem (e);
          v = v_addsub (e, v, r, 1);
        }
      else
        return v;
    }

#ifdef _CH_
  /*NOTREACHED*/ /* unreachable */
  return v;
#endif
}

/******************************************************************************/

int
expr_eval2 (const char *s, const eval_env *env, value_t *out,
            const char **endp, const char **err)
{
  ectx e;
  value_t v;
  eval_env def;

  if (env)
    e.env = env;
  else
    {
      def.radix = RADIX_DEFAULT;
      def.syms = NULL;
      def.lc = 0;
      def.lc_reloc = 0;
      def.lc_base = 0;
      def.seg_hw = NULL;
      def.undef0 = 0;
      def.scope = 0;
      e.env = &def;
    }

  e.p = s;
  e.err = 0;
  e.msg = "";
  v = ev_addsub (&e);

  if (!e.err && NULL == v.ext && 0 != v.reloc && 1 != v.reloc)
    efail (&e, "relocation error: coefficient not 0 or 1");

  /* a relocatable result must resolve to one of the segment bases */
  if (!e.err && NULL == v.ext && 1 == v.reloc && (v.base < 1 || v.base > 3))
    efail (&e, "relocation error: no relocation base");

  if (endp)
    *endp = e.p;

  if (e.err)
    {
      if (err)
        *err = e.msg;

      *out = v; /* return the partial value -- the originals emit it on error */

      return 1;
    }

  *out = v;

  if (err)
    *err = "";

  return 0;
}

/******************************************************************************/

int
expr_eval (const char *s, const eval_env *env, value_t *out, const char **err)
{
  const char *endp;
  int rc = expr_eval2 (s, env, out, &endp, err);

  if (rc)
    return rc;

  while (' ' == *endp || '\t' == *endp)
    endp++;

  if ('\0' != *endp)
    {
      if (err)
        *err = "trailing characters";

      return 1;
    }

  return 0;
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
