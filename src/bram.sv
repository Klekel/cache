module bram#(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 5
)
(
  input  logic                   clk_i,
  input  logic [ADDR_WIDTH-1 :0] addr_i,
  input  logic [DATA_WIDTH-1 :0] data_i,
  input  logic                   we_i,
  input  logic                   en_i,
  output logic [DATA_WIDTH-1 :0] data_o
);

  localparam RAM_DEPTH = 2**ADDR_WIDTH;

  logic [DATA_WIDTH-1:0] bram [RAM_DEPTH-1:0];
  logic [DATA_WIDTH-1:0] data_out_ff;

  always_ff @(posedge clk_i) begin
    if (en_i) begin
      if (we_i) begin
        bram[addr_i] <= data_i;
        data_out_ff  <= data_i;
      end else
        data_out_ff <= bram[addr_i];
    end
  end

  assign data_o = data_out_ff;

endmodule
