#!/bin/sh
# TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/test_trunc.sh
# Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
# SPDX-License-Identifier: MIT-0
# scspell-id: d1b51ea4-643b-11f1-9353-80ee73e9b8e7

################################################################################

set -eu

################################################################################

# Default: a symbol longer than six characters keeps only its first six in the
# SYMBOL TABLE (LONGENTRY -> LONGEN, LONGINTERN -> LONGIN).
./asm -z tests/longname.asm > out.txt 2>&1
sed -n '/+++++ SYMBOL TABLE +++++/,$p' out.txt > symtab.txt

if grep -q "LONGENTRY" symtab.txt || grep -q "LONGINTERN" symtab.txt; then
  printf '\n%s\n\n' \
    "FAILURE: Default assembly did not truncate symbols in SYMBOL TABLE."
  cat symtab.txt
  rm -f out.txt symtab.txt
  exit 1
fi

if ! grep -q "LONGEN" symtab.txt || ! grep -q "LONGIN" symtab.txt; then
  printf '\n%s\n\n' \
    "FAILURE: Default assembly did not truncate symbols in SYMBOL TABLE."
  cat symtab.txt
  rm -f out.txt symtab.txt
  exit 1
fi

################################################################################

# With -L (non-standard): long symbols are kept in full in the SYMBOL TABLE
./asm -z -L tests/longname.asm > out.txt 2>&1
sed -n '/+++++ SYMBOL TABLE +++++/,$p' out.txt > symtab.txt

if ! grep -q "LONGENTRY" symtab.txt || ! grep -q "LONGINTERN" symtab.txt; then
  printf '\n%s\n\n' \
    "FAILURE: -L assembly did not preserve long symbols in SYMBOL TABLE."
  cat symtab.txt
  rm -f out.txt symtab.txt
  exit 1
fi

################################################################################

printf '\n%s\n' "SUCCESS: Symbol truncation tests passed."
rm -f out.txt symtab.txt
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
