`timescale 1ns/1ps

module mdio_if_apb_tb;

// Parameters
localparam  DIV = 10;

//Ports
reg  clk = 0;
reg  rst = 1;
wire  mdc;
wire [4 :0] mdo;
wire [4 :0] mdi;
wire [4 :0] mdt;
wire [4 :0] mdio;

reg  [15:0] paddr =0;
reg  pwrite =0;
reg  psel =0;
reg  penable =0;
reg  [15:0] pwdata =0;
wire [15:0] prdata;
wire  pready;

assign mdio[0] = mdt[0] ? mdo[0] : 1'dz;
assign mdio[1] = mdt[1] ? mdo[1] : 1'dz;
assign mdio[2] = mdt[2] ? mdo[2] : 1'dz;
assign mdio[3] = mdt[3] ? mdo[3] : 1'dz;
assign mdio[4] = mdt[4] ? mdo[4] : 1'dz;
assign mdi = mdio;

pullup(mdio[0]);
pullup(mdio[1]);
pullup(mdio[2]);
pullup(mdio[3]);
pullup(mdio[4]);
mdio_if_apb # (
  .DIV(DIV)
)
mdio_if_apb_inst (
  .clk(clk),
  .rst(rst),
  .mdc(mdc),
  .mdo(mdo),
  .mdi(mdi),
  .mdt(mdt),

  .paddr(paddr),
  .pwrite(pwrite),
  .psel(psel),
  .penable(penable),
  .pwdata(pwdata),
  .prdata(prdata),
  .pready(pready)
);
always #5  clk = ! clk ;

task automatic apb_wr;
  input [15:0]addr;
  input [15:0]din;
  begin
    paddr = addr;
    pwrite = 1'd1;
    pwdata = din;
    psel = 1'd1;
    @(posedge clk)#0;
    penable = 1'd1;
    @(posedge clk)#0;
    while (!pready) begin
      @(posedge clk)#0;
    end
    psel = 1'd0;
    penable = 1'd0;
  end
endtask 

task automatic apb_rd;
  input [15:0]addr;
  output reg [15:0]dout;
  begin
    paddr = addr;
    pwrite = 1'd0;
    psel = 1'd1;
    @(posedge clk)#0;
    penable = 1'd1;
    @(posedge clk)#0;
    while (!pready) begin
      @(posedge clk)#0;
    end
    dout = prdata;
    psel = 1'd0;
    penable = 1'd0;
  end
endtask 

reg [15:0] ret = 0;
initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0,mdio_if_apb_tb);

    #10
    rst = 0;
    #1000

    @(posedge clk) #0;
    @(posedge clk) #0;
    @(posedge clk) #0;
    @(posedge clk) #0;

    apb_wr({4'd4,5'b00111,1'd0,5'b10001,1'd0},16'h1111);// | bus select | phyaddr | dummy | regaddr | dummy |
    @(posedge clk) #0;
    @(posedge clk) #0;
    @(posedge clk) #0;
    @(posedge clk) #0;
    apb_rd({4'd4,5'b00111,1'd0,5'b10001,1'd0},ret);$display("ret = 0x%4x", ret);
    

    
    #10000;
    $finish;

end
endmodule