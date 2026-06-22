/*
 * TPZASM: TDL ZASM / PSA PASM compatible assembler - lex.c
 * Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
 * SPDX-License-Identifier: MIT-0
 * scspell-id: 4c0746bc-6335-11f1-b123-246e96298730
 */

/******************************************************************************/

/*
 * A statement is:  [label:] [operator [operands]] [;comment]   (free-format).
 * A label is an identifier terminated by ':'.
 * A direct assignment is `symbol = expr`,
 * or `symbol EQU/SET/DEFL expr` (no colon).
 * Otherwise the leading identifier is the operator (mnemonic or pseudo-op).
 */

/******************************************************************************/

#include "asm.h"
#include <ctype.h>
#include <string.h>

/******************************************************************************/

#ifdef _CH_
# undef skipws
# define skipws lex_skipws
# undef idstart
# define idstart lex_idstart
# undef idchar
# define idchar lex_idchar
#endif

/******************************************************************************/

static int
idstart (int c)
{ /*
   * symbols use only the Radix-40 set (A-Z 0-9 $ % .); _ ? @ are NOT in it
   * -- '_' flags a macro subscript reference, '@' is the remainder operator.
   * A symbol may START with any of these but a digit (a leading digit is a
   * number); '$' is an ordinary symbol char, not the location counter ('.')
   */
  return isalpha (c) || '$' == c || '.' == c || '%' == c;
}

/******************************************************************************/

static int
idchar (int c)
{
  return isalnum (c) || '.' == c || '$' == c || '%' == c;
}

/******************************************************************************/

static const char *
skipws (const char *p)
{
  while (' ' == *p || '\t' == *p)
    p++;

  return p;
}

/******************************************************************************/

static const char *
parse_id (const char *p, char *out)
{
  int n = 0;

  while (idchar ((unsigned char)*p))
    {
      if (n < NAMEBUF - 1)
        out[n++] = *p;

      p++;
    }

  out[n] = '\0';

  return p;
}

/******************************************************************************/

void
lex_line (const char *line, line_t *out)
{
  const char *p = skipws (line);

  out->label[0] = '\0';
  out->op[0] = '\0';
  out->operands = p;
  out->assign = 0;
  out->internal = 0;

  if ('\0' == *p || ';' == *p)
    return;

  if (idstart ((unsigned char)*p))
    {
      char tok1[NAMEBUF];
      const char *q = parse_id (p, tok1);
      const char *r = skipws (q);

      if (':' == *r)
        { /* label:  (or `label::' -- the internal-definition delimiter) */
          (void)xstrlcpy (out->label, tok1, sizeof (out->label));
          r++;

          if (':' == *r)
            { /* `::' declares the label internal (== .INTERN label) */
              out->internal = 1;
              r++;
            }

          r = skipws (r);

          if (idstart ((unsigned char)*r))
            r = parse_id (r, out->op);

          out->operands = skipws (r);

          return;
        }

      if ('=' == *r)
        { /* symbol = / == expr  (a trailing `:' makes the symbol internal) */
          (void)xstrlcpy (out->label, tok1, sizeof (out->label));
          (void)xstrlcpy (out->op, "=", sizeof (out->op));
          out->assign = 1;
          r++;

          if ('=' == *r)
            r++; /* '==' entry/global assignment */

          if (':' == *r)
            { /* `=:' / `==:' declares the symbol internal (== .INTERN sym) */
              out->internal = 1;
              r++;
            }

          out->operands = skipws (r);

          return;
        }

      if (idstart ((unsigned char)*r) && '.' != tok1[0])
        { /*
           * symbol EQU/SET expr ?  Only when the first token is a plain symbol:
           * a dot-prefixed directive is never an assignment target, so
           * `.WORD SET' is the data directive with the mnemonic `SET' as its
           * operand (value 0C0CBH), not an assignment to a symbol `.WORD'.
           */
          char tok2[NAMEBUF];
          const char *s = parse_id (r, tok2);

          if (0 == strcmp (tok2, "EQU") || 0 == strcmp (tok2, "SET")
              || 0 == strcmp (tok2, "DEFL"))
            {
              (void)xstrlcpy (out->label, tok1, sizeof (out->label));
              (void)xstrlcpy (out->op, tok2, sizeof (out->op));
              out->assign = 1;
              out->operands = skipws (s);

              return;
            }
        }

      /*
       * operator, no label
       */

      (void)xstrlcpy (out->op, tok1, sizeof (out->op));
      out->operands = r;

      return;
    }

  /*
   * out->operands already points at p (set above)
   */
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
