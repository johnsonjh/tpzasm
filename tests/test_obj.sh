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
# .RAD40, the .SYN family, .EXIT/.IF1/.IF2, and the truncated spellings (newkw).
cases="smoke data insn8080 objword sargon newkw"

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
asm="${here}/asm"
gold="${here}/tests/golden"

fail=0
tmp="${here}/obj_test.tmp"

for c in ${cases}; do
  for flag_ext in "-R:rel" "-X:hex"; do
    flag=${flag_ext%:*}
    ext=${flag_ext#*:}
    "${asm}" -p "${flag}" "${tmp}" "${here}/tests/${c}.asm" > /dev/null 2>&1

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
