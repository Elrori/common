`timescale 1ns/1ps
module tb_spi8370;
    reg clk=0; always #12.5 clk=~clk;
    reg rst_n=0, wr_en=0;
    reg [7:0] wr_dat=8'ha5;
    wire wr_fin,sclk,mosi,ltch;
    reg [7:0] observed=0;
    integer bits=0, finish_count=0;
    spi8370 #(.DIV(10)) dut (
        .clk(clk),.rst_n(rst_n),.wr_en(wr_en),.wr_dat(wr_dat),
        .wr_fin(wr_fin),.sclk(sclk),.mosi(mosi),.ltch(ltch));
    always @(posedge sclk) if(rst_n && !ltch && bits<8) begin
        observed={observed[6:0],mosi};
        bits=bits+1;
    end
    always @(posedge clk) if(wr_fin) finish_count=finish_count+1;
    initial begin
        repeat(5) @(negedge clk);rst_n=1;
        @(negedge clk);wr_en=1;
        @(negedge clk);wr_en=0;
        repeat(150) @(posedge clk);
        if(bits!=8 || observed!==8'ha5 || finish_count!=1 || ltch!==1)
            $fatal(1,"SPI failed: bits=%0d observed=%h fin=%0d latch=%d",bits,observed,finish_count,ltch);
        $display("PASS: AD8370 SPI 8-bit MSB-first word=0xA5, finish and latch");
        $finish;
    end
endmodule
