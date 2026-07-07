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

#ifdef HAVE_SYSARCH
const char *sysarch(void)
{
# if defined(_WIN32) && !defined(__CYGWIN__)
  SYSTEM_INFO si;

  GetSystemInfo (&si);

  switch (si.wProcessorArchitecture)
    {

  /*******************************************************************/

#  ifdef PROCESSOR_ARCHITECTURE_INTEL
    case PROCESSOR_ARCHITECTURE_INTEL:
      return "x86";
#  endif

  /*******************************************************************/

#  ifdef PROCESSOR_ARCHITECTURE_AMD64
    case PROCESSOR_ARCHITECTURE_AMD64:
      return "x64";
#  endif

  /*******************************************************************/

#  ifdef PROCESSOR_ARCHITECTURE_ARM
    case PROCESSOR_ARCHITECTURE_ARM:
      return "ARM";
#  endif

  /*******************************************************************/

#  ifdef PROCESSOR_ARCHITECTURE_ARM64
    case PROCESSOR_ARCHITECTURE_ARM64:
      return "ARM64";
#  endif

  /*******************************************************************/

#  ifdef PROCESSOR_ARCHITECTURE_IA64
    case PROCESSOR_ARCHITECTURE_IA64:
      return "IA64";
#  endif

  /*******************************************************************/

#  ifdef PROCESSOR_ARCHITECTURE_ALPHA
    case PROCESSOR_ARCHITECTURE_ALPHA:
      return "AXP";
#  endif

  /*******************************************************************/

#  ifdef PROCESSOR_ARCHITECTURE_ALPHA64
    case PROCESSOR_ARCHITECTURE_ALPHA64:
      return "AXP64";
#  endif

  /*******************************************************************/

#  ifdef PROCESSOR_ARCHITECTURE_MIPS
    case PROCESSOR_ARCHITECTURE_MIPS:
      return "MIPS";
#  endif

  /*******************************************************************/

#  ifdef PROCESSOR_ARCHITECTURE_PPC
    case PROCESSOR_ARCHITECTURE_PPC:
      return "PowerPC";
#  endif

  /*******************************************************************/

#  ifdef PROCESSOR_ARCHITECTURE_SHX
    case PROCESSOR_ARCHITECTURE_SHX:
      return "SH";
#  endif

  /*******************************************************************/

    default:
      return NULL;
    }

  /*******************************************************************/

# elif !defined(HAVE_UTSNAME_H) && !defined(__VBCC__)
  return NULL;
# else

  /*******************************************************************/

#  if defined(__VBCC__) && defined(__COLDFIRE)
  return "Coldfire";

  /*******************************************************************/

#  elif defined(__VBCC__) && defined(__6502__)
  return "6502";

  /*******************************************************************/

#  elif defined(__VBCC__) && defined(__65816__)
  return "65816";

  /*******************************************************************/

#  elif defined(__VBCC__) && defined(__PPC__)
  return "powerpc";

  /*******************************************************************/

#  elif defined(__VBCC__) && defined(__ALPHA__)
  return "alpha";

  /*******************************************************************/

#  elif defined(__VBCC__) && (defined(__X86__) || defined(__I386__))
  return "i386";

  /*******************************************************************/

#  elif defined(__VBCC__) && (defined(__C16X__) || \
        defined(__C167_) || defined(__ST10__))
  return "C16X";

  /*******************************************************************/

#  elif defined(__VBCC__) && defined(__VIDEOCORE__)
  return "VCIV";

  /*******************************************************************/

#  elif defined(__VBCC__) && defined(__HC12__)
  return "HC12";

  /*******************************************************************/

#  elif defined(__VBCC__) && defined(__6809__)
  return "6809";

  /*******************************************************************/

#  elif defined(__VBCC__) && defined(__6309__)
  return "6309";

  /*******************************************************************/

#  elif defined(__M68K__) || defined(__m68k__) || \
        defined(__M68000__) || defined(__mc68000) || \
        defined(__mc68000__) || defined(__m68k)
  return "m68k";

  /*******************************************************************/

#  elif defined(__SICORTEX__) && defined(__mips64)
  return "mips64";

  /*******************************************************************/

#  elif defined(__DJGPP__)
  return "x86";

  /*******************************************************************/

#  elif defined(_AIX)
#   if defined(_ARCH_PPC64) || defined(__PPC64__)
  return "powerpc64";

  /*******************************************************************/

#   elif defined(_ARCH_PPC) || defined(__PPC__)
  return "powerpc";

  /*******************************************************************/

#   else
  return NULL;
#   endif

  /*******************************************************************/

#  else
  static char buf [1024];
  struct utsname u;

  if (0 != uname (&u))
    return NULL;

  /*******************************************************************/

  strncpy (buf, u.machine, sizeof(buf) - 1);
  buf [sizeof(buf) - 1] = '\0';

  return buf;

  /*******************************************************************/

#  endif
# endif
}
#endif

/******************************************************************************/

#if defined(__atarist__) || defined(__atarist) || defined(atarist)
typedef struct
{
  unsigned long tag;
  unsigned long value; /* cppcheck-suppress unusedStructMember */
} COOKIE;

/******************************************************************************/

static volatile int mint_present_super = 0;

/******************************************************************************/

static void
probe_mint_super(void)
{
  const COOKIE *cookies = *(COOKIE **) 0x5a0;

  mint_present_super = 0;

  if (!cookies)
    return;

  while (cookies->tag)
    {
      if (cookies->tag == 0x4d694e54ul)
        {
          mint_present_super = 1;

          return;
        }

      cookies++;
    }
}
#endif

/******************************************************************************/

#if defined(__atarist__) || defined(__atarist) || defined(atarist)
static int
is_mint(void)
{
  mint_present_super = 0;
  Supexec((void (*)(void))probe_mint_super);

  return mint_present_super;
}
#endif

/******************************************************************************/

const char *platform_name (void)
{

  /*******************************************************************/

#if defined(__serenity__)
  return "SerenityOS";

  /*******************************************************************/

#elif defined(__MORPHOS__)
  return "MorphOS";

  /*******************************************************************/

#elif defined(__VBCC__)
  return "VBCC"; /* VBCC defines no platform-detection macros */

  /*******************************************************************/

#elif defined(__SICORTEX__) && (defined(__linux__) || defined(__linux))
  return "Linux/SiCortex";

  /*******************************************************************/

#elif defined(__linux__) || defined(__linux)
  return "Linux";

  /*******************************************************************/

#elif defined(__illumos__)
  return "illumos";

  /*******************************************************************/

#elif defined(__sun) || defined(sun)
# if defined(__SVR4)
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
  return "AIX";

  /*******************************************************************/

#elif defined(_AIX) && defined(__PASE__)
  return "OS400";

  /*******************************************************************/

#elif defined(__sgi)
  return "IRIX";

  /*******************************************************************/

#elif defined(__FreeBSD__)
  return "FreeBSD";

  /*******************************************************************/

#elif defined(__NetBSD__)
  return "NetBSD";

  /*******************************************************************/

#elif defined(__OpenBSD__)
  return "OpenBSD";

  /*******************************************************************/

#elif defined(__DragonFly__)
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
  return "Haiku";

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
  return "DOS/DJGPP";

  /*******************************************************************/

#elif defined(__MSDOS__) || defined(__MS_DOS__) || defined(MSDOS) \
    || defined(_DOS) || defined(__DOS__) || defined(__IA16_SYS_MSDOS)
  return "DOS";

  /*******************************************************************/

#elif defined(__CYGWIN__)
  return "Cygwin";

  /*******************************************************************/

#elif defined(_WIN32)
  return "Windows";

  /*******************************************************************/

#elif defined(_CH_)
  return "Ch";

  /*******************************************************************/

#elif defined(__atarist__) || defined(__atarist) || defined(atarist)
  return (is_mint () ? "MINT" : "TOS");

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
