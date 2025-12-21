module tb_cache();
import cache_pkg::*;

  logic                        clk;
  logic                        rstn;
  logic                        valid_s;
  logic [FIFO_WIDTH_EX-1  :0]  transaction_data;
  logic                        cache2cpu_ready;
  logic                        valid_m;
  logic [DATA_WIDTH-1     :0]  mem_data;
  logic                        cache2mem_ready;
  logic                        valid;
  logic [DATA_WIDTH-1     :0]  data;
  logic                        cpu2cache_ready;
  logic                        wb_ready;
  logic                        dirty;
  logic [ADDR_WIDTH-1     :0]  wb_addr;
  logic [ADDR_WIDTH-1     :0]  pre_addr;
  logic                        pre_hit;
  logic [TECH_ADDR_WIDTH-1:0]  tech_data_addr;
  logic                        tech_data_we;
  logic [DATA_WIDTH-1     :0]  tech_data_in;
  logic [DATA_WIDTH-1     :0]  tech_data_out;
  logic [MATRIX_WIDTH-1   :0]  matrix_vec;
  logic [SET_BITS-1       :0]  matrix_addr;
  logic                        write_vec;
  logic [MATRIX_WIDTH-1   :0]  updated_matrix_vec;

  initial begin
    forever begin
      #10 clk = ~clk;
    end
  end

  task reset();
    clk              <= '0;
    rstn             <= '0;
    valid_s          <= '0;
    transaction_data <= '0;
    valid_m          <= '1;
    mem_data         <= '0;
    cpu2cache_ready  <= '1;
    wb_ready         <= '1;
    pre_addr         <= '0;
    repeat(5)@(posedge clk);
    rstn             <= '1;
  endtask

  task write_transaction(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb, input logic wr_r, input logic load);
    valid_s           <= '1;
    transaction_data  <= {addr,data,strb,wr_r,load};
    do
      @(posedge clk);
    while(!cache2cpu_ready);
    valid_s           <= '0;
  endtask

  task temporari_valid();
    valid_m <= '0;
    for (int i = 0; i < 10; i++) begin
      @(posedge clk);
    end
    valid_m <= '1;
    @(posedge clk);
  endtask

  task psevdo_fifo();
    mem_data <= $urandom();
    wait(cache2mem_ready && valid_m);
    @(posedge clk);
  endtask

  assign pre_addr = transaction_data[ADDR_MSB : ADDR_LSB];

  cache i_cache (
    .aclk_i               ( clk                ),
    .arstn_i              ( rstn               ),

    .valid_s_i            ( valid_s            ),
    .transaction_data_i   ( transaction_data   ),
    .cache2cpu_ready_o    ( cache2cpu_ready    ),

    .valid_m_i            ( valid_m            ),
    .mem_data_i           ( mem_data           ),
    .cache2mem_ready_o    ( cache2mem_ready    ),

    .valid_o              ( valid              ),
    .data_o               ( data               ),
    .cpu2cache_ready_i    ( cpu2cache_ready    ),

    .wb_ready_i           ( wb_ready           ),
    .dirty_o              ( dirty              ),
    .wb_addr_o            ( wb_addr            ),

    .pre_addr_i           ( pre_addr           ),
    .pre_hit_o            ( pre_hit            ),

    .tech_data_addr_o     ( tech_data_addr     ),
    .tech_data_we_o       ( tech_data_we       ),
    .tech_data_i          ( tech_data_in       ),
    .tech_data_o          ( tech_data_out      ),

    .matrix_vec_i         ( matrix_vec         ),
    .matrix_addr_o        ( matrix_addr        ),
    .write_vec_o          ( write_vec          ),
    .updated_matrix_vec_o ( updated_matrix_vec )
  );

    bram #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(TECH_ADDR_WIDTH)
  )i_cache_mem(
    .clk_i  ( clk                ),
    .addr_i ( tech_data_addr     ),
    .data_i ( tech_data_out      ),
    .we_i   ( tech_data_we       ),
    .en_i   ( '1                 ),
    .data_o ( tech_data_in       )
  );

  bram #(
    .DATA_WIDTH(MATRIX_WIDTH),
    .ADDR_WIDTH(SET_BITS)
  )i_lru_mem(
    .clk_i  ( clk                ),
    .addr_i ( matrix_addr        ),
    .data_i ( updated_matrix_vec ),
    .we_i   ( write_vec          ),
    .en_i   ( '1                 ),
    .data_o ( matrix_vec         )
  );

  initial begin
    reset();
    repeat(10) @(posedge clk);
    write_transaction(.addr(32'd0),    .data('1), .strb(4'b1101), .wr_r(1'b1), .load(1'b1));
    write_transaction(.addr(32'd0),    .data('1), .strb(4'b1101), .wr_r(1'b0), .load(1'b0));
    write_transaction(.addr(32'd3*4),  .data('1), .strb(4'b1101), .wr_r(1'b0), .load(1'b1));
    write_transaction(.addr(32'd5*4),  .data('1), .strb(4'b1101), .wr_r(1'b0), .load(1'b0));
    write_transaction(.addr(32'd6*4),  .data('1), .strb(4'b1101), .wr_r(1'b0), .load(1'b0));
    write_transaction(.addr(32'd0),    .data('0), .strb(4'b0001), .wr_r(1'b1), .load(1'b0));
    write_transaction(.addr(32'd1*32), .data('1), .strb(4'b0001), .wr_r(1'b1), .load(1'b1));
    write_transaction(.addr(32'd2*32), .data('1), .strb(4'b0001), .wr_r(1'b0), .load(1'b1));
    write_transaction(.addr(32'd3*32), .data('1), .strb(4'b0001), .wr_r(1'b0), .load(1'b1));
    write_transaction(.addr(32'd4*32), .data('1), .strb(4'b0001), .wr_r(1'b1), .load(1'b1));
    write_transaction(.addr(32'd5*32), .data('1), .strb(4'b0001), .wr_r(1'b1), .load(1'b1));
  end

  initial begin
    forever begin
      fork
        temporari_valid();
        psevdo_fifo();
      join
    end
  end

endmodule