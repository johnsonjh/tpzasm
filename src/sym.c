/*
 * TPZASM: TDL ZASM / PSA PASM compatible assembler - sym.c
 * Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
 * SPDX-License-Identifier: MIT-0
 * scspell-id: 5a50d972-6335-11f1-96f6-246e96298730
 */

/******************************************************************************/

/*
 * sym.c - symbol table (hash table with chaining) for the assembler clone.
 * Names are matched case-insensitively (TDL folds case for symbols).
 */

/******************************************************************************/

#include <ctype.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>

/******************************************************************************/

#include "asm.h"

/******************************************************************************/

extern int allow_long_symbols;

/******************************************************************************/

int
ci_eq (const char *a, const char *b)
{
  while ('\0' != *a
         && toupper ((unsigned char)*a) == toupper ((unsigned char)*b))
    {
      a++;
      b++;
    }

  return '\0' == *a && '\0' == *b;
}

/******************************************************************************/

size_t
xstrlcpy (char *dst, const char *src, size_t cap)
{
  size_t i = 0;

  if (0 != cap)
    {
      while (i + 1 < cap && '\0' != src[i])
        {
          dst[i] = src[i];
          i++;
        }

      dst[i] = '\0';
    }

  while ('\0' != src[i])
    i++;

  return i;
}

/******************************************************************************/

size_t
xstrlcat (char *dst, const char *src, size_t cap)
{
  size_t dl = 0;
  size_t i = 0;
  size_t w;

  while (dl < cap && '\0' != dst[dl])
    dl++;

  if (dl == cap)
    {
      while ('\0' != src[i])
        i++;

      return cap + i;
    }

  w = dl;

  while ('\0' != src[i])
    {
      if (w + 1 < cap)
        dst[w++] = src[i];

      i++;
    }

  dst[w] = '\0';

  return dl + i;
}

/******************************************************************************/

int
xsnprintf (char *dst, size_t cap, const char *fmt, ...)
{
  va_list ap;
  size_t n = 0;
  const char *f = fmt;

  va_start (ap, fmt);

  while ('\0' != *f)
    {
      if ('%' != *f)
        {
          if (n + 1 < cap)
            dst[n] = *f;

          n++;
          f++;

          continue;
        }

      f++;

      {
        int zero = 0;
        int width = 0;

        while ('0' == *f)
          {
            zero = 1;
            f++;
          }

        while (*f >= '0' && *f <= '9')
          {
            width = width * 10 + (*f - '0');
            f++;
          }

        switch (*f)
          {
          case 's':
            {
              const char *s = va_arg (ap, const char *);

              while ('\0' != *s)
                {
                  if (n + 1 < cap)
                    dst[n] = *s;

                  n++;
                  s++;
                }
            }

            break;

          case 'c':
            {
              int c = va_arg (ap, int);

              if (n + 1 < cap)
                dst[n] = (char)c;

              n++;
            }

            break;

          case 'u':
          case 'X':
            {
              unsigned v = va_arg (ap, unsigned);
              unsigned base = (('X' == *f) ? 16u : 10u);
              char tmp[32];
              int t = 0;

              if (0 == v)
                tmp[t++] = '0';

              /*
               * base is always 10 or 16, never 0
               * old cppcheck zerodivcond is a false positive
               */

              while (0 != v)
                {
                  unsigned d = v % base; /* cppcheck-suppress zerodivcond */
                  int dc = ((d < 10u) ? ('0' + (int)d) : ('A' + (int)d - 10));
                  tmp[t++] = (char)dc;
                  v /= base;
                }

              while (t < width)
                tmp[t++] = (char)((zero) ? '0' : ' ');

              while (t > 0)
                {
                  t--;

                  if (n + 1 < cap)
                    dst[n] = tmp[t];

                  n++;
                }
            }

            break;

          case '%':
            if (n + 1 < cap)
              dst[n] = '%';

            n++;

            break;

          default:
            if (n + 1 < cap)
              dst[n] = '%';

            n++;

            if ('\0' != *f)
              {
                if (n + 1 < cap)
                  dst[n] = *f;

                n++;
              }

            break;
          }

        if ('\0' != *f)
          f++;
      }
    }

  if (0 != cap)
    dst[((n < cap) ? n : cap - 1)] = '\0';

  va_end (ap);

  if (0 == cap)
    return 0;

  return (int)((n < cap) ? n : cap - 1);
}

/******************************************************************************/

struct symtab
{
  symbol **bucket;
  int nbuckets;
  int count;
};

/******************************************************************************/

static unsigned
hash (const char *s)
{
  unsigned h = 5381u;

  while (*s)
    h = h * 33u + (unsigned char)toupper ((unsigned char)*s++);

  return h;
}

/******************************************************************************/

symtab *
sym_new (void)
{
  symtab *t = (symtab *)malloc (sizeof (*t));
  int i;

  if (NULL == t)
    return NULL;

  t->nbuckets = 1024;
  t->count = 0;
  t->bucket = (symbol **)malloc (sizeof (symbol *) * (unsigned)t->nbuckets);

  if (NULL == t->bucket)
    {
      FREE (t);

      return NULL;
    }

  for (i = 0; i < t->nbuckets; i++)
    t->bucket[i] = NULL;

  return t;
}

/******************************************************************************/

symbol *
sym_lookup (const symtab *t, const char *name)
{
  symbol *s;
  char buf[7];
  const char *n = name;

  if (NULL == t)
    return NULL;

  if (!allow_long_symbols && NULL == strchr (name, ':'))
    {
      (void)strncpy (buf, name, 6);
      buf[6] = '\0';
      n = buf;
    }

  for (s = t->bucket[hash (n) % (unsigned)t->nbuckets]; NULL != s;
       s = s->next)
    if (ci_eq (s->name, n))
      return s;

  return NULL;
}

/******************************************************************************/

symbol *
sym_intern (symtab *t, const char *name)
{
  unsigned idx;
  symbol *s;
  char buf[7];
  const char *n = name;

  if (NULL == t)
    return NULL;

  if (!allow_long_symbols && NULL == strchr (name, ':'))
    {
      (void)strncpy (buf, name, 6);
      buf[6] = '\0';
      n = buf;
    }

  s = sym_lookup (t, n);

  if (NULL != s)
    return s;

  idx = hash (n) % (unsigned)t->nbuckets;
  s = (symbol *)malloc (sizeof (*s));

  if (NULL == s)
    return NULL;

  s->name = (char *)malloc (strlen (n) + 1);

  if (NULL == s->name)
    {
      FREE (s);
      return NULL;
    }

  /*
   * Store the symbol name folded to upper case: both originals are
   * case-insensitive and print the symbol table in upper case (the body
   * listing still shows the label as typed, from the source line).
   * False positive CWE-120: s->name = malloc(strlen(n)+1).
   */

  {
    size_t k;

    for (k = 0; '\0' != n[k]; k++)
      s->name[k] = (char)toupper ((unsigned char)n[k]);

    s->name[k] = '\0';
  }

  s->val.value = 0;
  s->val.reloc = 0;
  s->val.ext = NULL;
  s->defined = 0;
  s->external = 0;
  s->seen = 0;
  s->next = t->bucket[idx];
  t->bucket[idx] = s;
  t->count++;

  return s;
}

/******************************************************************************/

void
sym_free (symtab *t)
{
  int i;
  symbol *s, *nx;

  if (NULL == t)
    return;

  for (i = 0; i < t->nbuckets; i++)
    {
      s = t->bucket[i];

      while (NULL != s)
        {
          nx = s->next;
          FREE (s->name);
          FREE (s);
          s = nx;
        }
    }

  FREE (t->bucket);
  FREE (t);
}
/******************************************************************************/

int
sym_count (const symtab *t)
{
  return ((NULL != t) ? t->count : 0);
}

/******************************************************************************/

void
sym_collect (const symtab *t, symbol **buf)
{
  int i, n = 0;
  symbol *s;

  if (NULL == t)
    return;

  for (i = 0; i < t->nbuckets; i++)
    for (s = t->bucket[i]; NULL != s; s = s->next)
      buf[n++] = s;
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
