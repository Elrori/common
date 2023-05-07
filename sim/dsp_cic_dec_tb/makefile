.PHONY:all sim clean clr

VERILOG_DIR = -y../../       \
              -y../../common \

all:
	@echo "Nothing to generate, 'make sim' to run iverilog"

sine.txt sine_int.txt:gen_sine.c
	$(CC) -o gen_sine gen_sine.c -lm
	./gen_sine > gen_sine.log

sim:dsp_cic_dec_tb.v sine.txt sine_int.txt
	iverilog $(VERILOG_DIR) -o dsp_cic_dec_tb.vvp dsp_cic_dec_tb.v
	vvp dsp_cic_dec_tb.vvp
clean:
	rm *.txt *.vvp *.vcd  *.log gen_sine -rf 

clr:clean
