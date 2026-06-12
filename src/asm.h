/*
 * TPZASM: TDL ZASM / PSA PASM compatible assembler - asm.h
 * Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
 * SPDX-License-Identifier: MIT-0
 * scspell-id: 082e7c62-6335-11f1-a161-246e96298730
 */

/******************************************************************************/

#ifndef ASM_H
# define ASM_H

/******************************************************************************/

# ifdef FREE
#  undef FREE
# endif

# ifndef __ORACLE_LINT__
#  define FREE(p) \
  do {            \
    free((p));    \
    (p) = NULL;   \
  } while (0)
# else
#  define FREE(p) free(p)
# endif

/******************************************************************************/

# include <stddef.h> /* size_t, NULL */

/******************************************************************************/

typedef unsigned char u8;   /* a machine byte                       */
typedef unsigned short u16; /* a 16-bit value / address (Z80 word)  */

/******************************************************************************/

typedef enum
{
  DIALECT_ZASM, /* TDL Z80 CP/M Disk Assembler 2.21 (TDL, 1976-1977) */
  DIALECT_PASM  /* PSA Macro Assembler 1.02 (Phoenix, 1980)          */
} dialect_t;

/******************************************************************************/

# define RADIX_DEFAULT 10

/******************************************************************************/

/* ---- values, symbols, relocation ----------------------------------- */

struct symbol; /* forward */

/******************************************************************************/

/*
 * A 16-bit assembly-time value with relocation attributes.  At load time the
 * effective value is  value + reloc*r.  A complete expression is legal only if
 * reloc is 0 (absolute) or 1 (relocatable), or references a single external.
 */

typedef struct
{
  u16 value;
  long reloc;         /* relocation coefficient n             */
  struct symbol *ext; /* external symbol referenced, or NULL  */
} value_t;

/******************************************************************************/

typedef struct symbol
{
  char *name;
  value_t val;
  unsigned char defined;
  unsigned char external;
  unsigned char seen; /* pass # in which last defined as a label */
  struct symbol *next;
} symbol;

/******************************************************************************/

typedef struct symtab symtab; /* opaque (src/sym.c) */

/******************************************************************************/

extern int allow_long_symbols;

/******************************************************************************/

symtab *sym_new (void);
void sym_free (symtab *t);
symbol *sym_lookup (const symtab *t, const char *name);
symbol *sym_intern (symtab *t, const char *name);
int sym_count (const symtab *t);                  /* number of symbols   */
void sym_collect (const symtab *t, symbol **buf); /* fill buf[0..count-1] */
int ci_eq (const char *a, const char *b); /* actually in src/sym.c */

/******************************************************************************/

/* ---- bounded, C89-only string/format helpers (src/sym.c) ----------- */

/* strlcpy: copy src into dst[cap]; returns strlen(src).             */
size_t xstrlcpy (char *dst, const char *src, size_t cap);

/* strlcat: append src to dst[cap]; returns the would-be length.     */
size_t xstrlcat (char *dst, const char *src, size_t cap);

int xsnprintf (char *dst, size_t cap, const char *fmt, ...);

/******************************************************************************/

/* ---- expression evaluator (src/expr.c) ----------------------------- */

typedef struct
{
  int radix;      /* current numeric radix (2/8/10/16)           */
  symtab *syms;   /* symbols for lookups (NULL => none)          */
  u16 lc;         /* location counter (for '.')                  */
  int lc_reloc;   /* relocation coeff of '.'                     */
  int undef0;     /* if set, undefined symbols evaluate to 0     */
  unsigned scope; /* local-symbol scope ('..' labels)            */
} eval_env;

/******************************************************************************/

/*
 * Evaluate a complete expression (must consume the whole string).
 */

int expr_eval (const char *s, const eval_env *env, value_t *out,
               const char **err);

/******************************************************************************/

/*
 * Evaluate ONE expression; *endp gets the stop position (does
 * not require end-of-string).  For comma-separated operand lists.
 */

int expr_eval2 (const char *s, const eval_env *env, value_t *out,
                const char **endp, const char **err);

/******************************************************************************/

/* ---- line lexer (src/lex.c) ---------------------------------------- */

# define NAMEBUF 64

typedef struct
{
  char label[NAMEBUF];  /* label/symbol to define, or ""       */
  char op[NAMEBUF];     /* mnemonic / pseudo-op, or ""         */
  const char *operands; /* operand text (into the line), or " "*/
  int assign;           /* 1: `label` = operands (= / EQU)     */
} line_t;

void lex_line (const char *line, line_t *out);

/******************************************************************************/

/* ---- two-pass driver (src/assemble.c) ------------------------------ */

int asm_source (const char *path, dialect_t dialect, const char *outpath,
                const char *lstpath, const char *relpath, /* -R: binary REL */
                const char *hexpath,                      /* -X: ASCII REL  */
                int pad, /* pad: 1=pad .com to next 128B boundary with 0x1A */
                int long_symbols);

/******************************************************************************/

/* ---- object output (src/objout.c) ---------------------------------- */

/*
 * Per-byte relocation map, parallel to the assembled image.  Each emitted
 * address is classified so the object emitter can build TDL `;' data records.
 */

# define REL_GAP 0 /* address not emitted (a .BLKB/.LOC gap)        */
# define REL_ABS 1 /* absolute byte: load unmodified                */
# define REL_LO  2 /* low byte of a .PROG.-relative 16-bit value    */
# define REL_HI  3 /* high byte of that value (follows a REL_LO)    */

typedef struct
{
  const u8 *em_byte;  /* emitted byte values, in emission order           */
  const u8 *em_rel;   /* parallel REL_* class per emitted byte            */
  const u16 *span_a;  /* emission-order span start addresses              */
  const u16 *span_n;  /* emission-order span lengths                      */
  int nspans;         /* number of emission spans                         */
  unsigned prog_size; /* .PROG. segment size (LC high-water)              */
  unsigned data_size; /* .DATA. segment size                             */
  unsigned blnk_size; /* .BLNK. segment size                             */
  int abs_mode;       /* 1 = .PABS (Intel `:' records), 0 = .PREL (`;')   */
  int data_base;      /* data-record relocation base (1 .PROG., 0 pinned) */
  unsigned start;     /* program start address (EOF record)              */
  int start_reloc;    /* start-address relocation base (0 abs, 1 .PROG.)  */
  int ascii;          /* 1 = ASCII (.PHEX), 0 = binary (.PBIN)            */
  int emit_progid;    /* 1 = emit the `+' program-id record (PASM)        */
  int xlink;          /* 1 = .XLINK: omit the `!'/`\\' link records       */
} objspec;

/*
 * Write the TDL Object Module (or Intel-hex absolute module) for `spec' to
 * `path'.  Returns 0 on success, non-zero on a file error.
 */

int obj_write (const char *path, const objspec *s);

/******************************************************************************/

/* ---- instruction table (src/insn.c) -------------------------------- */

typedef enum
{
  FMT_NONE,    /* no operand                            */
  FMT_MOV,     /* MOV r,r : 0x40 | dst<<3 | src         */
  FMT_DST,     /* reg in bits 3-5  (INR DCR)            */
  FMT_MVI,     /* reg in bits 3-5 + imm8                */
  FMT_SRC,     /* reg in bits 0-2  (ADD..CMP)           */
  FMT_RP,      /* reg pair in bits 4-5 (INX DCX DAD)    */
  FMT_LXI,     /* reg pair + imm16                      */
  FMT_PUSHPOP, /* reg pair, SP slot is PSW              */
  FMT_RP2,     /* reg pair B or D only (LDAX STAX)      */
  FMT_IMM8,    /* opcode + imm8 (ADI.. IN OUT)          */
  FMT_ADDR,    /* opcode + addr16 (JMP CALL LDA..)      */
  FMT_RST,     /* opcode | n<<3                         */
  FMT_REL,     /* Z80: opcode + signed relative disp    */
  FMT_ED16,    /* Z80: ED + opcode + addr16             */
  FMT_EDHL,    /* Z80: ED + (opcode | rp<<4)            */
  FMT_ED0,     /* Z80: ED + opcode, no operand          */
  FMT_EDDST,   /* Z80: ED + (opcode | reg<<3) (INP OUTP) */
  FMT_CBR,     /* Z80: CB + (opcode | reg)              */
  FMT_CBB,     /* Z80: CB + (opcode | bit<<3 | reg)     */
  FMT_IXP,     /* Z80: index prefix + opcode (PCIX..)   */
  FMT_IXADD,   /* Z80: DADX/DADY (ADD IX/IY,rr)         */
  FMT_IXADDR   /* Z80: LIXD/LIYD/SIXD/SIYD LD IX/IY,(a) */
} insn_fmt_t;

/******************************************************************************/

typedef struct
{
  const char *name;
  u8 opcode;
  insn_fmt_t fmt;
} insn;

/******************************************************************************/

const insn *insn_find (const char *upname); /* upname must be uppercase */

/******************************************************************************/

#endif /* ifndef ASM_H */

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
