#!/bin/sh
# TPZASM: TDL ZASM / PSA PASM compatible assembler - vpasm2.sh
# vpasm2.sh - assemble SRC.asm with the clone (--pasm2, ASCII REL via -X) AND
# with the original PSA PASM 2.00G (orig/pasm2.com) under tnylpo, then compare
# the object record streams byte-for-byte.  PASM 2.00G is the `.ZOP' standard
# Zilog + `.EPOP' Intel/M80 dialect; only pasm2.com builds such sources.
#
# The differential is on the ASCII (`.PHEX') object -- the form every real
# 2.00G source selects (HEXCOM consumes the ASCII stream).  The binary `.PBIN'
# form is intentionally NOT differenced here: 2.00G packs its binary data
# records into larger chunks than PASM 1.02 (a documented "REL record packing"
# difference -- identical content, different framing), which the clone's 1.02-
# style binary serializer does not reproduce.  The assembled BYTES are identical
# (the ASCII compare proves it); only the binary chunk boundaries differ.
#
# Usage: tools/vpasm2.sh tests/foo.asm
set -u
src=${1:?Usage: vpasm2.sh src.asm}

export CPE1704TKS=1
asmcommon=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck disable=SC1091
. "${asmcommon}/.common.sh"
export FIND_COMMAND_FATAL=1
find_command awk basename cp dirname env mkdir python3 sed timeout tnylpo tr \
  || exit 1

ref=${ASM_REF:-${asmcommon}}
base=$(basename "${src}" | sed 's/\.[Aa][Ss][Mm]$//' \
  | tr '[:upper:]' '[:lower:]')
# shellcheck disable=SC2119
work=$(mktemp -d 2> /dev/null || mktemp_local)
[ -d "${work}" ] || {
  rm -f "${work}"
  mkdir -p "${work}"
}
trap 'env rm -rf "$work"' EXIT

# clone: ASCII REL (-X)
"${ref}/asm" --pasm2 -X "${work}/clone.hex" "${src}" > /dev/null 2>&1

# Stage every sibling .asm (lowercase) so an .INSERT resolves under CP/M.
for f in "$(dirname "${src}")"/*.asm; do
  [ -f "${f}" ] || continue
  b=$(basename "${f}" | tr '[:upper:]' '[:lower:]')
  {
    sed 's/$/\r/' "${f}"
    printf '\032'
  } > "${work}/${b}"
done
env cp -f "${ref}/orig/pasm2.com" "${work}/"

# ASCII oracle: prepend .PHEX (re-assert it after each .PRGEND module boundary)
# so every module emits the ASCII object; retry once on a transient tnylpo hang.
{
  printf '\t.PHEX\r\n'
  awk '{printf "%s\r\n",$0} toupper($0)~/\.PRGEN/{printf "\t.PHEX\r\n"}' \
    "${src}"
  printf '\032'
} \
  > "${work}/${base}.asm"
i=0
while [ "${i}" -lt 2 ]; do
  rm -f "${work}/${base}.hex"
  (cd "${work}" && timeout -k 5 30 tnylpo -b pasm2.com "${base}.asm" \
    > /dev/null 2>&1)
  [ -f "${work}/${base}.hex" ] && break
  i=$((i + 1))
done

python3 - "${work}/clone.hex" "${work}/${base}.hex" << 'PY'
import sys, os
clone, oracle = sys.argv[1], sys.argv[2]
if not os.path.exists(clone) or not os.path.exists(oracle):
    side = "clone" if not os.path.exists(clone) else "oracle"
    print("  -X/asc : MISSING (%s)" % side)
    sys.exit(1)
c = open(clone, 'rb').read()
o = open(oracle, 'rb').read()
head, tail = o[:len(c)], o[len(c):]
if head == c and all(b in (0x00, 0x1a) for b in tail):
    print("  -X/asc : IDENTICAL (%d record bytes)" % len(c))
    sys.exit(0)
print("  -X/asc : DIFFER (clone %d, oracle %d)" % (len(c), len(o)))
for i in range(min(len(c), len(head))):
    if c[i] != head[i]:
        print("           first diff @%d: clone %02X oracle %02X"
              % (i, c[i], head[i]))
        print("           clone : %s" % c[max(0, i - 4):i + 8].hex())
        print("           oracle: %s" % head[max(0, i - 4):i + 8].hex())
        break
sys.exit(1)
PY
