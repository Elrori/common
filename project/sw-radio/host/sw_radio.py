#!/usr/bin/env python3
"""Zero-dependency K9+ SDR LAN control, packet validation and IQ16 capture.

Examples:
  python sw_radio.py tune 7100000 --target 192.168.10.255
  python sw_radio.py gain 0x20 --target 192.168.10.255
  python sw_radio.py receive --packets 100 --output mycapture.iq16
"""
import argparse
import socket
import struct
import sys
from pathlib import Path

SAMPLE_RATE = 1_250_000
ADC_RATE = 62_500_000
IQ_PER_PACKET = 256
K9IQ_PACKET_SIZE = 32 + IQ_PER_PACKET * 4
CONTROL_PORT = 50001
IQ_PORT = 50003


def tune_bytes(hertz: int) -> bytes:
    if not 0 <= hertz <= 30_000_000:
        raise ValueError("tuning supported from 0 to 30 MHz (direct sampling)")
    phase_increment = round(hertz * 2**32 / ADC_RATE) & 0xFFFFFFFF
    return b"K9TU" + struct.pack("<II", hertz, phase_increment)


def gain_bytes(code: int) -> bytes:
    if not 0 <= code <= 255:
        raise ValueError("AD8370 code must be 0..255")
    return b"K9AG" + bytes((code,))


def parse_iq(payload: bytes) -> dict:
    if len(payload) != K9IQ_PACKET_SIZE:
        raise ValueError(f"expected {K9IQ_PACKET_SIZE} bytes, received {len(payload)}")
    if payload[:4] != b"K9IQ" or payload[4] != 3 or not payload[5] & 4:
        raise ValueError("not a K9IQ v3 I16/Q16 packet")
    if struct.unpack_from("<H", payload, 6)[0] != 32:
        raise ValueError("invalid app header length")
    sequence, tune, samplerate = struct.unpack_from("<III", payload, 8)
    sample_index, drops = struct.unpack_from("<QI", payload, 20)
    if samplerate != SAMPLE_RATE:
        raise ValueError(f"incorrect sample rate {samplerate}")
    return dict(seq=sequence, tuned_hz=tune, sample_index=sample_index,
                dropped_samples=drops, adc_overrange=bool(payload[5] & 2),
                data=payload[32:])


def transmit(payload: bytes, target: str) -> None:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.sendto(payload, (target, CONTROL_PORT))
    print(f"sent {payload[:4].decode()} to {target}:{CONTROL_PORT}")


def receive(packets: int, output: Path | None, bind: str) -> None:
    last_index = None
    gaps = 0
    prev_drops = 0
    sink = output.open("wb") if output else None
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.bind((bind, IQ_PORT))
            sock.settimeout(10.0)
            for i in range(packets):
                payload, peer = sock.recvfrom(4096)
                try:
                    pkt = parse_iq(payload)
                except ValueError as exc:
                    print(f"skipped {peer}: {exc}", file=sys.stderr)
                    continue
                if last_index is not None and pkt["sample_index"] != last_index:
                    gaps += 1
                    print(f"gap: expected={last_index}, received={pkt['sample_index']}")
                last_index = pkt["sample_index"] + IQ_PER_PACKET
                prev_drops = pkt["dropped_samples"]
                if sink:
                    sink.write(pkt["data"])
                if i % 100 == 0:
                    print(f"#{i} seq={pkt['seq']} tune={pkt['tuned_hz']}Hz "
                          f"sample={pkt['sample_index']} dropped={prev_drops} "
                          f"adc_overrange={pkt['adc_overrange']}")
    finally:
        if sink:
            sink.close()
    print(f"packets={packets}, discontinuities={gaps}, FPGA_dropped_samples={prev_drops}")


def main() -> None:
    cli = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = cli.add_subparsers(dest="operation", required=True)
    p_tune = sub.add_parser("tune")
    p_tune.add_argument("hertz", type=int)
    p_tune.add_argument("--target", default="192.168.10.255")
    p_gain = sub.add_parser("gain")
    p_gain.add_argument("code", type=lambda s: int(s, 0))
    p_gain.add_argument("--target", default="192.168.10.255")
    p_read = sub.add_parser("receive")
    p_read.add_argument("--packets", type=int, default=100)
    p_read.add_argument("--output", type=Path)
    p_read.add_argument("--bind", default="0.0.0.0")
    args = cli.parse_args()
    if args.operation == "tune": transmit(tune_bytes(args.hertz), args.target)
    elif args.operation == "gain": transmit(gain_bytes(args.code), args.target)
    else: receive(args.packets, args.output, args.bind)


if __name__ == "__main__":
    main()
