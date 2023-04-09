/*
*   Name        :dsp_cic_dec
*   Description :cic decimator,two's complement input
*   Origin      :200317
*                200322
*   EE          :hel
*/
module dsp_cic_dec
#(
    parameter R     = 20,               // Decimation factor
    parameter M     = 1 ,               // Differential delay 1 or 2
    parameter N     = 5 ,               // Number of stages, refers to the order of one side
    parameter BIN   = 16,               // Input data width
    parameter COUT  = 16,               // Output dout_cut width
    parameter CUT_METHOD = "ROUND",     // ROUND or CUT
    parameter BOUT  = 38                // BOUT=BIN + $clog2((R*M)**N)
)
(
    input   wire            clk     ,   // 
    input   wire            rst_n   ,   // 
    input   wire [BIN-1 :0] din     ,   // Two's complement input
    output  wire [BOUT-1:0] dout    ,   // Full precision data output
    output  wire [COUT-1:0] dout_cut,   // Clipped data output
    output  wire            dvld        // 
);
generate
    if(CUT_METHOD=="ROUND")begin
        wire    carry_bit   =  dout[BOUT-1] ? ( dout[BOUT-(COUT-1)-1-1] & ( |dout[BOUT-(COUT-1)-1-1-1:0] ) ) : dout[BOUT-(COUT-1)-1-1] ;
        assign  dout_cut    = {dout[BOUT-1], dout[BOUT-1:BOUT-(COUT-1)-1]} + carry_bit ;
    end else if(CUT_METHOD=="CUT")begin
        assign  dout_cut    = (dout>>(BOUT-COUT));
    end
endgenerate
/*
*   Integrator
*/
generate
genvar i;
for ( i=0 ; i<N ; i=i+1 ) begin :LOOP
    reg  [BOUT-1:0]inte;
    wire [BOUT-1:0]sum;
    if ( i == 0 ) begin
        assign sum = inte + {{(BOUT-BIN){din[BIN-1]}},din};
    end else begin
        assign sum = inte + ( LOOP[i-1].sum );
    end
    always@(posedge clk or negedge rst_n)begin
        if ( !rst_n )
            inte <= {(BOUT){1'd0}};
        else
            inte <= sum;
    end    
end
endgenerate
wire [BOUT-1:0]inte_out;
assign inte_out=LOOP[N-1].sum;
/*
*   Decimation
*/
reg [$clog2(R)-1:0]cnt0;
reg [BOUT-1:0]dec_out;
assign dvld = (cnt0==(R-1));
always@(posedge clk or negedge rst_n)begin
    if ( !rst_n ) begin
        cnt0    <=  'd0;
        dec_out <=  'd0;
    end else begin
        cnt0    <=  dvld?'d0        :cnt0 + 1'd1;
        dec_out <=  dvld?inte_out   :dec_out;
    end
end

/*
*   Comb
*/
generate
genvar j;
for ( j=0 ; j<N ; j=j+1 ) begin :LOOP2
    reg  [BOUT-1:0]comb;
    wire [BOUT-1:0]sub;

    if ( j == 0 ) begin
        if(M==1)begin
            assign sub = dec_out - comb;
            always@(posedge clk or negedge rst_n)begin
                if ( !rst_n )
                    comb <= {(BOUT){1'd0}};
                else 
                    comb <= (dvld) ? dec_out : comb;
            end  
        end else begin
            reg  [BOUT-1:0]comb1;
            assign sub = dec_out - comb1;
            always@(posedge clk or negedge rst_n)begin
                if ( !rst_n )begin
                    comb <= {(BOUT){1'd0}};
                    comb1<= {(BOUT){1'd0}};
                end else if(dvld)begin
                    comb <= dec_out ;
                    comb1<= comb    ;
                end
            end  
        end


    end else begin
        if(M==1)begin
            assign sub = LOOP2[j-1].sub - comb;
            always@(posedge clk or negedge rst_n)begin
                if ( !rst_n )
                    comb <= {(BOUT){1'd0}};
                else
                    comb <= (dvld) ? LOOP2[j-1].sub : comb;
            end  
        end else begin
            reg  [BOUT-1:0]comb1;
            assign sub = LOOP2[j-1].sub - comb1;
            always@(posedge clk or negedge rst_n)begin
                if ( !rst_n )begin
                    comb <= {(BOUT){1'd0}};
                    comb1<= {(BOUT){1'd0}};
                end else if(dvld)begin
                    comb <=  LOOP2[j-1].sub;
                    comb1<=  comb;
                end
            end  

        end
    end
end
endgenerate
assign dout = LOOP2[N-1].sub;
endmodule
