module rst_sync(
  input  logic aclk_i,
  input  logic arstn_i,

  output logic arstn_sync_o
);

  logic [1:0] sync;

  always_ff @(posedge aclk_i or negedge arstn_i) begin
    if(!arstn_i) sync <= '0;
    else begin
      sync[0] <= 1;
      sync[1] <= sync[0];
    end
  end

  assign arstn_sync_o = sync[1];

endmodule