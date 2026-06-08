/*
 * ASM - TDL/Phoenix ZASM/PASM compatible assembler
 * Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
 * SPDX-License-Identifier: MIT-0
 * scspell-id: 4c0746bc-6335-11f1-b123-246e96298730
 */

/******************************************************************************/

/*
 * lex.c - line lexer for the TDL/PSA clone.
 *
 * A statement is:  [label:] [operator [operands]] [;comment]   (free-format).
 * A label is an identifier terminated by ':'.  A direct assignment is
 * `symbol = expr` or `symbol EQU/SET/DEFL expr` (no colon).  Otherwise the
 * leading identifier is the operator (mnemonic or pseudo-op).
 */

/******************************************************************************/

#include <ctype.h>
#include <string.h>
#include "asm.h"

/******************************************************************************/

/* The Ch lint cat's all sources into one unit; rename file-local helpers that
 * clash with the same-named ones in expr.c. */
#ifdef _CH_
# undef  skipws
# define skipws  lex_skipws
# undef  idstart
# define idstart lex_idstart
# undef  idchar
# define idchar  lex_idchar
#endif

/******************************************************************************/

static int idstart(int c)
{
    return isalpha(c) || c == '_' || c == '?' || c == '@'
        || c == '.' || c == '%';
}
static int idchar(int c)
{
    return isalnum(c) || c == '_' || c == '?' || c == '@'
        || c == '.' || c == '$' || c == '%';
}

/******************************************************************************/

static const char *skipws(const char *p)
{
    while (*p == ' ' || *p == '\t') p++;
    return p;
}

/******************************************************************************/

static const char *parse_id(const char *p, char *out)
{
    int n = 0;
    while (idchar((unsigned char)*p)) {
        if (n < NAMEBUF - 1) out[n++] = *p;
        p++;
    }
    out[n] = '\0';
    return p;
}

/******************************************************************************/

void lex_line(const char *line, line_t *out)
{
    const char *p = skipws(line);
    out->label[0] = '\0';
    out->op[0] = '\0';
    out->operands = p;
    out->assign = 0;
    if (*p == '\0' || *p == ';') return;

    if (idstart((unsigned char)*p)) {
        char tok1[NAMEBUF];
        const char *q = parse_id(p, tok1);
        const char *r = skipws(q);

        if (*r == ':') {                         /* label: */
            /* False positive CWE-120: out->label[NAMEBUF] >= tok1
             * (parse_id caps NAMEBUF-1) */
            (void)strcpy(out->label, tok1);  /* Flawfinder: ignore */
            r = skipws(r + 1);
            if (idstart((unsigned char)*r)) r = parse_id(r, out->op);
            out->operands = skipws(r);
            return;
        }
        if (*r == '=') {                         /* symbol = / == expr */
            /* False positive CWE-120: out->label[NAMEBUF] >= tok1
             * (parse_id caps NAMEBUF-1) */
            (void)strcpy(out->label, tok1);  /* Flawfinder: ignore */
            (void)strcpy(out->op, "=");
            out->assign = 1;
            r++;
            if (*r == '=') r++;       /* '==' entry/global assignment */
            out->operands = skipws(r);
            return;
        }
        if (idstart((unsigned char)*r)) {        /* symbol EQU/SET expr ? */
            char tok2[NAMEBUF];
            const char *s = parse_id(r, tok2);
            if (strcmp(tok2, "EQU") == 0 || strcmp(tok2, "SET") == 0 ||
                strcmp(tok2, "DEFL") == 0) {
                /* False positive CWE-120: out->label[NAMEBUF] >= tok1,
                 * out->op[NAMEBUF] >= tok2 (parse_id caps NAMEBUF-1) */
                (void)strcpy(out->label, tok1);  /* Flawfinder: ignore */
                (void)strcpy(out->op, tok2);  /* Flawfinder: ignore */
                out->assign = 1;
                out->operands = skipws(s);
                return;
            }
        }
        /* operator, no label; false positive CWE-120:
         * out->op[NAMEBUF] >= tok1 */
        (void)strcpy(out->op, tok1);  /* Flawfinder: ignore */
        out->operands = r;
        return;
    }
    /* out->operands already points at p (set above) */
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
