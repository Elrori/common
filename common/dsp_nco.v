/*
*  Name         :dsp_nco.v
*  Description  :
*  Origin       :230507
*  EE           :hel
*/
module dsp_nco #(
    parameter PHI_WIDTH  = 32,
    parameter ADDR_WIDTH = 12,
    parameter DATA_WIDTH = 12,
    parameter DITHER_MAX = 1 , // 0:error, 1:not use, 2:0~1, 3:0~2, 4:0~3 ...256:0~255
    parameter REG_OUT    = 0 ,
    parameter FILE_SIN   = "dsp_nco_rom_sin45.txt",
    parameter FILE_COS   = "dsp_nco_rom_cos45.txt",
    parameter METHOD     = "SMALL_ROM"  // "LARGE_ROM"   : the ROM stores the full 360 degrees of both the sine and cosine
                                        // "MEDIUM_ROM"  : the ROM stores 90 degrees of the sine and cosine waveforms
                                        // "SMALL_ROM"   : the ROM only stores 45 degrees of the sine and cosine waveforms
)(
    input   wire                    clk         ,
    input   wire                    rst_n       ,

    input   wire                    en          ,
    input   wire                    dither_en   ,
    input   wire [PHI_WIDTH-1  :0]  phi_inc     , // Frequency Control Word

    output  wire [DATA_WIDTH-1 :0]  sin_o       ,
    output  wire [DATA_WIDTH-1 :0]  cos_o    
);
reg    [PHI_WIDTH-1 :0] phi_acc;
wire   [ADDR_WIDTH-1:0] addr_tmp;
wire   [ADDR_WIDTH-1:0] addr;
wire   [7           :0] dither;
wire   [7           :0] dither_tmp;
localparam  DITHER_WIDTH = $clog2(DITHER_MAX);
generate
    genvar i;
    for (i = 0;i<DITHER_WIDTH;i=i+1 ) begin:msq
        reg [1:32] lfsr;// 32 22 2 1 
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                lfsr[1:32] <= i+32'h6B91C206;
            end else if(en && dither_en)begin
                lfsr[1:32] <= {lfsr[32]^lfsr[22]^lfsr[2]^lfsr[1],lfsr[1:31]};
            end 
        end           
    end
endgenerate
assign dither[7:0]                = DITHER_WIDTH==0 ? 8'd0 :
                                    DITHER_WIDTH==1 ? {7'd0,msq[0].lfsr[32]} :
                                    DITHER_WIDTH==2 ? {6'd0,msq[1].lfsr[32],msq[0].lfsr[32]} :
                                    DITHER_WIDTH==3 ? {5'd0,msq[2].lfsr[32],msq[1].lfsr[32],msq[0].lfsr[32]} :
                                    DITHER_WIDTH==4 ? {4'd0,msq[3].lfsr[32],msq[2].lfsr[32],msq[1].lfsr[32],msq[0].lfsr[32]} :
                                    DITHER_WIDTH==5 ? {3'd0,msq[4].lfsr[32],msq[3].lfsr[32],msq[2].lfsr[32],msq[1].lfsr[32],msq[0].lfsr[32]} :
                                    DITHER_WIDTH==6 ? {2'd0,msq[5].lfsr[32],msq[4].lfsr[32],msq[3].lfsr[32],msq[2].lfsr[32],msq[1].lfsr[32],msq[0].lfsr[32]} :
                                    DITHER_WIDTH==7 ? {1'd0,msq[6].lfsr[32],msq[5].lfsr[32],msq[4].lfsr[32],msq[3].lfsr[32],msq[2].lfsr[32],msq[1].lfsr[32],msq[0].lfsr[32]} :
                                    DITHER_WIDTH==8 ? {msq[7].lfsr[32],msq[6].lfsr[32],msq[5].lfsr[32],msq[4].lfsr[32],msq[3].lfsr[32],msq[2].lfsr[32],msq[1].lfsr[32],msq[0].lfsr[32]} :
                                    8'd0;
assign dither_tmp[7           :0] = dither_en ? dither[7:0]%DITHER_MAX : 8'd0;
assign addr_tmp  [ADDR_WIDTH-1:0] = phi_acc [PHI_WIDTH-1 :PHI_WIDTH-ADDR_WIDTH]; // Phase Truncation
assign addr      [ADDR_WIDTH-1:0] = addr_tmp[ADDR_WIDTH-1:0] + dither_tmp[7:0];
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        phi_acc <= {PHI_WIDTH{1'd0}};
    end else if(en)begin
        phi_acc <= phi_acc + phi_inc;
    end else begin
        phi_acc <= {PHI_WIDTH{1'd0}};
    end
end
dsp_nco_rom #(
    .ADDR_WIDTH ( ADDR_WIDTH ),
    .DATA_WIDTH ( DATA_WIDTH ),
    .REG_OUT    ( REG_OUT    ),
    .FILE_SIN   ( FILE_SIN   ),
    .FILE_COS   ( FILE_COS   ),
    .METHOD     ( METHOD     ))
u_dsp_nco_rom (
    .clk        ( clk                     ),
    .rst_n      ( rst_n                   ),
    .addr       ( addr   [ADDR_WIDTH-1:0] ),
    .sin_o      ( sin_o  [DATA_WIDTH-1:0] ),
    .cos_o      ( cos_o  [DATA_WIDTH-1:0] )
);
endmodule
