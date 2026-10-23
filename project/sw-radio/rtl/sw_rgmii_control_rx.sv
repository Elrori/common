// PHY0 RGMII input timing copied from the K9+ board's verified IDELAY12/IDDR
// interface. Command parser accepts UDP/IPv4 destination port 50001 only.
// "K9TU" + uint32LE Hz + uint32LE FCW (40 MHz); "K9AG" + uint8 gain.
module sw_rgmii_control_rx (
    input wire phy_clk, input wire idelay_refclk,
    input wire idelay_rst, input wire rst,
    input wire [3:0] rgmii_rxd, input wire rgmii_rx_ctl,
    output wire clk,
    output reg [31:0] tune_hz,
    output reg [31:0] phase_increment,
    output reg tune_pulse,
    output reg [7:0] gain_value,
    output reg gain_pulse
);
    assign clk=phy_clk;
    wire [4:0] raw={rgmii_rxd, rgmii_rx_ctl};
    wire [4:0] delayed, rising, falling;
    IDELAYCTRL delay_control(.REFCLK(idelay_refclk),.RST(idelay_rst),.RDY());
    genvar i;
    generate for(i=0;i<5;i=i+1) begin: rgmii_input
        IDELAYE2 #(
            .CINVCTRL_SEL("FALSE"),.DELAY_SRC("IDATAIN"),
            .HIGH_PERFORMANCE_MODE("TRUE"),.IDELAY_TYPE("FIXED"),
            .IDELAY_VALUE(12),.PIPE_SEL("FALSE"),
            .REFCLK_FREQUENCY(200.0),.SIGNAL_PATTERN("DATA")
        ) idealy (
            .DATAOUT(delayed[i]),.DATAIN(1'b0),.C(phy_clk),
            .CE(1'b0),.INC(1'b0),.IDATAIN(raw[i]),
            .CNTVALUEIN(5'd0),.CNTVALUEOUT(),.LD(1'b0),
            .LDPIPEEN(1'b0),.REGRST(1'b0),.CINVCTRL(1'b0)
        );
        IDDR #(.DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),.SRTYPE("ASYNC"))
        in_ddr(.C(phy_clk),.CE(1'b1),.D(delayed[i]),
            .R(1'b0),.S(1'b0),.Q1(rising[i]),.Q2(falling[i]));
    end endgenerate

    wire [7:0] gmii_data={falling[4:1], rising[4:1]};
    wire gmii_valid=rising[0];
    sw_udp_control_parser parser (
        .clk(phy_clk),.rst(rst),.rx_valid(gmii_valid),
        .rx_data(gmii_data),.tune_hz(tune_hz),
        .phase_increment(phase_increment),.tune_pulse(tune_pulse),
        .gain_value(gain_value),.gain_pulse(gain_pulse)
    );
endmodule

// Isolated parser is directly simulatable without Xilinx transceiver primitives.
module sw_udp_control_parser (
    input wire clk, input wire rst,
    input wire rx_valid, input wire [7:0] rx_data,
    output reg [31:0] tune_hz, phase_increment,
    output reg tune_pulse,
    output reg [7:0] gain_value,
    output reg gain_pulse
);
    reg seen_55, in_frame;
    reg [10:0] idx;
    reg eth_ok, proto_ok, port_ok, tune_magic, gain_magic;
    reg [31:0] pending_hz, pending_fcw;
    always @(posedge clk) begin
        if (rst) begin
            seen_55<=0; in_frame<=0; idx<=0;
            eth_ok<=0; proto_ok<=0; port_ok<=0;
            tune_magic<=0; gain_magic<=0;
            tune_hz<=0; phase_increment<=0; tune_pulse<=0;
            gain_value<=0; gain_pulse<=0;
            pending_hz<=0; pending_fcw<=0;
        end else begin
            tune_pulse<=0;
            gain_pulse<=0;
            if (!rx_valid) begin
                seen_55<=0; in_frame<=0; idx<=0;
            end else if (!in_frame) begin
                if (rx_data==8'h55) seen_55<=1;
                else if (rx_data==8'hd5 && seen_55) begin
                    in_frame<=1; idx<=0;
                    eth_ok<=1; proto_ok<=1; port_ok<=1;
                    tune_magic<=1; gain_magic<=1;
                end else seen_55<=0;
            end else begin
                idx<=idx+1'b1;
                case(idx)
                    12:eth_ok<=eth_ok && rx_data==8'h08;
                    13:eth_ok<=eth_ok && rx_data==8'h00;
                    23:proto_ok<=proto_ok && rx_data==8'h11;
                    36:port_ok<=port_ok && rx_data==8'hc3;
                    37:port_ok<=port_ok && rx_data==8'h51;
                    42:begin
                        tune_magic<=rx_data==8'h4b;
                        gain_magic<=rx_data==8'h4b;
                    end
                    43:begin
                        tune_magic<=tune_magic && rx_data==8'h39;
                        gain_magic<=gain_magic && rx_data==8'h39;
                    end
                    44:begin
                        tune_magic<=tune_magic && rx_data==8'h54;
                        gain_magic<=gain_magic && rx_data==8'h41;
                    end
                    45:begin
                        tune_magic<=tune_magic && rx_data==8'h55;
                        gain_magic<=gain_magic && rx_data==8'h47;
                    end
                    46:begin
                        pending_hz[7:0]<=rx_data;
                        if (eth_ok && proto_ok && port_ok && gain_magic) begin
                            gain_value<=rx_data;
                            gain_pulse<=1;
                        end
                    end
                    47:pending_hz[15:8]<=rx_data;
                    48:pending_hz[23:16]<=rx_data;
                    49:pending_hz[31:24]<=rx_data;
                    50:pending_fcw[7:0]<=rx_data;
                    51:pending_fcw[15:8]<=rx_data;
                    52:pending_fcw[23:16]<=rx_data;
                    53:if (eth_ok && proto_ok && port_ok && tune_magic) begin
                        tune_hz<=pending_hz;
                        phase_increment<={rx_data,pending_fcw[23:0]};
                        tune_pulse<=1;
                    end
                    default:begin end
                endcase
            end
        end
    end
endmodule
