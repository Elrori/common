`timescale  1ns / 1ps

module tb_dsp_nco;

// dsp_nco Parameters
parameter PERIOD      = 1000000000/`FS         ; 
parameter PHI_WIDTH   = `PHI_WIDTHS            ;
parameter ADDR_WIDTH  = `ADDR_WIDTHS           ;
parameter DATA_WIDTH  = `DATA_WIDTHS           ;
parameter DITHER_MAX  = `DITHER_MAXS           ;
parameter REG_OUT     = `REG_OUT               ;
parameter FILE_SIN    = "dsp_nco_rom_sin45.txt";
parameter FILE_COS    = "dsp_nco_rom_cos45.txt";
parameter METHOD      = "SMALL_ROM"            ;
initial begin
    $display("Verilog Testbench conf: ");  
    $display("PHI_WIDTH     : %0d ",PHI_WIDTH );
    $display("ADDR_WIDTH    : %0d ",ADDR_WIDTH);
    $display("DATA_WIDTH    : %0d ",DATA_WIDTH);
    $display("DITHER_MAX    : %0d ",DITHER_MAX);
    $display("REG_OUT       : %0d ",REG_OUT   );
    $display("FILE_SIN      : \"%s\"  ",FILE_SIN  );
    $display("FILE_COS      : \"%s\"  ",FILE_COS  );
    $display("METHOD        : \"%s\"  ",METHOD    );
end
// dsp_nco Inputs
reg   clk                                  = 0 ;
reg   rst_n                                = 0 ;
reg   en                                   = 0 ;// fo * (2**PHI_WIDTH)/40000000
reg   [PHI_WIDTH-1  :0]  phi_inc           = `PHI_INCS;//5MHz   fo = 40MHz*phi_inc/(2**PHI_WIDTH) 

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
    .DITHER_MAX ( DITHER_MAX ),
    .REG_OUT    ( REG_OUT    ),
    .FILE_SIN   ( FILE_SIN   ),
    .FILE_COS   ( FILE_COS   ),
    .METHOD     ( METHOD     ))
 u_dsp_nco (
    .clk                     ( clk                        ),
    .rst_n                   ( rst_n                      ),
    .en                      ( en                         ),
    .phi_inc                 ( phi_inc  [PHI_WIDTH-1  :0] ),
    .dither_en               ( 1'd1                       ),
    .sin_o                   ( sin_o    [DATA_WIDTH-1 :0] ),
    .cos_o                   ( cos_o    [DATA_WIDTH-1 :0] )
);
reg [31:0]cnt = 0 ;
reg en_d1;
always @(posedge clk) begin
    en_d1 <= en;
end
always @(posedge clk) begin
    if((REG_OUT != 0 )? en_d1 : en)begin
        $fwrite(fsin,"%0d\n",sin_o);
        $fwrite(fcos,"%0d\n",cos_o);
        cnt <= cnt + 1'd1;
    end
end
initial
begin 
    $dumpfile("wave.vcd");
    $dumpvars(0,tb_dsp_nco);
    fsin = $fopen("dsp_nco_sin_ret.txt","w");   
    fcos = $fopen("dsp_nco_cos_ret.txt","w");   
    repeat(10)begin @(posedge clk);#0;end
    @(posedge clk);#0;
    en=1; 
    repeat(`RET_NUMS)begin
    @(posedge clk);#0;
    end
    en=0; 
    repeat(10)begin @(posedge clk);#0;end
    $fclose(fsin);
    $fclose(fcos);
    $finish;
end

endmodule
