module pmod_ad1 (
  input CLK_i,
  output logic AD7476_CS_o,
  output logic AD7476_SCLK_o,
  input AD7476_SDATA0_i,
  input AD7476_SDATA1_i,
  output logic [15:0] ADC_DATA0_o,
  output logic [15:0] ADC_DATA1_o,
  output logic ADC_VALID_o,
  //AXI4-Stream Interface
  output logic [15:0] AXIS_TDATA_o,
  output [1:0] AXIS_TKEEP_o,
  output logic AXIS_TLAST_o,
  input AXIS_TREADY_i,
  output logic AXIS_TVALID_o,
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

logic [7:0] adc_state = 0;
logic [15:0] adc_startup = 0;
logic adc_cs = 1;
logic adc_sclk = 1;
logic adc_sdata0 = 0;
logic adc_sdata1 = 0;
logic [15:0] adc_sdata0_reg = 0;
logic [15:0] adc_sdata1_reg = 0;
logic [15:0] adc_data0 = 0;
logic [15:0] adc_data1 = 0;
logic adc_valid = 0;
integer adc_bit_index = 0;
logic [7:0] adc_wait = 0;

logic adc_valid_reg1 = 0;
logic adc_valid_reg2 = 0;
logic [3:0] capture_state = 0;
logic capture_start;
logic [15:0] capture_size = 0;

//AXI4-Lite Interface
pmod_ad1_v1_0_axi_slave regif (
  .S_AXI_ACLK      (AXI_ACLK_i),
  .S_AXI_ARESETN   (AXI_ARESETN_i),
  .S_AXI_AWADDR    (AXI_AWADDR_i),
  .S_AXI_AWPROT    (3'b000),
  .S_AXI_AWVALID   (AXI_AWVALID_i),
  .S_AXI_AWREADY   (AXI_AWREADY_o),
  .S_AXI_WDATA     (AXI_WDATA_i),
  .S_AXI_WSTRB     (AXI_WSTRB_i),
  .S_AXI_WVALID    (AXI_WVALID_i),
  .S_AXI_WREADY    (AXI_WREADY_o),
  .S_AXI_BRESP     (AXI_BRESP_o),
  .S_AXI_BVALID    (AXI_BVALID_o),
  .S_AXI_BREADY    (AXI_BREADY_i),
  .S_AXI_ARADDR    (AXI_ARADDR_i),
  .S_AXI_ARPROT    (3'b000),
  .S_AXI_ARVALID   (AXI_ARVALID_i),
  .S_AXI_ARREADY   (AXI_ARREADY_o),
  .S_AXI_RDATA     (AXI_RDATA_o),
  .S_AXI_RRESP     (AXI_RRESP_o),
  .S_AXI_RVALID    (AXI_RVALID_o),
  .S_AXI_RREADY    (AXI_RREADY_i),
  .ADC0_i          ({4'h0, adc_data0[11:0]}),
  .ADC1_i          ({4'h0, adc_data1[11:0]}),
  .CAPTURE_START_o (capture_start)
);

assign ADC_DATA0_o = {4'h0, adc_data0[11:0]};
assign ADC_DATA1_o = {4'h0, adc_data1[11:0]};
assign ADC_VALID_o = adc_valid;

//AXI4-Stream Interface
assign AXIS_TKEEP_o = 2'b11;
always @ (posedge CLK_i)
begin
  AXIS_TDATA_o <= {4'h0, adc_data0[11:0]};
  AXIS_TVALID_o <= 0;
  AXIS_TLAST_o <= 0;
  adc_valid_reg1 <= adc_valid;
  adc_valid_reg2 <= adc_valid_reg1;
  case (capture_state)
    4'h0 :
      begin
        capture_size <= 0;
        if (capture_start & adc_valid_reg2)
          capture_state <= capture_state + 1;
      end
    4'h1 :
      begin
        AXIS_TVALID_o <= adc_valid_reg1 | adc_valid_reg2;
	    if (adc_valid)
            capture_size <= capture_size + 1;
        if (capture_size == 16'h400)
          begin
            capture_state <= capture_state + 1;
            AXIS_TLAST_o <= 1;
          end
      end
    4'h2 :
      begin
        AXIS_TVALID_o <= 1;
        AXIS_TLAST_o <= 1;
        capture_state <= capture_state + 1;
      end
    4'h3 :
      begin
        if (capture_start == 0)
          capture_state <= 0;
      end
  endcase
end

//ADC Interface
always @ (posedge CLK_i)
begin
  //pipeline in order to ensure use of IO registers
  AD7476_CS_o <= adc_cs;
  AD7476_SCLK_o <= adc_sclk;
  adc_sdata0 <= AD7476_SDATA0_i;
  adc_sdata1 <= AD7476_SDATA1_i;

  adc_cs <= 1;
  adc_sclk <= 1;
  adc_valid <= 0;
  case (adc_state)
    8'h00 :
      begin
        adc_startup <= adc_startup + 1;
        if (adc_startup == 16'h00C8)
          adc_state <= adc_state + 1;
      end
    8'h01, 8'h02 :
      begin
        adc_bit_index <= 15;
        adc_state <= adc_state + 1;
      end
    8'h03, 8'h04, 8'h05, 8'h06, 8'h07 :
      begin
        adc_cs <= 0;
        adc_state <= adc_state + 1;
      end
    8'h08, 8'h09, 8'h0A, 8'h0B, 8'h0C :
      begin
        adc_cs <= 0;
        adc_sclk <= 0;
        adc_state <= adc_state + 1;
        if (adc_state == 8'h08)
          begin
            adc_sdata0_reg[adc_bit_index] <= adc_sdata0;
            adc_sdata1_reg[adc_bit_index] <= adc_sdata1;
          end
        if (adc_state == 8'h0C)
          begin
            adc_bit_index <= adc_bit_index - 1;
            if (adc_bit_index == 0)
              begin
                adc_data0 <= adc_sdata0_reg;
                adc_data1 <= adc_sdata1_reg;
                adc_valid <= 1;
                adc_state <= 8'h0D;
              end
            else
              adc_state <= 8'h03;
          end
      end
    8'h0D :
      begin
        adc_wait <= adc_wait + 1;
        if (adc_wait == 8'h25)
          begin
            adc_wait <= 0;
            adc_state <= 8'h01;
          end
      end
  endcase
end

endmodule
