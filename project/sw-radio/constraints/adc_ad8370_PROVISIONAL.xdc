# ===========================================================================
# DANGER! THESE ARE *ONLY PLACEHOLDER* LOCs, NOT ADC / VGA BOARD CONNECTIONS.
# DO NOT PROGRAM THE FPGA, APPLY ADC SIGNALS, OR POWER A PCB FROM THIS MAP.
# Replace ALL LOCs and check bank VCCO, VIH/VIL and clock timing first.
# The identifiers below are package pads known from the reference K9+ design,
# but many are physically connected to LEDs, keys, PHY1, or RF LVDS connectors.
# They ARE NOT usable for an ADC merely because Vivado can compile with them.
# ===========================================================================

# Placeholder parallel ADC12 data (AD9235-40/AD9226):
set_property PACKAGE_PIN J20 [get_ports {adc_data[0]}]
set_property PACKAGE_PIN Y18 [get_ports {adc_data[1]}]
set_property PACKAGE_PIN AB21 [get_ports {adc_data[2]}]
set_property PACKAGE_PIN AA21 [get_ports {adc_data[3]}]
set_property PACKAGE_PIN AB22 [get_ports {adc_data[4]}]
set_property PACKAGE_PIN Y21 [get_ports {adc_data[5]}]
set_property PACKAGE_PIN V18 [get_ports {adc_data[6]}]
set_property PACKAGE_PIN V19 [get_ports {adc_data[7]}]
set_property PACKAGE_PIN U18 [get_ports {adc_data[8]}]
set_property PACKAGE_PIN P16 [get_ports {adc_data[9]}]
set_property PACKAGE_PIN P17 [get_ports {adc_data[10]}]
set_property PACKAGE_PIN V20 [get_ports {adc_data[11]}]
# J20 is bank15 LVDS connector (nominal 2.5 V), NOT a suitable 3.3 V ADC IO.
set_property IOSTANDARD LVCMOS33 [get_ports {adc_data[*]}]
set_property IOSTANDARD LVCMOS25 [get_ports {adc_data[0]}]

# 40 MHz ADC clock forward output, provisional physical pad on PHY1 TX clock!
set_property PACKAGE_PIN W20 [get_ports adc_clk_out]
set_property IOSTANDARD LVCMOS33 [get_ports adc_clk_out]
set_property SLEW FAST [get_ports adc_clk_out]
set_property DRIVE 8 [get_ports adc_clk_out]

# AD8370 SPI pads provisional; THESE PADS ALSO HAVE BOARD-LEVEL LOADS.
set_property PACKAGE_PIN AA20 [get_ports ad8370_sclk]
set_property PACKAGE_PIN V22 [get_ports ad8370_mosi]
set_property PACKAGE_PIN U21 [get_ports ad8370_latch]
set_property IOSTANDARD LVCMOS33 [get_ports {ad8370_sclk ad8370_mosi ad8370_latch}]
set_property DRIVE 4 [get_ports {ad8370_sclk ad8370_mosi ad8370_latch}]
set_property SLEW SLOW [get_ports {ad8370_sclk ad8370_mosi ad8370_latch}]

# TODO actual ADC: create_clock -period 25 ns on conversion output; derive
# input clock/data timing from AD9235 / AD9226 TCO, trace delay and sampling
# edge; set_input_delay / set_output_delay with board-proven figures.
# The temporary timing is NOT a pass of ADC input timing closure.
