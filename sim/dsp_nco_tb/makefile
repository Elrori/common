.PHONY:all sim draw clean clr

DEEP  = 16384
WIDTH = 12
VERILOG_DIR = -y../../       \
              -y../../common \

sim:dsp_nco_tb.vvp 
	vvp dsp_nco_tb.vvp

dsp_nco_tb.vvp:dsp_nco_tb.v ../../common/*.v
	iverilog $(VERILOG_DIR) -o dsp_nco_tb.vvp dsp_nco_tb.v

clean:
	rm *.txt *.vvp *.vcd -rf

clr:clean
