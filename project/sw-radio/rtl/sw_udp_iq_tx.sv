// Ethernet II / IPv4 / UDP broadcaster. K9IQ v3: 256 signed I16/Q16 pairs.
// Reference framing: Elrori/k9plus-fm-radio, but payload is lossless 16-bit.
// Ethernet MAC/FCS, preamble and IFG are supplied by axis_gmii_tx.
module sw_udp_iq_tx (
    input  wire clk, input wire rst,
    input  wire [31:0] tuned_hz,
    input  wire [31:0] dropped_samples,
    input  wire [31:0] fifo_word,
    input  wire fifo_empty,
    input  wire [11:0] fifo_count,
    output wire fifo_rd_en,
    output reg [7:0] axis_data,
    output wire axis_valid,
    input  wire axis_ready,
    output wire axis_last,
    output reg [31:0] packet_count
);
    // UDP 8 + app 32 + 1024 IQ = 1064 (0x0428).
    // IPv4 20 + UDP 1064 = 1084 (0x043c), checksum 0xa05f.
    localparam integer FRAME_BYTES=14+20+8+32+1024;
    localparam integer IQ_WORDS=256;
    reg [10:0] idx;
    reg sending;
    reg [31:0] tune_latched, dropped_latched;
    reg [63:0] sample_index, index_latched;
    reg [31:0] sequence_latched;
    wire [10:0] payload_index=idx-11'd42;
    wire [10:0] iq_index=payload_index-11'd32;
    wire is_iq=idx>=11'd74;
    assign axis_valid=sending;
    assign axis_last=sending && (idx==FRAME_BYTES-1);
    // FWFT FIFO advances only at the last byte of a complete sample.
    assign fifo_rd_en=sending && is_iq && axis_ready &&
                      (iq_index[1:0]==2'b11) && !fifo_empty;

    function automatic [7:0] ip_header(input [4:0] n);
        begin
            case (n)
                0:ip_header=8'h45; 1:ip_header=0;
                2:ip_header=8'h04; 3:ip_header=8'h3c;
                4:ip_header=0; 5:ip_header=0;
                6:ip_header=8'h40; 7:ip_header=0;
                8:ip_header=8'h40; 9:ip_header=8'h11;
                10:ip_header=8'ha0; 11:ip_header=8'h5f;
                12:ip_header=8'hc0; 13:ip_header=8'ha8;
                14:ip_header=8'h0a; 15:ip_header=8'h02;
                16:ip_header=8'hc0; 17:ip_header=8'ha8;
                18:ip_header=8'h0a; 19:ip_header=8'hff;
                default:ip_header=0;
            endcase
        end
    endfunction

    function automatic [7:0] udp_header(input [2:0] n);
        begin
            case (n)
                0,2:udp_header=8'hc3; // source/destination UDP port 50003
                1,3:udp_header=8'h53;
                4:udp_header=8'h04;
                5:udp_header=8'h28;
                default:udp_header=0;  // UDP checksum optional for IPv4
            endcase
        end
    endfunction

    always @* begin
        axis_data=0;
        if (idx < 6) axis_data=8'hff; // destination broadcast MAC
        else if (idx < 12) begin
            case (idx)
                6:axis_data=8'h02; 7:axis_data=8'h4b;
                8:axis_data=8'h39; 9:axis_data=8'h2b;
                10:axis_data=8'h01; 11:axis_data=8'h03;
                default:axis_data=0;
            endcase
        end else if (idx==12) axis_data=8'h08;
        else if (idx==13) axis_data=0;
        else if (idx<34) axis_data=ip_header(idx-14);
        else if (idx<42) axis_data=udp_header(idx-34);
        else if (idx<74) begin
            case (payload_index)
                0:axis_data=8'h4b; 1:axis_data=8'h39;
                2:axis_data=8'h49; 3:axis_data=8'h51; // "K9IQ"
                4:axis_data=8'h03; // protocol v3; incompatible with v2 I8/Q8
                5:axis_data=8'h04 | ((dropped_latched!=0)?8'h01:8'h00);
                6:axis_data=8'h20; 7:axis_data=0;
                8:axis_data=sequence_latched[7:0];
                9:axis_data=sequence_latched[15:8];
                10:axis_data=sequence_latched[23:16];
                11:axis_data=sequence_latched[31:24];
                12:axis_data=tune_latched[7:0];
                13:axis_data=tune_latched[15:8];
                14:axis_data=tune_latched[23:16];
                15:axis_data=tune_latched[31:24];
                // 1,250,000 complex samples/second (uint32LE)
                16:axis_data=8'hd0; 17:axis_data=8'h12;
                18:axis_data=8'h13; 19:axis_data=0;
                20:axis_data=index_latched[7:0];
                21:axis_data=index_latched[15:8];
                22:axis_data=index_latched[23:16];
                23:axis_data=index_latched[31:24];
                24:axis_data=index_latched[39:32];
                25:axis_data=index_latched[47:40];
                26:axis_data=index_latched[55:48];
                27:axis_data=index_latched[63:56];
                28:axis_data=dropped_latched[7:0];
                29:axis_data=dropped_latched[15:8];
                30:axis_data=dropped_latched[23:16];
                31:axis_data=dropped_latched[31:24];
                default:axis_data=0;
            endcase
        end else begin
            case (iq_index[1:0])
                0:axis_data=fifo_word[7:0];
                1:axis_data=fifo_word[15:8];
                2:axis_data=fifo_word[23:16];
                3:axis_data=fifo_word[31:24];
            endcase
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            idx<=0; sending<=0; packet_count<=0;
            sequence_latched<=0; tune_latched<=0;
            dropped_latched<=0; sample_index<=0; index_latched<=0;
        end else begin
            if (!sending && fifo_count>=IQ_WORDS) begin
                sending<=1; idx<=0;
                sequence_latched<=packet_count;
                tune_latched<=tuned_hz;
                dropped_latched<=dropped_samples;
                index_latched<=sample_index;
                packet_count<=packet_count+1'b1;
            end else if (sending && axis_ready) begin
                if (idx==FRAME_BYTES-1) begin
                    sending<=0; idx<=0;
                    sample_index<=sample_index+IQ_WORDS;
                end else idx<=idx+1'b1;
            end
        end
    end
endmodule
