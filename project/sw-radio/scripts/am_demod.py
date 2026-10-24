#!/usr/bin/env python3
"""Software AM/SSB demodulator for K9IQ captures, independent of HDSDR.

If this produces intelligible audio from a capture that HDSDR renders as a bare
spike, the RF chain and DFE are fine and the problem is host-side.  If it is
noise too, the capture itself has no recoverable modulation.

Usage:
  python am_demod.py build/x.iq16 --offset 100000 --bw 5000 --out build/x.wav
  python am_demod.py build/x.iq16 --offset 100000 --bw 2400 --mode usb --out y.wav
"""
import argparse
import struct
import wave

import numpy as np

FS = 1_250_000
AUDIO_FS = 12500


def load(path):
    raw = np.fromfile(path, dtype="<i2").astype(np.float64)
    return raw[0::2] + 1j * raw[1::2]


def lpf(x, cutoff, fs, taps=1023):
    n = np.arange(taps) - (taps - 1) / 2
    h = np.sinc(2 * cutoff / fs * n) * np.hamming(taps)
    h /= h.sum()
    return np.convolve(x, h, mode="same")


def zoom_psd(x, offset, span, label):
    """High-resolution look at +/-span/2 around offset: is there modulation?"""
    n = min(1 << 18, 1 << (len(x).bit_length() - 1))
    t = np.arange(n) / FS
    y = x[:n] * np.exp(-2j * np.pi * offset * t)
    y = lpf(y, span / 2, FS, 2047)[2047:-2047]
    m = 1 << 15
    w = np.hanning(m)
    acc = np.zeros(m)
    segs = 0
    for k in range(0, len(y) - m, m // 2):
        acc += np.abs(np.fft.fft(y[k:k + m] * w)) ** 2
        segs += 1
    acc /= max(segs, 1)
    f = np.fft.fftshift(np.fft.fftfreq(m, 1 / FS))
    p = np.fft.fftshift(10 * np.log10(acc / (w.sum() ** 2) / 32768.0 ** 2 + 1e-30))
    inband = np.abs(f) < span / 2 * 0.85
    med = np.median(p[inband])
    print(f"\n--- {label}: span +/-{span/2/1e3:.0f} kHz around {offset/1e3:+.0f} kHz "
          f"(bin {FS/m:.1f} Hz)")
    print(f"    floor {med:.1f} dBFS, peak {p.max():.1f} dBFS at "
          f"{f[np.argmax(p)]/1e3:+.3f} kHz")
    # sideband table in 500 Hz buckets out to +/-6 kHz
    for edge in (500, 1000, 2000, 3000, 4000, 5000, 6000):
        sel = (np.abs(f) > edge - 500) & (np.abs(f) <= edge)
        if sel.any():
            print(f"    |f| {edge-500:5d}-{edge:5d} Hz: {p[sel].max():7.1f} dBFS "
                  f"({p[sel].max()-med:+5.1f} dB over floor)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("path")
    ap.add_argument("--offset", type=float, default=100_000)
    ap.add_argument("--bw", type=float, default=5000)
    ap.add_argument("--mode", default="am", choices=("am", "usb", "lsb"))
    ap.add_argument("--out")
    a = ap.parse_args()

    x = load(a.path)
    print(f"{a.path}: {len(x)/FS:.2f} s, rms "
          f"{20*np.log10(np.sqrt(np.mean(np.abs(x)**2))/32768):.1f} dBFS")
    zoom_psd(x, a.offset, 40e3, "wide")
    zoom_psd(x, a.offset, 14e3, "channel")

    t = np.arange(len(x)) / FS
    y = x * np.exp(-2j * np.pi * a.offset * t)
    if a.mode == "am":
        y = lpf(y, a.bw / 2, FS, 2047)
        audio = np.abs(y)
        audio = audio - audio.mean()
    else:
        y = lpf(y, a.bw, FS, 2047)
        audio = np.real(y) if a.mode == "usb" else np.imag(y)
    audio = lpf(audio, 4000, FS, 501)
    audio = audio[::int(FS // AUDIO_FS)]
    audio *= 12000 / (np.max(np.abs(audio)) + 1e-9)

    n = len(audio)
    w = np.hanning(min(8192, n))
    seg = audio[:len(w)] * w
    sp = np.abs(np.fft.rfft(seg))
    fr = np.fft.rfftfreq(len(seg), 1 / AUDIO_FS)
    band = sp[(fr > 300) & (fr < 3500)]
    print(f"\naudio: {n/AUDIO_FS:.2f} s @ {AUDIO_FS} Hz, "
          f"rms {20*np.log10(np.std(audio)/32768+1e-9):.1f} dBFS, "
          f"300-3500 Hz peak/median {20*np.log10(band.max()/(np.median(band)+1e-9)):.1f} dB")
    if a.out:
        with wave.open(a.out, "wb") as f:
            f.setnchannels(1)
            f.setsampwidth(2)
            f.setframerate(AUDIO_FS)
            f.writeframes(struct.pack(f"<{n}h", *audio.astype("<i2").tolist()))
        print(f"wrote {a.out}")


if __name__ == "__main__":
    main()
