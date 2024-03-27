`timescale 1ns/1ps
module mdio_if_tb;

  // Parameters
  localparam  DIV = 10;

  //Ports
  reg  clk=0;
  reg  rst=1;
  wire  mdc;
  wire  mdt;
  wire  mdo;
  wire  mdi;
  reg  op_ena  = 0;
  reg  op_rdwr = 0;
  reg  [4 :0] op_phya = 0;
  reg  [4 :0] op_rega = 0;
  reg  [15:0] op_din  = 16'h1111;
  wire [15:0] op_dout;
  wire  op_done;
  wire mdio;
  assign mdio = mdt? mdo : 1'dz;
  assign mdi = mdio;
  mdio_if # (
    .DIV(DIV)
  )
  mdio_if_inst (
    .clk(clk),
    .rst(rst),
    .mdc(mdc),
    .mdt(mdt),
    .mdo(mdo),
    .mdi(mdi),
    .op_ena(op_ena),
    .op_rdwr(op_rdwr),
    .op_phya(op_phya),
    .op_rega(op_rega),
    .op_din(op_din),
    .op_dout(op_dout),
    .op_done(op_done)
  );

always #5  clk = ! clk ;
initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0,mdio_if_tb);

    #10
    rst = 0;
    #100

    
    @(posedge clk) #0;
    op_ena  = 1;
    op_rdwr = 1;
    op_phya = 5'b10001;
    op_rega = 5'b10001;
    op_din  = 16'h1111;
    @(posedge clk) #0;
    op_ena  = 0;
    wait(op_done);
    @(posedge clk) #0;
    #1000;


    @(posedge clk) #0;
    op_ena  = 1;
    op_rdwr = 0;
    op_phya = 5'b10001;
    op_rega = 5'b10001;
    @(posedge clk) #0;
    op_ena  = 0;
    wait(op_done);
    @(posedge clk) #0;
    #100;


    
    #10000;
    $finish;

end
endmodule