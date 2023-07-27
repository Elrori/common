/*
*  Name         :fir_dec.v
*  Description  :FIR, caution: make sure CLOCK_PER_SAMPLE * R > N_COE+2
*  Origin       :200328
*               :230502
*  EE           :hel
*/
module dsp_fir_dec
#(
        parameter R                   = 2,           // Decimation factor
        parameter COE_FILE            = "coe.txt",   // coefficients, fill 0 that are not used
        parameter CLOCK_PER_SAMPLE    = 20,          // how many clocks, din comes to data once
        parameter W_DIN               = 16,         
        parameter W_DOUT              = 32,         
        parameter W_COE               = 16,         
        parameter M_DEEP              = 32,          // memory deep, 2**x
        parameter N_COE               = 31           // number of coefficients, should < M_DEEP
)
(   
    input   wire            clk     ,
    input   wire            rst_n   ,

    input   wire    [15:0]  din     ,
    input   wire            din_val ,

    output  reg     [31:0]  dout    ,
    output  reg             dout_val
);
generate
    if (CLOCK_PER_SAMPLE * R <= N_COE + 2) begin
        wire [1:0]error;
        wire parameter_error_please_check = error[2];
    end
endgenerate
//-----------------------------------------------------------------------------------------------
localparam WOUT  = W_DIN + (W_COE+$clog2(N_COE));//全精度
localparam WIDTHAD = $clog2(M_DEEP);
reg  [1        :0]  dec_cnt;
reg  [WIDTHAD-1:0]  wraddress;
reg  [WIDTHAD-1:0]  rdaddress;
reg  [WIDTHAD-1:0]  addr_a;
wire [W_DIN-1  :0]  q;
wire [W_DIN-1  :0]  q_a;
wire                fir_start = ((dec_cnt==R-1) && din_val);
reg  [2        :0]  st;
reg  signed  [15:0] multa;
reg  signed  [15:0] multb;
wire signed  [31:0] result;
reg  signed  [WOUT-1:0]result_b;
wire signed  [WOUT-1:0]sum;
assign result   = multa    * multb ;
assign sum      = result_b + result;
wire dout_val_  = (st==3);

// Round
localparam BOUT = WOUT;
localparam COUT = W_DOUT;
wire    carry_bit   =  sum[BOUT-1] ? ( sum[BOUT-(COUT-1)-1-1] & ( |sum[BOUT-(COUT-1)-1-1-1:0] ) ) : sum[BOUT-(COUT-1)-1-1] ;
wire[W_DOUT:0]dout_     = {sum[BOUT-1], sum[BOUT-1:BOUT-(COUT-1)-1]} + carry_bit ;
// Cut
//wire [31:0]dout_    = (sum>>(WOUT-32));
//-----------------------------------------------------------------------------------------------
initial begin
    $display("\n----------fir_dec----------\n");
    $display("W_DIN : %d bit",W_DIN);
    $display("W_DOUT: %d bit",W_DOUT);
    $display("W_COE : %d bit",W_COE);
    $display("N_COE : %d bit",N_COE);
    $display("WOUT  : %d bit\n",WOUT );
end
always@(posedge clk or negedge rst_n)begin
    if ( !rst_n ) begin
        wraddress <= 'd0;
        dec_cnt   <= 'd0;
    end else begin
        wraddress <= ( din_val      )?wraddress+1'd1 :wraddress;
        dec_cnt   <= (!din_val      )?dec_cnt        :
                     ( dec_cnt==R-1 )?'d0            :dec_cnt+1'd1;
    end
end
always@(posedge clk or negedge rst_n)begin
    if ( !rst_n ) begin
        dout_val    <= 'd0;
        dout        <= 'd0;
    end else begin
        dout_val    <= dout_val_;
        dout        <= (dout_val_)?dout_:dout;
    end
end
always@(posedge clk or negedge rst_n)begin
    if ( !rst_n ) begin
        st          <='d0;
        multa       <='d0;
        multb       <='d0;
        result_b    <='d0;
        rdaddress   <='d0;
        addr_a      <='d0;
    end else begin
        case(st)
            0:begin
                if (fir_start) begin
                    multa       <=  din;
                    multb       <=  q_a;
                    result_b    <=  'd0;
                    rdaddress   <=  wraddress - 1'd1;
                    addr_a      <=  addr_a    + 1'd1;
                    st          <=  st        + 1'd1;
                end
            end
            1:begin
                st          <=  st  + 1'd1;
                rdaddress   <=  rdaddress - 1'd1;
                addr_a      <=  addr_a    + 1'd1;
            end
            2:begin
                multa       <=  q;
                multb       <=  q_a;
                result_b    <=  sum;//result_b + multa*multb
                rdaddress   <=  rdaddress - 1'd1;
                if ( addr_a == N_COE ) begin
                    addr_a  <=  'd0;
                    st      <=  st        + 1'd1;
                end else begin
                    addr_a  <=  addr_a    + 1'd1;
                end
            end
            3:begin
                st <= 'd0;
            end
            default:st <= 'd0;
        endcase
    end
end
simple_ram #(
    .widthad    (WIDTHAD    ),
    .width      (W_DIN      )
)simple_ram_0(
    .clk        ( clk       ),
    .wraddress  ( wraddress ),
    .wren       ( din_val   ),
    .data       ( din       ),
    .rdaddress  ( rdaddress ),
    .q          ( q         )
);
simple_rom #(
    .widthad    (WIDTHAD    ),
    .width      (W_DIN      ),
    .datafile   (COE_FILE   )//31 coe
)simple_rom_0(
    .clk        ( clk       ),
    .addr_a     ( addr_a    ),
    .q_a        ( q_a       ),
    .addr_b     (           ),
    .q_b        (           )
);
endmodule
