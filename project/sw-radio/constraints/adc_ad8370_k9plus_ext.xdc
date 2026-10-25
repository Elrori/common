# K9plus_ext ADC/AD8370 mezzanine wiring supplied for this hardware.
# ADC bit order is explicit to make alternating connector placement visible.
set_property PACKAGE_PIN H3 [get_ports {adc_data[0]}]
set_property PACKAGE_PIN K6 [get_ports {adc_data[1]}]
set_property PACKAGE_PIN H4 [get_ports {adc_data[2]}]
set_property PACKAGE_PIN L6 [get_ports {adc_data[3]}]
set_property PACKAGE_PIN J5 [get_ports {adc_data[4]}]
set_property PACKAGE_PIN L3 [get_ports {adc_data[5]}]
set_property PACKAGE_PIN J4 [get_ports {adc_data[6]}]
set_property PACKAGE_PIN L5 [get_ports {adc_data[7]}]
set_property PACKAGE_PIN J6 [get_ports {adc_data[8]}]
set_property PACKAGE_PIN P4 [get_ports {adc_data[9]}]
set_property PACKAGE_PIN K2 [get_ports {adc_data[10]}]
set_property PACKAGE_PIN N4 [get_ports {adc_data[11]}]
set_property PACKAGE_PIN K1 [get_ports adc_otr]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_data[*] adc_otr}]

# FPGA-forwarded 62.5 MHz conversion clock.
set_property PACKAGE_PIN K4 [get_ports adc_clk_out]
set_property IOSTANDARD LVCMOS33 [get_ports adc_clk_out]
set_property DRIVE 8 [get_ports adc_clk_out]
set_property SLEW FAST [get_ports adc_clk_out]

# AD8370 three-wire control: SDA, SCK, CS/latch.
set_property PACKAGE_PIN J1 [get_ports ad8370_mosi]
set_property PACKAGE_PIN M6 [get_ports ad8370_sclk]
set_property PACKAGE_PIN H5 [get_ports ad8370_latch]
set_property IOSTANDARD LVCMOS33 [get_ports {ad8370_sclk ad8370_mosi ad8370_latch}]
set_property DRIVE 4 [get_ports {ad8370_sclk ad8370_mosi ad8370_latch}]
set_property SLEW SLOW [get_ports {ad8370_sclk ad8370_mosi ad8370_latch}]

# The ADC launches data from the forwarded clock and the FPGA captures the
# preceding sample immediately before the converter updates it.  The AD9226
# data-sheet specifies 3.5 ns minimum and 7.0 ns maximum clock-to-data delay
# at 65 MSPS; this 62.5 MHz build therefore uses the worst-case values.
# Post-route hold/setup reports remain mandatory before programming.
create_generated_clock -name adc_forwarded_clk \
    -source [get_ports clk_25m] -multiply_by 5 -divide_by 2 \
    [get_ports adc_clk_out]
set_input_delay -clock adc_forwarded_clk -min 3.5 \
    [get_ports {adc_data[*] adc_otr}]
set_input_delay -clock adc_forwarded_clk -max 7.0 \
    [get_ports {adc_data[*] adc_otr}]
