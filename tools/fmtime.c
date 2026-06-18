/*
 * TPZASM: TDL ZASM / PSA PASM compatible assembler - tools/fmtime.c
 * Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
 * SPDX-License-Identifier: MIT-0
 * scspell-id: cce7abcc-6a8e-11f1-9fef-80ee73e9b8e7
 */

/******************************************************************************/

#include <stdio.h>
#include <time.h>
#include <sys/stat.h>

/******************************************************************************/

#ifndef NO_PLATFORM_NAME
# define NO_PLATFORM_NAME
#endif

/******************************************************************************/

#include "../src/platform.h"

/******************************************************************************/

# ifdef _CH_
#  include <locale.h>
#  ifndef HAVE_LOCALE_H
#   define HAVE_LOCALE_H
#  endif
# endif

/******************************************************************************/

#ifndef __CPPCHECK__
# ifndef _CH_
#  ifndef __IA16_SYS_MSDOS
#   if HAS_INCLUDE(<locale.h>)
#    include <locale.h>
#    ifndef HAVE_LOCALE_H
#     define HAVE_LOCALE_H
#    endif
#   endif
#  endif
# endif
#endif

/******************************************************************************/

#ifdef NO_LOCALE
# ifdef HAVE_LOCALE_H
#  undef HAVE_LOCALE_H
# endif
#endif

/******************************************************************************/

int main(int argc, char * * argv)
{
  struct stat st;
  char buf [256];
  const struct tm * tm;

#ifdef HAVE_LOCALE_H
  setlocale (LC_ALL, "");
#endif

  if (3 != argc)
    return 1;

  if (0 != stat (argv [1], & st))
    return 1;

  tm = localtime (& st.st_mtime);

  if (! tm)
    return 1;

  if (0 == strftime (buf, sizeof (buf), argv [2], tm))
    return 1;

  (void)printf ("%s\n", buf);

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
