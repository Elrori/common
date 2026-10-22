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

For both I and Q, there are **two signed 21x16 multipliers** at RTL. Each fits inside **one Artix-7 DSP48E1 (25x18 signed multiplication)**, so **both 18- and 20-bit variants use two FIR DSP48E1 slices in total**. On XC7A50T the small FIR history arrays map efficiently into **RAM64M distributed RAM**. An XC7-targeted cell-mapping run observed **28 RAM64M and no extra block RAM** across both new FIR lanes; the NCO ROM uses block RAM separately. The 18-bit option reduces distributed RAM width and a few logic resources but does not save a DSP48E1. See the FPGA-specific counts below.

## Hardware target: Artix-7 XC7A50T-FGG484-1

The selected part is **`xc7a50t-fgg484-1`**, as used in the hardware of [Elrori/k9plus-fm-radio](https://github.com/Elrori/k9plus-fm-radio). **Only its FPGA/board hardware is relevant**: its RF converter, DSP architecture, and FM processing are **not reused**. This DFE retains the external **12-bit, 40 MSPS direct-sampling ADC**. The existing K9+ board reference has a **25 MHz oscillator on W19** and does **not** document the required parallel ADC12 pinout; actual ADC data/clock pins, input standard, and sampling-clock synchronization must be specified before hardware implementation. If the ADC provides a source-synchronous 40 MHz clock, constrain that clock and the data arrival times. Do not substitute the 25 MHz board clock without accounting for the ADC clock-domain relationship.

AMD [DS180](https://docs.amd.com/api/khub/documents/2LByHkO~nSZXcei2D55fTg/content) lists the following XC7A50T on-chip capacity: **32,600 LUT, 65,200 FF, 120 DSP48E1 and 150 RAMB18-equivalent blocks (75 RAMB36)**. XC7A50T-FGG484-1 is the speed-grade -1 package target. The open-source Yosys XC7 pass can map RTL to Xilinx primitives, but **it does not run Vivado placement, routing, setup/hold STA or speed-grade-specific timing analysis**.

### FPGA resource comparison: complete, two-channel 12-bit ADC DFE

The complete original and optimized tops were synthesized against the same Yosys 7-series technology library, with generated original NCO LUT data in both cases:

| Mapping statistic | Original CIC16/FIR31 | New CIC18/FIR47 | New CIC20/FIR47 |
| --- | ---: | ---: | ---: |
| Estimated LUTs, including LUTRAM | **1,328** | **1,378** | **1,406** |
| FF (all FD variants) | 1,942 | 1,844 | 1,856 |
| DSP48E1 | **4** | **4** | **4** |
| RAMB18E1 | **6** | **6** | **6** |
| RAM64M / RAM32M | 0 / 6 | 24 / 0 | 28 / 0 |
| CARRY4 | 296 | 312 | 314 |

These totals include **both** I/Q chains, NCO, two 12x12 mixers, CICs, FIRs, and top-level input/output buffers. The **four DSP48E1** comprise **two mixer and two FIR** multipliers. The **six RAMB18E1** are for the existing sine/cosine NCO LUTs; FIR history does not require additional physical Block RAM in this mapping. A RAM64M/RAM32M consumes four LUT resources, hence `estimated LUT = LUT1..LUT6 count + 4*(RAM64M+RAM32M)`. Vivado may optimize resource sharing and LUTRAM packing differently; these are **technology-mapped estimates**, not post-implementation device utilization.

**20-bit compared with 18-bit:** +28 estimated LUTs, +12 FF, **zero extra DSP/Block RAM**. Both are comfortably within this device's available resources; the 20-bit default gives slightly better simulated digital quantization margin (+0.14 dB in the fixed 12-bit ADC case) for negligible cost. Compared with the complete original top, CIC20/FIR47 costs **+78 estimated LUT**, uses **86 fewer FF**, and retains the same four DSP and six NCO ROM BRAM18 blocks. Estimated 20-bit utilization is **4.31% LUT, 2.85% FF, 3.33% DSP and 4.00% RAMB18** *for this DFE alone*. It does not include Ethernet, other DSP functions or a board-level shell.

Isolated FIR cell mapping per lane: original FIR31 **~125 LUT, 170 FF, 1 DSP**; FIR47/18 **~169 LUT, 154 FF, 1 DSP**; FIR47/20 **~183 LUT, 160 FF, 1 DSP**. Thus, the extra filter taps chiefly cost small LUTRAM / address-control resources. A critical timing path **may** instead reside in the five cascaded **41-bit CIC integrator adders**, not the single time-multiplexed FIR DSP. **The 40 MHz clock (25 ns period) is a requirement, not a timing result.** A Vivado 2019.1+ design for the exact `xc7a50t-fgg484-1` must run `synth_design`, `place_design`, `route_design` and `report_timing_summary` with the real ADC interface constraints before any claim of timing closure.

Reproduce **all six** XC7 reports and the machine-readable summary using Python 3/NumPy and Yosys (from the repository root):

```sh
python3 sim/dfe_1mhz_tb/run_xc7_synth.py
```

Outputs: `sim/dfe_1mhz_tb/results_xc7.json` (committed reference numbers) and ignored raw Yosys logs under `sim/dfe_1mhz_tb/.tmp/`. The script regenerates identical NCO ROM contents for both tops, then maps original/new full designs and all three isolated FIRs. The reference numbers are **Yosys architecture estimates; no Vivado installation or physical board run was available here**.

## Reproducible RTL tests

Requirements: Python 3 + NumPy + SciPy, Icarus Verilog (`iverilog`, `vvp`). From the repository root:

```sh
python3 sim/dfe_1mhz_tb/run.py --full
python3 sim/dfe_1mhz_tb/run_adc12.py --full
python3 sim/dfe_1mhz_tb/run_adc12.py --bits 18  # 18-bit quick end-to-end comparison
# or: make -C sim/dfe_1mhz_tb test (runs both full suites)
```

The second test runs the **entire original top-level and the entire optimized top-level**, both with the *same signed 12-bit ADC samples*, the original ROM-based NCO and the original 12x12-to-16-bit multiplier. NCO lookup tables are deterministically generated into the ignored `.tmp` test directory; they are not added as thousands of source lines to the repository. The ADC model quantizes analog test tones plus 0.4 LSB-RMS white voltage noise; the LO is 8 MHz, with NCO dithering enabled. Both outputs are measured as complex I/Q FFTs over the same 4.096 ms period. It also includes combinations of a wanted signal and much stronger 550/750 kHz offsets.

**Full-chain bug exposed and corrected:** in the repository's original `dsp_mul2.v`, the reset branch assigned zero to `aout_b` twice, failing to initialize `bout_b`. In a four-state RTL simulation, `bout_b=X` entered one CIC integrator before its first valid multiplier cycle, making that entire I/Q branch permanently unknown. The branch includes the one-line correction `bout_b <= 0` and uses it in **both** old/new comparison chains. This fix addresses deterministic reset behavior; it does not represent a measured SNR improvement.

The testbench feeds identical deterministic **16-bit post-mixer** samples into 3 actual RTL chains: original CIC16/FIR31, optimized CIC18/FIR47, optimized CIC20/FIR47. The external ADC remains **12-bit in both synthesizable top-level designs**, but the noise injection is *after* the unmodified mixer to isolate CIC/FIR losses. **Do not interpret these filtered-noise results as measured RF receiver SNR, ADC ENOB, or 12-bit ADC dynamic range.**

- Clock 40 MSPS; 262,144 input samples per case; seven cases, including three random-noise seeds, 450 kHz edge, 550 kHz guard-band tone, 750 kHz stopband blocker, and 30k-amplitude stress.
- Wanted tone amplitude 16000 LSB in 16-bit post-mixer data, input AWGN RMS 3.3 LSB, exact same waveform sent to all three chains; stress test uses 30000 LSB.
- Coherent FFT/least-squares window: 4096 samples at 1.0 MSPS versus 5120 samples at 1.25 MSPS, both 4.096 ms. ROI is **+/-500 kHz**, full two-sided complex-output equivalent analysis for one real I/Q branch.
- The script compares every FIR implementation against an independent floating-point direct FIR convolution of its **observed RTL CIC output**; all tested signals have output RMSE under 0.60 output LSB after pipeline phase alignment. Full-precision CIC outputs from the 18- and 20-bit variants are compared bit-for-bit.
- `sim/dfe_1mhz_tb/results.json` contains machine-readable per-case SNR, tone RMS, phase alignment, attenuation and filter transfer function metrics.
- `sim/dfe_1mhz_tb/results_adc12.json` contains the separately measured complete ADC12/NCO/mixer/IQ-chain results. Those tests are software-emulated 12-bit *digitization*, **not physical ADC or RF-front-end measurements**.

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

### Complete 12-bit ADC + NCO + I/Q RTL results

This additional test injects signed **12-bit quantized** ADC samples into the unmodified original and optimized system top modules, using the same 8 MHz NCO, NCO phase dithering and 12x12-to-16-bit multiplier, with the common one-line multiplier reset correction described earlier. An AWGN source of 0.4 ADC LSB RMS is applied **before** quantization. Every case uses 262,144 samples at 40 MSPS and the same 1 MHz analysis region. ADC clipping was **zero in all cases**.

| 12-bit ADC test | Original chain, ROI SINAD | New chain, ROI SINAD | Improvement |
| --- | ---: | ---: | ---: |
| 237 kHz, AWGN seed 1, amplitude 1500 LSB | 70.71 dB | **77.92 dB** | +7.21 dB |
| 237 kHz, AWGN seed 2 | 70.68 dB | **77.94 dB** | +7.26 dB |
| 450 kHz band edge, amplitude 1500 LSB | 70.97 dB | **77.82 dB** | +6.85 dB |
| 237 kHz wanted 350 LSB + 550 kHz blocker 1300 LSB | -1.82 dB | **66.59 dB** | +68.41 dB |
| 237 kHz wanted 350 LSB + 750 kHz blocker 1300 LSB | 58.42 dB | **66.51 dB** | +8.09 dB |

As an additional one-case check, selecting **18-bit CIC** at 237 kHz gives **77.78 dB** instead of the 20-bit default's **77.92 dB**, a 0.14 dB difference in this ADC12/NCO noise setup. The separate output file `results_adc12_18.json` records this comparison; the main `results_adc12.json` contains all five 20-bit cases.

The particularly large **550 kHz** result is a bandwidth/aliasing effect: at the original **1 MSPS** output this nearby blocker aliases to about **450 kHz**, **inside** the monitored band. At the new **1.25 MSPS** output the 550 kHz tone remains in the 500–625 kHz guard region, which is excluded from the 1 MHz measurement. Its amplitude is **not** suppressed by 68 dB inside the raw 1.25 MSPS samples. The receiver application must discard the guard before interpreting a 1 MHz spectrum. Both chains also benefited equally from fixing the original multiplier reset bug; that bug fix is not counted as a gain.

The 750 kHz dual-tone test confirms additional rejection of energy that would fold into the 1 MHz measurement. At the actual digitized noise level, NCO/ADC quantization effects limit end-to-end rejection; do **not** substitute the ideal coefficient-response number (-96.79 dB) for an experimentally observed whole-chain spur-free dynamic-range specification.

For the 1500-LSB sine and 0.4-LSB additive voltage noise used above, the simplified white-noise benchmark after 12-bit quantization is `20 log10((1500/sqrt(2))/sqrt(0.4^2 + 1/12)) + 10 log10(20)`, approximately **79.66 dB for 1 MHz**. The optimized full-chain **77.9 dB** is therefore about 1.7 dB below that idealized figure. This difference includes NCO/mixer and digital implementation effects; it is **not** proof that FIR precision alone costs 1.7 dB, and the noise-whiteness assumption is only an approximation.

## What 12-bit ADC can and cannot achieve

An ideal 12-bit ADC's *full-Nyquist* sine quantization-limited SNR is `6.02*12+1.76 = 74.0 dB` over a real 0..20 MHz Nyquist band at 40 MSPS. Under a flat, uncorrelated quantization-noise assumption, integrating only **1 MHz** of that noise yields another `10 log10(20 MHz / 1 MHz) = 13.01 dB`, or an **approximately 87 dB ideal upper benchmark** for a full-scale sinusoid and this monitoring bandwidth, before analog nonlinearity, ENOB loss, ADC clock jitter, NCO spurs, front-end gain, and noise/interference. This estimate is not an independently measured SNR for any actual 12-bit ADC, and DSP cannot recreate information lost at the converter. At narrower FFT resolution bandwidths, the displayed noise floor per bin can be much lower without increasing wideband SFDR.

### Industry reference (vendor specification, not normalized A/B measurements)

| Receiver / vendor specification | Reference point | Why comparison is limited |
| --- | --- | --- |
| [Airspy HF+ Discovery](https://airspy.com/airspy-hf-discovery/) | Cascaded CIC/FIR DDC, 18-bit intermediate output, **108 dBc alias rejection**, HF blocking dynamic range **110 dB** | Sigma-delta IF ADC and active analog preselection, not a 12-bit direct-sampling ADC; RF BDR and digital alias specs differ |
| [WiNRADiO WR-G33DDC](https://winradio.com/home/g33ddc.htm) | **16-bit 100 MSPS** direct-sampling ADC, **4 MHz** DDC bandwidth, vendor-claimed dynamic range **107 dB** | Different ADC resolution, analog preselectors, bandwidth and dynamic-range definition |
| Azure/common optimized DFE (this patch) | **-96.79 dB calculated digital filter stopband**, ~**86.63 dB simulated injected-noise passband SNR** | No antenna/RF measurement, blocker desensitization test or ADC SFDR/ENOB characterization |

In short: the optimized **digital CIC/FIR** approaches industry-style passband flatness and useful alias protection without changing the 12-bit ADC. It does **not** establish commercial-receiver system-level noise figure or 100+ dB blocking dynamic range. Next required hardware validations are: **Vivado post-route timing/resource reports for XC7A50T-FGG484-1**, measured 12-bit ADC SNR/SFDR with realistic reference clock jitter, a two-tone blocking/intermodulation test across the HF band, and NCO spur evaluation after downconversion.
