/*
 * Symmetric, time-multiplexed 47-tap FIR decimator by two.
 *
 * Two copies of a circular sample buffer give independent synchronous reads
 * of each symmetric pair.  The arrays may map to FPGA distributed RAM
 * (RAM64M in XC7 Yosys) instead of 47*W_DIN registers and wide muxes.
 * One signed multiplier is used per I/Q channel: 23 symmetric pairs and
 * the centre tap are processed in 24 MAC clocks, plus 2 pipeline clocks.
 * This fits the 32 clocks available per output at CIC decimation R=16.
 *
 * COE_FILE contains (N_TAPS+1)/2 signed hex coefficients, from the
 * outermost tap h[0] through the centre h[(N_TAPS-1)/2].
 */
module dsp_fir_dec_sym #(
    parameter integer W_DIN = 20,
    parameter integer W_COE = 16,
    parameter integer W_DOUT = 32,
    parameter integer N_TAPS = 47,
    parameter integer CLOCKS_PER_INPUT = 16,
    parameter COE_FILE = "common/fir_cic16_comp47_q15.hex"
) (
    input  wire                        clk,
    input  wire                        rst_n,
    input  wire signed [W_DIN-1:0]     din,
    input  wire                        din_val,
    output reg  signed [W_DOUT-1:0]    dout,
    output reg                         dout_val
);
localparam integer HALF = (N_TAPS-1)/2;
localparam integer TAP_BITS = $clog2(HALF+1);
localparam integer ADDR_BITS = $clog2(N_TAPS+1);
localparam integer MEM_DEPTH = 1 << ADDR_BITS;
localparam integer PRODUCT_BITS = W_DIN+1+W_COE;
localparam integer ACC_BITS = W_DIN+W_COE+$clog2(N_TAPS);

reg signed [W_COE-1:0] coeff [0:HALF];
reg signed [W_DIN-1:0] mem_a [0:MEM_DEPTH-1];
reg signed [W_DIN-1:0] mem_b [0:MEM_DEPTH-1];
reg [ADDR_BITS-1:0] wr_addr;
reg [ADDR_BITS-1:0] latest_addr;
reg [ADDR_BITS-1:0] fill_count;
reg window_filled;
reg pending_valid;
reg busy;
reg issuing_done;
reg mac_valid;
reg [TAP_BITS-1:0] issue_tap;
reg signed [W_DIN-1:0] rd_a, rd_b;
reg signed [W_COE-1:0] rd_coeff;
reg rd_center;
reg signed [ACC_BITS-1:0] accum;

initial begin
    $readmemh(COE_FILE, coeff);
`ifndef SYNTHESIS
    if ((N_TAPS < 3) || ((N_TAPS & 1) == 0))
        $fatal(1, "dsp_fir_dec_sym requires an odd N_TAPS >= 3");
    if (CLOCKS_PER_INPUT*2 <= HALF+3)
        $fatal(1, "Not enough ADC clocks for symmetric FIR MAC");
    if (W_DOUT > ACC_BITS)
        $fatal(1, "W_DOUT cannot exceed the accumulator precision");
`endif
end

wire [ADDR_BITS-1:0] read_addr_a = latest_addr - issue_tap;
wire [ADDR_BITS-1:0] read_addr_b =
    latest_addr - (N_TAPS-1-issue_tap);

// Both ports are synchronous read/single write.  No reset or other
// combinational accesses to either array: FPGA block-RAM inference.
always @(posedge clk) begin
    if (din_val) begin
        mem_a[wr_addr] <= din;
        mem_b[wr_addr] <= din;
    end
    if (busy && !issuing_done) begin
        rd_a <= mem_a[read_addr_a];
        rd_b <= mem_b[read_addr_b];
    end
end

wire signed [W_DIN:0] first =
    $signed({rd_a[W_DIN-1], rd_a});
wire signed [W_DIN:0] second =
    $signed({rd_b[W_DIN-1], rd_b});
wire signed [W_DIN:0] multiplicand =
    rd_center ? first : (first+second);
wire signed [PRODUCT_BITS-1:0] product =
    multiplicand * rd_coeff;
wire signed [ACC_BITS-1:0] mac_sum = accum + product;

wire signed [W_DOUT-1:0] rounded_result;
generate
    if (ACC_BITS > W_DOUT) begin: ROUND_TO_EVEN
        localparam integer DROP = ACC_BITS-W_DOUT;
        wire signed [ACC_BITS-1:0] quotient = mac_sum >>> DROP;
        wire [DROP-1:0] remainder = mac_sum[DROP-1:0];
        wire [DROP-1:0] half_way = {1'b1, {(DROP-1){1'b0}}};
        wire round_up = (remainder > half_way) ||
                        ((remainder == half_way) && quotient[0]);
        wire signed [ACC_BITS-1:0] nearest =
            quotient + {{(ACC_BITS-1){1'b0}}, round_up};
        assign rounded_result = nearest[W_DOUT-1:0];
    end else begin: NO_ROUNDING
        assign rounded_result = mac_sum[W_DOUT-1:0];
    end
endgenerate

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_addr        <= 'd0;
        latest_addr    <= 'd0;
        fill_count     <= 'd0;
        window_filled  <= 1'b0;
        pending_valid  <= 1'b0;
        busy           <= 1'b0;
        issuing_done   <= 1'b0;
        issue_tap      <= 'd0;
        mac_valid      <= 1'b0;
        rd_center      <= 1'b0;
        rd_coeff       <= 'd0;
        accum          <= 'd0;
        dout           <= 'd0;
        dout_val       <= 1'b0;
    end else begin
        dout_val <= 1'b0;

        if (din_val) begin
            wr_addr <= wr_addr + 1'b1;
            if (fill_count < N_TAPS)
                fill_count <= fill_count + 1'b1;
            if (!pending_valid) begin
                // First input of the next decimation-by-two pair.
                pending_valid  <= 1'b1;
            end else begin
                // The newest sample is written at wr_addr this cycle.
                // The first pair read starts one cycle later, so there is
                // no read-during-write address collision.
                pending_valid <= 1'b0;
                latest_addr   <= wr_addr;
                window_filled <= (fill_count >= N_TAPS-1);
                busy      <= 1'b1;
                issuing_done <= 1'b0;
                issue_tap <= 'd0;
                mac_valid <= 1'b0;
                accum     <= 'd0;
`ifndef SYNTHESIS
                if (busy)
                    $fatal(1, "FIR overrun: CIC input interval too short");
`endif
            end
        end

        if (busy) begin
            if (!issuing_done) begin
                rd_coeff <= coeff[issue_tap];
                rd_center <= (issue_tap == HALF);
                if (issue_tap == HALF)
                    issuing_done <= 1'b1;
                else
                    issue_tap <= issue_tap + 1'b1;
            end
            mac_valid <= !issuing_done;
            if (mac_valid) begin
                if (rd_center) begin
                    // Uninitialized block RAM cannot be read as valid data
                    // until an entire FIR window of CIC inputs has arrived.
                    dout_val <= window_filled;
                    if (window_filled)
                        dout <= rounded_result;
                    busy     <= 1'b0;
                end else begin
                    accum <= mac_sum;
                end
            end
        end
    end
end
endmodule
