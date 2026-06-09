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

#include "asm.h"
#include "platform.h"
#include "version.h"
#include <stdio.h>
#include <string.h>

/******************************************************************************/

static const char *
basename_of (const char *p)
{
  const char *b = p;
  const char *s;

  for (s = p; *s != '\0'; ++s)
    {
      if (*s == '/' || *s == '\\')
        {
          b = s + 1;
        }
    }

  return b;
}

/******************************************************************************/

static dialect_t
dialect_from_name (const char *argv0)
{
  const char *b = basename_of (argv0);

  if (strncmp (b, "pasm", 4) == 0)
    {
      return DIALECT_PASM;
    }

  return DIALECT_ZASM;
}

/******************************************************************************/

#if defined(__TIMESTAMP__) || defined(__DATE__) || defined(__TIME__)

# define TRIMSTR_SLOTS 3

static const char *
trimstr (const char *s)
{
  /* cppcheck-suppress constVariable */
  static char buf[TRIMSTR_SLOTS][1024];
  static int slot = 0;

  char *d;
  int in_ws = 0;

  if (s == 0)
    {
      return "";
    }

  slot = (slot + 1) % TRIMSTR_SLOTS;
  d = buf[slot];

  while (*s == ' ' || *s == '\t' || *s == '\n' || *s == '\r')
    {
      s++;
    }

  for (; *s != '\0'; s++)
    {
      if (*s == ' ' || *s == '\t' || *s == '\n' || *s == '\r')
        {
          in_ws = 1;

          continue;
        }

      if (in_ws)
        {
          *d++ = ' ';
          in_ws = 0;
        }

      *d++ = *s;
    }

  if (d > buf[slot] && d[-1] == ' ')
    {
      d--;
    }

  *d = '\0';

  return buf[slot];
}

#endif

/******************************************************************************/

static void
usage (const char *prog, dialect_t dialect)
{
  (void)fprintf (stderr,
                 "TPZASM - TDL ZASM / PSA PASM compatible assembler%s\n"
                 "Copyright (c) 2026 Jeffrey H. Johnson"
                 " <johnsonjh.dev@gmail.com>\n"
                 "%s%s%s%s%s%s",
                 platform_name (), ASM_VERSION,
#ifdef __TIMESTAMP__
                 " (",
# ifndef __clang__
                 ((*(__TIMESTAMP__)) ? trimstr (__TIMESTAMP__) : ""), "", "",
                 ")\n"
# else  /* ifndef __clang__ */
                 trimstr (__TIMESTAMP__), "", "", ")\n"
# endif /* ifndef __clang__ */
#else  /* ifdef __TIMESTAMP__ */
# if defined(__DATE__) && defined(__TIME__)
                 " (", ((*(__DATE__)) ? trimstr (__DATE__) : ""), " ",
                 ((*__TIME__) ? trimstr (__TIME__) : ""), ")\n"
# elif defined(__DATE__)
                 " (", ((*(__DATE__)) ? trimstr (__DATE__) : ""), "", "", ")\n"
# else  /* if defined( __DATE__ ) && defined( __TIME__ ) */
                 "", "", "", "", "\n"
# endif /* if defined( __DATE__ ) && defined( __TIME__ ) */
#endif /* ifdef __TIMESTAMP__ */
  );
  (void)fprintf (stderr,
                 "\n"
                 "  Usage: %s [options] <source[.asm]>\n\n"
                 "    -z       Emulate TDL ZASM 2.21 behavior%s\n"
                 "    -p       Emulate PSA PASM 1.0 behavior%s\n"
                 "    -o file  Write the assembled binary image to file\n"
                 "    -P       Pad output to full CP/M record boundary\n"
                 "    -l file  Write the listing to file (default: stderr)\n"
                 "    -r file  Answer assembly-time prompts from file\n"
                 "    -e expr  Evaluate single expression and exit\n"
                 "    -h       Show this help text and exit\n"
                 "\n",
                 prog, (dialect == DIALECT_ZASM ? " (default)" : ""),
                 (dialect == DIALECT_PASM ? " (default)" : ""));
}

/******************************************************************************/

int
main (int argc, char **argv)
{
  const char *prog = basename_of (argv[0]);
  dialect_t dialect = dialect_from_name (argv[0]);
  const char *src = NULL;
  const char *outpath = NULL;
  const char *lstpath = NULL;
  int pad = 0;
  int i;

  for (i = 1; i < argc; ++i)
    {
      const char *a = argv[i];
      if (a[0] == '-' && a[1] != '\0' && a[2] == '\0')
        {
          switch (a[1])
            {
            case 'p':
              dialect = DIALECT_PASM;
              break;

            case 'z':
              dialect = DIALECT_ZASM;
              break;

            case 'P':
              pad = 1;
              break;

            case 'h':
              usage (prog, dialect);
              return 0;

            case 'o':
              if (i + 1 >= argc)
                {
                  (void)fprintf (stderr, "%s: -o needs a filename\n", prog);
                  return 2;
                }

              outpath = argv[++i];
              break;

            case 'l':
              if (i + 1 >= argc)
                {
                  (void)fprintf (stderr, "%s: -l needs a filename\n", prog);
                  return 2;
                }

              lstpath = argv[++i];
              break;

            case 'r':
              /* Take answers to the '\' console prompts from a file instead
               * of the terminal (a "response file"); equivalent to piping. */
              if (i + 1 >= argc)
                {
                  (void)fprintf (stderr, "%s: -r needs a filename\n", prog);
                  return 2;
                }

              if (freopen (argv[++i], "r", stdin) == NULL)
                {
                  (void)fprintf (stderr,
                                 "%s: cannot open response file '%s'\n", prog,
                                 argv[i]);
                  return 2;
                }

              break;

            case 'e':
              {
                value_t v;
                const char *eerr;
                eval_env env;
                if (i + 1 >= argc)
                  {
                    (void)fprintf (stderr, "%s: -e needs an expression\n",
                                   prog);
                    return 2;
                  }

                env.radix = RADIX_DEFAULT;
                env.syms = NULL;
                env.lc = 0;
                env.lc_reloc = 0;
                env.undef0 = 0;
                env.scope = 0;
                if (expr_eval (argv[++i], &env, &v, &eerr))
                  {
                    (void)fprintf (stderr, "%s: -e: %s\n", prog, eerr);
                    return 1;
                  }

                (void)printf ("%u (0x%04X)%s\n", (unsigned)v.value,
                              (unsigned)v.value,
                              v.reloc ? " [relocatable]" : "");
                return 0;
              }

            default:
              (void)fprintf (stderr, "%s: unknown option '%s'\n", prog, a);
              usage (prog, dialect);
              return 2;
            }
        }
      else
        {
          src = a;
        }
    }

  if (src == NULL)
    {
      usage (prog, dialect);
      return 2;
    }

  return asm_source (src, dialect, outpath, lstpath, pad);
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
