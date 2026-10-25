#!/usr/bin/env python3
"""Quantitative RF probe for the K9+ direct-sampling SW receiver.

Reports absolute-referred numbers, not HDSDR colours:
  * dBFS RMS and peak
  * noise PSD in dBFS/Hz and equivalent noise inside a 6 kHz AM channel
  * strongest stable lines with offset from the DFE centre
  * PSD shape (DC bump / tilt) sampled across the +/-500 kHz passband

Usage:
  python rf_probe.py listen   --freq 15230000 --gain 0xa0 --packets 4096
  python rf_probe.py gain     --freq 15230000 --codes 0x00,0x20,0x40,0x60,0xa0,0xc0
  python rf_probe.py retune   --freqs 15130000,15230000,15330000 --gain 0xa0
  python rf_probe.py scan     --start 400000 --stop 30000000 --step 250000 --gain 0x40
  python rf_probe.py file     build/xxx.iq16 [build/yyy.iq16]
"""
import argparse
import socket
import struct
import sys
import time
from pathlib import Path

import numpy as np

FS = 1_250_000
ADC_RATE = 62_500_000
IQ_PER_PACKET = 256
K9IQ_PACKET_SIZE = 32 + IQ_PER_PACKET * 4
CONTROL_PORT = 50001
IQ_PORT = 50003
TARGET = "192.168.10.255"


# ---------------------------------------------------------------- transport
def tune(hz: int) -> None:
    fcw = round(hz * 2**32 / ADC_RATE) & 0xFFFFFFFF
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        s.sendto(b"K9TU" + struct.pack("<II", hz, fcw), (TARGET, CONTROL_PORT))


def gain(code: int) -> None:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        s.sendto(b"K9AG" + bytes((code,)), (TARGET, CONTROL_PORT))


def capture(packets: int, sock=None) -> np.ndarray:
    """Return complex baseband (float64) and the last packet header."""
    own = sock is None
    if own:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.bind(("0.0.0.0", IQ_PORT))
        sock.settimeout(10.0)
    buf = bytearray()
    last = None
    got = 0
    try:
        while got < packets:
            payload, _ = sock.recvfrom(4096)
            if len(payload) != K9IQ_PACKET_SIZE or payload[:4] != b"K9IQ":
                continue
            last = dict(seq=struct.unpack_from("<I", payload, 8)[0],
                        tune=struct.unpack_from("<I", payload, 12)[0],
                        drops=struct.unpack_from("<I", payload, 28)[0],
                        otr=bool(payload[5] & 2), flags=payload[5])
            buf += payload[32:]
            got += 1
    finally:
        if own:
            sock.close()
    raw = np.frombuffer(bytes(buf), dtype="<i2").astype(np.float64)
    iq = raw[0::2] + 1j * raw[1::2]
    return iq, last


# ---------------------------------------------------------------- analysis
def psd(x: np.ndarray):
    """Welch PSD, calibrated so a full-scale complex tone reads 0 dBFS.

    Returns (freqs, psd_dbfs_per_hz)."""
    n = min(16384, 1 << (len(x).bit_length() - 1))
    n = max(n, 1024)
    w = np.hanning(n)
    sw1 = w.sum()
    sw2 = (w ** 2).sum()
    acc = np.zeros(n)
    segs = 0
    for k in range(0, len(x) - n + 1, n // 2):
        acc += np.abs(np.fft.fft(x[k:k + n] * w)) ** 2
        segs += 1
    if segs == 0:
        acc = np.abs(np.fft.fft(x[:n] * w[:len(x[:n])])) ** 2
        segs = 1
    acc /= segs
    # PSD in FS^2/Hz, FS = 32768 amplitude
    p = acc / (sw2 * FS)
    f = np.fft.fftshift(np.fft.fftfreq(n, 1 / FS))
    return f, np.fft.fftshift(10 * np.log10(p / 32768.0 ** 2 + 1e-30))


def summarise(x, label, extra=""):
    f, p = psd(x)
    med = np.median(p)
    # robust despiked path for a "signal-free" floor estimate
    n6k = med + 10 * np.log10(6000)
    rms = 10 * np.log10(np.mean(np.abs(x) ** 2) / 32768.0 ** 2 + 1e-30)
    peak_i = int(np.argmax(p))
    print(f"{label:<34} rms {rms:7.1f}  floor {med:7.1f} dBFS/Hz  "
          f"in6kHz {n6k:7.1f} dBFS  pk {p[peak_i]:6.1f}@ {f[peak_i]/1e3:+7.1f}kHz{extra}")
    return dict(f=f, p=p, med=med, rms=rms, n6k=n6k)


def peaks(f, p, med, count=10, thresh=8.0):
    """Stable-ish strongest lines above the floor, clustered."""
    idx = np.argsort(p)[::-1]
    out, used = [], []
    for j in idx:
        if p[j] < med + thresh:
            break
        if any(abs(f[j] - u) < 1500 for u in used):
            continue
        used.append(f[j])
        out.append((f[j], p[j], p[j] - med))
        if len(out) >= count:
            break
    return out


def band_shape(f, p):
    """PSD sampled at fixed offsets -> exposes DC bump, tilt, passband edges."""
    offs = [-600, -500, -400, -300, -200, -120, -80, -50, -20,
            0, 20, 50, 80, 120, 200, 300, 400, 500, 600]
    vals = []
    for o in offs:
        j = int(np.argmin(np.abs(f - o * 1e3)))
        lo, hi = max(0, j - 3), min(len(p), j + 4)
        vals.append(np.median(p[lo:hi]))
    return offs, vals


def print_shape(f, p):
    offs, vals = band_shape(f, p)
    base = np.median([v for o, v in zip(offs, vals) if abs(o) in (300, 400, 500)])
    print("    offset kHz :" + "".join(f"{o:7d}" for o in offs))
    print("    rel to edge:" + "".join(f"{v - base:7.1f}" for v in vals))


# ---------------------------------------------------------------- commands
def cmd_listen(a):
    tune(a.freq)
    time.sleep(0.05)
    if a.gain is not None:
        gain(a.gain)
        time.sleep(0.05)
    x, hdr = capture(a.packets)
    s = summarise(x, f"listen {a.freq/1e6:.3f} MHz g=0x{a.gain:02x}" if a.gain is not None
                  else f"listen {a.freq/1e6:.3f} MHz", f"  otr={hdr['otr']}")
    print("    top lines:")
    for fo, pj, d in peaks(s["f"], s["p"], s["med"]):
        print(f"      {fo/1e3:+9.2f} kHz  {pj:7.1f} dBFS/Hz  (+{d:5.1f} dB)")
    print_shape(s["f"], s["p"])
    print(f"    header {hdr}")


def cmd_gain(a):
    tune(a.freq)
    time.sleep(0.05)
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("0.0.0.0", IQ_PORT))
    sock.settimeout(10.0)
    codes = [int(c, 0) for c in a.codes.split(",")]
    rows = []
    try:
        for c in codes:
            gain(c)
            time.sleep(a.settle)
            x, hdr = capture(a.packets, sock)
            s = summarise(x, f"gain 0x{c:02x} ({a.freq/1e6:.3f} MHz)",
                          f"  otr={hdr['otr']}")
            rows.append((c, s))
    finally:
        sock.close()
    print("\n    gain step test (floor must move 1:1 with gain if the noise is "
          "at the antenna):")
    for (c0, s0), (c1, s1) in zip(rows, rows[1:]):
        print(f"      0x{c0:02x}->0x{c1:02x}: floor {s1['med']-s0['med']:+6.2f} dB, "
              f"rms {s1['rms']-s0['rms']:+6.2f} dB")


def cmd_retune(a):
    tune(a.freqs[0])
    time.sleep(0.05)
    if a.gain is not None:
        gain(a.gain)
        time.sleep(0.05)
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("0.0.0.0", IQ_PORT))
    sock.settimeout(10.0)
    base = None
    try:
        for fr in a.freqs:
            tune(fr)
            time.sleep(a.settle)
            x, hdr = capture(a.packets, sock)
            s = summarise(x, f"retune {fr/1e6:.4f} MHz")
            lines = peaks(s["f"], s["p"], s["med"], count=8)
            for fo, pj, d in lines:
                print(f"      {fo/1e3:+9.2f} kHz  {pj:7.1f} dBFS/Hz  (+{d:5.1f})")
            if base is None:
                base = [l[0] for l in lines]
            else:
                moved = sorted(round((b - l[0]) / 1e3, 2) for b, l in zip(base, lines))
                print(f"      offset change vs first tune (kHz): {moved}")
                print("      -> external carriers shift by -(delta tune); "
                      "internal spurs stay put")
    finally:
        sock.close()


def cmd_scan(a):
    print(f"{'MHz':>9} {'rms':>7} {'floor dBFS/Hz':>14} {'in6k':>7} "
          f"{'peak dBFS/Hz':>13} {'pk@kHz':>8}  otr")
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("0.0.0.0", IQ_PORT))
    sock.settimeout(10.0)
    try:
        for fr in range(a.start, a.stop + 1, a.step):
            tune(fr)
            gain(a.gain)
            time.sleep(a.settle)
            x, hdr = capture(a.packets, sock)
            s = summarise(x, "")  # printed below instead
            f, p = s["f"], s["p"]
            j = int(np.argmax(p))
            print(f"{fr/1e6:9.3f} {s['rms']:7.1f} {s['med']:14.1f} {s['n6k']:7.1f} "
                  f"{p[j]:13.1f} {f[j]/1e3:+8.1f}  {'OTR' if hdr['otr'] else '.'}")
    finally:
        sock.close()


def cmd_noise(a):
    """Discriminate thermal/atmospheric noise from impulsive man-made noise.

    A complex Gaussian baseband gives |x|^2 exponential: median/mean = -1.6 dB
    and power kurtosis 9. Man-made (SMPS, LED, dimmer, LAN bursts) noise is
    impulsive: median/mean falls well below that and kurtosis rises."""
    tune(a.freq)
    time.sleep(0.05)
    if a.gain is not None:
        gain(a.gain)
        time.sleep(0.05)
    x, hdr = capture(a.packets)
    p = np.abs(x) ** 2
    med, mean = np.median(p), p.mean()
    kurt = np.mean((p - mean) ** 4) / mean ** 4
    rms = np.sqrt(mean)
    exceed = [np.mean(np.abs(x) > t * rms) for t in (3, 4, 5, 6)]
    print(f"noise {a.freq/1e6:.3f} MHz g=0x{(a.gain or 0):02x}  "
          f"median/mean {10*np.log10(med/mean):+.2f} dB (Gaussian -1.59)  "
          f"power kurtosis {kurt:.2f} (Gaussian 9.0)")
    print("  P(|x| > n*rms):" + "".join(
        f"  {n}x {v*100:6.3f}%" for n, v in zip((3, 4, 5, 6), exceed)))
    # envelope spectrum: repetition rates of bursts (SMPS / line harmonics)
    env = np.abs(x) ** 2
    env = env - env.mean()
    n = min(65536, len(env))
    w = np.hanning(n)
    sp = np.abs(np.fft.rfft(env[:n] * w)) ** 2
    fr = np.fft.rfftfreq(n, 1 / FS)
    sp = 10 * np.log10(sp / np.median(sp) + 1e-30)
    idx = np.argsort(sp)[::-1][:6]
    print("  envelope-spectrum lines (burst repetition):")
    for j in sorted(idx):
        print(f"    {fr[j]:9.1f} Hz  {sp[j]:6.1f} dB above median")


def tone_at(f, p, f0, bw=3000.0):
    """Integrate the strongest line near f0. Returns (freq, peak_dbfs_hz, total_dbfs)."""
    m = (f > f0 - bw) & (f < f0 + bw)
    pj = np.where(m, p, -1e9)
    j = int(np.argmax(pj))
    lo, hi = max(0, j - 8), min(len(p), j + 9)
    df = FS / len(f)
    tot = 10 * np.log10(np.sum(10 ** (p[lo:hi] / 10)) * df)
    return f[j], p[j], tot


def cmd_tiny(a):
    """Absolute calibration with a known CW input (tinySA).

    Every level below is derived from the source level the operator dialled in,
    so the result is traceable:  G = tone_dBFS - level_dBm  is the true
    dBFS-per-dBm conversion, hence the input-referred noise floor and NF."""
    tune(a.freq)
    time.sleep(0.05)
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("0.0.0.0", IQ_PORT))
    sock.settimeout(10.0)
    codes = [int(c, 0) for c in a.codes.split(",")]
    f0 = a.tone_offset
    rows = []
    print(f"inject {a.level:+.1f} dBm CW, DFE centre {a.freq/1e6:.3f} MHz, "
          f"tone expected at {f0/1e3:+.1f} kHz")
    print(f"{'code':>5} {'tone dBFS':>10} {'G dB':>7} {'floor':>8} {'floor_in':>9} "
          f"{'NF':>5} {'CNR5k':>6} {'pkk':>6}  sat")
    try:
        for c in codes:
            gain(c)
            time.sleep(a.settle)
            x, hdr = capture(a.packets, sock)
            f, p = psd(x)
            med = float(np.median(p))
            ft, pk, tot = tone_at(f, p, f0)
            g = tot - a.level
            floor_in = med - g
            nf = floor_in + 174.0
            cnr = tot - (med + 10 * np.log10(a.cw_bw))
            pkx = float(np.abs(x).max())
            sat = "CLIP" if pkx > 0.9 * 32768 else ""
            print(f"0x{c:02x} {tot:10.1f} {g:7.1f} {med:8.1f} {floor_in:9.1f} "
                  f"{nf:5.1f} {cnr:6.1f} {pkx:6.0f}  {sat}")
            rows.append(dict(code=c, tone=tot, g=g, floor=med, fin=floor_in,
                             nf=nf, cnr=cnr, pk=pkx, f=ft))
            if a.save:
                raw = np.empty(2 * len(x), dtype="<i2")
                raw[0::2] = x.real.astype("<i2")
                raw[1::2] = x.imag.astype("<i2")
                raw.tofile(f"{a.save}_0x{c:02x}.iq16")
    finally:
        sock.close()
    if len(rows) > 1:
        print("\n    gain step vs nominal, and how much of it the floor follows:")
        for r0, r1 in zip(rows, rows[1:]):
            print(f"      0x{r0['code']:02x}->0x{r1['code']:02x}: "
                  f"tone {r1['tone']-r0['tone']:+6.2f} dB, "
                  f"floor {r1['floor']-r0['floor']:+6.2f} dB, "
                  f"(floor still 1:1 with gain => noise enters before the VGA)")
    best = max(rows, key=lambda r: r["g"])
    print(f"\n    best absolute gain {best['g']:.1f} dB at 0x{best['code']:02x}; "
          f"with this gain a 0 dBFS iq sample = {a.level - best['g']:.1f} dBm input")


def cmd_file(a):
    for pth in a.files:
        raw = np.fromfile(pth, dtype="<i2").astype(np.float64)
        x = raw[0::2] + 1j * raw[1::2]
        s = summarise(x, Path(pth).name)
        for fo, pj, d in peaks(s["f"], s["p"], s["med"]):
            print(f"      {fo/1e3:+9.2f} kHz  {pj:7.1f} dBFS/Hz  (+{d:5.1f} dB)")
        print_shape(s["f"], s["p"])


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    pl = sub.add_parser("listen")
    pl.add_argument("--freq", type=int, required=True)
    pl.add_argument("--gain", type=lambda s: int(s, 0))
    pl.add_argument("--packets", type=int, default=4096)
    pl.set_defaults(fn=cmd_listen)

    pg = sub.add_parser("gain")
    pg.add_argument("--freq", type=int, required=True)
    pg.add_argument("--codes", default="0x00,0x20,0x40,0x60,0xa0,0xc0")
    pg.add_argument("--packets", type=int, default=2048)
    pg.add_argument("--settle", type=float, default=0.15)
    pg.set_defaults(fn=cmd_gain)

    pr = sub.add_parser("retune")
    pr.add_argument("--freqs", type=lambda s: [int(v) for v in s.split(",")],
                    required=True)
    pr.add_argument("--gain", type=lambda s: int(s, 0), default=0x40)
    pr.add_argument("--packets", type=int, default=2048)
    pr.add_argument("--settle", type=float, default=0.15)
    pr.set_defaults(fn=cmd_retune)

    ps = sub.add_parser("scan")
    ps.add_argument("--start", type=int, default=400_000)
    ps.add_argument("--stop", type=int, default=30_000_000)
    ps.add_argument("--step", type=int, default=250_000)
    ps.add_argument("--gain", type=lambda s: int(s, 0), default=0x40)
    ps.add_argument("--packets", type=int, default=256)
    ps.add_argument("--settle", type=float, default=0.04)
    ps.set_defaults(fn=cmd_scan)

    pt = sub.add_parser("tiny")
    pt.add_argument("--freq", type=int, default=15_230_000,
                    help="DFE centre frequency")
    pt.add_argument("--tone-offset", type=int, default=250_000,
                    help="tone offset from the DFE centre (Hz)")
    pt.add_argument("--level", type=float, required=True,
                    help="source level dialled into the tinySA (dBm)")
    pt.add_argument("--codes", default="0x00,0x40,0x60,0x80,0xa0,0xc0")
    pt.add_argument("--packets", type=int, default=2048)
    pt.add_argument("--settle", type=float, default=0.25)
    pt.add_argument("--cw-bw", type=float, default=5000.0,
                    help="bandwidth for the CNR figure (Hz)")
    pt.add_argument("--save", default="", help="prefix to dump raw iq16")
    pt.set_defaults(fn=cmd_tiny)

    pf = sub.add_parser("file")
    pf.add_argument("files", nargs="+")
    pf.set_defaults(fn=cmd_file)

    pn = sub.add_parser("noise")
    pn.add_argument("--freq", type=int, required=True)
    pn.add_argument("--gain", type=lambda s: int(s, 0), default=0x40)
    pn.add_argument("--packets", type=int, default=20480)
    pn.set_defaults(fn=cmd_noise)

    a = ap.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
