<!-- TPZASM: TDL ZASM / PSA PASM compatible assembler - README.md -->
<!-- Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com> -->
<!-- SPDX-License-Identifier: MIT-0 -->
<!-- scspell-id: 76c2d6a6-6334-11f1-84fe-246e96298730 -->

# TPZASM

**TPZASM** (*pronounceable as* «***Topaz Assembler***») is a portable
cross‑assembler intended to be fully interchangeable (and in most cases
bug‑for‑bug compatible) with the **TDL&nbsp;ZASM&nbsp;2.21** and
**PSA&nbsp;PASM&nbsp;1.02** assemblers, targeting the Intel&nbsp;**8080**,
Zilog&nbsp;**Z80**, and other equivalent processors.

An enhanced clone of **HEXCOM 3.00**, the DRI
[Intel&nbsp;HEX](https://en.wikipedia.org/wiki/Intel_HEX) to binary conversion
tool, is also included.

[Precompiled binaries for many systems are available for download.](#downloads)

---

<!-- toc -->

- [Usage](#usage)
- [Downloads](#downloads)
- [Building from source](#building-from-source)
  * [Portability](#portability)
- [Status](#status)
- [Notes](#notes)
  * [Developer notes](#developer-notes)
  * [Future plans](#future-plans)
    + [CDL MACRO emulation](#cdl-macro-emulation)
    + [PSA PASM 2.0 emulation](#psa-pasm-20-emulation)
- [Reference](#reference)
  * [Original binaries](#original-binaries)
  * [Original documentation](#original-documentation)
- [Security](#security)
- [License](#license)
  * [Third‑party materials](#third%E2%80%91party-materials)

<!-- tocstop -->

---

## Usage

```
TPZASM - TDL ZASM / PSA PASM compatible Z80 assembler (Linux/x86_64)
Release 0.83 (Built Jun 18 2026) https://github.com/johnsonjh/tpzasm
Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>

Usage: asm [options] <source[.asm]>

  Options:
    -z, --zasm            Emulate TDL ZASM 2.21 behavior [default]
    -p, --pasm            Emulate PSA PASM 1.02 behavior
    -o, --out <file>      Write the assembled binary image to <file>
    -P, --pad             Pad output to full CP/M record boundary
    -l, --list <file>     Write the listing to <file> [default: stderr]
    -R, --pbin <file>     Write the object module as binary TDL REL to <file>
    -X, --phex <file>     Write the object module as ASCII-hex REL to <file>
    -L, --long            Allow long (>6 character, non-standard) symbol names
    -r, --read <file>     Answer assembly-time prompts from <file>
    -i, --include <file>  Include <file> before processing <source[.asm]>
    -a, --prefix <expr>   Evaluate <expr> before processing <source[.asm]>
    -e, --expr <expr>     Evaluate only expression <expr> and exit
    -v, --version         Display version information and exit
    -h, --help            Display this help text and exit
```

**NOTE**: Invoking the assembler as `zasm` explicitly selects the
**TDL ZASM 2.21** emulation, and invoking it as `pasm` selects the
**PSA PASM 1.02** emulation.

## Downloads

|                                                                                                                  File  |         Size | Platform                             |
|-----------------------------------------------------------------------------------------------------------------------:|-------------:|:-------------------------------------|
| [TPZASM86.ZIP](https://github.com/johnsonjh/tpzasm/raw/refs/heads/master/bindist/TPZASM86.ZIP)                         | 188&nbsp;KiB | **MS‑DOS**&nbsp;(80386&nbsp;DPMI)    |
| [TPZASMO2.ZIP](https://github.com/johnsonjh/tpzasm/raw/refs/heads/master/bindist/TPZASMO2.ZIP)                         | 60&nbsp;KiB | **OS/2**&nbsp;(32‑bit&nbsp;i386)      |
| [TPZASM32.ZIP](https://github.com/johnsonjh/tpzasm/raw/refs/heads/master/bindist/TPZASM32.ZIP)                         | 64&nbsp;KiB | **Windows**&nbsp;(32‑bit&nbsp;MSVCRT) |
| [TPZASM64.ZIP](https://github.com/johnsonjh/tpzasm/raw/refs/heads/master/bindist/TPZASM64.ZIP)                         | 68&nbsp;KiB | **Windows**&nbsp;(64‑bit&nbsp;UCRT)   |
| [tpzasm-linuxarm32.tar.gz](https://github.com/johnsonjh/tpzasm/raw/refs/heads/master/bindist/tpzasm-linuxarm32.tar.gz) | 96&nbsp;KiB | **Linux**&nbsp;(32‑bit&nbsp;ARMv5)    |
| [tpzasm-linuxarm64.tar.gz](https://github.com/johnsonjh/tpzasm/raw/refs/heads/master/bindist/tpzasm-linuxarm64.tar.gz) | 108&nbsp;KiB | **Linux**&nbsp;(64‑bit&nbsp;ARMv8)   |
| [tpzasm-linux32.tar.gz](https://github.com/johnsonjh/tpzasm/raw/refs/heads/master/bindist/tpzasm-linux32.tar.gz)       | 56&nbsp;KiB | **Linux**&nbsp;(32‑bit&nbsp;i386)     |
| [tpzasm-linux64.tar.gz](https://github.com/johnsonjh/tpzasm/raw/refs/heads/master/bindist/tpzasm-linux64.tar.gz)       | 116&nbsp;KiB | **Linux**&nbsp;(64‑bit&nbsp;x86‑64)  |

## Building from source

**TPZASM** needs **only an ANSI C89 compiler** to build on any
UNIX‑like system.

* To build a native binary, just run `make` (or `gmake`):

  ```sh
  make
  ```

* You can also explicitly set `CC`, `CFLAGS`, `LDFLAGS`, etc.  For example, to
  build an optimized 64‑bit binary on IBM AIX using the IBM XL C/C++ compiler
  and AIX `make`:

  ```sh
  make CC=xlc CFLAGS="-O3 -q64" LDFLAGS="-Wl,-b64"
  ```

* To build a native binary on Windows using the Microsoft Visual Studio C/C++
  compiler, from a **Developer Command Prompt for Visual Studio** window, run:

  ```sh
  msvcbuild.bat
  ```

### Portability

**TPZASM** should compile cleanly on any system with an
ANSI&nbsp;C89 compiler.

* Linux, AIX, OS/400, Solaris, illumos, FreeBSD, NetBSD, OpenBSD,
  DragonFly&nbsp;BSD, Haiku, MS‑DOS, OS/2, and Windows are known to work
  without modification.

* The [SoftIntegration Ch](https://www.softintegration.com/) interpreter, and
  the GNU&nbsp;GCC, LLVM&nbsp;Clang, PCC, NVIDIA&nbsp;HPC&nbsp;SDK&nbsp;C/C++,
  Oracle&nbsp;Studio&nbsp;C/C++, DMD&nbsp;ImportC, CompCert&nbsp;C, Open64,
  PathScale&nbsp;EKOPath, IBM&nbsp;XL&nbsp;C/C++, DJGPP,
  Microsoft&nbsp;Visual&nbsp;C/C++, IBM&nbsp;Open&nbsp;XL&nbsp;C/C++,
  Open&nbsp;Watcom&nbsp;V2, and МЦСТ&nbsp;LCC compilers are regularly tested.

## Status

**TPZASM** is \~**99.8%** complete relative to **TDL&nbsp;ZASM&nbsp;2.21**
and **PSA&nbsp;PASM&nbsp;1.02**.

* It is a fully faithful reimplementation of *both* assemblers (including
  their quirks and bugs) and can assemble many substantial historic codebases
  (which also serve as [test cases](tests)), including:

  | Codebase                                                                                                  |               Size |
  |:----------------------------------------------------------------------------------------------------------|-------------------:|
  | [Plu\*Perfect High-BIOS for Advent Kaypro Turbo ROM](tests/turbobs.asm)                                   |    \~900&nbsp;SLOC |
  | [Zapple](https://en.wikipedia.org/wiki/Zapple_Monitor)&nbsp;[1K&nbsp;Monitor&nbsp;2.0](tests/zap1k.asm)   |  \~1,000&nbsp;SLOC |
  | [TAPELIB](tests/tapelib.asm)                                                                              |  \~1,500&nbsp;SLOC |
  | [Zapple](https://en.wikipedia.org/wiki/Zapple_Monitor)&nbsp;[2K&nbsp;Monitor&nbsp;2.1R](tests/ssmon.asm)  |  \~1,900&nbsp;SLOC |
  | [Burke&nbsp;Z80&nbsp;Disassembler](tests/dis.asm)                                                         |  \~2,200&nbsp;SLOC |
  | [Zapple](https://en.wikipedia.org/wiki/Zapple_Monitor)&nbsp;[2K&nbsp;Monitor&nbsp;1.11](tests/zapple.asm) |  \~2,500&nbsp;SLOC |
  | [Alloy](tests/ittl.asm)&nbsp;[Engineering](tests/atu4.asm)&nbsp;[Utilities](tests/mtu4.asm)               |  \~2,800&nbsp;SLOC |
  | [SARGON](tests/sargon.asm)                                                                                |  \~3,500&nbsp;SLOC |
  | [DMS/3&nbsp;&amp;&nbsp;DMS/4&nbsp;HiNet&nbsp;CP/M&nbsp;BIOS](tests/bios.asm)                              | \~10,000&nbsp;SLOC |
  | [VEDIT‑PLUS](https://github.com/johnsonjh/VEDIT)                                                          | \~30,000&nbsp;SLOC |

* In every case, **TPZASM** produces *identical* listings and
  *byte‑for‑byte identical* object output when compared to the reference
  TDL/PSA assemblers.  The only differences are when processing certain
  deliberately malformed or specially crafted inputs (that cause the
  reference assemblers to abort or crash).

* **TPZASM** can write the assembled output as a raw binary image, or as a
  **TDL&nbsp;Object&nbsp;Module** in relocatable (`.PREL`) or absolute
  Intel&nbsp;HEX module (`.PABS`) formats, serialized either as raw binary
  (using the `-R` flag, *i.e.*, `.PBIN`) or as ASCII‑hex text (using the `-X`
  flag, *i.e.*, `.PHEX`), all of which is *byte‑for‑byte identical* to the
  object output of the reference software.

**HEXCOM** is **100%** complete and produces byte‑for‑byte identical
output to the original reference tool, with matching messages and identical
error‑handling semantics, plus user‑configurable control of output padding.

## Notes

**TPZASM** is ***not*** related to the similarly named
[Cromemco](https://en.wikipedia.org/wiki/Cromemco) ZASM or
[Megatokio](https://github.com/Megatokio) ZASM assemblers.

### Developer notes

* `make lint` needs only a POSIX shell to run (plus whichever linters and
  static analysis tools it invokes).  You'll be informed of any missing
  prerequisites as well as any optional tools when you invoke `make lint`.

* `make longtest` requires *Georg Brein*'s
  [`tnylpo`](https://gitlab.com/gbrein/tnylpo) emulator available in your PATH.

* If you would like to contribute to **TPZASM** development, it is *extremely*
  *important* that you have ***all*** of the optional linters, static analysis
  tools, emulators, and cross‑toolchains installed, and that `make lint`,
  `make test`, and `make longtest` all pass completely clean, as this is a
  prerequisite for any change.  Every linter has, at some point, caught real
  bugs in the code.

* Usage of AI (artificial intelligence) tools by contributors is permitted,
  subject to the same terms and conditions as the
  [LLVM AI Tool Use Policy](https://llvm.org/docs/AIToolPolicy.html).

### Future plans

In 1979, after the closure of TDL/Xitan, Neil J. Colvin formed **Phoenix
Software Associates** (PSA), and Carl Galletti and Roger Amidon formed
**Computer Design Labs** (CDL), with both companies offering TDL‑derived
development tools for several years.

#### CDL MACRO emulation

* The **CDL MACRO** assemblers are in the same family, with three variants of
  these three assemblers definitively known from various listing outputs
  (`E12011-0311`, `C12012-0312`, and `C12012-414X` *i.e.*, versions `3.11`,
  `3.12`, and `4.14X`).

  * **MACRO I** is described as "a macro assembler which will generate
    relocatable or absolute code for the 8080 or Z80 using standard Intel
    mnemonics plus TDL/Z80 extensions.  Functions include 14 conditionals, 16
    listing controls, 54 pseudo‑ops, 11 arithmetic/logical operations, local
    and global symbols, chaining files, linking capability with optional
    linker, and recursive/reiterative macros",

  * **MACRO II** is described as "expanding upon MACRO I's linking
    capabilities and offering more listing options", and,

  * **MACRO III** is described as "an enhanced version of MACRO II; internal
    buffers have been increased to achieve a significant improvement in speed
    of assembly; additional features include line numbers, cross‑reference
    compressed PRN files, form feeds, page parity, additional pseudo‑ops,
    internal setting of time and date, and expanded assembly‑time data entry".
    At least one new pseudo‑op, `.SETWID`, has been definitively identified
    by reviewing listings.

  Unfortunately, no copies of these CDL assemblers are known to be archived,
  but **TPZASM** successfully assembles several program sources written for
  **CDL MACRO** without modification.  If these assemblers could be found and
  analyzed, their bugs, quirks, and listing styles could be emulated in a
  future **TPZASM** release.

#### PSA PASM 2.0 emulation

* Another **PSA PASM** variant, **PSA&nbsp;PASM&nbsp;2.00G** (`C12011-0200G`,
  *likely a beta release*), is also known, though no documentation for it
  seems to have survived.  Its assembly output seems to be byte‑for‑byte
  identical to **PSA&nbsp;PASM&nbsp;1.02** (with the same instruction encoding
  and the same relocatable object output) for all our TDL‑style test inputs.
  This release completely overhauls the listing format and adds some
  completely new modes, activated by the `.EPOP` and `.ZOP` pseudo‑ops,
  allowing the use of MACRO‑80‑style pseudo‑ops and Zilog mnemonics.  It also
  exhibits several behaviors that are clearly bugs, such as sometimes omitting
  the symbol table from listings when certain macros are defined.

  Support for emulation of this assembler and its improved listing style
  (but without the bugs) may be offered in a future release.

* An optional *extended error checking* mode may be added in a future release,
  enabling new features such as classifying errors or warnings by severity,
  and emitting new diagnostics the originals never supported, for example,
  warning when symbols longer than six characters would be silently truncated.

## Reference

### Original binaries

* The [`orig/`](orig) directory contains the original CP/M‑80 executables.

### Original documentation

* The [`docs/`](docs) directory contains PDF‑format documentation for the
  assemblers (directly applicable to **TPZASM**), the book
  “**Z‑80 assembly language under TurboDOS**” by R.&nbsp;Roger&nbsp;Breton
  (an excellent TDL assembly resource), and some reverse engineering notes.

## Security

* The canonical home of this software is
  [`https://github.com/johnsonjh/tpzasm`](https://github.com/johnsonjh/tpzasm),
  with a mirror on [GitLab](https://gitlab.com/johnsonjh/tpzasm).
* This software is intended to be **secure** 🛡️.
* If you find any security‑related problems, please don’t hesitate to
  [open a GitHub Issue](https://github.com/johnsonjh/tpzasm/issues/new/choose)
  (or send an
  [email](mailto:incoming+johnsonjh-tpzasm-83023857-issue-@incoming.gitlab.com)
  to the author).

## License

The **TPZASM** software is distributed under the terms of the permissive
[**MIT&nbsp;No&nbsp;Attribution&nbsp;(MIT‑0) License**](LICENSE).

### Third‑party materials

The following third‑party materials are provided under their own licenses:

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

* The book “**Z‑80 assembly language under TurboDOS**” is © 1984, 1987, 1990,
  2003, 2009 R.&nbsp;Roger&nbsp;Breton and distributed with permission under
  the terms and conditions of the
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
