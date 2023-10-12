`timescale 1ns/1ps
module simple_adapter_tb;

// Parameters
localparam  WIDTH_DIN = 8;

//Ports
reg  clk=0;
reg  rstn=0;
reg  din_vld_bad=0;
reg  random1b=0;
wire  din_vld=din_vld_bad&random1b;
reg  [WIDTH_DIN-1:0] din=0;

wire  dout_vld;
wire  [2*WIDTH_DIN-1:0] dout;


reg [WIDTH_DIN-1:0]buff[0:1023];
reg [2*WIDTH_DIN-1:0]buff_golden[0:511];
reg chk_en=0;
reg [31:0]chk_len=0;
reg [31:0]chk_len_=0;
simple_adapter # (
    .WIDTH_DIN(WIDTH_DIN)
)
simple_adapter_inst (
    .clk(clk),
    .rstn(rstn),
    .last_align(1'd0),
    .din_vld(din_vld),
    .din(din),
    .dout_vld(dout_vld),
    .dout(dout)
);

task nop;
  input integer n;
  begin repeat(n)begin @(posedge clk) #0; end end
endtask
always@(posedge clk)begin
    random1b <= {$random}%100 < 20 ? 1:0;
end
always #5  clk = ! clk ;

always@(posedge clk)begin : checker
    if(chk_en && chk_len==0)begin
        chk_len <= 1;
    end else if(chk_en && chk_len!=0 && dout_vld) begin
        if (chk_len==1) begin
            chk_en <= 0;
        end else begin
            chk_len <= chk_len - 1;
        end
        if(buff_golden[chk_len_-chk_len] != dout)begin
            $display("error occur buff_golden[%0d] != dout:%0d",chk_len_-chk_len,dout);
            $stop;
            $finish;
        end else begin
            $display("pass buff_golden[%0d]:%6d == dout:%6d",chk_len_-chk_len,buff_golden[chk_len_-chk_len],dout);
        end
    end
end

task make_data;
integer i;
begin
    for (i = 0;i<1024 ;i=i+1 ) begin
        buff[i] = {$random};
        if (i%2) begin
            buff_golden[i/2]={buff[i-1],buff[i]};
        end
    end
end
endtask

task print_data;
integer i;
begin
    for (i = 0;i<1024 ;i=i+1 ) begin
        $display("%4d 0x%x",i,buff[i]);
    end

    for (i = 0;i<1024/2 ;i=i+1 ) begin
        $display("%4d 0x%x",i,buff_golden[i]);
    end
end
endtask

task run_data;
input integer len;
integer i;
begin
    chk_en=1;
    chk_len=len/2;
    chk_len_=len/2;
    for (i = 0;i<len ;i=i+1 ) begin
        din_vld_bad=1;
        din=buff[i];
        @(posedge clk) #0;
        while (random1b == 0) begin
            @(posedge clk) #0;
        end
    end
    din_vld_bad<=0;
    @(posedge clk) #0;
    wait(chk_en==0);
    @(posedge clk) #0;
end
endtask

integer i;
initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0,simple_adapter_tb );
    nop(2);
    rstn=1;
    nop(2);

    make_data();
    run_data(1024);

    make_data();
    run_data(1024);

    make_data();
    run_data(1024);

    for (i = 0;i<100 ;i=i+1 ) begin
        make_data();
        run_data(1024);        
    end


    $display("PASS");
    nop(8);
    $finish;
end
endmodule