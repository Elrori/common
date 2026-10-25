/*
 * Timing-friendly CIC decimator for faster ADC clocks.
 *
 * Unlike dsp_cic_dec, every integrator and comb stage is separated by a
 * register.  The extra latency has no effect on the CIC magnitude response,
 * while removing the five-wide-adder/subtractor combinational paths that
 * become marginal at 62.5 MHz on an Artix-7 -1 device.
 */
module dsp_cic_dec_pipe #(
    parameter integer R = 25,
    parameter integer M = 2,
    parameter integer N = 5,
    parameter integer BIN = 18,
    parameter integer COUT = 20,
    parameter CUT_METHOD = "ROUND",
    parameter integer BOUT = 47
) (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire [BIN-1:0]       din,
    output wire [BOUT-1:0]      dout,
    output wire [COUT-1:0]      dout_cut,
    output wire                 dout_vld
);
localparam integer CNTW = $clog2(R);

reg signed [BOUT-1:0] integrator [0:N-1];
reg signed [BOUT-1:0] comb_out [0:N-1];
reg signed [BOUT-1:0] comb_delay1 [0:N-1];
reg signed [BOUT-1:0] comb_delay2 [0:N-1];
reg [CNTW-1:0] count;
reg valid;
integer i;

wire signed [BOUT-1:0] din_extended =
    {{(BOUT-BIN){din[BIN-1]}}, din};
assign dout = comb_out[N-1];
assign dout_vld = valid;

generate
    if (CUT_METHOD == "ROUND") begin: ROUND
        // Preserve the proven sign-aware rounding convention used by the
        // original CIC so the only numerical change is R=25.
        wire carry_bit = dout[BOUT-1] ?
            (dout[BOUT-(COUT-1)-2] &
             (|dout[BOUT-(COUT-1)-3:0])) :
             dout[BOUT-(COUT-1)-2];
        assign dout_cut =
            {dout[BOUT-1], dout[BOUT-1:BOUT-(COUT-1)-1]} + carry_bit;
    end else begin: CUT
        assign dout_cut = $signed(dout) >>> (BOUT-COUT);
    end
endgenerate

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        count <= 0;
        valid <= 0;
        for (i=0; i<N; i=i+1) begin
            integrator[i] <= 0;
            comb_out[i] <= 0;
            comb_delay1[i] <= 0;
            comb_delay2[i] <= 0;
        end
    end else begin
        // A register between every integrator stage bounds the critical path
        // to one BOUT-bit addition.  Pipeline latency is immaterial to DDC.
        integrator[0] <= integrator[0] + din_extended;
        for (i=1; i<N; i=i+1)
            integrator[i] <= integrator[i] + integrator[i-1];

        valid <= (count == R-1);
        if (count == R-1) begin
            count <= 0;
            comb_delay1[0] <= integrator[N-1];
            if (M == 2)
                comb_delay2[0] <= comb_delay1[0];
            comb_out[0] <= integrator[N-1] -
                           ((M == 2) ? comb_delay2[0] : comb_delay1[0]);
            for (i=1; i<N; i=i+1) begin
                comb_delay1[i] <= comb_out[i-1];
                if (M == 2)
                    comb_delay2[i] <= comb_delay1[i];
                comb_out[i] <= comb_out[i-1] -
                               ((M == 2) ? comb_delay2[i] : comb_delay1[i]);
            end
        end else begin
            count <= count + 1'b1;
        end
    end
end

`ifndef SYNTHESIS
initial begin
    if (R < 2 || N < 1 || (M != 1 && M != 2))
        $fatal(1, "invalid pipelined CIC parameters");
    if (BOUT <= COUT)
        $fatal(1, "pipelined CIC requires BOUT > COUT");
end
`endif
endmodule
