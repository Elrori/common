/*
*  Av = wr_dat[6:0] × 0.055744 × (1 + (7.079458 − 1) × wr_dat[7])
*/
module spi8370 #(parameter DIV = 10)(
    input       wire        clk     ,
    input       wire        rst_n   ,

    input       wire        wr_en   ,
    input       wire [7:0]  wr_dat  ,
    output      reg         wr_fin  ,

    output      reg         sclk    ,
    output      wire        mosi    ,
    output      reg         ltch    
);
reg [9:0] cnt;
reg [7:0] dat;
reg [2:0] dnt;
reg       req;

wire      clr;
wire      hlf;
assign    clr = (cnt == DIV   - 1);
assign    hlf = (cnt == DIV/2 - 1);
assign    mosi= ltch==1'd0 ? dat[7-dnt] :1'd0;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sclk <=  1'd0;
    end else if (hlf) begin
        sclk <= 1'd1;
    end else if (clr) begin
        sclk <= 1'd0;
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt  <= 10'd0;
    end else if (clr) begin
        cnt  <= 10'd0;
    end else begin
        cnt  <= cnt  + 1'd1;
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        req <= 1'd0;
        dat <= 8'd0;
    end else if (wr_fin) begin
        req <= 1'd0;
    end else if(wr_en) begin
        req <= 1'd1;
        dat <= wr_dat;
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dnt     <= 3'd0;
        ltch    <= 1'd1;
        wr_fin  <= 1'd0;
    end else if(req && clr && (!wr_fin))begin
        if (&dnt) begin
            ltch    <= 1'd1;
            wr_fin  <= 1'd1;
            dnt     <= 3'd0;
        end else begin
            ltch    <= 1'd0;
            if(!ltch)
                dnt <= dnt + 1'd1;
        end
    end else if(wr_fin)begin
        wr_fin  <= 1'd0;
    end
end
endmodule
