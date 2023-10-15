`timescale  1ns / 1ps

module simple_axis_fifo_tb;

// simple_axis_fifo Parameters
parameter PERIOD          = 10 ;

parameter DATA_IN_WIDTH   = 16 ;
parameter DATA_OUT_WIDTH  = 128;
parameter ADDR_WIDTH      = 3  ;// 8 *128 bits
parameter FRAME_MODE      = 1  ;
parameter FULL_SLACK      = 1  ;

parameter DIV      = DATA_OUT_WIDTH/DATA_IN_WIDTH  ;
// simple_axis_fifo Inputs
reg   clk                                  = 0 ;
reg   rst                                  = 1 ;
reg   [DATA_IN_WIDTH-1:0]     s_axis_tdata = 0 ;
reg   s_axis_tlast                         = 0 ;
reg   [DATA_IN_WIDTH/8-1:0]   s_axis_tkeep = 0 ;
reg   s_axis_tvalid                        = 0 ;
reg   m_axis_tready                        = 0 ;

// simple_axis_fifo Outputs
wire  s_axis_tready                        ;
wire  [DATA_OUT_WIDTH-1:0]    m_axis_tdata ;
wire  m_axis_tlast                         ;
wire  [DATA_OUT_WIDTH/8-1:0]  m_axis_tkeep ;
wire  m_axis_tvalid                        ;

integer  i;

reg random1b=0;
always @(posedge clk) begin
     random1b <= {$random}%100 < 80 ?1:0;
end
initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial
begin
    #(PERIOD*2) rst  =  0;
end

task nop;
    input integer n;
    begin repeat(n)begin @(posedge clk) #0; end end
endtask

task push;
    input [DATA_IN_WIDTH-1:0]dat;
    begin
        s_axis_tvalid = 1;
        s_axis_tdata  = dat;
        @(posedge clk) #0;
        while(s_axis_tready==0)begin
            @(posedge clk) #0;
        end
        s_axis_tvalid  = 0;
    end
endtask
task pop;
    output [DATA_OUT_WIDTH-1:0]dat;
    begin
        m_axis_tready = 1;
        @(posedge clk)#0;
        m_axis_tready = 0;
	    dat    = m_axis_tdata;
    end
endtask
task push_frame;
    input integer len;
    begin
        for(i=0;i<len;i=i+1)begin
            if(i==len-1)begin
                s_axis_tlast=1;
	        end
            push(i);
            s_axis_tlast=0;
        end
    end
endtask
task pop_frame;
    input integer len;
    integer ret;
    begin
        for(i=0;i<len;i=i+1)begin
            pop(ret);
        end
    end
endtask
simple_axis_fifo #(
    .DATA_IN_WIDTH  ( DATA_IN_WIDTH  ),
    .DATA_OUT_WIDTH ( DATA_OUT_WIDTH ),
    .ADDR_WIDTH     ( ADDR_WIDTH     ),// output side fifo deep, 2**ADDR_WIDTH
    .FULL_SLACK     ( FULL_SLACK     ),
    .FRAME_MODE     ( FRAME_MODE     ))
 u_simple_axis_fifo (
    .clk                                       ( clk                                        ),
    .rst                                       ( rst                                        ),
    .s_axis_tdata  ( s_axis_tdata   ),
    .s_axis_tlast                              ( s_axis_tlast                               ),
    .s_axis_tvalid                             ( s_axis_tvalid                              ),
    .s_axis_tready                             ( s_axis_tready                              ),

    .m_axis_tready                             ( random1b                              ),
    .m_axis_tdata  ( m_axis_tdata   ),
    .m_axis_tlast                              ( m_axis_tlast                               ),
    .m_axis_tvalid                             ( m_axis_tvalid                              )
);

initial
begin
    $dumpfile("wave.vcd");
    $dumpvars(0,simple_axis_fifo_tb );
    nop(5);

    push_frame(64);

    push_frame(56);

    push_frame(48);

    push_frame(40);

    push_frame(32);

    push_frame(24);

    push_frame(16);

    push_frame(8);

    push_frame(512);

    push_frame(48);

    nop(50);
    $finish;
end

endmodule