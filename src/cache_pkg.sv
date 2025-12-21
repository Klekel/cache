package cache_pkg;

localparam SET_BITS          = 1;
localparam BLOCK_BITS        = 1;
localparam BUFFER_DEPTH_BITS = 2;
localparam DATA_WIDTH        = 32;
localparam ADDR_WIDTH        = 32;
localparam CPU_ADDR_BUF      = 2;
localparam CPU_ADDR_DEPTH    = 2**CPU_ADDR_BUF;
localparam DATA_BYTES        = DATA_WIDTH/8;
localparam TECH_ADDR_WIDTH   = SET_BITS + BLOCK_BITS;
localparam BLOCK_AMOUNT      = 2**BLOCK_BITS;
localparam MATRIX_WIDTH      = BLOCK_AMOUNT*(BLOCK_AMOUNT-1)/2;
localparam SET_AMOUNT        = 2**SET_BITS;
localparam FIFO_WIDTH        = DATA_WIDTH + ADDR_WIDTH + 1 + DATA_BYTES;
localparam FIFO_WIDTH_EX     = FIFO_WIDTH + 1;

localparam SET_ANY           = (SET_BITS == 0)   ? 1 : SET_BITS;
localparam BLOCK_ANY         = (BLOCK_BITS == 0) ? 1 : BLOCK_BITS;

localparam LOAD_LSB = 0;
localparam LOAD_MSB = LOAD_LSB;
localparam MODE_LSB = LOAD_LSB + 1;
localparam MODE_MSB = MODE_LSB;
localparam STRB_LSB = MODE_MSB + 1;
localparam STRB_MSB = STRB_LSB + DATA_BYTES - 1;
localparam DATA_LSB = STRB_MSB + 1;
localparam DATA_MSB = DATA_LSB + DATA_WIDTH - 1;
localparam ADDR_LSB = DATA_MSB + 1;
localparam ADDR_MSB = ADDR_LSB + ADDR_WIDTH - 1;

endpackage