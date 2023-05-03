@echo off
set dp=4096
set wd=12
gcc -o dsp_nco_rom.exe .\dsp_nco_rom.c
dsp_nco_rom.exe %dp% %wd%
iverilog -DDEPTH=%dp% -DWIDTH=%wd% -y../../ -y../../common -o dsp_nco_rom_tb.vvp .\dsp_nco_rom_tb.v
vvp dsp_nco_rom_tb.vvp
@REM gtkwave wave.vcd