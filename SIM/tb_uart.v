
//--------------------------------------------------------------------------------------------------------
// Module  : tb_uart
// Type    : simulation, top
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: testbench for uart_tx and uart_rx
//--------------------------------------------------------------------------------------------------------

`timescale 1ps/1ps

module tb_uart ();


//-----------------------------------------------------------------------------------------------------------------------------
// parameters (you can modify them)
//-----------------------------------------------------------------------------------------------------------------------------
localparam TX_CLK_FREQ         = 4000000;
localparam RX_CLK_FREQ         = 5000000;
localparam UART_BAUD_RATE      = 115200;
localparam UART_PARITY         = "ODD";
localparam UART_STOP_BITS      = 1;
localparam TX_AXIS_BYTE_WIDTH  = 2;


//-----------------------------------------------------------------------------------------------------------------------------
// UART signal
//-----------------------------------------------------------------------------------------------------------------------------
wire uart_signal;


//-----------------------------------------------------------------------------------------------------------------------------
// generate reset and clock
//-----------------------------------------------------------------------------------------------------------------------------
reg rstn  = 1'b0;
reg txclk = 1'b1;
reg rxclk = 1'b1;
always #(1000000000000 / 2 / TX_CLK_FREQ) txclk = ~txclk;
always #(1000000000000 / 2 / RX_CLK_FREQ) rxclk = ~rxclk;
initial begin repeat(4) @(posedge txclk); rstn<=1'b1; end


//-----------------------------------------------------------------------------------------------------------------------------
// generate an AXI-stream source's behavior for uart_rx
//-----------------------------------------------------------------------------------------------------------------------------
wire                            tx_tready;
wire                            tx_tvalid;
wire [TX_AXIS_BYTE_WIDTH*8-1:0] tx_tdata;
wire [TX_AXIS_BYTE_WIDTH  -1:0] tx_tkeep;
wire                            tx_tlast;

tb_axis_inc_source # (
    .BYTE_WIDTH                ( TX_AXIS_BYTE_WIDTH   )
) u_tb_axis_inc_source (
    .rstn                      ( rstn                 ),
    .clk                       ( txclk                ),
    .o_tready                  ( tx_tready            ),
    .o_tvalid                  ( tx_tvalid            ),
    .o_tdata                   ( tx_tdata             ),
    .o_tkeep                   ( tx_tkeep             ),
    .o_tlast                   ( tx_tlast             )
);


//-----------------------------------------------------------------------------------------------------------------------------
// design under test : UART TX
//-----------------------------------------------------------------------------------------------------------------------------
uart_tx #(
    .CLK_FREQ                  ( TX_CLK_FREQ          ),
    .BAUD_RATE                 ( UART_BAUD_RATE       ),
    .PARITY                    ( UART_PARITY          ),
    .STOP_BITS                 ( UART_STOP_BITS       ),
    .BYTE_WIDTH                ( TX_AXIS_BYTE_WIDTH   ),
    .FIFO_EA                   ( 0                    ),
    .EXTRA_BYTE_AFTER_TRANSFER ( ""                   ),
    .EXTRA_BYTE_AFTER_PACKET   ( ""                   )
) u_uart_tx (
    .rstn                      ( rstn                 ),
    .clk                       ( txclk                ),
    .i_tready                  ( tx_tready            ),
    .i_tvalid                  ( tx_tvalid            ),
    .i_tdata                   ( tx_tdata             ),
    .i_tkeep                   ( tx_tkeep             ),
    .i_tlast                   ( tx_tlast             ),
    .o_uart_tx                 ( uart_signal          )
);


//-----------------------------------------------------------------------------------------------------------------------------
// design under test : UART RX
//-----------------------------------------------------------------------------------------------------------------------------
wire       rx_tready = 1'b1;
wire       rx_tvalid;
wire [7:0] rx_tdata;

wire       rx_overflow;

uart_rx #(
    .CLK_FREQ                  ( RX_CLK_FREQ          ),
    .BAUD_RATE                 ( UART_BAUD_RATE       ),
    .PARITY                    ( UART_PARITY          ),
    .FIFO_EA                   ( 1                    )
) u_uart_rx (
    .rstn                      ( rstn                 ),
    .clk                       ( rxclk                ),
    .i_uart_rx                 ( uart_signal          ),
    .o_tready                  ( rx_tready            ),
    .o_tvalid                  ( rx_tvalid            ),
    .o_tdata                   ( rx_tdata             ),
    .o_overflow                ( rx_overflow          )
);


//-----------------------------------------------------------------------------------------------------------------------------
// print UART RX result
//-----------------------------------------------------------------------------------------------------------------------------
reg [7:0] expect_byte = 8'h0;
always @ (posedge rxclk or negedge rstn)
    if (~rstn) begin
        expect_byte <= 8'h0;
    end else begin
        if (rx_tvalid & rx_tready) begin 
            $write("%02x ", rx_tdata);
            if (rx_tdata !== expect_byte) begin
                $display("***error : RX data not increase");
                $stop;
            end
            expect_byte <= expect_byte + 8'h1;
        end
    end

always @ (posedge rxclk)
    if (rx_overflow)
        $display("\nrx overflow");


//-----------------------------------------------------------------------------------------------------------------------------
// simulation control
//-----------------------------------------------------------------------------------------------------------------------------
initial begin repeat (1000000) @(posedge txclk); $finish;  end            // simulation for 1000000 clock cycles
initial $dumpvars(0, tb_uart);


endmodule
