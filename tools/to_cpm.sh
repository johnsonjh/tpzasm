#!/bin/sh
# TPZASM: TDL ZASM / PSA PASM compatible assembler - to_cpm.sh
# to_cpm.sh - convert UNIX (LF) text to CP/M text:
# CRLF line endings + a trailing
# ^Z (0x1A) end-of-file marker, written to stdout.  The TDL/PSA assemblers (and
# most CP/M software) require this; a plain LF file yields
# "UNEXPECTED END OF INPUT FILE".
#
#   tools/to_cpm.sh < unix.asm > CPM.ASM
#   tools/to_cpm.sh unix.asm   > CPM.ASM

export CPE1704TKS=1
asmcommon=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
if [ ! -f "${asmcommon}/.common.sh" ]; then
  printf '%s\n' "ERROR: cannot locate .common.sh" >&2
  exit 1
fi
# shellcheck disable=SC1091
. "${asmcommon}/.common.sh"
export FIND_COMMAND_FATAL=1
find_command sed || exit 1
sed 's/$/\r/' -- "$@"
printf '\032'
