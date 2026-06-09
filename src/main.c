/*
 * TPZASM: TDL ZASM / PSA PASM compatible assembler - main.c
 * Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
 * SPDX-License-Identifier: MIT-0
 * scspell-id: 528d6ba6-6335-11f1-a96f-246e96298730
 */

/******************************************************************************/

/*
 * asm - portable ANSI C89 reimplementation of the TDL ZASM / PSA PASM
 * CP/M Z80 macro assemblers.  CLI shell; the engine lives in assemble.c.
 */

/******************************************************************************/

#include <stdio.h>
#include <string.h>
#include "asm.h"

/******************************************************************************/

static const char *basename_of(const char *p)
{
    const char *b = p;
    const char *s;
    for (s = p; *s != '\0'; ++s)
        if (*s == '/' || *s == '\\') b = s + 1;
    return b;
}

/******************************************************************************/

static dialect_t dialect_from_name(const char *argv0)
{
    const char *b = basename_of(argv0);
    if (strncmp(b, "pasm", 4) == 0) return DIALECT_PASM;
    return DIALECT_ZASM;
}

/******************************************************************************/

static void usage(const char *prog)
{
    (void)fprintf(stderr,
        "TPZASM - TDL ZASM / PSA PASM compatible assembler\n"
        "usage: %s [options] SOURCE.ASM\n"
        "  -p       Emulate PSA PASM behavior\n"
        "  -z       Emulate TDL ZASM behavior\n"
        "  -o file  write the assembled binary image to file\n"
        "  -P       pad -o output to a 128-byte CP/M record boundary\n"
        "  -l file  write the listing to file (default: stderr)\n"
        "  -r file  read assembly-time console-prompt answers from file\n"
        "  -e expr  evaluate single expression and exit\n"
        "  -h       show this help text\n",
        prog);
}

/******************************************************************************/

int main(int argc, char **argv)
{
    const char *prog = basename_of(argv[0]);
    dialect_t dialect = dialect_from_name(argv[0]);
    const char *src = NULL;
    const char *outpath = NULL;
    const char *lstpath = NULL;
    int pad = 0;
    int i;

    for (i = 1; i < argc; ++i) {
        const char *a = argv[i];
        if (a[0] == '-' && a[1] != '\0' && a[2] == '\0') {
            switch (a[1]) {
            case 'p': dialect = DIALECT_PASM; break;
            case 'z': dialect = DIALECT_ZASM; break;
            case 'P': pad = 1; break;
            case 'h': usage(prog); return 0;
            case 'o':
                if (i + 1 >= argc) {
                    (void)fprintf(stderr, "%s: -o needs a filename\n", prog);
                    return 2;
                }
                outpath = argv[++i];
                break;
            case 'l':
                if (i + 1 >= argc) {
                    (void)fprintf(stderr, "%s: -l needs a filename\n", prog);
                    return 2;
                }
                lstpath = argv[++i];
                break;
            case 'r':
                /* Take answers to the '\' console prompts from a file instead
                 * of the terminal (a "response file"); equivalent to piping. */
                if (i + 1 >= argc) {
                    (void)fprintf(stderr, "%s: -r needs a filename\n", prog);
                    return 2;
                }
                if (freopen(argv[++i], "r", stdin) == NULL) {
                    (void)fprintf(stderr,
                                  "%s: cannot open response file '%s'\n",
                                  prog, argv[i]);
                    return 2;
                }
                break;
            case 'e': {
                value_t v;
                const char *eerr;
                eval_env env;
                if (i + 1 >= argc) {
                    (void)fprintf(stderr, "%s: -e needs an expression\n", prog);
                    return 2;
                }
                env.radix = RADIX_DEFAULT;
                env.syms = NULL;
                env.lc = 0;
                env.lc_reloc = 0;
                env.undef0 = 0;
                env.scope = 0;
                if (expr_eval(argv[++i], &env, &v, &eerr)) {
                    (void)fprintf(stderr, "%s: -e: %s\n", prog, eerr);
                    return 1;
                }
                (void)printf("%u (0x%04X)%s\n",
                       (unsigned)v.value, (unsigned)v.value,
                       v.reloc ? " [relocatable]" : "");
                return 0;
            }
            default:
                (void)fprintf(stderr, "%s: unknown option '%s'\n", prog, a);
                usage(prog);
                return 2;
            }
        } else {
            src = a;
        }
    }

    if (src == NULL) {
        usage(prog);
        return 2;
    }
    return asm_source(src, dialect, outpath, lstpath, pad);
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
