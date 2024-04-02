module phy_dlyset #(
    parameter DIV      = 10000,
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
    // CLOCK
    input   wire        clk,
    input   wire        rst,
    // MDIO
    output  wire        mdc,
    output  wire [4 :0] mdo,
    input   wire [4 :0] mdi,
    output  wire [4 :0] mdt,
    // DLY
    input   wire            set_ena,
    input   wire [8 :0]     set_rxcdlyena,// D C2 C1 B3 A3 B2 A2 B1 A1
    input   wire [4*9-1 :0] set_rxcdlysel // 
);
localparam MASK_2NS = 16'b0000_0001_0000_0000;
localparam MASK_DEL = 16'b0011_1100_0000_0000;
reg [2:0] state_rdset;
reg [3:0] state_chips;
reg psel;
reg pwrite;
reg [15:0] paddr;
reg [15:0] pwdata;
wire [15:0] prdata;
wire pready;

reg start_rdset;
reg chip_2ns;
reg [3:0]chip_dlysel;
reg [8:0]chip_sel;

reg [15:0]buf_a;
wire rdset_fin;
assign rdset_fin = state_rdset == 0 && pready;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state_chips <= 'd0;
        start_rdset <= 'd0;
        chip_2ns    <= 'd0;
        chip_dlysel <= 'd0;
        chip_sel    <= 'd0;
    end else begin
        case (state_chips)
            0:begin
                if (set_ena) begin
                    state_chips <= state_chips + 1'd1;
                    start_rdset <= 1'd1;
                    chip_2ns    <= set_rxcdlyena[0];
                    chip_dlysel <= set_rxcdlysel[3:0];
                    chip_sel    <= {4'd0,PHYA_A1};
                end
            end 
            1:begin
                if (rdset_fin) begin
                    state_chips <= state_chips + 1'd1;
                    start_rdset <= 1'd1;
                    chip_2ns    <= set_rxcdlyena[1];
                    chip_dlysel <= set_rxcdlysel[7:4];
                    chip_sel    <= {4'd0,PHYA_B1};
                end
            end

            2:begin
                if (rdset_fin) begin
                    state_chips <= state_chips + 1'd1;
                    start_rdset <= 1'd1;
                    chip_2ns    <= set_rxcdlyena[2];
                    chip_dlysel <= set_rxcdlysel[11:8];
                    chip_sel    <= {4'd1,PHYA_A2};
                end
            end
            3:begin
                if (rdset_fin) begin
                    state_chips <= state_chips + 1'd1;
                    start_rdset <= 1'd1;
                    chip_2ns    <= set_rxcdlyena[3];
                    chip_dlysel <= set_rxcdlysel[15:12];
                    chip_sel    <= {4'd1,PHYA_B2};
                end
            end

            4:begin
                if (rdset_fin) begin
                    state_chips <= state_chips + 1'd1;
                    start_rdset <= 1'd1;
                    chip_2ns    <= set_rxcdlyena[4];
                    chip_dlysel <= set_rxcdlysel[19:16];
                    chip_sel    <= {4'd2,PHYA_A3};
                end
            end
            5:begin
                if (rdset_fin) begin
                    state_chips <= state_chips + 1'd1;
                    start_rdset <= 1'd1;
                    chip_2ns    <= set_rxcdlyena[5];
                    chip_dlysel <= set_rxcdlysel[23:20];
                    chip_sel    <= {4'd2,PHYA_B3};
                end  
            end

            6:begin
                if (rdset_fin) begin
                    state_chips <= state_chips + 1'd1;
                    start_rdset <= 1'd1;
                    chip_2ns    <= set_rxcdlyena[6];
                    chip_dlysel <= set_rxcdlysel[27:24];
                    chip_sel    <= {4'd3,PHYA_C1};
                end
            end
            7:begin
                if (rdset_fin) begin
                    state_chips <= state_chips + 1'd1;
                    start_rdset <= 1'd1;
                    chip_2ns    <= set_rxcdlyena[7];
                    chip_dlysel <= set_rxcdlysel[31:28];
                    chip_sel    <= {4'd3,PHYA_C2};
                end
            end

            8:begin
                if (rdset_fin) begin
                    state_chips <= state_chips + 1'd1;
                    start_rdset <= 1'd1;
                    chip_2ns    <= set_rxcdlyena[8];
                    chip_dlysel <= set_rxcdlysel[35:32];
                    chip_sel    <= {4'd4,PHYA_D};
                end
            end
            9:begin
                if (rdset_fin) begin
                    state_chips <= 'd0;
                    start_rdset <= 1'd0;
                end
            end
            default: state_chips <= 'd0;
        endcase
    end
end
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state_rdset <= 'd0;
        psel        <= 'd0;
        pwrite      <= 'd0;
        paddr       <= 'd0;
        pwdata      <= 'd0;
        buf_a       <= 'd0;
    end else begin
        case (state_rdset)
            0:begin // wr 1e a001
                if (pready) begin // plus
                    psel        <= 1'd0;
                end else if(start_rdset)begin
                    state_rdset <= 3'd1;
                    psel        <= 1'd1;
                    pwrite      <= 1'd1;
                    paddr       <= {chip_sel,1'd0,5'h1E,1'd0};
                    pwdata      <= 16'hA001;
                end
            end 
            1:begin // A = rd 1f
                if (pready) begin
                    state_rdset <= 3'd2;
                    psel        <= 1'd1;
                    pwrite      <= 1'd0;
                    paddr       <= {chip_sel,1'd0,5'h1F,1'd0};
                end
            end
            2:begin //wr 1e a001
                if (pready) begin
                    state_rdset <= 3'd3;
                    buf_a       <= prdata;
                    psel        <= 1'd1;
                    pwrite      <= 1'd1;
                    paddr       <= {chip_sel,1'd0,5'h1E,1'd0};
                    pwdata      <= 16'hA001;
                end
            end 
            3:begin // wr 1f B
                if (pready) begin
                    state_rdset <= 3'd4;
                    psel        <= 1'd1;
                    pwrite      <= 1'd1;
                    paddr       <= {chip_sel,1'd0,5'h1F,1'd0};
                    pwdata      <= {buf_a[15:9],chip_2ns,buf_a[7:0]};
                end
            end


            4:begin // wr 1e a003
                if (start_rdset) begin
                    state_rdset <= 3'd5;
                    psel        <= 1'd1;
                    pwrite      <= 1'd1;
                    paddr       <= {chip_sel,1'd0,5'h1E,1'd0};
                    pwdata      <= 16'hA003;
                end
            end 
            5:begin // A = rd 1f
                if (pready) begin
                    state_rdset <= 3'd6;
                    psel        <= 1'd1;
                    pwrite      <= 1'd0;
                    paddr       <= {chip_sel,1'd0,5'h1F,1'd0};
                end
            end
            6:begin //wr 1e a003
                if (pready) begin
                    state_rdset <= 3'd7;
                    buf_a       <= prdata;
                    psel        <= 1'd1;
                    pwrite      <= 1'd1;
                    paddr       <= {chip_sel,1'd0,5'h1E,1'd0};
                    pwdata      <= 16'hA003;
                end
            end 
            7:begin // wr 1f B
                if (pready) begin
                    state_rdset <= 3'd0;
                    psel        <= 1'd1;
                    pwrite      <= 1'd1;
                    paddr       <= {chip_sel,1'd0,5'h1F,1'd0};
                    pwdata      <= {buf_a[15:14],chip_dlysel,buf_a[9:0]};
                end
            end
            default: ;
        endcase
    end
end
mdio_if_apb # (
  .DIV(DIV)
)
mdio_if_apb_inst (
  .clk(clk),
  .rst(rst),
  .mdc(mdc),
  .mdo(mdo),
  .mdi(mdi),
  .mdt(mdt),

  .paddr(paddr),// | 4 bus select | 5 phyaddr | 1 dummy | 5 regaddr | 1 dummy |
  .pwrite(pwrite),
  .psel(psel),
  .penable(1'd0),
  .pwdata(pwdata),
  .prdata(prdata),
  .pready(pready)
);
endmodule