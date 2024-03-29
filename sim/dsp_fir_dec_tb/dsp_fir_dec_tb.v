//~ `New testbench
`timescale  1ns / 1ps

module dsp_fir_dec_tb;

// fir_dec Parameters
parameter PERIOD            = 25;
parameter R                 = 2 ;
parameter CLOCK_PER_SAMPLE  = 30;

// fir_dec Inputs
reg   clk                                  = 0 ;
reg   rst_n                                = 0 ;
reg   signed [15:0]  din                          = 0 ;
reg   din_val                              = 0 ;
wire   [31:0]  dout                          ;
wire   dout_val                             ;

// fir_dec Outputs

reg [10-1:0]sine[0:1999];

initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial
begin
    #(PERIOD*2) rst_n  =  1;
end
reg [7:0]cnt=0;
reg [15:0]cnt1=0;
always@(posedge clk or negedge rst_n)begin
    if ( !rst_n ) begin
        din <= 'd0;
        cnt <= 'd0;
        cnt1<= 'd0;
    end else begin
        if (cnt==CLOCK_PER_SAMPLE-1) begin
            din <=(sine[cnt1]<<6);// 采样率20MSPS，频率10KHz正弦波 + 200KHz的高频正弦波
            cnt1 <= (cnt1==1999)?0:cnt1 + 1;
        end
        cnt <=(cnt==CLOCK_PER_SAMPLE-1)?'d0:cnt+1;
    end
end

dsp_fir_dec #(
    .R                ( R                ),
    .CLOCK_PER_SAMPLE ( CLOCK_PER_SAMPLE ),
    .W_DIN            ( 16               ),
    .W_DOUT           ( 32               ),
    .W_COE            ( 16               ),
    .M_DEEP           ( 64               ),
    .N_COE            ( 57               ))
 u_fir_dec (
    .clk                     ( clk              ),
    .rst_n                   ( rst_n            ),
    .din                     ( din       [15:0] ),
    .din_val                 ( cnt==CLOCK_PER_SAMPLE-1),
    .dout                    ( dout      [31:0] ),
    .dout_val                ( dout_val         )
);
initial
begin
    $dumpfile("wave.vcd");
    $dumpvars(0,dsp_fir_dec_tb);
    $readmemh("sine.txt",sine);
    wait(cnt1==1999)begin
        #(1000)
        wait(cnt1==1999)begin
            $finish;
        end
    end
    
end

endmodule