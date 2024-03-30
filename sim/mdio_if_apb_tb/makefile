.PHONY:all sim clean clr

VERILOG_DIR = -y.       \
              -y../../common \
              -y../../example

sim:
	iverilog $(VERILOG_DIR) -o mdio_if_apb_tb.vvp mdio_if_apb_tb.v
	vvp mdio_if_apb_tb.vvp

clean:
	rm *.txt *.vvp *.vcd  *.log -rf

clr:clean
