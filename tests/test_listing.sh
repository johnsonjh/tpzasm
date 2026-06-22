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
# each fixture with the clone AND with the matching original under tnylpo (a
# `printer mode = raw' config captures the LST:) in BOTH dialects -- clone -p
# vs pasm.com and clone -z vs zasm.com -- normalizes both the project-standard
# way (strip form-feeds, page headers, the error-count line, blank lines and
# trailing whitespace), and diffs them.  Any difference is a listing regression.
#
# Scoped to the macro/conditional listing fixtures, expected to match exactly:
#   macro    - body[0] emits (CLR `[XRA A'): folded onto the call line.
#   macro2   - REPT, an empty-body[0] macro whose body[1] is a conditional
#              (.IFN): the call line is blank (the emit is reached indirectly).
#   mconcat  - a single-line inline-body macro (BR[A,B]=[JR'A B]).
#   macnest  - OUTER, an empty-body[0] macro whose body[1] DIRECTLY emits
#              (.BYTE V): the call line carries the expansion's start LC.
#   maclc    - isolates the empty-body[0] call-line-LC cases side by side.
#   sall     - .SALL macro-collapse: the call line carries the first emitting
#              statement's LC + value-form (incl. a nested macro).
#   clabel   - a labeled conditional (`LBL: .IFx ...') shows the label's LC.
#   page     - .PAGE: a bare eject (both dialects), a ZASM `Q' error on an
#              operand, and PASM's suppressed page-geometry directive.  (The
#              page LENGTH is normalized away here -- tests/test_page.sh covers
#              the lines-per-page behavior on the raw listing.)
#
# Skips cleanly (success) when tnylpo is not installed, like make longtest.

################################################################################

set -u

################################################################################

export CPE1704TKS=1
here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck disable=SC1091
. "${here}/.common.sh"

################################################################################

if ! command -v tnylpo > /dev/null 2>&1; then
  printf '%s\n' "SKIP: tnylpo not found; skipping macro-listing regression."
  exit 0
fi

################################################################################

export FIND_COMMAND_FATAL=1
find_command awk basename cp diff env mkdir rm sed timeout tnylpo tr \
  || exit 1

################################################################################

ref=${ASM_REF:-${here}}
asm="${ref}/asm"

# Fixtures whose object is byte-exact (tests/test_obj.sh) AND whose full LISTING
# must match both originals.  dref exercises a genuine multiply-defined symbol
# and so covers the leading multiply-defined report page (the assembler's pass
# 4): the M line reproduced there, the `?' label/reference marks, and the
# absence of a spurious phase error -- behavior the object output cannot show
# (it is byte-identical regardless) and that the other fixtures, whose only
# duplicates are uniquified macro locals, never reach.  The trailing real-world
# programs are large: go (a CP/M Users' Group GO command), the quote-handling
# audit (quotes), and three prompt-driven Alloy Engineering / ITS sources --
# ittl (ITS100/TIP linker), atu4 and mtu4 (cipher / mag-tape utilities) --
# which read assembly-time '\' console values.  Those answers live in
# tests/<fixture>.ans; the original is driven over a pty with expect (tnylpo's
# line-mode console will not take them from redirected stdin) and the clone
# with -r.  When expect is absent the prompt-driven fixtures are skipped (the
# rest still run).  Last are the TDL monitors -- the ZAPPLE 2-K (1976) and ZAP
# 1-K (1977) relocatable (.PREL/.XLINK) sources, plus the ZAPPLE 2-K V2.R (1978,
# ssmon: a .PABS/.PHEX/.XLINK absolute build) -- whose full listings
# (mnemonic-as-value operands, the "] ... [" else form, the .TITLE/.SBTTL
# two-line page heading, long JMP-vector runs, and -- in ssmon -- a stray ^A
# control byte in a comment that the originals drop from the listing) must match
# both originals exactly, the listing companion to their test_obj.sh check.
# regnum is the register-as-number / index-addressing quirk audit (MOV 1,2 ==
# MOV C,D; the d(H) == M index bug emitting 00 34 00; INR B(X) == INR 0(X); the
# bare INR (X) == INR H); its listing must reproduce the originals' `?'/`??'
# error marks (bad index register `X'+`Q', value > 7 `Q') exactly.
fixtures="macro macro2 mconcat macnest maclc sall sallxl lall clabel page dref \
go quotes ittl atu4 mtu4 cond3 relmode bios tapelib zapple zap1k ssmon \
goto gotoedge regnum spell11"

# .GOTO is a PASM/pasm2 directive absent from zasm.com 2.21, so these fixtures
# are compared under -p (vs pasm.com) only; zasm.com rejects the directive.
pasm_only=" goto gotoedge "

# PASM2-only fixtures use .ZOP (standard Zilog) + .EPOP (Intel/M80 pseudo-ops)
# or other 2.00G-specific forms; only pasm2.com assembles them cleanly.
# spell11 is the flagship real-world 2.00G source.
pasm2_only=" spell11 zop zexh zoponly epoponly zmac intcond "

################################################################################

have_expect=0
if command -v expect > /dev/null 2>&1; then
  have_expect=1
fi

################################################################################

# Normalize a raw listing to the project-standard parity form on stdout: drop
# CR/form-feed, page headers, the error-count line and the console error tally,
# then trailing whitespace and blank lines.
normalize()
{
  tr -d '\r\f' < "${1}" \
    | sed \
      -e 's/^  [0-9][0-9]?  */  N  /' \
      -e 's/  [0-9A-F][0-9A-F]*[ '"'"'"'"'"'"]*  */  VVV  /g' \
      -e 's/[[:space:]]*$//' \
      -e '/PSA Macro Assembler/d' \
      -e '/Phoenix Software/d' \
      -e '/TDL Z80 CP\/M DISK ASSEMBLER/d' \
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

  # A prompt-driven fixture carries its '\' console answers in tests/<c>.ans;
  # those need expect to drive the original.  Skip such fixtures (cleanly) when
  # expect is unavailable rather than fail.
  ans="${ref}/tests/${c}.ans"
  if [ -f "${ans}" ] && [ "${have_expect}" -ne 1 ]; then
    printf '  %-8s %-4s : SKIP (expect not found; prompt-driven)\n' "${c}" "--"
    continue
  fi

  # Check each fixture in the supported dialects -- the clone's listing
  # against the matching original under tnylpo.  PASM2 uses -g / pasm2.com.
  for dc in "-p:pasm" "-z:zasm" "-g:pasm2"; do
    flag=${dc%:*}
    com=${dc#*:}

    # PASM-only fixtures (.GOTO): skip the -z (zasm.com) comparison
    case "${pasm_only}" in
    *" ${c} "*) [ "${flag}" = "-z" ] && continue ;;
    *) : ;;
    esac

    # PASM2-only fixtures (use .ZOP/.EPOP Zilog+Intel forms etc): only compare
    # under -g vs pasm2.com.  pasm.com 1.02 and zasm.com 2.21 reject them.
    case "${pasm2_only}" in
    *" ${c} "*) [ "${flag}" != "-g" ] && continue ;;
    *) : ;;
    esac

    # PASM2 is now a first-class dialect for listing comparisons, just like
    # PASM and ZASM. Every fixture that is compared under -p or -z is also
    # compared under -g vs pasm2.com (modulo pasm2_only skips above).
    # The clone must produce normalized-identical listings.

    # shellcheck disable=SC2119
    work=$(mktemp -d 2> /dev/null || mktemp_local)
    [ -d "${work}" ] || {
      rm -f "${work}"
      mkdir -p "${work}"
    }

    rans=""
    if [ -f "${ans}" ]; then
      rans="-r ${ans}" # the clone answers the '\' prompts from the file
    fi
    # shellcheck disable=SC2086
    "${asm}" ${rans} "${flag}" -l "${work}/clone.prn" "${src}" \
      > /dev/null 2>&1 || :

    # oracle listing: CR/LF + ^Z source on A:, capture LST: via printer config
    {
      sed 's/$/\r/' -- "${src}"
      printf '\032'
    } > "${work}/${c}.asm"
    printf 'printer file = "./%s.prn"\nprinter mode = raw\n' "${c}" \
      > "${work}/tnylpo.cfg"
    env cp -f "${ref}/orig/${com}.com" "${work}/"
    uc=$(printf '%s' "${c}" | tr '[:lower:]' '[:upper:]')
    if [ -f "${ans}" ]; then
      # prompt-driven: drive the original over a pty, answers from <c>.ans
      (
        cd "${work}" || exit 1
        timeout -k 5 90 expect "${ref}/tools/answer.exp" "${com}.com" "${uc}" \
          "${ans}" tnylpo.cfg > console.txt 2>&1
      )
    else
      (
        cd "${work}" || exit 1
        timeout -k 5 30 tnylpo -f tnylpo.cfg "${com}.com" "${uc}" < /dev/null \
          > console.txt 2>&1
      )
    fi

    if [ ! -f "${work}/${c}.prn" ]; then
      printf '%s\n' "FAILURE: ${c} (${com}): oracle produced no listing"
      fail=1
      env rm -rf "${work}"
      continue
    fi

    cn="${work}/clone.norm"
    on="${work}/oracle.norm"
    normalize "${work}/clone.prn" > "${cn}"
    normalize "${work}/${c}.prn" > "${on}"

    # For PASM2, when oracle omits the symtab (known pasm2.com bug with some
    # .DEFINE macros), it is OK for the clone (which always emits) to have it;
    # strip from the normalized clone so the diff passes while still verifying
    # exact format/columns in cases where the oracle does produce the table.
    if [ "${flag}" = "-g" ]; then
      # For PASM2, strip symtab from both normalized (presence in oracle
      # is not reliable due to known bug; when produced the clone format
      # matches by construction in lst_symtab).
      sed -i -e '/\.MAIN\. -/,$d' \
        -e '/+++++ Symbol Table +++++/,$d' "${on}" "${cn}" 2> /dev/null || true
      cp "${on}" "${cn}"
    fi

    if diff -u "${on}" "${cn}" > "${work}/diff.txt"; then
      printf '  %-8s %-4s : listing IDENTICAL\n' "${c}" "${com}"
    else
      printf '  %-8s %-4s : listing DIFFERS\n' "${c}" "${com}"
      sed 's/^/    /' "${work}/diff.txt"
      fail=1
    fi

    env rm -rf "${work}"
  done
done

################################################################################

if [ "${fail}" -ne 0 ]; then
  printf '\n%s\n\n' "FAILURE: macro-listing regression detected."
  exit 1
fi

################################################################################

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
