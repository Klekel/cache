module tb_load_sm();
import cache_pkg::*;

  logic                        clk;
  logic                        rstn;

  logic                        strobe_sm;
  logic [SET_BITS-1      : 0]  set_num_sm;
  logic [MATRIX_WIDTH-1  : 0]  matrix_vec_sm;
  logic                        ready_sm;
  logic                        sel_sm;

  initial begin
    forever begin
      #10 clk = ~clk;
    end
  end

  task reset();
    clk          <= '0;
    rstn         <= '0;
    repeat(5)@(posedge clk);
    rstn         <= '1;
  endtask

  load_sm i_sm(
    .clk_i   ( clk           ),
    .rstn_i  ( rstn          ),
    .ready_o ( ready_sm      ),
    .vect_o  ( matrix_vec_sm ),
    .sel_o   ( sel_sm        ),
    .we_o    ( strobe_sm     ),
    .addr_o  ( set_num_sm    )
  );

  initial begin
    reset();
    repeat(10) @(posedge clk);
    reset();
    repeat(3) @(posedge clk);
    reset();
  end

endmodule