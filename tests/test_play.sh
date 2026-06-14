#!/bin/sh
# TPZASM: TDL ZASM / PSA PASM compatible assembler - tests/test_play.sh
# Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
# SPDX-License-Identifier: MIT-0
# scspell-id: e22a118c-661f-11f1-a189-246e96298730

################################################################################

# SARGON playability regression test (requires tnylpo; skips if absent).
#
# Assembles tests/sargon.asm with the clone into an absolute CP/M .COM image,
# runs it under tnylpo, and drives a fixed game as White at search depth 3.
# The console transcript is normalized (the ANSI screen-clear sequences and the
# bare CR bytes that line-mode tnylpo echoes are removed) and diffed against the
# committed golden in tests/golden/sargon.play.
#
# The game is fully deterministic: with the human playing White the engine
# never reaches its only randomness source (the LDAR opening-book coin-flip,
# which fires solely for the computer's first move as White), so the move list
# is byte-stable.  After the six scripted moves a Ctrl-R (0x12) aborts to the
# "CARE FOR ANOTHER GAME?" prompt; "N" there declines, and "N" at the following
# "ANALYZE A POSITION?" prompt exits cleanly back to CP/M (no input is left to
# hang on at end-of-file).  Any regression in the source or the assembler that
# breaks move parsing, board indexing, or the engine shows up as a transcript
# diff.

set -eu

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
export CPE1704TKS=1
# shellcheck disable=SC1091
. "${here}/.common.sh"

# tnylpo gate: skip (do not fail) when the CP/M emulator is unavailable.
if ! command -v tnylpo > /dev/null 2>&1; then
  printf '\n%s\n\n' "SKIP: tnylpo not found; skipping SARGON playability test."
  exit 0
fi

export FIND_COMMAND_FATAL=1
find_command cmp diff dirname mkdir rm sed timeout tnylpo tr

asm="${here}/asm"
src="${here}/tests/sargon.asm"
gold="${here}/tests/golden/sargon.play"

if [ ! -x "${asm}" ]; then
  printf '%s\n' "FAILURE: ${asm} not built (run 'make' first)."
  exit 1
fi
if [ ! -f "${gold}" ]; then
  printf '%s\n' "FAILURE: missing golden ${gold}."
  exit 1
fi

# shellcheck disable=SC2119
work=$(mktemp -d 2> /dev/null || mktemp_local)
[ -d "${work}" ] || {
  rm -f "${work}"
  mkdir -p "${work}"
}
trap 'rm -rf "${work}"' EXIT

# Assemble the fixture to an absolute .COM (CP/M loads it at 0100H).
"${asm}" -p -o "${work}/sargon.com" "${src}" > /dev/null 2>&1

# Scripted input: Y(play) w(white) 3(depth); six legal White moves; then
# Ctrl-R (\022) / N / N to exit cleanly.  See the header note for the rationale.
printf 'Yw3\ne2-e4\ng1-f3\nf1-c4\nb1-c3\nd2-d4\nd1-e2\n\022NN\n' \
  > "${work}/in.txt"

# 60s is generous: the reference run is ~9s of emulated depth-3 search.
(cd "${work}" && timeout -k 5 60 tnylpo -b sargon.com < in.txt > out.raw 2>&1) \
  || :

# Normalize away terminal control noise (ANSI CSI sequences + bare CRs).
esc=$(printf '\033')
sed "s/${esc}\\[[0-9;]*[A-Za-z]//g" "${work}/out.raw" | tr -d '\r' \
  > "${work}/out.txt"

if cmp -s "${work}/out.txt" "${gold}"; then
  printf '\n%s\n\n' "SUCCESS: SARGON playability transcript matches golden."
  exit 0
fi

printf '%s\n' "FAILURE: SARGON playability transcript differs from golden:"
diff "${gold}" "${work}/out.txt" || :
exit 1

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
