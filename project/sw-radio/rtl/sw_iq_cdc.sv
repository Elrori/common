// Transfer *whole complex samples* atomically. Never drop half an I/Q word.
// SHIFT is selected by top-level bench calibration to target signed 16-bit IQ.
module sw_iq_cdc #(
    parameter integer SHIFT=9,
    parameter integer FIFO_DEPTH=2048
) (
    input  wire wr_clk, input wire wr_rst,
    input  wire sample_valid,
    input  wire signed [31:0] i_fir, q_fir,
    input  wire rd_clk,
    output wire [31:0] rd_word,
    input  wire rd_en,
    output wire rd_empty,
    output wire [11:0] rd_count,
    output reg  [31:0] dropped_samples
);
    function automatic [15:0] quant16(input signed [31:0] x);
        reg signed [31:0] s;
        begin
            // Rounding toward nearest with symmetric handling for negatives.
            s = (x + (32'sd1 << (SHIFT-1))) >>> SHIFT;
            if (s > 32767) quant16 = 16'h7fff;
            else if (s < -32768) quant16 = 16'h8000;
            else quant16 = s[15:0];
        end
    endfunction
    wire full, wr_busy, rd_busy;
    reg [31:0] dropped_wr;
    wire [31:0] gray_wr = (dropped_wr >> 1) ^ dropped_wr;
    (* ASYNC_REG="TRUE" *) reg [31:0] gray_m1, gray_m2;
    wire [31:0] decoded;
    genvar g;
    assign decoded[31] = gray_m2[31];
    generate for (g=0;g<31;g=g+1) begin : decode
        assign decoded[g] = decoded[g+1] ^ gray_m2[g];
    end endgenerate
    always @(posedge wr_clk) begin
        if (wr_rst) dropped_wr <= 0;
        else if (sample_valid && (full || wr_busy)) dropped_wr <= dropped_wr + 1'b1;
    end
    always @(posedge rd_clk) begin
        if (wr_rst) begin gray_m1 <= 0; gray_m2 <= 0; dropped_samples <= 0; end
        else begin
            gray_m1 <= gray_wr;
            gray_m2 <= gray_m1;
            dropped_samples <= decoded;
        end
    end
    xpm_fifo_async #(
        .CDC_SYNC_STAGES(2), .DOUT_RESET_VALUE("0"),
        .ECC_MODE("no_ecc"), .FIFO_MEMORY_TYPE("block"),
        .FIFO_READ_LATENCY(0), .FIFO_WRITE_DEPTH(FIFO_DEPTH),
        .FULL_RESET_VALUE(0), .PROG_EMPTY_THRESH(10),
        .PROG_FULL_THRESH(FIFO_DEPTH-32),
        .RD_DATA_COUNT_WIDTH(12), .READ_DATA_WIDTH(32),
        .READ_MODE("fwft"), .RELATED_CLOCKS(0), .SIM_ASSERT_CHK(0),
        .USE_ADV_FEATURES("0707"), .WAKEUP_TIME(0),
        .WRITE_DATA_WIDTH(32), .WR_DATA_COUNT_WIDTH(12)
    ) buffer (
        .almost_empty(), .almost_full(), .data_valid(), .dbiterr(),
        .dout(rd_word), .empty(rd_empty), .full(full),
        .overflow(), .prog_empty(), .prog_full(), .rd_data_count(rd_count),
        .rd_rst_busy(rd_busy), .sbiterr(), .underflow(), .wr_ack(),
        .wr_data_count(), .wr_rst_busy(wr_busy),
        .din({quant16(q_fir), quant16(i_fir)}),
        .injectdbiterr(1'b0), .injectsbiterr(1'b0),
        .rd_clk(rd_clk), .rd_en(rd_en && !rd_busy),
        .rst(wr_rst), .sleep(1'b0), .wr_clk(wr_clk),
        .wr_en(sample_valid && !full && !wr_busy)
    );
endmodule
