# Copied from verified Elrori/k9plus-fm-radio constraints/k9plus_fm.xdc.
# ONLY the clock and PHY0 pins in this file are board-verified.
set_property PACKAGE_PIN W19 [get_ports clk_25m]
set_property IOSTANDARD LVCMOS33 [get_ports clk_25m]
create_clock -name board_clk_25m -period 40.000 [get_ports clk_25m]

set_property PACKAGE_PIN W4 [get_ports eth_tx_clk]
set_property PACKAGE_PIN V4 [get_ports eth_rx_clk]
set_property PACKAGE_PIN Y4 [get_ports eth_tx_ctl]
set_property PACKAGE_PIN AA1 [get_ports eth_rx_ctl]
set_property PACKAGE_PIN AA3 [get_ports {eth_tx_data[0]}]
set_property PACKAGE_PIN AA4 [get_ports {eth_tx_data[1]}]
set_property PACKAGE_PIN AB5 [get_ports {eth_tx_data[2]}]
set_property PACKAGE_PIN AA5 [get_ports {eth_tx_data[3]}]
set_property PACKAGE_PIN AB1 [get_ports {eth_rx_data[0]}]
set_property PACKAGE_PIN AB2 [get_ports {eth_rx_data[1]}]
set_property PACKAGE_PIN Y3 [get_ports {eth_rx_data[2]}]
set_property PACKAGE_PIN AB3 [get_ports {eth_rx_data[3]}]
set_property PACKAGE_PIN W21 [get_ports eth_mdc]
set_property PACKAGE_PIN Y22 [get_ports eth_mdio]
set_property PACKAGE_PIN W22 [get_ports eth_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports {eth_tx_clk eth_rx_clk eth_tx_ctl eth_rx_ctl eth_tx_data[*] eth_rx_data[*] eth_mdc eth_mdio eth_rst_n}]
set_property DRIVE 8 [get_ports {eth_tx_clk eth_tx_ctl eth_tx_data[*]}]
set_property SLEW FAST [get_ports {eth_tx_clk eth_tx_ctl eth_tx_data[*]}]
create_clock -name phy0_rx_clk -period 8.000 [get_ports eth_rx_clk]

# Retained from the reference K9+ board project; check FPGA I/O timing in
# post-route analysis, especially PHY receive data/clock centering.
set_false_path -from [get_ports {eth_rx_ctl eth_rx_data[*]}]
set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks board_clk_25m] \
    -group [get_clocks phy0_rx_clk]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 1 [current_design]
set_property CONFIG_MODE SPIx1 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
