module axi_regmap #(
    parameter AXI_REGMAP_UID            = 32'h20230524,
    parameter AXI_REGMAP_PADDING_DATA   = 32'hDFECDFEC,
    parameter AXI_ADDRESS_WIDTH         = 10
)
(
    input   wire                          s_axi_aclk        ,
    input   wire                          s_axi_aresetn     ,
    input   wire                          s_axi_awvalid     ,
    input   wire  [AXI_ADDRESS_WIDTH-1 :0]s_axi_awaddr      ,
    output  wire                          s_axi_awready     ,
    input   wire  [2 :0]                  s_axi_awprot      ,
    input   wire                          s_axi_wvalid      ,
    input   wire  [31:0]                  s_axi_wdata       ,
    input   wire  [3 :0]                  s_axi_wstrb       ,
    output  wire                          s_axi_wready      ,
    output  wire                          s_axi_bvalid      ,
    output  wire  [1 :0]                  s_axi_bresp       ,
    input   wire                          s_axi_bready      ,
    input   wire                          s_axi_arvalid     ,
    input   wire  [AXI_ADDRESS_WIDTH-1 :0]s_axi_araddr      ,
    output  wire                          s_axi_arready     ,
    input   wire  [2 :0]                  s_axi_arprot      ,
    output  wire                          s_axi_rvalid      ,
    input   wire                          s_axi_rready      ,
    output  wire  [1 :0]                  s_axi_rresp       ,
    output  wire  [31:0]                  s_axi_rdata       ,

    output  reg   [31:0]                  rego_fcw          ,
    output  reg   [31:0]                  rego_8370         ,
    output  wire                          rego_8370_tri     ,
    output  reg   [31:0]                  rego_msic         ,
    input   wire  [31:0]                  regi_msic         ,

    input   wire                          ctrl_fifo_full    ,
    input   wire                          ctrl_fifo_empty   ,
    input   wire  [63:0]                  ctrl_fifo_rdat    ,
    output  wire                          ctrl_fifo_rena    ,
    input   wire  [31:0]                  ctrl_fifo_dcnt    
);
reg             up_wack;
reg   [31:0]    up_rdata;
reg             up_rack;
reg   [31:0]    ctrl_fifo_rdat_hi;
wire            up_wreq;
wire  [(AXI_ADDRESS_WIDTH-3):0]  up_waddr;
wire  [31:0]    up_wdata;
wire            up_rreq;
wire  [(AXI_ADDRESS_WIDTH-3):0]  up_raddr;

assign ctrl_fifo_rena = (up_rreq & (up_raddr==5));
assign rego_8370_tri  = (up_wreq & (up_waddr==2));

always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
    if (!s_axi_aresetn) begin
        rego_fcw  <= 32'd0;
        rego_8370 <= 32'd0;
        rego_msic <= 32'd0;
        up_wack   <=  1'b0;
        up_rack   <=  1'd0;
    end else begin
        up_wack <= up_wreq;
        up_rack <= up_rreq;
        if (up_wreq == 1'b1) begin
            case (up_waddr)
            0:;
            1: rego_fcw  <= up_wdata;
            2: rego_8370 <= up_wdata;
            3:;
            4:;
            5:;
            6:;
            7:;
            8: rego_msic <= up_wdata;
            9:;
            default:;
            endcase
        end
    end
end

always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
    if (!s_axi_aresetn)begin
        up_rdata                <= 32'd0;
        ctrl_fifo_rdat_hi       <= 32'd0;
    end else if (up_rreq == 1'b1) begin
        case (up_raddr)
        0: up_rdata             <= AXI_REGMAP_UID;
        1: up_rdata             <= rego_fcw;
        2: up_rdata             <= rego_8370;
        3: up_rdata             <= {31'd0,ctrl_fifo_full };
        4: up_rdata             <= {31'd0,ctrl_fifo_empty};
        5: begin
            up_rdata            <= ctrl_fifo_rdat[31 : 0];
            ctrl_fifo_rdat_hi   <= ctrl_fifo_rdat[63 :32];
        end
        6: up_rdata             <= ctrl_fifo_rdat_hi;
        7: up_rdata             <= ctrl_fifo_dcnt;
        8: up_rdata             <= rego_msic;
        9: up_rdata             <= regi_msic;
        default: up_rdata       <= AXI_REGMAP_PADDING_DATA;
        endcase
    end
end
up_axi #(
    .AXI_ADDRESS_WIDTH ( AXI_ADDRESS_WIDTH ))
u_up_axi (
    .up_rstn                 ( s_axi_aresetn                            ),
    .up_clk                  ( s_axi_aclk                               ),

    .up_axi_awvalid          ( s_axi_awvalid                            ), // axi-4 lite
    .up_axi_awaddr           ( s_axi_awaddr   [(AXI_ADDRESS_WIDTH-1):0] ),
    .up_axi_wvalid           ( s_axi_wvalid                             ),
    .up_axi_wdata            ( s_axi_wdata    [31:0]                    ),
    .up_axi_wstrb            ( s_axi_wstrb    [ 3:0]                    ),
    .up_axi_bready           ( s_axi_bready                             ),
    .up_axi_arvalid          ( s_axi_arvalid                            ),
    .up_axi_araddr           ( s_axi_araddr   [(AXI_ADDRESS_WIDTH-1):0] ),
    .up_axi_rready           ( s_axi_rready                             ),
    .up_axi_awready          ( s_axi_awready                            ),
    .up_axi_wready           ( s_axi_wready                             ),
    .up_axi_bvalid           ( s_axi_bvalid                             ),
    .up_axi_bresp            ( s_axi_bresp    [ 1:0]                    ),
    .up_axi_arready          ( s_axi_arready                            ),
    .up_axi_rvalid           ( s_axi_rvalid                             ),
    .up_axi_rresp            ( s_axi_rresp    [ 1:0]                    ),
    .up_axi_rdata            ( s_axi_rdata    [31:0]                    ),

    .up_wreq                 ( up_wreq                                   ),
    .up_waddr                ( up_waddr        [(AXI_ADDRESS_WIDTH-3):0] ),
    .up_wdata                ( up_wdata        [31:0]                    ),
    .up_rreq                 ( up_rreq                                   ),
    .up_raddr                ( up_raddr        [(AXI_ADDRESS_WIDTH-3):0] ),
    .up_wack                 ( up_wack                                   ),
    .up_rdata                ( up_rdata        [31:0]                    ),
    .up_rack                 ( up_rack                                   )
);
endmodule
