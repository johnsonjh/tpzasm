#!/bin/sh
# TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/test_page.sh
# Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
# SPDX-License-Identifier: MIT-0
# scspell-id: 9d0fcecb-4481-46bb-8031-2dd2421e0fc2

################################################################################

# .PAGE pagination regression test (clone-only; no CP/M oracle needed).
#
# The macro/listing differential (tests/test_listing.sh) normalizes the page
# geometry away -- it strips form-feeds, page headers and blank padding -- so
# the .PAGE *lines-per-page* behavior is invisible there.  This test exercises
# it directly on the clone's raw -l listing: it counts the physical lines
# between consecutive form-feeds and asserts the page interval.
#
# The model (both dialects): the form-feed fires after LST_PAGE = 63 content
# lines -- a 66-line printer page less a 3-line bottom margin.  PASM `.PAGE
# width,length' sets the page to `length' total lines, so the interval becomes
# `length' - 3.  A one-operand PASM `.PAGE width' carries no length and leaves
# the interval at 63.  ZASM `.PAGE' takes no operand (an operand is a `Q' error
# and the geometry is ignored), so its interval stays 63.  A bare `.PAGE'
# forces an eject in either dialect.

set -u

export CPE1704TKS=1
here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck disable=SC1091
. "${here}/.common.sh"

export FIND_COMMAND_FATAL=1
find_command awk mkdir rm

asm="${here}/asm"

# shellcheck disable=SC2119
work=$(mktemp -d 2> /dev/null || mktemp_local)
[ -d "${work}" ] || {
  rm -f "${work}"
  mkdir -p "${work}"
}

fail=0

# Emit a .PABS program to ${work}/p.asm: an optional directive block (arg 1,
# carrying its own embedded newlines) followed by `count' (arg 2) NOPs, enough
# to force several auto-ejects.
gen()
{
  pre="${1}"
  count="${2}"
  {
    printf '\t.PABS\n\t.LOC\t100H\n'
    if [ -n "${pre}" ]; then
      printf '%s\n' "${pre}"
    fi
    i=0
    while [ "${i}" -lt "${count}" ]; do
      printf '\tNOP\n'
      i=$((i + 1))
    done
    printf '\t.END\n'
  } > "${work}/p.asm"
}

# Print the steady-state form-feed interval (physical lines between the first
# and second form-feed) of the clone's listing for the given dialect flag.
interval()
{
  flag="${1}"
  "${asm}" "${flag}" -l "${work}/p.prn" "${work}/p.asm" > /dev/null 2>&1 || true
  awk 'BEGIN { p = 0; seen = 0 }
    /\f/ {
      if (1 == seen) { print NR - p; exit }
      p = NR
      seen = 1
    }' "${work}/p.prn"
}

# Print the number of form-feeds in the clone's listing for the dialect flag.
ffcount()
{
  flag="${1}"
  "${asm}" "${flag}" -l "${work}/p.prn" "${work}/p.asm" > /dev/null 2>&1 || true
  awk 'BEGIN { c = 0 } /\f/ { c = c + 1 } END { print c }' "${work}/p.prn"
}

# Assert that `actual' (arg 3) equals `want' (arg 2), labelled by `desc'.
expect()
{
  desc="${1}"
  want="${2}"
  actual="${3}"
  if [ "${want}" = "${actual}" ]; then
    printf '  %-44s : OK (%s)\n' "${desc}" "${actual}"
  else
    printf '  %-44s : FAIL (want %s, got %s)\n' "${desc}" "${want}" "${actual}"
    fail=1
  fi
}

# 1. PASM default page: 63 lines (66 less the 3-line bottom margin).
gen "" 200
got=$(interval -p)
expect "PASM default interval" 63 "${got}"

# 2. PASM `.PAGE width,length': interval becomes length - 3.
gen "$(printf '\t.PAGE\t79,30')" 120
got=$(interval -p)
expect "PASM .PAGE 79,30 interval" 27 "${got}"

gen "$(printf '\t.PAGE\t79,40')" 120
got=$(interval -p)
expect "PASM .PAGE 79,40 interval" 37 "${got}"

# 3. PASM `.PAGE width' (one operand): width only, length kept at 63.
gen "$(printf '\t.PAGE\t40')" 200
got=$(interval -p)
expect "PASM .PAGE 40 interval (length kept)" 63 "${got}"

# 4. ZASM ignores the geometry (an operand is a `Q' error): interval stays 63.
gen "$(printf '\t.PAGE\t79,30')" 200
got=$(interval -z)
expect "ZASM .PAGE 79,30 interval (ignored)" 63 "${got}"

# 5. A minimal program still emits one trailing form-feed (the listing's final
# page eject); a bare `.PAGE' in the body forces exactly one more, in either
# dialect.  Assert both the baseline and the +1.
gen "" 1
got=$(ffcount -p)
expect "PASM minimal program: 1 trailing eject" 1 "${got}"

gen "$(printf '\tNOP\n\t.PAGE')" 1
got=$(ffcount -p)
expect "PASM bare .PAGE forces an extra eject" 2 "${got}"
got=$(ffcount -z)
expect "ZASM bare .PAGE forces an extra eject" 2 "${got}"

rm -rf "${work}"

if [ "${fail}" -ne 0 ]; then
  printf '\n%s\n\n' "FAILURE: .PAGE pagination regression detected."
  exit 1
fi

printf '\n%s\n\n' "SUCCESS: .PAGE pagination regression tests passed."
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
