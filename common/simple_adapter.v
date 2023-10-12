/*
*   Name  : simple_adapter, in width n, out width 2n
*   Origin: 231011
*   EE    : hel
*/
module simple_adapter#(
    parameter WIDTH_DIN = 8
)
(
     input  wire                 clk,
     input  wire                 rstn,
     input  wire                 last_align,

     input  wire                 din_vld,
     input  wire [WIDTH_DIN-1:0] din,
     
     output reg                  dout_vld,
     output reg  [2*WIDTH_DIN-1:0] dout
);
reg                 din_vld_d1;
reg [WIDTH_DIN-1:0] din_d1;
reg [WIDTH_DIN-1:0] din_d1_half;
reg                 tick;
reg                 last_align_d1;
always@(posedge clk or negedge rstn)begin
    if (!rstn) begin
        tick       <= 1'd0;
        din_vld_d1 <= 1'd0;
        din_d1     <= {(WIDTH_DIN-1){1'd0}};
        din_d1_half<= {(WIDTH_DIN-1){1'd0}};
        dout       <= {(2*WIDTH_DIN-1){1'd0}};
        dout_vld   <= 1'd0;
    end else begin
        din_vld_d1 <= din_vld;
        din_d1     <= din;
        last_align_d1 <= last_align & din_vld;
        if(last_align_d1)begin
            tick    <= 1'd0;
        end else if(din_vld_d1)begin
            tick    <= ~tick;
        end
        if(tick==1'd0 && din_vld_d1==1'd1)begin
            din_d1_half <= din_d1;
        end
        if(tick==1'd1 && din_vld_d1==1'd1)begin
            dout        <= {din_d1_half,din_d1};
            dout_vld    <= 1'd1;
        end else begin
            dout_vld    <= 1'd0;
        end
    end

end
endmodule