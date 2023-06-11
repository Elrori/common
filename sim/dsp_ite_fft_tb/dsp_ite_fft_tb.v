`timescale  1ns / 1ps

module tb_dsp_ite_fft;

// dsp_ite_fft Parameters
parameter PERIOD       = 10;
parameter DATA_W       = 16;
parameter ADD_LATENCY  = 2 ;
parameter MUL_LATENCY  = 2 ;

// dsp_ite_fft Inputs
reg   clk                                  = 0 ;
reg   rst_n                                = 0 ;
reg   [DATA_W*2-1:0]  din                    = 0 ;


// dsp_ite_fft Outputs
wire  din_busy                             ;
wire  [DATA_W*2-1:0]  dout                   ;
wire  dout_vld                             ;

reg [31:0] cnt=0;

initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial
begin
    #(PERIOD*2) rst_n  =  1;
end

dsp_ite_fft #(
    .DATA_W      ( DATA_W      ),
    .ADD_LATENCY ( ADD_LATENCY ),
    .MUL_LATENCY ( MUL_LATENCY ))
 u_dsp_ite_fft (
    .clk                     ( clk                    ),
    .rst_n                   ( rst_n                  ),
    .din                     ( din       [DATA_W*2-1:0] ),
    .din_vld                 ( (cnt < 16 && cnt >=8)     ||     (cnt < 8*20+8 && cnt >=8*20)      ),

    .din_busy                ( din_busy               ),
    .dout                    ( dout      [DATA_W*2-1:0] ),
    .dout_vld                ( dout_vld               )
);
always @(posedge clk) begin
    cnt <= cnt + 1;
end
initial
begin
    $dumpfile("wave.vcd");
    $dumpvars(0,tb_dsp_ite_fft);
    #50000;
    $finish;
end

endmodule