"""Host/control protocol tests independent of third-party FPGA tools."""
import importlib.util
import struct
import unittest
from pathlib import Path

MODULE = Path(__file__).resolve().parents[1] / 'host' / 'sw_radio.py'
spec = importlib.util.spec_from_file_location('sw_radio', MODULE)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class TestProtocol(unittest.TestCase):
    def test_tune_control(self):
        payload = mod.tune_bytes(7_100_000)
        self.assertEqual(payload[:4], b'K9TU')
        self.assertEqual(len(payload), 12)
        hertz, fcw = struct.unpack('<II', payload[4:])
        self.assertEqual(hertz, 7_100_000)
        self.assertAlmostEqual(fcw / 2**32 * 62_500_000, hertz, delta=.008)

    def test_gain_control(self):
        self.assertEqual(mod.gain_bytes(0x80), b'K9AG\x80')
        with self.assertRaises(ValueError): mod.gain_bytes(256)

    def test_iq_v3(self):
        pairs = [(-32768, 32767), (100, -100)] * 128
        header = struct.pack('<4sBBHIIIQI', b'K9IQ', 3, 4, 32,
                             123, 7_100_000, 1_250_000, 8192, 0)
        self.assertEqual(len(header), 32)
        raw = header + b''.join(struct.pack('<hh', *p) for p in pairs)
        packet = mod.parse_iq(raw)
        self.assertEqual(packet['seq'], 123)
        self.assertEqual(packet['sample_index'], 8192)
        self.assertEqual(struct.unpack_from('<hh', packet['data']), pairs[0])

    def test_invalid_header(self):
        with self.assertRaises(ValueError): mod.parse_iq(b'wrong')


if __name__ == '__main__': unittest.main()
