module mdio_if #(
    parameter DIV      = 1000
)(
    input   wire        clk,
    input   wire        rst,

    output  reg         mdc,
    output  reg         mdt, // mdio = mdt? mdo : 1'dz;
    output  reg         mdo,
    input   wire        mdi,

    input   wire        op_ena,
    input   wire        op_rdwr, // rd 0 wr 1
    input   wire  [4 :0]op_phya,
    input   wire  [4 :0]op_rega,
    input   wire  [15:0]op_din,
    output  reg   [15:0]op_dout,
    output  reg         op_done
);
reg [10:0]cnt0;
reg [6 :0]cnt1;
reg ckpp;
reg cknn;
reg op_ena_period;
reg [9 :0] op_add_buf;
reg [15:0] op_din_buf;
reg [1:0]mdi_d ;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cnt0    <= 'd0;
        ckpp <= 'd0;
        mdc  <= 1'd0;
    end else begin
        if (cnt0 >= DIV - 1) begin
            cnt0 <= 'd0;
        end else begin
            cnt0 <= cnt0 + 1'd1;
        end
        if (cnt0 == DIV - 1) begin
            ckpp <= 1'd1;
        end else begin
            ckpp <= 1'd0;
        end
        if (cnt0 == DIV/2 - 1) begin
            cknn <= 1'd1;
        end else begin
            cknn <= 1'd0;
        end
        if (ckpp) begin
            mdc <= 1'd1;
        end else if(cknn) begin
            mdc <= 1'd0;
        end
    end
end
always @(posedge clk or posedge rst) begin
    if (rst) begin
        op_ena_period   <= 1'd0;
        op_done         <= 1'd0;
        cnt1            <= 'd0;
    end else begin
        op_done <= (cknn && cnt1 == 65) ? 1'd1 : 1'd0;
        if (op_done) begin
            op_ena_period <= 1'd0;
        end else if(op_ena)begin
            op_ena_period <= 1'd1;
        end
        if (op_ena_period && cknn && cnt1 <= 65) begin
            cnt1 <= cnt1 + 1'd1;
        end else if(cnt1 == 66) begin
            cnt1 <= 'd0;
        end
    end
end
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mdt         <= 1'd0;
        mdo         <= 1'd0;
        op_add_buf  <=  'd0;
        op_din_buf  <=  'd0;
    end else if(cknn)begin
        if(cnt1 == 0)begin
            mdt <= 1'd0;
        end else if (cnt1 >= 1 && cnt1 <= 32) begin
            mdt <= 1'd1;
            mdo <= 1'd1;
        end else if(cnt1 == 33 || cnt1 == 34)begin
            mdt <= 1'd1;
            mdo <= ~cnt1[0];
        end else if(cnt1 == 35 || cnt1 == 36)begin
            mdt <= 1'd1;
            mdo <= op_rdwr ? ~cnt1[0] : cnt1[0] ;
            op_add_buf <= {op_phya,op_rega};
            op_din_buf <= op_rdwr ? op_din : 16'd0;
        end else if(cnt1 >= 37 && cnt1 <= 46)begin
            op_add_buf <= {op_add_buf,1'd0};
            mdo <= op_add_buf[9];
        end else if(cnt1 == 47 || cnt1 == 48)begin // TA
            mdt <= op_rdwr ? 1'd1    : 1'd0;
            mdo <= op_rdwr ? cnt1[0] : 1'd0;
        end else if(op_rdwr && cnt1 > 48 && cnt1 <= 64)begin // wr
            op_din_buf <= {op_din_buf,1'd0};
            mdo <= op_din_buf[15];
        end else begin
            mdt <= 1'd0;
        end
    end
end
always @(posedge clk or posedge rst) begin:read_data
    if (rst) begin
        op_dout <= 'd0;
        mdi_d   <= 'd0;
    end else begin
        mdi_d <= {mdi_d,mdi};
        if (cnt1 <= 65 && cnt1 >=50 && ckpp) begin
            op_dout <= {op_dout,mdi_d[1]};
        end else begin
            op_dout <= op_dout;
        end
    end
end
endmodule