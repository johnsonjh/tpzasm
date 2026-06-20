# PASM 2.00G (`orig/pasm2.com`) bugs and quirks

PASM 2.00G (`[C12011-0200G]`, 06/27/81) is a buggy version of the PSA Macro
Assembler.  These are clear and obvious defects in `pasm2.com` itself.
**TPZASM does NOT reproduce these bugs** and always produces the correct
output.  Where a bug interferes with differential testing, the test
cases are adjusted to avoid triggering it (noted per item).

## 1. `.XLINK` object writer drops/truncates small + mid-sized objects

**Symptom.**  A program that assembles **cleanly (zero errors)** writes a
WRONG object file under `.XLINK`: the listing shows the correct assembled
bytes, but the `.hex`/`.rel` on disk is either empty or truncated.

**Behavior by object size** (`.EPOP`/`.ZOP`/`.PABS`/`.PHEX`/`.XLINK`/`ASEG`/
`ORG 100H`, body = N×`NOP`; the object is written as 128-byte CP/M records):

|      object content | with `.XLINK`                                                      | without `.XLINK` |
|--------------------:|--------------------------------------------------------------------|-----------------:|
| < ~30 bytes         | **empty file**                                                     | written (padded) |
| ~30 .. 128          | written (one 128-B record)                                         | written          |
| 128 .. ~few-hundred | **TRUNCATED to 128 bytes** (content past the first record is lost) | written          |
| large (e.g. ~900)   | written in full                                                    | written          |

So under `.XLINK` only the small (≤ one record) and large objects come out
intact; a mid-sized object (one full record plus a partial) is silently cut to
the first 128-byte record, dropping the rest AND the EOF record.  Without
`.XLINK` the `!` module-name + `\` segment-size records are present and the
object is always written correctly, so the bug is specific to the `.XLINK`
object path.

**TPZASM behavior.**  TPZASM writes the complete assembled object for ANY size
(e.g. the 5-byte `LD A,1`/`NOP` `.XLINK` program emits `:030100003E0100BD` +
EOF; the 191-byte `intcond`-style program emits all of its records).  TPZASM
is correct; pasm2 is buggy.

**Testing workaround.**  PASM 2.00G object fixtures avoid the truncation zone:
the large sweeps (`zop`, `zexh`) sit above it; the small mode fixtures
(`zoponly`, `epoponly`, `zmac`) stay under one record; and the Intel-directive
fixture (`intcond`) simply omits `.XLINK` (its `!`/`\` records make pasm2 write
the object in full).  Plain NOP padding is NOT a safe blanket fix — adding
bytes can push a small object UP into the truncation zone.

## 2. Symbol table intermittently dropped when macros are defined

Content-dependent: with certain `.DEFINE` macro definitions the closing symbol
table is omitted from the listing (1.02 always emits it).  TPZASM always emits
the symbol table.

## 3. Dormant/unfinished beta artifacts

The unfilled `XX/XX/81 XX:XX:XX` date template (no RTC under CP/M 2.2), the
seemingly unwired ` (OPCD) `/` (MACR) ` strings, and the `G` revision suffix
seem to be signs this is not a final release.

## Notes on intentional TPZASM/pasm2 differences (not really bugs)

- **Binary `.PBIN` record chunking.**  2.00G packs binary data records into
  larger chunks than PASM 1.02; TPZASM uses the 1.02 chunking.  Identical
  content, different framing.  Our real sources select `.PHEX` (ASCII), which
  is byte-exact, so `tools/vpasm2.sh` differences only the ASCII object.
- **Multi-character `.BYTE` `Q` error.**  pasm2 flags a multi-character TDL
  `.BYTE "AB"` with a `Q` error (it still emits the single character-constant
  low byte); TPZASM emits the same byte without the `Q`.  Error-listing
  only; object bytes match.
- **Error-recovery byte counts.**  On invalid input pasm2 may emit a 4-byte
  zero placeholder where TPZASM emits a best-effort instruction size, and
  pasm2 SUPPRESSES the object file entirely when there are errors.  Error-input
  only; valid programs are byte-exact.
