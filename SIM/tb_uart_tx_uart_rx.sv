
//--------------------------------------------------------------------------------------------------------
// Module  : tb_uart_tx_uart_rx
// Type    : simulation, top
// Standard: SystemVerilog 2005 (IEEE1800-2005)
// Function: testbench for uart_tx and uart_rx
//--------------------------------------------------------------------------------------------------------

`timescale 1ps/1ps

module tb_uart_tx_uart_rx();


// -----------------------------------------------------------------------------------------------------------------------------
// simulation control
// -----------------------------------------------------------------------------------------------------------------------------
initial $dumpvars(0, tb_uart_tx_uart_rx);
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

localparam UART_PARITY = "NONE";


// -----------------------------------------------------------------------------------------------------------------------------
// UART TX
// -----------------------------------------------------------------------------------------------------------------------------
localparam TX_DWIDTH = 2;
reg [TX_DWIDTH*8-1:0] tx_data = '0;
reg                   tx_last = '0;
reg                   tx_en   = '0;
wire                  tx_rdy;

always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        tx_data <= '0;
        tx_en <= 1'b0;
    end else begin
        if(tx_en & tx_rdy) begin
            tx_data <= tx_data + (TX_DWIDTH*8)'(1);
            tx_last <= tx_data % (TX_DWIDTH*8)'(7) == (TX_DWIDTH*8)'(5);
        end
        tx_en <= 1'b1;
    end


// -----------------------------------------------------------------------------------------------------------------------------
// UART TX
// -----------------------------------------------------------------------------------------------------------------------------
uart_tx #(
    .CLK_DIV      ( 217           ),   // 25MHz/217 = 115200
    .PARITY       ( UART_PARITY   ),   // "NONE", "ODD" or "EVEN"
    .ASIZE        ( 3             ),   // Specify tx buffer size
    .DWIDTH       ( TX_DWIDTH     ),   // Specify width of tx_data , that is, how many bytes can it input per clock cycle
    .ENDIAN       ( "LITTLE"      ),   // "LITTLE" or "BIG"
    .MODE         ( "HEX"         ),   // "RAW", "PRINTABLE", "HEX" or "HEXSPACE"
    .END_OF_DATA  ( ""            ),   // Dont send extra byte after each tx_data
    .END_OF_PACK  ( "\n"          )    // Send a extra "\n" after each tx_data with tx_last=1
) uart_tx_i (
    .rstn         ( rstn          ),
    .clk          ( clk           ),
    .tx_data      ( tx_data       ),
    .tx_last      ( tx_last       ),
    .tx_en        ( tx_en         ),
    .tx_rdy       ( tx_rdy        ),
    .o_uart_tx    ( uart_tx       )
);


// -----------------------------------------------------------------------------------------------------------------------------
// UART RX
// -----------------------------------------------------------------------------------------------------------------------------
wire [7:0] rx_data;
wire       rx_en;

uart_rx #(
    .CLK_DIV      ( 217           ),   // 25MHz/217 = 115200
    .PARITY       ( UART_PARITY   )    // "NONE", "ODD" or "EVEN"
) uart_rx_i (
    .rstn         ( rstn          ),
    .clk          ( clk           ),
    .i_uart_rx    ( uart_tx       ),
    .rx_data      ( rx_data       ),
    .rx_en        ( rx_en         )
);


// -----------------------------------------------------------------------------------------------------------------------------
// print UART RX result
// -----------------------------------------------------------------------------------------------------------------------------
always @ (posedge clk)
    if(rx_en)
        $write("%c", rx_data);

endmodule
