.PHONY:all sim clean clr

VERILOG_DIR = -y../../       \
              -y../../common \

sim:
	iverilog $(VERILOG_DIR) -o simple_adapter_tb.vvp simple_adapter_tb.v
	vvp simple_adapter_tb.vvp

sim_serial:
	iverilog $(VERILOG_DIR) -o simple_adapter_serial_tb.vvp simple_adapter_serial_tb.v
	vvp simple_adapter_serial_tb.vvp

	
clean:
	rm *.txt *.vvp *.vcd  *.log -rf 

clr:clean
