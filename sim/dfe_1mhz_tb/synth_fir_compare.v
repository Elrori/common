// Small synthesizable wrappers for comparing FIR footprints in Yosys.
// Run from repository root.  All three expose exactly the same interface;
// synthesis results are technology-independent, not Intel ALM or DSP counts.
module synth_fir_old (
    input wire clk, rst_n,
    input wire [15:0] din,
    input wire din_val,
    output wire [31:0] dout,
    output wire dout_val
);
    dsp_fir_dec #(
        .R(2), .COE_FILE("sim/dfe_1mhz_tb/legacy_fir_comp31.hex"),
        .CLOCK_PER_SAMPLE(20)
    ) u (
        .clk(clk), .rst_n(rst_n), .din(din), .din_val(din_val),
        .dout(dout), .dout_val(dout_val)
    );
endmodule

module synth_fir_18 (
    input wire clk, rst_n,
    input wire signed [17:0] din,
    input wire din_val,
    output wire signed [31:0] dout,
    output wire dout_val
);
    dsp_fir_dec_sym #(.W_DIN(18)) u (
        .clk(clk), .rst_n(rst_n), .din(din), .din_val(din_val),
        .dout(dout), .dout_val(dout_val)
    );
endmodule

module synth_fir_20 (
    input wire clk, rst_n,
    input wire signed [19:0] din,
    input wire din_val,
    output wire signed [31:0] dout,
    output wire dout_val
);
    dsp_fir_dec_sym #(.W_DIN(20)) u (
        .clk(clk), .rst_n(rst_n), .din(din), .din_val(din_val),
        .dout(dout), .dout_val(dout_val)
    );
endmodule
