#!/bin/sh
# TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/test_maclist.sh
# Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
# SPDX-License-Identifier: MIT-0
# scspell-id: c8beeb2a-6906-11f1-a656-246e96298730

################################################################################

# Macro-expansion listing regression test (no CP/M oracle required).
#
# The macro-listing MODEL -- how a macro call is folded onto / expanded across
# listing lines (the call line carrying body[0]'s LC + bytes + the inline `['
# body, the `+' continuation lines for the rest, the `.SALL' collapse, the
# empty-body[0] call-line-LC rule) -- is delicate and shared by every macro.
# tests/test_listing.sh guards it DIFFERENTIALLY against the originals, but only
# when tnylpo is installed.  This test guards the SAME model with committed
# golden listings: it re-lists each macro fixture with the clone (-p AND -z),
# normalizes (drop the page headers, form-feeds, the error tally, blank lines
# and trailing whitespace -- the project-standard listing-compare form), and
# diffs the result against tests/golden/<fixture>.{plst,zlst}.
#
# The goldens were captured from the clone AFTER tests/test_listing.sh proved
# its macro listing byte-for-byte identical to BOTH originals in BOTH dialects,
# so any difference here is a regression in the macro-expansion listing model.
# Unlike test_listing.sh this needs no oracle, so it runs in the default `test'
# target and gives a fast, deterministic safety net for changes to that model.

set -eu

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
export CPE1704TKS=1
# shellcheck disable=SC1091
. "${here}/.common.sh"
export FIND_COMMAND_FATAL=1
find_command diff rm sed tr

asm="${here}/asm"
gold="${here}/tests/golden"

# The macro-listing-model fixtures (each is also guarded vs the originals in
# tests/test_listing.sh):
#   macro    - body[0] emits (CLR `[XRA A'): folded onto the call line, the
#              rest a `+' continuation.
#   macro2   - REPT; an empty-body[0] macro whose body[1] is a conditional.
#   mconcat  - a single-line inline-body macro (BR[A,B]=[JR'A B]).
#   macnest  - OUTER, an empty-body[0] macro whose body[1] DIRECTLY emits.
#   maclc    - the empty-body[0] call-line-LC cases side by side.
#   sall     - .SALL macro-collapse: the call line carries the first emitting
#              statement's LC + value-form (incl. a nested macro).
#   salldref - .SALL with an errored (multiply-defined operand) body statement,
#              which is still listed as a '+' expansion (the originals never
#              hide a diagnostic), with the body-close ']' and the `?' past it.
#   macins   - a macro called from an .INSERT'd file: its expansion lines carry
#              the '+' macro marker, not the '@' inserted-file marker.
fixtures="macro macro2 mconcat macnest maclc sall salldref macins"

# Normalize a raw listing to the project-standard compare form on stdout: drop
# CR/form-feed, the per-page header (banner + `.MAIN. -' title line) and the
# error-count line, then trailing whitespace and blank lines.
normalize()
{
  tr -d '\r\f' < "${1}" \
    | sed -e 's/[[:space:]]*$//' \
      -e '/Macro Assembler \[/d' \
      -e '/CP\/M DISK ASSEMBLER/d' \
      -e '/Phoenix Software/d' \
      -e '/^Copyright (c) 20/d' \
      -e '/^\.MAIN\. -/d' \
      -e '/[Ee][Rr][Rr][Oo][Rr][Ss]* [Ww][Ee][Rr][Ee] [Dd]etected/d' \
      -e '/^[0-9][0-9]* [Ee]rror/d' \
      -e '/^[[:space:]]*$/d'
}

fail=0
tmp="${here}/maclist.tmp"

for c in ${fixtures}; do
  for flag_ext in "-p:plst" "-z:zlst"; do
    flag=${flag_ext%:*}
    ext=${flag_ext#*:}

    "${asm}" "${flag}" -l "${tmp}" "${here}/tests/${c}.asm" \
      > /dev/null 2>&1 || :

    normalize "${tmp}" > "${tmp}.n"

    if [ ! -f "${gold}/${c}.${ext}" ]; then
      printf '%s\n' "FAILURE: missing golden tests/golden/${c}.${ext}"
      fail=1
    elif ! diff -u "${gold}/${c}.${ext}" "${tmp}.n" > "${tmp}.d"; then
      printf '%s\n' "FAILURE: ${flag} listing for ${c} differs from golden"
      sed 's/^/  /' "${tmp}.d"
      fail=1
    fi

    rm -f "${tmp}.n"

    rm -f "${tmp}" "${tmp}.d"
  done
done

if [ "${fail}" -ne 0 ]; then
  printf '\n%s\n\n' "FAILURE: macro-listing golden regression detected."
  exit 1
fi

printf '\n%s\n\n' "SUCCESS: macro-listing golden regression tests passed."
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
