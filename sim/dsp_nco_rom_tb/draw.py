import matplotlib.pyplot as plt
import numpy as np
a = np.loadtxt('dsp_nco_rom_ret.log')
b = np.abs(np.fft.fftshift(np.fft.fft(a)))
plt.plot(a)
plt.show()