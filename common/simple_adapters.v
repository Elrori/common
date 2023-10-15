/*
*   Name  : simple_adapters, in width n, out width n * 2^x, x=1,2,3,4,5...
*   Origin: 231011
*   EE    : hel
*/
module simple_adapters#(
    parameter integer DATA_IN_WIDTH     = 16  ,
    parameter integer DATA_OUT_WIDTH    = 128 
)
(
    input  wire                     clk,
    input  wire                     rstn,

    input  wire                     din_vld,
    input  wire                     din_last,
    input  wire [DATA_IN_WIDTH-1:0] din,
    
    output wire                     dout_vld,
    output wire                     dout_last,
    output wire [DATA_OUT_WIDTH-1:0]dout
);
localparam SMALL2BIG_DIV = $clog2(DATA_OUT_WIDTH/DATA_IN_WIDTH);
generate 
genvar j;
    for ( j=0 ; j<SMALL2BIG_DIV ; j=j+1 ) begin :loop
        wire dout_vld_  ;
        wire dout_last_ ;
        wire [DATA_IN_WIDTH*(2**(j+1))-1:0]dout_;
        if (j==0) begin
            simple_adapter # (
                .WIDTH_DIN(DATA_IN_WIDTH)
            )
        simple_adapter_inst (
                .clk        (clk                ),
                .rstn       (rstn               ),
                .din_vld    (din_vld            ),
                .din_last   (din_last           ),
                .din        (din                ),
                .dout_vld   (dout_vld_          ),
                .dout_last  (dout_last_         ),
                .dout       (dout_              )
            );
        end else begin
            simple_adapter # (
                .WIDTH_DIN(DATA_IN_WIDTH*(2**j))
            ) 
         simple_adapter_inst (
                .clk        (clk                ),
                .rstn       (rstn               ),
                .din_vld    (loop[j-1].dout_vld_),
                .din_last   (loop[j-1].dout_last_),
                .din        (loop[j-1].dout_    ),
                .dout_vld   (dout_vld_          ),
                .dout_last  (dout_last_         ),
                .dout       (dout_              )
            );
        end
    end
endgenerate
generate
    if(SMALL2BIG_DIV!=0)begin
        assign dout_vld  = loop[SMALL2BIG_DIV-1].dout_vld_ ;
        assign dout_last = loop[SMALL2BIG_DIV-1].dout_last_;
        assign dout      = loop[SMALL2BIG_DIV-1].dout_;
    end else begin
        assign dout_vld  = din_vld ;
        assign dout_last = din_last;
        assign dout      = din;
    end
endgenerate
endmodule
