# SW-Radio | K9+ FPGA / 40 MSPS ADC / Gigabit Ethernet / HDSDR

> **IMPORTANT: NON-BOARD-VERIFIED PIN MAP. DO NOT FLASH A BITSTREAM FROM THIS PROJECT.**
> `constraints/adc_ad8370_PROVISIONAL.xdc` has deliberately temporary pad LOCs,
> including pads occupied by PHY1, LEDs, keys or the LVDS RF connector. They
> are **not physically wired to an ADC or AD8370**, and one ADC placeholder uses
> a **2.5 V bank**, not a safe connection for a 3.3 V ADC output. The pin map,
> I/O voltage, output drive, timing and external clocks **must be replaced and
> reviewed before programming the FPGA or connecting the ADC**.

This is a self-contained Vivado *source/project template* in the branch
`feature/dfe-nco14-mixer18-adc12`. It reuses the present `common/` DSP RTL;
only its Ethernet MAC RTL is vendored. Physical target:
`xc7a50t-fgg484-1` (Colorlight K9+ / XI050CD hardware as referenced in
`Elrori/k9plus-fm-radio`). AD8370 control RTL comes from the supplied
`spi8370` attachment. The Ethernet PHY0 RX IDELAY12 / TX ODDR configuration
and pins are drawn from the board-proven FM-radio hardware design.

## Data path

```text
25 MHz oscillator -> MMCM: 40 MHz ADC/sample clock + 200 MHz IDELAY reference
40 MHz AD9235-40 or AD9226 12-bit offset-binary parallel data
       -> MSB inversion -> signed 12-bit ADC
       -> NCO14 / signed 18-bit mixer (32-bit frequency word)
       -> 5-stage CIC, R=16, M=2, CIC output 20 bits
       -> 47-tap symmetric/compensated FIR, R=2, 32-bit result
       -> signed 16-bit saturating quantizer (right shift 9)
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
.\build.ps1 -SynthOnly      # recommended until your physical pinout is known
.\build.ps1                 # synth, place, route, write *_UNSAFE*.bit
```

On Linux, `bash project/sw-radio/build.sh --synth-only` or
`bash project/sw-radio/build.sh` (requires installed Vivado).
Build artifacts go to `project/sw-radio/build/`:

- `post_synth.dcp`, `routed.dcp`, utilization, timing and DRC reports;
- `sw_radio_UNSAFE_PROVISIONAL_PINS.bit` after full successful build.

**A complete Vivado run has not been performed in the development environment**
because no Vivado installation or physical board is available. RTL syntax
elaboration and standalone simulations are separate checks and are **not**
evidence that Vivado placement, timing, IO banking, HDSDR integration or
actual electrical operation will pass. Use **post-route** timing reports
before considering the build ready for hardware.

## Pin mapping: what must change before hardware

| Interface | Status | File |
| --- | --- | --- |
| K9+ 25 MHz W19 | Reference board verified | `constraints/k9plus_phy0.xdc` |
| PHY0 RGMII W4/V4, AA1..AB5 | Reference board verified | `constraints/k9plus_phy0.xdc` |
| 12 parallel ADC data pins | **Placeholder; not wired and not safe** | `constraints/adc_ad8370_PROVISIONAL.xdc` |
| FPGA → ADC 40 MHz clock | **Placeholder; verify drive/timing/connector** | same |
| AD8370 CLK/DAT/LTCH | **Placeholder; verify control pin polarities** | same |

The ADC *model and exact output code mode* must be confirmed. The code assumes
the common default **offset binary** format for AD9235/AD9226. If the ADC is
configured for **two's complement**, remove the `adc_data[11]` inversion in
`rtl/sw_radio_top.sv` (it is a compile-time change, not runtime automatic
detection). Check 40 MHz clock edge, Tco, wire delay, I/O voltage and input
setup/hold; add board-specific ADC clock/data `set_input_delay` and
`set_output_delay`. Output OTR/overrange is **not yet connected** because its
pin is unknown. There is **no ADC RF anti-alias or input protection** in this
FPGA template; the 12-bit front end and preselector remain hardware concerns.

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
use **an isolated SDR LAN**, not an untrusted network. Gain starts at AD8370
code 0x00. Host gain commands may be coalesced if issued rapidly while SPI
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
**The Windows x86 DLL has been cross-compiled and its exports inspected,
but has not been loaded or tested under Windows HDSDR.** The Visual Studio
project has not been compiled under MSVC; only cross-compilation is verified.

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

All unit checks are source-level or functional simulation. The actual
RGMII I/O timing, async XPM FIFO silicon behavior, ADC pin mapping, AD8370
hardware response, bitstream build and HDSDR callback timing require Vivado
and bench validation before claiming a deployable radio.

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
