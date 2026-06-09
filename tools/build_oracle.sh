#!/bin/sh
# TPZASM: TDL ZASM / PSA PASM compatible assembler - build_oracle.sh
# build_oracle.sh - run a full multi-module CP/M assembly through the original
# assembler(s) under tnylpo.  The master source pulls in the rest via .INSERT;
# assembly-time console answers (the '\' operator) come from an answers file.
# If the build emits a .HEX, HEXCOM is run to produce the final .COM.
#
#   tools/build_oracle.sh MASTER [SRCDIR] [ANSWERS] [ASMS]
#     MASTER   root source basename (host <master>.asm), e.g. vedplus
#     SRCDIR   dir of .asm/.tbl modules (default: /home/jhj/src/VEDIT/src)
#     ANSWERS  console answers, one per line     (default: /dev/null)
#     ASMS     which originals to run            (default: "pasm zasm")
#
# Env: ASM_REF (repo root; originals zasm.com/pasm.com/hexcom.com in
#      ASM_REF/orig; default repo root)
#      OUTDIR  (default ./oracle-out)
set -u
master=${1:?Usage: build_oracle.sh master [srcdir] [answers] [asms]}
srcdir=${2:-/home/jhj/src/VEDIT/src}
answers=${3:-/dev/null}
asms=${4:-pasm zasm}

export CPE1704TKS=1
asmcommon=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
if [ ! -f "${asmcommon}/.common.sh" ]; then
  printf '%s\n' "ERROR: cannot locate .common.sh" >&2
  exit 1
fi
# shellcheck disable=SC1091
. "${asmcommon}/.common.sh"
export FIND_COMMAND_FATAL=1
find_command awk basename cmp cp dirname env mkdir rm sed tail timeout \
  tnylpo tr wc || exit 1

ref=${ASM_REF:-${asmcommon}}
outdir=${OUTDIR:-oracle-out}

# build_one runs tnylpo from a temp work dir, so paths must be absolute.
abspath()
{
  case "$1" in
  /*) printf '%s\n' "$1" ;;
  *) printf '%s/%s\n' "${PWD}" "$1" ;;
  esac
}
answers=$(abspath "${answers}")
outdir=$(abspath "${outdir}")

mlc=$(printf '%s' "${master}" | tr '[:upper:]' '[:lower:]')
muc=$(printf '%s' "${master}" | tr '[:lower:]' '[:upper:]')

build_one()
{
  asm=$1
  # shellcheck disable=SC2119
  work=$(mktemp -d 2> /dev/null || mktemp_local)
  [ -d "${work}" ] || {
    rm -f "${work}"
    mkdir -p "${work}"
  }
  n=0
  for f in "${srcdir}"/*.asm "${srcdir}"/*.tbl; do
    [ -f "${f}" ] || continue
    b=$(basename "${f}" | tr '[:upper:]' '[:lower:]')
    {
      sed 's/$/\r/' "${f}"
      printf '\032'
    } > "${work}/${b}"
    n=$((n + 1))
  done
  dest="${outdir}/${master}-${asm}"
  env rm -rf "${dest}"
  env mkdir -p "${dest}"
  (
    cd "${work}" || exit 1
    timeout 300 tnylpo "${ref}/orig/${asm}.com" "${muc}" \
      < "${answers}" > asm.con 2>&1
    echo "[asm rc=$?]" >> asm.con
    if [ -f "${mlc}.hex" ]; then
      timeout 120 tnylpo "${ref}/orig/hexcom.com" "${muc}" \
        < /dev/null > hexcom.con 2>&1
      echo "[hexcom rc=$?]" >> hexcom.con
    fi
  )
  for e in hex rel prn com con; do
    [ -f "${work}/${mlc}.${e}" ] \
      && env cp -f "${work}/${mlc}.${e}" "${dest}/${muc}.${e}"
  done
  env cp -f "${work}/asm.con" "${dest}/asm.con" 2> /dev/null
  [ -f "${work}/hexcom.con" ] \
    && env cp -f "${work}/hexcom.con" "${dest}/hexcom.con"
  env rm -rf "${work}"

  echo "================= ${asm}  (staged ${n} modules) ================="
  echo "--- assembler console (tail) ---"
  tail -12 "${dest}/asm.con" | sed 's/^/  /'
  [ -f "${dest}/hexcom.con" ] && {
    echo "--- hexcom console ---"
    sed 's/^/  /' "${dest}/hexcom.con"
  }
  echo "--- outputs ---"
  # shellcheck disable=SC2012 # display-only listing; filenames are ours
  ls -l "${dest}" 2> /dev/null | awk 'NR>1{print "  "$5" "$NF}'
}

for a in ${asms}; do build_one "${a}"; done

echo "===== object comparison (pasm vs zasm) ====="
for e in hex rel com; do
  pf="${outdir}/${master}-pasm/${muc}.${e}"
  zf="${outdir}/${master}-zasm/${muc}.${e}"
  if [ -f "${pf}" ] && [ -f "${zf}" ]; then
    if cmp -s "${pf}" "${zf}"; then
      psz=$(wc -c < "${pf}")
      echo "  .${e} : IDENTICAL (${psz} bytes)"
    else
      psz=$(wc -c < "${pf}")
      zsz=$(wc -c < "${zf}")
      echo "  .${e} : DIFFER (pasm=${psz} zasm=${zsz})"
    fi
  fi
done
