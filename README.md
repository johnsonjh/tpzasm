<!-- TPZASM: TDL ZASM / PSA PASM compatible assembler - README.md -->
<!-- Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com> -->
<!-- SPDX-License-Identifier: MIT-0 -->
<!-- scspell-id: 76c2d6a6-6334-11f1-84fe-246e96298730 -->

# TPZASM

**TPZASM** is a portable cross‑assembler intended to be fully interchangeable
(and bug‑compatible) with the **TDL&nbsp;ZASM&nbsp;2.21** and
**PSA&nbsp;PASM&nbsp;1.02** assemblers, targeting the Intel&nbsp;**8080**,
Zilog&nbsp;**Z80**, and other equivalent processors.

**TPZASM** is ***not*** related to the similarly named
[Cromemco](https://en.wikipedia.org/wiki/Cromemco) ZASM or
[Megatokio](https://github.com/Megatokio)
[zasm](https://github.com/Megatokio/zasm) assemblers, nor Z80ASM from
SLR Systems.

## Portability

**TPZASM** should compile cleanly on any system with an ANSI&nbsp;C89 compiler.
Linux, AIX, OS/400, Solaris, illumos, FreeBSD, NetBSD, OpenBSD,
DragonFly&nbsp;BSD, Haiku, MS‑DOS, OS/2, and Windows are known to work
without modification.

The GNU&nbsp;GCC, LLVM&nbsp;Clang, PCC, NVIDIA&nbsp;HPC&nbsp;SDK&nbsp;C/C++,
Oracle&nbsp;Studio&nbsp;C/C++, DMD&nbsp;ImportC, CompCert&nbsp;C, Open64,
PathScale&nbsp;EKOPath, IBM&nbsp;XL&nbsp;C/C++, DJGPP,
IBM&nbsp;Open&nbsp;XL&nbsp;C/C++, Open&nbsp;Watcom&nbsp;V2, and МЦСТ&nbsp;LCC
compilers are regularly tested.

## Status

* **`TPZASM`** is \~**90%** complete relative to **TDL&nbsp;ZASM&nbsp;2.21**
  and **PSA&nbsp;PASM&nbsp;1.02**.  It is fully dialect‑faithful and can
  assemble the substantial (\~30,000 SLOC)
  [VEDIT‑PLUS](https://github.com/johnsonjh/VEDIT) codebase, producing
  byte‑for‑byte identical output to the reference assemblers.
  * Remaining known differences are mostly cosmetic issues in the generated
    listings, and error‑handling behavior has only been lightly verified.
* **`HEXCOM`** is **100%** complete and produces byte‑for‑byte identical
  output to the original reference tool, with matching messages and identical
  error‑handling semantics, plus user‑configurable control of output padding.

## Future

* Another variant, **PSA&nbsp;PASM&nbsp;2.00G** (possibly a beta release),
  is also known, though no documentation for it seems to have survived.
  Its behavior has not yet been analyzed for emulation by **TPZASM**, but
  this is planned for a future release.  The **PSA&nbsp;PASM&nbsp;2.00G**
  binary has been verified to assemble VEDIT‑PLUS identically to
  **PSA&nbsp;PASM&nbsp;1.02** and **TDL&nbsp;ZASM&nbsp;2.21**.
* Support for additional output formats (*i.e.*, HEX and relocatable object
  module formats) is also planned for a future release.

## Reference

* The [`orig/`](orig) directory contains the original CP/M‑80 executables.
* The [`docs/`](docs) directory contains PDF documentation for the assemblers
  (directly applicable to **TPZASM**).

## License

* The **TPZASM** software is distributed under the terms of the permissive
  [MIT&nbsp;No&nbsp;Attribution&nbsp;(MIT‑0)](LICENSE) license.

* The `ZASM` assembler and its accompanying documentation are © 1976‑1977
  [Technical Design Labs, Inc.](https://en.wikipedia.org/wiki/Technical_Design_Labs),
  with all rights acquired by Phoenix Software Associates, Ltd.

* The `PASM` assembler and its accompanying documentation are © 1980‑1981
  [Phoenix Software Associated, Ltd.](https://en.wikipedia.org/wiki/Phoenix_Technologies),
  now [Phoenix Technologies, Ltd](https://phoenixtech.com/).

* The `HEXCOM` utility is © 1982
  [Digital Research, Inc.](https://en.wikipedia.org/wiki/Digital_Research),
  with all rights acquired by
  [DRDOS, Inc. dba DeviceLogics LLC.](https://en.wikipedia.org/wiki/DeviceLogics).

<!--
Local Variables:
mode: markdown
indent-tabs-mode: nil
fill-column: 80
eval: (setq-local display-fill-column-indicator-column 80)
eval: (display-fill-column-indicator-mode 1)
End:
-->

<!-- vim: set ft=markdown expandtab cc=80 : -->
<!-- EOF -->
