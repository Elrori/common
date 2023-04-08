/* 
*   Name  : data asynchronous bridge
*   Origin: 230404
*   EE    : hel
*/
module cdc_pulse_data #(
    parameter DW = 8
)(
    input   wire                s_clk   ,
    input   wire                s_rstn  ,
    input   wire    [DW-1:0]    s_din   ,
    input   wire                s_vld   , // pulse input 

    input   wire                d_clk   ,
    input   wire                d_rstn  ,
    output  reg     [DW-1:0]    d_dout  ,
    output  reg                 d_vld   ,// pulse output 

    output  wire                active   // do not give a s_din/s_vld when active is set high
);
reg [1   :0] s_syncer ;
reg [1   :0] d_syncer ;
wire         ack_d2 = s_syncer[1];
wire         req_d2 = d_syncer[1];    
reg          req_d3;
reg [DW-1:0] async_dat;
reg          async_req;
wire         async_ack = req_d2;
assign       active = async_req | ack_d2 ;
// Source clock domain
always @(posedge s_clk or negedge s_rstn) begin
    if (!s_rstn) begin
        s_syncer   <= 2'd0;
    end else begin
        s_syncer   <=  {s_syncer[0],async_ack};
    end
end
always @(posedge s_clk or negedge s_rstn) begin
    if (!s_rstn) begin
        async_dat   <= {DW{1'd0}};
    end else if(s_vld && (!active))begin
        async_dat   <=  s_din;
    end
end
always @(posedge s_clk or negedge s_rstn) begin
    if (!s_rstn) begin
        async_req   <= 1'd0;
    end else if(ack_d2)begin
        async_req   <= 1'd0;
    end else if(s_vld)begin
        async_req   <= 1'd1;
    end
end
// Destination clock domain
always @(posedge d_clk or negedge d_rstn) begin
    if (!d_rstn) begin
        d_syncer   <= 2'd0;
    end else begin
        d_syncer   <=  {d_syncer[0],async_req};
    end
end
always @(posedge d_clk or negedge d_rstn) begin
    if (!d_rstn) begin
        d_dout      <= {DW{1'd0}};
    end else if(req_d2)begin
        d_dout      <= async_dat;
    end 
end
always @(posedge d_clk or negedge d_rstn) begin
    if (!d_rstn) begin
        req_d3      <= 1'd0;
        d_vld       <= 1'd0;
    end else begin
        req_d3      <= req_d2;
        d_vld       <= req_d2 & (~req_d3);
    end 
end
endmodule
