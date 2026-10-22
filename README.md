# common

**Optional HF/shortwave 1 MHz DFE:** [CIC 18/20-bit + symmetric 47-tap FIR design, test data, FPGA resource estimates and receiver benchmarks](docs/dfe_1mhz.md).

**12-bit ADC NCO precision upgrade:** [12/16 versus 14/18 versus 16/20 full-RTL A/B, 5-frequency NCO spur sweep, Artix-7 mapping, and reproduction](docs/dfe_nco_optimization.md).

```
common verilog module 
  |
  |-- common    can be used directly without modifying the code.
  |
  |-- example   code modifications may be required to use.
  |
  +-- sim       simulation.
```

simulation dependency:

```
sudo apt-get install make
sudo apt-get install python3
sudo apt-get install python3-pip
sudo apt-get install python3-tk
sudo apt-get install iverilog
sudo apt-get install gtkwave
pip3 install matplotlib
pip3 install numpy
pip3 install scipy
```
