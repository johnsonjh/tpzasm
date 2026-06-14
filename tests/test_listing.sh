#!/bin/sh
# TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/test_listing.sh
# Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
# SPDX-License-Identifier: MIT-0
# scspell-id: 51b67b20-679d-11f1-aaf9-246e96298730

################################################################################

# Macro-listing regression test (needs the tnylpo CP/M emulator).
#
# The object output is guarded byte-for-byte by tests/test_obj.sh, but the
# LISTING (the .PRN) has its own delicate model -- in particular the macro
# expansion call-line LC and the '+' continuation lines.  This test assembles
# each macro fixture with the clone (-p, listing to a file) AND with the
# original PSA PASM (pasm.com under tnylpo, listing captured via a `printer
# mode = raw' config), normalizes both the project-standard way (strip the
# form-feeds, page headers, the error-count line, blank lines and trailing
# whitespace), and diffs them.  Any difference is a macro-listing regression.
#
# Scoped to the macro fixtures, whose listings are expected to match exactly:
#   macro    - body[0] emits (CLR `[XRA A'): folded onto the call line.
#   macro2   - REPT, an empty-body[0] macro whose body[1] is a conditional
#              (.IFN): the call line is blank (the emit is reached indirectly).
#   mconcat  - a single-line inline-body macro (BR[A,B]=[JR'A B]).
#   macnest  - OUTER, an empty-body[0] macro whose body[1] DIRECTLY emits
#              (.BYTE V): the call line carries the expansion's start LC.
#   maclc    - isolates the empty-body[0] call-line-LC cases side by side.
#
# Skips cleanly (success) when tnylpo is not installed, like make longtest.

set -u

export CPE1704TKS=1
here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck disable=SC1091
. "${here}/.common.sh"

if ! command -v tnylpo > /dev/null 2>&1; then
  printf '%s\n' "SKIP: tnylpo not found; skipping macro-listing regression."
  exit 0
fi

export FIND_COMMAND_FATAL=1
find_command awk basename cp diff env mkdir rm sed timeout tnylpo tr \
  || exit 1

ref=${ASM_REF:-${here}}
asm="${ref}/asm"

fixtures="macro macro2 mconcat macnest maclc sall"

# Normalize a raw listing to the project-standard parity form on stdout: drop
# CR/form-feed, page headers, the error-count line and the console error tally,
# then trailing whitespace and blank lines.
normalize()
{
  tr -d '\r\f' < "${1}" \
    | sed -e 's/[[:space:]]*$//' \
      -e '/PSA Macro Assembler/d' \
      -e '/Phoenix Software/d' \
      -e '/[Ee][Rr][Rr][Oo][Rr][Ss]* [Ww][Ee][Rr][Ee] [Dd]etected/d' \
      -e '/^[0-9][0-9]* error(s)$/d' \
      -e '/^[[:space:]]*$/d'
}

fail=0
for c in ${fixtures}; do
  src="${ref}/tests/${c}.asm"
  if [ ! -f "${src}" ]; then
    printf '%s\n' "FAILURE: missing fixture tests/${c}.asm"
    fail=1
    continue
  fi

  # shellcheck disable=SC2119
  work=$(mktemp -d 2> /dev/null || mktemp_local)
  [ -d "${work}" ] || {
    rm -f "${work}"
    mkdir -p "${work}"
  }

  # clone listing
  "${asm}" -p -l "${work}/clone.prn" "${src}" > /dev/null 2>&1 || true

  # oracle listing: CR/LF + ^Z source on A:, capture LST: via printer config
  {
    sed 's/$/\r/' -- "${src}"
    printf '\032'
  } > "${work}/${c}.asm"
  printf 'printer file = "./%s.prn"\nprinter mode = raw\n' "${c}" \
    > "${work}/tnylpo.cfg"
  env cp -f "${ref}/orig/pasm.com" "${work}/"
  uc=$(printf '%s' "${c}" | tr '[:lower:]' '[:upper:]')
  (
    cd "${work}" || exit 1
    timeout 30 tnylpo -f tnylpo.cfg pasm.com "${uc}" < /dev/null \
      > console.txt 2>&1
  )

  if [ ! -f "${work}/${c}.prn" ]; then
    printf '%s\n' "FAILURE: ${c}: oracle produced no listing"
    fail=1
    env rm -rf "${work}"
    continue
  fi

  cn="${work}/clone.norm"
  on="${work}/oracle.norm"
  normalize "${work}/clone.prn" > "${cn}"
  normalize "${work}/${c}.prn" > "${on}"

  if diff -u "${on}" "${cn}" > "${work}/diff.txt"; then
    printf '  %-8s : listing IDENTICAL\n' "${c}"
  else
    printf '  %-8s : listing DIFFERS\n' "${c}"
    sed 's/^/    /' "${work}/diff.txt"
    fail=1
  fi

  env rm -rf "${work}"
done

if [ "${fail}" -ne 0 ]; then
  printf '\n%s\n\n' "FAILURE: macro-listing regression detected."
  exit 1
fi

printf '\n%s\n\n' "SUCCESS: macro-listing regression tests passed."
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
