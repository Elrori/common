// apb multi-mdio support
module mdio_if_apb #(
    parameter DIV      = 1000
    // ,parameter PHYA_A1  = 5'b00_001,
    // parameter PHYA_B1  = 5'b00_010,
    // parameter PHYA_A2  = 5'b00_001,
    // parameter PHYA_B2  = 5'b00_010,
    // parameter PHYA_A3  = 5'b00_001,
    // parameter PHYA_B3  = 5'b00_010,
    // parameter PHYA_C1  = 5'b00_001,
    // parameter PHYA_C2  = 5'b00_011,
    // parameter PHYA_D   = 5'b00_001
)(
    // CLOCK
    input   wire        clk,
    input   wire        rst,
    // MDIO
    output  wire        mdc,
    output  reg  [4 :0] mdo,
    input   wire [4 :0] mdi,
    output  reg  [4 :0] mdt,
    // APB3
    input   wire [15:0] paddr, // | 4bits bus select | 5bits phyaddr | 1bit dummy | 5bits regaddr | 1bit dummy |
    input   wire        pwrite,
    input   wire        psel,
    input   wire        penable,
    input   wire [15:0] pwdata,
    output  reg  [15:0] prdata,
    output  reg         pready
);
reg [3:0] st;
reg       op_ena;
reg       op_rdwr;
reg [4:0] op_phya;
reg [4:0] op_rega;
wire      op_done;
reg [15:0] op_din;
wire[15:0] op_dout;
reg [3:0] bus_sel;
wire mdt_w;
wire mdo_w;
reg  mdi_w;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        bus_sel <= 'd0;
        op_phya <= 'd0;
        op_rega <= 'd0;
        op_rdwr <= 'd0;
        op_ena  <= 'd0;
        op_din  <= 'd0;
        st      <= 'd0;
        pready  <= 1'd0;
        prdata  <= 'd0;
    end else begin
        case (st)
            0:begin
                if (psel) begin
                    bus_sel <= paddr[15:12];
                    op_phya <= paddr[11:7];
                    op_rega <= paddr[5:1];
                    op_rdwr <= pwrite;
                    op_ena  <= 1'd1;
                    op_din  <= pwrite ? pwdata : 16'h0;
                    st <= st + 1'd1;
                end
            end 
            1:begin
                op_ena  <= 1'd0;
                if (op_done) begin
                    pready <= 1'd1;
                    prdata <= op_dout;
                    st <= st + 1'd1;
                end
            end
            2:begin
                pready <= 1'd0;
                st     <= 'd0;
            end
            default: begin
                bus_sel <= 'd0;
                op_phya <= 'd0;
                op_rega <= 'd0;
                op_rdwr <= 'd0;
                op_ena  <= 'd0;
                op_din  <= 'd0;
                st      <= 'd0;
                pready  <= 1'd0;
                prdata  <= 'd0;
            end
        endcase
    end
end
always @(*) begin
    mdo    = 'd0;
    mdt    = 'd0;
    case (bus_sel)
        0:begin
            mdo[0] = mdo_w;
            mdt[0] = mdt_w;
            mdi_w  = mdi[0];
        end 
        1:begin
            mdo[1] = mdo_w;
            mdt[1] = mdt_w;
            mdi_w  = mdi[1];
        end 
        2:begin
            mdo[2] = mdo_w;
            mdt[2] = mdt_w;
            mdi_w  = mdi[2];
        end 
        3:begin
            mdo[3] = mdo_w;
            mdt[3] = mdt_w;
            mdi_w  = mdi[3];
        end 
        4:begin
            mdo[4] = mdo_w;
            mdt[4] = mdt_w;
            mdi_w  = mdi[4];
        end 
        default: begin
            mdo    = 'd0;
            mdt    = 'd0;
            mdi_w  = 1'd0;
        end
    endcase
end

mdio_if # (
    .DIV(DIV)
  )
mdio_if_inst (
    .clk(clk),
    .rst(rst),
    .mdc(mdc),
    .mdt(mdt_w),
    .mdo(mdo_w),
    .mdi(mdi_w),
    .op_ena(op_ena),
    .op_rdwr(op_rdwr),//wr:1
    .op_phya(op_phya),
    .op_rega(op_rega),
    .op_din(op_din),
    .op_dout(op_dout),
    .op_done(op_done)
);
endmodule