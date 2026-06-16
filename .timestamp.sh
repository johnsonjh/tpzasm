#!/bin/sh
# TPZASM: TDL ZASM / PSA PASM compatible assembler - .timestamp.sh
# Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
# SPDX-License-Identifier: MIT-0
# scspell-id: 0e0ef32c-69cb-11f1-8ef1-80ee73e9b8e7

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

# shellcheck disable=SC2065
test -d "./src" > /dev/null 2>&1 || {
  printf '%s\n' "ERROR: Could not locate ./src in current directory."
  exit 1
}

################################################################################

export CPE1704TKS=1

# shellcheck disable=SC1091
. ./.common.sh

################################################################################

export FIND_COMMAND_FATAL=1
find_command head ls test touch

################################################################################

# shellcheck disable=SC2012
newest=$(ls -t ./src 2> /dev/null | head -n 1)
[ -z "${newest:?}" ] && exit 0

################################################################################

newest="./src/${newest:?}"
for f in ./src/*; do
  [ "${f:?}" = "${newest:?}" ] && continue
  [ -f "${f:?}" ] || continue
  touch -r "${newest:?}" "${f:?}"
done

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
