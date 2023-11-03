.PHONY:all sim clean clr

VERILOG_DIR = -y../../       \
              -y../../common \

sim:
	iverilog $(VERILOG_DIR) -o simple_fifo_sync_tb.vvp simple_fifo_sync_tb.v
	vvp simple_fifo_sync_tb.vvp
	
clean:
	rm *.txt *.vvp *.vcd  *.log -rf 

clr:clean
