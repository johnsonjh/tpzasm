/*
 * TPZASM: TDL ZASM / PSA PASM compatible assembler - platform.c
 * Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
 * SPDX-License-Identifier: MIT-0
 * scspell-id: 3649741a-63fa-11f1-b3f9-80ee73e9b8e7
 */

/******************************************************************************/

/*
 * portable platform detection
 */

/******************************************************************************/

#include "platform.h"

/******************************************************************************/

#ifndef _CH_
const
#endif
char *
platform_name (void)
{
#if defined(__linux__) || defined(__linux)
  return " (Linux)";

  /*******************************************************************/

#elif defined(__illumos__)
  return " (illumos)";

  /*******************************************************************/

#elif defined(__sun) || defined(sun)
# if defined(__SVR4)
  return " (Solaris)";

  /*******************************************************************/

# else
  return " (SunOS)";
# endif

  /*******************************************************************/

#elif defined(__hpux)
  return " (HP-UX)";

  /*******************************************************************/

#elif defined(_AIX) && !defined(__PASE__)
  return " (AIX)";

  /*******************************************************************/

#elif defined(__PASE__)
  return " (OS/400)"

  /*******************************************************************/

#elif defined(__sgi)
  return " (IRIX)";

  /*******************************************************************/

#elif defined(__FreeBSD__)
  return " (FreeBSD)";

  /*******************************************************************/

#elif defined(__NetBSD__)
  return " (NetBSD)";

  /*******************************************************************/

#elif defined(__OpenBSD__)
  return " (OpenBSD)";

  /*******************************************************************/

#elif defined(__DragonFly__)
  return " (DragonFly BSD)";

  /*******************************************************************/

#elif defined(BSD) || defined(__BSD__)
  return " (BSD)";

  /*******************************************************************/

#elif defined(__QNX__) || defined(__QNXNTO__)
  return " (QNX)";

  /*******************************************************************/

#elif defined(__VXWORKS__)
  return " (VxWorks)";

  /*******************************************************************/

#elif defined(__HAIKU__)
  return " (Haiku)";

  /*******************************************************************/

#elif defined(__serenity__)
  return " (SerenityOS)";

  /*******************************************************************/

#elif defined(__GNU__) && !defined(__linux__)
  return " (GNU/Hurd)";

  /*******************************************************************/

#elif defined(__MACH__) && defined(__NeXT__)
  return " (NeXTSTEP)";

  /*******************************************************************/

#elif defined(__MACH__) && defined(__APPLE__)
  return " (macOS)";

  /*******************************************************************/

#elif defined(__ELKS__) || defined(__IA16_SYS_ELKS)
  return " (ELKS)";

  /*******************************************************************/

#elif defined(multics)
  return " (Multics)";

  /*******************************************************************/

#elif defined(__COMPILER_KCC__)
  return " (TOPS-20)";

  /*******************************************************************/

#elif defined(__CPM86__) || defined(CPM86)
  return " (CP/M-86)";

  /*******************************************************************/

#elif defined(__CPM__) || defined(__CPM80__) || defined(_CPM) || defined(CPM)
  return " (CP/M)";

  /*******************************************************************/

#elif defined(__DJGPP) || defined(__DJGPP__) || defined(DJGPP)
  return " (DJGPP/MS-DOS)";

  /*******************************************************************/

#elif defined(__MSDOS__) || defined(__MS_DOS__) || defined(MSDOS) \
    || defined(_DOS) || defined(__DOS__) || defined(__IA16_SYS_MSDOS)
  return " (MS-DOS)";

  /*******************************************************************/

#elif defined(__CYGWIN__)
  return " (Windows/Cygwin)";

  /*******************************************************************/

#elif defined(_WIN32)
  return " (Windows)";

  /*******************************************************************/

#elif defined(_CH_)
  struct utsname name;

  if (uname (&name) == -1)
    {
      return " (SoftIntegration Ch)";
    }

  string_t buf;

  /* cppcheck-suppress legacyUninitvar */
  buf += " (Ch on ";
  buf += name.sysname;
  buf += " ";
  buf += name.machine;
  buf += ")";

  return buf;

  /*******************************************************************/

#elif defined(__unix__) || defined(__unix) || defined(__UNIX__) \
    || defined(unix)
  return " (Unix)";

  /*******************************************************************/

#else
  return "";
#endif
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
