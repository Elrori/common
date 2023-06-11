/*
*  Name         :dsp_ite_fft.v, dsp_ite_fft_mult.v, dsp_ite_fft_butt.v
*  Description  :Low cost iterative DIF FFT 
*  Origin       :230610
*  EE           :hel
*/
module dsp_ite_fft #(
    parameter DATA_W        = 16,
    parameter ADD_LATENCY   = 2,
    parameter MUL_LATENCY   = 2
)(
    input       wire                clk     ,
    input       wire                rst_n   ,

    input       wire [DATA_W*2-1:0] din     ,
    input       wire                din_vld ,
    output      wire                din_busy,

    output      wire [DATA_W*2-1:0] dout    ,
    output      wire                dout_vld
);
localparam PTN = 8;
localparam RND = 3;
localparam CTW = $clog2(PTN);
wire    wren0;
wire    rden0;	
wire    wren1;	
wire    rden1;	
wire    din_vld_pre_raw;
wire    din_vld_pre  ;
wire    dat_vld;
wire    butt_dout_vld;
reg     ram1_dout_vld;
wire    din_vld_nxt_raw;
wire    din_vld_nxt  ;
reg     din_vld_nxt_d1;
wire    butt_neg_rden_start;
wire    butt_neg_rden;
reg     butt_neg_rden_d1;
wire    mult_dout_vld;
wire    butt_pos_rden_start;
wire    butt_pos_rden;
reg  [CTW-1:0]din_cnt;
wire [CTW-1:0]din_cnt_tmp;
reg  [CTW-2:0]butt_cnt;
reg  [CTW-2:0]mult_cnt;
reg  [CTW-2:0]butt_neg_rden_cnt;
reg  [CTW-1:0]butt_pos_rden_cnt;
reg  [CTW-1:0]butt_pos_rden_cnt_d1;
wire [CTW-2:0]waddr0;	
wire [CTW-2:0]raddr0;	
wire [CTW-2:0]waddr1;	
wire [CTW-2:0]raddr1;
wire [DATA_W*2-1:0] q0;	
wire [DATA_W*2-1:0] q1;	
wire [DATA_W*2-1:0] wdata0;
wire [DATA_W*2-1:0] wdata1;
wire [DATA_W-1:0] butt_dout_real_pos;
wire [DATA_W-1:0] butt_dout_imag_pos;
wire [DATA_W-1:0] butt_dout_real_neg;
wire [DATA_W-1:0] butt_dout_imag_neg;
wire [DATA_W-1:0] butt_din_real_pos;
wire [DATA_W-1:0] butt_din_imag_pos;
wire [DATA_W-1:0] butt_din_real_neg;
wire [DATA_W-1:0] butt_din_imag_neg;
wire [DATA_W-1:0] mult_dout_real;
wire [DATA_W-1:0] mult_dout_imag;
wire [DATA_W-1:0] mult_din_real;
wire [DATA_W-1:0] mult_din_imag;
reg  [3    :0]round_in;
wire          finish;
wire          store_half;
wire [DATA_W*2-1:0] din_muxo;

assign  dat_vld               = din_vld | (ram1_dout_vld & (round_in != 0 & round_in < RND));
assign  din_vld_pre_raw       = ( din_cnt <  PTN/2    );
assign  din_vld_nxt_raw       = ((din_cnt >= PTN/2 - 1) & (din_cnt < PTN - 1)); 
assign  din_vld_pre           =   din_vld_pre_raw       & dat_vld;
assign  din_vld_nxt           =   din_vld_nxt_raw       & dat_vld;
assign  butt_neg_rden_start   = ( din_cnt == PTN - 1  ) & dat_vld;
assign  butt_pos_rden_start   = butt_cnt == {(CTW-1){1'd1}} & butt_dout_vld;
assign  butt_neg_rden         = butt_neg_rden_start | (butt_neg_rden_cnt != {(CTW-1){1'd0}});
assign  butt_pos_rden         = butt_pos_rden_start | (butt_pos_rden_cnt != {(CTW  ){1'd0}});


assign  wren0 = din_vld_pre   |  butt_dout_vld | store_half;
assign  rden0 = din_vld_nxt   |  butt_neg_rden;
assign  wren1 = butt_dout_vld |  mult_dout_vld;
assign  rden1 = butt_pos_rden;

assign  waddr0[CTW-2:0]       = butt_dout_vld ? butt_cnt[CTW-2:0]               : 
                                store_half    ? butt_pos_rden_cnt_d1[CTW-2:0]   :
                                din_cnt[CTW-2:0];
assign  din_cnt_tmp[CTW-1:0]  = din_cnt[CTW-1:0] + 1'd1;
assign  raddr0[CTW-2:0]       = din_vld_nxt_raw ? din_cnt_tmp : butt_neg_rden_cnt;
assign  waddr1[CTW-2:0]       = butt_dout_vld   ? butt_cnt : mult_cnt;
assign  raddr1[CTW-2:0]       = butt_pos_rden   ? butt_pos_rden_cnt : {(CTW-1){1'd0}};

assign  wdata0[DATA_W*2-1:0]  = butt_dout_vld ? {butt_dout_real_neg,butt_dout_imag_neg} : din_muxo;
assign  butt_din_real_pos     = q0       [DATA_W*2-1 :DATA_W];
assign  butt_din_imag_pos     = q0       [DATA_W-1   :     0];
assign  mult_din_real         = q0       [DATA_W*2-1 :DATA_W];
assign  mult_din_imag         = q0       [DATA_W-1   :     0];
assign  butt_din_real_neg     = din_muxo [DATA_W*2-1 :DATA_W];
assign  butt_din_imag_neg     = din_muxo [DATA_W-1   :     0];
assign  wdata1[DATA_W*2-1:0]  = butt_dout_vld ? {butt_dout_real_pos,butt_dout_imag_pos} : {mult_dout_real,mult_dout_imag};
assign  din_muxo              = din_vld ? din : q1[DATA_W*2-1:0];

assign  dout_vld              = ram1_dout_vld & (round_in == RND);
assign  dout                  = q1 & {(DATA_W*2){dout_vld}};
assign  finish                = (round_in == RND) & (butt_pos_rden_cnt_d1 == PTN-1);
assign  store_half            = (round_in == RND) & (butt_pos_rden_cnt_d1 <  PTN/2) & ram1_dout_vld;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        din_cnt  <= {CTW{1'd0}};
    end else if(dat_vld)begin
        if(din_cnt<PTN)
            din_cnt  <= din_cnt + 1'd1;
        else begin
            din_cnt  <= {CTW{1'd0}};
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        round_in <= 4'd0;
    end else if(din_cnt == PTN-1)begin
        round_in <= round_in + 1'd1;
    end else if (finish) begin
        round_in <= 4'd0;
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        butt_neg_rden_cnt <= {(CTW-1){1'd0}};
    end else if(butt_neg_rden_start && butt_neg_rden_cnt == {(CTW-1){1'd0}})begin
        butt_neg_rden_cnt <= butt_neg_rden_cnt + 1'd1;
    end else if(butt_neg_rden_cnt != {(CTW-1){1'd0}})begin
        butt_neg_rden_cnt <= butt_neg_rden_cnt + 1'd1;
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        butt_pos_rden_cnt <= {(CTW){1'd0}};
    end else if(butt_pos_rden_start && butt_pos_rden_cnt == {(CTW){1'd0}})begin
        butt_pos_rden_cnt <= butt_pos_rden_cnt + 1'd1;
    end else if(butt_pos_rden_cnt != {(CTW){1'd0}})begin
        butt_pos_rden_cnt <= butt_pos_rden_cnt + 1'd1;
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        butt_pos_rden_cnt_d1 <= {(CTW){1'd0}};
    end else begin
        butt_pos_rden_cnt_d1 <= butt_pos_rden_cnt;
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        butt_cnt <= {(CTW-1){1'd0}};
    end else if(butt_dout_vld)begin
        butt_cnt <= butt_cnt + 1'd1;
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mult_cnt <= {(CTW-1){1'd0}};
    end else if(mult_dout_vld)begin
        mult_cnt <= mult_cnt + 1'd1;
    end
end
always @(posedge clk or negedge rst_n) begin // ram delay 1
    if (!rst_n) begin
        butt_neg_rden_d1 <= 1'd0;
        din_vld_nxt_d1   <= 1'd0;
        ram1_dout_vld    <= 1'd0;
    end else begin
        butt_neg_rden_d1 <= butt_neg_rden;
        din_vld_nxt_d1   <= din_vld_nxt;
        ram1_dout_vld    <= butt_pos_rden;
    end
end
simple_dpram #(
    .width     ( DATA_W*2   ),
    .widthad   ( CTW-1      ),
    .initfile  ( "None"     )    
)simple_dpram_0
(
    .clk       ( clk        ),
    .wraddress ( waddr0     ),
    .wren      ( wren0      ),
    .data      ( wdata0     ),
    .rden      ( rden0      ),
    .rdaddress ( raddr0     ),
    .q         ( q0         )
);
simple_dpram #(
    .width     ( DATA_W*2   ),
    .widthad   ( CTW-1      ),
    .initfile  ( "None"     )    
)simple_dpram_1
(
    .clk       ( clk        ),
    .wraddress ( waddr1     ),
    .wren      ( wren1      ),
    .data      ( wdata1     ),
    .rden      ( rden1      ),
    .rdaddress ( raddr1     ),
    .q         ( q1         )
);

dsp_ite_fft_mult #(DATA_W) dsp_ite_fft_mult
(
    .clk             ( clk              ),
    .rst_n           ( rst_n            ),
    .din_vld         ( butt_neg_rden_d1 ),
    .din_real        ( mult_din_real    ),
    .din_imag        ( mult_din_imag    ),
    .dout_vld        ( mult_dout_vld    ),
    .dout_real       ( mult_dout_real   ),
    .dout_imag       ( mult_dout_imag   ) 
);
dsp_ite_fft_butt #(DATA_W)dsp_ite_fft_butt
(
    .clk             ( clk                  ),
    .rst_n           ( rst_n                ),
    .din_vld         ( din_vld_nxt_d1       ),
    .din_real_pos    ( butt_din_real_pos    ),
    .din_imag_pos    ( butt_din_imag_pos    ),
    .din_real_neg    ( butt_din_real_neg    ),
    .din_imag_neg    ( butt_din_imag_neg    ),
    .dout_vld        ( butt_dout_vld        ),
    .dout_real_pos   ( butt_dout_real_pos   ),
    .dout_imag_pos   ( butt_dout_imag_pos   ),
    .dout_real_neg   ( butt_dout_real_neg   ),
    .dout_imag_neg   ( butt_dout_imag_neg   ) 
);

endmodule

module dsp_ite_fft_mult#(
    parameter DATA_W        = 16
)(
    input       wire                clk         ,
    input       wire                rst_n       ,

    input       wire                din_vld     ,
    input       wire [DATA_W-1:0]   din_real    ,
    input       wire [DATA_W-1:0]   din_imag    ,

    output      wire                dout_vld    ,
    output      wire [DATA_W-1:0]   dout_real   ,
    output      wire [DATA_W-1:0]   dout_imag    
);
reg  [2:0]din_vld_d;
assign    dout_vld = din_vld_d[2];
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        din_vld_d <= 3'd0;
    end else begin
        din_vld_d <= {din_vld_d,din_vld};
    end
end
assign dout_real = 1;
assign dout_imag = 1;
endmodule

module dsp_ite_fft_butt#(
    parameter DATA_W        = 16
)(
    input       wire                clk             ,
    input       wire                rst_n           ,

    input       wire                din_vld         ,
    input       wire [DATA_W-1:0]   din_real_pos    ,
    input       wire [DATA_W-1:0]   din_imag_pos    ,
    input       wire [DATA_W-1:0]   din_real_neg    ,
    input       wire [DATA_W-1:0]   din_imag_neg    ,

    output      wire                dout_vld        ,
    output      wire [DATA_W-1:0]   dout_real_pos   ,
    output      wire [DATA_W-1:0]   dout_imag_pos   ,
    output      wire [DATA_W-1:0]   dout_real_neg   ,
    output      wire [DATA_W-1:0]   dout_imag_neg    
);
reg  [1:0]din_vld_d;
assign    dout_vld = din_vld_d[1];
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        din_vld_d <= 2'd0;
    end else begin
        din_vld_d <= {din_vld_d,din_vld};
    end
end
assign dout_real_pos = 1;
assign dout_imag_pos = 1;
assign dout_real_neg = 1;
assign dout_imag_neg = 1;
endmodule