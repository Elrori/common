/* 
*   Name  : First_Word_Fall_Through  FIFO
*   Origin: 231012
*   EE    : hel
*/
module simple_fifo_adapter
#(
    parameter integer DATA_IN_WIDTH     = 16  ,
    parameter integer DATA_OUT_WIDTH    = 128 ,
    parameter integer ADDR_WIDTH        = 8   ,// DEEP = 2**ADDR_WIDTH 
    parameter integer FULL_SLACK        = 1     
)
(
    input   wire                    rst     ,    
    input   wire                    clk     , 

    input   wire                    wr_ena  ,    
    input   wire[DATA_IN_WIDTH-1:0] wr_dat  , 
    output  wire                    wr_full ,

    input   wire                    rd_ena  ,    
    output  wire[DATA_OUT_WIDTH-1:0]rd_dat  , 
    output  wire                    rd_empty,

    output  wire[ADDR_WIDTH:0]      rd_dat_cnt  
);
// small2big width, adapter => big fifo
wire    almost_full;
wire    wr_full_int;
wire    dout_vld;
wire [DATA_OUT_WIDTH-1:0]dout;

assign  almost_full = rd_dat_cnt >= {1'd1,{ADDR_WIDTH{1'd0}}} - FULL_SLACK;
assign  wr_full     = (FULL_SLACK==0) ? wr_full_int : almost_full;

simple_adapters#(
    .DATA_IN_WIDTH  (DATA_IN_WIDTH  ),
    .DATA_OUT_WIDTH (DATA_OUT_WIDTH )
)simple_adapters
(
    .clk        (clk        ),
    .rstn       (~rst       ),
    .din_vld    (wr_ena     ),
    .din_last   (1'd0       ),
    .din        (wr_dat     ),
    .dout_vld   (dout_vld   ),
    .dout_last  (           ),
    .dout       (dout       )
);
simple_fifo#(
    .DATA_WIDTH(DATA_OUT_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) simple_fifo_tb(
    .rst        (rst           ),    
    .clk        (clk           ), 
    .wr_ena     (dout_vld      ),    
    .wr_dat     (dout          ), 
    .wr_full    (wr_full_int   ),
    .rd_ena     (rd_ena        ),    
    .rd_dat     (rd_dat        ), 
    .rd_empty   (rd_empty      ),
    .dat_cnt    (rd_dat_cnt    ) 
);

endmodule
