`timescale 1ns/1ps
module simple_adapter_serial_tb;

// Parameters
localparam DATA_IN_WIDTH  = 16;
localparam DATA_OUT_WIDTH  = 128;
localparam BUFFERSIZE = 1024;
//Ports
reg  clk=0;
reg  rstn=0;
reg  din_vld_bad=0;
reg  random1b=0;
wire  din_vld=din_vld_bad&random1b;
reg  [DATA_IN_WIDTH-1:0] din=0;
reg din_last=0;

reg [DATA_IN_WIDTH-1:0]buff[0:BUFFERSIZE-1];
reg chk_en=0;
reg [31:0]chk_len=0;
reg [31:0]chk_len_=0;

localparam SMALL2BIG_DIV = $clog2(DATA_OUT_WIDTH/DATA_IN_WIDTH);
generate 
genvar j;
    for ( j=0 ; j<SMALL2BIG_DIV ; j=j+1 ) begin :loop
        wire dout_vld,dout_last;
        wire [DATA_IN_WIDTH*(2**(j+1))-1:0]dout;
        if (j==0) begin
            simple_adapter # (
                .WIDTH_DIN(DATA_IN_WIDTH)
            )
	    simple_adapter_inst (
                .clk        (clk),
                .rstn       (rstn),
                .din_vld    (din_vld),
                .din_last   (din_last),
                .din        (din),
                .dout_vld   (dout_vld),
		.dout_last  (dout_last),
                .dout       (dout)
            );
        end else begin
            simple_adapter # (
                .WIDTH_DIN(DATA_IN_WIDTH*(2**j))
            ) 
 	    simple_adapter_inst (
                .clk        (clk),
                .rstn       (rstn),
                .din_vld    (loop[j-1].dout_vld),
                .din_last   (loop[j-1].dout_last),
                .din        (loop[j-1].dout),
                .dout_vld   (dout_vld),
		.dout_last  (dout_last),
                .dout       (dout)
            );
        end
    end
endgenerate






task nop;
  input integer n;
  begin repeat(n)begin @(posedge clk) #0; end end
endtask
always@(posedge clk)begin
    random1b <= {$random}%100 < 20 ? 1:0;
end
always #5  clk = ! clk ;


task make_data;
integer i;
begin
    for (i = 0;i<BUFFERSIZE ;i=i+1 ) begin
        buff[i] = {$random};
    end
end
endtask


task run_data;
input integer len;
integer i;
begin
    for (i = 0;i<len ;i=i+1 ) begin
        din_vld_bad=1;
        din=buff[i];
	if(i==len-1)begin
            din_last = 1;
	end
        @(posedge clk) #0;
        while (random1b == 0) begin
            @(posedge clk) #0;
        end
        din_last = 0;
    end
    din_vld_bad<=0;
end
endtask

integer i;
initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0,simple_adapter_serial_tb );
    nop(2);
    rstn=1;
    nop(2);

    make_data();
    run_data(8);
    nop(20);
    make_data();
    run_data(32);

    nop(8);
    $finish;
end
endmodule
