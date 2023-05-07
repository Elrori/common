.PHONY:all sim clean clr

VERILOG_DIR = -y../../       \
              -y../../common \

all:
	@echo "Nothing to generate, 'make sim' to run iverilog"

sim:dsp_fir_dec_tb.v
	iverilog $(VERILOG_DIR) -o dsp_fir_dec_tb.vvp dsp_fir_dec_tb.v
	vvp dsp_fir_dec_tb.vvp

clean:
	rm *.vvp *.vcd -rf

clr:clean
