<!-- TPZASM: TDL ZASM / PSA PASM compatible assembler - README.md -->
<!-- Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com> -->
<!-- SPDX-License-Identifier: MIT-0 -->
<!-- scspell-id: 76c2d6a6-6334-11f1-84fe-246e96298730 -->

# TPZASM

* **TPZASM** is a portable cross‑assembler intended to be fully interchangeable
  (and in most cases bug‑for‑bug compatible) with the
  **TDL&nbsp;ZASM&nbsp;2.21** and **PSA&nbsp;PASM&nbsp;1.02** assemblers,
  targeting the Intel&nbsp;**8080**, Zilog&nbsp;**Z80**, and other
  equivalent processors.

* An enhanced clone of **`HEXCOM`** 3.00, the DRI
  [Intel HEX](https://en.wikipedia.org/wiki/Intel_HEX) to binary conversion
  tool, is also included.

---

<!-- toc -->

- [Portability](#portability)
- [Status](#status)
- [Future](#future)
- [Notes](#notes)
- [Reference](#reference)
- [License](#license)

<!-- tocstop -->

---

## Portability

* **TPZASM** should compile cleanly on any system with an
  ANSI&nbsp;C89 compiler.

  Linux, AIX, OS/400, Solaris, illumos, FreeBSD, NetBSD, OpenBSD,
  DragonFly&nbsp;BSD, Haiku, MS‑DOS, OS/2, and Windows are known to work
  without modification.

  The GNU&nbsp;GCC, LLVM&nbsp;Clang, PCC, NVIDIA&nbsp;HPC&nbsp;SDK&nbsp;C/C++,
  Oracle&nbsp;Studio&nbsp;C/C++, DMD&nbsp;ImportC, CompCert&nbsp;C, Open64,
  PathScale&nbsp;EKOPath, IBM&nbsp;XL&nbsp;C/C++, DJGPP,
  Microsoft&nbsp;Visual&nbsp;C/C++, IBM&nbsp;Open&nbsp;XL&nbsp;C/C++,
  Open&nbsp;Watcom&nbsp;V2, and МЦСТ&nbsp;LCC compilers are regularly tested.

## Status

* **`TPZASM`** is \~**99.8%** complete relative to **TDL&nbsp;ZASM&nbsp;2.21**
  and **PSA&nbsp;PASM&nbsp;1.02**.
[]()

[]()
  * It is a fully faithful reimplementation of both assemblers (including their
    bugs) that can assemble many substantial historical codebases, including:
    * [Zapple&nbsp;Monitor](https://en.wikipedia.org/wiki/Zapple_Monitor)
      (\~2,500 SLOC)
    * [Burke&nbsp;Disassembler](tests/dis.asm) (\~2,200 SLOC)
    * [Alloy](tests/ittl.asm) [Engineering](tests/atu4.asm)
      [Utilities](tests/mtu4.asm) (\~2,800 SLOC)
    * [VEDIT‑PLUS](https://github.com/johnsonjh/VEDIT) (\~30,000 SLOC)
    * [DMS/3&nbsp;/&nbsp;DMS/4&nbsp;HiNet&nbsp;CP/M&nbsp;BIOS](tests/bios.asm)
      (\~10,000 SLOC)
    * [SARGON](tests/sargon.asm) (\~3,500 SLOC)
    []()

    []()
    In every case, **TPZASM** produces identical listings as well as
    byte‑for‑byte identical object output when compared to the reference
    TDL/PSA assemblers.  The only differences are when processing
    *deliberately malformed* or specially crafted inputs (that cause the
    reference assemblers to abort or crash).
[]()

[]()
  * **TPZASM** can write the assembled output as a raw binary image, or as a
    **TDL&nbsp;Object&nbsp;Module** in relocatable `.PREL` or absolute
    Intel‑HEX module `.PABS` formats, serialized either as raw binary
    (using the `-R` flag, *i.e.*, `.PBIN`) or as ASCII‑hex text (using the `-X`
    flag, *i.e.*, `.PHEX`), all of which is byte‑for‑byte identical to the
    object output of the reference software.

* **`HEXCOM`** is **100%** complete and produces byte‑for‑byte identical
  output to the original reference tool, with matching messages and identical
  error‑handling semantics, plus user‑configurable control of output padding.

## Future

* Another **PASM** variant, **PSA&nbsp;PASM&nbsp;2.00G** (*likely* *a* *beta*
  *release*), is also known, though no documentation for it seems to have
  survived. Its assembly output seems to be byte‑for‑byte identical to
  **PSA&nbsp;PASM&nbsp;1.02** (with the same instruction encoding and the
  same relocatable object output) for all test inputs, but the listing format
  was completely overhauled.  It also exhibits several behaviors that are
  clearly bugs, such as sometimes omitting the symbol table from listings
  when certain macros are defined.  Support for emulation of its improved
  listing style (without the bugs) may be offered in a future release.

* An optional *extended error checking* mode may be added, possibly printing
  errors to the console even when the listing is written to a file, classifying
  errors or warnings by severity, and emitting new diagnostics the originals
  never supported, for example, warning when symbols longer than six
  characters would be silently truncated.

## Notes

* **TPZASM** is ***not*** related to the similarly named
  [Cromemco](https://en.wikipedia.org/wiki/Cromemco) ZASM or
  [Megato**kio**](https://github.com/Megatokio) ZASM assemblers.

## Reference

* The [`orig/`](orig) directory contains the original CP/M‑80 executables.

* The [`docs/`](docs) directory contains PDF‑format documentation for the
  assemblers (directly applicable to **TPZASM**) and the book
  **Z‑80&nbsp;assembly&nbsp;language&nbsp;under&nbsp;TurboDOS** by
  R.&nbsp;Roger&nbsp;Breton (an excellent TDL assembly resource).

## License

* The **TPZASM** software is distributed under the terms of the permissive
  [MIT&nbsp;No&nbsp;Attribution&nbsp;(MIT‑0)](LICENSE) license.

* The `ZASM` assembler and its accompanying documentation are © 1976‑1977
  [Technical&nbsp;Design&nbsp;Labs,&nbsp;Inc.](https://en.wikipedia.org/wiki/Technical_Design_Labs),
  with all rights acquired by Phoenix&nbsp;Software&nbsp;Associates,&nbsp;Ltd.

* The `PASM` assembler and its accompanying documentation are © 1980‑1981
  [Phoenix Software Associates,&nbsp;Ltd.](https://en.wikipedia.org/wiki/Phoenix_Technologies),
  now [Phoenix&nbsp;Technologies,&nbsp;Ltd.](https://phoenixtech.com/)

* The `HEXCOM` utility is © 1982
  [Digital&nbsp;Research,&nbsp;Inc.](https://en.wikipedia.org/wiki/Digital_Research),
  with all rights acquired by
  [DRDOS,&nbsp;Inc.&nbsp;dba&nbsp;DeviceLogics&nbsp;LLC.](https://en.wikipedia.org/wiki/DeviceLogics)

* The book **Z‑80&nbsp;assembly&nbsp;language&nbsp;under&nbsp;TurboDOS**
  is © 1984, 1987, 1990, 2003, 2009 R.&nbsp;Roger&nbsp;Breton and distributed
  with permission under the terms and conditions of the
  [Personal‑Use and Distribution License](LICENSES/LicenseRef-ZALUT.txt).

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
