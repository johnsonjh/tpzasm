#!/bin/sh
# TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/test_datetime.sh
# Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
# SPDX-License-Identifier: MIT-0
# scspell-id: 15861268-669f-11f1-b112-246e96298730

################################################################################

# .DATE / .TIME regression (no CP/M oracle required).
#
# .DATE emits the eight ASCII bytes "MM/DD/YY" and .TIME emits "HH:MM:SS" at
# the current location.  For reproducible builds the assembler honors
# SOURCE_DATE_EPOCH (a UTC Unix timestamp); otherwise it uses the local clock.
# This test pins SOURCE_DATE_EPOCH to a known instant and checks that the bytes
# in the ASCII (-X) object record are exactly the expected date/time strings,
# then checks that the local-clock fallback still emits two well-formed 8-byte
# fields.

set -eu

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
export CPE1704TKS=1
# shellcheck disable=SC1091
. "${here}/.common.sh"
export FIND_COMMAND_FATAL=1
find_command awk dirname rm sed tr

asm="${here}/asm"
src="${here}/tests/datetime.asm"
tmp="${here}/dt_test.tmp"

fail=0

# Pull the 16 data bytes (.DATE + .TIME) out of the ASCII-hex `:' data record
# at load address 0100 and decode them back to ASCII.
extract()
{
  sed 's/\r//g' "$1" | tr -d '\n' \
    | sed 's/.*:10010000\(................................\).*/\1/' \
    | awk '{
        s = "";
        for (i = 1; i <= length ($0); i += 2)
          {
            h = substr ($0, i, 2); n = 0;
            for (k = 1; k <= 2; k++)
              n = n * 16 + (index ("0123456789ABCDEF", \
                                   toupper (substr (h, k, 1))) - 1);
            s = s sprintf ("%c", n);
          }
        printf "%s", s;
      }'
}

# --- 1. fixed SOURCE_DATE_EPOCH (UTC) gives deterministic bytes -------------
# 1700000000 == 2023-11-14 22:13:20 UTC
SOURCE_DATE_EPOCH=1700000000 "${asm}" -p -X "${tmp}" "${src}" > /dev/null 2>&1
got=$(extract "${tmp}")
want="11/14/2322:13:20"

if [ "${got}" != "${want}" ]; then
  printf '%s\n' "FAILURE: epoch 1700000000 = '${got}' (want '${want}')"
  fail=1
fi

# --- 2. a second instant, to be sure it is not hard-coded -------------------
# 0 == 1970-01-01 00:00:00 UTC
SOURCE_DATE_EPOCH=0 "${asm}" -p -X "${tmp}" "${src}" > /dev/null 2>&1
got=$(extract "${tmp}")
want="01/01/7000:00:00"

if [ "${got}" != "${want}" ]; then
  printf '%s\n' "FAILURE: .DATE/.TIME for epoch 0 = '${got}' (want '${want}')"
  fail=1
fi

# --- 3. local-clock fallback (no SOURCE_DATE_EPOCH): well-formed fields ------
unset SOURCE_DATE_EPOCH || :
"${asm}" -p -X "${tmp}" "${src}" > /dev/null 2>&1
got=$(extract "${tmp}")

# Expect MM/DD/YYHH:MM:SS : digits with '/' at 3,6 and ':' at 11,14 (0-based).
case "${got}" in
[0-9][0-9]/[0-9][0-9]/[0-9][0-9][0-9][0-9]:[0-9][0-9]:[0-9][0-9]) ;;
*)
  printf '%s\n' "FAILURE: .DATE/.TIME local fallback malformed: '${got}'"
  fail=1
  ;;
esac

rm -f "${tmp}"

if [ "${fail}" -ne 0 ]; then
  printf '\n%s\n\n' "FAILURE: .DATE/.TIME regression detected."
  exit 1
fi

printf '\n%s\n\n' "SUCCESS: .DATE/.TIME tests passed."
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
