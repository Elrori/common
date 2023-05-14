.PHONY:all sim draw clean clr

DEEP  = 16384
WIDTH = 12
VERILOG_DIR = -y../../../       \
              -y../../../common \

all:*.txt

sim:dsp_nco_rom_tb.vvp 
	vvp dsp_nco_rom_tb.vvp

draw:sim dsp_nco_rom_sin_ret.txt dsp_nco_rom_cos_ret.txt
	python3 draw.py

dsp_nco_rom:dsp_nco_rom.c
	$(CC) -o dsp_nco_rom dsp_nco_rom.c -lm

*.txt:dsp_nco_rom
	./dsp_nco_rom $(DEEP) $(WIDTH)

dsp_nco_rom_tb.vvp:dsp_nco_rom_tb.v *.txt
	iverilog -DDEPTH=$(DEEP) -DWIDTH=$(WIDTH) $(VERILOG_DIR) -o dsp_nco_rom_tb.vvp dsp_nco_rom_tb.v

clean:
	rm *.txt *.vvp *.vcd dsp_nco_rom -rf

clr:clean
