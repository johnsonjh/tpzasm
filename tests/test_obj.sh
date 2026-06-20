#!/bin/sh
# TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/test_obj.sh
# Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
# SPDX-License-Identifier: MIT-0
# scspell-id: 2f66b7de-65f8-11f1-909c-246e96298730

################################################################################

# Object-output regression test (no CP/M oracle required).
#
# Re-assembles each source with the clone's -R (binary TDL REL / Intel-hex
# absolute) and -X (ASCII) object emitters and diffs the result against the
# committed golden files in tests/golden/.  Those golden files were captured
# from the clone AFTER its object output was verified byte-for-byte identical
# to PSA PASM 1.02 (orig/pasm.com) via tools/vrel.sh, so any change here is a
# regression.  See tools/vrel.sh for the differential test against the original.

set -eu

# Each entry: source[.asm] under tests/, golden basename under tests/golden/.
# Covers relocatable (.PREL) modules with multi-record packing and a
# relocation-control-byte straddle (objword), the .BLKB gap case (data), the
# full 8080 instruction sweep (insn8080), an absolute (.PABS) program that
# revisits earlier addresses via .LOC, exercising emission-order records and
# overwritten bytes (sargon), and the Z80 I/O / overflow-alias instructions plus
# .RAD40, the .SYN family, .EXIT/.IF1/.IF2, and the truncated spellings (newkw),
# and two fully independent modules separated by .PRGEND -- "library file
# generation" -- each emitting its own !/+/@/\\/#/; record framing (prgend),
# and default 6-character symbol truncation feeding the @/#/\\ name fields and
# the relocation references (longname), the '@' remainder operator applied to
# identifier operands -- '@' is an operator, not a symbol char (oprem) -- and
# the .LIMAGE/.XIMAGE data directives, whose multi-line listing image must not
# perturb the object output (limage), the "#" inline external-symbol modifier
# (SYM# == .EXTERN SYM), which must emit the same external records as an
# explicit .EXTERN (extmod), .XLINK, which suppresses every link record
# (!/@/\\/#) and emits only the ';' data stream + EOF (xlink), and the .I8080
# mode, under which a Z80 instruction is still assembled (the "Z" warning does
# not change the emitted bytes) -- .Z80 re-enables the extensions (i8080) --
# the internal-definition delimiters ::/=:/==:, which declare a symbol internal
# at its definition, emitting the same '#' record as .INTERN (intern), and the
# signed-comparison/symbol-test conditionals .IFG/.IFGE/.IFL/.IFLE/.IFDEF/
# .IFNDEF, whose branch selection determines which bytes are emitted (cond2),
# the macro apostrophe-concatenation operator, which pastes a macro argument
# onto adjacent text to form a symbol -- JR'A with A=Z builds JRZ (mconcat) --
# the blank-argument conditionals .IFB/.IFNB (the last two of the 14 IF forms;
# PASM-only -- ZASM's are buggy) with both branches taken (ifbnb), a macro
# defined inside another macro, callable once the outer macro runs (macnest),
# .INSERT with an ignored drive specifier and the default .ASM extension
# (dinsert -> isub), and the one-level-only rule: a nested .INSERT is an "F"
# error and is not performed (insnest -> insnsub, whose .INSERT isub is
# skipped), and .PSYM, which appends the "&" global-symbol-table object record
# (segment bases, externals, then defined symbols in definition order) for the
# PSA BUG debugger -- ".." locals excluded (psym) -- .TEMPS local temporaries
# referenced as ![sub] inside a macro (PASM-only; temps), the "&" macro
# argument-count operator (PASM-only; varargs), and trailing (extra) operands,
# which the originals flag Q/AQ/A/AA but still assemble the valid prefix of
# (extop), and a reference to a multiply-defined symbol, which flags the using
# line "D" (a "?" just past the symbol) but keeps the symbol's first value, so
# the emitted object is unchanged (dref), and the single-line inline
# conditional form ".IFx cond,[stmt][else]", whose taken branch assembles on
# the directive's own line (cinl), and .LADDR, which lists 16-bit values in
# load (memory) order -- a listing-only mode, so the object is unchanged
# (laddr; its .LADDR rendering is verified by hand against the originals), and
# the real-world TDL ZAPPLE 2-K monitor (c) 1976 -- a large .PREL/.XLINK source
# exercising mnemonic-as-value operands (MVI A,JMP == MVI A,0C3H), double-quoted
# character constants (CPI "'"), the multi-line "] ... [" else form, and a
# relocation-control-byte straddle across many consecutive relocatable JMP
# vectors (zapple; object byte-exact to BOTH zasm.com -z and pasm.com -p), and
# the smaller TDL ZAP 1-K monitor (c) 1977 -- the same .PREL/.XLINK relocatable
# form, a second real-world vindication of the JMP-vector relocation straddle
# (zap1k; object byte-exact to BOTH originals), and
# the real-world TDL Z80 disassembler (c) 1979 -- an absolute (.PABS) program
# using .LADDR/.LALL, mid-source .RADIX 16/10, double-quoted .TITLE/.SBTTL, and
# many .LOC-addressed tables (dis; object byte-exact to BOTH originals), and the
# empty-body[0] macro call-line-LC cases (maclc), the .SALL macro-collapse cases
# (sall), the labeled-conditional LC cases (clabel) and the .PAGE eject /
# ZASM-Q-on-operand cases (page) -- object byte-exact; their LISTINGS are the
# subject of tests/test_listing.sh.  The
# trailing group (cond imain macro macro2 str z80 z80b z80c) were originally
# added as standalone LISTING fixtures (compared by hand against the originals);
# their emitted object is byte-exact too, so they are guarded here as well.
# Finally, the binary-shift operators < and > (shift), whose count is a 16-bit
# two's-complement value: a magnitude of 16 or more shifts to 0 (NOT a modulo-16
# wrap of the count) and a negative count reverses the shift direction -- the
# emitted .WORD values are byte-exact vs PASM 1.02, ZASM 2.21, and PASM 2.00G.
cases="smoke data insn8080 objword sargon newkw seg blnk ext prgend longname \
oprem limage extmod xlink i8080 intern cond2 mconcat ifbnb macnest dinsert \
insnest psym temps varargs extop dref cinl laddr zapple zap1k dis maclc sall \
clabel \
page cond imain macro macro2 str z80 z80b z80c go ittl atu4 mtu4 quotes cond3 \
relmode bios tapelib ssmon turbobs progid goto gotoedge regnum shift"

# PASM 2.00G (.ZOP standard Zilog + .EPOP Intel/M80) fixtures, asserted with
# --pasm2 against the ASCII (.hex) golden only.  zop is the full Zilog
# instruction sweep; zoponly exercises .ZOP without .EPOP (Zilog mnemonics with
# the TDL dotted pseudo-ops) and epoponly the reverse (.EPOP without .ZOP: the
# Intel pseudo-ops with the 8080/TDL mnemonic set) -- the two mode axes are
# independent.  zmac exercises the TDL `.DEFINE' macro mechanism with Zilog-
# mnemonic bodies (PASM 2.00G has NO M80 `MACRO'/`ENDM' -- both pasm2.com and
# the clone reject those as `O' errors -- only `.DEFINE').  Their .PABS/.PHEX
# sources select the ASCII object; only that form is golden-checked (2.00G packs
# the binary .PBIN records differently -- identical content, different framing
# -- so it is not differenced).  zexh is the generated EXHAUSTIVE Zilog sweep
# (every mnemonic x every operand form, 810 instructions).  intcond exercises
# the Intel/M80 TITLE/SUBTTL/PAGE headings and the IF/IFT/IFE/IFF/COND + ELSE +
# ENDIF/ENDC conditionals (no bracket blocks); it omits .XLINK to dodge a pasm2
# object-writer bug (docs/re/pasm2-bugs.md).  spell11 is the flagship real-world
# 2.00G source -- "A Poor Person's Spelling Checker" (A. Bomberger / J. Byram,
# Dr. Dobb's Journal #66, 1981/82), the canonical .ZOP/.EPOP program.  All are
# byte-exact vs pasm2.com (tools/vpasm2.sh).
pasm2_cases="zop zexh zoponly epoponly zmac intcond spell11"

# Some real-world fixtures read assembly-time '\' console values; their answers
# (the system options that select the assembled configuration) live in a
# committed tests/<case>.ans file, fed to the clone with -r so the run is
# non-interactive and deterministic.  go (a CP/M Users' Group GO command) and
# the quote-handling audit (quotes -- ' " and / interchangeably in char
# constants, .BYTE/.WORD/.ASCII/.ASCIZ/.ASCIS, plus .IFB '' == .IFB "") need no
# answers; ittl (ITS100/TIP linker), atu4 and mtu4 (Alloy cipher/mag-tape
# utilities) each take their port-group and overlap options from <case>.ans.
# cond3 is a conditional-block / local-symbol audit: a multi-line `.ife COND,['
# whose body closes `stmt]' on a later line (the close may sit after a comment),
# a block whose FIRST statement shares the `.ife' line, a skipped multi-line
# block that must not swallow the next block, a `$'-leading symbol ($ is an
# ordinary Radix-40 char, not the location counter), a `..local' EQUATE used in
# an expression (scope-qualified like a `..local:' label), a trailing block-
# close `]' that is not flagged as an extra operand, and the zasm.com quirk
# whereby an .ascii string whose close quote abuts an inline `]' loses its last
# char (ZASM only; PASM keeps it) -- byte-exact both dialects.  relmode covers
# .PABS keeping the LC RELOCATABLE until a `.LOC' (so `.RELOC' lists `0000'',
# the .PROG. base, not `0000') -- .PABS selects only the absolute object format.
# bios is the real-world DMS/3, DMS/4 CP/M BIOS (~9300 lines) that drove all of
# the above conditional/local/`$'/`.ascii'/`.PABS' fixes (SELECT=1/HARDboot=0 in
# bios.ans); it is byte-exact in OBJECT and LISTING against BOTH originals.
# tapelib is the real-world TAPELIB cassette-tape library manager (S. J. Singer,
# 1977), a .PABS COM built entirely from TDL `.DEFINE' macros; it drove the
# macro engine's `PARAM(default)' default values, `%'-prefixed auto-generated
# local labels (`..NNNN'), the paste-right apostrophe (`.ASCII 'A$''),
# `$'-leading dummy substitution, and bracketed `.IFB/.IFNB/.IFIDN' arguments --
# byte-exact in OBJECT and LISTING vs BOTH originals; its provided tapelib.com
# matches bit-for-bit once its saved dirty-RAM BSS tail is excluded.  ssmon is
# the ZAPPLE 2-K monitor V2.R (Computer Design Labs / TDL, (c) 1978, re-keyed by
# Herb Johnson in 2019 from a 1979 V1.05R printout) -- a .PABS/.PHEX/.XLINK
# absolute build using .LOC tables and `.END BASE'; it assembles cleanly under
# BOTH original assemblers and is byte-exact in OBJECT and LISTING vs both.  Its
# verbatim source even carries a stray ^A (0x01) byte mid-word in one comment (a
# transcription artifact), which the originals drop from the listing -- the
# clone now does the same (a listing-only behavior; the object is unaffected).
# turbobs is the Plu*Perfect Systems Universal High-BIOS for the Advent Turbo
# ROM (Kaypro, (c) 1985), a .PABS/.PHEX/.XLINK absolute build (syssiz=64 in
# turbobs.ans) that drove three engine changes and is byte-identical in OBJECT
# to BOTH originals: (1) the recursive PADBYT memory-fill macro nests one
# conditional per byte, which overflowed the old 64-deep conditional stack, so
# the MAXCOND/MACRO_NEST_MAX caps were raised to 1024; (2) TDL parenthesized
# index addressing `mov a,(disp)(X)' is now parsed (the disp may be a `(' expr,
# not only the bare `(X)'); and (3) a `\' segment-base byte in an absolute
# (.PABS) `:' record is now per-span, so an `O'-error placeholder emitted while
# the LC is still relocatable .PROG. (the unknown `.SETWID' directive sits ahead
# of the first .LOC) carries base 1, as the originals write it.  (Its full
# LISTING differs in only one place -- the .SALL-collapsed XENTRY call lines
# show the equate value's low nibble in the originals -- so turbobs is guarded
# for OBJECT here / vrel, not in tests/test_listing.sh.)  regnum exercises the
# TDL/PSA register-as-number and index-addressing quirks Mark Ogden documented:
# a register operand may be written as a number (MOV 1,2 == MOV C,D, because the
# register letters B..A are predefined 0..7 values and the register field is an
# expression), the d(H) index "bug" (0(H) was meant to be M but emits the three
# bytes 00 34 00 -- a 0 prefix + displacement), a register/expression used as
# the index displacement (INR B(X) == INR 0(X)), the bare (X) parsed as the
# expression X (INR (X) == INR H == 24), and the flagged-but-byte-exact recovery
# cases (a bad index register -> `X'+`Q', a register value > 7 -> `Q').

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
export CPE1704TKS=1
# shellcheck disable=SC1091
. "${here}/.common.sh"
export FIND_COMMAND_FATAL=1
find_command cmp dirname rm

asm="${here}/asm"
gold="${here}/tests/golden"

fail=0
tmp="${here}/obj_test.tmp"

for c in ${cases}; do
  for flag_ext in "-R:rel" "-X:hex"; do
    flag=${flag_ext%:*}
    ext=${flag_ext#*:}
    # A fixture may deliberately assemble with diagnostics (e.g. i8080's "Z"
    # warnings), so the assembler can exit non-zero; we compare the object
    # bytes regardless, so do not let `set -e' abort on that exit status.
    rans=""
    if [ -f "${here}/tests/${c}.ans" ]; then
      rans="-r ${here}/tests/${c}.ans" # answer the '\' console prompts
    fi
    # word-split rans intentionally (flag + path)
    # shellcheck disable=SC2086
    "${asm}" -p ${rans} "${flag}" "${tmp}" "${here}/tests/${c}.asm" \
      > /dev/null 2>&1 || :

    if [ ! -f "${gold}/${c}.${ext}" ]; then
      printf '%s\n' "FAILURE: missing golden tests/golden/${c}.${ext}"
      fail=1
    elif ! cmp -s "${tmp}" "${gold}/${c}.${ext}"; then
      printf '%s\n' "FAILURE: ${flag} object for ${c} differs from golden"
      fail=1
    fi

    rm -f "${tmp}"
  done
done

# PASM 2.00G fixtures: ASCII (.hex) object only (see pasm2_cases above).
for c in ${pasm2_cases}; do
  "${asm}" --pasm2 -X "${tmp}" "${here}/tests/${c}.asm" > /dev/null 2>&1 || :

  if [ ! -f "${gold}/${c}.hex" ]; then
    printf '%s\n' "FAILURE: missing golden tests/golden/${c}.hex"
    fail=1
  elif ! cmp -s "${tmp}" "${gold}/${c}.hex"; then
    printf '%s\n' "FAILURE: --pasm2 object for ${c} differs from golden"
    fail=1
  fi

  rm -f "${tmp}"
done

if [ "${fail}" -ne 0 ]; then
  printf '\n%s\n\n' "FAILURE: object-output regression detected."
  exit 1
fi

printf '\n%s\n\n' "SUCCESS: object-output regression tests passed."
exit 0

################################################################################

# Local Variables:
# mode: shell
# indent-tabs-mode: nil
# sh-basic-offset: 2
# tab-width: 2
# fill-column: 80
# eval: (add-hook 'before-save-hook 'untabify nil t)
# eval: (setq-local display-fill-column-indicator-column 80)
# eval: (display-fill-column-indicator-mode 1)
# End:

################################################################################
# vim: set ft=sh ts=2 sw=2 tw=0 ai expandtab cc=80 :
################################################################################
