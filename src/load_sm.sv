`timescale 1ns / 1ps
module load_sm
import cache_pkg::*;
(
input  logic                      clk_i,
input  logic                      rstn_i,

output logic                      ready_o,
output logic [MATRIX_WIDTH-1 : 0] vect_o,
output logic                      sel_o,
output logic                      we_o,
output logic [SET_BITS-1     : 0] addr_o
    );

typedef enum logic {IDLE,RUN} state_t;

state_t next_state, state;

logic [SET_BITS : 0] cnt_ff;
logic [SET_BITS : 0] cnt_next;
logic [1        : 0] rst_ff;
logic                sync_rst;

always_ff @(posedge clk_i or negedge rstn_i) begin
  if(!rstn_i) rst_ff <= '1;
  else begin
    rst_ff[0] <= !rstn_i;
    rst_ff[1] <= rst_ff[0];
  end
end

assign sync_rst = rst_ff[1] & ~rst_ff[0];

always_ff @(posedge clk_i or negedge rstn_i) begin
  if(!rstn_i) state <= IDLE;
  else state <= next_state;
end

always_comb begin
  next_state = state;
  case(state)
    IDLE : next_state = (sync_rst) ? RUN : IDLE;
    RUN  : next_state = (cnt_next < SET_AMOUNT ) ? RUN : IDLE;
  endcase
end

assign cnt_next = cnt_ff + 1'b1;

always_ff @(posedge clk_i or negedge rstn_i) begin
  if(!rstn_i) cnt_ff <= '0;
  else if(state == RUN) begin
    cnt_ff <= cnt_next;
  end
end

assign addr_o  = cnt_ff;
assign sel_o   = state == RUN;
assign we_o    = state == RUN;
assign vect_o  = '1;
assign ready_o = cnt_ff == (SET_AMOUNT) && state == IDLE;

endmodule
