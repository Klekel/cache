module tb_fifo();

logic clk;
logic rstn_i;
logic [32-1:0] data_i;
logic [32-1:0] data_o;
logic full;
logic empty;

logic push;
logic pop;

initial forever #10 clk = !clk;

fifo dut(
  .clk_i   ( clk ),
  .rstn_i  ( rstn_i ),
  .data_i  ( data_i ),
  .push_i  ( push ),
  .full_o  ( full ),
  .data_o  ( data_o ),
  .pop_i   ( pop ),
  .empty_o ( empty )
);

task full_fifo();
  for (int i =0; i < 5; i++) begin
    push <= '1;
    data_i <= $urandom();
    @(posedge clk);
    push <= '0;
  end
endtask

initial begin
clk  <= '0;
rstn_i  <= '0;
pop  <= '0;
push <= '0;
@(posedge clk);
rstn_i  <= '1;
@(posedge clk);
full_fifo();
@(posedge clk);
pop  <= '1;

end


endmodule