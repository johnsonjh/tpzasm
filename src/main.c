/*
 * TPZASM: TDL ZASM / PSA PASM compatible assembler - main.c
 * Copyright (c) 2025-2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
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
#include <stdlib.h>
#include <string.h>

/******************************************************************************/

#include "asm.h"
#include "platform.h"
#include "version.h"

/******************************************************************************/

int allow_long_symbols;

/******************************************************************************/

#if defined(__atarist__) || defined(__atarist) || defined(atarist)
long _stksize = -1L;
#endif

/******************************************************************************/

#if defined(__VBCC__)
long __stack = 160 * 1024;
#endif

/******************************************************************************/

static const char *
basename_of (const char *p)
{
  const char *b = p;
  const char *s;

  for (s = p; '\0' != *s; ++s)
    if ('/' == *s || '\\' == *s)
      b = s + 1;

  return b;
}

/******************************************************************************/

static dialect_t
dialect_from_name (const char *argv0)
{
  const char *b = basename_of (argv0);

  /*
   * `m80' (the MACRO-80 simulation) is upcoming, uses the PASM 2.00G engine;
   * main() adds its `.ZOP'/`.EPOP' prefixes on top of the dialect
   * (see add_m80_preops).
   */

  if (0 == strncmp (b, "pasm2", 5) || 0 == strncmp (b, "m80", 3))
    return DIALECT_PASM2;

  if (0 == strncmp (b, "pasm", 4))
    return DIALECT_PASM;

  return DIALECT_ZASM;
}

/******************************************************************************/

#if defined(__DATE__) || defined(__TIME__)

# define TRIMSTR_SLOTS 3

static const char *
trimstr (const char *s)
{
  /* cppcheck-suppress constVariable */
  static char buf[TRIMSTR_SLOTS][1024];
  static int slot = 0;

  char *d;
  int in_ws = 0;

  if (0 == s)
    return "";

  slot = (slot + 1) % TRIMSTR_SLOTS;
  d = buf[slot];

  while (' ' == *s || '\t' == *s || '\n' == *s || '\r' == *s)
    s++;

  for (; '\0' != *s; s++)
    {
      if (' ' == *s || '\t' == *s || '\n' == *s || '\r' == *s)
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

  if (d > buf[slot] && ' ' == d[-1])
    d--;

  *d = '\0';

  return buf[slot];
}

#endif

/******************************************************************************/

static const char *osinfo(void)
{
  static char buf[1024];
  const char *name;
#ifdef HAVE_SYSARCH
  const char *arch;
#endif

  name = platform_name ();
#ifdef HAVE_SYSARCH
  arch = sysarch ();
#endif

  if (
#ifdef HAVE_SYSARCH
      NULL == arch &&
#endif
      NULL == name)
    return NULL;

  buf[0] = '(';
  buf[1] = '\0';

  /* cppcheck-suppress knownConditionTrueFalse */
  if (NULL != name)
    (void)strncat (buf, name, sizeof (buf) - strlen (buf) - 1);

#ifdef HAVE_SYSARCH
  if (NULL != arch && 1 < strlen (arch))
    {
      if (NULL != name)
        (void)strncat (buf, "/", sizeof (buf) - strlen (buf) - 1);

      (void)strncat (buf, arch, sizeof (buf) - strlen (buf) - 1);
    }
#endif

  (void)strncat (buf, ")", sizeof (buf) - strlen (buf) - 1);

  return buf;
}

/******************************************************************************/

static void
usage (const char *prog, dialect_t dialect, int version)
{
  (void)fprintf (stderr,
             "TPZASM - TDL ZASM / PSA PASM compatible 8080 / Z80 assembler %s\n"
             "%s%s%s%s%s%s"
             "Copyright (c) 2026 Jeffrey H. Johnson"
             " <johnsonjh.dev@gmail.com>\n",
             (osinfo () ? osinfo () : ""), ASM_VERSION,
#if defined(__DATE__)
             " (Built ",
# ifdef __clang__
             trimstr (__DATE__),
# else
             ((*(__DATE__)) ? trimstr (__DATE__) : ""),
# endif
             "", "", ")"
#else
             "", "", "", "", " -"
#endif
  ASM_URL);

  if (0 == version)
    {
      (void)fprintf (stderr,
"\n"
"Usage: %s [options] <source[.asm]>"
"\n"
"\n"
"  Options:\n"
"    -z, --zasm            Emulate TDL ZASM 2.21 behavior%s"
"\n"
"    -p, --pasm            Emulate PSA PASM 1.02 behavior%s"
"\n"
"    -g, --pasm2           Emulate PSA PASM 2.00G behavior (WIP)%s"
"\n"
#ifdef ENABLE_M80
"    -m, --m80             Simulate MACRO-80 (-g with .ZOP + .EPOP)"
"\n"
#endif
"    -o, --out <file>      Write the assembled binary image to <file>"
"\n"
"    -P, --pad             Pad output to full CP/M record boundary"
"\n"
"    -l, --list <file>     Write the listing to <file> [default: stderr]"
"\n",
      prog, (DIALECT_ZASM == dialect ? " [default]" : ""),
            (DIALECT_PASM == dialect ? " [default]" : ""),
            (DIALECT_PASM2 == dialect ? " [default]" : ""));
      (void)fprintf (stderr,
"    -R, --pbin <file>     Write the object module as binary TDL REL to <file>"
"\n"
"    -X, --phex <file>     Write the object module as ASCII-hex REL to <file>"
"\n"
"    -L, --long            Allow long (>6 character, non-standard) symbol names"
"\n"
"    -r, --read <file>     Answer assembly-time prompts from <file>"
"\n");
      (void)fprintf (stderr,
"    -i, --include <file>  Include <file> before processing <source[.asm]>"
"\n"
"    -a, --prefix <expr>   Evaluate <expr> before processing <source[.asm]>"
"\n"
"    -e, --expr <expr>     Evaluate only expression <expr> and exit"
"\n"
"    -v, --version         Display version information and exit"
"\n"
"    -h, --help            Display this help text and exit"
#ifndef __DJGPP__
"\n"
#endif
"\n");
    }
}

/******************************************************************************/

static void
free_preops (asm_preop *preops)
{
  while (preops)
    {
      asm_preop *p = preops;
      preops = p->next;
      /*LINTED E_CONSTANT_CONDITION*/
      FREE (p);
    }
}

/******************************************************************************/

/*
 * Whether argv[0] selects the MACRO-80 simulation (the `m80' command name).
 */

static int
name_is_m80 (const char *argv0)
{
  return 0 == strncmp (basename_of (argv0), "m80", 3);
}

/******************************************************************************/

/*
 * Append the `.ZOP'/`.EPOP' assembly-time prefixes that put the assembler into
 * MACRO-80 mode -- the standard Zilog mnemonic set plus the Intel/M80 pseudo-
 * ops, enabled before the source as if it opened with those two directives.
 * Used by both the `--m80' option and the `m80' argv[0].  Returns 0, or -1 on
 * out-of-memory (the caller frees the partial list).
 */

static int
add_m80_preops (asm_preop **head, asm_preop **tail)
{
  static const char *const m80dir[2] = { ".ZOP", ".EPOP" };
  int mi;

  for (mi = 0; mi < 2; mi++)
    {
      asm_preop *p = (asm_preop *)malloc (sizeof (asm_preop));

      if (NULL == p)
        return -1;

      p->type = 'a';
      p->arg = m80dir[mi];
      p->next = NULL;

      if (NULL == *tail)
        *head = p;
      else
        (*tail)->next = p;

      *tail = p;
    }

  return 0;
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
  const char *relpath = NULL;
  const char *hexpath = NULL;
  asm_preop *preops = NULL;
  asm_preop *pretail = NULL;
  int pad = 0;
  int i;

  allow_long_symbols = 0;

  /*
   * the `m80' command name selects MACRO-80 mode (PASM 2.00G with the
   * `.ZOP'/`.EPOP' prefixing for now, just like the `--m80' option
   * (dialect set above)
   */

  if (name_is_m80 (argv[0]) && 0 != add_m80_preops (&preops, &pretail))
    {
      (void)fprintf (stderr, "%s: Out of memory!\n", prog);

      free_preops (preops);

      return 2;
    }

  for (i = 1; i < argc; ++i)
    {
      const char *a = argv[i];
      char opt = '\0';

      if ('-' == a[0] && '-' == a[1] && '\0' != a[2])
        {
          /*
           * GNU-style long option: map to its short-option letter, then
           * fall through to the shared per-option handling below
           */

          static const struct
          {
            const char *name;
            char ch;
          } longs[]
              = { {    "zasm", 'z' }, {   "pasm", 'p' }, {     "out", 'o' },
                  {     "pad", 'P' }, {   "list", 'l' }, {    "pbin", 'R' },
                  {    "phex", 'X' }, {   "long", 'L' }, {    "read", 'r' },
                  {    "expr", 'e' }, {   "help", 'h' }, { "version", 'v' },
                  { "include", 'i' }, { "prefix", 'a' }, {   "pasm2", 'g' },
                  {     "m80", 'm' },
                };
          int li;

          for (li = 0; li < (int)(sizeof (longs) / sizeof (longs[0])); ++li)
            if (0 == strcmp (a + 2, longs[li].name))
              {
                opt = longs[li].ch;

                break;
              }

          if ('\0' == opt)
            {
              (void)fprintf (stderr, "%s: unknown option '%s'\n", prog, a);
              usage (prog, dialect, 0);

              free_preops (preops);

              return 2;
            }
        }
      else if ('-' == a[0] && '\0' != a[1] && '\0' == a[2])
        opt = a[1];

      if ('\0' != opt)
        {
          switch (opt)
            {
            case 'p':
              dialect = DIALECT_PASM;

              break;

            case 'g':
              dialect = DIALECT_PASM2;

              break;

            case 'm':
              /*
               * --m80: simulate MACRO-80.  Currently just PASM 2.00G with
               * the Zilog mnemonic set (.ZOP) and the Intel/M80 pseudo-ops
               * (.EPOP) enabled from the start, as if the source opened
               * with `.ZOP' and `.EPOP'.  Equivalent to:
               * `--pasm2 --prefix ".ZOP" --prefix ".EPOP"'.
               */

              dialect = DIALECT_PASM2;

              if (0 != add_m80_preops (&preops, &pretail))
                {
                  (void)fprintf (stderr, "%s: Out of memory!\n", prog);

                  free_preops (preops);

                  return 2;
                }

              break;

            case 'z':
              dialect = DIALECT_ZASM;

              break;

            case 'L':
              allow_long_symbols = 1;

              break;

            case 'P':
              pad = 1;

              break;

            case 'v':
              usage (prog, dialect, 1);

              free_preops (preops);

              return 0;

            case 'h':
              usage (prog, dialect, 0);

              free_preops (preops);

              return 0;

            case 'o':
              if (i + 1 >= argc)
                {
                  (void)fprintf (stderr, "%s: -o needs a filename\n", prog);

                  free_preops (preops);

                  return 2;
                }

              outpath = argv[++i];

              break;

            case 'l':
              if (i + 1 >= argc)
                {
                  (void)fprintf (stderr, "%s: -l needs a filename\n", prog);

                  free_preops (preops);

                  return 2;
                }

              lstpath = argv[++i];

              break;

            case 'R':
              /*
               * write the object module as a binary TDL REL file (.PBIN)
               */

              if (i + 1 >= argc)
                {
                  (void)fprintf (stderr, "%s: -R needs a filename\n", prog);

                  free_preops (preops);

                  return 2;
                }

              relpath = argv[++i];

              break;

            case 'X':
              /*
               * write the object module as an ASCII-hex REL file (.PHEX)
               */

              if (i + 1 >= argc)
                {
                  (void)fprintf (stderr, "%s: -X needs a filename\n", prog);

                  free_preops (preops);

                  return 2;
                }

              hexpath = argv[++i];

              break;

            case 'r':
              /*
               * Take answers to the '\' console prompts from a file instead
               * of the terminal (a "response file"); equivalent to piping.
               */

              if (i + 1 >= argc)
                {
                  (void)fprintf (stderr, "%s: -r needs a filename\n", prog);

                  free_preops (preops);

                  return 2;
                }

              if (NULL == freopen (argv[++i], "r", stdin))
                {
                  (void)fprintf (stderr,
                                 "%s: cannot open response file '%s'\n", prog,
                                 argv[i]);

                  free_preops (preops);

                  return 2;
                }

              break;

            case 'i':
            case 'a':
              {
                asm_preop *p;

                if (i + 1 >= argc)
                  {
                    (void)fprintf (stderr, "%s: -%c needs an argument\n",
                                   prog, opt);

                    free_preops (preops);

                    return 2;
                  }

                p = (asm_preop *)malloc (sizeof (asm_preop));

                if (NULL == p)
                  {
                    (void)fprintf (stderr, "%s: Out of memory!\n", prog);

                    free_preops (preops);

                    return 2;
                  }

                p->type = opt;
                p->arg = argv[++i];
                p->next = NULL;

                if (NULL == pretail)
                  preops = p;
                else
                  pretail->next = p;

                pretail = p;

                break;
              }

            case 'e':
              {
                value_t v;
                const char *eerr;
                eval_env env;

                if (i + 1 >= argc)
                  {
                    (void)fprintf (stderr, "%s: -e needs an expression\n",
                                   prog);

                    free_preops (preops);

                    return 2;
                  }

                env.radix = RADIX_DEFAULT;
                env.syms = NULL;
                env.lc = 0;
                env.lc_reloc = 0;
                env.undef0 = 0;
                env.scope = 0;
                env.ext_next = NULL;
                env.ext_decl = NULL;

                if (expr_eval (argv[++i], &env, &v, &eerr))
                  {
                    (void)fprintf (stderr, "%s: -e: %s\n", prog, eerr);

                    free_preops (preops);

                    return 1;
                  }

                (void)printf ("%u (0x%04X)%s\n", (unsigned)v.value,
                              (unsigned)v.value,
                              (v.reloc ? " [relocatable]" : ""));

                free_preops (preops);

                return 0;
              }

            default:
              (void)fprintf (stderr, "%s: unknown option '%s'\n", prog, a);
              usage (prog, dialect, 0);

              free_preops (preops);

              return 2;
            }
        }
      else
        src = a;
    }

  if (NULL == src)
    {
      usage (prog, dialect, 0);

      free_preops (preops);

      return 2;
    }

  {
    int res = asm_source (src, dialect, outpath, lstpath, relpath, hexpath, pad,
                          allow_long_symbols, preops);

    free_preops (preops);

    return res;
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
