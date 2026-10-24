#!/usr/bin/env python3
"""Live monitor: prints the strongest line in the DFE passband once a second.

Lets the operator drive the signal source by hand (menu, knobs) and see the
effect in real time. Ctrl-C to stop.

  python watch_tone.py --freq 15230000 --gain 0x40 --seconds 120
"""
import argparse
import socket
import sys
import time

import numpy as np

sys.path.insert(0, ".")
import rf_probe as R


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--freq", type=int, default=15_230_000)
    ap.add_argument("--gain", type=lambda s: int(s, 0), default=0x40)
    ap.add_argument("--seconds", type=float, default=120)
    a = ap.parse_args()

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("0.0.0.0", R.IQ_PORT))
    sock.settimeout(10.0)
    R.tune(a.freq)
    time.sleep(0.05)
    R.gain(a.gain)
    time.sleep(0.2)

    t0 = time.time()
    print(f"watching DFE {a.freq/1e6:.3f} MHz  gain 0x{a.gain:02x}  "
          f"passband +/-600 kHz, {a.seconds:.0f}s", flush=True)
    print(f"{'t':>6} {'floor':>8} {'peak':>8} {'offset kHz':>11} {'SNR':>6}", flush=True)
    while time.time() - t0 < a.seconds:
        x, hdr = R.capture(1024, sock)
        f, p = R.psd(x)
        med = float(np.median(p))
        j = int(np.argmax(p))
        print(f"{time.time()-t0:6.1f} {med:8.1f} {p[j]:8.1f} {f[j]/1e3:11.2f} "
              f"{p[j]-med:6.1f}", flush=True)
    sock.close()


if __name__ == "__main__":
    main()
