.PHONY:all sim clean clr

VERILOG_DIR = -y../../       \
              -y../../common \

WIDTH = 16

all:
	@echo "Nothing to generate, 'make sim' to run iverilog"

sim:
	cd ../dsp_cic_dec_tb && make clr && make sine.txt WIDTH=16
	cp ../dsp_cic_dec_tb/sine.txt .
	iverilog $(VERILOG_DIR) -DWIDTH=$(WIDTH) -o dsp_cic_dec_var_tb.vvp dsp_cic_dec_var_tb.v
	vvp dsp_cic_dec_var_tb.vvp

clean:
	rm *.txt *.vvp *.vcd  *.log gen_sine -rf 
	cd ../dsp_cic_dec_tb && make clr

clr:clean
