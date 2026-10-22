#!/usr/bin/env python3
"""Bit-true CIC/FIR regression at 40 MSPS; Icarus + NumPy/SciPy.

Run from anywhere: python3 sim/dfe_1mhz_tb/run.py --full
The ADC remains 12-bit in the synthesizable top.  For filter isolation this
test drives the unchanged mixer's 16-bit *output* with a tone and noise.
"""

import argparse
import json
import os
from pathlib import Path
import subprocess
import statistics
import numpy as np
from scipy.signal import lfilter

ROOT = Path(__file__).resolve().parents[2]
TB = Path(__file__).resolve().parent
FS_IN = 40_000_000
N_IN = 262144
N_OLD = 4096
N_FAST = 5120
GUARD = 350
DEFAULT_AMP = 16000
DEFAULT_SIGMA = 3.3


def coefficients(filename):
    raw = [int(s, 16) for s in (ROOT / filename).read_text().split()]
    return np.array([v-65536 if v & 0x8000 else v for v in raw], dtype=np.float64)


def compile_rtl():
    tmp = TB / ".tmp"
    tmp.mkdir(exist_ok=True)
    env = os.environ.copy()
    env["TMPDIR"] = str(tmp)
    files = [
        "sim/dfe_1mhz_tb/dfe_chain_tb.v",
        "common/dsp_cic_dec.v", "common/dsp_fir_dec.v",
        "common/dsp_fir_dec_sym.v", "common/simple_ram.v",
        "common/simple_rom.v",
    ]
    subprocess.run(["iverilog", "-g2012", "-s", "dfe_chain_tb", "-o",
                    str(TB / "dfe_chain_tb.vvp"), *files], cwd=ROOT,
                   env=env, check=True)


def make_stimulus(k, seed, amp, sigma):
    rng = np.random.default_rng(seed)
    n = np.arange(N_IN, dtype=np.float64)
    f = k * 1_000_000/N_OLD
    x = amp*np.sin(2*np.pi*f*n/FS_IN)
    if sigma:
        x += rng.normal(0, sigma, size=N_IN)
    x = np.clip(np.rint(x), -32768, 32767).astype(np.int16)
    with (TB / "stimulus.hex").open("w") as out:
        out.writelines(f"{int(v)&0xffff:04x}\n" for v in x)
    return float(f)


def read_rtl():
    paths = {key: TB / f"out_{key}.txt" for key in (
        "old_cic", "18_cic", "20_cic", "old_fir", "18_fir", "20_fir")}
    cic = {k: np.loadtxt(v, dtype=np.int64) for k, v in paths.items()
           if "cic" in k}
    fir = {}
    for k, p in paths.items():
        if "fir" in k:
            # The legacy FIR's unfilled initial sample RAM produces X words.
            fir[k] = np.array([
                float(s) if s.lstrip("-").isdigit() else np.nan
                for s in p.read_text().splitlines()], dtype=np.float64)
    return cic, fir


def fit_tone(y, k, nfft, fs, roi_hz=500_000):
    y = np.asarray(y[-nfft-GUARD:-GUARD], dtype=np.float64)
    assert len(y) == nfft and np.all(np.isfinite(y)), "FIR produced X/no data"
    n = np.arange(nfft, dtype=np.float64)
    basis = np.stack((np.sin(2*np.pi*k*n/N_OLD*1_000_000/fs),
                      np.cos(2*np.pi*k*n/N_OLD*1_000_000/fs),
                      np.ones_like(n)), axis=1)
    coefs = np.linalg.lstsq(basis, y, rcond=None)[0]
    tone = basis[:, :2] @ coefs[:2]
    residual = y-basis@coefs
    signal_power = np.mean(tone**2)
    # Output-rate-specific Nyquist and common 1 MHz monitoring ROI.
    spectrum = np.fft.fft(residual)/nfft
    freqs = np.fft.fftfreq(nfft, 1/fs)
    noise_all = np.sum(np.abs(spectrum)**2)
    noise_roi = np.sum(np.abs(spectrum[np.abs(freqs)<=roi_hz])**2)
    return {
        "tone_rms": float(np.sqrt(signal_power)),
        "snr_full_db": float(10*np.log10(signal_power/noise_all)),
        "snr_roi_db": float(10*np.log10(signal_power/noise_roi)),
        "resid_rms": float(np.sqrt(noise_all)),
    }


def verify_filter_rtl(name, ci, yr, h, scale):
    # Compare the actual registered MAC against exact convolution followed by
    # the RTL's integer output scaling.  Account for pipeline/decimation phase.
    x = ci[:, 1].astype(np.float64)
    best = (float("inf"), None, None)
    for phase in (0, 1):
        expected = lfilter(h, [1.0], x)[phase::2]/scale
        for lag in range(-8, 9):
            a = yr[-1800:-GUARD]
            # Match the *tail* of each stream, since the legacy FIR has
            # an extra registered valid latency compared with the new FIR.
            ii = np.arange(-1800, -GUARD)+len(expected)+lag
            if len(a)==0 or ii.min()<0 or ii.max()>=len(expected):
                continue
            b = expected[ii]
            rmse = float(np.sqrt(np.mean((a-b)**2)))
            if rmse < best[0]:
                best = (rmse, phase, lag)
    if best[0]>0.60:
        raise AssertionError(f"{name}: RTL/golden FIR mismatch: {best}")
    return {"rmse_output_lsb":best[0], "phase":best[1], "lag":best[2]}


def frequency_response():
    old = coefficients("sim/dfe_1mhz_tb/legacy_fir_comp31.hex")[:31]
    half = coefficients("common/fir_cic16_comp47_q15.hex")
    new = np.r_[half, half[-2::-1]]
    assert len(new)==47 and np.array_equal(new, new[::-1])
    def response(f, r, fs_cic, h):
        with np.errstate(divide="ignore", invalid="ignore"):
            cic = (np.abs(np.sin(np.pi*r*2*f/FS_IN)/
                          (r*2*np.sin(np.pi*f/FS_IN)))**5)
        cic[f==0] = 1.0
        # FIR at the output of CIC (f[Hz], fs_cic[Hz]).
        coeff_freq = np.exp(-2j*np.pi*np.outer(f, np.arange(len(h)))/fs_cic)
        fir = np.abs(coeff_freq @ h)/np.sum(h)
        return 20*np.log10(np.maximum(cic*fir, 1e-300))
    fp = np.linspace(0, 500_000, 10001)
    sp = np.linspace(750_000, 1_250_000, 10001)
    new_pass = response(fp, 16, 2_500_000, new)
    new_stop = response(sp, 16, 2_500_000, new)
    old_at = response(np.array([400e3,450e3,500e3,550e3,600e3]),
                      20,2_000_000,old)
    out = {
        "new_pass_peak_to_peak_db":float(np.ptp(new_pass)),
        "new_pass_min_db":float(np.min(new_pass)),
        "new_pass_max_db":float(np.max(new_pass)),
        "new_stop_max_db":float(np.max(new_stop)),
        "old_400_450_500_550_600_khz_db":old_at.tolist(),
        "coef_sum_old":int(sum(old)), "coef_sum_new":int(sum(new)),
    }
    assert out["new_pass_peak_to_peak_db"] < 0.12, out
    assert out["new_stop_max_db"] < -85.0, out
    return out, old, new


def run_case(case, old_h, new_h):
    k, seed = case["k"], case["seed"]
    f = make_stimulus(k, seed, case["amp"], case["sigma"])
    with (TB / "sim_output.log").open("w") as log:
        subprocess.run(["vvp", str(TB / "dfe_chain_tb.vvp")], cwd=ROOT,
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    cic, fir = read_rtl()
    assert len(cic["old_cic"]) > 13000
    assert len(cic["20_cic"]) > 16300
    assert np.array_equal(cic["18_cic"][:,0],cic["20_cic"][:,0])
    verification = {
        "old": verify_filter_rtl("old", cic["old_cic"], fir["old_fir"], old_h,32),
        "18":verify_filter_rtl("18",cic["18_cic"],fir["18_fir"],new_h,256),
        "20":verify_filter_rtl("20",cic["20_cic"],fir["20_fir"],new_h,1024),
    }
    metrics = {
        "old":fit_tone(fir["old_fir"],k,N_OLD,1_000_000),
        "18":fit_tone(fir["18_fir"],k,N_FAST,1_250_000),
        "20":fit_tone(fir["20_fir"],k,N_FAST,1_250_000),
    }
    # The full-precision CIC is an upper bound on the attainable SNR with
    # precisely the same inputs, coefficients and decimation.
    ideal = lfilter(new_h,[1.0],cic["20_cic"][:,0].astype(float)/(2**21))[1::2]/1024
    metrics["full_cic_ideal"] = fit_tone(ideal,k,N_FAST,1_250_000)
    result = {**case,"freq_hz":f,"metrics":metrics,"rtl_verification":verification,
              "cic_counts":{"old":len(cic["old_cic"]),"new":len(cic["20_cic"])}}
    print(f"{f/1000:8.3f} kHz seed={seed:2d} sigma={case['sigma']:.1f}: "
          f"ROI SNR old={metrics['old']['snr_roi_db']:.2f}, "
          f"18={metrics['18']['snr_roi_db']:.2f}, "
          f"20={metrics['20']['snr_roi_db']:.2f} dB; "
          f"MAC RMSE={verification['20']['rmse_output_lsb']:.3f} LSB")
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--full",action="store_true",help="3 seeds + band edges + blockers")
    args = parser.parse_args()
    profile, old_h, new_h = frequency_response()
    print("FREQUENCY_RESPONSE", json.dumps(profile, sort_keys=True))
    compile_rtl()
    cases = [{"k":971,"seed":1,"amp":DEFAULT_AMP,"sigma":DEFAULT_SIGMA}]
    if args.full:
        cases += [
            {"k":971,"seed":2,"amp":DEFAULT_AMP,"sigma":DEFAULT_SIGMA},
            {"k":971,"seed":3,"amp":DEFAULT_AMP,"sigma":DEFAULT_SIGMA},
            {"k":1843,"seed":1,"amp":DEFAULT_AMP,"sigma":DEFAULT_SIGMA},
            {"k":2253,"seed":1,"amp":DEFAULT_AMP,"sigma":0.0}, # 550 kHz
            {"k":3072,"seed":1,"amp":DEFAULT_AMP,"sigma":0.0}, # 750 kHz
            {"k":1843,"seed":1,"amp":30000,"sigma":0.0},
        ]
    all_cases = [run_case(case,old_h,new_h) for case in cases]
    band_cases = [c for c in all_cases if c["sigma"] and c["k"] in (971,1843)]
    band_snr = {
        key: float(statistics.mean(c["metrics"][key]["snr_roi_db"]
                                   for c in band_cases))
        for key in ("old","18","20","full_cic_ideal")
    }
    ref = all_cases[0]["metrics"]
    for c in all_cases:
        if c["sigma"] == 0.0 and c["k"] in (2253,3072):
            # These are rejection measurements, not meaningful SNR tests:
            # a clean out-of-band tone has no in-band wanted signal.
            c["relative_tone_attenuation_db"] = {
                key:float(20*np.log10(c["metrics"][key]["tone_rms"] /
                                          ref[key]["tone_rms"]))
                for key in ("old","18","20")
            }
            if c["k"] == 3072:
                assert c["relative_tone_attenuation_db"]["20"] < -90
    output = {"assumptions":{"fs_adc":FS_IN,"adc_bits":12,"mixer_bits":16,
               "post_mixer_awgn_rms_lsb":DEFAULT_SIGMA,"input_tone_amplitude":DEFAULT_AMP,
               "baseline_fs_out":1_000_000,"optimized_fs_out":1_250_000,
               "fft_seconds":N_OLD/1_000_000},
              "response":profile,
              "mean_inband_snr_db":band_snr,
              "mean_inband_snr_gain_18_db":band_snr["18"]-band_snr["old"],
              "mean_inband_snr_gain_20_db":band_snr["20"]-band_snr["old"],
              "cases":all_cases}
    (TB/"results.json").write_text(json.dumps(output,indent=2,allow_nan=False)+"\n")
    print("PASS all CIC/FIR bit-true regressions; results in",TB/"results.json")


if __name__ == "__main__":
    main()
