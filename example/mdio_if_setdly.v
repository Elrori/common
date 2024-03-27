module mdio_if_setdly #(
    parameter DIV      = 1000,
    parameter PHYA_A1  = 5'b00_001,
    parameter PHYA_B1  = 5'b00_010,
    parameter PHYA_A2  = 5'b00_001,
    parameter PHYA_B2  = 5'b00_010,
    parameter PHYA_A3  = 5'b00_001,
    parameter PHYA_B3  = 5'b00_010,
    parameter PHYA_C1  = 5'b00_001,
    parameter PHYA_C2  = 5'b00_011,
    parameter PHYA_D   = 5'b00_001
)(
    input   wire        clk,
    input   wire        rst,

    output  wire        mdc,
    inout   wire        mdio_a1,
    inout   wire        mdio_b1,
    inout   wire        mdio_a2,
    inout   wire        mdio_b2,
    inout   wire        mdio_a3,
    inout   wire        mdio_b3,
    inout   wire        mdio_dd,
);
localparam IDLE = ;
reg [3:0]st;
reg       op_ena;
reg [4:0] op_phya;
reg [4:0] op_rega;
wire      op_done;
reg [15:0] op_din;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        
    end else begin
        case (st)
            0:begin
                op_ena <= 1'd1;
                op_phya<= PHYA_A1;
                op_rega<= 5'h1e;
                op_din <= 5'ha001;
            end 
            1:begin
                op_ena <= 1'd0;
                
            end
            default: ;
        endcase
    end
end
assign mdio_a1 = (st==1)?:1'dz;
assign mdio_b1 = (st==2)?:1'dz;
assign mdio_a2 = ()?:1'dz;
assign mdio_b2 = ()?:1'dz;
assign mdio_a3 = ()?:1'dz;
assign mdio_b3 = ()?:1'dz;
assign mdio_dd = ()?:1'dz;
mdio_if # (
    .DIV(DIV)
  )
mdio_if_inst (
    .clk(clk),
    .rst(rst),
    .mdc(mdc),
    .mdt(mdt),
    .mdo(mdo),
    .mdi(mdi),
    .op_ena(op_ena),
    .op_rdwr(1'd1),//wr:1
    .op_phya(op_phya),
    .op_rega(op_rega),
    .op_din(op_din),
    .op_dout(),
    .op_done(op_done)
);
endmodule