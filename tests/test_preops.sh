#!/bin/sh
# TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/test_preops.sh
# Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
# SPDX-License-Identifier: MIT-0
# scspell-id: 719a498c-6b0b-11f1-9791-80ee73e9b8e7

################################################################################

set -eu

################################################################################

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

################################################################################

export CPE1704TKS=1
# shellcheck disable=SC1091
. "${here}/.common.sh"
export FIND_COMMAND_FATAL=1
find_command cat dirname grep rm

################################################################################

asm="${here}/asm"

################################################################################

tmp_out="${here}/preop_test.out"
tmp_lst="${here}/preop_test.lst"
tmp_inc="${here}/preop_test_inc.asm"
tmp_src="${here}/preop_test.asm"

################################################################################

cleanup()
{
  rm -f "${tmp_out}" "${tmp_lst}" "${tmp_inc}" "${tmp_src}"
}

################################################################################

trap cleanup EXIT

################################################################################

cat > "${tmp_src}" << EOF
        MVI A, VALUE1
        MVI B, VALUE2
        MVI C, VALUE3
        .END
EOF

################################################################################

cat > "${tmp_inc}" << EOF
VALUE3 = 33H
EOF

################################################################################

run_asm()
{
  "${asm}" "$@" > "${tmp_out}" 2>&1 || :
}

################################################################################

run_asm -a "VALUE1=55H" -a "VALUE2=0AAH" -i "${tmp_inc}" \
  -l "${tmp_lst}" "${tmp_src}"

################################################################################

grep -q "VALUE1 0055" "${tmp_lst}" || {
  printf '%s\n' "FAILURE: VALUE1 not found or wrong value"
  cat "${tmp_out}"
  exit 1
}

################################################################################

grep -q "VALUE2 00AA" "${tmp_lst}" || {
  printf '%s\n' "FAILURE: VALUE2 not found or wrong value"
  cat "${tmp_out}"
  exit 1
}

################################################################################

grep -q "VALUE3 0033" "${tmp_lst}" || {
  printf '%s\n' "FAILURE: VALUE3 not found or wrong value"
  cat "${tmp_out}"
  exit 1
}

################################################################################

if grep -q "VALUE1 0066" "${tmp_lst}" > /dev/null 2>&1; then
  printf '%s\n' \
    "FAILURE: Test passed when it should have failed (Can-fail check failed)"
  exit 1
fi

################################################################################

run_asm -a "ZVAL=10" -a "ZVAL=ZVAL+5" -a "ZVAL=ZVAL*2" \
  -l "${tmp_lst}" "${tmp_src}"

################################################################################

grep -q "ZVAL   001E" "${tmp_lst}" || {
  printf '%s\n' "FAILURE: Order test failed (expected 001E for ZVAL)"
  cat "${tmp_out}"
  exit 1
}

################################################################################

cat > "${tmp_inc}" << EOF
YVAL=YVAL+1
EOF

################################################################################

run_asm -a "YVAL=100" -i "${tmp_inc}" -a "YVAL=YVAL*2" \
  -l "${tmp_lst}" "${tmp_src}"

################################################################################

grep -q "YVAL   00CA" "${tmp_lst}" || {
  printf '%s\n' "FAILURE: Mixed order test failed (expected 00CA for YVAL)"
  cat "${tmp_out}"
  exit 1
}

################################################################################

cat > "${tmp_src}" << EOF
        MVI A, PREVAL
        .PRGEND
        MVI B, PREVAL
        .END
EOF

################################################################################

if ! "${asm}" -a "PREVAL=42H" -l "${tmp_lst}" "${tmp_src}" \
  > "${tmp_out}" 2>&1; then
  printf '%s\n' "FAILURE: Multi-module assembly failed"
  cat "${tmp_out}"
  exit 1
fi

################################################################################

grep -q "3E42                 MVI A, PREVAL" "${tmp_lst}" || {
  printf '%s\n' "FAILURE: Multi-module test failed (module 1)"
  exit 1
}

################################################################################

grep -q "0642                 MVI B, PREVAL" "${tmp_lst}" || {
  printf '%s\n' "FAILURE: Multi-module test failed (module 2)"
  exit 1
}

################################################################################

if "${asm}" -i non_existent_file.asm "${tmp_src}" > /dev/null 2>&1; then
  printf '%s\n' "FAILURE: Assembler should have failed on missing include file"
  exit 1
fi

################################################################################

if "${asm}" -a "INVALID !!! SYNTAX" "${tmp_src}" > /dev/null 2>&1; then
  printf '%s\n' "FAILURE: Assembler should have failed on invalid prefix syntax"
  exit 1
fi

################################################################################

cat > "${tmp_src}" << EOF
        MVI A, VALUE1
        .END
EOF

################################################################################

if ! "${asm}" --prefix "VALUE1=1" --include "${tmp_inc}" -l "${tmp_lst}" \
  "${tmp_src}" > "${tmp_out}" 2>&1; then
  printf '%s\n' "FAILURE: Long option assembly failed"
  cat "${tmp_out}"
  exit 1
fi

################################################################################

grep -q "VALUE1 0001" "${tmp_lst}" || {
  printf '%s\n' "FAILURE: Long option test failed"
  exit 1
}

################################################################################

cleanup

################################################################################

printf '%s\n\n' "SUCCESS: pre-operation (--include/--prefix) tests passed."

################################################################################

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
