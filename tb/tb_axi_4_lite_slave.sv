module tb_axi_4_lite_slave();
import cache_pkg::*;

  logic                        clk = 0;
  logic                        rstn = 0;

  logic                        wready;
  logic                        awready;

  logic                        wvalid;
  logic                        awvalid;

  logic [ADDR_WIDTH-1 :0]      awaddr;
  logic [DATA_WIDTH-1 :0]      wdata;
  logic [DATA_BYTES-1 :0]      wstrb;

  logic                        bvalid;
  logic [1:0]                  bresp_o;
  logic                        bready;

  logic                        arready;
  logic                        rready;
  logic                        arvalid;
  logic                        rvalid;
  logic                        rresp;

  logic [ADDR_WIDTH-1 :0]      araddr;
  logic [DATA_WIDTH-1 :0]      rdata;

  logic                   clk_out;
  logic                   arstn_out;
  logic [FIFO_WIDTH-1 :0] data_out;
  logic                   valid_out;
  logic                   ready_in;
  logic                   cpu_ready;
  logic [DATA_WIDTH-1 :0] cache_data;
  logic                   cache_valid;

  initial begin
    forever begin
      #10 clk = ~clk;
    end
  end

  task reset();
    clk         <= '0;
    cache_data  <= '0;
    cache_valid <= '0;
    rready      <= '0;
    araddr      <= '0;
    arvalid     <= '0;
    bready      <= '1;
    wstrb       <= '0;
    wdata       <= '0;
    wvalid      <= '0;
    awaddr      <= '0;
    awvalid     <= '0;
    rstn        <= '0;
    ready_in    <= '1;
    repeat(5)@(posedge clk);
    rstn        <= '1;
  endtask

  task axi_write(input logic [DATA_WIDTH-1 :0] data, input logic [DATA_BYTES-1 :0] wstrb_);
    wvalid  <= 1'b1;
    wdata   <= data;
    wstrb   <= wstrb_;
    do
    @(posedge clk);
    while(!wready);
    wvalid  <= 1'b0;
  endtask

  task axi_addr_write(input logic [ADDR_WIDTH-1 :0] addr);
    awvalid <= 1'b1;
    awaddr  <= addr;
    do
    @(posedge clk);
    while(!awready);
    awvalid <= 1'b0;
  endtask

    task axi_both_write( input logic [DATA_WIDTH-1 :0] data, input logic [ADDR_WIDTH-1 :0] addr, input logic [DATA_BYTES-1 :0] wstrb);
    awvalid <= 1'b1;
    wvalid  <= 1'b1;
    wdata   <= data;
    awaddr  <= addr;
    wstrb   <= wstrb;
    do
    @(posedge clk);
    while(!(wready & awready));
    awvalid <= 1'b0;
    wvalid  <= 1'b0;
  endtask

  task axi_read(input logic [ADDR_WIDTH-1 :0] addr);
    arvalid <= 1'b1;
    araddr  <= addr;
    do
    @(posedge clk);
    while(!arready);
    arvalid <= 1'b0;
  endtask

  task cache_write(input logic [DATA_WIDTH-1 :0] data);
    cache_valid <= 1'b1;
    cache_data  <= data;
    do
    @(posedge clk);
    while(!cpu_ready);
    cache_valid <= 1'b0;
  endtask

  axi_4_lite_slave dut(
    .aclk_i        ( clk         ),
    .arstn_i       ( rstn        ),

    .awready_o     ( awready     ),
    .awvalid_i     ( awvalid     ),
    .awaddr_i      ( awaddr      ),
    .awprot_i      ( '0          ),

    .wready_o      ( wready      ),
    .wvalid_i      ( wvalid      ),
    .wdata_i       ( wdata       ),
    .wstrb_i       ( wstrb       ),

    .bvalid_o      ( bvalid      ),
    .bresp_o       ( bresp_o     ),
    .bready_i      ( bready      ),

    .arready_o     ( arready     ),
    .arvalid_i     ( arvalid     ),
    .araddr_i      ( araddr      ),
    .arprot_i      ( '0          ),

    .rvalid_o      ( rvalid      ),
    .rdata_o       ( rdata       ),
    .rresp_o       ( rresp       ),
    .rready_i      ( rready      ),

    .data_pkt_o    ( data_out    ),
    .valid_pkt_o   ( valid_out   ),
    .ready_pkt_i   ( ready_in    ),

    .cpu_ready_o   ( cpu_ready   ),

    .cache_data_i  ( cache_data  ),
    .cache_valid_i ( cache_valid )
  );


initial begin
  reset();
  axi_addr_write('0);
  axi_write(32'd1,'1);

  axi_addr_write('d0);
  axi_write(32'd2,'1);

  axi_addr_write('0);
  axi_write(32'd3,'1);

  axi_addr_write(32'd0);
  axi_write(32'd4,'1);

  axi_both_write(32'd5, 32'd1,'1);

  axi_read(32'd5);

  repeat(10) @(posedge clk);

  cache_write(32'd2);

end

endmodule