// One-deep, acknowledged multi-bit register transfer: no torn tuning words.
// Deliberately coalesces commands arriving faster than the destination accepts.
module sw_control_cdc #(parameter integer WIDTH=32) (
    input wire src_clk, input wire src_rst,
    input wire src_update, input wire [WIDTH-1:0] src_value,
    input wire dst_clk, input wire dst_rst,
    output reg [WIDTH-1:0] dst_value,
    output reg dst_pulse
);
    reg [WIDTH-1:0] hold_value;
    reg request_toggle, ack_m1, ack_m2;
    reg req_m1, req_m2, acknowledge;
    reg [1:0] settle;
    always @(posedge src_clk) begin
        if (src_rst) begin
            hold_value <= 0; request_toggle <= 0;
            ack_m1 <= 0; ack_m2 <= 0;
        end else begin
            ack_m1 <= acknowledge;
            ack_m2 <= ack_m1;
            if (src_update && (ack_m2 == request_toggle)) begin
                hold_value <= src_value;
                request_toggle <= ~request_toggle;
            end
        end
    end
    always @(posedge dst_clk) begin
        if (dst_rst) begin
            req_m1 <= 0; req_m2 <= 0; acknowledge <= 0;
            dst_value <= 0; dst_pulse <= 0; settle <= 0;
        end else begin
            req_m1 <= request_toggle;
            req_m2 <= req_m1;
            dst_pulse <= 0;
            if (req_m2 != acknowledge) begin
                if (settle == 2) begin
                    dst_value <= hold_value;
                    dst_pulse <= 1;
                    acknowledge <= req_m2;
                    settle <= 0;
                end else settle <= settle + 1'b1;
            end else settle <= 0;
        end
    end
endmodule
