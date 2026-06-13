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
# PSA BUG debugger -- ".." locals excluded (psym).
cases="smoke data insn8080 objword sargon newkw seg blnk ext prgend longname \
oprem limage extmod xlink i8080 intern cond2 mconcat ifbnb macnest dinsert \
insnest psym"

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
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
    "${asm}" -p "${flag}" "${tmp}" "${here}/tests/${c}.asm" > /dev/null 2>&1 \
      || true

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
