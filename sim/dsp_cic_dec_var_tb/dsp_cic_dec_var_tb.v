/*
*   Name        :dsp_cic_dec_var tb
*   Description :
*   Origin      :
*   Author      :
*/
`timescale  1ns / 1ps
module dsp_cic_dec_var_tb;
parameter M     = 1 ;           // 
parameter N     = 3 ;           // 
parameter BIN   = `WIDTH;       // 
parameter COUT  = 16;           // 
parameter BOUT  = (BIN + $clog2((512*M)**N));
parameter PERIOD = 25;          // 40Mhz
parameter fs    = 10_000_000_000/PERIOD;   // Sampling rate

reg  clk   = 0;
reg  rst_n = 0;
wire dout_vld;
integer fp;
reg  [8 :0]dec_fac = 199;
reg  [63:0]cnt0=0,cnt1=0;
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
    if (dout_vld) begin
        $fwrite(fp,"%d\n",dout);
        cnt0 <= cnt0 + 1;
    end
end
dsp_cic_dec_var #(
    .M      (M  ),
    .N      (N  ),
    .BIN    (BIN),
    .COUT   (COUT),
    .BOUT   (BOUT),
    .CUT_METHOD("ROUND")
)dsp_cic_dec_var(
    .clk     ( clk      ),   // fs
    .rst_n   ( rst_n    ),
    .dec_fac ( dec_fac  ),
    .din     ( din      ),
    .dout    ( dout     ),
    .dout_cut( dout_cut ),
    .dout_vld( dout_vld )    //dout valid
);

initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0,dsp_cic_dec_var);
    $display("dsp_cic_dec_var_tb conf:");
    $display("M                         : %0d",M     );
    $display("N                         : %0d",N     );
    $display("BIN  (din width)          : %0d",BIN   );
    $display("COUT (dout cut width)     : %0d",COUT  );
    $display("BOUT (origin dout width)  : %0d",BOUT  );
    $display("PERIOD                    : %0d ns",PERIOD); 
    $display("fs                        : %0d sps",fs );
    fp=$fopen("dout.txt","w");
    $readmemh("sine.txt",sine);
    wait(cnt0==2000)begin
        $fclose(fp);
        $finish;
    end
end
endmodule