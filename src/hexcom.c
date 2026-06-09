/*
 * TPZASM: TDL ZASM / PSA PASM compatible assembler - hexcom.c
 * DRI HEXCOM 3.00 compatible utility
 * Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
 * SPDX-License-Identifier: MIT-0
 * scspell-id: 380e86a2-6335-11f1-92c6-246e96298730
 */

/******************************************************************************/

/*
 * hexcom.c - convert an Intel HEX file to a CP/M .COM image.
 *
 * A portable ANSI C89 reimplementation of Digital Research's HEXCOM 3.00,
 * output-compatible with the original (validated against orig/hexcom.com run
 * under the tnylpo CP/M emulator).
 *
 * Reads base.hex and writes base.com. Absolute memory image from the lowest
 * to the highest loaded address, padded up to a CP/M record boundary with
 * 0x00, and prints the same report and the same diagnostics as the original.
 */

/******************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/******************************************************************************/

#define TPA 0x100        /* CP/M transient program area base address */
#define RECSZ 128        /* CP/M record (sector) size                */
#define ADDRSP 0x10000UL /* 64K address space                        */

/******************************************************************************/

static unsigned char image[ADDRSP];

/******************************************************************************/

static unsigned first_addr;  /* lowest address loaded                    */
static unsigned last_addr;   /* highest address loaded                   */
static unsigned total_bytes; /* count of data bytes actually loaded      */
static int have_first;       /* set once the first data record is seen   */

/******************************************************************************/

static int
hexval (int c)
{
  if (c >= '0' && c <= '9')
    return c - '0';

  if (c >= 'A' && c <= 'F')
    return c - 'A' + 10;

  if (c >= 'a' && c <= 'f')
    return c - 'a' + 10;

  return -1;
}

/******************************************************************************/

/* Read one byte (two hex digits) from f.  *ok is cleared on a bad digit/EOF.
 */
static int
rd_byte (FILE *f, int *ok)
{
  int c1, c2, hi, lo;

  c1 = fgetc (f);

  if (c1 == EOF)
    {
      *ok = 0;
      return 0;
    } /* don't read past EOF */

  c2 = fgetc (f);
  hi = hexval (c1);
  lo = hexval (c2);

  if (hi < 0 || lo < 0)
    {
      *ok = 0;
      return 0;
    }

  *ok = 1;

  return (hi << 4) | lo;
}

/******************************************************************************/

/*
 * Dump a failing record's bytes the way the original does
 * a "<addr>: " header line, then the bytes 16 per line each
 * prefixed with their address.
 */

static void
dump_record (unsigned recaddr, const unsigned char *data, int n)
{
  int i;

  (void)printf ("%04X: \n", recaddr);

  for (i = 0; i < n; i++)
    {
      if (i % 16 == 0)
        (void)printf ("%04X: ", (recaddr + (unsigned)i) & 0xFFFF);

      (void)printf ("%02X ", data[i]);

      if ((i + 1) % 16 == 0)
        (void)printf ("\n");
    }

  if (n % 16 != 0)
    (void)printf ("\n");

  (void)fflush (stdout);
  (void)fflush (stderr);
}

/******************************************************************************/

/*
 * Every "ERROR: " diagnostic goes through the original's common routine,
 * which prints  "ERROR: <msg>" CRLF "LOAD  ADDRESS <addr>"  with no
 * trailing newline (verified by disassembly at 0x0412 in orig/hexcom.com).
 */

static void
fatal_load (const char *msg, unsigned addr)
{
  (void)printf ("ERROR: %s\nLOAD  ADDRESS %04X", msg, addr);

  exit (1);
}

/******************************************************************************/

/*
 * Record-data error (invalid hex digit / bad checksum) with the byte dump.
 */

static void
record_error (const char *msg, unsigned recaddr, unsigned erraddr,
              const unsigned char *data, int n)
{
  (void)printf ("FIRST ADDRESS %04X\n", first_addr);
  (void)printf ("%s\n", msg);
  (void)printf ("LOAD  ADDRESS %04X\n", recaddr);
  (void)printf ("ERROR ADDRESS %04X\n", erraddr);
  (void)printf ("BYTES READ    \n");

  dump_record (recaddr, data, n);

  exit (1);
}

/******************************************************************************/

int
main (int argc, char **argv)
{
  char base[256];
  char srcname[300];
  char dstname[300];
  char *dot;
  FILE *src;
  FILE *out;
  unsigned char data[256] = { 0 };
  unsigned span, records;
  size_t write_size;

  (void)printf ("HEXCOM\tVERS: 3.00\n");

  (void)fflush (stdout);
  (void)fflush (stderr);

  if (argc < 2 || strlen (argv[1]) >= sizeof (base))
    {
      (void)fprintf (stderr,
        "Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>\n"
        "\n"
        "Usage:\n"
        "  hexcom <basename>  (Reads basename.hex, writes basename.com)\n"
        "\n"
        "Set 'HEXCOM_NO_PAD=1' in the environment to disable record padding.\n"
        "\n");

      return 1;
    }

  (void)strncpy (base, argv[1], sizeof (base) - 1);
  base[sizeof (base) - 1] = '\0';
  dot = strrchr (base, '.');

  if (dot != NULL && (strcmp (dot, ".hex") == 0 || strcmp (dot, ".HEX") == 0))
    *dot = '\0';

  /* False positives CWE-120: srcname/dstname[300] >= base[<256] + ext[4] */
  (void)sprintf (srcname, "%s.hex", base); /* Flawfinder: ignore */
  (void)sprintf (dstname, "%s.com", base); /* Flawfinder: ignore */

  src = fopen (srcname, "rb");

  if (src == NULL)
    fatal_load ("CANNOT OPEN SOURCE FILE", TPA);

  /*
   * The original creates the output file before reading, so a malformed HEX
   * leaves an empty .com behind; opening it here reproduces that behavior!
   */

  out = fopen (dstname, "wb");

  if (out == NULL)
    fatal_load ("DIRECTORY FULL", TPA);

  for (;;)
    {
      unsigned addr;
      int c, ok, ll, tt, i, sum, cc;

      do
        c = fgetc (src);
      while (c != ':' && c != EOF && c != 0x1A);

      if (c != ':')
        break; /* end of input: no further records */

      ll = rd_byte (src, &ok);

      if (!ok)
        record_error ("INVALID HEX DIGIT", 0, 0, data, 0);

      addr = (unsigned)rd_byte (src, &ok) << 8;

      if (!ok)
        record_error ("INVALID HEX DIGIT", 0, 0, data, 0);

      addr |= (unsigned)rd_byte (src, &ok);

      if (!ok)
        record_error ("INVALID HEX DIGIT", 0, 0, data, 0);

      tt = rd_byte (src, &ok);

      if (!ok)
        record_error ("INVALID HEX DIGIT", addr, addr, data, 0);

      if (tt == 0x01)
        break; /* end-of-file record */

      if (tt != 0x00)
        continue; /* ignore other record types */

      /*
       * A zero-length record (e.g. the ":0000000000" terminator some HEX
       * writers emit) loads nothing: it neither triggers the < 100 check
       * nor extends the image.
       */

      if (ll > 0 && addr < TPA)
        fatal_load ("LOAD ADDRESS LESS THAN 100", addr);

      if (ll > 0 && !have_first)
        {
          first_addr = addr;
          have_first = 1;
        }

      sum = ll + (int)((addr >> 8) & 0xFF) + (int)(addr & 0xFF) + tt;

      for (i = 0; i < ll; i++)
        {
          int b = rd_byte (src, &ok);

          if (!ok)
            record_error ("INVALID HEX DIGIT", addr,
                          (addr + (unsigned)i) & 0xFFFF, data, i);

          data[i] = (unsigned char)b;
          sum += b;
        }

      cc = rd_byte (src, &ok);

      if (!ok)
        record_error ("INVALID HEX DIGIT", addr,
                      (addr + (unsigned)ll) & 0xFFFF, data, ll);

      sum += cc;

      if ((sum & 0xFF) != 0)
        record_error ("CHECKSUM ERROR ", addr,
                      (addr + (unsigned)ll) & 0xFFFF, data, ll);

      for (i = 0; i < ll; i++)
        image[(addr + (unsigned)i) & 0xFFFF] = data[i];

      if (ll > 0 && (addr + (unsigned)ll - 1) > last_addr)
        last_addr = addr + (unsigned)ll - 1;

      total_bytes += (unsigned)ll;
    }

  if (ferror (src))
    {
      (void)fclose (src);
      fatal_load ("DISK READ", have_first ? first_addr : (unsigned)TPA);
    }

  (void)fclose (src);

  if (!have_first)
    {
      first_addr = 0;
      last_addr = 0;
    }

  span = (last_addr >= first_addr) ? (last_addr - first_addr + 1) : 0;
  records = (span + RECSZ - 1) / RECSZ;

  /* Flawfinder: ignore */ /* False positive CWE-807/CWE-20 */
  if (getenv ("HEXCOM_NO_PAD") == NULL)
    {
      size_t pad_start = (size_t)first_addr + span;
      size_t pad_end = (size_t)first_addr + (size_t)records * RECSZ;

      if (pad_end > (size_t)0x10000UL)
        pad_end = (size_t)0x10000UL;

      if (pad_start < pad_end)
        (void)memset (image + pad_start, 0x1A, pad_end - pad_start);
    }

  (void)printf ("FIRST ADDRESS %04X\n", first_addr);
  (void)printf ("LAST  ADDRESS %04X\n", last_addr);
  (void)printf ("BYTES READ    %04X\n", total_bytes & 0xFFFF);
  (void)printf ("RECORDS WRITTEN %02X\n", records & 0xFFu);
  (void)printf ("\n");

  (void)fflush (stdout);
  (void)fflush (stderr);

  /* Flawfinder: ignore */ /* False positive CWE-807/CWE-20 */
  write_size = ((getenv ("HEXCOM_NO_PAD") == NULL)
                 ? (size_t)records * RECSZ
                 : (size_t)span);

  if (fwrite (image + first_addr, 1, write_size, out) != write_size)
    {
      (void)fclose (out);
      fatal_load ("DISK WRITE", first_addr);
    }

  if (fclose (out) != 0)
    fatal_load ("CANNOT CLOSE FILE", first_addr);

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
