# 1 MHz shortwave DFE: CIC 18/20-bit + 47-tap FIR

This is an **optional DFE architecture** for a 40 MSPS, **12-bit direct-sampling ADC**. The original `common/sys_sw_dfe.v` is intentionally unchanged. The replacement entry point is `common/sys_sw_dfe_1mhz.v`.

## Signal path and integration

| Stage | Original DFE | 1 MHz monitoring DFE |
| --- | --- | --- |
| External ADC | 12 bits, 40 MSPS | **12 bits, 40 MSPS (unchanged)** |
| NCO and multiplier | 32-bit phase NCO, 12-bit sine/cosine, 12x12 to 16 bits | **Unchanged** |
| CIC | N=5, M=2, R=20, 43-bit internal, 16-bit cut | N=5, M=2, R=16, 41-bit internal, **18/20-bit rounded cut** |
| CIC output | 2.000 MSPS | 2.500 MSPS |
| FIR | 31-tap, decimate by 2, single MAC | 47-tap, symmetric, decimate by 2, single time-shared MAC, 2 synchronous RAM reads |
| IQ output | 1.000 MSPS complex | **1.250 MSPS complex** |
| Supported monitoring span | Severe edge droop at +/-500 kHz | **Center +/-500 kHz**, with +/-500..625 kHz transition/guard |
| Interface | signed 32-bit I and Q | signed 32-bit I and Q, valid strobes |

Switch top-level instantiation to `sys_sw_dfe_1mhz`, set `CIC_BITS=20` (default) or `18`. `ADC_OFFSET_BINARY=0` expects the same signed 12-bit two's-complement samples as the original; set it to 1 **only** for a real offset-binary ADC. Do not assume which convention a specific ADC uses without checking its interface. Clock must remain 40 MHz for the stated frequency bounds.

**Compatibility notes:** The IQ sample rate changes from 1.0 to 1.25 MSPS (32-bit I and Q payload grows from 64 to 80 Mbit/s before transport overhead). Software must use the correct sample rate and explicitly retain only the center 1 MHz for measurement. The NCO's `dsp_nco_rom_sin45.txt` and `dsp_nco_rom_cos45.txt` must be generated/supplied by the existing project flow; they were not checked into the original common repository. The unchanged NCO/mixer and external ADC are not replaced by this patch.

## FIR implementation and sizing

The 47-tap signed Q15 coefficients are stored in `common/fir_cic16_comp47_q15.hex`: 24 values representing the first 23 symmetric pairs and center coefficient. The center coefficient is `0x7fff`, and the symmetric sum is 27495, equivalent to a **-1.52 dB coefficient-only DC gain** relative to 32768. This is intentional to avoid 16-bit coefficient overflow while flattening CIC droop; downstream absolute gain calibration is required when comparing raw ADC-unit magnitudes.

`dsp_fir_dec_sym` forms `(x[n-k] + x[n-(46-k)]) * h[k]` for k=0..22 and multiplies the center sample once. It uses a `W_DIN+1`-bit signed preadder, one signed `(W_DIN+1)x16` multiplier, full-precision accumulator and round-to-nearest/ties-to-even when producing 32 bits. At decimation R=16 there are 32 ADC clocks per FIR output, enough for 24 MACs plus pipeline clocks. Startup outputs are suppressed until at least 47 CIC input samples have filled the ring buffer.

Two 64-sample synchronous memory copies permit two reads and one write per channel without a 47-way flip-flop multiplexer. A technology-independent Yosys `memory_collect` run successfully inferred **3 memories (two data buffers plus coefficient ROM) and one multiplier** for a 20-bit FIR. Estimated, per I/Q channel:

| Component | Original 31-tap FIR | New 47-tap FIR, 20-bit |
| --- | ---: | ---: |
| Data RAM capacity | 32x16 = 512 bits | 2x(64x20) = **2560 bits** |
| Coefficient storage | 32x16 = 512 bits | 24x16 = **384 bits** |
| Parallel multiplier operators | 1 of 16x16 | 1 of **21x16** |
| MAC cycles/output | ~31 | **24** (plus read/output pipeline) |

For both I and Q, estimate **four small block-RAM banks** for FIR sample history if the target FPGA can pack 64x20 in one block per bank, and **two signed 21x16 multipliers** at RTL. Such multipliers *may* consume as many as four 18x18-class physical DSP blocks in total, depending on device family and mapping; the original 12x12 NCO mixer multipliers are unchanged. **These are mapping estimates, not verified Quartus ALM/DSP/M9K or fMAX numbers.** The 18-bit variant saves 10% sample RAM width and shortens adders; it may not save a DSP block because its symmetric preadder is still 19 bits wide. FPGA part number and a real place-and-route are necessary for a credible ALM count and timing sign-off.

## Reproducible RTL tests

Requirements: Python 3 + NumPy + SciPy, Icarus Verilog (`iverilog`, `vvp`). From the repository root:

```sh
python3 sim/dfe_1mhz_tb/run.py --full
# or: make -C sim/dfe_1mhz_tb test
```

The testbench feeds identical deterministic **16-bit post-mixer** samples into 3 actual RTL chains: original CIC16/FIR31, optimized CIC18/FIR47, optimized CIC20/FIR47. The external ADC remains **12-bit in both synthesizable top-level designs**, but the noise injection is *after* the unmodified mixer to isolate CIC/FIR losses. **Do not interpret these filtered-noise results as measured RF receiver SNR, ADC ENOB, or 12-bit ADC dynamic range.**

- Clock 40 MSPS; 262,144 input samples per case; seven cases, including three random-noise seeds, 450 kHz edge, 550 kHz guard-band tone, 750 kHz stopband blocker, and 30k-amplitude stress.
- Wanted tone amplitude 16000 LSB in 16-bit post-mixer data, input AWGN RMS 3.3 LSB, exact same waveform sent to all three chains; stress test uses 30000 LSB.
- Coherent FFT/least-squares window: 4096 samples at 1.0 MSPS versus 5120 samples at 1.25 MSPS, both 4.096 ms. ROI is **+/-500 kHz**, full two-sided complex-output equivalent analysis for one real I/Q branch.
- The script compares every FIR implementation against an independent floating-point direct FIR convolution of its **observed RTL CIC output**; all tested signals have output RMSE under 0.60 output LSB after pipeline phase alignment. Full-precision CIC outputs from the 18- and 20-bit variants are compared bit-for-bit.
- `sim/dfe_1mhz_tb/results.json` contains machine-readable per-case SNR, tone RMS, phase alignment, attenuation and filter transfer function metrics.

### Measured digital results

| Condition | Original CIC16/FIR31 | CIC18/FIR47 | CIC20/FIR47 |
| --- | ---: | ---: | ---: |
| 237.061 kHz, seed 1, in-band SNR | 79.44 dB | 86.51 dB | **86.64 dB** |
| Mean SNR, 4 AWGN band cases | 79.53 dB | 86.51 dB | **86.63 dB** |
| Gain relative to original, mean | reference | +6.98 dB | **+7.10 dB** |
| Full CIC internal-precision reference (same new FIR) | n/a | n/a | approx. 86.64 dB |

Frequency-response calculations use the exact committed integer coefficients and analytic CIC response, both normalized to unity at DC:

| Property | Measured / calculated |
| --- | ---: |
| New CIC+FIR gain ripple, DC to 500 kHz | **0.01753 dB peak-to-peak** |
| New CIC+FIR stopband, 750 kHz to 1.25 MHz | **worst -96.79 dB** |
| Original at 500 kHz | **-1.96 dB** |
| Original at 550 kHz | **-9.38 dB** |
| Original at 600 kHz | **-24.18 dB** |

**Guard-band caveat:** 550 kHz is still inside the new 625 kHz output Nyquist band, so it is a *transition-band* signal, not a 96 dB-rejected blocker. Software discards that portion of the spectrum; if hardware rejection at **550 kHz** is mandatory, the response specification or output rate/filter length must change. The -96.79 dB requirement starts at 750 kHz, where content would otherwise alias into the monitored central region. The whole cascade response is not a guarantee of suppression of arbitrary large blockers before the ADC or the mixer.

## What 12-bit ADC can and cannot achieve

An ideal 12-bit ADC's *full-Nyquist* sine quantization-limited SNR is `6.02*12+1.76 = 74.0 dB` over a real 0..20 MHz Nyquist band at 40 MSPS. Under a flat, uncorrelated quantization-noise assumption, integrating only **1 MHz** of that noise yields another `10 log10(20 MHz / 1 MHz) = 13.01 dB`, or an **approximately 87 dB ideal upper benchmark** for a full-scale sinusoid and this monitoring bandwidth, before analog nonlinearity, ENOB loss, ADC clock jitter, NCO spurs, front-end gain, and noise/interference. This estimate is not an independently measured SNR for any actual 12-bit ADC, and DSP cannot recreate information lost at the converter. At narrower FFT resolution bandwidths, the displayed noise floor per bin can be much lower without increasing wideband SFDR.

### Industry reference (vendor specification, not normalized A/B measurements)

| Receiver / vendor specification | Reference point | Why comparison is limited |
| --- | --- | --- |
| [Airspy HF+ Discovery](https://airspy.com/airspy-hf-discovery/) | Cascaded CIC/FIR DDC, 18-bit intermediate output, **108 dBc alias rejection**, HF blocking dynamic range **110 dB** | Sigma-delta IF ADC and active analog preselection, not a 12-bit direct-sampling ADC; RF BDR and digital alias specs differ |
| [WiNRADiO WR-G33DDC](https://winradio.com/home/g33ddc.htm) | **16-bit 100 MSPS** direct-sampling ADC, **4 MHz** DDC bandwidth, vendor-claimed dynamic range **107 dB** | Different ADC resolution, analog preselectors, bandwidth and dynamic-range definition |
| Azure/common optimized DFE (this patch) | **-96.79 dB calculated digital filter stopband**, ~**86.63 dB simulated injected-noise passband SNR** | No antenna/RF measurement, blocker desensitization test or ADC SFDR/ENOB characterization |

In short: the optimized **digital CIC/FIR** approaches industry-style passband flatness and useful alias protection without changing the 12-bit ADC. It does **not** establish commercial-receiver system-level noise figure or 100+ dB blocking dynamic range. Next required hardware validations are: Quartus compile/fMAX and ALM/M9K/DSP occupancy for the exact FPGA, measured 12-bit ADC SNR/SFDR with realistic reference clock jitter, a two-tone blocking/intermodulation test across the HF band, and NCO spur evaluation after downconversion.
