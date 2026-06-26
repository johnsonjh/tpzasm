#!/bin/sh
# TPZASM: TDL ZASM / PSA PASM compatible assembler - .bindist.sh
# Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
# SPDX-License-Identifier: MIT-0
# scspell-id: d8b0be40-6ac4-11f1-97f2-80ee73e9b8e7

################################################################################

# For use by the maintainer only - not the general public.
# This script requires GNU coreutils `du` to work correctly.

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

if [ "${DU:-}x" = "x" ]; then
  DU="$(command -v du 2> /dev/null || printf '%s\n' 'du')"
fi

################################################################################

MAKE="${MAKE:-make}"

##############################################################################

CWSDSTUB="${CWSDSTUB:-/opt/cwspdmi/cwsdstub.exe}"
DJGPPGCC="${DJGPPGCC:-/opt/djgpp/bin/i586-pc-msdosdjgpp-gcc}"
EXE2COFF="${EXE2COFF:-/opt/djgpp/i586-pc-msdosdjgpp/bin/exe2coff}"

##############################################################################

test -f "${CWSDSTUB:?}" \
  || {
    printf '%s\n' "ERROR: ${CWSDSTUB:?} not found."
    exit 1
  }

##############################################################################

WATCOM="${WATCOM:-/opt/watcom}"
export WATCOM

##############################################################################

CROSSMINT="${HOME:?}/crossmint"
CROSSMINT_ARCH="${CROSSMINT:?}/usr/m68k-atari-mintelf"
CROSSMINT_GCC="${CROSSMINT:?}/usr/bin/m68k-atari-mintelf-gcc"

##############################################################################

export VBCC=/opt/vbcc
export PATH="${VBCC:?}/bin:${PATH:-}"

##############################################################################

export FIND_COMMAND_FATAL=0

if out=$(
  # shellcheck disable=SC2310
  find_command sstrip 2>&1
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

##############################################################################

export FIND_COMMAND_FATAL=1

find_command "${AWK:-awk}" "${CROSSMINT_GCC:?}" "${DJGPPGCC:?}" "${DU:?}" \
  "${EXE2COFF:?}" "${MAKE:?}" "${WATCOM:?}/binl64/owcc" advzip ./asm cat cp \
  docker grep i686-w64-mingw32-gcc lha mkdir musl-gcc mkdir mv pigz rm sed \
  sleep strip tar upx x86_64-w64-mingw32ucrt-gcc zip cranker \
  "${VBCC:?}/bin/vc"

################################################################################

"${DU:?}" --version 2>&1 | grep -q 'GNU coreutils' 2> /dev/null \
  || {
    printf '%s\n' "ERROR: '${DU:?}' is not GNU coreutils du."
    exit 1
  }

################################################################################

if [ ! -d "bindist" ] || [ ! -f "README.md" ]; then
  printf '%s\n' "ERROR: No bindist/ and/or README.md found!" >&2
  exit 1
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
    "Some steps will be skipped! [pausing ${OVERRIDE_PAUSE:-10}s]" \
    | wrap "${width:?}"
  sleep "${OVERRIDE_PAUSE:-10}"
}

################################################################################

USAGE="$(./asm -h 2>&1)"

################################################################################

# shellcheck disable=SC2119
TMP_README="$(mktemp 2> /dev/null || mktemp_local)"
# shellcheck disable=SC2119
SED_README="$(mktemp 2> /dev/null || mktemp_local)"

##############################################################################

set -eux

:
################################################################################
: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: :
################################################################################
:

# MS-DOS (DJGPP) build

rm -f ./pasm ./zasm ./hexcom.exe ./asm.exe ./TPZASM86.ZIP > /dev/null 2>&1

"${MAKE:?}" distclean CC="${DJGPPGCC:?}"
"${MAKE:?}" CC="${DJGPPGCC:?}" LDFLAGS="-s"

rm -f ./pasm ./zasm > /dev/null 2>&1

"${EXE2COFF:?}" ./hexcom.exe && rm -f ./hexcom.exe
"${EXE2COFF:?}" ./asm.exe && rm -f ./asm.exe

cat "${CWSDSTUB:?}" ./hexcom > ./hexcom.exe && rm -f ./hexcom
cat "${CWSDSTUB:?}" ./asm > ./asm.exe && rm -f ./asm

(upx -q --best ./hexcom.exe ./asm.exe 2> /dev/null \
  | grep ' \-> ' 2> /dev/null) || :

zip -0 -X -D -j ./TPZASM86.ZIP hexcom.exe asm.exe
rm -f ./hexcom.exe ./asm.exe
advzip -z4 ./TPZASM86.ZIP

:
################################################################################
: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: :
################################################################################
:

# Linux (32-bit) build (Open Watcom V2)

rm -f -r ./tpzasm ./tpzasm-linux32.tar* > /dev/null 2>&1
mkdir -p ./tpzasm

"${MAKE:?}" distclean CC="${WATCOM:?}/binl64/owcc"
env \
  INCLUDE="${WATCOM:?}/lh:/usr/include" \
  PATH="${WATCOM:?}/binl64:${PATH:-}" \
  "${MAKE:?}" \
  CC="${WATCOM:?}/binl64/owcc" \
  CFLAGS="-D__linux__ -blinux -std=c89 -march=i386 -Wall -Wextra -g0 -O3 \
  -frerun-optimizer -mstack-size=1024k -fgrow-stack" \
  LDFLAGS="-blinux"

rm -f ./pasm ./zasm > /dev/null 2>&1

strip --strip-all ./hexcom
sstrip -z ./hexcom > /dev/null 2>&1 || :

strip --strip-all ./asm
sstrip -z ./asm > /dev/null 2>&1 || :

mv -f ./hexcom ./asm ./tpzasm/

tar cf ./tpzasm-linux32.tar tpzasm
pigz -11v ./tpzasm-linux32.tar

rm -f -r ./tpzasm > /dev/null 2>&1

:
################################################################################
: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: :
################################################################################
:

# OS/2 (32-bit) build (Open Watcom V2)

OS2OLD="This is an OS/2 32-bit executable"
OS2TPZ="This TPZASM requires 32-bit OS/2."
OS2HEX="This HEXCOM requires 32-bit OS/2."

rm -f ./pasm ./zasm ./asm.exe ./hexcom.exe ./TPZASMO2.ZIP > /dev/null 2>&1

"${MAKE:?}" distclean CC="${WATCOM:?}/binl64/owcc"
env \
  INCLUDE="${WATCOM:?}/h" \
  PATH="${WATCOM:?}/binl64:${PATH:-}" \
  LIBPATH="${WATCOM:?}/binp/dll:${LIBPATH:-}" \
  "${MAKE:?}" \
  CC="${WATCOM:?}/binl64/owcc" \
  CFLAGS="-bos2v2 -std=c89 -march=i386 -Wall -Wextra -g0 -O3 \
  -frerun-optimizer -mstack-size=512k -fgrow-stack" \
  LDFLAGS="-bos2v2"
rm -f ./pasm ./zasm > /dev/null 2>&1

sed "s|${OS2OLD:?}|${OS2TPZ:?}|" ./asm > ./asm.exe && rm -f ./asm
sed "s|${OS2OLD:?}|${OS2HEX:?}|" ./hexcom > ./hexcom.exe && rm -f ./hexcom

zip -0 -X -D -j ./TPZASMO2.ZIP hexcom.exe asm.exe
rm -f ./hexcom.exe ./asm.exe
advzip -z4 ./TPZASMO2.ZIP

:
################################################################################
: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: :
################################################################################
:

# Linux (64-bit) build (musl-gcc, assumes a 64-bit Linux host)

rm -f -r ./pasm ./zasm ./hexcom ./asm ./tpzasm ./tpzasm-linux64.tar* \
  > /dev/null 2>&1
mkdir -p ./tpzasm

"${MAKE:?}" distclean CC="musl-gcc"
"${MAKE:?}" CC="musl-gcc" LDFLAGS="-s -static"

rm -f ./pasm ./zasm > /dev/null 2>&1

strip --strip-all ./hexcom
sstrip -z ./hexcom > /dev/null 2>&1 || :

strip --strip-all ./asm
sstrip -z ./asm > /dev/null 2>&1 || :

(upx -q --best ./hexcom ./asm 2> /dev/null \
  | grep ' \-> ' 2> /dev/null) || :

mv -f ./hexcom ./asm ./tpzasm/

tar cf ./tpzasm-linux64.tar tpzasm
pigz -11v ./tpzasm-linux64.tar

rm -f -r ./tpzasm > /dev/null 2>&1

:
################################################################################
: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: :
################################################################################
:

# Windows (32-bit MSVCRT) build (MinGW-w64)

rm -f -r ./pasm ./zasm ./hexcom.exe ./asm.exe ./TPZASM32.ZIP > /dev/null 2>&1

"${MAKE:?}" distclean CC="i686-w64-mingw32-gcc"
"${MAKE:?}" CC="i686-w64-mingw32-gcc" LDFLAGS="-s"

rm -f ./pasm ./zasm > /dev/null 2>&1

(upx -q --best ./hexcom.exe ./asm.exe 2> /dev/null \
  | grep ' \-> ' 2> /dev/null) || :

zip -0 -X -D -j ./TPZASM32.ZIP hexcom.exe asm.exe
rm -f ./hexcom.exe ./asm.exe
advzip -z4 ./TPZASM32.ZIP

:
################################################################################
: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: :
################################################################################
:

# Windows (64-bit UCRT) build (MinGW-w64)

rm -f -r ./pasm ./zasm ./hexcom.exe ./asm.exe ./TPZASM64.ZIP > /dev/null 2>&1

"${MAKE:?}" distclean CC="x86_64-w64-mingw32ucrt-gcc"
"${MAKE:?}" CC="x86_64-w64-mingw32ucrt-gcc" LDFLAGS="-s"

rm -f ./pasm ./zasm > /dev/null 2>&1

(upx -q --best ./hexcom.exe ./asm.exe 2> /dev/null \
  | grep ' \-> ' 2> /dev/null) || :

zip -0 -X -D -j ./TPZASM64.ZIP hexcom.exe asm.exe
rm -f ./hexcom.exe ./asm.exe
advzip -z4 ./TPZASM64.ZIP

:
################################################################################
: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: :
################################################################################
:

# Atari TOS/MINT build (using CROSSMiNT)

rm -f -r ./pasm ./zasm ./hexcom.ttp ./asm.ttp ./TPZASMST.LZH > /dev/null 2>&1

"${MAKE:?}" distclean CC="${CROSSMINT_GCC:?}"
env PATH="${CROSSMINT_ARCH:?}/bin:${CROSSMINT_ARCH:?}/usr/bin:${PATH:-}" \
  LDFLAGS="-s" \
  "${MAKE:?}" \
  CC="${CROSSMINT_GCC:?} -mfastcall"

rm -f ./pasm ./zasm > /dev/null 2>&1

mv -f asm asm.ttp
mv -f hexcom hexcom.ttp

(upx -q --best ./hexcom.ttp ./asm.ttp 2> /dev/null \
  | grep ' \-> ' 2> /dev/null) || :

lha -c -z -0 TPZASMST.LZH hexcom.ttp asm.ttp
rm -f ./hexcom.ttp ./asm.ttp

:
################################################################################
: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: :
################################################################################
:

# Linux ARM (32-bit) build (Docker)

rm -f -r ./pasm ./zasm ./hexcom ./asm ./tpzasm ./tpzasm-linuxarm32.tar* \
  hexcom.out asm.out > /dev/null 2>&1
mkdir -p ./tpzasm

docker run --rm -v "$(pwd -P || :)":/src -w /src \
  dockcross/linux-armv5-musl sh -xc 'make distclean && make \
CC=/usr/xcc/armv5-unknown-linux-musleabi/bin/armv5-unknown-linux-musleabi-gcc \
LDFLAGS="-s -static" && \
/usr/xcc/armv5-unknown-linux-musleabi/bin/armv5-unknown-linux-musleabi-strip \
--strip-all asm hexcom'

rm -f ./pasm ./zasm > /dev/null 2>&1

cp -f hexcom hexcom.out
rm -f hexcom
mv -f hexcom.out hexcom

sstrip -z ./hexcom > /dev/null 2>&1 || :

cp -f asm asm.out
rm -f asm
mv -f asm.out asm

sstrip -z ./asm > /dev/null 2>&1 || :

(upx -q --best ./hexcom ./asm 2> /dev/null \
  | grep ' \-> ' 2> /dev/null) || :

mv -f ./hexcom ./asm ./tpzasm/

tar cf ./tpzasm-linuxarm32.tar tpzasm
pigz -11v ./tpzasm-linuxarm32.tar

rm -f -r ./tpzasm > /dev/null 2>&1

:
################################################################################
: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: :
################################################################################
:

# Linux ARM (64-bit) build (Docker)

rm -f -r ./pasm ./zasm ./hexcom ./asm ./tpzasm ./tpzasm-linuxarm64.tar* \
  hexcom.out asm.out > /dev/null 2>&1
mkdir -p ./tpzasm

docker run --rm -v "$(pwd -P || :)":/src -w /src \
  dockcross/linux-arm64-musl sh -xc 'make distclean && make \
CC=/usr/xcc/aarch64-linux-musl-cross/bin/aarch64-linux-musl-gcc \
LDFLAGS="-s -static" && \
/usr/xcc/aarch64-linux-musl-cross/bin/aarch64-linux-musl-strip \
--strip-all asm hexcom'

rm -f ./pasm ./zasm > /dev/null 2>&1

cp -f hexcom hexcom.out
rm -f hexcom
mv -f hexcom.out hexcom

sstrip -z ./hexcom > /dev/null 2>&1 || :

cp -f asm asm.out
rm -f asm
mv -f asm.out asm

sstrip -z ./asm > /dev/null 2>&1 || :

(upx -q --best ./hexcom ./asm 2> /dev/null \
  | grep ' \-> ' 2> /dev/null) || :

mv -f ./hexcom ./asm ./tpzasm/

tar cf ./tpzasm-linuxarm64.tar tpzasm
pigz -11v ./tpzasm-linuxarm64.tar

rm -f -r ./tpzasm > /dev/null 2>&1

:
################################################################################
: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: :
################################################################################
:

# AmigaOS (68020)

rm -f -r ./pasm ./zasm ./hexcom ./asm ./TPZASMAM.LHA > /dev/null 2>&1

"${MAKE:?}" distclean CC="${CROSSMINT_GCC:?}"
"${MAKE:?}" CC=vc CFLAGS="+aos68k -cpu=68020 -c89 -no-trigraphs -speed -O3 \
  -maxoptpasses=1 -dontwarn=172" LDFLAGS="-final"

cranker -f hexcom -o hexcom.out -d minimal
mv -f hexcom.out hexcom

cranker -f asm -o asm.out -d minimal
mv -f asm.out asm

lha -c -z -0 TPZASMAM.LHA hexcom asm
rm -f ./hexcom ./asm

:
################################################################################
: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: :
################################################################################
:

mkdir -p ./bindist

mv -f ./TPZASMO2.ZIP ./bindist
mv -f ./TPZASM86.ZIP ./bindist
mv -f ./TPZASM64.ZIP ./bindist
mv -f ./TPZASM32.ZIP ./bindist
mv -f ./TPZASMST.LZH ./bindist
mv -f ./TPZASMAM.LHA ./bindist
mv -f ./tpzasm-linux64.tar.gz ./bindist
mv -f ./tpzasm-linux32.tar.gz ./bindist
mv -f ./tpzasm-linuxarm64.tar.gz ./bindist
mv -f ./tpzasm-linuxarm32.tar.gz ./bindist

:
################################################################################
: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: :
################################################################################
:

set +x

################################################################################

SIZES="$("${DU:?}" -Sh --block-size=KiB bindist/*)"

################################################################################

sed 's|[0-9]\+&nbsp;KiB|00\&nbsp;KiB|' README.md > "${SED_README}"
mv -f "${SED_README}" README.md

################################################################################

# shellcheck disable=SC2016
"${AWK:-awk}" -v sizes_raw="${SIZES}" -v usage_raw="${USAGE}" '
BEGIN {
  FS = "|"
  OFS = "|"

  n = split(sizes_raw, lines, "\n")

  for (i = 1; i <= n; i++) {
    if (lines[i] == "") continue

    split(lines[i], parts, /[ \t]+/)
    sz = parts[1]
    pth = parts[2]

    fname = pth
    sub(/.*\//, "", fname)

    sub(/KiB/, "\\&nbsp;KiB", sz)

    file_sizes[fname] = sz
  }
}

{
  if ($0 ~ /^```$/) {
    if (in_block == 0 && usage_done == 0) {
      in_block = 1
      print $0
      print usage_raw
      next
    } else if (in_block == 1) {
      in_block = 0
      print $0
      usage_done = 1
      next
    }
  }

  if (in_block == 1) {
    next
  }

  if ($0 ~ /^\|.*\[.*\]\(.*\).*\|.*\|/) {
    m_start = index($2, "[")
    m_end = index($2, "]")

    if (m_start > 0 && m_end > m_start) {
        current_fname = substr($2, m_start + 1, m_end - m_start - 1)

        if (current_fname in file_sizes) {
            $3 = " " file_sizes[current_fname] " "
        }
    }
  }

  print $0
}
' "README.md" > "${TMP_README:?}"

################################################################################

mv -f "${TMP_README:?}" "README.md"

################################################################################

printf '%s\n' \
  "Successfully updated README.md with archive sizes and usage information."

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
