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
    parameter USE_DITHER = 1 , // 
    parameter REG_OUT    = 0 ,
    parameter FILE_SIN   = "dsp_nco_rom_sin45.txt",
    parameter FILE_COS   = "dsp_nco_rom_cos45.txt",
    parameter METHOD     = "SMALL_ROM"  // "LARGE_ROM"   : the ROM stores the full 360 degrees of both the sine and cosine
                                        // "MEDIUM_ROM"  : the ROM stores 90 degrees of the sine and cosine waveforms
                                        // "SMALL_ROM"   : the ROM only stores 45 degrees of the sine and cosine waveforms
)(
    input   wire                    clk     ,
    input   wire                    rst_n   ,

    input   wire                    en      ,
    input   wire [PHI_WIDTH-1  :0]  phi_inc , // Frequency Control Word


    output  wire [DATA_WIDTH-1 :0] sin_o    ,
    output  wire [DATA_WIDTH-1 :0] cos_o    
);
reg    [PHI_WIDTH-1 :0] phi_acc;
wire   [ADDR_WIDTH-1:0] addr;
assign addr[ADDR_WIDTH-1:0] = phi_acc[PHI_WIDTH-1:PHI_WIDTH-ADDR_WIDTH]; // Phase Truncation
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
    .clk                     ( clk                     ),
    .rst_n                   ( rst_n                   ),
    .addr                    ( addr   [ADDR_WIDTH-1:0] ),

    .sin_o                   ( sin_o  [DATA_WIDTH-1:0] ),
    .cos_o                   ( cos_o  [DATA_WIDTH-1:0] )
);
endmodule
