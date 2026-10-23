# Vivado non-project end-to-end build. Invoke from project/sw-radio/build.ps1
# or: vivado -mode batch -source project/sw-radio/scripts/build.tcl
set here [file normalize [file dirname [info script]]]
set project [file normalize [file join $here ..]]
set repo [file normalize [file join $project .. ..]]
set out [file join $project build]
file mkdir $out
cd $repo
set part xc7a50t-fgg484-1

if {![info exists ::env(XILINX_VIVADO)]} {
    error "XILINX_VIVADO must point at the Vivado version directory (e.g. C:/Xilinx/Vivado/2023.2)"
}
set xpm [file join $::env(XILINX_VIVADO) data ip xpm]
read_verilog -sv [list \
    [file join $xpm xpm_cdc hdl xpm_cdc.sv] \
    [file join $xpm xpm_memory hdl xpm_memory.sv] \
    [file join $xpm xpm_fifo hdl xpm_fifo.sv]]

set rtl [file join $project rtl]
set vendor [file join $project vendor verilog-ethernet]
read_verilog [list \
    [file join $vendor lfsr.v] \
    [file join $vendor axis_gmii_tx.v] \
    [file join $rtl spi8370.v]]
read_verilog -sv [list \
    [file join $repo common simple_ram.v] \
    [file join $repo common dsp_nco_rom.v] \
    [file join $repo common dsp_nco.v] \
    [file join $repo common dsp_mul2.v] \
    [file join $repo common dsp_cic_dec.v] \
    [file join $repo common dsp_fir_dec_sym.v] \
    [file join $repo common sys_sw_dfe_1mhz.v] \
    [file join $repo common sys_sw_dfe_1mhz_nco14.v] \
    [file join $rtl sw_clock_gen.sv] \
    [file join $rtl sw_control_cdc.sv] \
    [file join $rtl sw_iq_cdc.sv] \
    [file join $rtl sw_udp_iq_tx.sv] \
    [file join $rtl sw_rgmii_control_rx.sv] \
    [file join $rtl sw_rgmii_tx.sv] \
    [file join $rtl sw_radio_top.sv]]
read_xdc [file join $project constraints k9plus_phy0.xdc]
read_xdc [file join $project constraints adc_ad8370_PROVISIONAL.xdc]

synth_design -top sw_radio_top -part $part -flatten_hierarchy rebuilt
write_checkpoint -force [file join $out post_synth.dcp]
report_utilization -hierarchical -file [file join $out utilization_synth.rpt]
report_timing_summary -file [file join $out timing_synth.rpt]
if {[lsearch -exact $argv "-synth-only"] >= 0} {
    puts "SW_RADIO_SYNTH_ONLY_PASS (ADC constraints are NOT board verified)"
    exit
}
opt_design
place_design
phys_opt_design
route_design
report_drc -file [file join $out drc_route.rpt]
report_route_status -file [file join $out route_status.rpt]
report_utilization -hierarchical -file [file join $out utilization_route.rpt]
report_timing_summary -max_paths 20 -file [file join $out timing_route.rpt]
write_checkpoint -force [file join $out routed.dcp]
write_bitstream -force [file join $out sw_radio_UNSAFE_PROVISIONAL_PINS.bit]
puts "SW_RADIO_BUILD_PASS: *UNSAFE* BITSTREAM -- NEVER FLASH WITHOUT PIN REVIEW"
exit
