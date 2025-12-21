module tb_lru;
import cache_pkg::*;
  logic                     clk = 0;
  logic                     rstn = 0;
  logic [BLOCK_AMOUNT-1 :0] block_num_i;
  logic [SET_BITS-1     :0] set_num_i;
  logic                     stall_i;
  logic                     strobe_i;
  logic                     hit_i;
  logic [MATRIX_WIDTH-1 :0] matrix_vec_i;
  logic [SET_BITS-1     :0] matrix_addr_o;
  logic                     write_vec_o;
  logic [MATRIX_WIDTH-1 :0] updated_matrix_vec_o;
  logic [BLOCK_AMOUNT-1 :0] push_block_vec_o;

  logic [SET_BITS-1     :0] matrix_addr_init;
  logic [MATRIX_WIDTH-1 :0] updated_matrix_vec_init;
  logic                     write_vec_init;
  logic [MATRIX_WIDTH-1 :0] matrix_vec_init;
  logic                     init = 0;
  logic                     ready = 0;
  logic [SET_BITS-1     :0] matrix_addr;
  logic [MATRIX_WIDTH-1 :0] updated_matrix_vec;
  logic [MATRIX_WIDTH-1 :0] matrix_vec;

  lru DUT (
    .clk_i                ( clk                  ),
    .rstn_i               ( rstn                 ),
    .block_num_i          ( block_num_i          ),
    .set_num_i            ( set_num_i            ),
    .stall_i              ( stall_i              ),
    .strobe_i             ( strobe_i             ),
    .hit_i                ( hit_i                ),
    .matrix_vec_i         ( matrix_vec           ),
    .matrix_addr_o        ( matrix_addr_o        ),
    .write_vec_o          ( write_vec_o          ),
    .updated_matrix_vec_o ( updated_matrix_vec_o ),
    .push_block_vec_o     ( push_block_vec_o     ),
    .ready_o              ( ready_o              )
  );

  assign matrix_addr        = (init) ? matrix_addr_init        : matrix_addr_o;
  assign updated_matrix_vec = (init) ? updated_matrix_vec_init : updated_matrix_vec_o;
  assign write_vec          = (init) ? write_vec_init          : write_vec_o;

  bram_lru dut2(
    .clk_i  ( clk                  ),
    .addr_i ( matrix_addr          ),
    .data_i ( updated_matrix_vec   ),
    .we_i   ( write_vec            ),
    .en_i   ( '1                   ),
    .data_o ( matrix_vec           )
  );

initial begin
  forever begin
    #10 clk = ~clk;
  end
end

task write_new_addr(input logic [BLOCK_AMOUNT-1:0] block_num, input logic [SET_BITS-1:0] set_num);
  hit_i <= 0;
  block_num_i  <= block_num;
  set_num_i    <= set_num;
  strobe_i     <= '1;
  @(posedge clk);
  strobe_i     <= '0;
  @(posedge clk);
endtask

task write_new_addr_hit(input logic [BLOCK_AMOUNT-1:0] block_num, input logic [SET_BITS-1:0] set_num, input logic hit);
  hit_i <= hit;
  block_num_i  <= block_num;
  set_num_i    <= set_num;
  strobe_i     <= '1;
  @(posedge clk);
  strobe_i     <= '0;
  @(posedge clk);
  hit_i        <= '0;
endtask

initial begin
  hit_i    <= '0;
  init     <= '0;
  rstn     <= 0;
  stall_i  <= 0;
  strobe_i <= '0;
  repeat(10)@(posedge clk);
  rstn <= 1;
  #12
  wait(ready_o)
  write_new_addr_hit(4'b0100, 2'd0, '1);
  write_new_addr_hit(4'b1000, 2'd0, '1);
  write_new_addr_hit(4'b0010, 2'd0, '1);
  write_new_addr(4'b0000, 2'd0);
  write_new_addr(4'b0100, 2'd0);
  write_new_addr(4'b0010, 2'd0);
  write_new_addr(4'b0001, 2'd0);
  write_new_addr_hit(4'b0001, 2'd0, '1);
end

endmodule