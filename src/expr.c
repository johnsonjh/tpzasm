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
#include <stdio.h>

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
  while (*e->p == ' ' || *e->p == '\t')
    {
      e->p++;
    }
}

/******************************************************************************/

static value_t
mkabs (u16 v)
{
  value_t r;

  r.value = v;
  r.reloc = 0;
  r.ext = NULL;

  return r;
}

/******************************************************************************/

static int
digit_val (int c)
{
  if (c >= '0' && c <= '9')
    {
      return c - '0';
    }

  if (c >= 'A' && c <= 'F')
    {
      return c - 'A' + 10;
    }

  if (c >= 'a' && c <= 'f')
    {
      return c - 'a' + 10;
    }

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
        {
          buf[n++] = *p;
        }

      p++;
    }

  buf[n] = '\0';
  ndig = n;

  if (*p == '.')
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
          radix = 2;
          ndig = n - 1;
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
          radix = 10;
          ndig = n - 1;
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
{
  return isalpha (c) || c == '_' || c == '?' || c == '@' || c == '.'
         || c == '%';
}

/******************************************************************************/

static int
idchar (int c)
{
  return isalnum (c) || c == '_' || c == '?' || c == '@' || c == '.'
         || c == '$' || c == '%';
}

/******************************************************************************/

static value_t ev_addsub (ectx *e); /* forward */

/******************************************************************************/

static value_t
ev_primary (ectx *e)
{
  skipws (e);
  if (*e->p == '^')
    { /* TDL ^H/^D/^O/^B radix prefix */
      int c = toupper ((unsigned char)e->p[1]), rdx = 0;

      if (c == 'H')
        {
          rdx = 16;
        }
      else if (c == 'D')
        {
          rdx = 10;
        }
      else if (c == 'O' || c == 'Q')
        {
          rdx = 8;
        }
      else if (c == 'B')
        {
          rdx = 2;
        }

      if (rdx)
        {
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
    }

  if (*e->p == '\'')
    { /* character constant 'A' / 'AB' */
      u16 val = 0;
      e->p++;

      while (*e->p != '\0' && *e->p != '\'')
        {
          val = (u16)((val << 8) | (unsigned char)*e->p);
          e->p++;
        }

      if (*e->p == '\'')
        {
          e->p++;
        }
      else
        {
          efail (e, "unterminated character constant");
        }

      return mkabs (val);
    }

  if (*e->p == '(')
    {
      value_t v;
      e->p++;
      v = ev_addsub (e);
      skipws (e);

      if (*e->p == ')')
        {
          e->p++;
        }
      else
        {
          efail (e, "missing ')'");
        }

      return v;
    }

  if (isdigit ((unsigned char)*e->p))
    {
      return mkabs (scan_number (e));
    }

  if (idstart ((unsigned char)*e->p))
    {
      char name[IDBUF];
      int n = 0;
      symbol *s;

      while (idchar ((unsigned char)*e->p))
        {
          if (n < IDBUF - 1)
            {
              name[n++] = *e->p;
            }

          e->p++;
        }

      name[n] = '\0';

      if (name[0] == '.' && name[1] == '\0')
        { /* location counter */
          value_t r;
          r.value = e->env->lc;
          r.reloc = e->env->lc_reloc;
          r.ext = NULL;

          return r;
        }

      if (name[0] == '.' && name[1] == '.')
        { /* local: scope-qualify */
          char qn[IDBUF + 16];
          /* False positive CWE-120: qn[IDBUF+16] >= %u + ':' + name */
          (void)sprintf (qn, "%u:%s", /* Flawfinder: ignore */
                         e->env->scope, name);
          s = e->env->syms ? sym_lookup (e->env->syms, qn) : NULL;
        }
      else
        {
          s = e->env->syms ? sym_lookup (e->env->syms, name) : NULL;
        }

      if (s != NULL && s->external)
        {
          value_t r;
          r.value = 0;
          r.reloc = 0;
          r.ext = s;

          return r;
        }

      if (s == NULL || !s->defined)
        {
          if (e->env->undef0)
            {
              return mkabs (0); /* pass-1 tolerance */
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

  if (*e->p == '-')
    {
      value_t v;
      e->p++;
      v = ev_unary (e);

      if (v.ext)
        {
          efail (e, "external negated");
        }

      v.value = (u16)(0u - v.value);
      v.reloc = -v.reloc;

      return v;
    }

  if (*e->p == '+')
    {
      e->p++;

      return ev_unary (e);
    }

  return ev_primary (e);
}

/******************************************************************************/

/* / @ & ! ^ < > : both operands must be absolute */
static value_t
v_absop (ectx *e, value_t a, value_t b, int op)
{
  u16 x = a.value, y = b.value, v = 0;

  if (a.ext || b.ext || a.reloc != 0 || b.reloc != 0)
    {
      efail (e, "relocatable value in division/logical/shift");

      return mkabs (0);
    }

  switch (op)
    {
    case '/':
      if (y == 0)
        {
          efail (e, "divide by zero");

          return mkabs (0);
        }

      v = (u16)(x / y);
      break;

    case '@':
      if (y == 0)
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

      if (*e->p == '<')
        {
          op = '<';
        }
      else if (*e->p == '>')
        {
          op = '>';
        }
      else
        {
          return v;
        }

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

      if (*e->p == '&')
        {
          op = '&';
        }
      else if (*e->p == '!')
        {
          op = '!';
        }
      else if (*e->p == '^')
        {
          op = '^';
        }
      else
        {
          return v;
        }

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

  if (a.reloc != 0 && b.reloc != 0)
    {
      efail (e, "two relocatables multiplied");

      return r;
    }

  r.value = (u16)(a.value * b.value);
  r.reloc = (long)a.value * b.reloc + (long)b.value * a.reloc;
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
      if (*e->p == '*')
        {
          e->p++;
          r = ev_logical (e);
          v = v_mul (e, v, r);
        }
      else if (*e->p == '/')
        {
          e->p++;
          r = ev_logical (e);
          v = v_absop (e, v, r, '/');
        }
      else
        {
          return v;
        }
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
      if (*e->p == '@')
        {
          value_t r;
          e->p++;
          r = ev_muldiv (e);
          v = v_absop (e, v, r, '@');
        }
      else
        {
          return v;
        }
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
  long bn = sub ? -b.reloc : b.reloc;

  if (a.ext && b.ext)
    {
      efail (e, "two externals combined");
    }

  if (sub && b.ext)
    {
      efail (e, "external subtracted");
    }

  if ((a.ext && b.reloc != 0) || (b.ext && a.reloc != 0))
    {
      efail (e, "external with relocatable");
    }

  r.ext = a.ext ? a.ext : b.ext;
  r.reloc = a.reloc + bn;
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

      if (*e->p == '+')
        {
          e->p++;
          r = ev_rem (e);
          v = v_addsub (e, v, r, 0);
        }
      else if (*e->p == '-')
        {
          e->p++;
          r = ev_rem (e);
          v = v_addsub (e, v, r, 1);
        }
      else
        {
          return v;
        }
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
    {
      e.env = env;
    }
  else
    {
      def.radix = RADIX_DEFAULT;
      def.syms = NULL;
      def.lc = 0;
      def.lc_reloc = 0;
      def.undef0 = 0;
      e.env = &def;
    }

  e.p = s;
  e.err = 0;
  e.msg = "";
  v = ev_addsub (&e);

  if (!e.err && v.ext == NULL && v.reloc != 0 && v.reloc != 1)
    {
      efail (&e, "relocation error: coefficient not 0 or 1");
    }

  if (endp)
    {
      *endp = e.p;
    }

  if (e.err)
    {
      if (err)
        {
          *err = e.msg;
        }

      return 1;
    }

  *out = v;

  if (err)
    {
      *err = "";
    }

  return 0;
}

/******************************************************************************/

int
expr_eval (const char *s, const eval_env *env, value_t *out, const char **err)
{
  const char *endp;
  int rc = expr_eval2 (s, env, out, &endp, err);

  if (rc)
    {
      return rc;
    }

  while (*endp == ' ' || *endp == '\t')
    {
      endp++;
    }

  if (*endp != '\0')
    {
      if (err)
        {
          *err = "trailing characters";
        }

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
