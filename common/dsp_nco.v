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
    parameter DITHER_MAX = 1 , // 0:error, 1:not use, 2:0~1, 3:0~2, 4:0~3 ...8:0~7
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
reg    [PHI_WIDTH -1: 0] phi_acc;
wire   [PHI_WIDTH -1: 0] phi_acc_tmp;
wire   [ADDR_WIDTH-1: 0] addr_tmp;
wire   [ADDR_WIDTH-1: 0] addr;
wire   [2           : 0] dither;
reg    [1           :32] lfsr0;// 32 22 2 1 
reg    [1           :32] lfsr1;// 32 22 2 1
reg    [1           :32] lfsr2;// 32 22 2 1
assign                   dither = {lfsr2,lfsr1,lfsr0};
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        lfsr0[1:32] <= 32'hABCDE110;
        lfsr1[1:32] <= 32'h20230516;
        lfsr2[1:32] <= 32'h20170723;
    end else if(en && dither_en)begin
        lfsr0[1:32] <= {lfsr0[32]^lfsr0[22]^lfsr0[2]^lfsr0[1],lfsr0[1:31]};
        lfsr1[1:32] <= {lfsr1[32]^lfsr1[22]^lfsr1[2]^lfsr1[1],lfsr1[1:31]};
        lfsr2[1:32] <= {lfsr2[32]^lfsr2[22]^lfsr2[2]^lfsr2[1],lfsr2[1:31]};
    end 
end       
assign phi_acc_tmp[PHI_WIDTH -1: 0] = phi_acc    [PHI_WIDTH-1 :0] + ((dither[2:0]%DITHER_MAX)<<(PHI_WIDTH-ADDR_WIDTH-3));
assign addr       [ADDR_WIDTH-1: 0] = phi_acc_tmp[PHI_WIDTH-1 :PHI_WIDTH-ADDR_WIDTH]; // Phase Truncation
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
