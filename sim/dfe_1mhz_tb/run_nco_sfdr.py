#!/usr/bin/env python3
"""Exact NCO RTL output SFDR/near-carrier noise measurements over LO points."""

import argparse
import json
import os
import subprocess

import numpy as np

from run_adc12 import ROOT, TB, TMP, FS, setup_roms

N = 65536
SKIP = 16
MODES = ("12off", "12on", "14off", "14on", "16off", "16on")
# Coherent FFT bins span shortwave and are intentionally not simple 1/4 cycles.
BINS = (4097, 8193, 13107, 20137, 28673)


def compile_rtl():
    files = ["sim/dfe_1mhz_tb/nco_sfdr_tb.v", "common/dsp_nco.v",
             "common/dsp_nco_rom.v", "common/simple_ram.v"]
    env = os.environ.copy()
    env["TMPDIR"] = str(TMP)
    subprocess.run(["iverilog", "-g2012", "-s", "nco_sfdr_tb",
                    "-o", str(TMP / "nco_sfdr_tb.vvp"), *files],
                   cwd=ROOT, env=env, check=True)


def run_bin(k):
    fcw = k * (1 << 16)
    with (TMP / "nco_sfdr_sim.log").open("w") as out:
        subprocess.run(["vvp", str(TMP / "nco_sfdr_tb.vvp"),
                        f"+FCW={fcw}", f"+SAMPLES={N+SKIP}"],
                       cwd=TMP, stdout=out, stderr=subprocess.STDOUT, check=True)
    data = np.loadtxt(TMP / "nco_sfdr_samples.txt", dtype=np.float64)
    assert data.shape == (N + SKIP, 12), data.shape
    data = data[SKIP:]
    result = {"fft_bin": k, "fcw": fcw,
              "lo_hz": k * FS / N, "modes": {}}
    for j, mode in enumerate(MODES):
        complex_nco = data[:, 2*j+1] + 1j * data[:, 2*j]
        spectrum = np.fft.fft(complex_nco)
        tone = abs(spectrum[k])
        spectrum[k] = 0
        spur_index = int(np.argmax(np.abs(spectrum)))
        sfdr = 20*np.log10(tone / abs(spectrum[spur_index]))
        sndr = 10*np.log10(tone*tone / np.sum(np.abs(spectrum)**2))
        nearest = np.zeros(N, dtype=bool)
        radius = int((500_000*N)//FS)
        nearest[(k+np.arange(-radius, radius+1))%N] = True
        nearest[k] = False
        near_snr = 10*np.log10(tone*tone / np.sum(np.abs(spectrum[nearest])**2))
        result["modes"][mode] = {
            "sfdr_db_c": float(sfdr),
            "sndr_whole_nyquist_db": float(sndr),
            "noise_ratio_near_carrier_1mhz_db": float(near_snr),
            "largest_spur_bin": spur_index,
        }
    a = result["modes"]
    # Regression gate for every tested HF LO: higher ROM amplitude precision
    # must measurably lower coherent oscillator spurs, not merely add bits.
    assert a["14on"]["sfdr_db_c"] - a["12on"]["sfdr_db_c"] > 10.0, result
    assert a["16on"]["sfdr_db_c"] - a["14on"]["sfdr_db_c"] > 4.0, result
    assert a["14on"]["sfdr_db_c"] - a["14off"]["sfdr_db_c"] > 20.0, result
    print(f"LO {result['lo_hz']/1e6:6.3f} MHz: dither ON SFDR "
          f"12b={a['12on']['sfdr_db_c']:.2f}, "
          f"14b={a['14on']['sfdr_db_c']:.2f}, "
          f"16b={a['16on']['sfdr_db_c']:.2f} dBc", flush=True)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--full", action="store_true")
    args = parser.parse_args()
    setup_roms()
    compile_rtl()
    cases = [run_bin(k) for k in (BINS if args.full else BINS[:1])]
    if args.full:
        out = TB / "results_nco_sfdr.json"
        result = {
            "method": "Icarus 12/14/16-bit actual NCO RTL, dither on/off; coherent 65536 FFT",
            "sample_rate_hz": FS, "fft_length": N,
            "limitations": "No analog ADC, no complex DFE filter, and no noncoherent LO sweep",
            "frequencies": cases,
        }
        out.write_text(json.dumps(result, indent=2) + "\n")
        print(f"PASS NCO RTL sweep; wrote {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
