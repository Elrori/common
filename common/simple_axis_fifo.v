/* 
*   Name  : Simple AXI STREAM FIFO with small2big width converter. Simulation model
*   Origin: 231013
*   EE    : hel
*/
module simple_axis_fifo
#(
    parameter integer DATA_IN_WIDTH     = 16  ,
    parameter integer DATA_OUT_WIDTH    = 128 ,
    parameter integer ADDR_WIDTH        = 8   ,// output deep = 2**ADDR_WIDTH 
    parameter integer FRAME_MODE        = 1   ,// FRAME_MODE(>0): m_axis_tvalid will only assert when fifo full or have one frame
    parameter integer FULL_SLACK        = 1    // important parameter, improper values may lead to functional failure,
                                               // suggest >= 1. not use when DATA_IN_WIDTH==DATA_OUT_WIDTH
)
(
    input   wire                        clk     , 
    input   wire                        rst     ,    

    input   wire[DATA_IN_WIDTH-1:0]     s_axis_tdata    ,
    input   wire                        s_axis_tlast    ,// if DATA_IN_WIDTH!=DATA_OUT_WIDTH, s_last should be aligned at last word at end of frame
    input   wire                        s_axis_tvalid   ,
    output  wire                        s_axis_tready   ,

    output  wire[DATA_OUT_WIDTH-1:0]    m_axis_tdata    ,
    output  wire                        m_axis_tlast    ,
    output  wire                        m_axis_tvalid   ,
    input   wire                        m_axis_tready   

);
wire    almost_full;
wire    wr_full_int;
wire    wr_full;
wire    dout_vld;
wire    dout_last;
wire [DATA_OUT_WIDTH-1:0]dout;
wire    rd_empty;
wire [ADDR_WIDTH:0]rd_dat_cnt;
wire [ADDR_WIDTH:0]almost_full_th;
wire    last;
wire [DATA_OUT_WIDTH/8-1:0]keep;
reg     can_read;
reg     can_read_req_full;
reg     can_read_req_last;
reg     can_read_t;
reg  [ADDR_WIDTH-1:0]cnt_data;

// small2big width, adapter => big width  firstfallthrough fifo
assign  almost_full_th  = {1'd1,{ADDR_WIDTH{1'd0}}} - FULL_SLACK;
assign  almost_full     = rd_dat_cnt >= almost_full_th;
assign  wr_full         = (FULL_SLACK==0) ? wr_full_int : almost_full;
assign  s_axis_tready   = ~wr_full ;
assign  m_axis_tvalid   = (FRAME_MODE==0) ? ~rd_empty : can_read;
assign  m_axis_tlast    = rd_empty ? 1'd0 : last;
simple_adapters#(
    .DATA_IN_WIDTH  (DATA_IN_WIDTH  ),
    .DATA_OUT_WIDTH (DATA_OUT_WIDTH )
)simple_adapters
(
    .clk        (clk                ),
    .rstn       (~rst               ),
    .din_vld    (s_axis_tready&s_axis_tvalid),
    .din_last   (s_axis_tlast       ),
    .din        (s_axis_tdata       ),
    .dout_vld   (dout_vld           ),
    .dout_last  (dout_last          ),
    .dout       (dout               )
);
simple_fifo#(
    .DATA_WIDTH(DATA_OUT_WIDTH+1),
    .ADDR_WIDTH(ADDR_WIDTH)
) simple_fifo(
    .rst        (rst                ),    
    .clk        (clk                ), 
    .wr_ena     (dout_vld           ),    
    .wr_dat     ({dout_last,dout}   ), 
    .wr_full    (wr_full_int        ),
    .rd_ena     (m_axis_tready&m_axis_tvalid),    
    .rd_dat     ({last,m_axis_tdata}), 
    .rd_empty   (rd_empty           ),
    .dat_cnt    (rd_dat_cnt         ) 
); 
always @(posedge clk or posedge rst) begin
    if (rst) begin
        can_read_req_full    <= 1'd0;
    end else if(can_read && can_read_t)begin
        can_read_req_full    <= 1'd0;
    end else if (wr_full) begin
        can_read_req_full    <= 1'd1;
    end
end 
always @(posedge clk or posedge rst) begin
    if (rst) begin
        can_read_req_last    <= 1'd0;
    end else if(can_read && (!can_read_t))begin
        can_read_req_last    <= 1'd0;
    end else if (dout_last && dout_vld) begin
        can_read_req_last    <= 1'd1;
    end
end 
always @(posedge clk or posedge rst) begin
    if (rst) begin
        can_read    <= 1'd0;
        can_read_t  <= 1'd0;
        cnt_data    <= {(ADDR_WIDTH-1){1'd0}};
    end else if((can_read_req_full) && (!can_read))begin
        can_read    <= 1'd1;
        can_read_t  <= 1'd1;
    end else if((can_read_req_last) && (!can_read))begin
        can_read    <= 1'd1;
        can_read_t  <= 1'd0;
    end else if (can_read && m_axis_tready) begin
        if (can_read_t) begin // full
            if ((cnt_data==almost_full_th-1'd1)) begin
                can_read    <= 1'd0;
                can_read_t  <= 1'd0;
                cnt_data    <= {(ADDR_WIDTH-1){1'd0}};
            end else begin
                cnt_data    <= cnt_data + 1'd1;
            end
        end else begin      // last
            if (m_axis_tlast) begin
                can_read <= 1'd0;
            end
        end
    end
end     

endmodule
