// K9+/XI050CD: proven 25 MHz oscillator, MMCM clocks for SDR and IDELAYCTRL.
module sw_clock_gen (
    input  wire clk25,
    output wire clk40,
    output wire clk200,
    output wire locked
);
    wire feedback_raw, feedback, clk40_raw, clk200_raw;
    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"), .CLKIN1_PERIOD(40.0),
        .DIVCLK_DIVIDE(1), .CLKFBOUT_MULT_F(40.0),
        .CLKOUT0_DIVIDE_F(25.0), .CLKOUT1_DIVIDE(5),
        .CLKOUT0_PHASE(0.0), .CLKOUT1_PHASE(0.0),
        .STARTUP_WAIT("FALSE")
    ) mmcm (
        .CLKIN1(clk25), .CLKFBIN(feedback), .CLKFBOUT(feedback_raw),
        .CLKOUT0(clk40_raw), .CLKOUT1(clk200_raw),
        .LOCKED(locked), .PWRDWN(1'b0), .RST(1'b0)
    );
    BUFG buf_feedback(.I(feedback_raw), .O(feedback));
    BUFG buf_adc(.I(clk40_raw), .O(clk40));
    BUFG buf_delay(.I(clk200_raw), .O(clk200));
endmodule
