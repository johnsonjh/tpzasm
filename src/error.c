/*
 * TPZASM: TDL ZASM / PSA PASM compatible assembler - error.c
 * Copyright (c) 2025-2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
 * SPDX-License-Identifier: MIT-0
 * scspell-id: a53b0562-7789-11f1-bc88-80ee73e9b8e7
 */

/******************************************************************************/

#include <stdio.h>
#include <string.h>

/******************************************************************************/

#include "error.h"

/******************************************************************************/

#define TRIM_BUFSIZE 1024
#define TRIM_RING 2 /* max reentrancy depth */

static char *trim_str (const char * const s)
{
  /*cppcheck-suppress constVariable*/
  static char bufs [TRIM_RING] [TRIM_BUFSIZE];
  static int idx = 0;

  /*cppcheck-suppress constStatement*/
  const char * p;
  /*cppcheck-suppress constStatement*/
  const char * q;
  /*cppcheck-suppress constStatement*/
  const char * last;

  char * buf;
  char * d;

  buf = bufs [idx];
  idx++;

  if (idx >= TRIM_RING)
    idx = 0;

  if (0 == s) {
    buf [0] = '\0';

    return buf;
  }

  p = s;

  while (' ' == * p || '\t' == * p || '\r' == * p || '\n' == * p)
    p++;

  if ('\0' == * p) {
    buf [0] = '\0';

    return buf;
  }

  q = p;
  last = p;

  while ('\0' != * q) {
    if (' ' != * q && '\t' != * q && '\r' != * q && '\n' != * q)
      last = q;

    q++;
  }

  d = buf;

  while (p <= last && d < buf + (TRIM_BUFSIZE - 1)) {
    if ('\r' == * p || '\n' == * p)
      * d++ = ' ';
    else
      * d++ = * p;

    p++;
  }

  * d = '\0';

  return buf;
}

/******************************************************************************/

void
error_msg (const char * m, const char * n, const int e)
{
  (void)fprintf (stderr, "ERROR: %s", m);

  if (NULL != n)
    (void)fprintf (stderr, " %s", n);

  if (0 != e) {
    (void)fprintf (stderr, " (Error %d", e);
    (void)fprintf (stderr, ": %s", trim_str (strerror (e)));
    (void)fprintf (stderr, ")");
  }

  (void)fprintf (stderr, ".\n");
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
