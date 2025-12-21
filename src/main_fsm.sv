module main_fsm
import cache_pkg::*;
(
  input  logic                     aclk_i,
  input  logic                     arstn_i,

  input  logic [FIFO_WIDTH-1   :0] data_pkt_i,
  input  logic                     valid_pkt_i,
  output logic                     ready_pkt_o,

  output logic                     addr_req_o,
  output logic [ADDR_WIDTH-1   :0] addr_o,
  input  logic                     addr_ready_i,

  output logic                     valid_s_o,
  output logic [FIFO_WIDTH_EX-1:0] transaction_data_o,
  input  logic                     cache2cpu_ready_i,
  input  logic                     pre_hit_i,

  output logic                     clr_valid_o,
  input  logic                     wb_hit_i,
  input  logic [DATA_WIDTH-1   :0] wb_r_data_i
);

  logic [ADDR_WIDTH-1   :0] addr;
  logic                     load;

  typedef enum logic[2:0] {IDLE, ADDR_REQUEST, COMMON, WB_HIT, WAIT} state_t;
  state_t state, next_state;

  always_ff @(posedge aclk_i or negedge arstn_i) begin
    if( !arstn_i )
      state <= IDLE;
    else
      state <= next_state;
  end

  always_comb begin
    case(state)
      IDLE: begin
        if      (valid_pkt_i && cache2cpu_ready_i && pre_hit_i)  next_state = COMMON;
        else if (valid_pkt_i && !cache2cpu_ready_i && pre_hit_i) next_state = WAIT;
        else if (valid_pkt_i && wb_hit_i && cache2cpu_ready_i)   next_state = WB_HIT;
        else if (valid_pkt_i && !pre_hit_i)                      next_state = ADDR_REQUEST;
        else                                                     next_state = IDLE;
      end
      WB_HIT:  begin
        if   (valid_pkt_i && cache2cpu_ready_i) next_state = COMMON;
        else                                    next_state = WAIT;
      end
      ADDR_REQUEST: begin
        if      (valid_pkt_i && addr_ready_i && cache2cpu_ready_i)  next_state = COMMON;
        else if (valid_pkt_i && addr_ready_i && !cache2cpu_ready_i) next_state = WAIT;
        else                                                        next_state = ADDR_REQUEST;
      end
      COMMON: begin
        if      (valid_pkt_i && cache2cpu_ready_i && pre_hit_i)  next_state = COMMON;
        else if (valid_pkt_i && !cache2cpu_ready_i && pre_hit_i) next_state = WAIT;
        else if (valid_pkt_i && wb_hit_i)                        next_state = WB_HIT;
        else if (valid_pkt_i && !pre_hit_i)                      next_state = ADDR_REQUEST;
        else                                                     next_state = IDLE;
      end
      WAIT:  begin
        if (valid_pkt_i && cache2cpu_ready_i) next_state = COMMON;
        else                                  next_state = WAIT;
      end
      default: next_state = IDLE;
    endcase
  end

  always_comb begin
    valid_s_o        = '0;
    clr_valid_o      = '0;
    ready_pkt_o      = '0;
    case(next_state)
      WB_HIT: begin
        clr_valid_o  = '1;
        valid_s_o    = '1;
      end
      WAIT: begin
        valid_s_o    = '1;
      end
      COMMON: begin
        valid_s_o    = '1;
        ready_pkt_o  = '1;
      end
    endcase
  end

  always_ff @(posedge aclk_i or negedge arstn_i) begin
    if      (!arstn_i)                   load <= '0;
    else if (next_state == ADDR_REQUEST) load <= '1;
    else if (next_state == COMMON)       load <= '0;
  end

  assign addr = data_pkt_i[FIFO_WIDTH-1 -: ADDR_WIDTH];

  assign addr_req_o         = state == ADDR_REQUEST;
  assign addr_o             = addr;
  assign transaction_data_o = (next_state == WB_HIT) ? {addr,wb_r_data_i,(DATA_BYTES)'('1),1'b1,1'b0} : {data_pkt_i, load};

endmodule