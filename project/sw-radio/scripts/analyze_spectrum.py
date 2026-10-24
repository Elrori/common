#!/usr/bin/env python3
"""Welch PSD / spur-line / noise-floor analysis for K9IQ .iq16 captures.

Usage: python analyze_spectrum.py file.iq16 [file2.iq16 ...]
Prints: duration, RMS dBFS, peak, clipping %, noise floor (dBFS/bin),
        top stable spur lines (offset Hz from DFE center).
"""
import struct
import sys
import numpy as np

FS = 1_250_000


def load(path):
    raw = np.fromfile(path, dtype="<i2")
    n = len(raw) // 2
    i = raw[0:2 * n:2].astype(np.float64)
    q = raw[1:2 * n:2].astype(np.float64)
    return i + 1j * q


def welch(x, seg=65536):
    w = np.hanning(seg)
    wnorm = (w ** 2).sum()
    nseg = len(x) // seg
    if nseg == 0:
        seg = len(x)
        w = np.hanning(seg)
        wnorm = (w ** 2).sum()
        nseg = 1
    acc = None
    for k in range(nseg):
        chunk = x[k * seg:(k + 1) * seg] * w
        spec = np.fft.fftshift(np.fft.fft(chunk))
        p = (np.abs(spec) ** 2) / wnorm
        acc = p if acc is None else acc + p
    acc /= nseg
    f = np.fft.fftshift(np.fft.fftfreq(seg, 1 / FS))
    return f, acc


def dbfs(p):
    # full scale complex sinusoid amplitude 32768 -> power 32768^2; dB relative
    return 10 * np.log10(p / 32768.0 ** 2 + 1e-30)


def analyze(path):
    x = load(path)
    dur = len(x) / FS
    rms = np.sqrt(np.mean(np.abs(x) ** 2))
    peak = np.max(np.abs(x))
    clip = np.mean(np.abs(x) > 32000) * 100
    print(f"\n=== {path}")
    print(f"duration {dur:.3f}s  samples {len(x)}  RMS {20*np.log10(rms/32768):.1f} dBFS  "
          f"peak {20*np.log10(peak/32768):.1f} dBFS  clip>32000: {clip:.4f}%")
    f, p = welch(x)
    pdb = dbfs(p)
    med = np.median(pdb)
    print(f"noise floor (median bin): {med:.1f} dBFS/bin  "
          f"(bin width {FS/len(f):.1f} Hz)")
    # stable spur lines: exceed median by >6 dB in >=80% of segments
    seg = min(65536, len(x))
    w = np.hanning(seg)
    wnorm = (w ** 2).sum()
    nseg = len(x) // seg
    present = np.zeros(seg)
    for k in range(nseg):
        spec = np.abs(np.fft.fftshift(np.fft.fft(x[k * seg:(k + 1) * seg] * w))) ** 2 / wnorm
        present += (dbfs(spec) > med + 6)
    frac = present / max(nseg, 1)
    idx = np.argsort(pdb)[::-1]
    shown = 0
    seen = set()
    print("top spur lines (stable>80%, >6dB over floor):")
    for j in idx:
        if frac[j] < 0.8 or pdb[j] < med + 6:
            break
        fc = round(f[j] / 500) * 500  # cluster within 500 Hz
        key = fc // 2000
        if key in seen:
            continue
        seen.add(key)
        print(f"  {f[j]/1000:+9.2f} kHz  {pdb[j]:7.1f} dBFS  ({pdb[j]-med:5.1f} dB over floor, stable {frac[j]*100:.0f}%)")
        shown += 1
        if shown >= 10:
            break
    if shown == 0:
        print("  none (noise-like floor)")
    return med


if __name__ == "__main__":
    for p in sys.argv[1:]:
        try:
            analyze(p)
        except Exception as e:
            print(f"{p}: ERROR {e}")
