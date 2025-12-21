package cache_struct_pkg;
import cache_pkg::*;

localparam TAG_WIDTH = ADDR_WIDTH - $clog2(DATA_WIDTH/8) - SET_BITS;

typedef struct {
  logic                  valid;
  logic [ADDR_WIDTH-1:0] addr;
  logic [DATA_WIDTH-1:0] data;
} wb_block_t;

typedef struct {
  logic                 valid;
  logic                 dirty;
  logic [TAG_WIDTH-1:0] tag;
} cache_block_t;

endpackage