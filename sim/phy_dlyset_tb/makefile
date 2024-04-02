.PHONY:all sim clean clr

VERILOG_DIR = -y.       \
              -y../../common \
              -y../../example

sim:
	iverilog $(VERILOG_DIR) -o phy_dlyset_tb.vvp phy_dlyset_tb.v
	vvp phy_dlyset_tb.vvp

clean:
	rm *.txt *.vvp *.vcd  *.log -rf

clr:clean
