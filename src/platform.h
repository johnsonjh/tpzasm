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

#ifdef _CH_
#include <string.h>
#include <sys/utsname.h>
#endif

/******************************************************************************/
# ifndef _CH_
const
# endif
char * platform_name (void);

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
