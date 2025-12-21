module tb_axi_4_lite_master();
import cache_pkg::*;

logic                   clk;
logic                   rstn;
logic                   awready;
logic                   awvalid;
logic [ADDR_WIDTH-1 :0] awaddr;
logic [2            :0] awprot;
logic                   wready;
logic                   wvalid;
logic [DATA_WIDTH-1 :0] wdata;
logic [DATA_BYTES   :0] wstrb;
logic                   bvalid;
logic [1            :0] bresp;
logic                   bready;
logic                   arready;
logic                   arvalid;
logic [ADDR_WIDTH-1 :0] araddr;
logic [2            :0] arprot;
logic                   rvalid;
logic [DATA_WIDTH-1 :0] rdata;
logic [1            :0] rresp;
logic                   rready;
logic                   wb_valid;
logic [DATA_WIDTH-1:0]  wb_data;
logic [ADDR_WIDTH-1:0]  wb_addr;
logic                   mem_ready_in;
logic [DATA_WIDTH-1:0]  mem_data;
logic                   mem_valid;
logic                   mem_ready_out;
logic                   addr_req;
logic                   addr_ready;
logic [ADDR_WIDTH-1 :0] addr;

  initial begin
    forever begin
      #10 clk = ~clk;
    end
  end

  task reset();
    clk          <= '0;
    rstn         <= '0;
    awready      <= '0;
    wready       <= '1;
    bvalid       <= '0;
    bresp        <= '0;
    arready      <= '1;
    rvalid       <= '0;
    rdata        <= '0;
    rresp        <= '0;
    wb_valid     <= '0;
    wb_data      <= '0;
    wb_addr      <= '0;
    mem_ready_in <= '1;
    addr_req     <= '0;
    addr         <= '0;
    repeat(5)@(posedge clk);
    rstn         <= '1;
  endtask

  task axi_read(input logic [DATA_WIDTH-1 :0] data);
    rvalid  <= 1'b1;
    rdata   <= data;
    do
    @(posedge clk);
    while(!rready);
    rvalid  <= 1'b0;
  endtask

  task wb_write(input logic [ADDR_WIDTH-1 :0] addr, input logic [DATA_WIDTH-1 :0] data);
    wb_valid <= 1'b1;
    wb_addr  <= addr;
    wb_data  <= data;
    do
    @(posedge clk);
    while(!mem_ready_out);
    wb_valid <= 1'b0;
  endtask

  task addr_read(input logic [ADDR_WIDTH-1 :0] addr_);
    addr_req <= 1'b1;
    addr  <= addr_;
    do
    @(posedge clk);
    while(!addr_ready);
    addr_req <= 1'b0;
  endtask

  axi_4_lite_master dut(
    .aclk_i       ( clk           ),
    .arstn_i      ( rstn          ),

    .awready_i    ( awready       ),
    .awvalid_o    ( awvalid       ),
    .awaddr_o     ( awaddr        ),
    .awprot_o     ( awprot        ),

    .wready_i     ( wready        ),
    .wvalid_o     ( wvalid        ),
    .wdata_o      ( wdata         ),
    .wstrb_o      ( wstrb         ),

    .bvalid_i     ( bvalid        ),
    .bresp_i      ( bresp         ),
    .bready_o     ( bready        ),

    .arready_i    ( arready       ),
    .arvalid_o    ( arvalid       ),
    .araddr_o     ( araddr        ),
    .arprot_o     ( arprot        ),

    .rvalid_i     ( rvalid        ),
    .rdata_i      ( rdata         ),
    .rresp_i      ( rresp         ),
    .rready_o     ( rready        ),

    .wb_valid_i   ( wb_valid      ),
    .wb_data_i    ( wb_data       ),
    .wb_addr_i    ( wb_addr       ),
    .mem_ready_o  ( mem_ready_out ),

    .mem_data_o   ( mem_data      ),
    .mem_valid_o  ( mem_valid     ),
    .mem_ready_i  ( mem_ready_in  ),

    .addr_req_i   ( addr_req      ),
    .addr_i       ( addr          ),
    .addr_ready_o ( addr_ready    )
  );


initial begin
  reset();
  axi_read(.data(32'd13));
  axi_read(.data(32'd12));
  wb_write(.addr(32'd0), .data(32'd13));
  wb_write(.addr(32'd1), .data(32'd14));
  wb_write(.addr(32'd2), .data(32'd15));
  wb_write(.addr(32'd3), .data(32'd16));
  repeat(10) @(posedge clk);
  awready <= '1;
  wb_write(.addr(32'd4), .data(32'd17));
  addr_read(.addr_(32'd23));

end

endmodule