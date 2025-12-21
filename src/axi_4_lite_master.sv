module axi_4_lite_master
import cache_pkg::*;
(
  input  logic                   aclk_i,
  input  logic                   arstn_i,

  input  logic                   awready_i,
  output logic                   awvalid_o,
  output logic [ADDR_WIDTH-1 :0] awaddr_o,
  output logic [2            :0] awprot_o,

  input  logic                   wready_i,
  output logic                   wvalid_o,
  output logic [DATA_WIDTH-1 :0] wdata_o,
  output logic [DATA_BYTES-1 :0] wstrb_o,

  input  logic                   bvalid_i,
  input  logic [1            :0] bresp_i,
  output logic                   bready_o,

  input  logic                   arready_i,
  output logic                   arvalid_o,
  output logic [ADDR_WIDTH-1 :0] araddr_o,
  output logic [2            :0] arprot_o,

  input  logic                   rvalid_i,
  input  logic [DATA_WIDTH-1 :0] rdata_i,
  input  logic [1            :0] rresp_i,
  output logic                   rready_o,

  input  logic                   wb_valid_i,
  input  logic [DATA_WIDTH-1:0]  wb_data_i,
  input  logic [ADDR_WIDTH-1:0]  wb_addr_i,
  output logic                   mem_ready_o,

  output logic [DATA_WIDTH-1:0]  mem_data_o,
  output logic                   mem_valid_o,
  input  logic                   mem_ready_i,

  input  logic                   addr_req_i,
  output logic                   addr_ready_o,
  input  logic [ADDR_WIDTH-1 :0] addr_i
);

  logic                    axi_w_full;
  logic                    axi_aw_full;

  logic                    axi_w_empty;
  logic                    axi_aw_empty;

  logic                    axi_w_pop;
  logic                    axi_aw_pop;

  logic                    axi_w_push;
  logic                    axi_aw_push;

  logic                    axi_mem_push;
  logic                    axi_mem_pop;

  logic                    axi_mem_full;
  logic                    axi_mem_empty;
  logic [ADDR_WIDTH-1:0]   aw_addr;
  logic [DATA_WIDTH-1:0]   w_data;

  assign axi_mem_push = rvalid_i && rready_o;
  assign axi_mem_pop  = mem_valid_o && mem_ready_i;

  fifo #(
    .DATA_WIDTH(DATA_WIDTH),
    .FIFO_DEPTH(CPU_ADDR_DEPTH)
  )i_mem2cache(
    .clk_i   ( aclk_i        ),
    .rstn_i  ( arstn_i       ),
    .data_i  ( rdata_i       ),
    .push_i  ( axi_mem_push  ),
    .full_o  ( axi_mem_full  ),
    .data_o  ( mem_data_o    ),
    .pop_i   ( axi_mem_pop   ),
    .empty_o ( axi_mem_empty )
  );

  assign axi_w_push = wb_valid_i && mem_ready_o && ((!wready_i && awready_i) || (!axi_w_empty && !axi_w_full));
  assign axi_w_pop  = !axi_w_empty && wready_i;

  fifo #(
    .DATA_WIDTH( DATA_WIDTH     ),
    .FIFO_DEPTH( CPU_ADDR_DEPTH )
  )i_cache_w_2mem(
    .clk_i   ( aclk_i        ),
    .rstn_i  ( arstn_i       ),
    .data_i  ( wb_data_i     ),
    .push_i  ( axi_w_push    ),
    .full_o  ( axi_w_full    ),
    .data_o  ( w_data        ),
    .pop_i   ( axi_w_pop     ),
    .empty_o ( axi_w_empty   )
  );

  assign axi_aw_push = wb_valid_i && mem_ready_o && ((wready_i && !awready_i) || (!axi_aw_empty && !axi_aw_full));
  assign axi_aw_pop  = !axi_aw_empty && awready_i;

  fifo #(
    .DATA_WIDTH( ADDR_WIDTH     ),
    .FIFO_DEPTH( CPU_ADDR_DEPTH )
  )i_cache_aw_2mem(
    .clk_i   ( aclk_i        ),
    .rstn_i  ( arstn_i       ),
    .data_i  ( wb_addr_i     ),
    .push_i  ( axi_aw_push   ),
    .full_o  ( axi_aw_full   ),
    .data_o  ( aw_addr       ),
    .pop_i   ( axi_aw_pop    ),
    .empty_o ( axi_aw_empty  )
  );

  assign mem_ready_o  = (!axi_w_full && !axi_aw_full) && (wready_i || awready_i);
  assign awvalid_o    = !axi_aw_empty || (wb_valid_i && (!axi_w_full && !axi_aw_full));
  assign wvalid_o     = !axi_w_empty || (wb_valid_i && (!axi_w_full && !axi_aw_full));
  assign awprot_o     = 3'b010;
  assign wstrb_o      = '1;
  assign rready_o     = !axi_mem_full;
  assign mem_valid_o  = !axi_mem_empty;
  assign arprot_o     = 3'b010;
  assign addr_ready_o = arready_i;
  assign arvalid_o    = addr_req_i;
  assign araddr_o     = addr_i;
  assign bready_o     = '1;
  assign awaddr_o     = (axi_aw_empty) ? wb_addr_i : aw_addr;
  assign wdata_o      = (axi_w_empty) ? wb_data_i : w_data;

endmodule