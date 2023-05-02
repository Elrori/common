iverilog -y../../ -y../../common -o dsp_fir_dec_tb.vvp .\dsp_fir_dec_tb.v
vvp dsp_fir_dec_tb.vvp
gtkwave wave.vcd