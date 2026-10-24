# SW-Radio | K9+ FPGA / 40 MSPS ADC / Gigabit Ethernet / HDSDR

The `k9plus_ext` ADC/AD8370 mezzanine pin map is in
`constraints/adc_ad8370_k9plus_ext.xdc`. It was supplied for the connected
hardware and bench-tested on 2026-10-23 with an XC7A50T K9+/XI050CD board,
Xilinx Platform Cable USB and PHY0 Ethernet. The obsolete deliberately unsafe
placeholder file remains only as branch history and is not read by the build.

This is a self-contained Vivado *source/project template* in the branch
`feature/dfe-nco14-mixer18-adc12`. It reuses the present `common/` DSP RTL;
only its Ethernet MAC RTL is vendored. Physical target:
`xc7a50t-fgg484-1` (Colorlight K9+ / XI050CD hardware as referenced in
`Elrori/k9plus-fm-radio`). AD8370 control RTL comes from the supplied
`spi8370` attachment. The Ethernet PHY0 RX IDELAY12 / TX ODDR configuration
and pins are drawn from the board-proven FM-radio hardware design.

## Current handoff status (2026-10-24)

This section is the starting point for the next engineer or AI. Do not infer
that "no audible station" means the FPGA stream is dead, and do not discard
the present uncommitted work. The complete ADC -> DFE -> Ethernet -> ExtIO
path is operating. The open problem is **live short-wave sensitivity / noise
and blocking**, most likely in the antenna and analog/EMI environment rather
than in the frequency-control or I/Q RTL.

### Last known live state

- The final bitstream is `build/sw_radio_k9plus_ext.bit`, SHA-256
  `D7E1FA2DDD4110424D72A948CF8ADCA937D364332168636D5EB81FEB9185D561`.
- It was loaded by volatile JTAG after the most recent power interruption;
  Vivado reported startup `HIGH` on `xc7a50t_0`.
- The FPGA was finally left tuned to **15,230,000 Hz** with AD8370 code
  **`0xA0`**. A 512-packet check then had zero sequence discontinuities,
  zero FPGA sample drops and `adc_overrange=false`. A power cycle loses the
  bitstream and requires `./program.ps1` again.
- HDSDR was deliberately stopped while command-line capture owned UDP/50003.
  Reopen it manually when needed. The user explicitly asked the agent not to
  use computer-use/UI automation; use scripts and let the user operate HDSDR.
- Windows HDSDR 2.81a is in `C:\Program Files (x86)\HDSDR`. Installed
  receivers are `ExtIO_SWRadio.dll`, `ExtIO_RTL.dll` and
  `ExtIO_SDRplay_RSP1.dll`. SDRplay API 3.15 and its service are installed;
  a connected RSP1 was successfully opened by HDSDR at 2 MSPS.

### What has been proved on RF

1. A tinySA source connected to this ADC board at 9.9 MHz, -76 dBm, AM 1 kHz
   was captured with the DFE centered at 9.8 MHz and gain `0x60`. The measured
   carrier was 9,899,959.37 Hz; the two sidebands were about +/-1 kHz and
   -15.8 dBc. There was no I16 clipping, UDP gap or FPGA drop. This is direct
   proof that the physical AD9226, ADC bus interpretation, NCO/mixer, filters
   and IQ transport preserve AM modulation.
2. The user heard a clear broadcast at **15,230 kHz** using the RSP1, while
   the FPGA/HDSDR display mainly showed a narrow peak. Direct FPGA captures
   nevertheless detected the same carrier near **15,229.96 kHz**. With DFE
   centers of 15.130, 15.230 and 15.330 MHz it appeared at approximately
   +99.96, 0 and -100.04 kHz respectively. This rules out an NCO scale, sign
   or ExtIO tune-command error.
3. At 15.230 MHz, increasing gain raised the carrier and noise normally. The
   carrier was about 20--22 dB above the spectral-bin median around `0xA0` to
   `0xC0`, but the broadcast audio sidebands were buried in broadband noise;
   a 3.36-second AM-envelope analysis did not yield intelligible speech. This
   explains the "peak but no station" symptom without blaming I/Q format.
4. Gain `0xC0` is marginal and has asserted OTR in one live run; `0xE0`
   asserted it. The final `0xA0` run was clean. OTR is sticky until FPGA reset
   or reprogramming, so a later lower gain does not clear an earlier event.

Useful evidence remains in `build/` and is intentionally not source control:

- `iq_tinysa_9p9m_am1k_gain60.iq16` -- known-good injected AM proof;
- `iq_station_center_15130000.iq16`, `...15230000...`, `...15330000...` --
  carrier-following-tune proof;
- `iq_15p230_station_long_gainC0.iq16` -- long live-station capture;
- `iq_final_15p230_gainA0.iq16` -- final clean status check after JTAG load.

### Analog front end versus KiwiSDR

The ADC board source is at
`C:\Users\Administrator\OneDrive\doc\work\mix\ad9226-ext`; its rendered
schematic is `kicad0.2\ad9226-ext.pdf`. It copies the KiwiSDR-style 30 MHz
Chebyshev input LPF, but it is not electrically identical to the complete
Kiwi receiver:

- this board uses an AD8370 variable-gain IF amplifier and a 12-bit AD9226 at
  40 MSPS; KiwiSDR uses a fixed +20 dB LTC6401-20 ADC driver and a 14-bit
  LTC2248 at 65 MSPS;
- Kiwi documents another roughly 40 MHz LC filter after its preamplifier,
  quiet LDO supplies, a local low-jitter ADC oscillator and RF shielding;
- this setup forwards 40 MHz from the FPGA across the mezzanine and operates
  beside FPGA/RGMII digital activity. Its 5 V supply, ground return, clock
  coupling, shielding and output matching have not yet been measured;
- neither receiver supplies a good antenna by itself. It is not yet confirmed
  that the RSP1 and FPGA comparisons used exactly the same antenna, feed line,
  adapters, grounding and time. Public Kiwi installations commonly benefit
  from quiet outdoor antennas and locations.

Reference design description and current vendor data:

- <https://github.com/jks-prv/KiwiSDR> (official repository links its design
  review and schematics);
- <https://www.analog.com/en/products/ltc2248.html>;
- <https://www.analog.com/en/products/ltc6401-20.html>;
- <https://www.analog.com/en/products/ad9226.html>;
- <https://www.analog.com/en/products/ad8370.html>.

The previous known-working ADC/antenna reference is
`E:\doc\WORK_SPACE\mix\ebaz4205-ad9226`. Also inspected was
`E:\doc\WORK_SPACE\mix\ebaz4205-ad9235-eth-sdr`; it is an older prototype
and is not the authoritative ADC data-format reference.

### Recommended next experiments, in order

1. Make a controlled RSP1/FPGA A/B test using the same antenna, feed line and
   adapters at nearly the same time (ideally through a suitable splitter).
   Record RSP1 bandwidth/gain/AGC and do not compare only waterfall colors.
2. Capture at gain `0xA0` first with a **50 ohm termination**, then with the
   antenna. If the noise floor barely rises, investigate antenna/feed/matching;
   if it rises strongly and is full of fixed lines, investigate local RFI,
   power, grounding and FPGA/Ethernet coupling.
3. Repeat the tinySA test at 15.230 MHz with AM 1 kHz while stepping roughly
   -110 to -60 dBm. Tune the DFE to 15.130 MHz so the signal is at +100 kHz,
   away from DC. This measures an actual demodulation threshold and separates
   analog sensitivity from propagation and antenna uncertainty.
4. Measure ADC-board 5 V/3.3 V noise, the 40 MHz clock at the ADC and analog
   common-mode levels. Try a clean supply, shorter ground/clock connection and
   temporary RF shielding before changing DFE RTL.
5. If strong broadcast/MW energy causes OTR, add an MW reject/high-pass or a
   15 MHz band-pass preselector. Raising AD8370 gain alone amplifies blockers
   and broadband noise and is not equivalent to the RSP1 front end.

For a repeatable command-line check, close HDSDR first so UDP/50003 is free:

```powershell
Get-Process HDSDR -ErrorAction SilentlyContinue | Stop-Process -Force
./program.ps1
python host/sw_radio.py tune 15130000
python host/sw_radio.py gain 0xA0
python host/sw_radio.py receive --packets 4096 --output build/check_15p230.iq16
```

The reusable tools in `scripts/` avoid repeating ad-hoc notebook commands:

- `rf_probe.py` performs live gain, retune, scan, noise and calibrated-tone
  measurements, or analyzes saved IQ16 files;
- `analyze_spectrum.py` and `am_demod.py` inspect saved captures and can
  produce an independent AM/SSB audio check;
- `mds_test.py`, `tinysa.py` and `watch_tone.py` support controlled source
  sweeps (verify the tinySA serial port and displayed RF level before use);
- `antenna_match.py` is a first-order whip/input-network model, not a VNA
  measurement; `parse_sch.py` extracts connectivity from the local KiCad
  source to help audit the assumed component network.

## Data path

```text
25 MHz oscillator -> MMCM: 40 MHz ADC/sample clock + 200 MHz IDELAY reference
40 MHz AD9226 12-bit two's-complement parallel data
       -> IOB capture of the raw signed bus (no MSB inversion)
       -> NCO14 / signed 18-bit mixer (32-bit frequency word)
       -> 5-stage CIC, R=16, M=2, CIC output 20 bits
       -> 47-tap symmetric/compensated FIR, R=2, 32-bit result
       -> signed 16-bit saturating quantizer (right shift 5)
       -> 2,048 x 32-bit asynchronous FIFO (atomic I/Q)
       -> K9IQ version-3 UDP/IP Ethernet II frame
       -> verilog-ethernet MAC (CRC/preamble/IFG) -> RGMII PHY0
       -> host UDP port 50003 -> ExtIO_SWRadio.dll -> HDSDR

Ethernet control UDP port 50001 -> RGMII parser -> acknowledged CDC
    -> NCO FCW and user-supplied spi8370 module -> AD8370 gain
```

40 MSPS / 16 / 2 = **1.25 MSPS complex I/Q**; monitor the central
**1 MHz (±500 kHz)** while using the ±500..625 kHz margins as FIR guard bands.
The Ethernet IQ16 payload is **5.00 MB/s, 40.0 Mbit/s before framing**. It
is not raw ADC12 samples. Because the source ADC remains 12-bit, 16-bit
network samples do **not** imply 16-bit ADC ENOB; they preserve DFE headroom.

## Build (Windows / Vivado)

The project deliberately uses reproducible **non-project mode**: no generated
`.xpr`, no machine-dependent absolute source paths, no downloads during build.
Vivado includes the XPM FIFO and CDC libraries.

```powershell
# In a Xilinx/Vivado command prompt with vivado.bat and XILINX_VIVADO set:
cd project\sw-radio
    .\build.ps1 -SynthOnly      # synth / utilization / timing
    .\build.ps1                 # synth, place, route, write bitstream
    .\program.ps1               # volatile JTAG load; does not write flash
```

On Linux, `bash project/sw-radio/build.sh --synth-only` or
`bash project/sw-radio/build.sh` (requires installed Vivado).
Build artifacts go to `project/sw-radio/build/`:

- `post_synth.dcp`, `routed.dcp`, utilization, timing and DRC reports;
- `sw_radio_k9plus_ext.bit` after a full successful build.

Vivado 2019.1 synthesis, placement, routing, bitstream generation, volatile
JTAG programming, live UDP streaming and the HDSDR ExtIO callback path have
all been exercised on the target hardware. Continue to use the post-route
timing/DRC reports and verify the connected module voltage before applying a
bitstream to another board revision.

## Pin mapping and tested board assumptions

| Interface | Status | File |
| --- | --- | --- |
| K9+ 25 MHz W19 | Reference board verified | `constraints/k9plus_phy0.xdc` |
| PHY0 RGMII W4/V4, AA1..AB5 | Reference board verified | `constraints/k9plus_phy0.xdc` |
| 12 parallel ADC data pins + OTR | Connected and live-tested | `constraints/adc_ad8370_k9plus_ext.xdc` |
| FPGA → ADC 40 MHz clock | Connected; IOB capture and post-route timing pass | same |
| AD8370 SDA/SCK/CS | Connected; live gain response and OTR boundary tested | same |

The fitted converter is the user's **AD9226** module.  Comparison against its
previously working EBAZ4205 design and live A/B captures confirms that the
module is strapped for **two's complement**, so the raw 12-bit bus goes into
the signed mixer without flipping bit 11.  The K9+ mezzanine was verified with
an in-phase 40 MHz forwarded clock; changing its polarity stopped the IQ
stream on this physical module.  AD9226 clock-to-data limits (3.5..7.0 ns) are
constrained in `constraints/adc_ad8370_k9plus_ext.xdc`, and post-route setup
and hold must pass before a bitstream is emitted.  OTR is connected and carried
as a sticky UDP status bit.  There is no ADC RF anti-alias or input protection
in the FPGA; the front end and preselector remain hardware concerns.

## Wire protocol (K9+ compatible transport, new payload version)

Ethernet destination broadcast `FF:FF:FF:FF:FF:FF`, source MAC
`02:4B:39:2B:01:03`; IPv4 source `192.168.10.2`, destination
`192.168.10.255`; UDP source/dest `50003`; frames contain one UDP app header
followed by **256 complex signed I16/Q16 samples**. Destination port 50001 is
reserved for control. The host needs a NIC on the `192.168.10.x/24` network
and firewall permission for inbound UDP/50003. UDP checksum is zero (allowed
in IPv4); Ethernet FCS is appended by the MAC.

32-byte payload header, little endian except fixed ASCII fields:

| Offset | Size | Field | Meaning |
| ---: | ---: | --- | --- |
| 0 | 4 | `K9IQ` | Magic |
| 4 | 1 | 3 | Protocol version (**not** FM v2/I8) |
| 5 | 1 | Flags | bit2 signed I16/Q16; bit0 FPGA sample drops |
| 6 | 2 | 32 | Header bytes |
| 8 | 4 | Sequence | Packet sequence, wraps modulo 2³² |
| 12 | 4 | Tune Hz | ADC-derived center frequency |
| 16 | 4 | 1,250,000 | Complex sample rate |
| 20 | 8 | Sample index | Complex samples emitted in previous frames |
| 28 | 4 | Dropped sample count | Atomic FIFO overflows since reset |
| 32 | 1024 | IQ data | I16LE, Q16LE, repeated 256 times |

UDP payload length 1056 bytes (32+1024); UDP header `length=1064`
(0x0428); IP total length 1084 (0x043c); Ethernet frame data length 1098
(excluding preamble/FCS). Frequency control payloads sent as UDP/50001:

```text
Tune: 'K9TU' + uint32LE frequency_hz + uint32LE (round(frequency_hz*2^32/40e6) mod 2^32)
Gain: 'K9AG' + uint8 AD8370 raw gain code, 0..255
```

Control parser validates EtherType IPv4, protocol UDP, destination port
50001 and the command magic before triggering once per frame. It does not
authenticate commands, validate IPv4 checksums, or parse VLAN/options;
use **an isolated SDR LAN**, not an untrusted network. Gain starts at the
headroom-oriented AD8370 code `0x40`; live antenna tests found `0xa0` clean,
`0xc0` marginal and `0xe0` overrange. A sufficiently strong input can of
course move those limits.
Host gain commands may be coalesced if issued rapidly while SPI
is busy. The current control parser assumes Ethernet II + 20-byte IPv4.

```shell
python3 project/sw-radio/host/sw_radio.py tune 7100000
python3 project/sw-radio/host/sw_radio.py gain 0x20
python3 project/sw-radio/host/sw_radio.py receive --packets 100 --output monitor.iq16
```

For HDSDR (32-bit Windows), open `ExtIO/ExtIO_SWRadio.vcxproj` in Visual Studio
2022 with the x86 C++ desktop workload and build **Release|Win32**, or run
`ExtIO/build_extio.ps1` in a Developer PowerShell. Copy the resulting
`ExtIO_SWRadio.dll` into HDSDR's application directory. Type 3 means signed
interleaved 16-bit IQ, the DLL feeds 512 complex samples per callback from
two UDP frames; `GetHWSR()` returns 1,250,000. Set
`SW_RADIO_CONTROL_HOST` (e.g. `192.168.10.255`) if a different control target
is needed. On Linux with MinGW-W64, the optional `ExtIO/build_mingw.sh`
produces an x86 DLL with undecorated ExtIO exports and static C++ runtime.
The Windows x86 DLL has been compiled with MSVC, its undecorated exports have
been inspected, and HDSDR 2.81a has loaded it as a 16-bit/1.25-MSPS ExtIO.
A two-second ABI smoke test delivered 4,890 callbacks and 2,503,680 complex
samples from the live FPGA. Click HDSDR's **SDR-Device** button to open the
built-in AD8370 gain panel. Its 0..255 slider and Low/Default/High presets send
`K9AG` immediately; the panel also displays the packetized sticky ADC OTR flag.
AD8370 codes are not monotonic across the entire unsigned 0..255 range: bit 7
selects the high-gain range and bits 6..0 contain its magnitude. In particular
`0x80` has zero magnitude and nearly mutes the input. The present presets are
Low `0x20`, Default `0x40`, High `0x60`; the last name means "higher preset",
not the AD8370 high-gain range. Use the slider for `0xa0`. Approximate gains
are `0x60` 14.6 dB, `0xa0` 22 dB, `0xc0` 28 dB, `0xe0` 31.6 dB and `0xff`
34 dB. Treat OTR as sticky until FPGA reset/reprogramming.
On a Public-profile SDR NIC, allow inbound
UDP/50003 only for HDSDR and remote address `192.168.10.2`.

## Tests and verified scope

Run `bash project/sw-radio/tests/run_rtl.sh` with Icarus Verilog 12+ and
Python 3.10+ installed. It executes:

1. UDP frame length, IPv4 header/checksum field, UDP length, IQ16 ordering,
   FIFO pop count, 256 samples and AXI-Stream stall/backpressure.
2. Ethernet control `K9TU`/`K9AG` parsing and exactly one tune/gain event.
3. Supplied AD8370 SPI sequencer: 8-bit MSB-first transmission, completion,
   serial clock and latch behavior.
4. NCO14 quadrature (two ROMs, 5 MHz 32-bit FCW, dither on).
5. 40 MSPS end-to-end DFE 5 MHz tone, aligned I/Q strobes and ~1.25 MSPS.
6. Top-level RTL elaboration, using black boxes for Xilinx-specific primitives.
7. Python protocol unit tests for tune FCW, gain range, signed IQ16 and v3.

The source-level simulations are complemented by a Vivado 2019.1 post-route
build and target-board checks. On the tested board, routing completed with no
unrouted nets, setup/hold timing passed, the PHY streamed without sequence
gaps in a 500-packet capture, AD8370 gain changed the measured ADC level, and
ADC OTR propagated into the UDP status flags. The HDSDR-specific callback path
was also exercised with the live FPGA stream. Receiver sensitivity, dynamic
range and demodulated audio still depend on the antenna, RF environment and
the exact ADC module fitted to the board.

## Files and upstream acknowledgments

- `rtl/` integrates DFE, RGMII, FIFO, UDP packetizer and user-provided `spi8370`.
- `vendor/verilog-ethernet/{axis_gmii_tx.v,lfsr.v,COPYING}` is from
  [alexforencich/verilog-ethernet](https://github.com/alexforencich/verilog-ethernet)
  (license retained), used in the reference K9+ build.
- FPGA MAC and PHY0 wiring follow
  [Elrori/k9plus-fm-radio](https://github.com/Elrori/k9plus-fm-radio),
  **only for hardware/Ethernet interfaces**, not its FM RF processing.
- DSP source in `../../common/` is reused unchanged; NCO14/MIX18/CIC20/FIR47
  is `sys_sw_dfe_1mhz_nco14` from this branch.
