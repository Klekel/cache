module top
import cache_pkg::*;
(
  input  logic                     aclk_i,
  input  logic                     arstn_i,
// AXI MASTER INTERFACE
  input  logic                     m_awready_i,
  output logic                     m_awvalid_o,
  output logic [ADDR_WIDTH-1 :0]   m_awaddr_o,
  output logic [2            :0]   m_awprot_o,

  input  logic                     m_wready_i,
  output logic                     m_wvalid_o,
  output logic [DATA_WIDTH-1 :0]   m_wdata_o,
  output logic [DATA_BYTES-1 :0]   m_wstrb_o,

  input  logic                     m_bvalid_i,
  input  logic [1            :0]   m_bresp_i,
  output logic                     m_bready_o,

  input  logic                     m_arready_i,
  output logic                     m_arvalid_o,
  output logic [ADDR_WIDTH-1 :0]   m_araddr_o,
  output logic [2            :0]   m_arprot_o,

  input  logic                     m_rvalid_i,
  input  logic [DATA_WIDTH-1 :0]   m_rdata_i,
  input  logic [1            :0]   m_rresp_i,
  output logic                     m_rready_o,
// AXI SLAVE INTERFACE
  output logic                     s_awready_o,
  input  logic                     s_awvalid_i,
  input  logic [ADDR_WIDTH-1 :0]   s_awaddr_i,
  input  logic [2            :0]   s_awprot_i,

  output logic                     s_wready_o,
  input  logic                     s_wvalid_i,
  input  logic [DATA_WIDTH-1 :0]   s_wdata_i,
  input  logic [DATA_BYTES-1 :0]   s_wstrb_i,

  output logic                     s_bvalid_o,
  output logic [1            :0]   s_bresp_o,
  input  logic                     s_bready_i,

  output logic                     s_arready_o,
  input  logic                     s_arvalid_i,
  input  logic [ADDR_WIDTH-1 :0]   s_araddr_i,
  input  logic [2            :0]   s_arprot_i,

  output logic                     s_rvalid_o,
  output logic [DATA_WIDTH-1 :0]   s_rdata_o,
  output logic [1            :0]   s_rresp_o,
  input  logic                     s_rready_i,

  input  logic [DATA_WIDTH-1 :0]   cache_data_i,
  output logic [ADDR_WIDTH-1 :0]   cache_addr_o,
  output logic                     cache_we_o,
  output logic                     cache_en_o,
  output logic [DATA_WIDTH-1 :0]   cache_data_o,

  input  logic [MATRIX_WIDTH-1 :0] lru_data_i,
  output logic [SET_ANY-1      :0] lru_addr_o,
  output logic                     lru_we_o,
  output logic                     lru_en_o,
  output logic [MATRIX_WIDTH-1 :0] lru_data_o

);

  logic [FIFO_WIDTH-1  :0]   s_data_pkt;
  logic                      s_valid_pkt;
  logic                      s_cpu_ready;
  logic [DATA_WIDTH-1    :0] s_wb_data;
  logic [DATA_WIDTH-1    :0] s_cache_data;
  logic                      s_cache_valid;
  logic [DATA_WIDTH-1    :0] m_mem_data;
  logic [DATA_WIDTH-1    :0] m_wb_data;
  logic [ADDR_WIDTH-1    :0] m_wb_addr;

  logic                      sm_valid_addr;
  logic                      sm_valid_cache;
  logic [ADDR_WIDTH-1    :0] sm_addr;
  logic [FIFO_WIDTH_EX-1 :0] transaction_data;
  logic                      sm_ready;
  logic                      sm_prehit;
  logic                      sm_wb_hit;
  logic                      m_addr_ready;
  logic [DATA_WIDTH-1  :0]   sm_wb_data;

  logic                      arstn;

  rst_sync i_rst_sync(
    .aclk_i       ( aclk_i  ),
    .arstn_i      ( arstn_i ),
    .arstn_sync_o ( arstn   )
  );

  axi_4_lite_master i_master(
    .aclk_i       ( aclk_i           ),
    .arstn_i      ( arstn            ),

    .awready_i    ( m_awready_i      ),
    .awvalid_o    ( m_awvalid_o      ),
    .awaddr_o     ( m_awaddr_o       ),
    .awprot_o     ( m_awprot_o       ),

    .wready_i     ( m_wready_i       ),
    .wvalid_o     ( m_wvalid_o       ),
    .wdata_o      ( m_wdata_o        ),
    .wstrb_o      ( m_wstrb_o        ),

    .bvalid_i     ( m_bvalid_i       ),
    .bresp_i      ( m_bresp_i        ),
    .bready_o     ( m_bready_o       ),

    .arready_i    ( m_arready_i      ),
    .arvalid_o    ( m_arvalid_o      ),
    .araddr_o     ( m_araddr_o       ),
    .arprot_o     ( m_arprot_o       ),

    .rvalid_i     ( m_rvalid_i       ),
    .rdata_i      ( m_rdata_i        ),
    .rresp_i      ( m_rresp_i        ),
    .rready_o     ( m_rready_o       ),
// данные для записи в память
    .wb_valid_i   ( m_wb_valid       ),
    .wb_data_i    ( m_wb_data        ),
    .wb_addr_i    ( m_wb_addr        ),
    .mem_ready_o  ( m_mem_ready_out  ),
// данные прочитанные по адресу
    .mem_data_o   ( m_mem_data       ),
    .mem_valid_o  ( m_mem_valid      ),
    .mem_ready_i  ( m_mem_ready_in   ),
// адрес с фифо
    .addr_req_i   ( sm_valid_addr    ),
    .addr_ready_o ( m_addr_ready     ),
    .addr_i       ( sm_addr          )
  );

  axi_4_lite_slave i_slave(
    .aclk_i        ( aclk_i        ),
    .arstn_i       ( arstn         ),

    .awready_o     ( s_awready_o   ),
    .awvalid_i     ( s_awvalid_i   ),
    .awaddr_i      ( s_awaddr_i    ),
    .awprot_i      ( 3'b101        ),

    .wready_o      ( s_wready_o    ),
    .wvalid_i      ( s_wvalid_i    ),
    .wdata_i       ( s_wdata_i     ),
    .wstrb_i       ( s_wstrb_i     ),

    .bvalid_o      ( s_bvalid_o    ),
    .bresp_o       ( s_bresp_o     ),
    .bready_i      ( s_bready_i    ),

    .arready_o     ( s_arready_o   ),
    .arvalid_i     ( s_arvalid_i   ),
    .araddr_i      ( s_araddr_i    ),
    .arprot_i      ( s_arprot_i    ),

    .rvalid_o      ( s_rvalid_o    ),
    .rdata_o       ( s_rdata_o     ),
    .rresp_o       ( s_rresp_o     ),
    .rready_i      ( s_rready_i    ),

    .data_pkt_o    ( s_data_pkt    ),
    .valid_pkt_o   ( s_valid_pkt   ),
    .ready_pkt_i   ( s_ready_pkt   ),

    .cpu_ready_o   ( s_cpu_ready   ),
    .cache_data_i  ( s_cache_data  ),
    .cache_valid_i ( s_cache_valid )
  );

  logic                  pre_hit;
  logic                  cache_ready;
  logic [ADDR_WIDTH-1:0] pre_addr;
  logic [DATA_WIDTH-1:0] cache_data;
  logic [ADDR_WIDTH-1:0] cache_addr;
  logic [DATA_BYTES-1:0] cache_strb;
  logic                  cache_we;
  logic                  cache_hit;

  logic                  clr;
  logic                  pre_hit_o;

  logic [DATA_WIDTH-1:0] r_data;
  logic [ADDR_WIDTH-1:0] wr_addr;
  logic [DATA_WIDTH-1:0] wr_data;
  logic                  dirty;
  logic                  wb_ready;
  logic                  stall;
  logic [ADDR_WIDTH-1:0] wb_addr;

  logic [TECH_ADDR_WIDTH-1:0] tech_data_addr;
  logic                       tech_data_we;
  logic [DATA_WIDTH-1     :0] tech_data_in;
  logic [DATA_WIDTH-1     :0] tech_data_out;

  logic [MATRIX_WIDTH-1 :0]   matrix_vec;
  logic [SET_BITS-1     :0]   matrix_addr;
  logic                       write_vec;
  logic [MATRIX_WIDTH-1 :0]   updated_matrix_vec;

  assign pre_addr        = s_data_pkt[FIFO_WIDTH-1 -: ADDR_WIDTH];

  cache i_cache(
    .aclk_i               ( aclk_i              ),
    .arstn_i              ( arstn               ),

    .valid_s_i            ( sm_valid_cache      ),
    .transaction_data_i   ( transaction_data    ),
    .cache2cpu_ready_o    ( sm_ready            ),

    .valid_m_i            ( m_mem_valid         ),
    .mem_data_i           ( m_mem_data          ),
    .cache2mem_ready_o    ( m_mem_ready_in      ),

    .valid_o              ( s_cache_valid       ),
    .data_o               ( s_cache_data        ),
    .cpu2cache_ready_i    ( s_cpu_ready         ),

    .wb_ready_i           ( wb_ready            ),
    .dirty_o              ( dirty               ),
    .wb_addr_o            ( wr_addr             ),

    .pre_addr_i           ( pre_addr            ),
    .pre_hit_o            ( sm_prehit           ),

    .tech_data_addr_o     ( tech_data_addr      ),
    .tech_data_we_o       ( tech_data_we        ),
    .tech_data_i          ( tech_data_out       ),
    .tech_data_o          ( tech_data_in        ),

    .matrix_vec_i         ( matrix_vec          ),
    .matrix_addr_o        ( matrix_addr         ),
    .write_vec_o          ( write_vec           ),
    .updated_matrix_vec_o ( updated_matrix_vec  )
  );

  assign wb_addr = s_data_pkt[FIFO_WIDTH-1 -: ADDR_WIDTH];

  write_back_buffer i_wb_buf(
    .clk_i       ( aclk_i          ),
    .rstn_i      ( arstn           ),

    .r_addr_i    ( wb_addr         ),
    .clr_valid_i ( clr             ),
    .wb_hit_o    ( sm_wb_hit       ),
    .r_data_o    ( sm_wb_data      ),
    .wr_addr_i   ( wr_addr         ),
    .wr_data_i   ( s_cache_data    ),
    .dirty_i     ( dirty           ),
    .wb_ready_o  ( wb_ready        ),

    .ready_i     ( m_mem_ready_out ),
    .valid_o     ( m_wb_valid      ),
    .addr_o      ( m_wb_addr       ),
    .data_o      ( m_wb_data       )
  );

  main_fsm i_main_fsm(
    .aclk_i              ( aclk_i           ),
    .arstn_i             ( arstn            ),

    .data_pkt_i          ( s_data_pkt       ),
    .valid_pkt_i         ( s_valid_pkt      ),
    .ready_pkt_o         ( s_ready_pkt      ),

    .addr_req_o          ( sm_valid_addr    ),
    .addr_o              ( sm_addr          ),
    .addr_ready_i        ( m_addr_ready     ),

    .valid_s_o           ( sm_valid_cache   ),
    .transaction_data_o  ( transaction_data ),
    .cache2cpu_ready_i   ( sm_ready         ),
    .pre_hit_i           ( sm_prehit        ),
    .clr_valid_o         ( clr              ),
    .wb_hit_i            ( sm_wb_hit        ),
    .wb_r_data_i         ( sm_wb_data       )
  );

  assign tech_data_out = cache_data_i;
  assign cache_addr_o  = tech_data_addr;
  assign cache_we_o    = tech_data_we;
  assign cache_en_o    = '1;
  assign cache_data_o  = tech_data_in;

  assign matrix_vec = lru_data_i;
  assign lru_addr_o = matrix_addr;
  assign lru_we_o   = write_vec;
  assign lru_en_o   = '1;
  assign lru_data_o = updated_matrix_vec;

endmodule
