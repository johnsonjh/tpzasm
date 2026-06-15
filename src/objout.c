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
 * The relocation control bytes form a prefix-coded BIT stream (read left to
 * right): '0' = one absolute byte; '10' = a 16-bit value relative to this
 * record's base (2 data bytes LSB,MSB); '110' = a 16-bit value relative to a
 * DIFFERENT base (3 data bytes: base#, LSB, MSB); '111' = an 8-bit value
 * relative to a different (external) base (2 data bytes: base#, value).  Each
 * control byte holds eight bits; a code's bits may straddle the boundary into
 * the next control byte.  For the common 0/10/110 codes there is one data byte
 * per control bit, and a data byte is written after the control byte whose
 * eight-bit window holds its owning bit -- so a code whose bits straddle a
 * boundary has its data bytes split across the two control bytes (a `10' word
 * in bits 7/8 lays its LSB after this control byte, its MSB after the next).
 * The layout is [control][data owned by this control byte's bits][control]...
 */

static int
emit_prel_record (FILE *f, int ascii, const u8 *eb, const u8 *er,
                  const u8 *etb, long addr, int avail, int base)
{
  u8 bit[REC_CAP * 8 + 16] = { 0 }; /* control-bit stream */
  u8 data[REC_CAP + 8] = { 0 };     /* data-byte stream   */
  int istart[REC_CAP + 8] = { 0 };  /* start bit of each item */
  int dbit[REC_CAP + 8] = { 0 };    /* control bit that owns each data byte */
  int nbits = 0, ndata = 0, nitem = 0;
  int i = 0; /* emission-log bytes consumed by this record */
  int nctrl, c, doff;
  recbuf r;

  /*
   * accept items while the record byte count (control + data) stays below
   * REC_CAP; the item is then added whole, so a code never splits across a
   * record boundary (its data bytes stay together).
   */
  while (i < avail)
    {
      int reloc = (REL_LO == er[i]);
      int ext8 = (REL_EXT8 == er[i]);
      int cross = (reloc && (int)etb[i] != base); /* different-base 16-bit */
      int id = (reloc ? 2 : 1);          /* emission-log bytes consumed */
      int cnt = (nbits + 7) / 8 + ndata; /* record bytes if we stop here */

      if (cnt >= REC_CAP && ndata > 0)
        break;

      /*
       * the REC_CAP acceptance test above keeps the buffers well under their
       * sizes; pin those bounds explicitly (these never trigger) so static
       * analyzers can prove the bit[]/data[]/istart[]/dbit[] indexing below
       * stays in range.
       */
      if (ndata + 3 > REC_CAP + 8)
        break;

      if (nbits + 3 > REC_CAP * 8 + 16)
        break;

      if (nitem + 1 > REC_CAP + 8)
        break;

      istart[nitem] = nbits;

      if (ext8)
        { /* '111': base#, 8-bit value */
          bit[nbits++] = 1;
          bit[nbits++] = 1;
          bit[nbits++] = 1;
          data[ndata] = etb[i];
          dbit[ndata] = istart[nitem];
          data[(long)ndata + 1] = eb[i];
          dbit[(long)ndata + 1] = istart[nitem] + 1;
          ndata += 2;
        }
      else if (cross)
        { /* '110': base#, LSB, MSB */
          bit[nbits++] = 1;
          bit[nbits++] = 1;
          bit[nbits++] = 0;
          data[ndata] = etb[i];
          dbit[ndata] = istart[nitem];
          data[(long)ndata + 1] = eb[i];
          dbit[(long)ndata + 1] = istart[nitem] + 1;
          data[(long)ndata + 2] = eb[(long)i + 1];
          dbit[(long)ndata + 2] = istart[nitem] + 2;
          ndata += 3;
        }
      else if (reloc)
        { /* '10': LSB, MSB */
          bit[nbits++] = 1;
          bit[nbits++] = 0;
          data[ndata] = eb[i];
          dbit[ndata] = istart[nitem];
          data[(long)ndata + 1] = eb[(long)i + 1];
          dbit[(long)ndata + 1] = istart[nitem] + 1;
          ndata += 2;
        }
      else
        { /* '0': absolute */
          bit[nbits++] = 0;
          data[ndata] = eb[i];
          dbit[ndata] = istart[nitem];
          ndata += 1;
        }

      nitem++;
      i += id;
    }

  nctrl = (nbits + 7) / 8;
  rb_begin (&r, f, ascii, ';');
  rb_bin (&r, (unsigned)(nctrl + ndata));
  rb_be16 (&r, (unsigned)addr);
  rb_bin (&r, (unsigned)base); /* relocation base (.PROG. = 1, pinned = 0) */

  doff = 0;

  for (c = 0; c < nctrl; c++)
    {
      unsigned ctrl = 0;
      int k;

      for (k = 0; k < 8; k++)
        if ((c * 8 + k) < nbits && bit[(long)c * 8 + k])
          ctrl |= (0x80u >> k);

      rb_bin (&r, ctrl);

      /*
       * Each data byte is written after the control byte whose 8-bit window
       * holds the control bit that owns it (dbit[]).  A code whose bits
       * straddle a control-byte boundary therefore has its data split across
       * the two control bytes -- e.g. a relocatable word whose `10' in bits
       * 7/8 lays its LSB after this control byte and its MSB after the next.
       * (doff < REC_CAP + 8 by construction; the explicit bound lets static
       * analyzers prove the data[] read stays in range.)
       */
      while (doff < ndata && doff < REC_CAP + 8 && dbit[doff] < (c + 1) * 8)
        {
          rb_bin (&r, (unsigned)data[doff]);
          doff++;
        }
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

/*
 * Open an object stream for writing (raw binary, the records carry their own
 * ASCII/binary framing via objspec.ascii).  Returns NULL on a file error.
 */

FILE *
obj_open (const char *path)
{
  return fopen (path, "wb");
}

/******************************************************************************/

/*
 * Close an object stream.  Returns 0 on success, non-zero on a file error.
 */

int
obj_close (FILE *f)
{
  return (0 != fclose (f)) ? 1 : 0;
}

/******************************************************************************/

/*
 * Append one module's complete record framing (`!' `+' `@' `\' `#', the data
 * records, and the end-of-file record) to an open object stream.  A single
 * object file holds one such module per .END, or several independent modules
 * separated by .PRGEND ("library file generation"); each module emits its own
 * full framing, so this is called once per module.
 */

void
obj_module (FILE *f, const objspec *s)
{
  recbuf r;

  /* '!' module identification record (omitted under .XLINK) */
  if (!s->xlink)
    {
      rb_begin (&r, f, s->ascii, '!');
      rb_name (&r, (NULL != s->modname) ? s->modname : ".MAIN.");
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
   * '@' entry-point records (.ENTRY), at most eight 6-char names per record.
   * Omitted under .XLINK.
   */
  if (!s->xlink && s->nents > 0)
    {
      int j = 0;

      while (j < s->nents)
        {
          int n = ((s->nents - j < 8) ? s->nents - j : 8);
          int k;

          rb_begin (&r, f, s->ascii, '@');
          rb_bin (&r, (unsigned)n);

          for (k = 0; k < n; k++)
            rb_name (&r, s->ents[(long)j + k].name);

          rb_flush (&r);
          j += n;
        }
    }

  /*
   * '\' segment / relocation-base table: the three predefined segments
   * (.PROG.=1, .DATA.=2, .BLNK.=3, with their sizes) followed by the external
   * bases (size 0), at most four entries per record.  Omitted under .XLINK.
   */
  if (!s->xlink)
    {
      objsym segs[3];
      int total, j;

      (void)xstrlcpy (segs[0].name, ".PROG.", sizeof (segs[0].name));
      segs[0].base = 1;
      segs[0].value = (u16)s->prog_size;
      (void)xstrlcpy (segs[1].name, ".DATA.", sizeof (segs[1].name));
      segs[1].base = 2;
      segs[1].value = (u16)s->data_size;
      (void)xstrlcpy (segs[2].name, ".BLNK.", sizeof (segs[2].name));
      segs[2].base = 3;
      segs[2].value = (u16)s->blnk_size;

      total = 3 + s->nexts;

      for (j = 0; j < total;)
        {
          int n = ((total - j < 4) ? total - j : 4);
          int k;

          rb_begin (&r, f, s->ascii, '\\');
          rb_bin (&r, (unsigned)n);

          for (k = 0; k < n; k++)
            {
              const objsym *e = (((long)j + k < 3) ? &segs[(long)j + k]
                                             : &s->exts[(long)j + k - 3]);
              rb_name (&r, e->name);
              rb_bin (&r, (unsigned)e->base);
              rb_be16 (&r, (unsigned)e->value);
            }

          rb_flush (&r);
          j += n;
        }
    }

  /*
   * '#' internal-symbol records (name, base#, value): the entry-point symbols
   * (.ENTRY) form one group, the plain internal symbols (.INTERN) another;
   * each group is at most four entries per record.  Omitted under .XLINK.
   */
  if (!s->xlink)
    {
      int g;

      for (g = 0; g < 2; g++)
        {
          const objsym *grp = ((0 == g) ? s->ents : s->ints);
          int ng = ((0 == g) ? s->nents : s->nints);
          int j = 0;

          while (j < ng)
            {
              int n = ((ng - j < 4) ? ng - j : 4);
              int k;

              rb_begin (&r, f, s->ascii, '#');
              rb_bin (&r, (unsigned)n);

              for (k = 0; k < n; k++)
                {
                  rb_name (&r, grp[(long)j + k].name);
                  rb_bin (&r, (unsigned)grp[(long)j + k].base);
                  rb_be16 (&r, (unsigned)grp[(long)j + k].value);
                }

              rb_flush (&r);
              j += n;
            }
        }
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
        const u8 *et = s->em_tbase + emoff;
        long addr = (long)s->span_a[sp];
        int avail = (int)s->span_n[sp];
        /* each ';' record loads relative to the span's active base */
        int rbase = ((NULL != s->span_seg) ? (int)s->span_seg[sp]
                                           : s->data_base);

        while (avail > 0)
          {
            int used;

            if (s->abs_mode)
              /* the ':' base/segment byte is per-span: bytes emitted while the
               * LC was still relocatable (.PROG. base 1, before any absolute
               * .LOC) carry that base even in an otherwise absolute module --
               * e.g. an `O'-error placeholder ahead of the first .LOC */
              used = emit_pabs_record (f, s->ascii, eb, addr, avail, rbase);
            else
              used = emit_prel_record (f, s->ascii, eb, er, et, addr, avail,
                                       rbase);

            eb += used;
            er += used;
            et += used;
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

  /*
   * '&' symbol-table records (.PSYM), appended AFTER the EOF for the PSA BUG
   * debugger: every global symbol -- the segment bases, the externals, then
   * the locally-defined symbols -- as name(6)+base#(1)+value(BE16), at most
   * four per record.  (Default .XPSYM emits none.)
   */
  if (s->psym)
    {
      int j = 0;

      while (j < s->npsyms)
        {
          int n = ((s->npsyms - j < 4) ? s->npsyms - j : 4);
          int k;

          rb_begin (&r, f, s->ascii, '&');
          rb_bin (&r, (unsigned)n);

          for (k = 0; k < n; k++)
            {
              rb_name (&r, s->psyms[(long)j + k].name);
              rb_bin (&r, (unsigned)s->psyms[(long)j + k].base);
              rb_be16 (&r, (unsigned)s->psyms[(long)j + k].value);
            }

          rb_flush (&r);
          j += n;
        }
    }
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
