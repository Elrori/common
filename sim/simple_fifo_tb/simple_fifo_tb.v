`timescale 1ns/ 1ps
module simple_fifo_tb();
parameter DATA_WIDTH=8;
parameter ADDR_WIDTH=4;
reg         clk=0;
reg         rst=1;
reg         wr_ena=0  ;
reg   [DATA_WIDTH-1:0]wr_dat=0  ;
wire        wr_full ;
reg         rd_ena=0  ;
wire  [DATA_WIDTH-1:0]rd_dat  ;
wire        rd_empty;
wire  [ADDR_WIDTH:0]  dat_cnt ;



always #10 clk <= ~clk;
simple_fifo#(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) simple_fifo_tb(
    .rst     (rst),    
    .clk     (clk), 
    .wr_ena  (wr_ena  ),    
    .wr_dat  (wr_dat  ), 
    .wr_full (wr_full ),
    .rd_ena  (rd_ena  ),    
    .rd_dat  (rd_dat  ), 
    .rd_empty(rd_empty),
    .dat_cnt (dat_cnt ) 
);
task nop;
    input integer n;
    begin repeat(n)begin @(posedge clk) #0; end end
endtask

task push;
    input [DATA_WIDTH-1:0]dat;
    begin
        wr_ena = 1;
	wr_dat = dat;
        @(posedge clk) #0;
        wr_ena = 0;
    end
endtask
task pop;
    output [DATA_WIDTH-1:0]dat;
    begin
        rd_ena = 1;
        @(posedge clk)#0;
        rd_ena = 0;
	dat    = rd_dat;
    end
endtask

integer i;
integer ret;
initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0,simple_fifo_tb );
    #10 rst = 0;
    @(posedge clk)#0;
    $display("--test 1");
    for(i=0;i<20;i=i+1)begin
        push(i); 
	$display("push %0d",i);
    end

    for(i=0;i<20;i=i+1)begin
        pop(ret);
        $display("pop %0d",ret);
    end

    $display("--test 2");
    for(i=0;i<20;i=i+1)begin
	ret = {$random}%256;
        push(ret); 
	$display("push %0d",ret);
    end

    for(i=0;i<20;i=i+1)begin
        pop(ret);
        $display("pop %0d",ret);
    end
    $display("--test 3");

    push(1);
    $display("push %0d",1);
    push(2);
    $display("push %0d",2);
    push(3);
    $display("push %0d",3);
    push(4);
    $display("push %0d",4);
    pop(ret);
    $display("pop %0d",ret);
    pop(ret);
    $display("pop %0d",ret);
    pop(ret);
    $display("pop %0d",ret);

    push(1);
    $display("push %0d",1);
    push(2);
    $display("push %0d",2);
    push(3);
    $display("push %0d",3);
    push(4);
    $display("push %0d",4);

    pop(ret);
    $display("pop %0d",ret);
    pop(ret);
    $display("pop %0d",ret);
    pop(ret);
    $display("pop %0d",ret);
    
    push(1);
    $display("push %0d",1);
    push(2);
    $display("push %0d",2);
    push(3);
    $display("push %0d",3);
    push(4);
    $display("push %0d",4);

    pop(ret);
    $display("pop %0d",ret);
    pop(ret);
    $display("pop %0d",ret);
    pop(ret);
    $display("pop %0d",ret);
    pop(ret);
    $display("pop %0d",ret);
    pop(ret);
    $display("pop %0d",ret);
    pop(ret);
    $display("pop %0d",ret);

    $display("--test 4");

    wr_ena = 1;
    wr_dat = 9;
    @(posedge clk)#0;
    rd_ena = 1;
    nop(100);
    wr_ena = 0;
    @(posedge clk)#0;
    rd_ena = 0;

    #100;
    $finish;
end
endmodule
