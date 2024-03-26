module mdio_if #(
    parameter DIV      = 1000
)(
    input   wire        clk,
    input   wire        rst,

    output  wire        mdc,
    inout   wire        mdio,

    input   wire        op_ena,
    input   wire        op_rdwr,
    input   wire  [4 :0]op_phya,
    input   wire  [4 :0]op_rega,
    input   wire  [15:0]op_din,
    output  wire  [15:0]op_dout,
    output  wire        op_done
);
reg [10:0]cnt0;
reg [6 :0]cnt1;
reg clk_ena;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cnt0    <= 'd0;
        clk_ena <= 'd0;
    end else begin
        if (cnt0 >= DIV - 1) begin
            cnt0 <= 'd0;
        end else begin
            cnt0 <= cnt0 + 1'd1;
        end
        if (cnt0 == DIV - 1) begin
            clk_ena <= 1'd1;
        end else begin
            clk_ena <= 1'd0;
        end
    end
end
endmodule