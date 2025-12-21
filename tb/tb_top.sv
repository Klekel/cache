module tb_top();
import cache_pkg::*;

  logic                       clk;
  logic                       rstn;

  logic                       m_awready;
  logic                       m_awvalid;
  logic [ADDR_WIDTH-1     :0] m_awaddr;
  logic [2                :0] m_awprot;
  logic                       m_wready;
  logic                       m_wvalid;
  logic [DATA_WIDTH-1     :0] m_wdata;
  logic [DATA_BYTES-1     :0] m_wstrb;
  logic                       m_bvalid;
  logic [1                :0] m_bresp;
  logic                       m_bready;
  logic                       m_arready;
  logic                       m_arvalid;
  logic [ADDR_WIDTH-1     :0] m_araddr;
  logic [2                :0] m_arprot;
  logic                       m_rvalid;
  logic [DATA_WIDTH-1     :0] m_rdata;
  logic [1                :0] m_rresp;
  logic                       m_rready;
  logic                       s_awready;
  logic                       s_awvalid;
  logic [ADDR_WIDTH-1     :0] s_awaddr;
  logic [2                :0] s_awprot;
  logic                       s_wready;
  logic                       s_wvalid;
  logic [DATA_WIDTH-1     :0] s_wdata;
  logic [DATA_BYTES-1     :0] s_wstrb;
  logic                       s_bvalid;
  logic [1                :0] s_bresp;
  logic                       s_bready;
  logic                       s_arready;
  logic                       s_arvalid;
  logic [ADDR_WIDTH-1     :0] s_araddr;
  logic [2                :0] s_arprot;
  logic                       s_rvalid;
  logic [DATA_WIDTH-1     :0] s_rdata;
  logic [1                :0] s_rresp;
  logic                       s_rready;

  logic [TECH_ADDR_WIDTH-1:0] tech_data_addr;
  logic                       tech_data_we;
  logic [DATA_WIDTH-1     :0] tech_data_in;
  logic [DATA_WIDTH-1     :0] tech_data_out;

  logic [MATRIX_WIDTH-1   :0] matrix_vec;
  logic [SET_BITS-1       :0] matrix_addr;
  logic                       write_vec;
  logic [MATRIX_WIDTH-1   :0] updated_matrix_vec;

  initial begin
    forever begin
      #20 clk = ~clk;
    end
  end

  task reset();
    clk          <= '0;
    rstn         <= '0;
    m_awready    <= '0;
    m_wready     <= '0;
    m_bvalid     <= '0;
    m_bresp      <= '0;
    m_arready    <= '1;
    m_rvalid     <= '0;
    m_rdata      <= '0;
    m_rresp      <= '0;
    s_awvalid    <= '0;
    s_awaddr     <= '0;
    s_awprot     <= '0;
    s_wvalid     <= '0;
    s_wdata      <= '0;
    s_wstrb      <= '0;
    s_bready     <= '1;
    s_arvalid    <= '0;
    s_araddr     <= '0;
    s_arprot     <= '0;
    s_rready     <= '1;
    repeat(5)@(posedge clk);
    rstn         <= '1;
  endtask

  task axi_m_read(input logic [DATA_WIDTH-1 :0] data);
    m_rvalid  <= 1'b1;
    m_rdata   <= data;
    do
    @(posedge clk);
    while(!m_rready);
    m_rvalid  <= 1'b0;
  endtask

  task axi_s_write(input logic [DATA_WIDTH-1 :0] data, input logic [DATA_BYTES-1 :0] wstrb_);
    s_wvalid  <= 1'b1;
    s_wdata   <= data;
    s_wstrb   <= wstrb_;
    do
    @(posedge clk);
    while(!s_wready);
    s_wvalid  <= 1'b0;
  endtask

  task axi_s_addr_write(input logic [ADDR_WIDTH-1 :0] addr);
    s_awvalid <= 1'b1;
    s_awaddr  <= addr * 4;
    do
    @(posedge clk);
    while(!s_awready);
    s_awvalid <= 1'b0;
  endtask

  task axi_s_both_write( input logic [DATA_WIDTH-1 :0] data, input logic [ADDR_WIDTH-1 :0] addr, input logic [DATA_BYTES-1 :0] wstrb);
    repeat(8)@(posedge clk);
    s_awvalid <= 1'b1;
    s_wvalid  <= 1'b1;
    s_wdata   <= data;
    s_awaddr  <= addr * 4;
    s_wstrb   <= wstrb;
    do
    @(posedge clk);
    while(!(s_wready & s_awready));
    s_awvalid <= 1'b0;
    s_wvalid  <= 1'b0;
  endtask

  task axi_s_read(input logic [ADDR_WIDTH-1 :0] addr);
    repeat(8)@(posedge clk);
    s_arvalid <= 1'b1;
    s_araddr  <= addr * 4;
    do
    @(posedge clk);
    while(!s_arready);
    s_arvalid <= 1'b0;
  endtask

  task temporari_valid();
    m_rvalid <= '0;
    m_rdata  <= '0;
    for (int i = 0; i < 10; i++) begin
      @(posedge clk);
    end
    m_rdata  <= $urandom();
    m_rvalid <= '1;
    @(posedge clk);
  endtask

  task m_load_data_by_request();
    wait(m_arvalid && m_arready);
    @(posedge clk);
    @(posedge clk);
    m_rvalid <= '1;
    m_rdata  <= $urandom();
    wait(m_rvalid && m_rready);
    @(posedge clk);
    m_rvalid <= '0;
    m_rdata  <= '0;
  endtask

  top dut(
    .aclk_i       ( clk                ),
    .arstn_i      ( rstn               ),

    .m_awready_i  ( m_awready          ),
    .m_awvalid_o  ( m_awvalid          ),
    .m_awaddr_o   ( m_awaddr           ),
    .m_awprot_o   ( m_awprot           ),

    .m_wready_i   ( m_wready           ),
    .m_wvalid_o   ( m_wvalid           ),
    .m_wdata_o    ( m_wdata            ),
    .m_wstrb_o    ( m_wstrb            ),

    .m_bvalid_i   ( m_bvalid           ),
    .m_bresp_i    ( m_bresp            ),
    .m_bready_o   ( m_bready           ),

    .m_arready_i  ( m_arready          ),
    .m_arvalid_o  ( m_arvalid          ),
    .m_araddr_o   ( m_araddr           ),
    .m_arprot_o   ( m_arprot           ),

    .m_rvalid_i   ( m_rvalid           ),
    .m_rdata_i    ( m_rdata            ),
    .m_rresp_i    ( m_rresp            ),
    .m_rready_o   ( m_rready           ),

    .s_awready_o  ( s_awready          ),
    .s_awvalid_i  ( s_awvalid          ),
    .s_awaddr_i   ( s_awaddr           ),
    .s_awprot_i   ( s_awprot           ),

    .s_wready_o   ( s_wready           ),
    .s_wvalid_i   ( s_wvalid           ),
    .s_wdata_i    ( s_wdata            ),
    .s_wstrb_i    ( s_wstrb            ),

    .s_bvalid_o   ( s_bvalid           ),
    .s_bresp_o    ( s_bresp            ),
    .s_bready_i   ( s_bready           ),

    .s_arready_o  ( s_arready          ),
    .s_arvalid_i  ( s_arvalid          ),
    .s_araddr_i   ( s_araddr           ),
    .s_arprot_i   ( s_arprot           ),

    .s_rvalid_o   ( s_rvalid           ),
    .s_rdata_o    ( s_rdata            ),
    .s_rresp_o    ( s_rresp            ),
    .s_rready_i   ( s_rready           ),

    .cache_data_i ( tech_data_out      ),
    .cache_addr_o ( tech_data_addr     ),
    .cache_we_o   ( tech_data_we       ),
    .cache_en_o   (                    ),
    .cache_data_o ( tech_data_in       ),

    .lru_data_i   ( matrix_vec         ),
    .lru_addr_o   ( matrix_addr        ),
    .lru_we_o     ( write_vec          ),
    .lru_en_o     (                    ),
    .lru_data_o   ( updated_matrix_vec )
  );

  bram #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(TECH_ADDR_WIDTH)
  )i_cache_mem(
    .clk_i  ( clk            ),
    .addr_i ( tech_data_addr ),
    .data_i ( tech_data_in   ),
    .we_i   ( tech_data_we   ),
    .en_i   ( '1             ),
    .data_o ( tech_data_out  )
  );

  bram #(
    .DATA_WIDTH(MATRIX_WIDTH),
    .ADDR_WIDTH(SET_BITS)
  )i_lru_mem(
    .clk_i  ( clk                ),
    .addr_i ( matrix_addr        ),
    .data_i ( updated_matrix_vec ),
    .we_i   ( write_vec          ),
    .en_i   ( '1                 ),
    .data_o ( matrix_vec         )
  );

  task read_test(input logic [ADDR_WIDTH-1 :0] addr_1, input logic [ADDR_WIDTH-1 :0] addr_2);
  axi_s_read(.addr(addr_1));
  axi_s_read(.addr(addr_2));
  endtask

  task write_test(input logic [ADDR_WIDTH-1 :0] addr_1, input logic [ADDR_WIDTH-1 :0] addr_2);
  axi_s_both_write(.data('1), .addr(addr_1), .wstrb(4'b1001));
  axi_s_both_write(.data('1), .addr(addr_2), .wstrb(4'b1001));
  endtask


  initial begin
    reset();
    repeat(8) @(posedge clk);
    read_test(.addr_1(1), .addr_2(3));
    repeat(8) @(posedge clk);
    write_test(.addr_1(1), .addr_2(3));
    repeat(8) @(posedge clk);
    write_test(.addr_1(5), .addr_2(7));
    repeat(8) @(posedge clk);
    read_test(.addr_1(1), .addr_2(3));
  end

  initial forever m_load_data_by_request();

endmodule