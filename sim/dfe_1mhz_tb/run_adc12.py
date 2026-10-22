#!/usr/bin/env python3
"""End-to-end 12-bit ADC -> NCO -> mixer -> CIC -> FIR regression.

This deliberately exercises both unmodified original top and optimized top.
The ADC model is ideal signed 12-bit quantization plus optional Gaussian
voltage noise; analog filters, nonlinearities and clock jitter are excluded.
"""

import argparse
import json
from pathlib import Path
import subprocess
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
TB = Path(__file__).resolve().parent
TMP = TB / ".tmp"             # all temporary NCO ROMs stay git-ignored
FS = 40_000_000
N = 262144
LO_HZ = 8_000_000
PHI_INC = 858993459
N_OLD = 4096
N_NEW = 5120
GUARD = 350
F_BIN = 1_000_000/N_OLD


def setup_roms():
    TMP.mkdir(exist_ok=True)
    link = TMP / "common"
    if not link.exists() and not link.is_symlink():
        link.symlink_to(ROOT / "common", target_is_directory=True)
    assert link.resolve() == (ROOT / "common").resolve()
    # ADDR_WIDTH=15 SMALL_ROM stores the first 45 degrees at addresses
    # 1..4096; add=0 is handled separately by the original NCO RTL.
    angle = 2*np.pi*np.arange(1,4097)/32768
    for name, signal in (("dsp_nco_rom_sin45.txt",np.sin(angle)),
                         ("dsp_nco_rom_cos45.txt",np.cos(angle))):
        values = np.clip(np.rint(2047*signal),-2048,2047).astype(int)
        (TMP/name).write_text("".join(f"{int(v)&0xfff:03x}\n" for v in values))
    (TMP/"fir_comp_coe.txt").write_text(
        (TB/"legacy_fir_comp31.hex").read_text())


def compile_rtl(cic_bits):
    files = [
        "sim/dfe_1mhz_tb/dfe_adc12_tb.v",
        "common/sys_sw_dfe.v", "common/sys_sw_dfe_1mhz.v",
        "common/dsp_nco.v", "common/dsp_nco_rom.v", "common/dsp_mul2.v",
        "common/dsp_cic_dec.v", "common/dsp_fir_dec.v",
        "common/dsp_fir_dec_sym.v", "common/simple_ram.v",
        "common/simple_rom.v",
    ]
    import os
    env = os.environ.copy()
    env["TMPDIR"] = str(TMP)
    subprocess.run(["iverilog","-g2012","-Wall","-s","dfe_adc12_tb",
                    "-P",f"dfe_adc12_tb.CIC_BITS={cic_bits}",
                    "-o",str(TMP/"dfe_adc12_tb.vvp"),*files],cwd=ROOT,
                   env=env,check=True)


def stimulus(case):
    n = np.arange(N,dtype=float)
    t = n/FS
    amplitude = np.zeros(N,dtype=float)
    for f,amp in case["tones"]:
        amplitude += amp*np.sin(2*np.pi*(LO_HZ+f)*t + 0.123)
    if case["sigma"]:
        amplitude += np.random.default_rng(case["seed"]).normal(
            0,case["sigma"],size=N)
    raw = np.rint(amplitude)
    clipping = int(np.count_nonzero((raw > 2047)|(raw < -2048)))
    raw = np.clip(raw,-2048,2047).astype(np.int16)
    (TMP/"adc12.hex").write_text("".join(f"{int(x)&0xfff:03x}\n" for x in raw))
    return clipping


def read_iq(name):
    samples = []
    for line in (TMP/f"out_adc12_{name}.txt").read_text().splitlines():
        parts = line.split()
        if len(parts) != 2 or any(not p.lstrip("-").isdigit() for p in parts):
            samples.append(complex(np.nan,np.nan))
        else:
            samples.append(complex(float(parts[0]),float(parts[1])))
    return np.array(samples,dtype=np.complex128)


def metrics(y,fs,span,tones):
    section = y[-span-GUARD:-GUARD]
    assert len(section)==span and np.all(np.isfinite(section))
    # Remove DC, retain mirror/image artifacts in the measured noise budget.
    section = section-np.mean(section)
    z = np.fft.fft(section)/span
    f = np.fft.fftfreq(span,1/fs)
    mask = abs(f)<=500_000
    whole_roi = float(np.sum(abs(z[mask])**2))
    lines = {}
    for freq,_ in tones:
        # Complex downconversion can choose either spectral orientation.
        index = np.argmin(abs(f - ((freq+fs/2)%fs-fs/2)))
        opposite = np.argmin(abs(f - ((-freq+fs/2)%fs-fs/2)))
        mag = max(abs(z[index]),abs(z[opposite]))
        lines[str(round(freq,6))] = float(mag)
    wanted = float(lines[str(round(tones[0][0],6))]) if tones else 0.0
    desired_bin = float(wanted**2)
    noise_roi = max(whole_roi-desired_bin,1e-300)
    return {
        "complex_tone_amplitudes":lines,
        "strongest_tone_amplitude":wanted,
        "inband_sinad_db":float(10*np.log10(desired_bin/noise_roi)) if wanted else None,
        "roi_rms":float(np.sqrt(whole_roi)),
        "sample_count":len(y),
    }


def run_case(case):
    clipped = stimulus(case)
    with (TMP/"adc12_sim.log").open("w") as log:
        subprocess.run(["vvp",str(TMP/"dfe_adc12_tb.vvp")],cwd=TMP,
                       stdout=log,stderr=subprocess.STDOUT,check=True)
    old = metrics(read_iq("old"),1_000_000,N_OLD,case["tones"])
    new = metrics(read_iq("new"),1_250_000,N_NEW,case["tones"])
    result={**case,"adc_clipped_samples":clipped,"old":old,"new":new}
    improvement = new["inband_sinad_db"] - old["inband_sinad_db"]
    result["inband_sinad_improvement_db"] = float(improvement)
    print(f"{case['name']:20s} clip={clipped}: "
          f"ROI SINAD original={old['inband_sinad_db']:.2f}, "
          f"new={new['inband_sinad_db']:.2f} dB; "
          f"tone_rms={old['strongest_tone_amplitude']:.1f}/"
          f"{new['strongest_tone_amplitude']:.1f}",flush=True)
    assert clipped==0,"ADC clipping invalidates the noise comparison"
    assert improvement > (40 if case["name"] == "550k strong blocker" else 5), (
        "CIC/FIR regression degraded the monitored 1 MHz band", result)
    return result


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--full",action="store_true")
    parser.add_argument("--bits",type=int,choices=(18,20),default=20,
                        help="CIC output width of optimized top")
    args=parser.parse_args()
    f237=971*F_BIN
    f450=1843*F_BIN
    f550=2253*F_BIN
    f750=3072*F_BIN
    cases=[dict(name="ADC12 237k AWGN",tones=[(f237,1500)],sigma=0.4,seed=1)]
    if args.full:
        cases += [
            dict(name="ADC12 237k seed2",tones=[(f237,1500)],sigma=0.4,seed=2),
            dict(name="ADC12 450k edge",tones=[(f450,1500)],sigma=0.4,seed=1),
            dict(name="550k strong blocker",tones=[(f237,350),(f550,1300)],sigma=0.4,seed=1),
            dict(name="750k strong blocker",tones=[(f237,350),(f750,1300)],sigma=0.4,seed=1),
        ]
    setup_roms()
    compile_rtl(args.bits)
    results=[run_case(case) for case in cases]
    output={"fs_adc":FS,"adc_bits":12,"cic_bits":args.bits,
            "lo_hz":LO_HZ,"nco_phi_inc":PHI_INC,
            "nco_dither":True,"adc_model":"ideal rounding to signed 12-bit and Gaussian voltage noise",
            "adc_noise_sigma_lsb":0.4,"limitations":"No analog RF front end, jitter, ENOB impairment, or real FPGA timing",
            "cases":results}
    filename="results_adc12.json" if args.bits==20 else "results_adc12_18.json"
    (TB/filename).write_text(json.dumps(output,indent=2)+"\n")
    print("PASS complete ADC12 end-to-end simulations",flush=True)


if __name__=="__main__":
    main()
