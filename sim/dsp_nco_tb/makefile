# 
# DATA_DEEPS: 2^ADDR_WIDTHS
# FS        : nco clock rate
# RET_NUMS  : capture numbers
#
FS          = 40000000
PHI_INCS    = 214748364
PHI_WIDTHS  = 32
ADDR_WIDTHS = 14
DATA_DEEPS  = 16384
DATA_WIDTHS = 12
RET_NUMS    = 16384
DITHERS     = 2

# 
# DO NOT MODIFY BELOW THIS LINE
# 
VERILOG_DIR = -y../../       \
              -y../../common \

VERILOG_DF = -DPHI_WIDTHS=$(PHI_WIDTHS) \
	 -DADDR_WIDTHS=$(ADDR_WIDTHS) \
	 -DDATA_WIDTHS=$(DATA_WIDTHS) \
	 -DPHI_INCS=$(PHI_INCS) \
	 -DRET_NUMS=$(RET_NUMS) \
	 -DFS=$(FS)

sim:
	cd dsp_nco_rom_tb && make clr && make DEEP=$(DATA_DEEPS) WIDTH=$(DATA_WIDTHS)
	cp ./dsp_nco_rom_tb/dsp_nco_rom_sin45.txt .
	cp ./dsp_nco_rom_tb/dsp_nco_rom_cos45.txt .
	iverilog $(VERILOG_DIR) $(VERILOG_DF) -o dsp_nco_tb.vvp dsp_nco_tb.v
	vvp dsp_nco_tb.vvp
	python3 dsp_nco.py $(ADDR_WIDTHS) $(DATA_WIDTHS) $(PHI_WIDTHS) $(DITHERS) $(FS) $(PHI_INCS) $(RET_NUMS) 

clean:
	rm *.txt *.vvp *.vcd -rf
	cd dsp_nco_rom_tb && make clr

clr:clean

.PHONY:all sim draw clean clr