module rgmii_tx (
    input  wire       clk,
    input  wire       clk90,
    input  wire [7:0] tx_byte,
    input  wire       tx_valid,
    output wire       rgmii_tx_clk,
    output wire [3:0] rgmii_txd,
    output wire       rgmii_tx_ctl
);
    genvar n;
    generate
        for (n = 0; n < 4; n = n + 1) begin : g_data
            ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .SRTYPE("SYNC")) data_oddr (
                .C(clk), .CE(1'b1), .D1(tx_byte[n]), .D2(tx_byte[n+4]),
                .Q(rgmii_txd[n]), .R(1'b0), .S(1'b0)
            );
        end
    endgenerate
    ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .SRTYPE("SYNC")) ctl_oddr (
        .C(clk), .CE(1'b1), .D1(tx_valid), .D2(tx_valid),
        .Q(rgmii_tx_ctl), .R(1'b0), .S(1'b0)
    );
    // XI050CD's PHY is strapped for its internal RGMII TX delay.  Match the
    // board's proven example and forward the unshifted clock here.
    ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .SRTYPE("SYNC")) clk_oddr (
        .C(clk), .CE(1'b1), .D1(1'b1), .D2(1'b0),
        .Q(rgmii_tx_clk), .R(1'b0), .S(1'b0)
    );
endmodule
