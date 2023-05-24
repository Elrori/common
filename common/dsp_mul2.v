/*
*  Name         :dsp_mul2.v
*  Description  :
*  Origin       :230523
*  EE           :hel
*/
module #(
    parameter I_W = 12,
    parameter O_W = 16
) 
dsp_mul2(
   input    wire                      clk         ,        
   input    wire                      rst_n       ,
   input    wire  signed   [I_W-1 :0] din         ,
   input    wire  signed   [I_W-1 :0] ain         ,
   input    wire  signed   [I_W-1 :0] bin         ,
   output   wire  signed   [O_W-1 :0] aout        , 
   output   wire  signed   [O_W-1 :0] bout
);
localparam M_W = I_W*2;
reg signed[M_W-1:0]aout_b;
reg signed[M_W-1:0]bout_b;

wire    carry_bit0   =  aout_b[M_W-1] ? ( aout_b[M_W-(O_W-1)-1-1] & ( |aout_b[M_W-(O_W-1)-1-1-1:0] ) ) : aout_b[M_W-(O_W-1)-1-1] ;
assign  aout         = {aout_b[M_W-1], aout_b[M_W-1:M_W-(O_W-1)-1]} + carry_bit0 ;
wire    carry_bit1   =  bout_b[M_W-1] ? ( bout_b[M_W-(O_W-1)-1-1] & ( |bout_b[M_W-(O_W-1)-1-1-1:0] ) ) : bout_b[M_W-(O_W-1)-1-1] ;
assign  bout         = {bout_b[M_W-1], bout_b[M_W-1:M_W-(O_W-1)-1]} + carry_bit1 ;

always@(posedge clk or negedge rst_n)begin
    if (!rst_n) begin
        aout_b  <=  {(M_W){1'd0}};
        aout_b  <=  {(M_W){1'd0}};
    end else begin
        aout_b  <=  ain * din;
        bout_b  <=  bin * din;
    end
end
endmodule
