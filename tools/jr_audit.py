#!/usr/bin/env python3
"""jr_audit.py - JR-relaxation audit for PASM/ZASM listings.

Scans an assembler listing (.prn) for 3-byte ABSOLUTE jumps whose target is
within Z80 JR reach (-128..+127 of the following instruction): candidates to
shrink to a 2-byte relative jump, saving one byte each.

Everything needed is in the listing: the address column gives the instruction's
location, the assembled bytes (C3/CA/C2/DA/D2 lo hi) give the resolved target.

IMPORTANT distinction (VEDIT uses relative-intent branch MACROS -- JMPR, JRZ,
BEQ, BLT, ...): on an 8080 build those macros are *forced* to absolute jumps
(8080 has no JR), so they all look like candidates, but on a Z80 build they are
already JR.  The ACTIONABLE sites are source lines using a LITERAL absolute jump
mnemonic (JMP/JZ/JNZ/JC/JNC) that could be flipped to the relative macro -- this
is build-independent, since a literal JMP is C3 on both 8080 and Z80.

Risk-free: flip a candidate in source, rebuild; an out-of-range relative jump
makes the assembler error, so a clean rebuild is the proof.

Usage: tools/jr_audit.py LISTING.prn [...]
"""

import sys
import re

ABS2REL = {0xC3: "JMPR", 0xCA: "JRZ", 0xC2: "JRNZ", 0xDA: "JRC", 0xD2: "JRNC"}
# literal absolute-jump source mnemonic -> relative form to flip to
HARD = {"JMP": "JMPR", "JZ": "JRZ", "JNZ": "JRNZ", "JC": "JRC", "JNC": "JRNC"}

LINE = re.compile(r"^[A-Za-z ]{0,2}\s*([0-9A-Fa-f]{4})\s+([0-9A-Fa-f]{6})\s+(\S.*)$")


def src_mnemonic(src):
    """The instruction mnemonic shown in a listing's source column, skipping a
    leading label (`FOO:`) or macro-expansion marker (`@`, `*`)."""
    toks = src.split()
    i = 0
    while i < len(toks) and (toks[i] in ("@", "*") or toks[i].endswith(":")):
        i += 1
    return toks[i].upper() if i < len(toks) else ""


def audit(path):
    actionable, hist = [], {}
    with open(path, "r", errors="replace") as f:
        for line in f:
            m = LINE.match(line)
            if not m:
                continue
            op = int(m.group(2)[0:2], 16)
            if op not in ABS2REL:
                continue
            addr = int(m.group(1), 16)
            b = m.group(2)
            target = int(b[2:4], 16) | (int(b[4:6], 16) << 8)
            disp = target - (addr + 2)
            if not (-128 <= disp <= 127):
                continue
            src = m.group(3).rstrip()
            mn = src_mnemonic(src)
            hist[mn] = hist.get(mn, 0) + 1
            if mn in HARD:
                actionable.append((addr, mn, HARD[mn], target, disp, src))
    return actionable, hist


def main(argv):
    if len(argv) < 2:
        sys.stderr.write("usage: jr_audit.py LISTING.prn [...]\n")
        return 2
    for path in argv[1:]:
        act, hist = audit(path)
        print("==== %s ====" % path)
        print("in-range 3-byte absolute jumps: %d" % sum(hist.values()))
        order = sorted(hist, key=lambda k: (-hist[k], k))
        print(
            "  by source mnemonic: "
            + ", ".join("%s=%d" % (k or "?", hist[k]) for k in order)
        )
        print(
            "ACTIONABLE (literal JMP/JZ/JNZ/JC/JNC -> relative): %d  (=> %d bytes)"
            % (len(act), len(act))
        )
        if act:
            print(
                "%-5s %-6s %-5s %-6s %-5s  %s"
                % ("ADDR", "FLIP", "FROM", "TARGET", "DISP", "SOURCE")
            )
            for addr, mn, rel, target, disp, src in act:
                print(
                    "%04X  %-6s %-5s %04X   %+5d  %s"
                    % (addr, rel, mn, target, disp, src[:52])
                )
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
