module cache
import cache_pkg::*;
import cache_struct_pkg::*;
(
  input  logic                       aclk_i,
  input  logic                       arstn_i,

  input  logic                       valid_s_i,          // CPU side
  input  logic [FIFO_WIDTH_EX-1  :0] transaction_data_i, // data from CPU
  output logic                       cache2cpu_ready_o,  // ready for the cpu transaction recieving

  input  logic                       valid_m_i,          // MEM side
  input  logic [DATA_WIDTH-1     :0] mem_data_i,         // data from MEM
  output logic                       cache2mem_ready_o,  // ready for the mem data recieving

  output logic                       valid_o,            // validation signal of correct data
  output logic [DATA_WIDTH-1     :0] data_o,             // data for CPU and WB
  input  logic                       cpu2cache_ready_i,  // ready from cpu r chanel

  input  logic                       wb_ready_i,         // WB not full
  output logic                       dirty_o,            // validness siganal for wb data
  output logic [ADDR_WIDTH-1     :0] wb_addr_o,          // addr for wb

  input  logic [ADDR_WIDTH-1     :0] pre_addr_i,         // address to check
  output logic                       pre_hit_o,          // decision making signal eather to write transaction in topre cache fifo or firstly make request to the mem

  output logic [TECH_ADDR_WIDTH-1:0] tech_data_addr_o,
  output logic                       tech_data_we_o,
  input  logic [DATA_WIDTH-1     :0] tech_data_i,
  output logic [DATA_WIDTH-1     :0] tech_data_o,

  input  logic [MATRIX_WIDTH-1   :0] matrix_vec_i,
  output logic [SET_ANY-1        :0] matrix_addr_o,
  output logic                       write_vec_o,
  output logic [MATRIX_WIDTH-1   :0] updated_matrix_vec_o
);

  localparam SET_OFFSET = $clog2(DATA_WIDTH/8);
  localparam TAG_OFFSET = SET_OFFSET + SET_ANY;
  localparam TAG_WIDTH  = ADDR_WIDTH-TAG_OFFSET;

  cache_block_t                         block     [SET_AMOUNT-1:0][BLOCK_AMOUNT-1 : 0];
  logic         [BLOCK_AMOUNT-1 : 0]    set_hit   [SET_AMOUNT-1:0];
  logic         [BLOCK_AMOUNT-1 : 0]    pre_hit   [SET_AMOUNT-1:0];
  logic         [SET_AMOUNT-1   : 0]    pre_hit_arr;
  logic         [TAG_WIDTH-1    : 0]    tag;
  logic         [SET_ANY-1      : 0]    set;
  logic         [TAG_WIDTH-1    : 0]    pre_tag;
  logic         [SET_ANY-1      : 0]    pre_set;
  logic         [TAG_WIDTH-1    : 0]    pre_addr;
  logic         [MATRIX_WIDTH-1 : 0]    matrix_vec;
  logic         [BLOCK_AMOUNT-1 : 0]    push_block_vec;
  logic         [SET_ANY-1      : 0]    matrix_addr;
  logic                                 write_vec;
  logic         [MATRIX_WIDTH-1 : 0]    updated_matrix_vec;
  logic         [BLOCK_ANY-1    : 0]    wr_pos;
  logic                                 hit;
  logic         [SET_AMOUNT-1    :0]    hit_arr;
  logic                                 dirty_ins;
  logic         [BLOCK_AMOUNT-1 : 0]    pos;

  logic                                 dirty_blockage;
  logic                                 no_blockage;
  logic                                 mem_blockage;
  logic         [DATA_WIDTH-1   : 0]    write_data;
  logic         [DATA_WIDTH-1   : 0]    temp_data;

  logic                                 lru_strobe;
  logic                                 lru_ready;

  logic                                 fifo_push;
  logic                                 fifo_pop;
  logic                                 full;
  logic                                 empty;
  logic         [FIFO_WIDTH_EX-1 :0]    fifo_data;
  logic                                 valid_transaction;

  logic                                 next_transaction;
  logic         [DATA_WIDTH-1   : 0]    data;
  logic         [ADDR_WIDTH-1   : 0]    addr;
  logic         [DATA_BYTES-1   : 0]    strb;
  logic                                 mode;
  logic                                 load;
  logic                                 write;
  logic                                 read;

  //--------------------------
  //        TRANSACTION RECIEVER LOGIC
  //--------------------------

  assign fifo_push = valid_s_i && cache2cpu_ready_o;
  assign fifo_pop  = !empty && next_transaction;

  fifo #(
    .DATA_WIDTH(FIFO_WIDTH_EX),
    .FIFO_DEPTH(CPU_ADDR_DEPTH)
  ) i_cpu_transaction_2_cache_fifo(
    .clk_i   ( aclk_i             ),
    .rstn_i  ( arstn_i            ),
    .data_i  ( transaction_data_i ),
    .push_i  ( fifo_push          ),
    .full_o  ( full               ),
    .data_o  ( fifo_data          ),
    .pop_i   ( fifo_pop           ),
    .empty_o ( empty              )
  );

  assign valid_transaction = !empty;
  assign addr              = fifo_data[ADDR_MSB : ADDR_LSB];
  assign data              = fifo_data[DATA_MSB : DATA_LSB];
  assign strb              = fifo_data[STRB_MSB : STRB_LSB];
  assign mode              = fifo_data[MODE_MSB : MODE_LSB];
  assign load              = fifo_data[LOAD_MSB : LOAD_LSB];

  assign tag               = addr[ADDR_WIDTH-1 : TAG_OFFSET];
  assign set               = addr[TAG_OFFSET-1 : SET_OFFSET];

  assign pre_tag           = pre_addr_i[ADDR_WIDTH-1 : TAG_OFFSET];
  assign pre_set           = pre_addr_i[TAG_OFFSET-1 : SET_OFFSET];

  assign pre_addr          = block[set][wr_pos].tag;

  //--------------------------
  //        FSM LOGIC
  //--------------------------
  // There are 4 states in FSM [IDLE, WAIT, WRITE, READ]
  // IDLE  - waiting for transaction to come
  // WAIT  - waiting data from MEM or for WB readiness when write/read with push of dirty data
  // READ  - reading from cache mem and setting data for CPU
  // WRITE - writing to the cache mem from CPU
  //                    ┌───────────┐
  //         ┌─────────>┤   IDLE    ├<───────────┐
  //         │          └─────┬─────┘            │
  //         │                │                  │
  //         v                v                  v
  // ┌───────────────┐   ┌───────────┐   ┌───────────────┐
  // │    WRITE      │<──┤   WAIT    ├──>│     READ      │
  // └───────────────┘   └───────────┘   └───────────────┘

  assign mem_blockage   = load && !valid_m_i;
  assign dirty_blockage = dirty_ins && !wb_ready_i;
  assign no_blockage    = !mem_blockage && !dirty_blockage && valid_transaction;

  typedef enum logic[1:0] {IDLE, WRITE, READ, WAIT} state_t;
  state_t state, next_state;

  always_ff @(posedge aclk_i or negedge arstn_i) begin
    if( !arstn_i )
      state <= IDLE;
    else
      state <= next_state;
  end

  //--------------------------NEXT STATE CHOOSING LOGIC--------------------------

  always_comb begin
    case(state)
      IDLE: begin
        if      ((load || dirty_blockage) && valid_transaction && lru_ready) next_state = WAIT;
        else if (!load && mode && valid_transaction && lru_ready)            next_state = WRITE;
        else if (!load && !mode && valid_transaction && lru_ready)           next_state = READ;
        else                                                                 next_state = IDLE;
      end
      WRITE: next_state = IDLE;
      READ:  begin
        if (cpu2cache_ready_i)         next_state = IDLE;
        else                           next_state = READ;
      end
      WAIT: begin
        if      (!mode && no_blockage) next_state = READ;
        else if (mode && no_blockage)  next_state = WRITE;
        else                           next_state = WAIT;
      end
      default: next_state = IDLE;
    endcase
  end

  //--------------------------NEXT STATE SIGNALS LOGIC--------------------------

  always_comb begin
    next_transaction  = '0;
    lru_strobe        = '0;
    case(next_state)
      IDLE: begin
        next_transaction = valid_transaction && (state inside {WRITE, READ});
      end
      WRITE: begin
        lru_strobe = '1;
      end
      READ: begin
        lru_strobe = '1;
      end
    endcase
  end

  //--------------------------
  //        LRU LOGIC
  //--------------------------
  // Logic to chose which block to push.

  assign matrix_vec = matrix_vec_i;

  lru i_lru (
    .clk_i                ( aclk_i               ),
    .rstn_i               ( arstn_i              ),

    .block_num_i          ( set_hit[set]         ),
    .set_num_i            ( set                  ),
    .strobe_i             ( lru_strobe           ),
    .hit_i                ( hit                  ),

    .matrix_vec_i         ( matrix_vec           ),
    .matrix_addr_o        ( matrix_addr          ),
    .write_vec_o          ( write_vec            ),
    .updated_matrix_vec_o ( updated_matrix_vec   ),

    .push_block_vec_o     ( push_block_vec       ),
    .ready_o              ( lru_ready            )
  );

  //--------------------------
  //        HIT LOGIC
  //--------------------------
  // hit_o is active when tag from address matches with tag from any block of chosen set.
  // Otherwise, hit_o is low.
  // set_hit is used to determine which block's tag match with address tag

  always_comb begin
    for ( int i = 0; i < SET_AMOUNT; i++ ) begin
      for ( int j = 0; j < BLOCK_AMOUNT; j++ ) begin
        pre_hit[i][j] = ( pre_tag == block[i][j].tag ) && block[i][j].valid && ( pre_set == i );
      end
      pre_hit_arr[i] = |pre_hit[i];
    end
  end

  assign pre_hit_o = |pre_hit_arr;

  always_comb begin
    for ( int i = 0; i < SET_AMOUNT; i++ ) begin
      for ( int j = 0; j < BLOCK_AMOUNT; j++ ) begin
        set_hit[i][j] = ( tag == block[i][j].tag ) && block[i][j].valid && ( set == i );
      end
      hit_arr[i] = |set_hit[i];
    end
  end

  assign hit = |hit_arr;

  //--------------------------
  //        WR_POS LOGIC
  //--------------------------
  // Logic of converting 1-hot to number.
  // Position is choosing by hit flag. If it raised then we already have data in cache and we will work with it.
  // If it omitted then we will work with block chosen by LRU.

  assign pos = (hit) ? set_hit[set] : push_block_vec;

  always_comb begin
    wr_pos = '0;
      for (int i = 0; i < BLOCK_AMOUNT; i++) begin
        wr_pos |= (BLOCK_ANY)'($unsigned(i)) & {BLOCK_ANY{pos[i]}};
      end
    end

  //--------------------------
  //        DIRTY LOGIC
  //--------------------------
  // This signal shows if the data must be sent to write back buffer or not.

  assign dirty_ins = block[set][wr_pos].dirty && !set_hit[set][wr_pos] && block[set][wr_pos].valid;

  //--------------------------
  //        BLOCK_FF LOGIC
  //--------------------------
  // There are two situations for filling fields in block.
  // One is for READ transaction. In this case we rise up validness flag and write tag of our data.
  // Also the dirty flag is omitted if it was raised before.
  // Another is for WRITE transaction. In this case we rise up validness and dirty flags and write tag of our data.

  always_ff @( posedge aclk_i or negedge arstn_i ) begin
    if ( !arstn_i ) begin
      for (int i = 0; i < SET_AMOUNT; i++) begin
          for (int j = 0; j < BLOCK_AMOUNT; j++) begin
              block[i][j].valid <= 1'b0;
          end
      end
    end
    else if (dirty_o) begin
      block[set][wr_pos].valid <= '0;;
    end
    else if (tech_data_we_o) begin
      block[set][wr_pos] <= '{valid: 1'b1, dirty: write, tag: tag};
    end
  end

  assign temp_data = (load) ? mem_data_i : tech_data_i;

  generate
    for(genvar i = 0; i < DATA_BYTES; i++) begin
      assign write_data[(i+1)*8-1:i*8] = temp_data[(i+1)*8-1:i*8] & {8{!strb[i]}} | data[(i+1)*8-1:i*8] & {8{strb[i]}};
    end
  endgenerate

  //--------------------------
  //        OUTPUT LOGIC
  //--------------------------

  assign write = state == WRITE;
  assign read  = state == READ;

  assign tech_data_we_o       = write || (next_state == READ && load);
  assign tech_data_o          = (!write) ? mem_data_i : write_data;
  assign tech_data_addr_o     = {set,wr_pos};
  assign cache2cpu_ready_o    = !full;
  assign dirty_o              = wb_ready_i && dirty_ins && state == WAIT;
  assign valid_o              = read;
  assign data_o               = tech_data_i;
  assign wb_addr_o            = {pre_addr,set,SET_OFFSET'(0)};
  assign matrix_addr_o        = matrix_addr;
  assign write_vec_o          = write_vec;
  assign updated_matrix_vec_o = updated_matrix_vec;
  assign cache2mem_ready_o    = !dirty_blockage && load && (state == WAIT || next_state == WAIT);

endmodule
