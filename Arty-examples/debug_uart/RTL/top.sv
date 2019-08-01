module top(  // this example connect a debug_uart to BRAM
    input  logic clk_100M,
    input  logic btn0,
    input  logic uart_rx,
    output logic uart_tx
);

logic wreq, wgnt;
logic [ 8-1:0] waddr;
logic [32-1:0] wdata;
logic rreq, rgnt;
logic [ 8-1:0] raddr;
logic [32-1:0] rdata;

debug_uart #(  // this module convert  UART command to bus read/write request
    .UART_RX_CLK_DIV  ( 217      ), // 100MHz/4/115200Hz=217
    .UART_TX_CLK_DIV  ( 868      ), // 100MHz/1/115200Hz=868
    .ADDR_BYTE_WIDTH  ( 1        ), // addr width = 1byte( 8bit)
    .DATA_BYTE_WIDTH  ( 4        ), // data width = 4byte(32bit)
    .READ_IMM         ( 0        )  // 0: read after rgnt : Capture rdata in the next clock cycle of rgnt=1
) debug_uart_i (
    .clk              ( clk_100M ),
    .rst_n            ( ~btn0    ),
    
    .wreq             ( wreq     ),
    .wgnt             ( wgnt     ),
    .waddr            ( waddr    ),
    .wdata            ( wdata    ),
    
    .rreq             ( rreq     ),
    .rgnt             ( rgnt     ),
    .raddr            ( raddr    ),
    .rdata            ( rdata    ),
    
    .uart_tx          ( uart_tx  ),
    .uart_rx          ( uart_rx  )
);

ram #( // a 8bit address width, 32bit data width BRAM
    .ADDR_LEN ( 8        ),
    .DATA_LEN ( 32       )
) ram_i (
    .clk      ( clk_100M ),
    .wr_req   ( wreq     ),
    .wr_addr  ( waddr    ),
    .wr_data  ( wdata    ),
    .rd_addr  ( raddr    ),
    .rd_data  ( rdata    )
);

assign rgnt = rreq; // read always ready
assign wgnt = wreq; // write always ready

endmodule
