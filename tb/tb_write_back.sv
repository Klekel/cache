module tb_write_back();
import cache_pkg::*;

  logic                       clk;
  logic                       rstn;
  logic [ADDR_WIDTH-1:0]      r_addr;
  logic                       wb_hit;
  logic [DATA_WIDTH-1:0]      r_data;
  logic [ADDR_WIDTH-1:0]      wr_addr;
  logic [DATA_WIDTH-1:0]      wr_data;
  logic                       dirty;
  logic                       wb_ready;
  logic                       stall;
  logic                       ready;
  logic                       valid;
  logic                       clr_valid;
  logic [ADDR_WIDTH-1:0]      addr;
  logic [DATA_WIDTH-1:0]      data;

  initial begin
    forever begin
      #10 clk = ~clk;
    end
  end

    task reset();
    clk          <= '0;
    rstn         <= '0;
    r_addr       <= '0;
    wr_addr      <= '0;
    wr_data      <= '0;
    dirty        <= '0;
    ready        <= '0;
    clr_valid    <= '0;
    repeat(5)@(posedge clk);
    rstn         <= '1;
  endtask

  task wb_write(input logic [DATA_WIDTH-1 :0] data, input logic [ADDR_WIDTH-1 :0] addr);
    dirty       <= 1'b1;
    wr_data     <= data;
    wr_addr     <= addr;
    do
    @(posedge clk);
    while(!wb_ready);
    dirty     <= 1'b0;
  endtask

  task axi_addr( input logic [ADDR_WIDTH-1 :0] addr);
    r_addr    <= addr;
    @(posedge clk);
    clr_valid <= '1;
    @(posedge clk);
    r_addr    <= '0;
    clr_valid <= '0;
  endtask

  task wb_read();
    ready       <= 1'b1;
    do
    @(posedge clk);
    while(!valid);
    ready     <= 1'b0;
  endtask

  write_back_buffer dut (
    .clk_i       ( clk      ),
    .rstn_i      ( rstn     ),

    .r_addr_i    ( r_addr   ),
    .clr_valid_i ( clr_valid),
    .wb_hit_o    ( wb_hit   ),
    .r_data_o    ( r_data   ),

    .wr_addr_i   ( wr_addr  ),
    .wr_data_i   ( wr_data  ),
    .dirty_i     ( dirty    ),
    .wb_ready_o  ( wb_ready ),

    .ready_i     ( ready    ),
    .valid_o     ( valid    ),
    .addr_o      ( addr     ),
    .data_o      ( data     )
  );

initial begin
  reset();
  wb_write(.data(32'd1), .addr(32'd12));
  wb_write(.data(32'd2), .addr(32'd13));
  wb_write(.data(32'd3), .addr(32'd14));
  wb_write(.data(32'd4), .addr(32'd15));
  wb_read();
  axi_addr(32'd15);
  repeat(10) @(posedge clk);
  wb_write(.data(32'd5), .addr(32'd16));
  wb_read();
  wb_read();
  wb_read();
  wb_read();
end

endmodule