module lru
import cache_pkg::*;
(
  input                             clk_i,
  input                             rstn_i,

  input  logic [BLOCK_AMOUNT-1 : 0] block_num_i,
  input  logic [SET_BITS-1     : 0] set_num_i,
  input                             strobe_i,
  input                             hit_i,

  input  logic [MATRIX_WIDTH-1 : 0] matrix_vec_i,
  output logic [SET_BITS-1     : 0] matrix_addr_o,
  output logic                      write_vec_o,
  output logic [MATRIX_WIDTH-1 : 0] updated_matrix_vec_o,

  output logic [BLOCK_AMOUNT-1 : 0] push_block_vec_o,
  output logic                      ready_o
);

  logic [BLOCK_AMOUNT-1  : 0]  set_push_next_ff [SET_AMOUNT-1:0];
  logic                        strobe_ff;
  logic [MATRIX_WIDTH-1  : 0]  matrix_vec_lru;
  logic [BLOCK_AMOUNT-1  : 0]  update_push_next;
  logic [SET_AMOUNT-1    : 0]  strobe;
  logic                        ready_lru;

  logic                        strobe_sm;
  logic [SET_BITS-1      : 0]  set_num_sm;
  logic [MATRIX_WIDTH-1  : 0]  matrix_vec_sm;
  logic                        ready_sm;
  logic                        sel_sm;

  logic [BLOCK_AMOUNT-1  : 0]  aim;

  // Matrix for vector expansion
  logic [BLOCK_AMOUNT-1:0][BLOCK_AMOUNT-1:0] matrix;
  logic [BLOCK_AMOUNT-1:0][BLOCK_AMOUNT-1:0] next_matrix;

  //------------------------------------
  // matrix logic
  //------------------------------------
  // SET_AMOUNT BLOCK_AMOUNT x BLOCK_AMOUNT matrix
  // when set_num_i and valid_i are raised block_num_i line
  // is set to 1 after what block_num_i column set to 0

  // Initial filling of the matrix with the input vector

  always_comb begin
    automatic  int offset = 0;
    matrix = '0;
    for ( int i = 0; i < BLOCK_AMOUNT; i = i + 1 ) begin
      for ( int j = i + 1; j < BLOCK_AMOUNT; j = j + 1 ) begin
        matrix[i][j] = matrix_vec_i[offset + j - i - 1];
      end
      for ( int j = 0; j < i; j = j + 1 ) begin
        matrix[i][j] = !matrix[j][i];
      end
      offset = offset + BLOCK_AMOUNT - i - 1;
    end
  end

  // Output one-hot vector
  always_comb begin
    for ( int i = 0; i < BLOCK_AMOUNT; i = i + 1 ) begin
      update_push_next[i] = !( |next_matrix[i] );
    end
  end

  // Updating the matrix

  assign aim = (hit_i) ? block_num_i : set_push_next_ff[set_num_i];

  always_comb begin
    next_matrix = matrix;
    for ( int i = 0; i < BLOCK_AMOUNT; i = i + 1 ) begin
      if ( aim[i] ) begin
        for ( int j = 0; j < BLOCK_AMOUNT; j = j + 1 ) begin
          next_matrix[i][j] = 1'b1;
        end
        for ( int j = 0; j < BLOCK_AMOUNT; j = j + 1 ) begin
          next_matrix[j][i] = 1'b0;
        end
      end
    end
  end

  // Output updated matrix
  always_comb begin
    automatic  int offset = 0;
    for ( int i = 0; i < BLOCK_AMOUNT; i = i + 1 ) begin
      for ( int j = i + 1; j < BLOCK_AMOUNT; j = j + 1 ) begin
        matrix_vec_lru[offset + j - i - 1] = next_matrix[i][j];
      end
      offset = offset + BLOCK_AMOUNT - i - 1;
    end
  end

  //------------------------------------
  // reg stage logic
  //------------------------------------
  // reg stage is used to reduce the critical path.

  always_ff @(posedge clk_i or negedge rstn_i) begin
    if(!rstn_i) strobe_ff <= '0;
    else strobe_ff <= strobe_i;
  end

  always_ff @(posedge clk_i or negedge rstn_i) begin
    if(!rstn_i) ready_lru <= '1;
    else ready_lru <= !strobe_i;
  end

  always_comb begin
    strobe = '0;
    for(int i = 0; i < BLOCK_AMOUNT; i++) begin
      strobe[i] = (i == set_num_i) && strobe_ff;
    end
  end

  generate
    for (genvar i=0; i<SET_AMOUNT; i++)
      always_ff @( posedge clk_i or negedge rstn_i ) begin
        if      (!rstn_i)   set_push_next_ff[i] <= 4'b1000;
        else if (strobe[i]) set_push_next_ff[i] <= update_push_next;
      end
  endgenerate

  //------------------------------------
  // ready_o logic
  //------------------------------------

  load_sm i_sm(
    .clk_i   ( clk_i         ),
    .rstn_i  ( rstn_i        ),
    .ready_o ( ready_sm      ),
    .vect_o  ( matrix_vec_sm ),
    .sel_o   ( sel_sm        ),
    .we_o    ( strobe_sm     ),
    .addr_o  ( set_num_sm    )
  );

  //------------------------------------
  // push_block_vec_o logic
  //------------------------------------
  // push_block_vec_o is a onehot
  // which shows next block to replace for chosen set
  // the 1's position shows which block will be replaced next

  assign push_block_vec_o     = set_push_next_ff[set_num_i];
  assign ready_o              = ready_sm && ready_lru;
  assign updated_matrix_vec_o = (sel_sm) ? matrix_vec_sm : matrix_vec_lru;
  assign write_vec_o          = (sel_sm) ? strobe_sm     : strobe_ff;
  assign matrix_addr_o        = (sel_sm) ? set_num_sm    : set_num_i;

endmodule