# HF 1 MHz DFE: 12-bit ADC, NCO14/mixer18 RTL optimization

Target: **XC7A50T-FGG484-1**, 40 MSPS external **12-bit** direct-sampling ADC, complex I/Q **1.25 MSPS**, monitored baseband **-500 to +500 kHz**. This is a follow-on to [CIC20/FIR47](dfe_1mhz.md). The legacy `sys_sw_dfe` and the default `sys_sw_dfe_1mhz` configuration are not replaced.

## Changed algorithm, not the ADC

The two complex mixer lanes now accept independent ADC and oscillator widths, and the 1 MHz DFE takes independently parameterized NCO and mixer output widths. The optional deployable top is **`sys_sw_dfe_1mhz_nco14`**:

| Stage | Prior 1 MHz reference | Main candidate | Higher precision comparison |
|---|---|---|---|
| ADC | 12-bit, 40 MSPS | **unchanged** | **unchanged** |
| NCO | 12-bit, 15 address bits, 32 phase bits | **14-bit**, Q13 ROM | **16-bit**, Q15 ROM |
| NCO dither | enabled, `DITHER_MAX=8` | unchanged | unchanged |
| Signed complex mixer | 12×12 => 24-bit product => rounded 16-bit | **12×14 => 26-bit product => rounded 18-bit** | **12×16 => 28-bit product => rounded 20-bit** |
| CIC | N=5, R=16, M=2, 41-bit accumulator, 20-bit cut | **43-bit accumulator, 20-bit cut** | **45-bit accumulator, 20-bit cut** |
| FIR | 47 taps, Q15, decimate 2 | **unchanged** | **unchanged** |
| Output | 32-bit I/Q at 1.25 MSPS | unchanged | unchanged |

Scaling is intentionally preserved at the CIC output. The old 24-to-16-bit mixer rounds away 8 low product bits; the 26-to-18 and 28-to-20 paths also round away 8 bits. A 14-bit NCO therefore gives approximately 4× the mixer numerical amplitude, but the CIC's BOUT-to-20-bit cut also shifts by 2 additional bits, so the FIR sees the **same signal scale**. Likewise the 16/20 path multiplies by 16 and cuts by 4 additional bits. A 12/18 control path isolates mixer rounding without increasing NCO precision.

The 4096-word first-45-degree sin/cos ROMs are regenerated deterministically by `sim/dfe_1mhz_tb/gen_nco_rom.py`; all eight-way quadrant/angle reconstruction is the existing `dsp_nco_rom` implementation. The wider path does **not** change oscillator phase accumulator width or fractional tune resolution.
The 32-bit phase accumulator still resolves a 40 MSPS tuning step of `40e6 / 2^32 = 0.009313 Hz`; this change improves generated sample accuracy/spurs, **not frequency-setting granularity**.

## Actual 32-bit-phase NCO RTL SFDR

Icarus runs **six parallel synthesizable NCOs** (12/14/16-bit, dither off/on). The 65,536-point coherent complex FFT sees all spectral bins at 40 MSPS; results are largest-spur SFDR in dBc relative to the fundamental. The tested FCWs are coherent FFT-bin multiples; these are *not* a claim of the worst-case SFDR at every possible tuning word.

| LO (MHz) | 12-bit dither ON | 14-bit dither ON | 16-bit dither ON |
|---:|---:|---:|---:|
| 2.501 | 101.19 | **113.68** | 121.19 |
| 5.001 | 101.17 | **113.53** | 121.41 |
| 8.000 | 101.68 | **114.52** | 121.17 |
| 12.291 | 101.47 | **114.75** | 120.93 |
| 17.501 | 101.51 | **114.98** | 121.19 |

At these points, **12 -> 14 bits increases SFDR by ~12–13 dB**. The no-dither cases all have a dominant phase-truncation spur at **86.39 dBc**. Enabling dither spreads that coherent spur into noise; this improves SFDR but *slightly reduces* integrated wideband NCO SNDR. At 8 MHz the full-Nyquist-band NCO-only SNDR is **73.55 / 81.49 / 83.23 dB** for 12/14/16-bit dither-on. These oscillator-only metrics are **not the RF receiver sensitivity or ADC SNR**.

Machine-readable sweep: [`results_nco_sfdr.json`](../sim/dfe_1mhz_tb/results_nco_sfdr.json).

## XC7A50T primitive mapping (Yosys XC7)

This is a **comparative synthesis estimate**, not a placed/routed Vivado utilization or 40 MHz timing guarantee. Logic LUT includes estimated LUTRAM mapping, and RAMB18 counts 36K blocks as two 18K equivalents.

| Real RTL top | Estimated LUT | FF | DSP48E1 | RAMB18 equivalents | CARRY4 |
|---|---:|---:|---:|---:|---:|
| `sys_sw_dfe_1mhz` (12/16, CIC20) | 1406 | 1856 | 4 | 6 | 314 |
| `sys_sw_dfe_1mhz_mix18` (12/18) | 1444 | 1920 | 4 | 6 | 316 |
| **`sys_sw_dfe_1mhz_nco14` (14/18)** | **1462** | **1928** | **4** | **8** | **318** |
| `sys_sw_dfe_1mhz_nco16` (16/20) | 1512 | 2000 | 4 | 8 | 338 |

The 14/18 upgrade costs **+56 LUT (+4.0% over this DFE), +72 FF, +2 RAMB18, and zero extra DSPs** versus the 12/16 CIC20/FIR47 baseline. The new DFE itself occupies an estimated 4.48% of 32,600 XC7A50T LUTs, 2.96% of 65,200 FFs, 3.33% of 120 DSPs, and 5.33% of 150 18K BRAM equivalents; the rest of the radio and peripherals are **not included**.

Machine-readable cell counts and full mapped log files: [`results_xc7.json`](../sim/dfe_1mhz_tb/results_xc7.json) and ignored `sim/dfe_1mhz_tb/.tmp/xc7_*.log` after a run.

## End-to-end ADC12 RTL comparison

Every candidate uses **exactly the same signed 12-bit ADC stream**, including ADC quantization and optional Gaussian input voltage noise. Four *complete* Verilog receiver chains (NCO, mixer, CIC20, FIR47) execute concurrently for 262,144 ADC samples per case. The 8 MHz LO is `phi_inc=858993459`; the test uses a 5,120-sample complex FFT at 1.25 MSPS after startup and excludes a 350-sample tail guard. SINAD counts *all* residual power in the ±500 kHz monitored region except the wanted coherent tone as noise/distortion, including leaked blockers. Frequency offset is from LO. It is not a calibrated physical ADC ENOB test.

| ADC12 case | Prior 12/16 (dB) | 12/18 (dB) | **14/18 (dB)** | 16/20 (dB) | **14/18 gain** |
|---|---:|---:|---:|---:|---:|
| 237 kHz, noise 0.4 LSB, seed 1 | 77.915 | 77.976 | **79.314** | 79.422 | **+1.398 dB** |
| 237 kHz, noise 0.4 LSB, seed 2 | 77.940 | 78.002 | **79.457** | 79.510 | **+1.517 dB** |
| 450 kHz, passband edge | 77.823 | 77.886 | **79.312** | 79.373 | **+1.489 dB** |
| 237 kHz weak + 550 kHz blocker | 66.586 | 66.626 | **66.834** | 66.852 | **+0.248 dB** |
| 237 kHz weak + 750 kHz blocker | 66.511 | 66.555 | **66.789** | 66.783 | **+0.279 dB** |
| 237 kHz weak + 0 Hz LO-centered blocker | 64.852 | 64.880 | **65.558** | 65.489 | **+0.706 dB** |
| 237 kHz *very weak* + 550 kHz blocker | 49.593 | 49.627 | **49.845** | 49.851 | **+0.251 dB** |
| 237 kHz, ideal quantization only | 80.077 | 80.215 | **83.077** | 83.245 | **+3.000 dB** |

The 14/18 path wins **all eight tested cases**, with no ADC clipping and exactly matching I/Q sample strobes across the four paths. The three ordinary AWGN signal cases each gain **+1.40 to +1.52 dB**, and the quantization-only case gains **+3.00 dB**. Increasing *only* mixer output to 18 bits typically gains just **0.03–0.14 dB**: the main improvement is a purer oscillator. The 16/20 path consumes further fabric but raises ordinary-signal SINAD by only ~0.05–0.11 dB over 14/18; it can be slightly worse under some blocker conditions due to different quantization/dither noise realizations.

For historical context, the *original* `sys_sw_dfe` 1.0 MSPS path measured **70.71 dB** on the same first ADC12 stimulus, compared with **77.92 dB** after the earlier CIC20/FIR47 1.25 MSPS upgrade and **79.31 dB** after this NCO14/mixer18 upgrade. The resulting approximately **+8.6 dB** is the combination of *both separate architectural changes*, not an improvement attributable to NCO width alone.

In the LO-centered blocker case the **DC FFT bin is subtracted before SINAD**, so this case tests the ADC/DSP consequences of a large LO-centered input; its displayed SINAD must not be read as rejection of the DC blocker itself. At 550/750 kHz, the FIR and CIC stopband/guard-band response dominate residual leakage, not NCO precision. In-band interferers are themselves counted as undesired power and cannot be removed by additional NCO bits.

Raw per-case results: [`results_nco_adc12.json`](../sim/dfe_1mhz_tb/results_nco_adc12.json). Strong-neighbor SINAD and isolated-NCO SFDR describe different quantities and must not be interchanged.

### Effective-resolution/noisy-ADC pressure test

Additional analog input voltage noise was added **before** exactly the same 12-bit rounding and four RTL chains (no ADC clipping):

| ADC additive noise RMS | 12/16 SINAD | 14/18 SINAD | Difference |
|---:|---:|---:|---:|
| 0.4 LSB | 77.915 dB | 79.314 dB | **+1.398 dB** |
| 3.0 LSB | 63.838 dB | 63.867 dB | **+0.029 dB** |
| 10.0 LSB | 53.440 dB | 53.437 dB | **-0.003 dB** |

The 10-LSB result is numerically a tiny regression, not a claim of improvement. Once *analog* noise dominates the budget, widening the *digital* NCO changes in-band SNR by essentially nothing. Actual ADC ENOB, clock jitter and RF interference could make that regime realistic. At the same time, NCO spur/headroom benefits remain meaningful for high-dynamic-range spectral observation, even when the receiver noise floor is set by hardware. Raw data: [`results_nco_adc12_stress.json`](../sim/dfe_1mhz_tb/results_nco_adc12_stress.json).

## Industry receiver context (not a like-for-like score)

- The [FlexRadio FLEX-6400/FLEX-6600 official hardware reference](https://www.flexradio.com/wp-content/uploads/assets/FLEX-6400-and-FLEX-6600-Hardware-Reference-Manual.pdf) specifies 16-bit ADCs, 122.88/245.76 MSPS, and receiver reciprocal-mixing dynamic range of 110 dB at 1 kHz and 116 dB at 2 kHz offsets. **RMDR is a complete radio/analog phase-noise measurement, so it must not be compared numerically with our bare digital NCO SFDR or simulated 1 MHz SINAD.**
- [Red Pitaya STEMlab 125-14](https://redpitaya.com/stemlab-125-14/) is an example of a 14-bit, 125 MSPS direct-sampling platform. A wider commercial ADC can raise the receiver's analog dynamic-range ceiling; digital widening cannot recover analog information absent from our 12-bit ADC stream.

Our measured **114 dBc NCO SFDR** is a *digital oscillator* spur metric, not a claim that the complete 12-bit RF receiver has 114 dB SFDR. Real HF performance also depends on analog preselection, LNA/compression, ADC ENOB/SFDR, sampling-clock phase noise and input level.

## Reproduce and deploy

From the repository root (requires Python 3, NumPy, Icarus Verilog; Yosys for resource mapping):

```bash
python3 sim/dfe_1mhz_tb/gen_nco_rom.py --verify
python3 sim/dfe_1mhz_tb/run_nco_sfdr.py --full
python3 sim/dfe_1mhz_tb/run_nco_adc12.py --full
python3 sim/dfe_1mhz_tb/run_nco_adc12.py --stress
python3 sim/dfe_1mhz_tb/run_xc7_synth.py
make -C sim/dfe_1mhz_tb test  # prior CIC20/FIR47 and legacy regression
```

Select `sys_sw_dfe_1mhz_nco14` as the new integration top (or instantiate `sys_sw_dfe_1mhz` with `NCO_BITS=14`, `MIX_BITS=18` and both supplied Q13 ROM paths). The I/Q port contract and ADC width are identical to the prior optional 1 MHz DFE. Maintain the existing 12/16 top as a comparison/fallback. Before committing to a PCB/bitstream, run **Vivado implementation/timing at 40 MHz**, validate the ROM file paths in the project, and measure over-air/real ADC captures with varying LO and RF interferer power. There are no physical-hardware RF measurements in this study.
