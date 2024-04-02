`timescale 1ns/1ps

module phy_dlyset_tb;

// Parameters
localparam  DIV = 10;
localparam PHYA_A1  = 5'b00_001;
localparam PHYA_B1  = 5'b00_010;
localparam PHYA_A2  = 5'b00_001;
localparam PHYA_B2  = 5'b00_010;
localparam PHYA_A3  = 5'b00_001;
localparam PHYA_B3  = 5'b00_010;
localparam PHYA_C1  = 5'b00_001;
localparam PHYA_C2  = 5'b00_011;
localparam PHYA_D   = 5'b00_001;

//Ports
reg  clk = 0;
reg  rst = 1;
wire  mdc;
wire [4 :0] mdo;
reg  [4 :0] mdi = 'b11111;
wire [4 :0] mdt;
reg  set_ena = 0;
reg  [8 :0] set_rxcdlyena = {9{1'd1}};
reg  [4*9-1 :0] set_rxcdlysel = {4'd8,4'd7,4'd6,4'd5,4'd4,4'd3,4'd2,4'd1,4'd0};

phy_dlyset # (
  .DIV(DIV),
  .PHYA_A1(PHYA_A1),
  .PHYA_B1(PHYA_B1),
  .PHYA_A2(PHYA_A2),
  .PHYA_B2(PHYA_B2),
  .PHYA_A3(PHYA_A3),
  .PHYA_B3(PHYA_B3),
  .PHYA_C1(PHYA_C1),
  .PHYA_C2(PHYA_C2),
  .PHYA_D(PHYA_D)
)
phy_dlyset_inst (
  .clk(clk),
  .rst(rst),
  .mdc(mdc),
  .mdo(mdo),
  .mdi(mdi),
  .mdt(mdt),
  .set_ena(set_ena),
  .set_rxcdlyena(set_rxcdlyena),
  .set_rxcdlysel(set_rxcdlysel)
);

always #8  clk = ! clk ;

initial begin
  $dumpfile("wave.vcd");
  $dumpvars(0,phy_dlyset_tb);

  #10
  rst = 0;
  #1000

  @(posedge clk) #0;
  set_ena = 1;
  @(posedge clk) #0;
  set_ena = 0;

  #100000;
  wait(phy_dlyset_inst.state_chips==9 && phy_dlyset_inst.rdset_fin)
  #1000;
  $finish;

end

endmodule


