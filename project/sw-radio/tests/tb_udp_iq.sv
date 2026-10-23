`timescale 1ns/1ps
module tb_udp_iq;
    reg clk=0;
    always #4 clk=~clk;
    reg rst=1;
    reg axis_ready=0;
    reg [31:0] fifo_word=32'h89ab1234;
    reg [11:0] fifo_count=12'd256;
    wire fifo_rd_en, axis_valid, axis_last;
    wire [7:0] axis_data;
    wire [31:0] packet_count;
    integer n, word_index, cycles;
    reg [7:0] first_frame [0:1097];
    sw_udp_iq_tx dut (
        .clk(clk),.rst(rst),.tuned_hz(32'd7100000),
        .dropped_samples(32'd2),.fifo_word(fifo_word),
        .fifo_empty(1'b0),.fifo_count(fifo_count),
        .fifo_rd_en(fifo_rd_en),.axis_data(axis_data),
        .axis_valid(axis_valid),.axis_ready(axis_ready),
        .axis_last(axis_last),.packet_count(packet_count)
    );
    initial begin
        n=0; word_index=0; cycles=0;
        repeat(5) @(negedge clk);
        rst=0;
        repeat(5000) begin
            @(negedge clk);
            cycles=cycles+1;
            // Exercise AXI4-S ready/valid backpressure.
            axis_ready=(cycles%7 != 0);
            if (axis_valid && axis_ready && n<1098) begin
                first_frame[n]=axis_data;
                if (axis_last !== (n==1097)) $fatal(1,"bad TLAST at %0d",n);
                n=n+1;
            end
            if (fifo_rd_en) begin
                word_index=word_index+1;
                fifo_word=32'h89ab1234+word_index;
                fifo_count=fifo_count-1;
            end
            if (n==1098) begin
                if (first_frame[0]!==8'hff || first_frame[12]!==8'h08) $fatal(1,"Ethernet header");
                if (first_frame[16]!==8'h04 || first_frame[17]!==8'h3c) $fatal(1,"IPv4 length");
                if (first_frame[24]!==8'ha0 || first_frame[25]!==8'h5f) $fatal(1,"IP checksum");
                if (first_frame[38]!==8'h04 || first_frame[39]!==8'h28) $fatal(1,"UDP length");
                if (first_frame[42]!==8'h4b || first_frame[46]!==8'h03 || first_frame[47]!==8'h05) $fatal(1,"K9IQ v3");
                if (first_frame[58]!==8'hd0 || first_frame[59]!==8'h12 || first_frame[60]!==8'h13) $fatal(1,"sample rate");
                if (first_frame[74]!==8'h34 || first_frame[75]!==8'h12 || first_frame[76]!==8'hab || first_frame[77]!==8'h89) $fatal(1,"IQ first word");
                if (word_index!==256) $fatal(1,"fifo pops %0d != 256",word_index);
                $display("PASS: UDP IQ16 frame 1098 bytes, 256 complex samples, backpressure and CRC-IP fields");
                $finish;
            end
        end
        $fatal(1,"timed out: n=%0d",n);
    end
endmodule
