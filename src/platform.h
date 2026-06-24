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

# if defined (__atarist__) || defined(__atarist) || defined(atarist)
#  include <gem.h>
#  include <osbind.h>
# endif

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

# if defined(HAVE_UTSNAME_H) || (defined(_WIN32) && !defined(__CYGWIN__)) || \
     defined(__VBCC__)
#  define HAVE_SYSARCH
# endif

/******************************************************************************/

# if defined(__VBCC__)
#  ifndef HAVE_SIGNAL_H
#   define HAVE_SIGNAL_H
#  endif
# elif defined(__SICORTEX__) && (defined(__linux__) || defined(__linux))
#  ifndef HAVE_SIGNAL_H
#   define HAVE_SIGNAL_H
#  endif
#  ifndef USE_GETLINE
#   define USE_GETLINE
#  endif
#  ifndef USE_TERMIOS
#   define USE_TERMIOS
#  endif
# elif defined(__linux__) || defined(__linux)
#  ifndef HAVE_SIGNAL_H
#   define HAVE_SIGNAL_H
#  endif
#  ifndef USE_GETLINE
#   define USE_GETLINE
#  endif
#  ifndef USE_TERMIOS
#   define USE_TERMIOS
#  endif
# elif defined(__illumos__)
#  ifndef HAVE_SIGNAL_H
#   define HAVE_SIGNAL_H
#  endif
#  ifndef USE_GETLINE
#   define USE_GETLINE
#  endif
#  ifndef USE_TERMIOS
#   define USE_TERMIOS
#  endif
# elif defined(__sun) || defined(sun)
#  if defined(__SVR4)
#   ifndef HAVE_SIGNAL_H
#    define HAVE_SIGNAL_H
#   endif
#   ifndef USE_GETLINE
#    define USE_GETLINE
#   endif
#   ifndef USE_TERMIOS
#    define USE_TERMIOS
#   endif
#  endif
# elif defined(_AIX) && !defined(__PASE__)
#  ifndef HAVE_SIGNAL_H
#   define HAVE_SIGNAL_H
#  endif
#  ifndef USE_GETLINE
#   define USE_GETLINE
#  endif
#  ifndef USE_TERMIOS
#   define USE_TERMIOS
#  endif
#  ifndef USE_SIGACTION
#   define USE_SIGACTION
#  endif
# elif defined(_AIX) && defined(__PASE__)
#  ifndef HAVE_SIGNAL_H
#   define HAVE_SIGNAL_H
#  endif
#  ifndef USE_GETLINE
#   define USE_GETLINE
#  endif
#  ifndef USE_TERMIOS
#   define USE_TERMIOS
#  endif
#  ifndef USE_SIGACTION
#   define USE_SIGACTION
#  endif
# elif defined(__FreeBSD__)
#  ifndef HAVE_SIGNAL_H
#   define HAVE_SIGNAL_H
#  endif
#  ifndef USE_GETLINE
#   define USE_GETLINE
#  endif
#  ifndef USE_TERMIOS
#   define USE_TERMIOS
#  endif
#  ifndef USE_SIGACTION
#   define USE_SIGACTION
#  endif
# elif defined(__NetBSD__)
#  ifndef HAVE_SIGNAL_H
#   define HAVE_SIGNAL_H
#  endif
#  ifndef USE_GETLINE
#   define USE_GETLINE
#  endif
#  ifndef USE_TERMIOS
#   define USE_TERMIOS
#  endif
#  ifndef USE_SIGACTION
#   define USE_SIGACTION
#  endif
# elif defined(__OpenBSD__)
#  ifndef HAVE_SIGNAL_H
#   define HAVE_SIGNAL_H
#  endif
#  ifndef USE_GETLINE
#   define USE_GETLINE
#  endif
#  ifndef USE_TERMIOS
#   define USE_TERMIOS
#  endif
#  ifndef USE_SIGACTION
#   define USE_SIGACTION
#  endif
# elif defined(__DragonFly__)
#  ifndef HAVE_SIGNAL_H
#   define HAVE_SIGNAL_H
#  endif
#  ifndef USE_GETLINE
#   define USE_GETLINE
#  endif
#  ifndef USE_TERMIOS
#   define USE_TERMIOS
#  endif
#  ifndef USE_SIGACTION
#   define USE_SIGACTION
#  endif
# elif defined(__HAIKU__)
#  ifndef HAVE_SIGNAL_H
#   define HAVE_SIGNAL_H
#  endif
#  ifndef USE_GETLINE
#   define USE_GETLINE
#  endif
#  ifndef USE_TERMIOS
#   define USE_TERMIOS
#  endif
#  ifndef USE_SIGACTION
#   define USE_SIGACTION
#  endif
# elif defined(__ELKS__) || defined(__IA16_SYS_ELKS)
#  ifndef HAVE_SIGNAL_H
#   define HAVE_SIGNAL_H
#  endif
# elif defined(__CYGWIN__)
#  ifndef HAVE_SIGNAL_H
#   define HAVE_SIGNAL_H
#  endif
#  ifndef USE_GETLINE
#   define USE_GETLINE
#  endif
#  ifndef USE_TERMIOS
#   define USE_TERMIOS
#  endif
#  ifndef USE_SIGACTION
#   define USE_SIGACTION
#  endif
# endif

/******************************************************************************/

# ifdef USE_GETLINE
#  ifndef HAVE_SIGNAL_H
#   error "Need HAVE_SIGNAL_H defined"
#  endif
#  include <signal.h>
#  if defined(USE_TERMIOS)
#   include <termios.h>
#  elif defined(USE_TERMIO)
#   include <termio.h>
#  else
#   error "Need USE_TERMIOS or USE_TERMIO defined"
#  endif
#  include <unistd.h>
#  include <errno.h>
#  include <string.h>
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

# ifndef NO_PLATFORM_NAME
const char *platform_name (void);
# endif
# ifdef HAVE_SYSARCH
const char *sysarch (void);
# endif

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
