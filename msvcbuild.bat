:: TPZASM: TDL ZASM / PSA PASM compatible assembler - msvcbuild.bat
:: Copyright (c) 2026 Jeffrey H. Johnson - johnsonjh.dev@gmail.com
:: SPDX-License-Identifier: MIT-0
:: vim: set ft=dosbatch cc=80 :
:: scspell-id: 06806274-6662-11f1-bba9-80ee73e9b8e7

REM === Compile ASM ===
cl /Ob3 /GS- /Oi /O2 /W4 /wd4996 /Feasm.exe ^
  src/main.c src/expr.c src/sym.c src/lex.c src/insn.c ^
  src/assemble.c src/objout.c src/platform.c

REM === Compile HEXCOM ===
cl /Ob3 /GS- /Oi /O2 /W4 /wd4996 /Fehexcom.exe src/hexcom.c

:: Local Variables:
:: mode: bat-mode
:: fill-column: 80
:: eval: (setq-local display-fill-column-indicator-column 80)
:: eval: (display-fill-column-indicator-mode 1)
:: End:
