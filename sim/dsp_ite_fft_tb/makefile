VERILOG_DIR = -y../../       \
              -y../../common \

sim:
	iverilog $(VERILOG_DIR) -o dsp_ite_fft_tb.vvp dsp_ite_fft_tb.v
	vvp dsp_ite_fft_tb.vvp

clean:
	rm *.txt *.vvp *.vcd -rf

clr:clean

.PHONY:all sim clean clr
