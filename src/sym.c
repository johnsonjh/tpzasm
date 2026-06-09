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
#include <stdlib.h>
#include <string.h>

/******************************************************************************/

#include "asm.h"

/******************************************************************************/

int
ci_eq (const char *a, const char *b)
{
  while (*a != '\0'
         && toupper ((unsigned char)*a) == toupper ((unsigned char)*b))
    {
      a++;
      b++;
    }

  return *a == '\0' && *b == '\0';
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
    {
      h = h * 33u + (unsigned char)toupper ((unsigned char)*s++);
    }

  return h;
}

/******************************************************************************/

symtab *
sym_new (void)
{
  symtab *t = (symtab *)malloc (sizeof *t);
  int i;

  if (t == NULL)
    {
      return NULL;
    }

  t->nbuckets = 1024;
  t->count = 0;
  t->bucket = (symbol **)malloc (sizeof (symbol *) * (unsigned)t->nbuckets);

  if (t->bucket == NULL)
    {
      free (t);
      return NULL;
    }

  for (i = 0; i < t->nbuckets; i++)
    {
      t->bucket[i] = NULL;
    }

  return t;
}

/******************************************************************************/

symbol *
sym_lookup (const symtab *t, const char *name)
{
  symbol *s;

  if (t == NULL)
    {
      return NULL;
    }

  for (s = t->bucket[hash (name) % (unsigned)t->nbuckets]; s != NULL;
       s = s->next)
    {
      if (ci_eq (s->name, name))
        {
          return s;
        }
    }

  return NULL;
}

/******************************************************************************/

symbol *
sym_intern (symtab *t, const char *name)
{
  unsigned idx;
  symbol *s;

  if (t == NULL)
    {
      return NULL;
    }

  s = sym_lookup (t, name);

  if (s != NULL)
    {
      return s;
    }

  idx = hash (name) % (unsigned)t->nbuckets;
  s = (symbol *)malloc (sizeof *s);

  if (s == NULL)
    {
      return NULL;
    }

  s->name = (char *)malloc (strlen (name) + 1);

  if (s->name == NULL)
    {
      free (s);
      return NULL;
    }

  /* False positive CWE-120: s->name = malloc(strlen(name)+1) */
  (void)strcpy (s->name, name); /* Flawfinder: ignore */

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

  if (t == NULL)
    {
      return;
    }

  for (i = 0; i < t->nbuckets; i++)
    {
      s = t->bucket[i];

      while (s != NULL)
        {
          nx = s->next;
          free (s->name);
          free (s);
          s = nx;
        }
    }

  free (t->bucket);
  free (t);
}

/******************************************************************************/

int
sym_count (const symtab *t)
{
  return (t != NULL) ? t->count : 0;
}

/******************************************************************************/

void
sym_collect (const symtab *t, symbol **buf)
{
  int i, n = 0;
  symbol *s;

  if (t == NULL)
    {
      return;
    }

  for (i = 0; i < t->nbuckets; i++)
    {
      for (s = t->bucket[i]; s != NULL; s = s->next)
        {
          buf[n++] = s;
        }
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
