module fifo #(
  parameter DATA_WIDTH = 32,
  parameter FIFO_DEPTH = 4
)(
  input  logic                  clk_i,
  input  logic                  rstn_i,

  input  logic [DATA_WIDTH-1:0] data_i,
  input  logic                  push_i,
  output logic                  full_o,

  output logic [DATA_WIDTH-1:0] data_o,
  input  logic                  pop_i,
  output logic                  empty_o
);

localparam PTR_WIDTH = $clog2(FIFO_DEPTH);

  logic [PTR_WIDTH  :0] read_pointer_n;
  logic [PTR_WIDTH  :0] read_pointer_q;
  logic [PTR_WIDTH  :0] write_pointer_n;
  logic [PTR_WIDTH  :0] write_pointer_q;
  logic [DATA_WIDTH-1:0] mem_q [FIFO_DEPTH-1:0];

  assign read_pointer_n  = read_pointer_q + (pop_i && ~empty_o);

  always_ff @(posedge clk_i or negedge rstn_i) begin
    if(~rstn_i) read_pointer_q  <= '0;
    else        read_pointer_q  <= read_pointer_n;
  end

  assign write_pointer_n =  write_pointer_q + (push_i && ~full_o);

  always_ff @(posedge clk_i or negedge rstn_i) begin
    if(~rstn_i) write_pointer_q <= '0;
    else        write_pointer_q <= write_pointer_n;
  end

  always_ff @(posedge clk_i) begin
    if ( push_i && ~full_o ) mem_q[write_pointer_q[PTR_WIDTH-1:0]] <= data_i;
  end

  assign empty_o = write_pointer_q == read_pointer_q;
  assign full_o  = {!write_pointer_q[PTR_WIDTH],write_pointer_q[PTR_WIDTH-1:0]} == {read_pointer_q[PTR_WIDTH],read_pointer_q[PTR_WIDTH-1:0]};

  assign data_o  = ( empty_o ) ? '0 : mem_q[read_pointer_q[PTR_WIDTH-1:0]];

endmodule
