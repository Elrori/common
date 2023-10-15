.PHONY:all sim clean clr

VERILOG_DIR = -y../../       \
              -y../../common \

sim:
	iverilog $(VERILOG_DIR) -o axis_fifo_tb.vvp axis_fifo_tb.v
	vvp axis_fifo_tb.vvp
	
clean:
	rm *.txt *.vvp *.vcd  *.log -rf 

clr:clean
