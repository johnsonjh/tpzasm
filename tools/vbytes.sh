#!/bin/sh
# TPZASM: TDL ZASM / PSA PASM compatible assembler - vbytes.sh
# vbytes.sh - assemble SRC.asm with the clone (./zasm) AND the original ZASM
# under tnylpo, extract the emitted byte stream from each listing, and report
# IDENTICAL / DIFFER.  Usage: tools/vbytes.sh tests/foo.asm
set -u
src=${1:?Usage: vbytes.sh src.asm}

export CPE1704TKS=1
asmcommon=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
if [ ! -f "${asmcommon}/.common.sh" ]; then
  printf '%s\n' "ERROR: cannot locate .common.sh" >&2
  exit 1
fi
# shellcheck disable=SC1091
. "${asmcommon}/.common.sh"
export FIND_COMMAND_FATAL=1
find_command basename cp dirname env mkdir python3 rm sed timeout tnylpo \
  tr || exit 1

ref=${ASM_REF:-${asmcommon}}
base=$(basename "${src}" | sed 's/\.[Aa][Ss][Mm]$//' \
  | tr '[:upper:]' '[:lower:]')
# prefer real mktemp -d; fall back to .common.sh's mktemp_local (a file name,
# which we turn into the work directory) only if mktemp is unavailable.
# shellcheck disable=SC2119
work=$(mktemp -d 2> /dev/null || mktemp_local)
[ -d "${work}" ] || {
  rm -f "${work}"
  mkdir -p "${work}"
}
trap 'env rm -rf "$work"' EXIT

"${ref}/zasm" "${src}" > "${work}/mine.txt" 2>&1
# stage every sibling .asm (CP/M-format, lowercase) so .INSERT resolves
for f in "$(dirname "${src}")"/*.asm; do
  [ -f "${f}" ] || continue
  b=$(basename "${f}" | tr '[:upper:]' '[:lower:]')
  {
    sed 's/$/\r/' "${f}"
    printf '\032'
  } > "${work}/${b}"
done
env cp -f "${ref}/orig/zasm.com" "${work}"/
printf 'printer file = "./out.prn"\nprinter mode = text\n' \
  > "${work}/tnylpo.cfg"
(cd "${work}" \
  && timeout -k 5 30 tnylpo -f tnylpo.cfg -b zasm.com "${base}.asm" \
    > /dev/null 2>&1)
[ -f "${work}/out.prn" ] || {
  echo "RESULT: oracle produced no listing"
  exit 1
}

python3 - "${work}/mine.txt" "${work}/out.prn" << 'PY'
import re, sys
def mine(p):
    s = b''
    for line in open(p):
        if re.match(r'^[0-9A-Fa-f]{4}  ', line):
            for t in line[6:23].split():
                if re.fullmatch(r'[0-9A-Fa-f]{2}', t): s += bytes([int(t, 16)])
    return s
def oracle(p):
    s = b''
    for line in open(p):
        m = re.match(
            r"^\s*[0-9A-Fa-f]{4}['*: ]\s+([0-9A-Fa-f][0-9A-Fa-f ]*?)\s{2,}\S",
            line)
        if not m: continue
        for i, t in enumerate(m.group(1).split()):
            if i == 0:
                for j in range(0, len(t)-1, 2): s += bytes([int(t[j:j+2], 16)])
            else:
                w = int(t, 16); s += bytes([w & 0xFF, (w >> 8) & 0xFF])
    return s
# clone now emits the same value-form layout as the original
a = oracle(sys.argv[1]); b = oracle(sys.argv[2])
print("  clone : %3d bytes %s" % (len(a), a.hex()))
print("  oracle: %3d bytes %s" % (len(b), b.hex()))
print("RESULT: IDENTICAL" if a == b and len(a) > 0 else "RESULT: DIFFER")
PY
