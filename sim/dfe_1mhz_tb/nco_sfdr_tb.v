`timescale 1ns/1ps
// Side-by-side RTL NCO output, with and without phase dither, at 40 MSPS.
// Column pairs: 12off/12on/14off/14on/16off/16on, each sin/cos.
module nco_sfdr_tb;
    reg clk=0, rst_n=0, en=0;
    reg [31:0] fcw=32'd858980352;
    integer fp, i=0, samples=65552;
    wire signed [11:0] s12off,c12off,s12on,c12on;
    wire signed [13:0] s14off,c14off,s14on,c14on;
    wire signed [15:0] s16off,c16off,s16on,c16on;
    always #12.5 clk=~clk;
    initial begin
        if($value$plusargs("FCW=%d",fcw)) begin end
        if($value$plusargs("SAMPLES=%d",samples)) begin end
        fp=$fopen("nco_sfdr_samples.txt","w");
        #75 rst_n=1;
        #25 en=1;
    end
    dsp_nco #(.PHI_WIDTH(32),.ADDR_WIDTH(15),.DATA_WIDTH(12),
              .DITHER_MAX(8),.REG_OUT(1),.METHOD("SMALL_ROM"),
              .FILE_SIN("dsp_nco_rom_sin45.txt"),
              .FILE_COS("dsp_nco_rom_cos45.txt")) no12 (
        .clk(clk),.rst_n(rst_n),.en(en),.phi_inc(fcw),.dither_en(1'b0),
        .sin_o(s12off),.cos_o(c12off));
    dsp_nco #(.PHI_WIDTH(32),.ADDR_WIDTH(15),.DATA_WIDTH(12),
              .DITHER_MAX(8),.REG_OUT(1),.METHOD("SMALL_ROM"),
              .FILE_SIN("dsp_nco_rom_sin45.txt"),
              .FILE_COS("dsp_nco_rom_cos45.txt")) yes12 (
        .clk(clk),.rst_n(rst_n),.en(en),.phi_inc(fcw),.dither_en(1'b1),
        .sin_o(s12on),.cos_o(c12on));
    dsp_nco #(.PHI_WIDTH(32),.ADDR_WIDTH(15),.DATA_WIDTH(14),
              .DITHER_MAX(8),.REG_OUT(1),.METHOD("SMALL_ROM"),
              .FILE_SIN("common/nco_q13_sin45.hex"),
              .FILE_COS("common/nco_q13_cos45.hex")) no14 (
        .clk(clk),.rst_n(rst_n),.en(en),.phi_inc(fcw),.dither_en(1'b0),
        .sin_o(s14off),.cos_o(c14off));
    dsp_nco #(.PHI_WIDTH(32),.ADDR_WIDTH(15),.DATA_WIDTH(14),
              .DITHER_MAX(8),.REG_OUT(1),.METHOD("SMALL_ROM"),
              .FILE_SIN("common/nco_q13_sin45.hex"),
              .FILE_COS("common/nco_q13_cos45.hex")) yes14 (
        .clk(clk),.rst_n(rst_n),.en(en),.phi_inc(fcw),.dither_en(1'b1),
        .sin_o(s14on),.cos_o(c14on));
    dsp_nco #(.PHI_WIDTH(32),.ADDR_WIDTH(15),.DATA_WIDTH(16),
              .DITHER_MAX(8),.REG_OUT(1),.METHOD("SMALL_ROM"),
              .FILE_SIN("common/nco_q15_sin45.hex"),
              .FILE_COS("common/nco_q15_cos45.hex")) no16 (
        .clk(clk),.rst_n(rst_n),.en(en),.phi_inc(fcw),.dither_en(1'b0),
        .sin_o(s16off),.cos_o(c16off));
    dsp_nco #(.PHI_WIDTH(32),.ADDR_WIDTH(15),.DATA_WIDTH(16),
              .DITHER_MAX(8),.REG_OUT(1),.METHOD("SMALL_ROM"),
              .FILE_SIN("common/nco_q15_sin45.hex"),
              .FILE_COS("common/nco_q15_cos45.hex")) yes16 (
        .clk(clk),.rst_n(rst_n),.en(en),.phi_inc(fcw),.dither_en(1'b1),
        .sin_o(s16on),.cos_o(c16on));
    always @(negedge clk) if(en) begin
        $fwrite(fp,"%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d\n",
            $signed(s12off),$signed(c12off),$signed(s12on),$signed(c12on),
            $signed(s14off),$signed(c14off),$signed(s14on),$signed(c14on),
            $signed(s16off),$signed(c16off),$signed(s16on),$signed(c16on));
        i=i+1;
        if(i>=samples) begin $fclose(fp); $finish; end
    end
endmodule
