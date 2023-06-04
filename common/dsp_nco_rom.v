/*
*  Name         :dsp_nco_rom.v
*  Description  :
*  Origin       :230503
*  EE           :hel
*/
module dsp_nco_rom #(
    parameter ADDR_WIDTH = 12,
    parameter DATA_WIDTH = 12,
    parameter REG_OUT    = 0 , // 0: 1clock latency, 1: 2clock latency
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
    if (REG_OUT != 0) begin:regout
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
        wire [DATA_WIDTH-1:0] mem_sin;
        wire [DATA_WIDTH-1:0] mem_cos;
        reg  [ADDR_WIDTH-3:0] add;
        reg  [ADDR_WIDTH-3:0] add_r;
        reg  [ADDR_WIDTH-1:0] addr_r;
        wire [DATA_WIDTH-1:0] mem_0;
        wire [DATA_WIDTH-1:0] mem_1;
        wire [ADDR_WIDTH-4:0] radd;
        assign radd[ADDR_WIDTH-4:0] = add[ADDR_WIDTH-3:0]-1'd1;
        simple_ram #(
            .widthad    (ADDR_WIDTH-3       ),
            .width      (DATA_WIDTH         ),
            .initfile   (FILE_SIN           )
        )simple_ram_sin(
            .clk        ( clk                           ),
            .wraddress  ( {(ADDR_WIDTH-3){1'd0}}        ),
            .wren       ( 1'd0                          ),
            .data       ( {DATA_WIDTH{1'd0}}            ),
            .rdaddress  ( radd                          ),
            .q          ( mem_sin                       )
        );
        simple_ram #(
            .widthad    (ADDR_WIDTH-3       ),
            .width      (DATA_WIDTH         ),
            .initfile   (FILE_COS           )
        )simple_ram_cos(
            .clk        ( clk                           ),
            .wraddress  ( {(ADDR_WIDTH-3){1'd0}}        ),
            .wren       ( 1'd0                          ),
            .data       ( {DATA_WIDTH{1'd0}}            ),
            .rdaddress  ( radd                          ),
            .q          ( mem_cos                       )
        );
        assign mem_0 = add_r == {(ADDR_WIDTH+1){1'd0}} ? {DATA_WIDTH{1'd0}}            : mem_sin;
        assign mem_1 = add_r == {(ADDR_WIDTH+1){1'd0}} ? {1'd0,{(DATA_WIDTH-1){1'd1}}} : mem_cos;
        always @(*) begin
            case(addr[ADDR_WIDTH-1:ADDR_WIDTH-3])
            3'd0:add = addr;
            3'd1:add = NPOINTdiv4 - addr;
            3'd2:add = addr - NPOINTdiv4;
            3'd3:add = NPOINTdiv2 - addr;
            3'd4:add = addr - NPOINTdiv2;
            3'd5:add = NPOINTdiv4*3 - addr;
            3'd6:add = addr - NPOINTdiv4*3;
            3'd7:add = NPOINT - addr;
            endcase
        end
        always @(posedge clk or negedge rst_n)begin
            if(!rst_n) begin
                add_r  <= {ADDR_WIDTH{1'd0}};
                addr_r <= {ADDR_WIDTH{1'd0}};
            end else begin
                add_r  <= add;
                addr_r <= addr;
            end
        end
        always @(*) begin
            sin = {DATA_WIDTH{1'd0}};
            cos = {DATA_WIDTH{1'd0}};
            case(addr_r[ADDR_WIDTH-1:ADDR_WIDTH-3])
            3'd0:begin
                sin      = mem_0;
                cos      = mem_1;
            end
            3'd1:begin
                sin      = mem_1;
                cos      = mem_0;
            end
            3'd2:begin
                sin      = mem_1;
                cos      = 0 - mem_0;
            end
            3'd3:begin
                sin      = mem_0;
                cos      = 0 - mem_1;
            end
            3'd4:begin
                sin      = 0 - mem_0;
                cos      = 0 - mem_1;
            end
            3'd5:begin
                sin      = 0 - mem_1;
                cos      = 0 - mem_0;
            end
            3'd6:begin
                sin      = 0 - mem_1;
                cos      = mem_0;
            end
            3'd7:begin
                sin      = 0 - mem_0;
                cos      = mem_1;
            end
            endcase
        end
    end else if (METHOD == "MEDIUM_ROM") begin
        wire [DATA_WIDTH-1:0] mem_sin;
        wire [DATA_WIDTH-1:0] mem_cos;
        reg  [ADDR_WIDTH-2:0] add;
        reg  [ADDR_WIDTH-2:0] add_r;
        reg  [ADDR_WIDTH-1:0] addr_r;
        wire [DATA_WIDTH-1:0] mem_0;
        wire [DATA_WIDTH-1:0] mem_1;
        wire [ADDR_WIDTH-3:0] radd;
        assign radd[ADDR_WIDTH-3:0] = add[ADDR_WIDTH-2:0]-1'd1;
        simple_ram #(
            .widthad    (ADDR_WIDTH-2       ),
            .width      (DATA_WIDTH         ),
            .initfile   (FILE_SIN           )
        )simple_ram_sin(
            .clk        ( clk                           ),
            .wraddress  ( {(ADDR_WIDTH-2){1'd0}}        ),
            .wren       ( 1'd0                          ),
            .data       ( {DATA_WIDTH{1'd0}}            ),
            .rdaddress  ( radd                          ),
            .q          ( mem_sin                       )
        );
        simple_ram #(
            .widthad    (ADDR_WIDTH-2       ),
            .width      (DATA_WIDTH         ),
            .initfile   (FILE_COS           )
        )simple_ram_cos(
            .clk        ( clk                           ),
            .wraddress  ( {(ADDR_WIDTH-2){1'd0}}        ),
            .wren       ( 1'd0                          ),
            .data       ( {DATA_WIDTH{1'd0}}            ),
            .rdaddress  ( radd                          ),
            .q          ( mem_cos                       )
        );
        assign mem_0 = add_r == {(ADDR_WIDTH+1){1'd0}} ? {DATA_WIDTH{1'd0}}            : mem_sin;
        assign mem_1 = add_r == {(ADDR_WIDTH+1){1'd0}} ? {1'd0,{(DATA_WIDTH-1){1'd1}}} : mem_cos;
        always@(*)begin
            case(addr[ADDR_WIDTH-1:ADDR_WIDTH-2])
            2'd0:add = addr;
            2'd1:add = NPOINTdiv2 - addr;
            2'd2:add = addr - NPOINTdiv2;
            2'd3:add = NPOINT - addr;
            endcase
        end
        always @(posedge clk or negedge rst_n)begin
            if(!rst_n) begin
                add_r  <= {ADDR_WIDTH{1'd0}};
                addr_r <= {ADDR_WIDTH{1'd0}};
            end else begin
                add_r  <= add;
                addr_r <= addr;
            end
        end

        always@(*)begin
            sin = {DATA_WIDTH{1'd0}};
            cos = {DATA_WIDTH{1'd0}};
            case(addr_r[ADDR_WIDTH-1:ADDR_WIDTH-2])
            2'd0:begin
                sin      = mem_0;
                cos      = mem_1;
            end
            2'd1:begin
                sin      = mem_0;
                cos      = 0 - mem_1;
            end
            2'd2:begin
                sin      = 0 - mem_0;
                cos      = 0 - mem_1;
            end
            2'd3:begin
                sin      = 0 - mem_0;
                cos      = mem_1;
            end
            endcase
        end
    end else if (METHOD == "LARGE_ROM") begin
        wire  [DATA_WIDTH-1:0] mem_sin ;
        wire  [DATA_WIDTH-1:0] mem_cos ;
        always@(*)begin
            sin      = mem_sin;
            cos      = mem_cos;
        end
        simple_ram #(
            .widthad    (ADDR_WIDTH         ),
            .width      (DATA_WIDTH         ),
            .initfile   (FILE_SIN           )
        )simple_ram_sin(
            .clk        ( clk                           ),
            .wraddress  ( {ADDR_WIDTH{1'd0}}            ),
            .wren       ( 1'd0                          ),
            .data       ( {DATA_WIDTH{1'd0}}            ),
            .rdaddress  ( addr                          ),
            .q          ( mem_sin                       )
        );
        simple_ram #(
            .widthad    (ADDR_WIDTH         ),
            .width      (DATA_WIDTH         ),
            .initfile   (FILE_COS           )
        )simple_ram_cos(
            .clk        ( clk                           ),
            .wraddress  ( {ADDR_WIDTH{1'd0}}            ),
            .wren       ( 1'd0                          ),
            .data       ( {DATA_WIDTH{1'd0}}            ),
            .rdaddress  ( addr                          ),
            .q          ( mem_cos                       )
        );
    end
endgenerate
endmodule
