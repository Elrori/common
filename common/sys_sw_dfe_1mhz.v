/*
 * 40 MSPS, 12-bit ADC -> complex I/Q, 1.25 MSPS per channel.
 *
 * The central +/-500 kHz is the specified 1 MHz monitoring passband.
 * The +/-500..625 kHz guard band permits anti-alias FIR filtering.
 *
 * New optional top; sys_sw_dfe.v (1.0 MSPS) is unchanged.
 */
module sys_sw_dfe_1mhz #(
    parameter integer CIC_BITS = 20,      // 18 reduces some LUT/FF; both use 1 DSP/FIR lane on XC7
    parameter integer NCO_BITS = 12,      // 12 baseline, optional 14/16-bit NCO
    parameter integer MIX_BITS = 16,      // 16 baseline, optional 18/20-bit rounded product
    parameter integer ADC_OFFSET_BINARY = 0,
    parameter COE_FILE = "common/fir_cic16_comp47_q15.hex",
    parameter NCO_SIN_FILE = "dsp_nco_rom_sin45.txt",
    parameter NCO_COS_FILE = "dsp_nco_rom_cos45.txt",
    parameter integer NCO_DITHER = 1
) (
    input  wire        clk_adc,
    input  wire        rst_n,
    input  wire [11:0] adc_dat,
    input  wire [31:0] phi_inc,
    output wire [31:0] sin_fir,
    output wire [31:0] cos_fir,
    output wire        sin_fir_vld,
    output wire        cos_fir_vld
);
localparam integer CIC_ACC_BITS = MIX_BITS + 5*$clog2(16*2); // 41/43/45
wire [11:0] adc_signed = ADC_OFFSET_BINARY ?
                         {~adc_dat[11],adc_dat[10:0]} : adc_dat;
wire [NCO_BITS-1:0] sin_nco, cos_nco;
wire [MIX_BITS-1:0] sin_mul, cos_mul;
wire [CIC_BITS-1:0] sin_cic, cos_cic;
wire sin_cic_val, cos_cic_val;

initial begin
`ifndef SYNTHESIS
    if (CIC_BITS != 18 && CIC_BITS != 20)
        $fatal(1, "CIC_BITS must be 18 or 20");
    if (NCO_BITS != 12 && NCO_BITS != 14 && NCO_BITS != 16)
        $fatal(1, "NCO_BITS must be 12, 14 or 16");
    if (MIX_BITS < 16 || MIX_BITS > 20 || MIX_BITS > 12+NCO_BITS)
        $fatal(1, "MIX_BITS must be 16..20 and not exceed product bits");
`endif
end

dsp_nco #(
    .PHI_WIDTH(32), .ADDR_WIDTH(15), .DATA_WIDTH(NCO_BITS),
    .DITHER_MAX(8), .REG_OUT(1), .METHOD("SMALL_ROM"),
    .FILE_SIN(NCO_SIN_FILE),
    .FILE_COS(NCO_COS_FILE)
) nco (
    .clk(clk_adc), .rst_n(rst_n), .en(1'b1),
    .phi_inc(phi_inc), .dither_en(NCO_DITHER != 0),
    .sin_o(sin_nco), .cos_o(cos_nco)
);

dsp_mul2 #(.I_W(12), .ADC_W(12), .NCO_W(NCO_BITS), .O_W(MIX_BITS)) mixer (
    .clk(clk_adc), .rst_n(rst_n), .din(adc_signed),
    .ain(sin_nco), .bin(cos_nco),
    .aout(sin_mul), .bout(cos_mul)
);

dsp_cic_dec #(
    .R(16), .M(2), .N(5),
    .BIN(MIX_BITS), .BOUT(CIC_ACC_BITS), .COUT(CIC_BITS),
    .CUT_METHOD("ROUND")
) cic_sin (
    .clk(clk_adc), .rst_n(rst_n), .din(sin_mul),
    .dout(), .dout_cut(sin_cic), .dout_vld(sin_cic_val)
);

dsp_cic_dec #(
    .R(16), .M(2), .N(5),
    .BIN(MIX_BITS), .BOUT(CIC_ACC_BITS), .COUT(CIC_BITS),
    .CUT_METHOD("ROUND")
) cic_cos (
    .clk(clk_adc), .rst_n(rst_n), .din(cos_mul),
    .dout(), .dout_cut(cos_cic), .dout_vld(cos_cic_val)
);

dsp_fir_dec_sym #(
    .W_DIN(CIC_BITS), .W_COE(16), .W_DOUT(32),
    .N_TAPS(47), .CLOCKS_PER_INPUT(16), .COE_FILE(COE_FILE)
) fir_sin (
    .clk(clk_adc), .rst_n(rst_n), .din(sin_cic),
    .din_val(sin_cic_val), .dout(sin_fir),
    .dout_val(sin_fir_vld)
);

dsp_fir_dec_sym #(
    .W_DIN(CIC_BITS), .W_COE(16), .W_DOUT(32),
    .N_TAPS(47), .CLOCKS_PER_INPUT(16), .COE_FILE(COE_FILE)
) fir_cos (
    .clk(clk_adc), .rst_n(rst_n), .din(cos_cic),
    .din_val(cos_cic_val), .dout(cos_fir),
    .dout_val(cos_fir_vld)
);
endmodule
