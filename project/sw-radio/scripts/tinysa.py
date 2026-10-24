#!/usr/bin/env python3
"""Minimal SCPI driver for a tinySA (v0.3 hardware, firmware 1.x) used as the
calibrated signal source for the K9+ front-end measurements.

  python tinysa.py cw  --freq 15480000 --level -80
  python tinysa.py off
  python tinysa.py info

The generator needs  mode output  +  modulation off  before  level  has any
effect, and  output on  after the level is dialled in, so that the attenuator
is already correct when the RF switch closes.
"""
import argparse
import time

import serial

PORT = "COM4"
BAUD = 115200


class TinySA:
    def __init__(self, port=PORT, baud=BAUD):
        self.s = serial.Serial(port, baud, timeout=0.4)
        time.sleep(0.35)
        self.s.reset_input_buffer()

    def cmd(self, text, wait=0.45):
        self.s.write((text + "\r").encode())
        time.sleep(wait)
        return self.s.read(8192).decode("utf-8", "replace").replace("\r\n", " | ").strip()

    def cw(self, freq_hz, level_dbm):
        """Configure a CW carrier. Level first, then enable the output."""
        self.cmd("modulation off")
        self.cmd("mode low output")
        self.cmd(f"freq {int(freq_hz)}")
        self.cmd(f"level {level_dbm:g}")
        self.cmd("output on")
        time.sleep(0.15)
        return self.state()

    def off(self):
        self.cmd("output off")
        self.cmd("mode input")
        return self.state()

    def state(self):
        return self.cmd("info", 0.6)

    def close(self):
        self.s.close()


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("cw")
    c.add_argument("--freq", type=float, required=True)
    c.add_argument("--level", type=float, required=True)
    sub.add_parser("off")
    sub.add_parser("info")

    a = ap.parse_args()
    d = TinySA()
    try:
        if a.cmd == "cw":
            print(d.cw(a.freq, a.level)[:400])
        elif a.cmd == "off":
            print(d.off()[:400])
        else:
            print(d.state()[:400])
    finally:
        d.close()


if __name__ == "__main__":
    main()
