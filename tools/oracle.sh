#!/bin/sh
# TPZASM: TDL ZASM / PSA PASM compatible assembler - oracle.sh
# oracle.sh - assemble a source with BOTH original CP/M assemblers (zasm.com and
# pasm.com) under tnylpo, capture their object/listing output, and diff them.
#
# The TDL/PSA assemblers can read console input at assembly time (the '\'
# operator, used by VEDIT's build menus).  Any such answers are read from THIS
# script's stdin and replayed identically to both assemblers.  For sources with
# no prompts, redirect stdin from /dev/null:
#
#     tools/oracle.sh tests/smoke.asm < /dev/null
#
# Env:
#   ASM_REF  repo root; the original zasm.com/pasm.com live in ASM_REF/orig/
#            (default: repo root)
#   OUTDIR   directory to leave captured outputs in  (default: ./oracle-out)

set -u

src=${1:?Usage: oracle.sh source.asm  (console answers on stdin)}

export CPE1704TKS=1
asmcommon=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
if [ ! -f "${asmcommon}/.common.sh" ]; then
  printf '%s\n' "ERROR: cannot locate .common.sh" >&2
  exit 1
fi
# shellcheck disable=SC1091
. "${asmcommon}/.common.sh"
export FIND_COMMAND_FATAL=1
find_command basename cat cmp cp diff dirname env mkdir rm sed timeout \
  tnylpo tr wc || exit 1

ref=${ASM_REF:-${asmcommon}}
outdir=${OUTDIR:-oracle-out}

base=$(basename -- "${src}" | sed 's/\.[Aa][Ss][Mm]$//')
lc=$(printf '%s' "${base}" | tr '[:upper:]' '[:lower:]')
uc=$(printf '%s' "${base}" | tr '[:lower:]' '[:upper:]')

# shellcheck disable=SC2119
scratch=$(mktemp -d 2> /dev/null || mktemp_local)
[ -d "${scratch}" ] || {
  rm -f "${scratch}"
  mkdir -p "${scratch}"
}
trap 'env rm -rf "$scratch"' EXIT
env mkdir -p "${outdir}"

# Stage the source as a lowercase, CP/M-format (CRLF + trailing ^Z) file on A:.
{
  sed 's/$/\r/' -- "${src}"
  printf '\032'
} > "${scratch}/${lc}.asm"

# Capture console answers once; replay identically to both assemblers.
ans="${scratch}/answers.txt"
cat > "${ans}"

run()
{
  name=$1
  env rm -f "${outdir}/${name}.rel" "${outdir}/${name}.prn" \
    "${outdir}/${name}.hex" "${outdir}/${name}.con"
  (
    cd "${scratch}" || exit 1
    env rm -f "${lc}.rel" "${lc}.prn" "${lc}.hex"
    timeout -k 5 30 tnylpo "${ref}/orig/${name}.com" "${uc}" \
      < "${ans}" > console.txt 2>&1
    echo "[rc=$?]" >> console.txt
  )
  env cp -f "${scratch}/console.txt" "${outdir}/${name}.con"
  for e in rel prn hex; do
    if [ -f "${scratch}/${lc}.${e}" ]; then
      env cp -f "${scratch}/${lc}.${e}" "${outdir}/${name}.${e}"
    fi
  done
}

run zasm
run pasm

echo "===== console ====="
for n in zasm pasm; do
  echo "--- ${n} ---"
  sed 's/^/  /' "${outdir}/${n}.con" 2> /dev/null
done

echo
echo "===== object output (.rel) ====="
for n in zasm pasm; do
  if [ -f "${outdir}/${n}.rel" ]; then
    rsz=$(wc -c < "${outdir}/${n}.rel")
    printf '  %-4s : %s bytes  -> %s\n' "${n}" "${rsz}" "${outdir}/${n}.rel"
  else
    printf '  %-4s : (no .rel produced)\n' "${n}"
  fi
done

if [ -f "${outdir}/zasm.rel" ] && [ -f "${outdir}/pasm.rel" ]; then
  if cmp -s "${outdir}/zasm.rel" "${outdir}/pasm.rel"; then
    echo "  DIFF : zasm.rel == pasm.rel  (IDENTICAL)"
  else
    echo "  DIFF : zasm.rel != pasm.rel  (see hexdump below)"
  fi
fi
