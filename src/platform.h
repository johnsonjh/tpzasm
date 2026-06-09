/*
 * TPZASM: TDL ZASM / PSA PASM compatible assembler - platform.h
 * Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
 * SPDX-License-Identifier: MIT-0
 * scspell-id: c151d874-63fd-11f1-9cd0-80ee73e9b8e7
 */

/******************************************************************************/

#ifndef PLATFORM_H
# define PLATFORM_H

/******************************************************************************/

# ifdef __has_include
#  define HAS_INCLUDE(inc) __has_include(inc)
# else
#  define HAS_INCLUDE(inc) 0
# endif

/******************************************************************************/

# ifdef _CH_
#  include <string.h>
#  include <sys/utsname.h>
#  ifndef HAVE_UTSNAME_H
#   define HAVE_UTSNAME_H
#  endif
# endif

/******************************************************************************/

# ifndef __CPPCHECK__
#  ifndef _CH_
#   if HAS_INCLUDE(<sys/utsname.h>)
#    include <string.h>
#    include <sys/utsname.h>
#    ifndef HAVE_UTSNAME_H
#     define HAVE_UTSNAME_H
#    endif
#   endif
#  endif
# endif

/******************************************************************************/

const char *platform_name (void);
const char *sysarch (void);

/******************************************************************************/

#endif

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
