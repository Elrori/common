// K9+/XI050CD Artix-7 xc7a50t-fgg484-1, AD9226 parallel ADC.
module sw_radio_top (
    input  wire        clk_25m,
    output wire        adc_clk_out,
    input  wire [11:0] adc_data,
    input  wire        adc_otr,
    output wire        ad8370_sclk,
    output wire        ad8370_mosi,
    output wire        ad8370_latch,
    input  wire        eth_rx_clk,
    input  wire [3:0]  eth_rx_data,
    input  wire        eth_rx_ctl,
    output wire        eth_tx_clk,
    output wire [3:0]  eth_tx_data,
    output wire        eth_tx_ctl,
    output wire        eth_mdc,
    inout  wire        eth_mdio,
    output wire        eth_rst_n
);
    wire adc_clk, ref_clk, clocks_locked;
    sw_clock_gen clocks(.clk25(clk_25m),.clk40(adc_clk),
        .clk200(ref_clk),.locked(clocks_locked));
    wire adc_rst=~clocks_locked;
    // This K9+ mezzanine has been verified with the forwarded clock in phase
    // with the internal capture clock.  The IOB then captures the preceding
    // AD9226 sample before the converter's next clock-to-data transition.
    ODDR #(.DDR_CLK_EDGE("SAME_EDGE"),.SRTYPE("SYNC")) clk_to_adc (
        .C(adc_clk),.CE(1'b1),.D1(1'b1),.D2(1'b0),
        .Q(adc_clk_out),.R(1'b0),.S(1'b0)
    );
    // This exact ADC mezzanine was proven by the EBAZ4205 design with its raw
    // 12-bit bus fed directly to signed DSP.  Its format strap is therefore
    // two's complement; flipping bit 11 here would create a half-scale
    // discontinuity at every zero crossing and destroy weak RF signals.
    // Keep the first capture register in the I/O cells.  At 40 MSPS this also
    // isolates the external bus from the DFE's wider routing fanout.
    (* IOB="TRUE" *) reg [11:0] adc_data_iob;
    (* IOB="TRUE" *) reg adc_otr_iob;
    always @(posedge adc_clk) begin
        adc_data_iob <= adc_data;
        adc_otr_iob <= adc_otr;
    end
    wire [11:0] adc_signed=adc_data_iob;

    // OTR is made sticky until reconfiguration so a short overload is not
    // hidden by UDP packet timing.  Synchronize the level into the PHY clock.
    reg adc_overrange_sticky;
    always @(posedge adc_clk) begin
        if (adc_rst) adc_overrange_sticky <= 1'b0;
        else if (adc_otr_iob) adc_overrange_sticky <= 1'b1;
    end

    wire eth_clk;
    // Asynchronous PHY clock deassertion synchronizer.
    (* ASYNC_REG="TRUE" *) reg [2:0] eth_reset_pipe=3'b111;
    always @(posedge eth_rx_clk or negedge clocks_locked) begin
        if (!clocks_locked) eth_reset_pipe<=3'b111;
        else eth_reset_pipe<={eth_reset_pipe[1:0],1'b0};
    end
    wire eth_rst=eth_reset_pipe[2];
    (* ASYNC_REG="TRUE" *) reg [1:0] overrange_sync;
    always @(posedge eth_rx_clk) begin
        if (eth_rst) overrange_sync <= 2'b00;
        else overrange_sync <= {overrange_sync[0],adc_overrange_sticky};
    end
    wire [31:0] tune_eth, fcw_eth;
    wire [7:0] gain_eth;
    wire tune_pulse_eth, gain_pulse_eth;
    sw_rgmii_control_rx control_rx (
        .phy_clk(eth_rx_clk),.idelay_refclk(ref_clk),
        .idelay_rst(adc_rst),.rst(eth_rst),
        .rgmii_rxd(eth_rx_data),.rgmii_rx_ctl(eth_rx_ctl),
        .clk(eth_clk),.tune_hz(tune_eth),
        .phase_increment(fcw_eth),.tune_pulse(tune_pulse_eth),
        .gain_value(gain_eth),.gain_pulse(gain_pulse_eth)
    );

    wire [31:0] fcw_adc;
    sw_control_cdc #(.WIDTH(32)) tune_cdc (
        .src_clk(eth_clk),.src_rst(eth_rst),
        .src_update(tune_pulse_eth),.src_value(fcw_eth),
        .dst_clk(adc_clk),.dst_rst(adc_rst),
        .dst_value(fcw_adc),.dst_pulse()
    );
    wire [7:0] gain_adc;
    wire gain_set;
    sw_control_cdc #(.WIDTH(8)) gain_cdc (
        .src_clk(eth_clk),.src_rst(eth_rst),
        .src_update(gain_pulse_eth),.src_value(gain_eth),
        .dst_clk(adc_clk),.dst_rst(adc_rst),
        .dst_value(gain_adc),.dst_pulse(gain_set)
    );

    wire [31:0] i_fir,q_fir;
    wire i_valid,q_valid;
    sys_sw_dfe_1mhz_nco14 dfe (
        .clk_adc(adc_clk),.rst_n(clocks_locked),
        .adc_dat(adc_signed),.phi_inc(fcw_adc),
        .sin_fir(i_fir),.cos_fir(q_fir),
        .sin_fir_vld(i_valid),.cos_fir_vld(q_valid)
    );

    wire [31:0] iq_word, dropped_samples;
    wire [11:0] fifo_words;
    wire fifo_empty, fifo_pop;
    // Correct two's-complement ADC data is about 30 dB below the previously
    // mis-decoded stream. SHIFT=5 uses the 16-bit transport range while the
    // measured 0x40 gain setting retains ample peak headroom.
    sw_iq_cdc #(.SHIFT(5)) iq_cdc (
        .wr_clk(adc_clk),.wr_rst(adc_rst),
        .sample_valid(i_valid && q_valid),
        .i_fir(i_fir),.q_fir(q_fir),
        .rd_clk(eth_clk),.rd_word(iq_word),
        .rd_en(fifo_pop),.rd_empty(fifo_empty),
        .rd_count(fifo_words),.dropped_samples(dropped_samples)
    );

    wire [7:0] payload_byte;
    wire payload_valid,payload_ready,payload_last;
    sw_udp_iq_tx pkt (
        .clk(eth_clk),.rst(eth_rst),
        .tuned_hz(tune_eth),.dropped_samples(dropped_samples),
        .adc_overrange(overrange_sync[1]),
        .fifo_word(iq_word),.fifo_empty(fifo_empty),
        .fifo_count(fifo_words),.fifo_rd_en(fifo_pop),
        .axis_data(payload_byte),.axis_valid(payload_valid),
        .axis_ready(payload_ready),.axis_last(payload_last),
        .packet_count()
    );
    wire [7:0] gmii_txd;
    wire gmii_tx_en, gmii_tx_er;
    axis_gmii_tx #(.ENABLE_PADDING(1),.MIN_FRAME_LENGTH(64)) mac (
        .clk(eth_clk),.rst(eth_rst),
        .s_axis_tdata(payload_byte),.s_axis_tvalid(payload_valid),
        .s_axis_tready(payload_ready),.s_axis_tlast(payload_last),
        .s_axis_tuser(1'b0),.gmii_txd(gmii_txd),
        .gmii_tx_en(gmii_tx_en),.gmii_tx_er(gmii_tx_er),
        .ptp_ts(96'b0),.m_axis_ptp_ts(),.m_axis_ptp_ts_tag(),
        .m_axis_ptp_ts_valid(),.clk_enable(1'b1),
        .mii_select(1'b0),.cfg_ifg(8'd12),.cfg_tx_enable(1'b1),
        .start_packet(),.error_underflow()
    );
    rgmii_tx phy_tx (
        .clk(eth_clk),.clk90(eth_clk),.tx_byte(gmii_txd),
        .tx_valid(gmii_tx_en),.rgmii_tx_clk(eth_tx_clk),
        .rgmii_txd(eth_tx_data),.rgmii_tx_ctl(eth_tx_ctl)
    );
    assign eth_rst_n=1'b1; // Keep PHY0 out of reset, as in verified K9+ build.
    assign eth_mdc=1'b0;
    assign eth_mdio=1'bz;

    // 0x40 leaves generous headroom on the connected bench setup. Live
    // antenna tests found 0xa0 clean, 0xc0 marginal and 0xe0 overrange; the
    // exact boundary remains input/environment dependent.
    // Subsequent control datagrams K9AG/gain may update the VGA while online.
    localparam [7:0] AD8370_BOOT_GAIN=8'h40;
    reg [11:0] boot_count;
    reg boot_written, spi_busy;
    reg spi_strobe;
    reg [7:0] spi_gain;
    wire spi_finished;
    always @(posedge adc_clk) begin
        if (adc_rst) begin
            boot_count<=0; boot_written<=0; spi_busy<=0;
            spi_strobe<=0; spi_gain<=AD8370_BOOT_GAIN;
        end else begin
            spi_strobe<=0;
            if (!boot_written) begin
                boot_count<=boot_count+1'b1;
                if (&boot_count && !spi_busy) begin
                    spi_strobe<=1;
                    spi_gain<=AD8370_BOOT_GAIN;
                    boot_written<=1;
                    spi_busy<=1;
                end
            end else if (spi_finished) spi_busy<=0;
            else if (gain_set && !spi_busy) begin
                spi_gain<=gain_adc;
                spi_strobe<=1;
                spi_busy<=1;
            end
        end
    end
    spi8370 #(.DIV(10)) ad8370 (
        .clk(adc_clk),.rst_n(clocks_locked),
        .wr_en(spi_strobe),.wr_dat(spi_gain),.wr_fin(spi_finished),
        .sclk(ad8370_sclk),.mosi(ad8370_mosi),.ltch(ad8370_latch)
    );
endmodule
