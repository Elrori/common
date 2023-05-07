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
    parameter FILE_SIN   = "dsp_nco_rom_sin90.txt",
    parameter FILE_COS   = "dsp_nco_rom_cos90.txt",
    parameter METHOD     = "MEDIUM_ROM" // "LARGE_ROM"   : the ROM stores the full 360 degrees of both the sine and cosine
                                        // "MEDIUM_ROM"  : the ROM stores 90 degrees of the sine and cosine waveforms
                                        // "SMALL_ROM"   : the ROM only stores 45 degrees of the sine and cosine waveforms
)(
    input   wire                    clk     ,
    input   wire                    rst_n   ,

    input   wire [ADDR_WIDTH-1:0]   addr    ,
    output  reg  [DATA_WIDTH-1:0]   sin_o   ,
    output  reg  [DATA_WIDTH-1:0]   cos_o  
);
reg [DATA_WIDTH-1:0]   sin;
reg [DATA_WIDTH-1:0]   cos;
localparam NPOINT       = 2**ADDR_WIDTH;
localparam NPOINTdiv2   = NPOINT/2;
localparam NPOINTdiv4   = NPOINT/4;
localparam NPOINTdiv8   = NPOINT/8;
initial begin
    $display("dsp_nco_rom.v Method : %s",METHOD);
    $display("dsp_nco_rom.v Sine   : %s",FILE_SIN);
    $display("dsp_nco_rom.v Cosine : %s",FILE_COS);
end
generate
    if (REG_OUT != 0) begin
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                sin_o <= {DATA_WIDTH{1'd0}};
                cos_o <= {DATA_WIDTH{1'd0}};
            end else begin
                sin_o <= sin;
                cos_o <= cos;
            end
        end        
    end else begin
        always @(*) begin
            sin_o = sin;
            cos_o = cos;            
        end
    end
endgenerate
generate
    if (METHOD == "SMALL_ROM") begin
        reg  [DATA_WIDTH-1:0] mem_sin [NPOINTdiv4-1:0];
        reg  [DATA_WIDTH-1:0] mem_cos [NPOINTdiv4-1:0];
        reg  [ADDR_WIDTH  :0] add_0;
        wire [DATA_WIDTH-1:0] mem_0;
        reg  [ADDR_WIDTH  :0] add_1;
        wire [DATA_WIDTH-1:0] mem_1;
        initial begin
        $readmemh(FILE_SIN, mem_sin);
        $readmemh(FILE_COS, mem_cos);
        end
        assign mem_0 = add_0 == {(ADDR_WIDTH+1){1'd0}} ? {DATA_WIDTH{1'd0}}            : mem_sin[add_0 - 1'd1];
        assign mem_1 = add_1 == {(ADDR_WIDTH+1){1'd0}} ? {1'd0,{(DATA_WIDTH-1){1'd1}}} : mem_cos[add_1 - 1'd1];
        always @(*) begin
            sin = {DATA_WIDTH{1'd0}};
            cos = {DATA_WIDTH{1'd0}};
            case(addr[ADDR_WIDTH-1:ADDR_WIDTH-3])
            3'd0:begin
                add_0    = addr;
                sin      = mem_0;
                add_1    = addr;
                cos      = mem_1;
            end
            3'd1:begin
                add_0    = NPOINTdiv4 - addr;
                sin      = mem_1;
                add_1    = NPOINTdiv4 - addr;
                cos      = mem_0;
            end
            3'd2:begin
                add_0    = addr - NPOINTdiv4;
                sin      = mem_1;
                add_1    = addr - NPOINTdiv4;
                cos      = 0 - mem_0;
            end
            3'd3:begin
                add_0    = NPOINTdiv2 - addr;
                sin      = mem_0;
                add_1    = NPOINTdiv2 - addr;
                cos      = 0 - mem_1;
            end
            3'd4:begin
                add_0    = addr - NPOINTdiv2;
                sin      = 0 - mem_0;
                add_1    = addr - NPOINTdiv2;
                cos      = 0 - mem_1;
            end
            3'd5:begin
                add_0    = NPOINTdiv4*3 - addr;
                sin      = 0 - mem_1;
                add_1    = NPOINTdiv4*3 - addr;
                cos      = 0 - mem_0;
            end
            3'd6:begin
                add_0    = addr - NPOINTdiv4*3;
                sin      = 0 - mem_1;
                add_1    = addr - NPOINTdiv4*3;
                cos      = mem_0;
            end
            3'd7:begin
                add_0    = NPOINT - addr;
                sin      = 0 - mem_0;
                add_1    = NPOINT - addr;
                cos      = mem_1;
            end
            endcase
        end
    end else if (METHOD == "MEDIUM_ROM") begin
        reg  [DATA_WIDTH-1:0] mem_sin [NPOINTdiv4-1:0];
        reg  [DATA_WIDTH-1:0] mem_cos [NPOINTdiv4-1:0];
        reg  [ADDR_WIDTH  :0] add;
        wire [DATA_WIDTH-1:0] mem_0;
        wire [DATA_WIDTH-1:0] mem_1;
        initial begin
        $readmemh(FILE_SIN, mem_sin);
        $readmemh(FILE_COS, mem_cos);
        end
        assign mem_0 = add == {(ADDR_WIDTH+1){1'd0}} ? {DATA_WIDTH{1'd0}}            : mem_sin[add - 1'd1];
        assign mem_1 = add == {(ADDR_WIDTH+1){1'd0}} ? {1'd0,{(DATA_WIDTH-1){1'd1}}} : mem_cos[add - 1'd1];
        always@(*)begin
            sin = {DATA_WIDTH{1'd0}};
            cos = {DATA_WIDTH{1'd0}};
            case(addr[ADDR_WIDTH-1:ADDR_WIDTH-2])
            2'd0:begin
                add      = addr;
                sin      = mem_0;
                cos      = mem_1;
            end
            2'd1:begin
                add      = NPOINTdiv2 - addr;
                sin      = mem_0;
                cos      = 0 - mem_1;
            end
            2'd2:begin
                add      = addr - NPOINTdiv2;
                sin      = 0 - mem_0;
                cos      = 0 - mem_1;
            end
            2'd3:begin
                add      = NPOINT - addr;
                sin      = 0 - mem_0;
                cos      = mem_1;
            end
            endcase
        end
    end else if (METHOD == "LARGE_ROM") begin
        reg  [DATA_WIDTH-1:0] mem_sin [NPOINT-1:0];
        reg  [DATA_WIDTH-1:0] mem_cos [NPOINT-1:0];
        initial begin
        $readmemh(FILE_SIN, mem_sin);
        $readmemh(FILE_COS, mem_cos);
        end
        always@(*)begin
            sin      = mem_sin[addr];
            cos      = mem_cos[addr];
        end
    end
endgenerate













endmodule
