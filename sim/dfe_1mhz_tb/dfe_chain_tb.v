`timescale 1ns/1ps
// Bit-true CIC/FIR comparison.  The unchanged 12x12 mixer is bypassed so the
// same deterministic 16-bit *post-mixer* samples reach all three pipelines.
module dfe_chain_tb;
    localparam integer NSAMPLES = 262144;
    reg clk = 0;
    reg rst_n = 0;
    reg signed [15:0] din = 0;
    reg [15:0] stimulus [0:NSAMPLES-1];
    integer n = 0;
    integer fp_old_cic, fp_18_cic, fp_20_cic;
    integer fp_old_fir, fp_18_fir, fp_20_fir;
    integer old_count = 0, fast_count = 0;

    wire [42:0] old_full;
    wire [15:0] old_cut;
    wire old_valid;
    wire signed [31:0] old_fir;
    wire old_fir_valid;

    wire [40:0] full18, full20;
    wire [17:0] cut18;
    wire [19:0] cut20;
    wire val18, val20;
    wire signed [31:0] fir18, fir20;
    wire fir18_val, fir20_val;

    always #12.5 clk = ~clk; // 40 MSPS

    initial begin
        $readmemh("sim/dfe_1mhz_tb/stimulus.hex", stimulus);
        fp_old_cic = $fopen("sim/dfe_1mhz_tb/out_old_cic.txt", "w");
        fp_18_cic  = $fopen("sim/dfe_1mhz_tb/out_18_cic.txt", "w");
        fp_20_cic  = $fopen("sim/dfe_1mhz_tb/out_20_cic.txt", "w");
        fp_old_fir = $fopen("sim/dfe_1mhz_tb/out_old_fir.txt", "w");
        fp_18_fir  = $fopen("sim/dfe_1mhz_tb/out_18_fir.txt", "w");
        fp_20_fir  = $fopen("sim/dfe_1mhz_tb/out_20_fir.txt", "w");
        #75 rst_n = 1'b1;
    end

    always @(negedge clk) if(rst_n) begin
        din <= n < NSAMPLES ? stimulus[n] : 16'sd0;
        n = n + 1;
        if (n >= NSAMPLES+256) begin
            $display("PIPELINE_COUNTS old_cic=%0d fast_cic=%0d", old_count, fast_count);
            if (old_count < 6400 || fast_count < 8100)
                $fatal(1, "Unexpected CIC output rate");
            $fclose(fp_old_cic); $fclose(fp_18_cic); $fclose(fp_20_cic);
            $fclose(fp_old_fir); $fclose(fp_18_fir); $fclose(fp_20_fir);
            $finish;
        end
    end

    dsp_cic_dec #(
        .R(20), .M(2), .N(5), .BIN(16), .BOUT(43),
        .COUT(16), .CUT_METHOD("ROUND")
    ) old_cic (
        .clk(clk), .rst_n(rst_n), .din(din), .dout(old_full),
        .dout_cut(old_cut), .dout_vld(old_valid)
    );
    dsp_fir_dec #(
        .R(2), .COE_FILE("sim/dfe_1mhz_tb/legacy_fir_comp31.hex"),
        .CLOCK_PER_SAMPLE(20)
    ) old_filter (
        .clk(clk), .rst_n(rst_n), .din(old_cut),
        .din_val(old_valid), .dout(old_fir), .dout_val(old_fir_valid)
    );

    dsp_cic_dec #(
        .R(16), .M(2), .N(5), .BIN(16), .BOUT(41),
        .COUT(18), .CUT_METHOD("ROUND")
    ) cic18 (
        .clk(clk), .rst_n(rst_n), .din(din), .dout(full18),
        .dout_cut(cut18), .dout_vld(val18)
    );
    dsp_fir_dec_sym #(.W_DIN(18)) filter18 (
        .clk(clk), .rst_n(rst_n), .din(cut18), .din_val(val18),
        .dout(fir18), .dout_val(fir18_val)
    );

    dsp_cic_dec #(
        .R(16), .M(2), .N(5), .BIN(16), .BOUT(41),
        .COUT(20), .CUT_METHOD("ROUND")
    ) cic20 (
        .clk(clk), .rst_n(rst_n), .din(din), .dout(full20),
        .dout_cut(cut20), .dout_vld(val20)
    );
    dsp_fir_dec_sym #(.W_DIN(20)) filter20 (
        .clk(clk), .rst_n(rst_n), .din(cut20), .din_val(val20),
        .dout(fir20), .dout_val(fir20_val)
    );

    always @(posedge clk) if(rst_n) begin
        if (old_valid) begin
            $fwrite(fp_old_cic, "%0d %0d\n", $signed(old_full), $signed(old_cut));
            old_count = old_count + 1;
        end
        if (val18) begin
            if (val18 !== val20)
                $fatal(1, "CIC18/CIC20 clock enable mismatch");
            if ($signed(full18) !== $signed(full20))
                $fatal(1, "CIC18/CIC20 full precision output mismatch");
            $fwrite(fp_18_cic, "%0d %0d\n", $signed(full18), $signed(cut18));
            $fwrite(fp_20_cic, "%0d %0d\n", $signed(full20), $signed(cut20));
            fast_count = fast_count + 1;
        end
        if (old_fir_valid) $fwrite(fp_old_fir, "%0d\n", $signed(old_fir));
        if (fir18_val) $fwrite(fp_18_fir, "%0d\n", $signed(fir18));
        if (fir20_val) $fwrite(fp_20_fir, "%0d\n", $signed(fir20));
    end
endmodule
