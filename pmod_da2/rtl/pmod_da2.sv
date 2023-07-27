module pmod_da2 (
  input CLK_i,
  output logic DAC121S101_SCLK_o,
  output logic DAC121S101_SYNC_o,
  output logic DAC121S101_DIN0_o,
  output logic DAC121S101_DIN1_o,
  input logic [15:0] DAC_DATA0_i,
  input logic [15:0] DAC_DATA1_i,
  //AXI4-Lite Interface
  input AXI_ACLK_i,
  input AXI_ARESETN_i,
  input [31:0] AXI_ARADDR_i,
  output AXI_ARREADY_o,
  input AXI_ARVALID_i,
  input [31:0] AXI_AWADDR_i,
  output AXI_AWREADY_o,
  input AXI_AWVALID_i,
  input AXI_BREADY_i,
  output [1:0] AXI_BRESP_o,
  output AXI_BVALID_o,
  output [31:0] AXI_RDATA_o,
  input AXI_RREADY_i,
  output [1:0] AXI_RRESP_o,
  output AXI_RVALID_o,
  input [31:0] AXI_WDATA_i,
  output AXI_WREADY_o,
  input [3:0] AXI_WSTRB_i,
  input AXI_WVALID_i
);

logic dds_enable = 0;
logic [7:0] dds_counter = 0;
logic [15:0] dds0_pinc;
logic [15:0] dds1_pinc;
logic dds_valid;
logic [15:0] dds0_data;
logic [15:0] dds1_data;
logic [15:0] dds0_gain;
logic [15:0] dds1_gain;
logic [31:0] dds0_scaled_data;
logic [31:0] dds1_scaled_data;

logic [11:0] prbs_data = 1;

logic [7:0] dac_state = 0;
logic [15:0] dac_startup = 0;
logic [1:0] dac0_mux;
logic [1:0] dac1_mux;
logic [15:0] dac_data0_constant;
logic [15:0] dac_data1_constant;
logic dac_sclk = 0;
logic dac_sync = 0;
logic dac_din0 = 0;
logic dac_din1 = 0;
logic [15:0] dac_data0 = 0;
logic [15:0] dac_data1 = 0;
integer dac_bit_index = 0;
logic [7:0] dac_wait = 0;

//AXI4-Lite Interface
pmod_da2_v1_0_axi_slave regif (
  .S_AXI_ACLK    (AXI_ACLK_i),
  .S_AXI_ARESETN (AXI_ARESETN_i),
  .S_AXI_AWADDR  (AXI_AWADDR_i),
  .S_AXI_AWPROT  (3'b000),
  .S_AXI_AWVALID (AXI_AWVALID_i),
  .S_AXI_AWREADY (AXI_AWREADY_o),
  .S_AXI_WDATA   (AXI_WDATA_i),
  .S_AXI_WSTRB   (AXI_WSTRB_i),
  .S_AXI_WVALID  (AXI_WVALID_i),
  .S_AXI_WREADY  (AXI_WREADY_o),
  .S_AXI_BRESP   (AXI_BRESP_o),
  .S_AXI_BVALID  (AXI_BVALID_o),
  .S_AXI_BREADY  (AXI_BREADY_i),
  .S_AXI_ARADDR  (AXI_ARADDR_i),
  .S_AXI_ARPROT  (3'b000),
  .S_AXI_ARVALID (AXI_ARVALID_i),
  .S_AXI_ARREADY (AXI_ARREADY_o),
  .S_AXI_RDATA   (AXI_RDATA_o),
  .S_AXI_RRESP   (AXI_RRESP_o),
  .S_AXI_RVALID  (AXI_RVALID_o),
  .S_AXI_RREADY  (AXI_RREADY_i),
  .DAC0_o        (dac_data0_constant),
  .DAC1_o        (dac_data1_constant),
  .DAC0_MUX_o    (dac0_mux),
  .DAC1_MUX_o    (dac1_mux),
  .DDS0_PINC_o   (dds0_pinc),
  .DDS1_PINC_o   (dds1_pinc),
  .DDS0_GAIN_o   (dds0_gain),
  .DDS1_GAIN_o   (dds1_gain)
);

//DDS
//Fout = 1MHz * dds_pinc / 2^16
pmod_da2_dds dds0 (
  .aclk                 (CLK_i),
  .aclken               (dds_enable),
  .s_axis_config_tvalid (1'b1),
  .s_axis_config_tdata  (dds0_pinc),
  .m_axis_data_tvalid   (dds_valid),
  .m_axis_data_tdata    (dds0_data),
  .m_axis_phase_tvalid  (),
  .m_axis_phase_tdata   ()
);

pmod_da2_dds dds1 (
  .aclk                 (CLK_i),
  .aclken               (dds_enable),
  .s_axis_config_tvalid (1'b1),
  .s_axis_config_tdata  (dds1_pinc),
  .m_axis_data_tvalid   (),
  .m_axis_data_tdata    (dds1_data),
  .m_axis_phase_tvalid  (),
  .m_axis_phase_tdata   ()
);

always @ (posedge CLK_i)
begin
  dds_counter <= dds_counter + 1;
  dds_enable <= 0;
  if (dds_counter == 8'hC7)
    begin
      dds_enable <= 1;
      dds_counter <= 0;
      dds0_scaled_data <= $signed(dds0_data) * $signed(dds0_gain); // S16.0 * S2.14 = S18.14
      dds1_scaled_data <= $signed(dds1_data) * $signed(dds1_gain); // S16.0 * S2.14 = S18.14
      prbs_data[11:1] <= prbs_data[10:0];
      prbs_data[0] <= prbs_data[11] ^ prbs_data[10] ^ prbs_data[9] ^ prbs_data[3] ^ prbs_data[0];
    end
end

//DAC Interface
always @ (posedge CLK_i)
begin
  //pipeline in order to ensure use of IO registers
  DAC121S101_SCLK_o <= dac_sclk;
  DAC121S101_SYNC_o <= dac_sync;
  DAC121S101_DIN0_o <= dac_din0;
  DAC121S101_DIN1_o <= dac_din1;

  dac_sync <= 0;
  case (dac_state)
    8'h00 :
      begin
        dac_startup <= dac_startup + 1;
        if (dac_startup == 16'h1F40)
          dac_state <= dac_state + 1;
      end
    8'h01, 8'h02, 8'h03, 8'h04 :
      begin
        dac_sync <= 1;
        case (dac0_mux)
          2'b00 :
            begin
              dac_data0[15:12] <= 0;
              dac_data0[11] <= ~dds0_scaled_data[29]; //convert to offset binary
              dac_data0[10:0] <= dds0_scaled_data[28:18];
            end
          2'b01 :
            begin
              dac_data0 <= dac_data0_constant;
            end
          2'b10 :
            begin
              dac_data0 <= DAC_DATA0_i;
            end
          2'b11 :
            begin
              dac_data0[15:12] <= 4'h0;
              dac_data0[11:0] <= prbs_data;
            end
        endcase
        case (dac1_mux)
          2'b00 :
            begin
              dac_data1[15:12] <= 0;
              dac_data1[11] <= ~dds1_scaled_data[29]; //convert to offset binary
              dac_data1[10:0] <= dds1_scaled_data[28:18];
            end
          2'b01 :
            begin
              dac_data1 <= dac_data1_constant;
            end
          2'b10 :
            begin
              dac_data1 <= DAC_DATA1_i;
            end
          2'b11 :
            begin
              dac_data1[15:12] <= 4'h0;
              dac_data1[11:0] <= prbs_data;
            end
        endcase
        dac_bit_index <= 15;
        dac_state <= dac_state + 1;
      end
    8'h05, 8'h06, 8'h07, 8'h08, 8'h09 :
      begin
        dac_sclk <= 1;
        dac_din0 <= dac_data0[dac_bit_index];
        dac_din1 <= dac_data1[dac_bit_index];
        dac_state <= dac_state + 1;
      end
    8'h0A, 8'h0B, 8'h0C, 8'h0D, 8'h0E :
      begin
        dac_sclk <= 0;
        dac_state <= dac_state + 1;
        if (dac_state == 8'h0E)
          begin
            dac_bit_index <= dac_bit_index - 1;
            if (dac_bit_index == 0)
              dac_state <= 8'h0F;
            else
              dac_state <= 8'h05;
          end
      end
    8'h0F :
      begin
        dac_wait <= dac_wait + 1;
        if (dac_wait == 8'h23)
          begin
            dac_wait <= 0;
            dac_state <= 8'h01;
          end
      end
  endcase
end

endmodule
