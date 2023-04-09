%% 加载verilog modelsim仿真结果，并做出频谱图
clc
clear
fs_in=20000000; % modelsim仿真时CIC的输入采样率
r=100;          % 抽样倍率，请修改该值，与verilog testbench 中R相同

fs_out=fs_in/r;
data =load('../modelsim/dout.txt');         %dout.txt是 verilog仿真后的波形文件
data2=load('../modelsim/sine_int.txt');     %sine_int.txt是输入verilog仿真的波形文件，中间经过了verilog CIC模块
y=fft(data);
y_=fft(data2);
n = length(data);                           % number of samples
n_= length(data2);

y0 = fftshift(y);                           % shift y values
y0_ = fftshift(y_);                         % shift y values
f0 = (-n/2:n/2-1)*(fs_out/n);               % 0-centered frequency range
f0_ = (-n_/2:n_/2-1)*(fs_in/n_);            % 0-centered frequency range
power0 = 20*log10(abs(y0).^2/n);            % 0-centered power
power0_ = 20*log10(abs(y0_).^2/n_);         % 0-centered power

subplot(2,1,1);
plot(f0_,power0_);
xlabel('Frequency (Hz)');
ylabel('Power');
title('输入verilog模块前频谱');

subplot(2,1,2);
plot(f0,power0);
xlabel('Frequency (Hz)');
ylabel('Power');
title('输入verilog模块后频谱');