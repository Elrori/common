/* 
*   Name  : First_Word_Fall_Through ASYNC FIFO
*   Origin: 
*   EE    : hel
*/
module simple_fifo_async
#(
    parameter integer DATA_WIDTH = 16 ,
    parameter integer ADDR_WIDTH = 8   // DEEP = 2**ADDR_WIDTH 
)
(
    input   wire                 wr_rst  ,    
    input   wire                 wr_clk  ,    
    input   wire                 wr_ena  ,    
    input   wire[DATA_WIDTH-1:0] wr_dat  , 
    output  wire                 wr_full ,

    input   wire                 rd_rst  ,  
    input   wire                 rd_clk  ,    
    input   wire                 rd_ena  ,    
    output  wire[DATA_WIDTH-1:0] rd_dat  , 
    output  wire                 rd_empty 
);
reg  [DATA_WIDTH-1:0]mem[0:2**ADDR_WIDTH-1];
reg  [ADDR_WIDTH  :0]wrptr;
reg  [ADDR_WIDTH  :0]rdptr;
wire [ADDR_WIDTH-1:0]wraddr = wrptr[ADDR_WIDTH-1:0];
wire [ADDR_WIDTH-1:0]rdaddr = rdptr[ADDR_WIDTH-1:0];
wire [ADDR_WIDTH  :0]wrptr_gray = (wrptr>>1)^wrptr;
wire [ADDR_WIDTH  :0]rdptr_gray = (rdptr>>1)^rdptr;

reg  [ADDR_WIDTH  :0]wrptr_gray_r0;
reg  [ADDR_WIDTH  :0]wrptr_gray_r1;
reg  [ADDR_WIDTH  :0]rdptr_gray_r0;
reg  [ADDR_WIDTH  :0]rdptr_gray_r1;
assign wr_full  = (wrptr_gray == {~rdptr_gray_r1[ADDR_WIDTH:ADDR_WIDTH-1],rdptr_gray_r1[ADDR_WIDTH-2:0]});
assign rd_empty = (rdptr_gray == wrptr_gray_r1);
assign rd_dat   = mem[rdaddr];
always @(posedge wr_clk or posedge wr_rst) begin
    if (wr_rst) begin
        rdptr_gray_r0 <= 'd0;
        rdptr_gray_r1 <= 'd0;
    end else begin
        rdptr_gray_r0 <= rdptr_gray;
        rdptr_gray_r1 <= rdptr_gray_r0;
    end
end
always @(posedge rd_clk or posedge rd_rst) begin
    if (rd_rst) begin
        wrptr_gray_r0 <= 'd0;
        wrptr_gray_r1 <= 'd0;
    end else begin
        wrptr_gray_r0 <= wrptr_gray;
        wrptr_gray_r1 <= wrptr_gray_r0;
    end
end
always @(posedge wr_clk or posedge wr_rst) begin
    if (wr_rst) begin
        wrptr       <= 'd0;
    end else if (wr_ena&&(!wr_full)) begin
        mem[wraddr] <= wr_dat;
        wrptr       <= wrptr + 1'd1;
    end
end
always @(posedge rd_clk or posedge rd_rst) begin
    if (rd_rst) begin
        rdptr       <= 'd0;
    end else if (rd_ena&&(!rd_empty)) begin
        rdptr       <= rdptr + 1'd1;
    end
end
endmodule
