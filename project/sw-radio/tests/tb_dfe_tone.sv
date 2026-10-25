`timescale 1ns/1ps
// End-to-end fixed-point DFE smoke test: 62.5 MSPS input, 7.8125 MHz tone,
// matching 32-bit FCW; ensure I/Q strobes align and 1.25 MSPS cadence.
module tb_dfe_tone;
    reg clk=0; always #8 clk=~clk;
    reg rst_n=0;
    reg [11:0] adc_dat=0;
    wire [31:0] i_out, q_out;
    wire i_valid,q_valid;
    integer tick=0, count=0, unexpected=0;
    longint signed i_total=0, q_total=0;
    reg signed [11:0] sample;
    sys_sw_dfe_1mhz_nco14_62m5 dut (
        .clk_adc(clk),.rst_n(rst_n),.adc_dat(adc_dat),
        .phi_inc(32'h20000000),
        .sin_fir(i_out),.cos_fir(q_out),
        .sin_fir_vld(i_valid),.cos_fir_vld(q_valid)
    );
    always @(negedge clk) begin
        case(tick%8)
            0:sample=0; 1:sample=1061;
            2:sample=1500; 3:sample=1061;
            4:sample=0; 5:sample=-1061;
            6:sample=-1500; 7:sample=-1061;
        endcase
        adc_dat=sample;
        tick=tick+1;
    end
    always @(posedge clk) begin
        if (rst_n) begin
            if (i_valid!==q_valid) unexpected=unexpected+1;
            if (i_valid) begin
                count=count+1;
                if (count>200) begin
                    if ((^i_out)===1'bx || (^q_out)===1'bx) $fatal(1,"invalid output X");
                    i_total=i_total+$signed(i_out);
                    q_total=q_total+$signed(q_out);
                    if (count>=220 && count<226)
                        $display("DFE output I=%0d Q=%0d",$signed(i_out),$signed(q_out));
                end
            end
        end
    end
    initial begin
        repeat(10) @(posedge clk);
        @(negedge clk);rst_n=1;
        repeat(32000) @(posedge clk);
        if (unexpected!=0) $fatal(1,"I/Q not aligned: %0d",unexpected);
        if (count<500 || count>620) $fatal(1,"output rate invalid: %0d",count);
        if (i_total==0 || q_total==0) $display("NOTE one I/Q mean is near zero (expected for DC tone)");
        if ((i_total<1000000 && i_total>-1000000) &&
            (q_total<1000000 && q_total>-1000000))
            $fatal(1,"NCO mixer or FIR no significant signal: %0d %0d",i_total,q_total);
        $display("PASS: DFE NCO14/MIX18/CIC20/FIR47: IQ strobes aligned; outputs=%0d; I_sum=%0d Q_sum=%0d",count,i_total,q_total);
        $finish;
    end
endmodule
