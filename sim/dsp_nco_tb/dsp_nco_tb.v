//~ `New testbench
`timescale  1ns / 1ps

module tb_dsp_nco;

// dsp_nco Parameters
parameter PERIOD      = 25                     ; // 40MHz
parameter PHI_WIDTH   = 14                     ;
parameter ADDR_WIDTH  = 14                     ;
parameter DATA_WIDTH  = 12                     ;
parameter USE_DITHER  = 1                      ;
parameter REG_OUT     = 0                      ;
parameter FILE_SIN    = "dsp_nco_rom_sin360.txt";
parameter FILE_COS    = "dsp_nco_rom_cos360.txt";
parameter METHOD      = "LARGE_ROM"           ;

// dsp_nco Inputs
reg   clk                                  = 0 ;
reg   rst_n                                = 0 ;
reg   en                                   = 0 ;
reg   [PHI_WIDTH-1  :0]  phi_inc           = 2048 ;//10MHz   fo = 40MHz*phi_inc/(2**PHI_WIDTH) 

// dsp_nco Outputs
wire  signed [DATA_WIDTH-1 :0]  sin_o             ;
wire  signed [DATA_WIDTH-1 :0]  cos_o             ;
integer fsin;
integer fcos;

initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial
begin
    #(PERIOD*2) rst_n  =  1;
end

dsp_nco #(
    .PHI_WIDTH  ( PHI_WIDTH  ),
    .ADDR_WIDTH ( ADDR_WIDTH ),
    .DATA_WIDTH ( DATA_WIDTH ),
    .USE_DITHER ( USE_DITHER ),
    .REG_OUT    ( REG_OUT    ),
    .FILE_SIN   ( FILE_SIN   ),
    .FILE_COS   ( FILE_COS   ),
    .METHOD     ( METHOD     ))
 u_dsp_nco (
    .clk                     ( clk                        ),
    .rst_n                   ( rst_n                      ),
    .en                      ( en                         ),
    .phi_inc                 ( phi_inc  [PHI_WIDTH-1  :0] ),

    .sin_o                   ( sin_o    [DATA_WIDTH-1 :0] ),
    .cos_o                   ( cos_o    [DATA_WIDTH-1 :0] )
);
always @(clk) begin
    if(en)begin
        $fwrite(fsin,"%0d\n",sin_o);
        $fwrite(fcos,"%0d\n",cos_o);
    end
end
initial
begin 
    $dumpfile("wave.vcd");
    $dumpvars(0,tb_dsp_nco);
    fsin = $fopen("dsp_nco_sin_ret.txt","w");   
    fcos = $fopen("dsp_nco_cos_ret.txt","w");   
    #100;
    @(posedge clk);#0;
    en=1; 
    repeat(20000)begin
    @(posedge clk);
    end
    $fclose(fsin);
    $fclose(fcos);
    $finish;
end

endmodule