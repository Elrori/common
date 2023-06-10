/*
*  Name         :dsp_ite_fft.v
*  Description  :Low cost iterative DIF FFT 
*  Origin       :230610
*  EE           :hel
*/
module dsp_ite_fft #(
    parameter DATA_W = 16
)(
    input       wire                clk     ,
    input       wire                rst_n   ,

    input       wire [DATA_W-1:0]   din     ,
    input       wire                din_vld ,
    output      wire                din_busy,

    output      wire [DATA_W-1:0]   dout    ,
    output      wire                dout_vld,
);
    
endmodule
