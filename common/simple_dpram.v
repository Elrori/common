/*
*  Name         :simple_dpram.v
*  Description  :
*  Origin       :230610
*  EE           :hel
*/

module simple_dpram #(
    parameter width     = 1,
    parameter widthad   = 1,
    parameter initfile  = "None"    
)(
    input                       clk,
    
    input       [widthad-1:0]   wraddress,
    input                       wren,
    input       [width-1:0]     data,
    
    input                       rden,
    input       [widthad-1:0]   rdaddress,
    output reg  [width-1:0]     q
);
reg [width-1:0] mem [(2**widthad)-1:0];
initial begin
    if(initfile != "None" )
    $readmemh(initfile, mem);
end

always @(posedge clk) begin
    if(wren) mem[wraddress] <= data;
end
always @(posedge clk) begin
    if(rden) q <= mem[rdaddress];
end
endmodule
