`timescale 1ns/1ps
module tb_control;
    reg clk=0; always #4 clk=~clk;
    reg rst=1, rx_valid=0;
    reg [7:0] rx_data=0;
    wire [31:0] tune_hz, fcw;
    wire tune_pulse, gain_pulse;
    wire [7:0] gain_value;
    integer p, tune_events=0, gain_events=0;
    sw_udp_control_parser dut (.clk(clk),.rst(rst),
        .rx_valid(rx_valid),.rx_data(rx_data),
        .tune_hz(tune_hz),.phase_increment(fcw),
        .tune_pulse(tune_pulse),.gain_value(gain_value),
        .gain_pulse(gain_pulse));
    always @(posedge clk) if (!rst) begin
        if (tune_pulse) tune_events<=tune_events+1;
        if (gain_pulse) gain_events<=gain_events+1;
    end
    task automatic frame(input bit gain);
        integer i;
        reg [7:0] b;
        begin
            for (i=0;i<8;i=i+1) begin
                @(negedge clk);rx_valid=1;rx_data=(i==7)?8'hd5:8'h55;
            end
            for (i=0;i<60;i=i+1) begin
                b=0;
                case(i)
                    12:b=8'h08; 13:b=0; 23:b=8'h11;
                    36:b=8'hc3; 37:b=8'h51;
                    42:b=8'h4b; 43:b=8'h39;
                    44:b=gain?8'h41:8'h54;
                    45:b=gain?8'h47:8'h55;
                    46:b=gain?8'h80:8'h60;
                    47:b=8'h56;48:b=8'h6c;49:b=0; // 7,100,000 = 0x006c5660
                    50:b=8'h44;51:b=8'h33;52:b=8'h22;53:b=8'h11;
                endcase
                @(negedge clk);rx_data=b;
            end
            @(negedge clk);rx_valid=0;rx_data=0;
            repeat(3) @(negedge clk);
        end
    endtask
    initial begin
        repeat(5) @(negedge clk);rst=0;
        frame(0);
        if (tune_events!==1 || tune_hz!==32'h006c5660 || fcw!==32'h11223344)
            $fatal(1,"tune parser/events failed %0d %h %h",tune_events,tune_hz,fcw);
        frame(1);
        if (gain_events!==1 || gain_value!==8'h80 || tune_events!==1)
            $fatal(1,"gain parser/events failed");
        $display("PASS: K9TU/K9AG exact one event, byte-order and UDP filter");
        $finish;
    end
endmodule
