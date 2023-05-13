import numpy as np
import matplotlib.pyplot as plt
import matplotlib.mlab as mlab
import scipy
np.set_printoptions(threshold=np.inf)


class nco:
    def __init__(self,addr_w,data_w,phi_w,dither,fs) -> None:
        self.fs     = fs
        self.dither = dither
        self.phi_w  = phi_w
        self.addr_w = addr_w
        self.deep   = 2**addr_w
        self.data_w = data_w
        self.rom    = self.get_rom(self.deep,data_w)
        print('ROM DEEP:{} \nROM WIDTH:{}'.format(self.deep,data_w))

    def get_rom(self,deep,width):
        dat = np.arange(deep)
        amp = 2**(width-1)-1
        dat = np.round(amp * np.e**(dat*1j*2*np.pi/deep))
        return dat
    
    def get_fcw(self,f):
        return int(f*(2**self.phi_w)//self.fs)

    def nco_model(self,phi_inc,ret_num):
        ptr = 0
        ret_sin = np.arange(ret_num)
        ret_cos = np.arange(ret_num)

        shift  = self.phi_w-self.addr_w

        for i in range(ret_num):
            d0 = np.random.randint(self.dither)
            d1 = np.random.randint(self.dither)
            ptr_trunc = np.right_shift(ptr, shift)
            ret_sin[i] = self.rom.imag[((ptr_trunc + d0) % self.deep)]
            ret_cos[i] = self.rom.real[((ptr_trunc + d1) % self.deep)]
            ptr += phi_inc
        return ret_cos+ret_sin*1j

    def get_spectrum(self,data,window='rectangular'):
        options = [ 'rectangular', 'hamming', 'hann', 'blackman' ]
        if window not in options:
            exit(0)
        arr_window = np.ones(len(data))
        if window == 'hamming':
            arr_window = np.hamming(len(data))
        elif window == 'hann':
            arr_window = np.hanning(len(data))
        elif window == 'blackman':
            arr_window = np.blackman(len(data))

        fft = np.fft.fft(np.multiply(data, arr_window))
        fft_mag = np.abs(fft)
        fft_mag = fft_mag * (2 / len(fft_mag))
        fft_mag = fft_mag / float(2**(self.data_w))
        fft_log = (20 * np.log10(fft_mag))

        center = int(len(fft_log)/2)
        half = fft_log[:center]
        peaks = sorted(half)[-100:]
        print(peaks)
        sfdr = peaks[-1] - peaks[-2]
        print()
        print(f"the SFDR of this signal is {sfdr} dBc")
        return half


mynco = nco(addr_w=14,data_w=12,phi_w=32,dither=10,fs=40e6)
ret   = mynco.nco_model(mynco.get_fcw(19.99e6),8192)

# print(mynco.rom)
# dat_sin = np.append(dat_sin,dat_sin)
# dats = np.arange(num*100)
# dats = np.round(amp * np.e**(dats*1j*2*np.pi/num))
# dats_sin = dats.imag.astype(np.int32)
# dats_cos = dats.real
# np.savetxt("dat_sin.txt",dat_sin,fmt='%x')
# np.savetxt("dat_cos.txt",dat_cos,fmt='%x')
# pw = plt.psd(ret,Fs=40e6)
plt.figure()
# plt.plot(mynco.rom.imag)
# plt.plot(mynco.rom.real)
# plt.plot(ret.imag)
# plt.plot(ret.real)
plt.plot(mynco.get_spectrum(ret,'rectangular'))

plt.show()