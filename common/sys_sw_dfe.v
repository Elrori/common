/*
*  Name         :sys_sw_dfe.v
*  Description  :
*  Origin       :230610
*  EE           :hel
*/
module sys_sw_dfe (
    input       wire        clk_adc     ,
    input       wire        rst_n       ,

    input       wire [11:0] adc_dat     ,
    input       wire [31:0] phi_inc     ,

    output      wire [31:0] sin_fir     ,
    output      wire [31:0] cos_fir     ,
    output      wire        sin_fir_vld ,
    output      wire        cos_fir_vld
);
wire [11:0]sin;
wire [11:0]cos;
wire [15:0]sin_mul;
wire [15:0]cos_mul;
wire [15:0]sin_cic;
wire [15:0]cos_cic;
wire       sin_cic_vld;
wire       cos_cic_vld;
dsp_nco #(
    .PHI_WIDTH  ( 32                        ),
    .ADDR_WIDTH ( 15                        ),
    .DATA_WIDTH ( 12                        ),
    .DITHER_MAX ( 8                         ),
    .REG_OUT    ( 1                         ),
    .FILE_SIN   ( "dsp_nco_rom_sin45.txt"   ),
    .FILE_COS   ( "dsp_nco_rom_cos45.txt"   ),
    .METHOD     ( "SMALL_ROM"               ))
u_dsp_nco (
    .clk        ( clk_adc                   ),
    .rst_n      ( rst_n                     ),
    .en         ( 1'd1                      ),
    .phi_inc    ( phi_inc[31:0]             ),
    .dither_en  ( 1'd1                      ),
    .sin_o      ( sin    [11:0]             ),
    .cos_o      ( cos    [11:0]             )
);
dsp_mul2 #(
    .I_W ( 12 ),
    .O_W ( 16 ))
u_dsp_mul2
(
   .clk         ( clk_adc           ),        
   .rst_n       ( rst_n             ),
   .din         ( adc_dat[11:0]     ),
   .ain         ( sin    [11:0]     ),
   .bin         ( cos    [11:0]     ),
   .aout        ( sin_mul[15:0]     ), 
   .bout        ( cos_mul[15:0]     )
);

dsp_cic_dec #(
    .R          ( 20    ),
    .M          ( 2     ),
    .N          ( 5     ),
    .BIN        ( 16    ),
    .COUT       ( 16    ),
    .BOUT       ( 43    ),
    .CUT_METHOD ("ROUND"))
u_cic_dec_sin(
    .clk        ( clk_adc       ),   
    .rst_n      ( rst_n         ),
    .din        ( sin_mul[15:0] ),
    .dout       (               ),
    .dout_cut   ( sin_cic[15:0] ),
    .dout_vld   ( sin_cic_vld   )    
);
dsp_cic_dec #(
    .R          ( 20    ),
    .M          ( 2     ),
    .N          ( 5     ),
    .BIN        ( 16    ),
    .COUT       ( 16    ),
    .BOUT       ( 43    ),
    .CUT_METHOD ("ROUND"))
u_cic_dec_cos(
    .clk        ( clk_adc       ),   
    .rst_n      ( rst_n         ),
    .din        ( cos_mul[15:0] ),
    .dout       (               ),
    .dout_cut   ( cos_cic[15:0] ),
    .dout_vld   ( cos_cic_vld   )    
);
dsp_fir_dec #(
    .R                ( 2                   ),
    .COE_FILE         ( "fir_comp_coe.txt"  ),
    .CLOCK_PER_SAMPLE ( 20                  ))
u_fir_dec_sin (
    .clk        ( clk_adc          ),
    .rst_n      ( rst_n            ),
    .din        ( sin_cic   [15:0] ),
    .din_val    ( sin_cic_vld      ),
    .dout       ( sin_fir   [31:0] ),
    .dout_val   ( sin_fir_vld      )
);
dsp_fir_dec #(
    .R                ( 2                   ),
    .COE_FILE         ( "fir_comp_coe.txt"  ),
    .CLOCK_PER_SAMPLE ( 20                  ))
u_fir_dec_cos (
    .clk        ( clk_adc          ),
    .rst_n      ( rst_n            ),
    .din        ( cos_cic   [15:0] ),
    .din_val    ( cos_cic_vld      ),
    .dout       ( cos_fir   [31:0] ),
    .dout_val   ( cos_fir_vld      )
);
endmodule
