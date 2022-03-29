
//--------------------------------------------------------------------------------------------------------
// Module  : tb_debug_uart
// Type    : simulation, top
// Standard: SystemVerilog 2005 (IEEE1800-2005)
// Function: testbench for debug_uart
//--------------------------------------------------------------------------------------------------------

`timescale 1ps/1ps

module tb_debug_uart();


// -----------------------------------------------------------------------------------------------------------------------------
// simulation control
// -----------------------------------------------------------------------------------------------------------------------------
initial $dumpvars(0, tb_debug_uart);
initial #100000000000 $finish;              // simulation for 100ms
         

// -----------------------------------------------------------------------------------------------------------------------------
// generate reset and clock
// -----------------------------------------------------------------------------------------------------------------------------
reg rstn = 1'b0;
reg clk  = 1'b1;
always #(20000) clk = ~clk;   // 25MHz
initial begin repeat(4) @(posedge clk); rstn<=1'b1; end


// -----------------------------------------------------------------------------------------------------------------------------
// UART signal
// -----------------------------------------------------------------------------------------------------------------------------
wire uart_tx;
wire uart_rx;


// -----------------------------------------------------------------------------------------------------------------------------
// UART TX
// -----------------------------------------------------------------------------------------------------------------------------
reg [15:0] tx_data = '0;
reg        tx_en   = '0;
initial begin
    while(1) begin
        repeat(100000) @(posedge clk);
        tx_data <= tx_data + {8'd1, 8'd2};
        tx_en   <= 1'b1;
        @(posedge clk);
        tx_en   <= 1'b0;
    end
end


// -----------------------------------------------------------------------------------------------------------------------------
// UART TX
// -----------------------------------------------------------------------------------------------------------------------------
uart_tx #(
    .CLK_DIV      ( 217           ),   // 25MHz/217 = 115200
    .PARITY       ( "NONE"        ),   // "NONE", "ODD" or "EVEN"
    .ASIZE        ( 3             ),   // Specify tx buffer size
    .DWIDTH       ( 2             ),   // Specify width of tx_data , that is, how many bytes can it input per clock cycle
    .ENDIAN       ( "LITTLE"      ),   // "LITTLE" or "BIG"
    .MODE         ( "HEXSPACE"         ),   // "RAW", "PRINTABLE", "HEX" or "HEXSPACE"
    .END_OF_DATA  ( "\n"          ),
    .END_OF_PACK  ( ""            )
) uart_tx_i (
    .rstn         ( rstn          ),
    .clk          ( clk           ),
    .tx_data      ( tx_data       ),
    .tx_last      ( 1'b0          ),
    .tx_en        ( tx_en         ),
    .tx_rdy       (               ),
    .o_uart_tx    ( uart_rx       )
);



// -----------------------------------------------------------------------------------------------------------------------------
// debug UART
// -----------------------------------------------------------------------------------------------------------------------------
localparam READ_IMM = 0;

wire       wr_en;
wire       wr_rdy = 1'b1;
wire [7:0] wr_addr;
wire [7:0] wr_data;
wire       rd_en;
wire       rd_rdy = 1'b1;
wire [7:0] rd_addr;
logic[7:0] rd_data;

generate if(READ_IMM) begin
    assign rd_data = rd_addr;
end else begin
    always @ (posedge clk)
        if(rd_en & rd_rdy)
            rd_data <= rd_addr;
end endgenerate

debug_uart #(
    .UART_CLK_DIV ( 217           ),   // 25MHz/217 = 115200
    .AWIDTH       ( 1             ),
    .DWIDTH       ( 1             ),
    .WR_TIMEOUT   ( 200           ),
    .RD_TIMEOUT   ( 200           ),
    .READ_IMM     ( READ_IMM      )
) debug_uart_i (
    .rstn         ( rstn          ),
    .clk          ( clk           ),
    .i_uart_rx    ( uart_rx       ),
    .o_uart_tx    ( uart_tx       ),
    .wr_en        ( wr_en         ),
    .wr_rdy       ( wr_rdy        ),
    .wr_addr      ( wr_addr       ),
    .wr_data      ( wr_data       ),
    .rd_en        ( rd_en         ),
    .rd_rdy       ( rd_rdy        ),
    .rd_addr      ( rd_addr       ),
    .rd_data      ( rd_data       )
);

always @ (posedge clk)
    if(rd_en & rd_rdy)
        $display("read  addr=%x", rd_addr);

always @ (posedge clk)
    if(wr_en & wr_rdy)
        $display("write addr=%x  data=%x", wr_addr, wr_data);





// -----------------------------------------------------------------------------------------------------------------------------
// UART RX
// -----------------------------------------------------------------------------------------------------------------------------
wire [7:0] rx_data;
wire       rx_en;

uart_rx #(
    .CLK_DIV      ( 217           ),   // 25MHz/217 = 115200
    .PARITY       ( "NONE"        )    // "NONE", "ODD" or "EVEN"
) uart_rx_i (
    .rstn         ( rstn          ),
    .clk          ( clk           ),
    .i_uart_rx    ( uart_tx       ),
    .rx_data      ( rx_data       ),
    .rx_en        ( rx_en         )
);

always @ (posedge clk)
    if(rx_en)
        $write("%c", rx_data);

endmodule
