/* 
*   Name  : data asynchronous bridge tb
*   Origin: 230404
*   EE    : hel
*/
`timescale 1ns/1ps
module cdc_pulse_data_tb ();
parameter DW = 8;
reg s_clk  = 0;
reg s_rstn = 0;
reg [DW-1:0] s_din = 0;
reg s_vld = 0;
reg d_clk  = 0;
reg d_rstn = 0;
wire [DW-1:0] d_dout;
wire d_vld;
wire active;
reg [DW-1:0]buffer ;
real ts;
real td;
real a;
real b;
real clkstp;
always #(ts)  s_clk <= ~s_clk;
always #(td)  d_clk <= ~d_clk;
cdc_pulse_data #(DW) cdc_pulse_data
(
    .s_clk   ( s_clk  ),
    .s_rstn  ( s_rstn ),
    .s_din   ( s_din  ),
    .s_vld   ( s_vld  ),
    .d_clk   ( d_clk  ),
    .d_rstn  ( d_rstn ),
    .d_dout  ( d_dout ),
    .d_vld   ( d_vld  ),
    .active  ( active )
);
task automatic gen_trans;
input [DW-1:0]data;
begin
    #0
    s_vld  =  1;
    s_din  = data;
    @(posedge s_clk);
    #0
    s_vld  =  0;
    s_din  =  0;
end
endtask //automatic

task automatic wait_busy;
begin
    @(posedge s_clk);#0;
    while (active) begin
        @(posedge s_clk);#0;
    end
end
endtask //automatic

task automatic loop_test;
input integer n;
integer i;
reg [63:0]random_dat;
begin
    for (i = 0;i<n ;i=i+1 ) begin
        random_dat = {$random} % (2**DW);
        gen_trans(random_dat[DW-1:0]);
        wait_busy;  
        if (buffer != random_dat[DW-1:0]) begin
            $display("error missmatch, send:0x%x, recv:0x%x",random_dat[DW-1:0],buffer);
            #100
            $finish;
        end 
        $display("%0d/%0d 0x%0x==0x%0x",i+1,n,random_dat[DW-1:0],buffer);     
    end
    $display("FULL PASS %0d",n);
end
endtask //automatic

always @(posedge d_clk) begin
    buffer <= (d_vld)?d_dout:buffer;
end

initial begin 
    ts = 3.333;
    td = 10.567;
    #3000;
    ts = 10.567;
    td = 3.333;
    while ( clkstp!=1 ) begin
        #3000;
        a = {$random}%300;
        b = {$random}%300;
        ts = a<10 ?10:a;
        td = b<10 ?10:b;
    end
end
initial begin
    // $dumpfile("wave.vcd");               
    // $dumpvars(0, cdc_pulse_data);      
    clkstp = 0;
    #10 s_rstn = 1;
    #10 d_rstn = 1;
    #10;
    @(posedge s_clk);
    loop_test(10000);
    #1000;
    clkstp = 1;
    $finish;
end
endmodule
