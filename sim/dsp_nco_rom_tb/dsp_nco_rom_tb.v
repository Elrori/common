//~ `New testbench
`timescale  1ns / 1ps

module dsp_nco_rom_tb;

// dsp_nco_rom Parameters
parameter PERIOD      = 10               ;

parameter ADDR_WIDTH  = $clog2(`DEPTH)   ;
parameter DATA_WIDTH  = `WIDTH           ;
parameter REG_OUT     = 0                ;
parameter DATAFILE    = "dsp_nco_rom.txt";

// dsp_nco_rom Inputs
reg   clk                                  = 0 ;
reg   rst_n                                = 0 ;
reg   [ADDR_WIDTH-1:0]  addr               = 0 ;

// dsp_nco_rom Outputs
wire  signed [DATA_WIDTH-1:0]  dout               ;
reg  [DATA_WIDTH-1:0] mem [2**ADDR_WIDTH-1:0];

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
    .DATAFILE   ( DATAFILE   ))
 u_dsp_nco_rom (
    .clk                     ( clk                     ),
    .rst_n                   ( rst_n                   ),
    .addr                    ( addr   [ADDR_WIDTH-1:0] ),

    .dout                    ( dout   [DATA_WIDTH-1:0] )
);
integer i;
integer f;
integer j = 0;
integer k;
task automatic check;
input   integer add;
begin
    #0;
    addr = add;
    @(posedge clk);
    $fwrite(k,"%0d\n",dout);
    if(dout != mem[add])begin
        j=j+1;
        $display("mismatch! dout:%0x  mem[%0d]:%0x",dout,add,mem[add]);
    end
end
endtask //automatic
initial
begin
    $dumpfile("wave.vcd");
    $dumpvars(0,u_dsp_nco_rom);
    $readmemh("dsp_nco_rom_full.log", mem);
    k = $fopen("dsp_nco_rom_ret.log","w");
    #10;
    rst_n=1;
    @(posedge clk);
    for (i = 0;i<2**ADDR_WIDTH ;i=i+1 ) begin
        check(i);
    end
    $display("mismatch %0d/%0d",j,2**ADDR_WIDTH);
    if(j == 0) $display("FULL PASS");
    #100;
    $fclose(k);
    $finish;
end

endmodule