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

#include <stddef.h>

/******************************************************************************/

#include "platform.h"

/******************************************************************************/

#if defined(_WIN32) && !defined(__CYGWIN__)
# include <windows.h>
#endif

/******************************************************************************/

const char *sysarch(void)
{
#if defined(_WIN32) && !defined(__CYGWIN__)
  SYSTEM_INFO si;

  GetSystemInfo (&si);

  switch (si.wProcessorArchitecture)
    {

  /*******************************************************************/

# ifdef PROCESSOR_ARCHITECTURE_INTEL
    case PROCESSOR_ARCHITECTURE_INTEL:
      return "x86";
# endif

  /*******************************************************************/

# ifdef PROCESSOR_ARCHITECTURE_AMD64
    case PROCESSOR_ARCHITECTURE_AMD64:
      return "x64";
# endif

  /*******************************************************************/

# ifdef PROCESSOR_ARCHITECTURE_ARM
    case PROCESSOR_ARCHITECTURE_ARM:
      return "ARM";
# endif

  /*******************************************************************/

# ifdef PROCESSOR_ARCHITECTURE_ARM64
    case PROCESSOR_ARCHITECTURE_ARM64:
      return "ARM64";
# endif

  /*******************************************************************/

# ifdef PROCESSOR_ARCHITECTURE_IA64
    case PROCESSOR_ARCHITECTURE_IA64:
      return "IA64";
# endif

  /*******************************************************************/

# ifdef PROCESSOR_ARCHITECTURE_ALPHA
    case PROCESSOR_ARCHITECTURE_ALPHA:
      return "AXP";
# endif

  /*******************************************************************/

# ifdef PROCESSOR_ARCHITECTURE_ALPHA64
    case PROCESSOR_ARCHITECTURE_ALPHA64:
      return "AXP64";
# endif

  /*******************************************************************/

# ifdef PROCESSOR_ARCHITECTURE_MIPS
    case PROCESSOR_ARCHITECTURE_MIPS:
      return "MIPS";
# endif

  /*******************************************************************/

# ifdef PROCESSOR_ARCHITECTURE_PPC
    case PROCESSOR_ARCHITECTURE_PPC:
      return "PowerPC";
# endif

  /*******************************************************************/

# ifdef PROCESSOR_ARCHITECTURE_SHX
    case PROCESSOR_ARCHITECTURE_SHX:
      return "SH";
# endif

  /*******************************************************************/

    default:
      return NULL;
    }

  /*******************************************************************/

#elif !defined(HAVE_UTSNAME_H)
  return NULL;
#else

  /*******************************************************************/

# if defined(__SICORTEX__) && defined(__mips64)
  return "mips64";

  /*******************************************************************/

# elif defined(__DJGPP__)
  return "x86";

  /*******************************************************************/

# elif defined(_AIX)
#  if defined(_ARCH_PPC64) || defined(__PPC64__)
  return "powerpc64";

  /*******************************************************************/

#  elif defined(_ARCH_PPC) || defined(__PPC__)
  return "powerpc";

  /*******************************************************************/

#  else
  return NULL;
#  endif

  /*******************************************************************/

# else
  static char buf[1024];
  struct utsname u;

  if (0 != uname (&u))
    return NULL;

  /*******************************************************************/

  strncpy (buf, u.machine, sizeof(buf) - 1);
  buf[sizeof(buf) - 1] = '\0';

  return buf;

  /*******************************************************************/

# endif
#endif
}

/******************************************************************************/

const char *platform_name (void)
{

  /*******************************************************************/

#if defined(__SICORTEX__) && (defined(__linux__) || defined(__linux))
# ifndef HAVE_SIGNAL_H
#  define HAVE_SIGNAL_H
# endif
  return "Linux/SiCortex";

  /*******************************************************************/

#elif defined(__linux__) || defined(__linux)
# ifndef HAVE_SIGNAL_H
#  define HAVE_SIGNAL_H
# endif
  return "Linux";

  /*******************************************************************/

#elif defined(__illumos__)
# ifndef HAVE_SIGNAL_H
#  define HAVE_SIGNAL_H
# endif
  return "illumos";

  /*******************************************************************/

#elif defined(__sun) || defined(sun)
# if defined(__SVR4)
#  ifndef HAVE_SIGNAL_H
#   define HAVE_SIGNAL_H
#  endif
  return "Solaris";

  /*******************************************************************/

# else
  return "SunOS";
# endif

  /*******************************************************************/

#elif defined(__hpux)
  return "HP-UX";

  /*******************************************************************/

#elif defined(_AIX) && !defined(__PASE__)
# ifndef HAVE_SIGNAL_H
#  define HAVE_SIGNAL_H
# endif
  return "AIX";

  /*******************************************************************/

#elif defined(_AIX) && defined(__PASE__)
# ifndef HAVE_SIGNAL_H
#  define HAVE_SIGNAL_H
# endif
  return "OS400";

  /*******************************************************************/

#elif defined(__sgi)
  return "IRIX";

  /*******************************************************************/

#elif defined(__FreeBSD__)
# ifndef HAVE_SIGNAL_H
#  define HAVE_SIGNAL_H
# endif
  return "FreeBSD";

  /*******************************************************************/

#elif defined(__NetBSD__)
# ifndef HAVE_SIGNAL_H
#  define HAVE_SIGNAL_H
# endif
  return "NetBSD";

  /*******************************************************************/

#elif defined(__OpenBSD__)
# ifndef HAVE_SIGNAL_H
#  define HAVE_SIGNAL_H
# endif
  return "OpenBSD";

  /*******************************************************************/

#elif defined(__DragonFly__)
# ifndef HAVE_SIGNAL_H
#  define HAVE_SIGNAL_H
# endif
  return "DragonFly BSD";

  /*******************************************************************/

#elif defined(BSD) || defined(__BSD__)
  return "BSD";

  /*******************************************************************/

#elif defined(__QNX__) || defined(__QNXNTO__)
  return "QNX";

  /*******************************************************************/

#elif defined(__VXWORKS__)
  return "VxWorks";

  /*******************************************************************/

#elif defined(__HAIKU__)
# ifndef HAVE_SIGNAL_H
#  define HAVE_SIGNAL_H
# endif
  return "Haiku";

  /*******************************************************************/

#elif defined(__serenity__)
  return "SerenityOS";

  /*******************************************************************/

#elif defined(__GNU__) && !defined(__linux__)
  return "GNU/Hurd";

  /*******************************************************************/

#elif defined(__MACH__) && defined(__NeXT__)
  return "NeXTSTEP";

  /*******************************************************************/

#elif defined(__MACH__) && defined(__APPLE__)
  return "macOS";

  /*******************************************************************/

#elif defined(__ELKS__) || defined(__IA16_SYS_ELKS)
# ifndef HAVE_SIGNAL_H
#  define HAVE_SIGNAL_H
# endif
  return "ELKS";

  /*******************************************************************/

#elif defined(multics)
  return "Multics";

  /*******************************************************************/

#elif defined(__COMPILER_KCC__)
  return "TOPS-20";

  /*******************************************************************/

#elif defined(__CPM86__) || defined(CPM86)
  return "CP/M-86";

  /*******************************************************************/

#elif defined(__CPM__) || defined(__CPM80__) || defined(_CPM) \
    || defined(CPM)
  return "CP/M";

  /*******************************************************************/

#elif defined(__DJGPP) || defined(__DJGPP__) || defined(DJGPP)
  return "MS-DOS/DJGPP";

  /*******************************************************************/

#elif defined(__MSDOS__) || defined(__MS_DOS__) || defined(MSDOS) \
    || defined(_DOS) || defined(__DOS__) || defined(__IA16_SYS_MSDOS)
  return "MS-DOS";

  /*******************************************************************/

#elif defined(__CYGWIN__)
# ifndef HAVE_SIGNAL_H
#  define HAVE_SIGNAL_H
# endif
  return "Windows/Cygwin";

  /*******************************************************************/

#elif defined(_WIN32)
  return "Windows";

  /*******************************************************************/

#elif defined(_CH_)
  struct utsname chname;

  if (-1 == uname (&chname))
    return "SoftIntegration Ch";

  string_t buf; /* Ch dynamic string */
  /* cppcheck-suppress legacyUninitvar */
  buf += "Ch/";
  buf += chname.sysname;

  return buf; /* legal for Ch */

  /*******************************************************************/

#elif defined(__unix__) || defined(__unix) || defined(__UNIX__) \
    || defined(unix)
  return "Unix";

  /*******************************************************************/

#else
  return "";
#endif

  /*******************************************************************/

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
