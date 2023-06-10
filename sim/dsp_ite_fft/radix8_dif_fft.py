#!/bin/python3
import numpy as np
import matplotlib.pyplot as plt
class radix8_butterfly:
    '''
    radix8 DIF butt model

    '''
    def __init__(self,base8_stage = 0):
        self.base8_stage = base8_stage 
        self.width0 =  0
        self.width1 =  0
        self.width2 =  0
        if self.base8_stage == 0:
            self.width0 =  512
            self.width1 =  256
            self.width2 =  128
        elif self.base8_stage == 1:
            self.width0 =  64
            self.width1 =  32
            self.width2 =  16
        elif self.base8_stage == 2:
            self.width0 =  8
            self.width1 =  4
            self.width2 =  2
        else:
            pass

    def get_wn(slef,n,N):
        return np.cos(2*np.pi*n/N)-np.sin(2*np.pi*n/N)*1j

    def stage0_core(self,din): # din = np.zeros(self.width0,dtype=complex)
        e0 =  0.7071067811865476 - 0.7071067811865476j
        e1 = -1j
        e2 = -0.7071067811865476 - 0.7071067811865476j
        dout  = np.zeros(self.width0,dtype=complex)
        half_range = self.width0//2
        for i in range(half_range):
            srange = i//(self.width0//8) # 0 1 2 3
            if srange==0:
                pos = din[i] + din[i+half_range]
                neg = din[i] - din[i+half_range]
            elif srange==1:
                pos = din[i] + din[i+half_range]
                neg = (din[i] - din[i+half_range]) * e0
            elif srange==2:
                pos = din[i] + din[i+half_range]
                neg = (din[i] - din[i+half_range]) * e1
            elif srange==3:
                pos = din[i] + din[i+half_range]
                neg = (din[i] - din[i+half_range]) * e2
            else:
                print('stage1_core error')
                exit(0)
            dout[i] = pos
            dout[i+half_range] = neg
        return dout

    def stage1_core(self,din):
        dout  = np.zeros(self.width1,dtype=complex)
        half_range = self.width1//2
        for i in range(half_range):
            srange = i//(self.width0//8) # 0 1 
            if srange==0:
                pos = din[i] + din[i+half_range]
                neg = din[i] - din[i+half_range]
            elif srange==1:
                pos = din[i] + din[i+half_range]
                neg = (din[i] - din[i+half_range]) * (-1j)
            else:
                print('stage2_core error')
                exit(0)
            dout[i] = pos
            dout[i+half_range] = neg
        return dout

    def stage2_core(self,din,b = 0):
        dout  = np.zeros(self.width2,dtype=complex)
        half_range = self.width2//2
        for i in range(half_range):
            if b == 0:
                pos = (din[i] + din[i+half_range]) 
                neg = (din[i] - din[i+half_range]) * self.get_wn((i )*4,self.width0)
            elif b == 1:
                pos = (din[i] + din[i+half_range]) * self.get_wn((i )*2,self.width0)
                neg = (din[i] - din[i+half_range]) * self.get_wn((i )*6,self.width0)
            elif b == 2:
                pos = (din[i] + din[i+half_range]) * self.get_wn((i )*1,self.width0)
                neg = (din[i] - din[i+half_range]) * self.get_wn((i )*5,self.width0)
            elif b == 3:
                pos = (din[i] + din[i+half_range]) * self.get_wn((i )*3,self.width0)
                neg = (din[i] - din[i+half_range]) * self.get_wn((i )*7,self.width0)
            else:
                print('error')
                exit(0)
            dout[i] = pos
            dout[i+half_range] = neg
        return dout

def radix8_1st_core(din):
    '''
    512=>512
    '''
    radix8_stage0 = radix8_butterfly(0)
    din          = radix8_stage0.stage0_core(din)
    din[0:256]   = radix8_stage0.stage1_core(din[0:256])
    din[256:512] = radix8_stage0.stage1_core(din[256:512])
    din[0:128]   = radix8_stage0.stage2_core(din[0:128]  ,0)
    din[128:256] = radix8_stage0.stage2_core(din[128:256],1)
    din[256:384] = radix8_stage0.stage2_core(din[256:384],2)
    din[384:512] = radix8_stage0.stage2_core(din[384:512],3)
    return din

def radix8_2nd_core(din):
    '''
    64=>64
    '''
    radix8_stage1 = radix8_butterfly(1)
    din          = radix8_stage1.stage0_core(din)
    din[0 :32]   = radix8_stage1.stage1_core(din[0 :32])
    din[32:64]   = radix8_stage1.stage1_core(din[32:64])
    din[0 :16]   = radix8_stage1.stage2_core(din[0 :16]  ,0)
    din[16:32]   = radix8_stage1.stage2_core(din[16:32]  ,1)
    din[32:48]   = radix8_stage1.stage2_core(din[32:48]  ,2)
    din[48:64]   = radix8_stage1.stage2_core(din[48:64]  ,3)
    return din

def radix8_3rd_core(din):
    '''
    8=>8
    '''
    radix8_stage2 = radix8_butterfly(2)
    din           = radix8_stage2.stage0_core(din)
    din[0 :4]     = radix8_stage2.stage1_core(din[0 :4])
    din[4 :8]     = radix8_stage2.stage1_core(din[4 :8])
    din[0 :2]     = radix8_stage2.stage2_core(din[0 :2]  ,0)
    din[2 :4]     = radix8_stage2.stage2_core(din[2 :4]  ,1)
    din[4 :6]     = radix8_stage2.stage2_core(din[4 :6]  ,2)
    din[6 :8]     = radix8_stage2.stage2_core(din[6 :8]  ,3)
    return din

def bit_reverse(data = 0,width = 9):
    dout = 0
    for i in range(width):
        b = data & (2**(width-1))
        data = data << 1
        dout = dout >> 1
        if b:
            dout = dout | (2**(width-1))
    return dout

def fft_512(data):
    dout     = np.ones(512,dtype=complex)
    data = radix8_1st_core(data)
    for i in range(8):
        data[i*64:i*64+64] = radix8_2nd_core(data[i*64:i*64+64])
    for i in range(64):
        data[i*8:i*8+8] = radix8_3rd_core(data[i*8:i*8+8])
    for i in range(512):
        dout[i] = data[bit_reverse(i,9)]
    return dout

def main():
    data = np.ones(512,dtype=complex)
    for i in range(512):
        data[i] = np.sin(21*2*np.pi*i/512)+np.random.random()-0.5

    plt.plot(np.fft.fftshift(abs(np.fft.fft(data)) ),linewidth=5.0)
    plt.plot(np.fft.fftshift(abs(fft_512(data))    ),)
    plt.show()

main()

