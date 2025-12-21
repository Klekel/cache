module write_back_buffer
import cache_pkg::*;
import cache_struct_pkg::*;
(
  input                              clk_i,
  input                              rstn_i,

  input  logic [ADDR_WIDTH-1:0]      r_addr_i,
  input  logic                       clr_valid_i,
  output logic                       wb_hit_o,
  output logic [DATA_WIDTH-1:0]      r_data_o,

  input  logic [ADDR_WIDTH-1:0]      wr_addr_i,
  input  logic [DATA_WIDTH-1:0]      wr_data_i,
  input  logic                       dirty_i,
  output logic                       wb_ready_o,

  input                              ready_i,
  output                             valid_o,
  output logic [ADDR_WIDTH-1:0]      addr_o,
  output logic [DATA_WIDTH-1:0]      data_o
);

  localparam BLOCK_DEPTH = 2**BUFFER_DEPTH_BITS;

  wb_block_t                       block   [BLOCK_DEPTH-1:0];
  logic    [BLOCK_DEPTH-1:0]       set_hit;
  logic    [BUFFER_DEPTH_BITS:0]   wr_ptr;
  logic    [BUFFER_DEPTH_BITS-1:0] wr_ptr_c;
  logic    [BUFFER_DEPTH_BITS:0]   wr_ptr_n;
  logic    [BUFFER_DEPTH_BITS:0]   r_ptr;
  logic    [BUFFER_DEPTH_BITS-1:0] r_ptr_c;
  logic    [BUFFER_DEPTH_BITS:0]   r_ptr_n;
  logic                            full;
  logic                            empty;
  logic    [BUFFER_DEPTH_BITS-1:0] clr_idx;

  assign full       = (r_ptr_c == wr_ptr_c) & (wr_ptr[BUFFER_DEPTH_BITS] != r_ptr[BUFFER_DEPTH_BITS]);
  assign empty      = wr_ptr == r_ptr;

  always_comb begin
    for ( int i = 0; i < BLOCK_DEPTH; i++ )
      set_hit[i]  = ( r_addr_i == block[i].addr ) & block[i].valid;
  end

  assign wb_hit_o = |set_hit;
  assign wr_ptr_n = wr_ptr + (dirty_i & wb_ready_o);
  assign r_ptr_n = r_ptr + (ready_i & valid_o);

  always_ff @(posedge clk_i or negedge rstn_i) begin
    if(!rstn_i) begin
      wr_ptr <= '0;
      r_ptr  <= '0;
    end
    else begin
      wr_ptr <= wr_ptr_n;
      r_ptr  <= r_ptr_n;
    end
  end

  assign wr_ptr_c = wr_ptr[BUFFER_DEPTH_BITS-1:0];
  assign r_ptr_c = r_ptr[BUFFER_DEPTH_BITS-1:0];

  always_ff @( posedge clk_i or negedge rstn_i ) begin
    if ( !rstn_i ) begin
      for (int i = 0; i < BLOCK_DEPTH; i++) begin
        block[i].valid <= '0;
      end
    end
    else
      if ( dirty_i & wb_ready_o ) begin
        block[wr_ptr_c] <= '{valid: 1'b1, addr: wr_addr_i, data: wr_data_i};
      end

      if (ready_i & valid_o) begin
        block[r_ptr_c].valid <= '0;
      end

      if ( wb_hit_o && clr_valid_i) begin
        block[clr_idx].valid <= '0;
      end
  end

  always_comb begin
    r_data_o = '0;
    clr_idx  = '0;
    for ( int i = 0; i < BLOCK_DEPTH; i++ ) begin
      if(r_addr_i == block[i].addr) begin
        r_data_o = block[i].data;
        clr_idx  = i;
      end
    end
  end

  assign data_o     = block[r_ptr_c].data;
  assign addr_o     = block[r_ptr_c].addr;
  assign valid_o    = !empty;
  assign wb_ready_o = !full;

endmodule
