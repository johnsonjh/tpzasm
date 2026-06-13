<!-- TPZASM: TDL ZASM / PSA PASM compatible assembler - README.md -->
<!-- Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com> -->
<!-- SPDX-License-Identifier: MIT-0 -->
<!-- scspell-id: 76c2d6a6-6334-11f1-84fe-246e96298730 -->

# TPZASM

* **TPZASM** is a portable cross‑assembler intended to be fully interchangeable
  (and bug‑compatible) with the **TDL&nbsp;ZASM&nbsp;2.21** and
  **PSA&nbsp;PASM&nbsp;1.02** assemblers, targeting the Intel&nbsp;**8080**,
  Zilog&nbsp;**Z80**, and other equivalent processors.

* An enhanced clone of `HEXCOM`, the DRI
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

* **`TPZASM`** is \~**99%** complete relative to **TDL&nbsp;ZASM&nbsp;2.21**
  and **PSA&nbsp;PASM&nbsp;1.02**.  It is fully dialect‑faithful and can
  assemble the substantial (\~30,000 SLOC)
  [VEDIT‑PLUS](https://github.com/johnsonjh/VEDIT) and (\~3,500 SLOC)
  [SARGON](tests/sargon.asm) codebases, producing byte‑for‑byte identical
  output to the reference TDL/PSA assemblers.

  * The standalone test corpus is byte‑for‑byte identical to both originals
    in **both** the object output and the **listing**, for **both** dialects.
    Error handling now reproduces the originals' lettered error codes (a
    column‑1 letter, the `?` marker at the fault, and the per‑page/trailing
    error count).  The remaining differences are a few listing details — the
    macro‑expansion display model, **`.LIMAGE`**/**`.PAGE`**/**`.COMMENT`**,
    a \~1‑line pagination residual on very large files, and a few deep
    error‑listing cases (the leading pass‑1 error page, symbol‑table error
    flags) — still being refined.

  * **TPZASM** implements the full **multi‑segment, relocatable, linkable**
    object model: the three program segments (**`.PROG.`**, **`.DATA.`**,
    **`.BLNK.`**) with `.LOC`/`.RELOC` segment switching and cross‑segment
    relocation, the predefined segment‑base symbols, external symbols
    (**`.EXTERN`**, with 16‑ and 8‑bit references), and the entry/internal
    symbol records (**`.ENTRY`**, **`.INTERN`**, **`.IDENT`**).  It also
    implements multi‑module *library file generation* (**`.PRGEND`**): each
    module is assembled as its own independent two‑pass unit and emits its own
    object record framing.  All of this is byte‑for‑byte identical to
    **PSA&nbsp;PASM&nbsp;1.02** (and, less the program‑id record, to
    **TDL&nbsp;ZASM&nbsp;2.21**).

  * **TPZASM** can write the assembled output as a raw binary image, or as a
    **TDL&nbsp;Object&nbsp;Module** in relocatable (`.PREL`) or an absolute
    Intel‑HEX module (`.PABS`) formats, serialized either as raw binary
    (the `-R` flag, *i.e.* `.PBIN`) or as ASCII‑hex text (the `-X` flag,
    *i.e.* `.PHEX`), which is byte‑for‑byte identical to the object output of
    **PSA&nbsp;PASM&nbsp;1.02**.

* **`HEXCOM`** is **100%** complete and produces byte‑for‑byte identical
  output to the original reference tool, with matching messages and identical
  error‑handling semantics, plus user‑configurable control of output padding.

## Future

* A few **listing** edges remain before the listing is byte‑for‑byte identical
  on *every* input: a multi‑word **`.WORD`** under **`.LIMAGE`** in the ZASM
  dialect (the TDL two‑word value‑field overstrike), a \~1‑line pagination
  residual on very large files, and a few deep error‑listing cases (the leading
  pass‑1 error‑summary page and the symbol‑table error flags).

* Another **PASM** variant, **PSA&nbsp;PASM&nbsp;2.00G** (*likely* *a* *beta*
  *release*), is also known, though no documentation for it seems to have
  survived.

  Its behavior has now been analyzed: the assembly output seems byte‑for‑byte
  identical to **PSA&nbsp;PASM&nbsp;1.02** (same instruction encoding and the
  same relocatable object output); only the *listing* format was reworked
  (source line numbers, line truncation instead of wrapping, *likely a bug*,
  and a `=` value flag), and it exhibits several behaviors that are clearly
  bugs (*i.e.*, an unfilled date/time stamp, the symbol table is sometimes
  omitted from listings when certain macros are defined).

  Optional emulation of its improved listing style (without the disappearing
  symbol bugs) may be offered in a future release, but the well‑behaved
  **1.02** output currently remains the reference.

* An optional *extended error checking* mode may be added: echoing errors to
  the console even when the listing is written to a file, and emitting new,
  clone‑only diagnostics the originals never gave (for example, warning when a
  symbol longer than six characters is silently truncated).  It would be off by
  default so the standard output stays byte‑identical to the originals.

## Notes

* **TPZASM** is ***not*** related to the similarly named
  [Cromemco](https://en.wikipedia.org/wiki/Cromemco) ZASM,
  [Megatokio](https://github.com/Megatokio) ZASM,
  SLR Systems Z80ASM, or [Pasmo](https://pasmo.speccy.org) Z80 assemblers.

## Reference

* The [`orig/`](orig) directory contains the original CP/M‑80 executables.

* The [`docs/`](docs) directory contains PDF‑format documentation for the
  assemblers (directly applicable to **TPZASM**).

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
