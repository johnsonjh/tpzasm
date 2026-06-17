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

# ifdef _CH_
#  include <signal.h>
#  ifndef HAVE_SIGNAL_H
#   define HAVE_SIGNAL_H
#  endif
# endif

/******************************************************************************/

# ifndef __CPPCHECK__
#  ifndef _CH_
#   ifndef __IA16_SYS_MSDOS
#    if HAS_INCLUDE(<signal.h>)
#     include <signal.h>
#     ifndef HAVE_SIGNAL_H
#      define HAVE_SIGNAL_H
#     endif
#    endif
#   endif
#  endif
# endif

/******************************************************************************/

# if defined(HAVE_UTSNAME_H) || (defined(_WIN32) && !defined(__CYGWIN__))
#  define HAVE_SYSARCH
# endif

/******************************************************************************/

# ifndef ASM_SIZE_T_NARROW
#  if defined(__SIZEOF_SIZE_T__)
#   if __SIZEOF_SIZE_T__ <= 2
#    define ASM_SIZE_T_NARROW 1
#   else
#    define ASM_SIZE_T_NARROW 0
#   endif
#  elif defined(__SIZE_WIDTH__)
#   if __SIZE_WIDTH__ <= 16
#    define ASM_SIZE_T_NARROW 1
#   else
#    define ASM_SIZE_T_NARROW 0
#   endif
#  else
#   define ASM_SIZE_T_NARROW 0
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
