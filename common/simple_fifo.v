/* 
*   Name  : First_Word_Fall_Through  FIFO
*   Origin: 
*   EE    : hel
*/
module simple_fifo
#(
    parameter integer DATA_WIDTH = 16 ,
    parameter integer ADDR_WIDTH = 8   // DEEP = 2**ADDR_WIDTH 
)
(
    input   wire                 rst     ,    
    input   wire                 clk     , 

    input   wire                 wr_ena  ,    
    input   wire[DATA_WIDTH-1:0] wr_dat  , 
    output  wire                 wr_full ,

    input   wire                 rd_ena  ,    
    output  wire[DATA_WIDTH-1:0] rd_dat  , 
    output  wire                 rd_empty,

    output  wire[ADDR_WIDTH:0]   dat_cnt  
);
wire [ADDR_WIDTH-1:0]tmp;
reg  [DATA_WIDTH-1:0]mem[0:2**ADDR_WIDTH-1];
reg  [ADDR_WIDTH  :0]wrptr;
reg  [ADDR_WIDTH  :0]rdptr;
wire [ADDR_WIDTH-1:0]wraddr = wrptr[ADDR_WIDTH-1:0];
wire [ADDR_WIDTH-1:0]rdaddr = rdptr[ADDR_WIDTH-1:0];

assign wr_full  = (wrptr == {~rdptr[ADDR_WIDTH],rdptr[ADDR_WIDTH-1:0]});
assign rd_empty = (rdptr == wrptr);
assign rd_dat   = mem[rdaddr];
assign tmp      = wraddr - rdaddr;
assign dat_cnt  = wr_full ? {1'd1,{ADDR_WIDTH{1'd0}}} : {1'd0,tmp};
always @(posedge clk or posedge rst) begin
    if (rst) begin
        wrptr       <= 'd0;
    end else if (wr_ena&&(!wr_full)) begin
        mem[wraddr] <= wr_dat;
        wrptr       <= wrptr + 1'd1;
    end
end
always @(posedge clk or posedge rst) begin
    if (rst) begin
        rdptr       <= 'd0;
    end else if (rd_ena&&(!rd_empty)) begin
        rdptr       <= rdptr + 1'd1;
    end
end
endmodule
