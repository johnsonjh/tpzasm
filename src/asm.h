/*
 * ASM - TDL/Phoenix ZASM/PASM compatible assembler
 * Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
 * SPDX-License-Identifier: MIT-0
 * scspell-id: 082e7c62-6335-11f1-a161-246e96298730
 */

/******************************************************************************/

/*
 * asm.h - common declarations for the TDL ZASM / PSA PASM assembler clone.
 */

/******************************************************************************/

#ifndef ASM_H
#define ASM_H

/******************************************************************************/

#include <stddef.h>           /* size_t, NULL */

/******************************************************************************/

typedef unsigned char  u8;    /* a machine byte                       */
typedef unsigned short u16;   /* a 16-bit value / address (Z80 word)  */

/******************************************************************************/

typedef enum {
    DIALECT_ZASM,             /* TDL Z80 CP/M Disk Assembler 2.21     */
    DIALECT_PASM              /* PSA Macro Assembler (Phoenix, 1980)  */
} dialect_t;

/******************************************************************************/

#define ASM_VERSION   "0.0.1"
#define RADIX_DEFAULT 10

/******************************************************************************/

/* ---- values, symbols, relocation ----------------------------------- */

struct symbol;                    /* forward */

/******************************************************************************/

/* A 16-bit assembly-time value with relocation attributes.  At load time the
 * effective value is  value + reloc*r.  A complete expression is legal only if
 * reloc is 0 (absolute) or 1 (relocatable), or references a single external. */
typedef struct {
    u16            value;
    long           reloc;     /* relocation coefficient n             */
    struct symbol *ext;       /* external symbol referenced, or NULL  */
} value_t;

/******************************************************************************/

typedef struct symbol {
    char          *name;
    value_t        val;
    unsigned char  defined;
    unsigned char  external;
    unsigned char  seen;       /* pass # in which last defined as a label */
    struct symbol *next;
} symbol;

/******************************************************************************/

typedef struct symtab symtab;    /* opaque (src/sym.c) */

/******************************************************************************/

symtab *sym_new(void);
void    sym_free(symtab *t);
symbol *sym_lookup(const symtab *t, const char *name);
symbol *sym_intern(symtab *t, const char *name);
int     sym_count(const symtab *t);                  /* number of symbols   */
void    sym_collect(const symtab *t, symbol **buf);  /* fill buf[0..count-1] */

/******************************************************************************/

/* ---- expression evaluator (src/expr.c) ----------------------------- */

typedef struct {
    int     radix;     /* current numeric radix (2/8/10/16)           */
    symtab *syms;      /* symbols for lookups (NULL => none)          */
    u16     lc;        /* location counter (for '.')                  */
    int     lc_reloc;  /* relocation coeff of '.'                     */
    int     undef0;    /* if set, undefined symbols evaluate to 0     */
    unsigned scope;    /* local-symbol scope ('..' labels)            */
} eval_env;

/******************************************************************************/

/* Evaluate a complete expression (must consume the whole string). */
int expr_eval(const char *s, const eval_env *env, value_t *out, const char **err);

/******************************************************************************/

/* Evaluate ONE expression; *endp gets the stop position (does not require
 * end-of-string).  For comma-separated operand lists. */
int expr_eval2(const char *s, const eval_env *env, value_t *out,
               const char **endp, const char **err);

/******************************************************************************/

/* ---- line lexer (src/lex.c) ---------------------------------------- */

#define NAMEBUF 64

typedef struct {
    char        label[NAMEBUF];  /* label/symbol to define, or ""      */
    char        op[NAMEBUF];     /* mnemonic / pseudo-op, or ""        */
    const char *operands;        /* operand text (into the line), or ""*/
    int         assign;          /* 1: `label` = operands (= / EQU)    */
} line_t;

/******************************************************************************/

void lex_line(const char *line, line_t *out);

/* ---- two-pass driver (src/assemble.c) ------------------------------ */

/******************************************************************************/

int asm_source(const char *path, dialect_t dialect, const char *outpath,
               const char *lstpath, int pad);   /* pad: 1=pad .com to 128B with 0x1A */

/* ---- instruction table (src/insn.c) -------------------------------- */

/******************************************************************************/

enum {
    FMT_NONE,      /* no operand                           */
    FMT_MOV,       /* MOV r,r : 0x40 | dst<<3 | src        */
    FMT_DST,       /* reg in bits 3-5  (INR DCR)           */
    FMT_MVI,       /* reg in bits 3-5 + imm8               */
    FMT_SRC,       /* reg in bits 0-2  (ADD..CMP)          */
    FMT_RP,        /* reg pair in bits 4-5 (INX DCX DAD)   */
    FMT_LXI,       /* reg pair + imm16                     */
    FMT_PUSHPOP,   /* reg pair, SP slot is PSW             */
    FMT_RP2,       /* reg pair B or D only (LDAX STAX)     */
    FMT_IMM8,      /* opcode + imm8 (ADI.. IN OUT)         */
    FMT_ADDR,      /* opcode + addr16 (JMP CALL LDA..)     */
    FMT_RST,       /* opcode | n<<3                        */
    FMT_REL,       /* Z80: opcode + signed relative disp   */
    FMT_ED16,      /* Z80: ED + opcode + addr16            */
    FMT_EDHL,      /* Z80: ED + (opcode | rp<<4)           */
    FMT_ED0,       /* Z80: ED + opcode, no operand         */
    FMT_CBR,       /* Z80: CB + (opcode | reg)             */
    FMT_CBB,       /* Z80: CB + (opcode | bit<<3 | reg)    */
    FMT_IXP,       /* Z80: index prefix + opcode (PCIX..)  */
    FMT_IXADD,     /* Z80: DADX/DADY (ADD IX/IY,rr)        */
    FMT_IXADDR     /* Z80: LIXD/LIYD/SIXD/SIYD LD IX/IY,(a)*/
};

/******************************************************************************/

typedef struct { const char *name; u8 opcode; int fmt; } insn;

/******************************************************************************/

const insn *insn_find(const char *upname);   /* upname must be uppercase */

/******************************************************************************/

#endif /* ASM_H */

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
