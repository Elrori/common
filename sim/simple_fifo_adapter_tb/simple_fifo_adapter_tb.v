`timescale 1ns/ 1ps
module simple_fifo_adapter_tb();
parameter DATA_IN_WIDTH=16;
parameter DATA_OUT_WIDTH=128;
parameter ADDR_WIDTH=4;
parameter USE_LAST=1;
reg         clk=0;
reg         rst=1;
reg         wr_ena=0  ;
reg   [DATA_IN_WIDTH-1:0]wr_dat=0  ;
wire        wr_full ;
reg         rd_ena=0  ;
wire  [DATA_OUT_WIDTH-1:0]rd_dat  ;
wire        rd_empty;
wire  [ADDR_WIDTH:0]  dat_cnt ;

reg wr_last=0;
wire rd_last;

always #10 clk <= ~clk;

simple_fifo_adapter # (
    .DATA_IN_WIDTH(DATA_IN_WIDTH),
    .DATA_OUT_WIDTH(DATA_OUT_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .FULL_SLACK(1)
  )
  simple_fifo_adapter_inst (
    .rst(rst),
    .clk(clk),
    .wr_ena(wr_ena),
    .wr_dat(wr_dat),
    .wr_full(wr_full),
    .rd_ena(rd_ena),
    .rd_dat(rd_dat),
    .rd_empty(rd_empty),
    .rd_dat_cnt(dat_cnt)
  );

task nop;
    input integer n;
    begin repeat(n)begin @(posedge clk) #0; end end
endtask

task push;
    input [DATA_IN_WIDTH-1:0]dat;
    begin
        wr_ena = 1;
        wr_dat = dat;
        @(posedge clk) #0;
        wr_ena = 0;
    end
endtask
task pop;
    output [DATA_OUT_WIDTH-1:0]dat;
    begin
        rd_ena = 1;
        @(posedge clk)#0;
        rd_ena = 0;
	dat    = rd_dat;
    end
endtask
task push_frame;
    input integer len;
    begin
        for(i=0;i<len;i=i+1)begin
            if(i==len-1)begin
                wr_last=1;
	    end
            push(i);
            wr_last=0;
        end
    end
endtask
task pop_frame;
    input integer len;
    integer ret;
    begin
        for(i=0;i<len;i=i+1)begin
            pop(ret);
        end
    end
endtask

integer i;
reg[127:0] ret;
initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0,simple_fifo_adapter_tb );
    #10 rst = 0;
    @(posedge clk)#0;


    $display("--test 0");
    push_frame(32);
    nop(10);
    pop_frame(4);

    $display("--test 1");
    for(i=0;i<128;i=i+1)begin
        push(i); 
	$display("push %0x",i);
    end

    nop(100);
    for(i=0;i<16;i=i+1)begin
        pop(ret);
        $display("pop %32x",ret);
    end

    
    $display("--test 2");
    for(i=0;i<16;i=i+1)begin
	ret = {$random}%256;
        push(ret); 
	$display("push %0x",ret);
    end
    nop(100);
    for(i=0;i<2;i=i+1)begin
        pop(ret);
        $display("pop %32x",ret);
    end
    wr_ena = 1;
    wr_dat = 9;
    nop(32);
    rd_ena = 1;
    nop(32);
    wr_ena = 0;
    @(posedge clk)#0;
    rd_ena = 0;

    #100;
    $finish;
end
endmodule
