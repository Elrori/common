//~ `New testbench
`timescale  1ns / 1ps

module dsp_nco_rom_tb;

// dsp_nco_rom Parameters
parameter PERIOD      = 10               ;

parameter ADDR_WIDTH  = $clog2(`DEPTH)   ;
parameter DATA_WIDTH  = `WIDTH           ;
parameter REG_OUT     = 0                ;

// dsp_nco_rom Inputs
reg   clk                                  = 0 ;
reg   rst_n                                = 0 ;
reg   [ADDR_WIDTH-1:0]  addr0               = 0 ;
reg   [ADDR_WIDTH-1:0]  addr1               = 0 ;
// dsp_nco_rom Outputs
wire  signed [DATA_WIDTH-1:0]  dout0            ;
wire  signed [DATA_WIDTH-1:0]  dout1            ;
reg  [DATA_WIDTH-1:0] mem0 [2**ADDR_WIDTH-1:0];
reg  [DATA_WIDTH-1:0] mem1 [2**ADDR_WIDTH-1:0];
initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial
begin
    #(PERIOD*2) rst_n  =  1;
end

dsp_nco_rom #(
    .ADDR_WIDTH ( ADDR_WIDTH ),
    .DATA_WIDTH ( DATA_WIDTH ),
    .REG_OUT    ( REG_OUT    ),
    .DATAFILE   ( "dsp_nco_rom_sin.txt"   ),
    .MODE       ( "sin"      ))
 u_dsp_nco_rom_sin (
    .clk                     ( clk                     ),
    .rst_n                   ( rst_n                   ),
    .addr                    ( addr0   [ADDR_WIDTH-1:0] ),

    .dout                    ( dout0   [DATA_WIDTH-1:0] )
);
dsp_nco_rom #(
    .ADDR_WIDTH ( ADDR_WIDTH ),
    .DATA_WIDTH ( DATA_WIDTH ),
    .REG_OUT    ( REG_OUT    ),
    .DATAFILE   ( "dsp_nco_rom_cos.txt"   ),
    .MODE       ( "cos"      ))
 u_dsp_nco_rom_cos (
    .clk                     ( clk                     ),
    .rst_n                   ( rst_n                   ),
    .addr                    ( addr1   [ADDR_WIDTH-1:0] ),

    .dout                    ( dout1   [DATA_WIDTH-1:0] )
);
integer i;
integer f;
integer err_sin = 0;
integer err_cos = 0;
integer fsin;
integer fcos;
task automatic check_sin;
input   integer add;
begin
    #0;
    addr0 = add;
    @(posedge clk);
    $fwrite(fsin,"%0d\n",dout0);
    if(dout0 != mem0[add])begin
        err_sin=err_sin+1;
        $display("nco sine mismatch! dout:%0x  mem[%0d]:%0x",dout0,add,mem0[add]);
    end
end
endtask
task automatic check_cos;
input   integer add;
begin
    #0;
    addr1 = add;
    @(posedge clk);
    $fwrite(fcos,"%0d\n",dout1);
    if(dout1 != mem1[add])begin
        err_cos=err_cos+1;
        $display("nco cosine mismatch! dout:%0x  mem[%0d]:%0x",dout1,add,mem1[add]);
    end
end
endtask //automatic
initial
begin
    $dumpfile("wave.vcd");
    $dumpvars(0,dsp_nco_rom_tb);
    $readmemh("dsp_nco_rom_sin_full.txt", mem0);    // golden ram
    $readmemh("dsp_nco_rom_cos_full.txt", mem1);    // golden ram
    fsin = $fopen("dsp_nco_rom_sin_ret.txt","w");   // verilog ram output
    fcos = $fopen("dsp_nco_rom_cos_ret.txt","w");   // verilog ram output
    #10;
    rst_n=1;
    @(posedge clk);
    for (i = 0;i<2**ADDR_WIDTH ;i=i+1 ) begin
        check_sin(i);
	check_cos(i);
    end
    $display("sine mismatch %0d/%0d",err_sin,2**ADDR_WIDTH);
    $display("cosine mismatch %0d/%0d",err_cos,2**ADDR_WIDTH);
    if(err_sin == 0 && err_cos == 0) $display("FULL PASS");
    #100;
    $fclose(fsin);
    $fclose(fcos);
    $finish;
end

endmodule
