#
# Name  : python nco model
# EE    : hel
# Origin: 230516
# Ref   : https://www.ieee.li/pdf/essay/dds.pdf
#         https://docs.xilinx.com/v/u/en-US/dds
#
import numpy as np
import matplotlib.pyplot as plt
from scipy import signal
import sys
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
        print("Python nco conf:")
        print('ROM DEEP      : {}'.format(self.deep))
        print('ROM ADDR WIDTH: {}'.format(self.addr_w))
        print('ROM DATA WIDTH: {}'.format(data_w))
        print('Fs            : {}'.format(self.fs))
        print('DITHER        : {}'.format(self.dither))
        print('PHI WIDTH     : {}'.format(self.phi_w))

    def get_rom(self,deep,width):
        # cos = np.loadtxt('dsp_nco_rom_cos_ret.txt')
        # sin = np.loadtxt('dsp_nco_rom_sin_ret.txt')
        # return cos+sin*1j
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
            d0 = np.left_shift(d0, shift-3)
            d1 = np.left_shift(d1, shift-3)
            ptr_trunc0 = np.right_shift(ptr+d0, shift)
            ptr_trunc1 = np.right_shift(ptr+d1, shift)
            ret_sin[i] = self.rom.imag[((ptr_trunc0) % self.deep)]
            ret_cos[i] = self.rom.real[((ptr_trunc1) % self.deep)]
            ptr += phi_inc
        return ret_cos+ret_sin*1j

    def get_spectrum(self,data,window='rectangular'):
        '''
        https://cushychicken.github.io/improving-sfdr-in-python-direct-digital-synthesizer/
        '''
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
        return half

    def sfdr(self,x,fs):
        """
        https://github.com/papamidas/notebooks/blob/master/SFDR.ipynb
        """
        xw = x * np.kaiser(len(x),beta=38) /len(x)
        xw -= np.mean(xw)
        Y = np.fft.rfft(xw)
        freqs = np.fft.rfftfreq(len(xw), d=1.0/fs)
        mag = np.abs(Y)
        YdB = 20 * np.log10(mag)
        peakind = signal.find_peaks_cwt(YdB, np.arange(3,9))
        pksf=freqs[peakind]
        pksY=YdB[peakind]
        isorted = np.argsort(pksY)
        sfdrval = pksY[isorted[-1]] - pksY[isorted[-2]]
        fig, ax = plt.subplots()
        pkfa = pksf[isorted[-1]]
        pkYa = pksY[isorted[-1]]
        pkfb = pksf[isorted[-2]]
        pkYb = pksY[isorted[-2]]
        plt.fill_between((0,fs/2),(pkYb,pkYb),(pkYa,pkYa), label = 'SFDR',color = "lightblue")   
        ax.plot(pkfa, pkYa, marker="s", label = 'fundamental')
        ax.plot(pkfb, pkYb, marker="s", label = 'spurs')
        ax.plot(freqs, YdB)
        ax.set(xlabel = 'Frequency (Hz)', ylabel = 'Power (dB)',title = "SFDR %.2f dB" % sfdrval)
        ax.set_xlim(0, fs / 2)
        ax.set_ylim(-150, 50)   
        ax.legend(loc = "upper right")
        return sfdrval

if len(sys.argv) != 8:
    print('Argv error')
    exit(0)

mynco           = nco(addr_w=int(sys.argv[1]),data_w=int(sys.argv[2]),phi_w=int(sys.argv[3]),dither=int(sys.argv[4]),fs=int(sys.argv[5]))
python_output   = mynco.nco_model(phi_inc=int(sys.argv[6]),ret_num=int(sys.argv[7]))
python_spectrum = mynco.get_spectrum(python_output ,'blackman')

verilog_cos = np.loadtxt('dsp_nco_cos_ret.txt')
verilog_sin = np.loadtxt('dsp_nco_sin_ret.txt')
verilog_output = verilog_cos+verilog_sin*1j
verilog_spectrum = mynco.get_spectrum(verilog_output,'blackman')

# pw = plt.psd(ret,Fs=40e6)
mynco.sfdr(verilog_output,40e6)

plt.figure()
ppython , = plt.plot(python_spectrum ,linewidth=5)
pverilog, = plt.plot(verilog_spectrum)
plt.legend([ppython,pverilog],['python NCO model','verilog NCO'])
plt.title("Verilog NCO VS. python NCO")
plt.xlabel("f")
plt.ylabel("dB")
plt.grid()
plt.show()

