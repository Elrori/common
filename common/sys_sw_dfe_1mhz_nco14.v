/*
 * Optional higher-purity NCO variants; keeps the 12-bit ADC and 1 MHz
 * CIC20/FIR47 backend exactly as in sys_sw_dfe_1mhz.
 * Original sys_sw_dfe_1mhz remains a 12x12 -> 16 baseline by default.
 */
module sys_sw_dfe_1mhz_nco14 (
    input wire clk_adc, rst_n,
    input wire [11:0] adc_dat,
    input wire [31:0] phi_inc,
    output wire [31:0] sin_fir, cos_fir,
    output wire sin_fir_vld, cos_fir_vld
);
sys_sw_dfe_1mhz #(
    .CIC_BITS(20), .NCO_BITS(14), .MIX_BITS(18),
    .NCO_SIN_FILE("common/nco_q13_sin45.hex"),
    .NCO_COS_FILE("common/nco_q13_cos45.hex")
) core (
    .clk_adc(clk_adc), .rst_n(rst_n), .adc_dat(adc_dat), .phi_inc(phi_inc),
    .sin_fir(sin_fir), .cos_fir(cos_fir),
    .sin_fir_vld(sin_fir_vld), .cos_fir_vld(cos_fir_vld)
);
endmodule

// 62.5 MSPS variant.  62.5 / 25 / 2 = 1.25 MSPS, preserving the host and
// Ethernet sample rate while moving ADC Nyquist above the 30 MHz input LPF.
module sys_sw_dfe_1mhz_nco14_62m5 (
    input wire clk_adc, rst_n,
    input wire [11:0] adc_dat,
    input wire [31:0] phi_inc,
    output wire [31:0] sin_fir, cos_fir,
    output wire sin_fir_vld, cos_fir_vld
);
sys_sw_dfe_1mhz #(
    .CIC_BITS(20), .NCO_BITS(14), .MIX_BITS(18),
    .CIC_RATE(25), .CIC_PIPELINED(1),
    .COE_FILE("common/fir_cic25_comp47_q15.hex"),
    .NCO_SIN_FILE("common/nco_q13_sin45.hex"),
    .NCO_COS_FILE("common/nco_q13_cos45.hex")
) core (
    .clk_adc(clk_adc), .rst_n(rst_n), .adc_dat(adc_dat), .phi_inc(phi_inc),
    .sin_fir(sin_fir), .cos_fir(cos_fir),
    .sin_fir_vld(sin_fir_vld), .cos_fir_vld(cos_fir_vld)
);
endmodule

module sys_sw_dfe_1mhz_nco16 (
    input wire clk_adc, rst_n,
    input wire [11:0] adc_dat,
    input wire [31:0] phi_inc,
    output wire [31:0] sin_fir, cos_fir,
    output wire sin_fir_vld, cos_fir_vld
);
sys_sw_dfe_1mhz #(
    .CIC_BITS(20), .NCO_BITS(16), .MIX_BITS(20),
    .NCO_SIN_FILE("common/nco_q15_sin45.hex"),
    .NCO_COS_FILE("common/nco_q15_cos45.hex")
) core (
    .clk_adc(clk_adc), .rst_n(rst_n), .adc_dat(adc_dat), .phi_inc(phi_inc),
    .sin_fir(sin_fir), .cos_fir(cos_fir),
    .sin_fir_vld(sin_fir_vld), .cos_fir_vld(cos_fir_vld)
);
endmodule

module sys_sw_dfe_1mhz_mix18 (
    input wire clk_adc, rst_n,
    input wire [11:0] adc_dat,
    input wire [31:0] phi_inc,
    output wire [31:0] sin_fir, cos_fir,
    output wire sin_fir_vld, cos_fir_vld
);
sys_sw_dfe_1mhz #(.CIC_BITS(20), .NCO_BITS(12), .MIX_BITS(18)) core (
    .clk_adc(clk_adc), .rst_n(rst_n), .adc_dat(adc_dat), .phi_inc(phi_inc),
    .sin_fir(sin_fir), .cos_fir(cos_fir),
    .sin_fir_vld(sin_fir_vld), .cos_fir_vld(cos_fir_vld)
);
endmodule
