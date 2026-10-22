`timescale 1ns/1ps
// Four *actual* full DFE RTL paths, all fed identical quantized ADC12 data.
// 12/16 is the unmodified previous CIC20/FIR47 baseline. The 12/18 path
// isolates mixer rounding; 14/18 and 16/20 add NCO amplitude precision.
module dfe_nco_adc12_tb;
    localparam integer NSAMPLES = 262144;
    localparam [31:0] FCW = 32'd858993459; // 8 MHz at 40 MSPS
    reg clk = 0, rst_n = 0;
    reg [11:0] adc_dat = 0;
    reg [11:0] adc_samples [0:NSAMPLES-1];
    integer n = 0;
    integer f0, f1, f2, f3;
    integer c0=0, c1=0, c2=0, c3=0;

    wire [31:0] i0,q0,i1,q1,i2,q2,i3,q3;
    wire vi0,vq0,vi1,vq1,vi2,vq2,vi3,vq3;
    always #12.5 clk = ~clk;
    initial begin
        $readmemh("adc12.hex", adc_samples);
        f0=$fopen("out_nco_12_16.txt","w");
        f1=$fopen("out_nco_12_18.txt","w");
        f2=$fopen("out_nco_14_18.txt","w");
        f3=$fopen("out_nco_16_20.txt","w");
        #75 rst_n=1;
    end
    always @(negedge clk) if (rst_n) begin
        adc_dat <= n < NSAMPLES ? adc_samples[n] : 12'd0;
        n=n+1;
        if (n>=NSAMPLES+256) begin
            $display("NCO_ADC12_COUNTS: %0d %0d %0d %0d",c0,c1,c2,c3);
            if(c0<8100 || c1!=c0 || c2!=c0 || c3!=c0)
                $fatal(1,"NCO variant sample counts differ");
            $fclose(f0); $fclose(f1); $fclose(f2); $fclose(f3);
            $finish;
        end
    end
    sys_sw_dfe_1mhz #(.CIC_BITS(20)) base (
        .clk_adc(clk),.rst_n(rst_n),.adc_dat(adc_dat),.phi_inc(FCW),
        .sin_fir(i0),.cos_fir(q0),.sin_fir_vld(vi0),.cos_fir_vld(vq0));
    sys_sw_dfe_1mhz_mix18 mix18 (
        .clk_adc(clk),.rst_n(rst_n),.adc_dat(adc_dat),.phi_inc(FCW),
        .sin_fir(i1),.cos_fir(q1),.sin_fir_vld(vi1),.cos_fir_vld(vq1));
    sys_sw_dfe_1mhz_nco14 nco14 (
        .clk_adc(clk),.rst_n(rst_n),.adc_dat(adc_dat),.phi_inc(FCW),
        .sin_fir(i2),.cos_fir(q2),.sin_fir_vld(vi2),.cos_fir_vld(vq2));
    sys_sw_dfe_1mhz_nco16 nco16 (
        .clk_adc(clk),.rst_n(rst_n),.adc_dat(adc_dat),.phi_inc(FCW),
        .sin_fir(i3),.cos_fir(q3),.sin_fir_vld(vi3),.cos_fir_vld(vq3));
    always @(posedge clk) if(rst_n) begin
        if(vi0 !== vq0 || vi1 !== vq1 || vi2 !== vq2 || vi3 !== vq3)
            $fatal(1,"I/Q stream strobe mismatch");
        if(vi0 !== vi1 || vi0 !== vi2 || vi0 !== vi3)
            $fatal(1,"NCO path pipeline/output strobe mismatch");
        if(vi0) begin
            $fwrite(f0,"%0d %0d\n",$signed(q0),$signed(i0));c0=c0+1;
            $fwrite(f1,"%0d %0d\n",$signed(q1),$signed(i1));c1=c1+1;
            $fwrite(f2,"%0d %0d\n",$signed(q2),$signed(i2));c2=c2+1;
            $fwrite(f3,"%0d %0d\n",$signed(q3),$signed(i3));c3=c3+1;
        end
    end
endmodule
