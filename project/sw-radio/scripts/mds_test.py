#!/usr/bin/env python3
"""Absolute sensitivity / noise-figure / MDS measurement for the K9+ SW receiver.

Needs ONE known input level (tinySA generator, frequency set ON THE DEVICE —
the serial `freq` command does not move the generator). Everything else is
derived from that single point.

  P_tone(dBFS) measured from the IQ stream, input level L(dBm) known
      -> R = P_tone - L            (dBFS per dBm, includes all gain + scaling)
      -> any dBFS reading minus R is dBm at the antenna port

  noise PSD (dBFS/Hz) - R          = input-referred noise density (dBm/Hz)
  NF      = PSD_dBm_per_Hz + 174
  3 kHz noise = PSD_dBm_per_Hz + 10log10(3000)
  MDS(0 dB SNR) = 3 kHz noise
  usable sensitivity (10 dB S/N) = MDS + 10

Usage:
  python mds_test.py --freq 15230000 --level -40 --codes 0x00,0x20,0x40,0x60,0x80,0xa0,0xc0
  python mds_test.py --freq 15230000 --level -40 --codes 0x40 --sweep -70,-60,-50,-40,-30,-20,-10
"""
import argparse
import socket
import sys
import time
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rf_probe as R

KTB = -174.0
FS = R.FS


def tone_and_floor(x, tone_off_hz, bw_hz, guard=4000.0):
    """Return (tone_dBFS, psd_dBm_free) where the second is the noise PSD
    with the tone and its close-in skirt excluded."""
    n = min(16384, 1 << (len(x).bit_length() - 1))
    n = max(n, 1024)
    f, p = R.psd(x)
    df = FS / n
    j0 = int(np.argmin(np.abs(f - tone_off_hz)))
    lo, hi = max(0, j0 - 4), min(len(p), j0 + 5)
    mask = np.ones(len(p), bool)
    mask[max(0, j0 - 8):j0 + 9] = False
    floor = float(np.median(p[mask]))
    tone = 10 * np.log10(np.sum(10 ** (p[lo:hi] / 10)) * df + 1e-30)
    return tone, floor, df


def one_point(tune_hz, level_dbm, code, tone_off_hz, bw_hz, packets=4096, sock=None):
    R.tune(tune_hz)
    time.sleep(0.03)
    R.gain(code)
    time.sleep(0.25)
    x, h = R.capture(packets, sock)
    tone, floor, df = tone_and_floor(x, tone_off_hz, bw_hz)
    ref = tone - level_dbm
    psd_dbm = floor - ref
    ch = psd_dbm + 10 * np.log10(bw_hz)
    return dict(code=code, tone=tone, ref=ref, psd=psd_dbm,
                nf=psd_dbm - KTB, ch=ch, mds10=ch + 10,
                peak=int(np.abs(x).max()), otr=h["otr"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--freq", type=int, default=15_230_000, help="board tune (Hz)")
    ap.add_argument("--tone-offset", type=int, default=250_000)
    ap.add_argument("--level", type=float, required=True,
                    help="tinySA level actually shown on the device (dBm)")
    ap.add_argument("--codes", default="0x00,0x20,0x40,0x60,0x80,0xa0,0xc0")
    ap.add_argument("--bw", type=float, default=3000.0)
    ap.add_argument("--packets", type=int, default=4096)
    ap.add_argument("--sweep", default="", help="comma list of levels for P1dB")
    ap.add_argument("--sweep-code", default="0x40")
    a = ap.parse_args()

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("0.0.0.0", R.IQ_PORT))
    sock.settimeout(10.0)

    print(f"board tune {a.freq/1e6:.4f} MHz, tone at {a.tone_offset/1e3:+.0f} kHz, "
          f"input {a.level} dBm, channel {a.bw/1e0:.0f} Hz")
    print(f"{'gain':>6} {'tone dBFS':>10} {'ref dB':>8} {'PSD dBm/Hz':>11} "
          f"{'NF dB':>7} {'3k dBm':>8} {'MDS+10':>8} {'peak':>6}")

    if a.sweep:
        code = int(a.sweep_code, 16)
        print(f"\n--- 1 dB compression sweep at gain 0x{code:02x} ---")
        rows = []
        for lv in [float(t) for t in a.sweep.split(",")]:
            r = one_point(a.freq, lv, code, a.tone_offset, a.bw, a.packets, sock)
            rows.append((lv, r["tone"]))
            print(f"  in {lv:7.1f} dBm   tone {r['tone']:7.2f} dBFS   "
                  f"peak {r['peak']:6d}   otr {r['otr']}")
        if len(rows) >= 3:
            base = rows[0][1] - rows[0][0]
            print(f"  small-signal slope ref = {base:+.2f} dB/dB")
            for lv, t in rows:
                comp = (t - lv) - base
                print(f"    {lv:7.1f} dBm  compression {comp:+6.2f} dB")

    print("\n--- gain table ---")
    for c in [int(t, 16) for t in a.codes.split(",")]:
        r = one_point(a.freq, a.level, c, a.tone_offset, a.bw, a.packets, sock)
        print(f" 0x{r['code']:02x} {r['tone']:10.2f} {r['ref']:8.2f} {r['psd']:11.1f} "
              f"{r['nf']:7.1f} {r['ch']:8.1f} {r['mds10']:8.1f} {r['peak']:6d}")

    sock.close()


if __name__ == "__main__":
    main()
