/*
 * TPZASM: TDL ZASM / PSA PASM compatible assembler - objout.c
 * Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
 * SPDX-License-Identifier: MIT-0
 * scspell-id: 2f602c70-65f8-11f1-9720-246e96298730
 */

/******************************************************************************/

/*
 * objout - write the TDL Object Module Format (.PREL, ';' data records) or the
 * PSA "Intel-hex" absolute module (.PABS, ':' data records).  Either may be
 * serialized as raw binary (.PBIN, the -R flag) or as ASCII hex (.PHEX, -X).
 *
 * Both forms share the same record framing:
 *
 *   <prompt> <field bytes...> <checksum>
 *
 * where the checksum is the two's complement of the sum of the field bytes
 * (the prompt is excluded).  In ASCII mode each record is preceded by CR/LF and
 * every *binary* field byte is expanded to two uppercase hex digits; ASCII name
 * characters (segment/module names, blank date/time) stay literal.  Records, in
 * order: '!' module-id, '+' program-id (PASM only), '\' segment/relocation-base
 * table, the data records, and a zero-length end-of-file record carrying the
 * program start address.
 *
 * Multi-byte fields use the layout the originals emit (verified against
 * pasm.com): the data-record load address and the '\' segment sizes are stored
 * big-endian, while a relocatable 16-bit datum's value is little-endian (Z80
 * order).  Records are flushed at a 24-byte count (control+data for ';', data
 * for ':') and never split a relocatable item; a gap in the image (.BLKB/.LOC)
 * starts a fresh data record.  See the manual's Appendix D.
 */

/******************************************************************************/

#include <stdio.h>

/******************************************************************************/

#include "asm.h"

/******************************************************************************/

#define REC_CAP  24 /* max count field per data record (control+data / data) */
#define FIELDMAX 96 /* field bytes buffered per record (>= worst case)       */

/******************************************************************************/

/*
 * A record being assembled: field byte values (for the checksum) plus a flag
 * per byte saying whether it is binary (hex-expanded in ASCII mode) or a
 * literal ASCII character.
 */

typedef struct
{
  FILE *f;
  int ascii;
  char prompt;
  u8 val[FIELDMAX];
  u8 lit[FIELDMAX]; /* 1 = literal ASCII char, 0 = binary byte */
  int n;
} recbuf;

/******************************************************************************/

static void
rb_begin (recbuf *r, FILE *f, int ascii, char prompt)
{
  r->f = f;
  r->ascii = ascii;
  r->prompt = prompt;
  r->n = 0;
}

/******************************************************************************/

static void
rb_bin (recbuf *r, unsigned b) /* a binary byte (hex-expanded in ASCII mode) */
{
  if (r->n < FIELDMAX)
    {
      r->val[r->n] = (u8)(b & 0xFFu);
      r->lit[r->n] = 0;
      r->n++;
    }
}

/******************************************************************************/

static void
rb_lit (recbuf *r, unsigned b) /* a literal ASCII character (both modes) */
{
  if (r->n < FIELDMAX)
    {
      r->val[r->n] = (u8)(b & 0xFFu);
      r->lit[r->n] = 1;
      r->n++;
    }
}

/******************************************************************************/

static void
rb_be16 (recbuf *r, unsigned w) /* a 16-bit value, big-endian */
{
  rb_bin (r, w >> 8);
  rb_bin (r, w & 0xFFu);
}

/******************************************************************************/

static void
rb_name (recbuf *r, const char *s) /* 6 chars, left-justified, blank-filled */
{
  int i;

  for (i = 0; i < 6; i++)
    {
      if ('\0' == s[i])
        break;

      rb_lit (r, (unsigned)(u8)s[i]);
    }

  for (; i < 6; i++)
    rb_lit (r, ' ');
}

/******************************************************************************/

static void
put_hex2 (FILE *f, unsigned b)
{
  static const char H[] = "0123456789ABCDEF";

  (void)fputc (H[(b >> 4) & 0xFu], f);
  (void)fputc (H[b & 0xFu], f);
}

/******************************************************************************/

static void
rb_flush (recbuf *r)
{
  unsigned sum = 0;
  unsigned ck;
  int i;

  for (i = 0; i < r->n; i++)
    sum += r->val[i];

  ck = (0u - sum) & 0xFFu; /* two's complement of the field-byte sum */

  if (r->ascii)
    {
      (void)fputc ('\r', r->f);
      (void)fputc ('\n', r->f);
      (void)fputc (r->prompt, r->f);

      for (i = 0; i < r->n; i++)
        {
          if (r->lit[i])
            (void)fputc (r->val[i], r->f);
          else
            put_hex2 (r->f, (unsigned)r->val[i]);
        }

      put_hex2 (r->f, ck);
    }
  else
    {
      (void)fputc (r->prompt, r->f);

      for (i = 0; i < r->n; i++)
        (void)fputc (r->val[i], r->f);

      (void)fputc ((int)ck, r->f);
    }
}

/******************************************************************************/

/* Emit one relocatable ';' data record for the contiguous bytes beginning at
 * eb[0..avail-1] (with classes er[]), loading at `addr'; returns the number of
 * emission-log bytes consumed.
 *
 * Within the record, an absolute byte carries one control bit ('0') and a
 * .PROG.-relative 16-bit value carries two ('1' then '0') -- so there is
 * exactly one control bit per *data* byte, and a control byte governs the next
 * eight data bytes.  A 16-bit value may therefore straddle the eight-byte
 * boundary (its `10' code split between two control bytes); the data stream is
 * laid out as [control byte][<=8 data bytes][control byte][<=8 data bytes]...
 */

static int
emit_prel_record (FILE *f, int ascii, const u8 *eb, const u8 *er, long addr,
                  int avail, int base)
{
  u8 data[REC_CAP + 2] = { 0 };
  u8 cbit[REC_CAP + 2] = { 0 }; /* control bit accompanying data[i] */
  int i = 0; /* emission-log bytes consumed by this record */
  int ndata = 0; /* data bytes accumulated for this record */
  int nctrl, c;
  recbuf r;

  /*
   * accept items while the count so far (data + control bytes) is below
   * REC_CAP; the item is then added whole, so a 16-bit value never splits
   * across a record (and may push the final count to 25 - the originals
   * emit a reloc16 begun while still under the cap).
   */
  while (i < avail)
    {
      int reloc = (REL_LO == er[i]);
      int id = (reloc ? 2 : 1);
      int cnt = ndata + (ndata + 7) / 8; /* count if we stopped right here */

      if (cnt >= REC_CAP && ndata > 0)
        break;

      data[ndata] = eb[i];
      cbit[ndata] = (u8)(reloc ? 1 : 0); /* reloc16 low: '1', absolute: '0' */

      if (reloc)
        {
          data[(long)ndata + 1] = eb[(long)i + 1];
          cbit[(long)ndata + 1] = 0; /* reloc16 high byte: trailing '0'     */
        }

      ndata += id;
      i += id;
    }

  /*
   * frame the record: ';' count load-addr(BE) reloc-base body.  The
   * accumulation cap above keeps ndata well under the buffer size; pin that
   * bound explicitly (never triggers) so static analyzers can prove the
   * data[]/cbit[] indexing below stays in range.
   */
  if (ndata > REC_CAP + 2)
    ndata = REC_CAP + 2;

  nctrl = (ndata + 7) / 8;
  rb_begin (&r, f, ascii, ';');
  rb_bin (&r, (unsigned)(ndata + nctrl));
  rb_be16 (&r, (unsigned)addr);
  rb_bin (&r, (unsigned)base); /* relocation base (.PROG. = 1, pinned = 0) */

  for (c = 0; c < nctrl; c++)
    {
      int b = c * 8;
      unsigned ctrl = 0;
      int k;

      for (k = 0; k < 8 && b + k < ndata; k++)
        if (cbit[(long)b + k])
          ctrl |= (0x80u >> k);

      rb_bin (&r, ctrl);

      for (k = 0; k < 8 && b + k < ndata; k++)
        rb_bin (&r, (unsigned)data[(long)b + k]);
    }

  rb_flush (&r);

  return i;
}

/******************************************************************************/

/*
 * Emit one absolute ':' data record (up to REC_CAP bytes) from eb[], loading
 * at `addr'; returns the number of bytes consumed.
 */

static int
emit_pabs_record (FILE *f, int ascii, const u8 *eb, long addr, int avail,
                  int base)
{
  int n = ((avail < REC_CAP) ? avail : REC_CAP);
  int k;
  recbuf r;

  rb_begin (&r, f, ascii, ':');
  rb_bin (&r, (unsigned)n);
  rb_be16 (&r, (unsigned)addr);
  rb_bin (&r, (unsigned)base); /* base/segment byte (Intel "unused" slot) */

  for (k = 0; k < n; k++)
    rb_bin (&r, (unsigned)eb[k]);

  rb_flush (&r);

  return n;
}

/******************************************************************************/

int
obj_write (const char *path, const objspec *s)
{
  FILE *f = fopen (path, "wb");
  recbuf r;

  if (NULL == f)
    return 1;

  /* '!' module identification record (omitted under .XLINK) */
  if (!s->xlink)
    {
      rb_begin (&r, f, s->ascii, '!');
      rb_name (&r, ".MAIN.");
      rb_flush (&r);
    }

  /* '+' program identification record (PASM emits it; ZASM omits it) */
  if (s->emit_progid)
    {
      int i;

      rb_begin (&r, f, s->ascii, '+');
      rb_name (&r, "      "); /* blank (6-space) program id */
      rb_bin (&r, 0);   /* version  */
      rb_bin (&r, 0);   /* revision */

      for (i = 0; i < 12; i++)
        rb_lit (&r, ' '); /* date (MMDDYY) + time (HHMMSS): unavailable */

      rb_flush (&r);
    }

  /*
   * '\' segment / relocation-base table: .PROG.=1, .DATA.=2, .BLNK.=3 (the
   * caller reports size 0 for a pinned/absolute .PROG. segment).  Omitted under
   * .XLINK, which writes a relocatable core image of `;' records only.
   */
  if (!s->xlink)
    {
      rb_begin (&r, f, s->ascii, '\\');
      rb_bin (&r, 3);
      rb_name (&r, ".PROG.");
      rb_bin (&r, 1);
      rb_be16 (&r, s->prog_size);
      rb_name (&r, ".DATA.");
      rb_bin (&r, 2);
      rb_be16 (&r, s->data_size);
      rb_name (&r, ".BLNK.");
      rb_bin (&r, 3);
      rb_be16 (&r, s->blnk_size);
      rb_flush (&r);
    }

  /*
   * data records: walk the emission-order spans (each a contiguous run of
   * emitted addresses), breaking every record at REC_CAP.  The originals write
   * records in emission order, so a span filled at a low address after a high
   * one produces a record that loads "backwards" -- this is required to match
   * programs that revisit earlier regions via .LOC (e.g. SARGON).
   */
  {
    int sp;
    long emoff = 0; /* running offset into the emission log */

    for (sp = 0; sp < s->nspans; sp++)
      {
        const u8 *eb = s->em_byte + emoff;
        const u8 *er = s->em_rel + emoff;
        long addr = (long)s->span_a[sp];
        int avail = (int)s->span_n[sp];

        while (avail > 0)
          {
            int used;

            if (s->abs_mode)
              used = emit_pabs_record (f, s->ascii, eb, addr, avail,
                                       s->data_base);
            else
              used = emit_prel_record (f, s->ascii, eb, er, addr, avail,
                                       s->data_base);

            eb += used;
            er += used;
            addr += used;
            avail -= used;
          }

        emoff += (long)s->span_n[sp];
      }
  }

  /* end-of-file record: zero count + start address + relocation base */
  rb_begin (&r, f, s->ascii, (s->abs_mode ? ':' : ';'));
  rb_bin (&r, 0);
  rb_be16 (&r, s->start);
  rb_bin (&r, (s->abs_mode ? 0 : (unsigned)(s->start_reloc ? 1 : 0)));
  rb_flush (&r);

  if (0 != fclose (f))
    return 1;

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
