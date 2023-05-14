import numpy as np
import matplotlib.pyplot as plt
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
        print(f"Peaks:{peaks[-1]-peaks[0]} dBc")
        return half
    
if len(sys.argv) != 8:
    print('Argv error')
    exit(0)

mynco           = nco(addr_w=int(sys.argv[1]),data_w=int(sys.argv[2]),phi_w=int(sys.argv[3]),dither=int(sys.argv[4]),fs=int(sys.argv[5]))
python_output   = mynco.nco_model(phi_inc=int(sys.argv[6]),ret_num=int(sys.argv[7]))
python_spectrum = mynco.get_spectrum(python_output ,'blackman')
# print('fcw:{}'.format(hex(fcw)))
# pw = plt.psd(ret,Fs=40e6)
verilog_cos = np.loadtxt('dsp_nco_cos_ret.txt')
verilog_sin = np.loadtxt('dsp_nco_sin_ret.txt')
verilog_output = verilog_cos+verilog_sin*1j
verilog_spectrum = mynco.get_spectrum(verilog_output,'blackman')


plt.figure()
ppython , = plt.plot(python_spectrum ,linewidth=5)
pverilog, = plt.plot(verilog_spectrum)
plt.legend([ppython,pverilog],['python NCO model','verilog NCO'])
plt.title("Verilog NCO VS. python NCO")
plt.xlabel("f")
plt.ylabel("dB")
plt.grid()
plt.show()