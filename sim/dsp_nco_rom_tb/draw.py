import matplotlib.pyplot as plt
import numpy as np
import matplotlib
matplotlib.use('TkAgg')
a = np.loadtxt('dsp_nco_rom_sin_ret.txt')
b = np.loadtxt('dsp_nco_rom_cos_ret.txt')
c = np.abs(np.fft.fftshift(np.fft.fft(a)))


fig = plt.figure(1)
ax1=plt.subplot(2,1,1) 
plt.plot(a)
ax2=plt.subplot(2,1,2) 
plt.plot(b)
plt.show()
