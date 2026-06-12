#!/bin/sh
# TPZASM: TDL ZASM / PSA PASM compatible assembler - vrel.sh
# vrel.sh - assemble SRC.asm with the clone (-R binary REL and -X ASCII REL)
# AND with the original PSA PASM under tnylpo, then compare the object record
# streams byte-for-byte.  The originals run under CP/M, which pads the output
# file to a 128-byte record boundary with ^Z/NUL; the clone writes only the
# records, so the oracle is compared up to the clone's length and the remainder
# is required to be pure padding.  Usage: tools/vrel.sh tests/foo.asm
set -u
src=${1:?Usage: vrel.sh src.asm}

export CPE1704TKS=1
asmcommon=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck disable=SC1091
. "${asmcommon}/.common.sh"
export FIND_COMMAND_FATAL=1
find_command basename cp dirname env mkdir python3 sed timeout tnylpo tr \
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

# clone: binary REL (-R) and ASCII REL (-X)
"${ref}/asm" -p -R "${work}/clone.rel" -X "${work}/clone.hex" "${src}" \
  > /dev/null 2>&1

# oracle: PSA PASM names its object after the source -- .rel for a relocatable
# (.PREL) module, .hex for an absolute (.PABS) one -- so grab whichever it
# wrote.  .PBIN (the default) yields the binary form; the .PHEX copy below the
# ASCII form.  copy_obj <dest> copies whichever object PASM just produced.
copy_obj()
{
  if [ -f "${work}/${base}.rel" ]; then
    env cp -f "${work}/${base}.rel" "${1}"
  elif [ -f "${work}/${base}.hex" ]; then
    env cp -f "${work}/${base}.hex" "${1}"
  fi
}
for f in "$(dirname "${src}")"/*.asm; do
  [ -f "${f}" ] || continue
  b=$(basename "${f}" | tr '[:upper:]' '[:lower:]')
  {
    sed 's/$/\r/' "${f}"
    printf '\032'
  } > "${work}/${b}"
done
env cp -f "${ref}/orig/pasm.com" "${work}/"
rm -f "${work}/${base}.rel" "${work}/${base}.hex"
(cd "${work}" && timeout 30 tnylpo -b pasm.com "${base}.asm" > /dev/null 2>&1)
copy_obj "${work}/oracle.rel"

# ASCII oracle: prepend .PHEX and reassemble (ASCII object, same extension).
{
  printf '\t.PHEX\r\n'
  sed 's/$/\r/' "${src}"
  printf '\032'
} \
  > "${work}/${base}.asm"
rm -f "${work}/${base}.rel" "${work}/${base}.hex"
(cd "${work}" && timeout 30 tnylpo -b pasm.com "${base}.asm" > /dev/null 2>&1)
copy_obj "${work}/oracle.hex"

python3 - "${work}" << 'PY'
import sys, os
work = sys.argv[1]
def cmp(clone, oracle, label):
    if not os.path.exists(clone) or not os.path.exists(oracle):
        side = "clone" if not os.path.exists(clone) else "oracle"
        print("  %-6s : MISSING (%s)" % (label, side))
        return False
    c = open(clone, 'rb').read()
    o = open(oracle, 'rb').read()
    head = o[:len(c)]
    tail = o[len(c):]
    ok = (head == c) and all(b in (0x00, 0x1a) for b in tail)
    if ok:
        print("  %-6s : IDENTICAL (%d record bytes)" % (label, len(c)))
    else:
        print("  %-6s : DIFFER (clone %d, oracle %d)" % (label, len(c), len(o)))
        for i in range(min(len(c), len(head))):
            if c[i] != head[i]:
                print("           first diff @%d: clone %02X oracle %02X"
                      % (i, c[i], head[i]))
                print("           clone : %s" % c[max(0,i-4):i+8].hex())
                print("           oracle: %s" % head[max(0,i-4):i+8].hex())
                break
    return ok
def g(name):
    return os.path.join(work, name)
a = cmp(g("clone.rel"), g("oracle.rel"), "-R/bin")
b = cmp(g("clone.hex"), g("oracle.hex"), "-X/asc")
sys.exit(0 if (a and b) else 1)
PY
