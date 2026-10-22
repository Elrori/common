#!/usr/bin/env python3
"""Bit-true NCO/mixer A/B at the output of the real 1-MHz ADC12 DFE RTL."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import numpy as np

from run_adc12 import (ROOT, TB, TMP, F_BIN, FS, N, N_NEW, GUARD,
                       setup_roms, stimulus, metrics)

CONFIGS = ("12_16", "12_18", "14_18", "16_20")


def compile_testbench():
    files = [
        "sim/dfe_1mhz_tb/dfe_nco_adc12_tb.v",
        "common/sys_sw_dfe_1mhz.v", "common/sys_sw_dfe_1mhz_nco14.v",
        "common/dsp_nco.v", "common/dsp_nco_rom.v", "common/dsp_mul2.v",
        "common/dsp_cic_dec.v", "common/dsp_fir_dec_sym.v", "common/simple_ram.v",
    ]
    env = os.environ.copy()
    env["TMPDIR"] = str(TMP)
    subprocess.run(["iverilog", "-g2012", "-s", "dfe_nco_adc12_tb",
                    "-o", str(TMP / "dfe_nco_adc12_tb.vvp"), *files],
                   cwd=ROOT, env=env, check=True)


def read_iq(config):
    path = TMP / f"out_nco_{config}.txt"
    arr = np.loadtxt(path, dtype=np.float64)
    assert arr.ndim == 2 and arr.shape[1] == 2
    return arr[:, 0] + 1j * arr[:, 1]


def run_case(case):
    clipped = stimulus(case)
    with (TMP / "nco_adc12_sim.log").open("w") as log:
        subprocess.run(["vvp", str(TMP / "dfe_nco_adc12_tb.vvp")],
                       cwd=TMP, stdout=log, stderr=subprocess.STDOUT, check=True)
    result = {**case, "adc_clipped_samples": clipped, "modes": {}}
    for config in CONFIGS:
        samples = read_iq(config)
        result["modes"][config] = metrics(samples, 1_250_000, N_NEW, case["tones"])
    baseline = result["modes"]["12_16"]["inband_sinad_db"]
    for cfg, data in result["modes"].items():
        data["delta_vs_12_16_db"] = data["inband_sinad_db"] - baseline
    labels = " ".join(f"{m}={result['modes'][m]['inband_sinad_db']:.3f}"
                      for m in CONFIGS)
    print(f"{case['name']:<25} {labels} dB, clips={clipped}", flush=True)
    assert clipped == 0
    assert all(np.isfinite(m["inband_sinad_db"]) for m in result["modes"].values())
    count = [m["sample_count"] for m in result["modes"].values()]
    assert len(set(count)) == 1, count
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--full", action="store_true")
    parser.add_argument("--stress", action="store_true",
                        help="Additional ADC input noise to model lower effective resolution")
    args = parser.parse_args()
    f237 = 971 * F_BIN
    f450 = 1843 * F_BIN
    f550 = 2253 * F_BIN
    f750 = 3072 * F_BIN
    cases = [dict(name="237k AWGN seed1", tones=[(f237, 1500)], sigma=0.4, seed=1)]
    if args.stress:
        cases = [
            dict(name="237k analog noise 3LSB", tones=[(f237,1500)], sigma=3.0, seed=1),
            dict(name="237k analog noise 10LSB", tones=[(f237,1500)], sigma=10.0, seed=1),
        ]
    elif args.full:
        cases += [
            dict(name="237k AWGN seed2", tones=[(f237, 1500)], sigma=0.4, seed=2),
            dict(name="450k edge AWGN", tones=[(f450, 1500)], sigma=0.4, seed=1),
            dict(name="550k strong blocker", tones=[(f237,350),(f550,1300)], sigma=0.4, seed=1),
            dict(name="750k strong blocker", tones=[(f237,350),(f750,1300)], sigma=0.4, seed=1),
            dict(name="near-LO strong blocker", tones=[(f237,300),(0.,1500)], sigma=0.4, seed=1),
            dict(name="very weak + 550k", tones=[(f237,50),(f550,1600)], sigma=0.4, seed=1),
            dict(name="237k quant-only", tones=[(f237,1500)], sigma=0., seed=1),
        ]
    setup_roms()
    compile_testbench()
    data = [run_case(c) for c in cases]
    result = {
        "adc_bits": 12, "adc_rate_hz": FS, "adc_samples_per_case": N,
        "nco_bits_mixer_bits": list(CONFIGS), "nco_dither": True,
        "downstream": "unchanged CIC5 R16 M2 20-bit + FIR47 decimate2",
        "methods": "Icarus 4-path complete RTL, identical quantized ADC12 waveform, 1-MHz ROI",
        "limitations": "No real ADC analog nonlinearity, sampling jitter or Vivado timing",
        "cases": data,
    }
    if args.full or args.stress:
        out = TB / ("results_nco_adc12_stress.json" if args.stress else "results_nco_adc12.json")
        out.write_text(json.dumps(result, indent=2) + "\n")
        print(f"PASS; wrote {out.relative_to(ROOT)}", flush=True)
    else:
        print("PASS quick NCO complete ADC12 comparison", flush=True)


if __name__ == "__main__":
    main()
