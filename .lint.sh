#!/bin/sh
# .lint.sh
# Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
# SPDX-License-Identifier: MIT-0
# scspell-id: 1ad67fe4-6318-11f1-aca2-246e96298730

################################################################################

if [ -n "${ZSH_VERSION-}" ]; then
  emulate sh
  setopt sh_word_split
fi

################################################################################

test -d "/opt/freeware/bin" && {
  export PATH="/opt/freeware/bin:${PATH:-}"
}

################################################################################

test -d "/usr/pkg/gnu/bin" && {
  export PATH="${PATH:-}:/usr/pkg/gnu/bin"
}

################################################################################

set -eu

################################################################################

cd "$(dirname "$0")"

################################################################################

# shellcheck disable=SC2065
test -f "./${0##*/}" > /dev/null 2>&1 || {
  printf '%s\n' "ERROR: Could not locate script in current directory."
  exit 1
}

################################################################################

# shellcheck disable=SC2065
test -f "./.common.sh" > /dev/null 2>&1 || {
  printf '%s\n' "ERROR: Could not locate .common.sh in current directory."
  exit 1
}

################################################################################

export CPE1704TKS=1

# shellcheck disable=SC1091
. ./.common.sh

################################################################################

export FIND_COMMAND_FATAL=1
find_command "${AWK:-awk}" diff grep head "${MAKE:-make}" mkdir paste rm \
  rmdir sed sleep tr uname

################################################################################

export FIND_COMMAND_FATAL=0

# shellcheck disable=SC2310
if out=$(
  find_command \
    "${BEAR_CMD:-bear}" "${BLACK_CMD:-black}" "${CH_CMD:-ch}" \
    "${CLANG_CMD:-clang}" "${CPPCHECK:-cppcheck}" codespell cppi flawfinder \
    git "${GCC_CMD:-gcc}" mktemp plog-converter pvs-studio-analyzer \
    "${REUSE_CMD:-reuse}" "${SCAN_BUILD_CMD:-scan-build}" \
    "${SHELLCHECK_CMD:-shellcheck}" "${SHFMT_CMD:-shfmt}" valgrind \
    "${HOME}/src/smatch/smatch" "${HOME}/src/smatch/cgcc" 2>&1
); then
  status=0
else
  status="$?"
fi

width="$(detect_width)"

# shellcheck disable=SC2310
printf '%s\n' "${out:-}" \
  | wrap "${width:?}"

unset NEED_PAUSE

if [ "${status:?}" -ne 0 ]; then
  NEED_PAUSE=1
fi

################################################################################

os="$(uname -s 2> /dev/null)"

unset CHECK_OLINT

case "${os:?}" in
Linux)
  CHECK_OLINT=1
  ;;
Solaris)
  CHECK_OLINT=1
  ;;
*) : ;;
esac

unset OLINT

if [ "${CHECK_OLINT:-0}" -eq 1 ]; then
  if command -v "/opt/solarisstudio12.6/bin/lint" \
    > /dev/null 2>&1; then
    OLINT="/opt/solarisstudio12.6/bin/lint"
  elif command -v "/opt/oracle/developerstudio12.6/bin/lint" \
    > /dev/null 2>&1; then
    OLINT="/opt/oracle/developerstudio12.6/bin/lint"
  fi

  if [ -z "${OLINT+x}" ]; then
    printf '%s\n' "WARNING: Oracle Developer Studio Lint 12.6 was not found!" \
      | wrap "${width:?}"
    NEED_PAUSE=1
  fi
fi

################################################################################

case ${OVERRIDE_PAUSE:-} in
'' | *[!0-9]*)
  unset OVERRIDE_PAUSE
  ;;
*) : ;;
esac

test "${NEED_PAUSE:-0}" -ne 1 || {
  printf '%s\n' \
    "Some checks will be skipped! [pausing ${OVERRIDE_PAUSE:-10}s]" \
    | wrap "${width:?}"
  sleep "${OVERRIDE_PAUSE:-10}"
}

################################################################################

rc=0

################################################################################

printf '\n%s\n\n' ">>>>>>>>>>>>>>>> distclean <<<<<<<<<<<<<<<<"

(
  set -x
  "${MAKE:-make}" distclean > /dev/null
)

################################################################################

printf '\n%s\n\n' ">>>>>>>>>>>>>>>> make <<<<<<<<<<<<<<<<"

if (
  set -x
  "${MAKE:-make}"
); then
  :
else
  printf '%s\n' "****** FAILURE DETECTED ******"
  rc=1
fi

################################################################################

command -v codespell > /dev/null 2>&1 && {
  command -v git > /dev/null 2>&1 && {
    printf '\n%s\n\n' ">>>>>>>>>>>>>>>> codespell <<<<<<<<<<<<<<<<"
    if (
      cd src
      CODESPELL_EXCLUDE=$({
        git ls-files --ignored --exclude-standard --others \
          | sed 's/["\\]/\\&/g' \
          | paste -sd',' -
      } | sed 's/^/"/; s/$/"/')
      codespell --ignore-words-list \
        "ACI,clen,DAA" --skip "${CODESPELL_EXCLUDE:-}" .
    ); then
      :
    else
      printf '%s\n' "****** FAILURE DETECTED ******"
      rc=1
    fi
  }
}

################################################################################

command -v editorconfig-checker > /dev/null 2>&1 && {
  printf '\n%s\n\n' ">>>>>>>>>>>>>>>> editorconfig <<<<<<<<<<<<<<<<"
  if (
    editorconfig-checker
  ); then
    :
  else
    printf '%s\n' "****** FAILURE DETECTED ******"
    rc=1
  fi
}

################################################################################

printf '\n%s\n\n' ">>>>>>>>>>>>>>>> dangling words <<<<<<<<<<<<<<<<"

if (
  set -x
  (awk '/^```/ { f = !f; next } !f' README.md \
    | grep -xi '[^[:space:]]\+' \
    | grep -Ev '(`|<|>|\[|\]|:)' \
    | grep -Ev '^[-*_]{3,}$') && {
    : ERROR: Dangling words found
    exit 1
  } || exit 0
); then
  :
else
  printf '%s\n' "****** FAILURE DETECTED ******"
  rc=1
fi

################################################################################

printf '\n%s\n\n' ">>>>>>>>>>>>>>>> tag generation <<<<<<<<<<<<<<<<"

if (
  set -x
  "${MAKE:-make}" tags
); then
  :
else
  printf '%s\n' "****** FAILURE DETECTED ******"
  rc=1
fi

################################################################################

printf '\n%s\n\n' ">>>>>>>>>>>>>>>> license diff <<<<<<<<<<<<<<<<"

if (
  set -x
  diff LICENSES/MIT-0.txt LICENSE
); then
  :
else
  printf '%s\n' "****** FAILURE DETECTED ******"
  rc=1
fi

################################################################################

command -v flawfinder > /dev/null 2>&1 && {
  printf '\n%s\n\n' ">>>>>>>>>>>>>>>> flawfinder <<<<<<<<<<<<<<<<"
  if (
    set -x
    flawfinder --quiet --dataonly --omittime --error-level=3 --context \
      --minlevel=3 src/*.c
  ); then
    :
  else
    printf '%s\n' "****** FAILURE DETECTED ******"
    rc=1
  fi
}

################################################################################

command -v cppi > /dev/null 2>&1 && {
  printf '\n%s\n\n' ">>>>>>>>>>>>>>>> cppi <<<<<<<<<<<<<<<<"
  for f in ./src/*.c; do
    if (
      set -x
      cppi -a --check "${f}"
    ); then
      :
    else
      printf '%s\n' "****** FAILURE DETECTED ******"
      rc=1
    fi
  done
}

################################################################################

CHECK_LEVEL=""
command -v "${CPPCHECK:-cppcheck}" > /dev/null 2>&1 && {
  "${CPPCHECK:-cppcheck}" --check-level=exhaustive 2>&1 \
    | grep -q 'unrecognized command line option' \
    || CHECK_LEVEL="--check-level=exhaustive"
}

################################################################################

CPPCHECK_FLAGS="--enable=warning,style,performance"
CPPCHECK_FLAGS="${CPPCHECK_FLAGS:?},portability,unusedFunction"
CPPCHECK_FLAGS="${CPPCHECK_FLAGS:?} --force ${CHECK_LEVEL:-}"
CPPCHECK_FLAGS="${CPPCHECK_FLAGS:?} --std=c89"
CPPCHECK_FLAGS="${CPPCHECK_FLAGS:?} --inline-suppr"
CPPCHECK_FLAGS="${CPPCHECK_FLAGS:?} --inconclusive"
CPPCHECK_FLAGS="${CPPCHECK_FLAGS:?} --quiet"
CPPCHECK_FLAGS="${CPPCHECK_FLAGS:?} --error-exitcode=2"
CPPCHECK_FLAGS="${CPPCHECK_FLAGS:?} -D__CPPCHECK__"
CPPCHECK_FLAGS="${CPPCHECK_FLAGS:?} -D__LINT__"
CPPCHECK_FLAGS="${CPPCHECK_FLAGS:?} -j 1"

################################################################################

command -v "${CPPCHECK:-cppcheck}" > /dev/null 2>&1 && {
  printf '\n%s\n\n' ">>>>>>>>>>>>>>>> cppcheck unix64 <<<<<<<<<<<<<<<<"
  if (
    set -x
    # shellcheck disable=SC2086
    "${CPPCHECK:-cppcheck}" \
      ${CPPCHECK_FLAGS:?} --platform=unix64 \
      ./src/*.c
  ); then
    :
  else
    printf '%s\n' "****** FAILURE DETECTED ******"
    rc=1
  fi
}

################################################################################

command -v "${CPPCHECK:-cppcheck}" > /dev/null 2>&1 && {
  printf '\n%s\n\n' ">>>>>>>>>>>>>>>> cppcheck unix32 <<<<<<<<<<<<<<<<"
  if (
    set -x
    # shellcheck disable=SC2086
    "${CPPCHECK:-cppcheck}" \
      ${CPPCHECK_FLAGS:?} --platform=unix32 \
      ./src/*.c
  ); then
    :
  else
    printf '%s\n' "****** FAILURE DETECTED ******"
    rc=1
  fi
}

################################################################################

command -v "${CPPCHECK:-cppcheck}" > /dev/null 2>&1 && {
  printf '\n%s\n\n' ">>>>>>>>>>>>>>>> cppcheck win64 <<<<<<<<<<<<<<<<"
  if (
    "${CPPCHECK:-cppcheck}" --check-level=exhaustive 2>&1 \
      | grep -q 'unrecognized command line option' \
      || {
        CHECK_LEVEL="--check-level=exhaustive"
      } || :
    set -x
    # shellcheck disable=SC2086
    "${CPPCHECK:-cppcheck}" \
      ${CPPCHECK_FLAGS:?} --platform=win64 \
      ./src/*.c
  ); then
    :
  else
    printf '%s\n' "****** FAILURE DETECTED ******"
    rc=1
  fi
}

################################################################################

command -v "${CPPCHECK:-cppcheck}" > /dev/null 2>&1 && {
  printf '\n%s\n\n' ">>>>>>>>>>>>>>>> cppcheck avr8 <<<<<<<<<<<<<<<<"
  if (
    "${CPPCHECK:-cppcheck}" --check-level=exhaustive 2>&1 \
      | grep -q 'unrecognized command line option' \
      || {
        CHECK_LEVEL="--check-level=exhaustive"
      } || :
    set -x
    # shellcheck disable=SC2086
    "${CPPCHECK:-cppcheck}" \
      ${CPPCHECK_FLAGS:?} --platform=avr8 \
      ./src/*.c
  ); then
    :
  else
    printf '%s\n' "****** FAILURE DETECTED ******"
    rc=1
  fi
}

################################################################################

GCCW=""

command -v "${GCC_CMD:-gcc}" > /dev/null 2>&1 && {
  for gw in -Wlogical-op -Wduplicated-cond -Wduplicated-branches \
    -Wjump-misses-init -Warith-conversion -Wtrampolines \
    -Wcast-align=strict -Wshift-overflow=2 -Wformat-overflow=2 \
    -Wformat-truncation=2 -Wstringop-overflow=4 -Walloc-zero \
    -Wnull-dereference -Wuse-after-free=3 -Wdangling-pointer=2; do
    printf '%s\n' "int main(void){return 0;}" \
      | "${GCC_CMD:-gcc}" -Werror "${gw}" -x c -c -o /dev/null - \
        > /dev/null 2>&1 \
      && GCCW="${GCCW} ${gw}"
  done
}

################################################################################

aCFLAGS="-std=c89 -pedantic -ansi -Wall -Werror -Wpedantic -Wextra -O3"
aCFLAGS="${aCFLAGS:?} -Wsign-conversion${GCCW}"
aCFLAGS="${aCFLAGS:?} -U_FORTIFY_SOURCE"
aCFLAGS="${aCFLAGS:?} -D_FORTIFY_SOURCE=${FORTIFY_LEVEL:-3}"
aCFLAGS="${aCFLAGS:?} -DGCC_ANALYZER -march=native -fanalyzer"

command -v "${GCC_CMD:-gcc}" > /dev/null 2>&1 && {
  printf '\n%s\n\n' ">>>>>>>>>>>>>>>> gcc analyzer <<<<<<<<<<<<<<<<"
  "${MAKE:-make}" distclean > /dev/null 2>&1 || :
  if (
    set -x
    "${MAKE:-make}" \
      CC="${GCC_CMD:-gcc}" \
      CFLAGS="${aCFLAGS:?}"
  ); then
    :
  else
    printf '%s\n' "****** FAILURE DETECTED ******"
    rc=1
  fi
}

################################################################################

lCFLAGS="-U_FORTIFY_SOURCE -O3 -Weverything -Wno-unsafe-buffer-usage"
lCFLAGS="${lCFLAGS:-} -Wno-padded -Wno-missing-noreturn"
lCFLAGS="${lCFLAGS:-} -Wno-disabled-macro-expansion"
lCFLAGS="${lCFLAGS:-} -Wno-used-but-marked-unused -Werror -ferror-limit=0"
lCFLAGS="${lCFLAGS:-} -std=c89 -Wno-padded -Wno-used-but-marked-unused"

command -v "${CLANG_CMD:-clang}" > /dev/null 2>&1 && {
  printf '\n%s\n\n' ">>>>>>>>>>>>>>>> clang strict <<<<<<<<<<<<<<<<"
  "${MAKE:-make}" distclean > /dev/null 2>&1 || :
  if (
    set -x
    "${MAKE:-make}" \
      CC="${CLANG_CMD:-clang}" \
      CFLAGS="${lCFLAGS:?}"
  ); then
    :
  else
    printf '%s\n' "****** FAILURE DETECTED ******"
    rc=1
  fi
}

################################################################################

command -v "${SCAN_BUILD_CMD:-scan-build}" > /dev/null 2>&1 && {
  command -v "${CLANG_CMD:-clang}" > /dev/null 2>&1 && {
    printf '\n%s\n\n' ">>>>>>>>>>>>>>>> scan-build <<<<<<<<<<<<<<<<"
    "${MAKE:-make}" distclean > /dev/null 2>&1 || :
    # shellcheck disable=SC2119
    TMPFILE="$(mktemp 2> /dev/null || mktemp_local)"
    rm -f "${TMPFILE:?}" || :
    if (
      set -x
      "${SCAN_BUILD_CMD:-scan-build}" \
        --status-bugs \
        -o "${TMPFILE:?}" "${MAKE:-make}" all > /dev/null 2>&1
    ); then
      rm -rf "${TMPFILE:?}" || :
    else
      printf '%s\n' "****** FAILURE DETECTED ******"
      printf \
        '\n%s\n' "*** scan-build reported issues, see '${TMPFILE:?}'"
      rc=1
    fi
  }
}

################################################################################

command -v "${BEAR_CMD:-bear}" > /dev/null 2>&1 && {
  command -v pvs-studio-analyzer > /dev/null 2>&1 && {
    command -v plog-converter > /dev/null 2>&1 && {
      printf '\n%s\n\n' ">>>>>>>>>>>>>>>> pvs-studio <<<<<<<<<<<<<<<<"
      rm -f compile_commands.json log.pvs 2> /dev/null
      rm -f -r ./pvsreport 2> /dev/null 2>&1
      "${MAKE:-make}" distclean > /dev/null 2>&1 || :
      (
        set -x
        "${BEAR_CMD:-bear}" -- "${MAKE:-make}" > /dev/null
      )
      (
        set -x
        pvs-studio-analyzer analyze -q --intermodular -j 1 -o log.pvs
      )
      if (
        set -x
        plog-converter -a "GA:1,2,3" -t fullhtml log.pvs \
          -o pvsreport --indicateWarnings
      ); then
        :
      else
        printf '%s\n' "****** FAILURE DETECTED ******"
        rc=1
      fi
    }
  }
}

################################################################################

ch_check()
{
  cc_rc=0
  # shellcheck disable=SC2119
  cc_tmp="$(mktemp 2> /dev/null || mktemp_local)"
  printf '+ %s -n %s\n' "${CH_CMD:-ch}" "$1"
  "${CH_CMD:-ch}" -n "$1" > "${cc_tmp:?}" 2>&1 || cc_rc="$?"
  cc_msg="$(tr -d '\000' < "${cc_tmp:?}" | tr -d '[:space:]')"
  if [ "${cc_rc}" -ne 0 ] || [ -n "${cc_msg}" ]; then
    tr -d '\000' < "${cc_tmp:?}"
    printf '%s\n' "****** FAILURE DETECTED ******"
    rm -f "${cc_tmp:?}" || :
    return 1
  fi
  rm -f "${cc_tmp:?}" || :
  return 0
}

################################################################################

command -v "${CH_CMD:-ch}" > /dev/null 2>&1 && {
  printf '\n%s\n\n' ">>>>>>>>>>>>>>>> ch <<<<<<<<<<<<<<<<"
  cat src/assemble.c src/expr.c src/insn.c src/lex.c src/main.c src/sym.c \
    > src/_chtmp.c
  # shellcheck disable=SC2310
  (cd src && ch_check ./_chtmp.c) || rc=1
  rm -f src/_chtmp.c
  # shellcheck disable=SC2310
  (cd src && ch_check ./hexcom.c) || rc=1
}

################################################################################

command -v "${OLINT:-}" > /dev/null 2>&1 && {
  printf '\n%s\n\n' ">>>>>>>>>>>>>>>> oracle lint <<<<<<<<<<<<<<<<"
  olint_engine=""
  for olint_f in ./src/*.c; do
    case "${olint_f}" in
    ./src/main.c | ./src/test_expr.c | ./src/hexcom.c) : ;;
    *) olint_engine="${olint_engine} ${olint_f}" ;;
    esac
  done
  olint_rc=0
  # test_expr links only expr/sym, so -x silences the engine prototypes in
  # asm.h (lex_line/asm_source/insn_find) that this subset declares but cannot
  # use or define.
  for olint_unit in "${olint_engine} ./src/main.c" \
    "-x ./src/expr.c ./src/sym.c ./src/test_expr.c" "./src/hexcom.c"; do
    if (
      set -x
      # shellcheck disable=SC2086
      "${OLINT:?}" \
        -O -fd -std=c89 -err=warn -XCC=no \
        -errchk=structarg,parentheses,locfmtchk ${olint_unit}
    ); then
      :
    else
      olint_rc=1
    fi
  done
  if [ "${olint_rc}" -ne 0 ]; then
    printf '%s\n' "****** FAILURE DETECTED ******"
    rc=1
  fi
}

################################################################################

command -v "${REUSE_CMD:-reuse}" > /dev/null 2>&1 && {
  printf '\n%s\n\n' ">>>>>>>>>>>>>>>> reuse <<<<<<<<<<<<<<<<"
  if (
    set -x
    "${REUSE_CMD:-reuse}" lint -q || "${REUSE_CMD:-reuse}" lint
  ); then
    :
  else
    printf '%s\n' "****** FAILURE DETECTED ******"
    rc=1
  fi
}

################################################################################

command -v "${SHELLCHECK_CMD:-shellcheck}" > /dev/null 2>&1 && {
  printf '\n%s\n\n' ">>>>>>>>>>>>>>>> shellcheck <<<<<<<<<<<<<<<<"
  if (
    set -x
    "${SHELLCHECK_CMD:-shellcheck}" -o any,all \
      ./.common.sh \
      ./.lint.sh \
      ./tools/*.sh
  ); then
    :
  else
    printf '%s\n' "****** FAILURE DETECTED ******"
    rc=1
  fi
}

################################################################################

command -v "${SHFMT_CMD:-shfmt}" > /dev/null 2>&1 && {
  printf '\n%s\n\n' ">>>>>>>>>>>>>>>> shfmt <<<<<<<<<<<<<<<<"
  if (
    set -x
    "${SHFMT_CMD:-shfmt}" -bn -sr -fn -i 2 -s -d \
      ./tools/*.sh ./.common.sh ./.lint.sh
  ); then
    :
  else
    printf '%s\n' "****** FAILURE DETECTED ******"
    rc=1
  fi
}

################################################################################

command -v "${BLACK_CMD:-black}" > /dev/null 2>&1 && {
  printf '\n%s\n\n' ">>>>>>>>>>>>>>>> black <<<<<<<<<<<<<<<<"
  if (
    set -x
    "${BLACK_CMD:-black}" --quiet --check \
      tools/jr_audit.py
  ); then
    :
  else
    printf '%s\n' "****** FAILURE DETECTED ******"
    ("${BLACK_CMD:-black}" --check \
      tools/jr_audit.py || :)
    rc=1
  fi
}

################################################################################

command -v "${HOME}/src/smatch/smatch" > /dev/null 2>&1 && {
  command -v "${HOME}/src/smatch/cgcc" > /dev/null 2>&1 && {
    printf '\n%s\n\n' ">>>>>>>>>>>>>>>> smatch <<<<<<<<<<<<<<<<"
    "${MAKE:-make}" distclean > /dev/null 2>&1 || :
    if (
      set -x
      unset CC > /dev/null 2>&1 || :
      unset CFLAGS > /dev/null 2>&1 || :
      unset LDFLAGS > /dev/null 2>&1 || :
      "${MAKE:-make}" -f Makefile \
        CHECK="${HOME}/src/smatch/smatch \
        --fatal-checks --two-pass --full-path" \
        CC="${HOME}/src/smatch/cgcc"
    ); then
      :
    else
      printf '%s\n' "****** FAILURE DETECTED ******"
      rc=1
    fi
  }
}

################################################################################

SAN_CFLAGS="-O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all"
SAN_CFLAGS="${SAN_CFLAGS:?} -fno-omit-frame-pointer"

san_probe()
{
  sp_rc=1
  # shellcheck disable=SC2119
  sp_d="$(mktemp -d 2> /dev/null \
    || printf '%s\n' "${TMPDIR:-/tmp}/asmsp.$$$$")"
  mkdir -p "${sp_d:?}" || :
  printf '%s\n' '#include <stdio.h>' \
    'int main(void) { (void)puts("ok"); return 0; }' > "${sp_d}/t.c"
  # shellcheck disable=SC2086
  if "${CLANG_CMD:-clang}" ${SAN_CFLAGS:?} -o "${sp_d}/t" "${sp_d}/t.c" \
    > /dev/null 2>&1 \
    && "${sp_d}/t" > /dev/null 2>&1; then
    sp_rc=0
  fi
  rm -rf "${sp_d}" || :
  return "${sp_rc}"
}

################################################################################

# Exercise the built tools: both dialects with -o image + -l listing/symbol
# table, the -e expression evaluator, the unit-test driver, and hexcom.
asm_cycle()
{
  ac_rc=1
  # shellcheck disable=SC2119
  ac_d="$(mktemp -d 2> /dev/null \
    || printf '%s\n' "${TMPDIR:-/tmp}/asmac.$$$$")"
  mkdir -p "${ac_d:?}" || :
  printf ':0A0100000102030405060708090ABE\n:00000001FF\n' \
    > "${ac_d}/h.hex"
  if ./asm -z -o "${ac_d}/z.com" -l "${ac_d}/z.lst" tests/insn8080.asm \
    > /dev/null 2>&1 \
    && ./asm -p -o "${ac_d}/p.com" -l "${ac_d}/p.lst" tests/macro.asm \
      > /dev/null 2>&1 \
    && ./asm -z -l "${ac_d}/c.lst" tests/cond.asm > /dev/null 2>&1 \
    && ./asm -e '(1+2)*3' > /dev/null 2>&1 \
    && ./test_expr > /dev/null 2>&1 \
    && ./hexcom "${ac_d}/h" > /dev/null 2>&1; then
    ac_rc=0
  fi
  rm -rf "${ac_d}" || :
  return "${ac_rc}"
}

################################################################################

command -v "${CLANG_CMD:-clang}" > /dev/null 2>&1 && {
  printf '\n%s\n\n' \
    ">>>>>>>>>>>>>>>> clang sanitizers <<<<<<<<<<<<<<<<"
  # shellcheck disable=SC2310
  if san_probe; then
    "${MAKE:-make}" distclean > /dev/null 2>&1 || :
    # shellcheck disable=SC2310
    if (
      set -x
      "${MAKE:-make}" CC="${CLANG_CMD:-clang}" CFLAGS="${SAN_CFLAGS:?}" \
        && "${MAKE:-make}" CC="${CLANG_CMD:-clang}" \
          CFLAGS="${SAN_CFLAGS:?}" test_expr
    ) && asm_cycle; then
      :
    else
      printf '%s\n' "****** FAILURE DETECTED ******"
      rc=1
    fi
  else
    printf '%s\n' ">> sanitizer runtime unavailable; SKIPPING sanitizer test"
  fi
}

################################################################################

command -v valgrind > /dev/null 2>&1 && {
  printf '\n%s\n\n' ">>>>>>>>>>>>>>>> valgrind memcheck <<<<<<<<<<<<<<<<"
  "${MAKE:-make}" distclean > /dev/null 2>&1 || :
  # shellcheck disable=SC2119
  vg_d="$(mktemp -d 2> /dev/null \
    || printf '%s\n' "${TMPDIR:-/tmp}/asmvg.$$$$")"
  mkdir -p "${vg_d:?}" || :
  printf ':0A0100000102030405060708090ABE\n:00000001FF\n' \
    > "${vg_d}/h.hex"
  if (
    set -x
    # shellcheck disable=SC3045
    ulimit -n 384 > /dev/null 2>&1 || :
    "${MAKE:-make}" CFLAGS="-O1 -g" \
      && "${MAKE:-make}" CFLAGS="-O1 -g" test_expr \
      && valgrind --quiet --error-exitcode=99 --leak-check=full \
        ./asm -z -o "${vg_d}/z.com" -l "${vg_d}/z.lst" \
        tests/insn8080.asm > /dev/null \
      && valgrind --quiet --error-exitcode=99 --leak-check=full \
        ./asm -p -o "${vg_d}/p.com" -l "${vg_d}/p.lst" \
        tests/macro.asm > /dev/null \
      && valgrind --quiet --error-exitcode=99 --leak-check=full \
        ./test_expr > /dev/null \
      && valgrind --quiet --error-exitcode=99 --leak-check=full \
        ./hexcom "${vg_d}/h" > /dev/null
  ); then
    :
  else
    printf '%s\n' "****** FAILURE DETECTED ******"
    rc=1
  fi
  rm -rf "${vg_d}" || :
}

################################################################################

case "$(uname -s 2> /dev/null || :)" in
NetBSD)
  if command -p -v lint > /dev/null 2>&1; then
    printf '\n%s\n\n' ">>>>>>>>>>>>>>>> NetBSD lint <<<<<<<<<<<<<<<<"
    if (
      set -x
      lint -a -aa -b -c -e -g -h -P -r -u -w -z ./src/lex.c
    ); then
      :
    else
      printf '%s\n' "****** FAILURE DETECTED ******"
      rc=1
    fi
    if (
      set -x
      lint -a -aa -b -c -e -g -h -P -r -u -w -z ./src/main.c
    ); then
      :
    else
      printf '%s\n' "****** FAILURE DETECTED ******"
      rc=1
    fi
    if (
      set -x
      lint -a -aa -b -c -e -g -h -P -r -u -w -z ./src/sym.c
    ); then
      :
    else
      printf '%s\n' "****** FAILURE DETECTED ******"
      rc=1
    fi
    if (
      set -x
      lint -a -aa -b -c -e -g -h -P -r -u -w -z ./test_expr.c
    ); then
      :
    else
      printf '%s\n' "****** FAILURE DETECTED ******"
      rc=1
    fi
    if (
      set -x
      lint -a -aa -b -c -e -g -h -P -r -u -w -z ./src/assemble.c
    ); then
      :
    else
      printf '%s\n' "****** FAILURE DETECTED ******"
      rc=1
    fi
    if (
      set -x
      lint -a -aa -b -c -e -g -h -P -r -u -w -z ./src/expr.c
    ); then
      :
    else
      printf '%s\n' "****** FAILURE DETECTED ******"
      rc=1
    fi
    if (
      set -x
      lint -a -aa -b -c -e -g -h -P -r -u -w -z ./src/hexcom.c
    ); then
      :
    else
      printf '%s\n' "****** FAILURE DETECTED ******"
      rc=1
    fi
    if (
      set -x
      lint -a -aa -b -c -e -g -h -P -r -u -w -z ./src/insn.c
    ); then
      :
    else
      printf '%s\n' "****** FAILURE DETECTED ******"
      rc=1
    fi
  fi
  ;;
*) : ;;
esac

################################################################################

if [ "${rc}" = 0 ]; then
  "${MAKE:-make}" distclean > /dev/null 2>&1 || :
  printf '\n%s\n\n' ">>>>>>>>>>>>>>>> lint SUCCESSFUL <<<<<<<<<<<<<<<<"
else
  printf '\n%s\n\n' ">>>>>>>>>>>>>>>> lint FAILED!!!! <<<<<<<<<<<<<<<<"
fi

exit "${rc}"

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
