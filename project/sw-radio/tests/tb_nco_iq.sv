`timescale 1ns/1ps
module tb_nco_iq;
reg clk=0; always #12.5 clk=~clk;
reg rst_n=0;
wire signed[13:0] a,b;
integer k=0;
longint signed dot=0, ea=0, eb=0;
dsp_nco #(.PHI_WIDTH(32),.ADDR_WIDTH(15),.DATA_WIDTH(14),
 .DITHER_MAX(8),.REG_OUT(1),.METHOD("SMALL_ROM"),
 .FILE_SIN("common/nco_q13_sin45.hex"),
 .FILE_COS("common/nco_q13_cos45.hex")) dut (
 .clk(clk),.rst_n(rst_n),.en(1'b1),
 .phi_inc(32'h20000000),.dither_en(1'b1),.sin_o(a),.cos_o(b));
initial begin
repeat(5) @(negedge clk);rst_n=1;
repeat(270) begin
 @(negedge clk);
 k=k+1;
 if(k<15) $display("NCO cycle %0d: sin=%0d cos=%0d",k,a,b);
 if(k>20) begin
  dot=dot+$signed(a)*$signed(b);
  ea=ea+$signed(a)*$signed(a);
  eb=eb+$signed(b)*$signed(b);
 end
end
$display("NCO quadrature energies=%0d %0d dot=%0d",ea,eb,dot);
if(ea<1000000 || eb<1000000 || (dot>ea/6 || dot<-ea/6))
 $fatal(1,"NCO sine and cosine are nonorthogonal");
$display("PASS: NCO14 quadrature");
$finish;
end
endmodule
