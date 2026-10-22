#!/usr/bin/env python3
"""Deterministically generate 45-degree, 4096-word NCO sine/cosine ROMs.

Addresses 1..4096 hold 2*pi*n/32768; address zero is special-cased
in common/dsp_nco_rom.v.  Q13 and Q15 retain identical phase indexing.
"""

import argparse
import hashlib
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def contents(bits, kind):
    amplitude = (1 << (bits - 1)) - 1
    fn = math.sin if kind == "sin" else math.cos
    words = []
    for n in range(1, 4097):
        v = round(amplitude * fn(2 * math.pi * n / 32768))
        assert 0 <= v <= amplitude
        words.append(f"{v:04x}\n")
    return "".join(words)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    for bits in (14, 16):
        for kind in ("sin", "cos"):
            path = ROOT / "common" / f"nco_q{bits-1}_{kind}45.hex"
            value = contents(bits, kind)
            if args.verify:
                assert path.read_text() == value, f"Bad ROM: {path}"
            else:
                path.write_text(value)
            print(path.relative_to(ROOT), hashlib.sha256(value.encode()).hexdigest()[:16])


if __name__ == "__main__":
    main()
