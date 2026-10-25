#!/usr/bin/env bash
# Executes Icarus Verilog tests and stdlib Python protocol tests (no Vivado).
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
sw="$repo/project/sw-radio"
tmp="$(mktemp -d "${TMPDIR:-$sw}/.rtl-test.XXXXXXXX")"
trap 'rm -r -- "$tmp"' EXIT
cd "$repo"
export TMPDIR="$tmp"
iverilog -g2012 -s tb_udp_iq -o "$tmp/tb_udp_iq.vvp" \
    "$sw/rtl/sw_udp_iq_tx.sv" "$sw/tests/tb_udp_iq.sv"
vvp "$tmp/tb_udp_iq.vvp"
iverilog -g2012 -s tb_control -o "$tmp/tb_control.vvp" \
    "$sw/rtl/sw_rgmii_control_rx.sv" "$sw/tests/tb_control.sv"
vvp "$tmp/tb_control.vvp"
iverilog -g2012 -s tb_spi8370 -o "$tmp/tb_spi8370.vvp" \
    "$sw/rtl/spi8370.v" "$sw/tests/tb_spi8370.sv"
vvp "$tmp/tb_spi8370.vvp"
dfe_files=(common/simple_ram.v common/dsp_nco_rom.v common/dsp_nco.v \
    common/dsp_mul2.v common/dsp_cic_dec.v common/dsp_cic_dec_pipe.v common/dsp_fir_dec_sym.v \
    common/sys_sw_dfe_1mhz.v common/sys_sw_dfe_1mhz_nco14.v)
iverilog -g2012 -s tb_dfe_tone -o "$tmp/tb_dfe_tone.vvp" \
    "${dfe_files[@]}" "$sw/tests/tb_dfe_tone.sv"
vvp "$tmp/tb_dfe_tone.vvp"
iverilog -g2012 -s tb_nco_iq -o "$tmp/tb_nco_iq.vvp" \
    common/simple_ram.v common/dsp_nco_rom.v common/dsp_nco.v \
    "$sw/tests/tb_nco_iq.sv"
vvp "$tmp/tb_nco_iq.vvp"
iverilog -g2012 -i -s sw_radio_top -o "$tmp/top_elaboration.vvp" \
    "${dfe_files[@]}" "$sw"/rtl/*.sv "$sw/rtl/spi8370.v" \
    "$sw/vendor/verilog-ethernet/lfsr.v" \
    "$sw/vendor/verilog-ethernet/axis_gmii_tx.v"
echo 'PASS: top module elaboration (Xilinx primitives treated as black boxes)'
python3 -m unittest discover -s "$sw/tests" -p 'test_*.py' -v
echo 'RTL_AND_PROTOCOL_TESTS_PASS'
