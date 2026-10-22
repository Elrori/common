`timescale 1ns/1ps
// End-to-end top-level test: identical signed 12-bit ADC samples are fed to
// the unmodified original sys_sw_dfe and the optimized sys_sw_dfe_1mhz.
// Run vvp with its working directory set to the generated ROM directory.
module dfe_adc12_tb;
    parameter integer CIC_BITS = 20;
    localparam integer NSAMPLES = 262144;
    localparam [31:0] PHI_INC = 32'd858993459; // 8 MHz / 40 MSPS

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg [11:0] adc_dat = 'd0;
    reg [11:0] adc_samples [0:NSAMPLES-1];
    integer n = 0;
    integer old_fp, new_fp;
    integer count_old = 0, count_new = 0;

    wire [31:0] old_sin, old_cos, new_sin, new_cos;
    wire old_sin_valid, old_cos_valid;
    wire new_sin_valid, new_cos_valid;

    always #12.5 clk = ~clk; // 40 MHz

    initial begin
        $readmemh("adc12.hex", adc_samples);
        old_fp = $fopen("out_adc12_old.txt", "w");
        new_fp = $fopen("out_adc12_new.txt", "w");
        #75 rst_n = 1'b1;
    end

    always @(negedge clk) if (rst_n) begin
        adc_dat <= n < NSAMPLES ? adc_samples[n] : 'd0;
        n = n+1;
        if (n >= NSAMPLES+256) begin
            $display("ADC12_COUNTS old=%0d new=%0d",count_old,count_new);
            if (count_old < 6500 || count_new < 8100)
                $fatal(1,"ADC12 chain output count below expectation");
            $fclose(old_fp);
            $fclose(new_fp);
            $finish;
        end
    end

    sys_sw_dfe legacy (
        .clk_adc(clk), .rst_n(rst_n), .adc_dat(adc_dat),
        .phi_inc(PHI_INC),
        .sin_fir(old_sin), .cos_fir(old_cos),
        .sin_fir_vld(old_sin_valid), .cos_fir_vld(old_cos_valid)
    );

    sys_sw_dfe_1mhz #(.CIC_BITS(CIC_BITS)) optimized (
        .clk_adc(clk), .rst_n(rst_n), .adc_dat(adc_dat),
        .phi_inc(PHI_INC),
        .sin_fir(new_sin), .cos_fir(new_cos),
        .sin_fir_vld(new_sin_valid), .cos_fir_vld(new_cos_valid)
    );

    always @(posedge clk) if (rst_n) begin
        if (old_sin_valid !== old_cos_valid)
            $fatal(1,"Original I/Q FIR valid mismatch");
        if (new_sin_valid !== new_cos_valid)
            $fatal(1,"New I/Q FIR valid mismatch");
        if (old_sin_valid) begin
            $fwrite(old_fp,"%0d %0d\n",$signed(old_cos),$signed(old_sin));
            count_old = count_old+1;
        end
        if (new_sin_valid) begin
            $fwrite(new_fp,"%0d %0d\n",$signed(new_cos),$signed(new_sin));
            count_new = count_new+1;
        end
    end
endmodule
