#!/bin/sh
# TPZASM: TDL ZASM / PSA PASM compatible assembler - .bindist.sh
# Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
# SPDX-License-Identifier: MIT-0
# scspell-id: ff19430a-6ac3-11f1-8ca0-80ee73e9b8e7

##############################################################################

# TODO: Use .common.sh tool detection framework

##############################################################################

set -eux

##############################################################################

MAKE="${MAKE:-make}"
command -v "${MAKE:?}"

CWSDSTUB="${CWSDSTUB:-/opt/cwspdmi/cwsdstub.exe}"
test -f "${CWSDSTUB:?}"

DJGPPGCC="${DJGPPGCC:-/opt/djgpp/bin/i586-pc-msdosdjgpp-gcc}"
test -x "${DJGPPGCC:?}"

EXE2COFF="${EXE2COFF:-/opt/djgpp/i586-pc-msdosdjgpp/bin/exe2coff}"
test -x "${EXE2COFF:?}"

WATCOM="${WATCOM:-/opt/watcom}"
test -d "${WATCOM:?}"
export WATCOM

##############################################################################
: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: :
##############################################################################

# MS-DOS (DJGPP) build

rm -f ./pasm ./zasm ./hexcom.exe ./asm.exe ./TPZASM86.ZIP > /dev/null 2>&1

"${MAKE:?}" distclean CC="${DJGPPGCC:?}"
"${MAKE:?}" CC="${DJGPPGCC:?}" LDFLAGS="-s"

rm -f ./pasm ./zasm > /dev/null 2>&1

"${EXE2COFF:?}" ./hexcom.exe && rm -f ./hexcom.exe
"${EXE2COFF:?}" ./asm.exe && rm -f ./asm.exe

cat "${CWSDSTUB:?}" ./hexcom > ./hexcom.exe && rm -f ./hexcom
cat "${CWSDSTUB:?}" ./asm > ./asm.exe && rm -f ./asm

(upx -q -9 ./hexcom.exe ./asm.exe 2> /dev/null \
  | grep ' \-> ' 2> /dev/null) || :

zip -0 -X -D -j ./TPZASM86.ZIP hexcom.exe asm.exe
rm -f ./hexcom.exe ./asm.exe
advzip -z4 ./TPZASM86.ZIP

##############################################################################
: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: :
##############################################################################

# Linux (32-bit) build (Open Watcom V2)

rm -f -r ./tpzasm ./tpzasm-linux32.tar* > /dev/null 2>&1
mkdir -p ./tpzasm

"${MAKE:?}" distclean CC="${WATCOM:?}/binl64/owcc"
env \
  INCLUDE="${WATCOM:?}/lh:/usr/include" \
  PATH="${WATCOM:?}/binl64:${PATH:-}" \
  "${MAKE:?}" \
  CC="${WATCOM:?}/binl64/owcc" \
  CFLAGS="-std=c89 -march=i386 -Wall -Wextra -g0 -O3 -frerun-optimizer" \
  LDFLAGS="-s -blinux"

rm -f ./pasm ./zasm > /dev/null 2>&1

strip --strip-all ./hexcom
sstrip -z ./hexcom > /dev/null 2>&1

strip --strip-all ./asm
sstrip -z ./asm > /dev/null 2>&1

mv -f ./hexcom ./asm ./tpzasm/

tar cf ./tpzasm-linux32.tar tpzasm
pigz -11v ./tpzasm-linux32.tar

rm -f -r ./tpzasm > /dev/null 2>&1

##############################################################################
: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: :
##############################################################################

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
  CFLAGS="-std=c89 -march=i386 -Wall -Wextra -g0 -O3 -mcmodel=f \
  -fno-stack-check -frerun-optimizer" \
  LDFLAGS="-s -bos2v2"
rm -f ./pasm ./zasm > /dev/null 2>&1

sed "s|${OS2OLD:?}|${OS2TPZ:?}|" ./asm > ./asm.exe && rm -f ./asm
sed "s|${OS2OLD:?}|${OS2HEX:?}|" ./hexcom > ./hexcom.exe && rm -f ./hexcom

zip -0 -X -D -j ./TPZASMO2.ZIP hexcom.exe asm.exe
rm -f ./hexcom.exe ./asm.exe
advzip -z4 ./TPZASMO2.ZIP

##############################################################################
: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: :
##############################################################################

# Linux (64-bit) build (musl-gcc, assumes a 64-bit Linux host)

rm -f -r ./pasm ./zasm ./hexcom ./asm ./tpzasm ./tpzasm-linux64.tar* \
  > /dev/null 2>&1
mkdir -p ./tpzasm

"${MAKE:?}" distclean CC="musl-gcc"
"${MAKE:?}" CC="musl-gcc" LDFLAGS="-s -static"

rm -f ./pasm ./zasm > /dev/null 2>&1

strip --strip-all ./hexcom
sstrip -z ./hexcom > /dev/null 2>&1

strip --strip-all ./asm
sstrip -z ./asm > /dev/null 2>&1

(upx -q -9 ./hexcom ./asm 2> /dev/null \
  | grep ' \-> ' 2> /dev/null) || :

mv -f ./hexcom ./asm ./tpzasm/

tar cf ./tpzasm-linux64.tar tpzasm
pigz -11v ./tpzasm-linux64.tar

rm -f -r ./tpzasm > /dev/null 2>&1

##############################################################################
: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: :
##############################################################################

# Windows (32-bit MSVCRT) build (MinGW-w64)

rm -f -r ./pasm ./zasm ./hexcom.exe ./asm.exe ./TPZASM32.ZIP > /dev/null 2>&1

"${MAKE:?}" distclean CC="i686-w64-mingw32-gcc"
"${MAKE:?}" CC="i686-w64-mingw32-gcc" LDFLAGS="-s"

rm -f ./pasm ./zasm > /dev/null 2>&1

(upx -q -9 ./hexcom.exe ./asm.exe 2> /dev/null \
  | grep ' \-> ' 2> /dev/null) || :

zip -0 -X -D -j ./TPZASM32.ZIP hexcom.exe asm.exe
rm -f ./hexcom.exe ./asm.exe
advzip -z4 ./TPZASM32.ZIP

##############################################################################
: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: :
##############################################################################

# Windows (64-bit UCRT) build (MinGW-w64)

rm -f -r ./pasm ./zasm ./hexcom.exe ./asm.exe ./TPZASM64.ZIP > /dev/null 2>&1

"${MAKE:?}" distclean CC="x86_64-w64-mingw32ucrt-gcc"
"${MAKE:?}" CC="x86_64-w64-mingw32ucrt-gcc" LDFLAGS="-s"

rm -f ./pasm ./zasm > /dev/null 2>&1

(upx -q -9 ./hexcom.exe ./asm.exe 2> /dev/null \
  | grep ' \-> ' 2> /dev/null) || :

zip -0 -X -D -j ./TPZASM64.ZIP hexcom.exe asm.exe
rm -f ./hexcom.exe ./asm.exe
advzip -z4 ./TPZASM64.ZIP

##############################################################################
: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: :
##############################################################################

mkdir -p ./bindist

mv -f ./TPZASMO2.ZIP ./bindist
mv -f ./TPZASM86.ZIP ./bindist
mv -f ./TPZASM64.ZIP ./bindist
mv -f ./TPZASM32.ZIP ./bindist
mv -f ./tpzasm-linux64.tar.gz ./bindist
mv -f ./tpzasm-linux32.tar.gz ./bindist

##############################################################################

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
