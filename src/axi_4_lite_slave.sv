module axi_4_lite_slave
import cache_pkg::*;
(
  input  logic                   aclk_i,
  input  logic                   arstn_i,
// ==================== AW =================
  output logic                   awready_o,
  input  logic                   awvalid_i,
  input  logic [ADDR_WIDTH-1 :0] awaddr_i,
  input  logic [2            :0] awprot_i,
// ==================== W ==================
  output logic                   wready_o,
  input  logic                   wvalid_i,
  input  logic [DATA_WIDTH-1 :0] wdata_i,
  input  logic [DATA_BYTES-1 :0] wstrb_i,
// ==================== B ==================
  output logic                   bvalid_o,
  output logic [1            :0] bresp_o,
  input  logic                   bready_i,
// ==================== AR =================
  output logic                   arready_o,
  input  logic                   arvalid_i,
  input  logic [ADDR_WIDTH-1 :0] araddr_i,
  input  logic [2            :0] arprot_i,
// ==================== R ==================
  output logic                   rvalid_o,
  output logic [DATA_WIDTH-1 :0] rdata_o,
  output logic [1            :0] rresp_o,
  input  logic                   rready_i,

  // cache interface

  output logic [FIFO_WIDTH-1 :0] data_pkt_o,
  output logic                   valid_pkt_o,
  input  logic                   ready_pkt_i,

  output logic                   cpu_ready_o,
  input  logic [DATA_WIDTH-1 :0] cache_data_i,
  input  logic                   cache_valid_i
);

  logic [CPU_ADDR_BUF : 0] b_cnt_ff;
  logic [CPU_ADDR_BUF : 0] b_cnt_next;

  logic [ADDR_WIDTH-1 :0] addr;
  logic [ADDR_WIDTH-1 :0] awadr_ff;

  logic [DATA_WIDTH-1 :0] wdata;
  logic [DATA_WIDTH-1 :0] wdata_ff;

  logic [DATA_BYTES-1 :0] w_strb;
  logic [DATA_BYTES-1 :0] wstrb_ff;

  logic                   w_valid;
  logic                   w_valid_ff;

  logic                   aw_valid;
  logic                   aw_valid_ff;

  logic                   in_full;
  logic                   in_empty;
  logic                   in_pop;
  logic                   in_push;
  logic [FIFO_WIDTH-1 :0] in_data;

  logic                   out_full;
  logic                   out_empty;
  logic                   out_pop;
  logic                   out_push;
  logic [DATA_WIDTH-1 :0] out_data;

  logic                   write_after_addr;
  logic                   addr_after_write;
  logic                   addr_and_write;
  logic                   write_trans;

  assign write_after_addr = (aw_valid_ff && wvalid_i && wready_o);
  assign write_befor_addr = !aw_valid_ff && (wvalid_i && wready_o && !(awvalid_i && awready_o));
  assign addr_after_write = (w_valid_ff && awvalid_i && awready_o);
  assign addr_befor_write = !w_valid_ff && (awvalid_i && awready_o && !(wvalid_i && wready_o));
  assign addr_and_write   = (awvalid_i && awready_o && wvalid_i && wready_o);

  assign write_trans      = write_after_addr || addr_and_write || addr_after_write;

  assign b_cnt_next       = (write_trans && bvalid_o && bready_i) ? b_cnt_ff :
                            (bvalid_o && bready_i) ?          b_cnt_next - 1 :
                            (write_trans) ?                   b_cnt_next + 1 :
                                                                     b_cnt_ff;

  always_ff @(posedge aclk_i or negedge arstn_i) begin
    if(!arstn_i) b_cnt_ff <= '0;
    else b_cnt_ff <= b_cnt_next;
  end

  always_ff @(posedge aclk_i) begin
    if (addr_befor_write) awadr_ff <= awaddr_i;
  end

  always_ff @(posedge aclk_i) begin
    if (write_befor_addr) wdata_ff <= wdata_i;
  end

  always_ff @(posedge aclk_i) begin
    if (write_befor_addr) wstrb_ff <= wstrb_i;
  end

  always_ff @(posedge aclk_i) begin
    if      (!arstn_i)         w_valid_ff <= '0;
    else if (write_befor_addr) w_valid_ff <= wvalid_i;
    else if (addr_after_write) w_valid_ff <= '0;
  end

  always_ff @(posedge aclk_i) begin
    if (!arstn_i)              aw_valid_ff <= '0;
    else if (addr_befor_write) aw_valid_ff <= awvalid_i;
    else if (write_after_addr) aw_valid_ff <= '0;
  end

  assign addr     = (addr_after_write || addr_and_write) ? awaddr_i : awadr_ff;
  assign wdata    = (write_after_addr || addr_and_write) ? wdata_i : wdata_ff;
  assign w_strb   = (write_after_addr || addr_and_write) ? wstrb_i : wstrb_ff;
  assign w_valid  = (write_after_addr || addr_and_write) ? wvalid_i : w_valid_ff;
  assign aw_valid = (addr_after_write || addr_and_write) ? awvalid_i : aw_valid_ff;

  assign in_data = (arready_o && arvalid_i) ? {araddr_i,(DATA_WIDTH)'(0),(DATA_BYTES)'(0),1'b0} : {addr,wdata,w_strb,1'b1};
  assign in_push = (arready_o && arvalid_i) || (aw_valid && w_valid) && !in_full;
  assign in_pop  = (ready_pkt_i && valid_pkt_o);

  fifo #(
    .DATA_WIDTH( FIFO_WIDTH     ),
    .FIFO_DEPTH( CPU_ADDR_DEPTH )
  )i_axi2cache(
    .clk_i   ( aclk_i     ),
    .rstn_i  ( arstn_i    ),
    .data_i  ( in_data    ),
    .push_i  ( in_push    ),
    .full_o  ( in_full    ),
    .data_o  ( data_pkt_o ),
    .pop_i   ( in_pop     ),
    .empty_o ( in_empty   )
  );

  assign out_push = cache_valid_i && !out_full;
  assign out_data = cache_data_i;
  assign out_pop  = rready_i && rvalid_o;

  fifo #(
    .DATA_WIDTH( DATA_WIDTH     ),
    .FIFO_DEPTH( CPU_ADDR_DEPTH )
  )i_cache2axi(
    .clk_i   ( aclk_i    ),
    .rstn_i  ( arstn_i   ),
    .data_i  ( out_data  ),
    .push_i  ( out_push  ),
    .full_o  ( out_full  ),
    .data_o  ( rdata_o   ),
    .pop_i   ( out_pop   ),
    .empty_o ( out_empty )
  );

  assign rresp_o     = 2'b00;
  assign bresp_o     = 2'b00;
  assign awready_o   = !aw_valid_ff && !in_full;
  assign wready_o    = !w_valid_ff && !in_full;
  assign arready_o   = !(awvalid_i || wvalid_i || aw_valid_ff || w_valid_ff) && !in_full;
  assign valid_pkt_o = !in_empty;
  assign cpu_ready_o = !out_full;
  assign rvalid_o    = !out_empty;
  assign bvalid_o    = b_cnt_ff != 0;

endmodule