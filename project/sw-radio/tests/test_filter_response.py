"""Analytic regression for the 62.5 MSPS CIC25/FIR47 cascade."""
import cmath
import math
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def coefficients(name: str) -> list[int]:
    raw = [int(word, 16) for word in (ROOT / "common" / name).read_text().split()]
    half = [word - 65536 if word & 0x8000 else word for word in raw]
    return half + half[-2::-1]


def cascade_db(h: list[int], fs_adc: float, rate: int, frequency: float) -> float:
    if frequency == 0:
        cic = 1.0
    else:
        x = math.pi * frequency / fs_adc
        cic = abs(math.sin(rate * 2 * x) / (rate * 2 * math.sin(x))) ** 5
    fs_fir = fs_adc / rate
    fir = abs(sum(c * cmath.exp(-2j * math.pi * frequency * n / fs_fir)
                  for n, c in enumerate(h))) / sum(h)
    return 20 * math.log10(max(cic * fir, 1e-300))


def metrics(name: str, fs_adc: float, rate: int) -> tuple[float, float]:
    h = coefficients(name)
    passband = [cascade_db(h, fs_adc, rate, i * 500_000 / 4000)
                for i in range(4001)]
    stopband = [cascade_db(h, fs_adc, rate, 750_000 + i * 500_000 / 4000)
                for i in range(4001)]
    return max(passband) - min(passband), max(stopband)


class TestFilterResponse(unittest.TestCase):
    def test_cic25_fir47_response(self):
        ripple, stop = metrics("fir_cic25_comp47_q15.hex", 62_500_000, 25)
        self.assertLess(ripple, 0.03)
        self.assertLess(stop, -95.0)

        baseline_ripple, baseline_stop = metrics(
            "fir_cic16_comp47_q15.hex", 40_000_000, 16)
        self.assertLess(ripple - baseline_ripple, 0.01)
        self.assertLess(stop - baseline_stop, 0.1)


if __name__ == "__main__":
    unittest.main()
