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
localparam SMALL2BIG_DIV = $clog2(DATA_OUT_WIDTH/DATA_IN_WIDTH);
wire    almost_full = rd_dat_cnt >= {1'd1,{ADDR_WIDTH{1'd0}}}-FULL_SLACK;
wire    wr_full_int;
assign  wr_full = (FULL_SLACK==0)?wr_full_int:almost_full;
generate 
genvar j;
    for ( j=0 ; j<SMALL2BIG_DIV ; j=j+1 ) begin :loop
        wire dout_vld;
        wire [DATA_IN_WIDTH*(2**(j+1))-1:0]dout;
        if (j==0) begin
            simple_adapter # (
                .WIDTH_DIN(DATA_IN_WIDTH)
            )
            simple_adapter_inst (
                .clk        (clk),
                .rstn       (~rst),
                .last_align (1'd0),
                .din_vld    (wr_ena),
                .din        (wr_dat),
                .dout_vld   (dout_vld),
                .dout       (dout)
            ); 
        end else begin
            simple_adapter # (
                .WIDTH_DIN(DATA_IN_WIDTH*(2**j))
            )
            simple_adapter_inst (
                .clk        (clk),
                .rstn       (~rst),
                .last_align (1'd0),
                .din_vld    (loop[j-1].dout_vld),
                .din        (loop[j-1].dout),
                .dout_vld   (dout_vld),
                .dout       (dout)
            );            
        end
    end
endgenerate
simple_fifo#(
    .DATA_WIDTH(DATA_OUT_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) simple_fifo_tb(
    .rst     (rst),    
    .clk     (clk), 
    .wr_ena  (loop[SMALL2BIG_DIV-1].dout_vld  ),    
    .wr_dat  (loop[SMALL2BIG_DIV-1].dout  ), 
    .wr_full (wr_full_int ),
    .rd_ena  (rd_ena  ),    
    .rd_dat  (rd_dat  ), 
    .rd_empty(rd_empty),
    .dat_cnt (rd_dat_cnt ) 
);

endmodule
