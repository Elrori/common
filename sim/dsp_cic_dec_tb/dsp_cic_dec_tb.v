/*
*   Name        :dsp_cic_dec tb
*   Description :
*   Origin      :200317
*                200322
*   Author      :
*/
`timescale  1ns / 1ps
module dsp_cic_dec_tb;

parameter R     = 100;          // 
parameter M     = 2 ;           // 
parameter N     = 3 ;           // 
parameter BIN   = 10;           // 
parameter COUT  = 16;           // 
parameter BOUT  = (BIN + $clog2((R*M)**N));
parameter PERIOD = 50;          // 20Mhz
parameter fs    = 10_000_000_000/PERIOD;   // Sampling rate

reg  clk   = 0;
reg  rst_n = 0;
wire dvld;
integer fp;
reg [63:0]cnt0=0,cnt1=0;
reg  signed [BIN-1:0] din;
wire signed [BOUT-1:0]dout;
wire signed [COUT-1:0]dout_cut;
reg [BIN-1:0]sine[0:1999];
initial
begin
    forever #(PERIOD/2)  clk=~clk;
end
initial
begin
    #(PERIOD*2) rst_n  =  1;
end
always@(posedge clk)begin
    //din<=$random%(2**BIN/3);
    din  <= sine[cnt1];
    cnt1 <= (cnt1==1999)?0:cnt1 + 1;
    //Receive simulation results for input to matlab
    if (dvld) begin
        $fwrite(fp,"%d\n",dout);
        cnt0 <= cnt0 + 1;
    end
end
dsp_cic_dec #(
    .R      (R  ),
    .M      (M  ),
    .N      (N  ),
    .BIN    (BIN),
    .COUT   (COUT),
    .BOUT   (BOUT),
    .CUT_METHOD("ROUND")
)dsp_cic_dec(
    .clk     ( clk      ),   // fs
    .rst_n   ( rst_n    ),
    .din     ( din      ),
    .dout    ( dout     ),
    .dout_cut( dout_cut ),
    .dvld    ( dvld     )    //dout valid
);

initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0,dsp_cic_dec);
    fp=$fopen("dout.txt","w");
    $readmemh("sine.txt",sine);
    wait(cnt0==2000)begin
        $fclose(fp);
        $finish;
    end
end
endmodule