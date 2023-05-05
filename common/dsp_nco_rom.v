/*
*  Name         :dsp_nco_rom.v
*  Description  :
*  Origin       :230503
*  EE           :hel
*/
module dsp_nco_rom #(
    parameter ADDR_WIDTH = 12,
    parameter DATA_WIDTH = 12,
    parameter REG_OUT    = 0 ,
    parameter DATAFILE   = "dsp_nco_rom_sin.txt",
    parameter MODE       = "sin" // "sin" or "cos"
)(
    input   wire                    clk     ,
    input   wire                    rst_n   ,

    input   wire [ADDR_WIDTH-1:0]   addr    ,
    output  reg  [DATA_WIDTH-1:0]   dout    
);
localparam NPOINT       = 2**ADDR_WIDTH;
localparam NPOINTdiv2   = NPOINT/2;
localparam NPOINTdiv4   = NPOINT/4;
reg  [DATA_WIDTH-1:0] mem [NPOINTdiv4-1:0];
reg  [ADDR_WIDTH  :0] add_0;
wire [DATA_WIDTH-1:0] mem_0;
initial begin
$readmemh(DATAFILE, mem);
end
generate 
    if(MODE=="sin")begin
	assign mem_0 = add_0 == {(ADDR_WIDTH+1){1'd0}} ? {DATA_WIDTH{1'd0}} : mem[add_0 - 1'd1];
        always@(*)begin
            case(addr[ADDR_WIDTH-1:ADDR_WIDTH-2])
            2'd0:begin
                add_0    = addr;
                dout     = mem_0;
            end
            2'd1:begin
                add_0    = NPOINTdiv2 - addr;
                dout     = mem_0;
            end
            2'd2:begin
                add_0    = addr - NPOINTdiv2;
                dout     = 0 - mem_0;
            end
            2'd3:begin
                add_0    = NPOINT - addr;
                dout     = 0 - mem_0;
            end
            endcase
        end
    end else if(MODE=="cos")begin
        assign mem_0 = add_0 == {(ADDR_WIDTH+1){1'd0}} ? {1'd0,{(DATA_WIDTH-1){1'd1}}} : mem[add_0 - 1'd1];
	always@(*)begin
            case(addr[ADDR_WIDTH-1:ADDR_WIDTH-2])
            2'd0:begin
                add_0    = addr;
                dout     = mem_0;
            end
            2'd1:begin
                add_0    = NPOINTdiv2 - addr;
                dout     = 0 - mem_0;
            end
            2'd2:begin
                add_0    = addr - NPOINTdiv2; 
                dout     = 0 - mem_0;
            end
            2'd3:begin
                add_0    = NPOINT - addr;
                dout     = mem_0;
            end
            endcase
        end
    end
endgenerate
endmodule
