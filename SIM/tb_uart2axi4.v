
//--------------------------------------------------------------------------------------------------------
// Module  : tb_uart2axi4
// Type    : simulation, top
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: testbench for uart_tx and uart_rx
//--------------------------------------------------------------------------------------------------------

`timescale 1ps/1ps

module tb_uart2axi4 ();


//-----------------------------------------------------------------------------------------------------------------------------
// simulation control
//-----------------------------------------------------------------------------------------------------------------------------
initial begin repeat (1000000) @(posedge clk); $finish;  end            // simulation for 1000000 clock cycles
initial $dumpvars(1, tb_uart2axi4);
initial $dumpvars(1, u_uart2axi4);


//-----------------------------------------------------------------------------------------------------------------------------
// parameters
//-----------------------------------------------------------------------------------------------------------------------------
localparam CLK_FREQ            = 16000000;
localparam UART_BAUD_RATE      = 115200;
localparam UART_PARITY         = "NONE";


//-----------------------------------------------------------------------------------------------------------------------------
// generate reset and clock
//-----------------------------------------------------------------------------------------------------------------------------
reg rstn  = 1'b0;
reg clk   = 1'b1;
always #(1000000000000 / 2 / CLK_FREQ   ) clk   = ~clk;
initial begin repeat(4) @(posedge clk); rstn<=1'b1; end


//-----------------------------------------------------------------------------------------------------------------------------
// signals
//-----------------------------------------------------------------------------------------------------------------------------
wire        uart_from_dut;
wire        uart_to_dut;

wire        en_from_dut;
wire [ 7:0] byte_from_dut;

reg         en_to_dut   = 1'b0;
reg  [ 7:0] byte_to_dut = 8'h0;


always @ (posedge clk)
    if (en_from_dut)
        $write("%c", byte_from_dut);


//-----------------------------------------------------------------------------------------------------------------------------
// generate data to DUT
//-----------------------------------------------------------------------------------------------------------------------------
initial begin
    while  (~rstn) @(posedge clk);
    repeat (10000) @(posedge clk);
    
    @(posedge clk) en_to_dut   <= 1'b1;
                   byte_to_dut <= "W";
    @(posedge clk) byte_to_dut <= "1";
    @(posedge clk) byte_to_dut <= "2";
    @(posedge clk) byte_to_dut <= "F";
    @(posedge clk) byte_to_dut <= " ";
    @(posedge clk) byte_to_dut <= "A";
    @(posedge clk) byte_to_dut <= "B";
    @(posedge clk) byte_to_dut <= "C";
    @(posedge clk) byte_to_dut <= " ";
    @(posedge clk) byte_to_dut <= "3";
    @(posedge clk) byte_to_dut <= "2";
    @(posedge clk) byte_to_dut <= " ";
    @(posedge clk) byte_to_dut <= "9";
    @(posedge clk) byte_to_dut <= "8";
    @(posedge clk) byte_to_dut <= "7";
    @(posedge clk) byte_to_dut <= "6";
    @(posedge clk) byte_to_dut <= "\n";
    
    @(posedge clk) byte_to_dut <= "R";
    @(posedge clk) byte_to_dut <= "1";
    @(posedge clk) byte_to_dut <= "2";
    @(posedge clk) byte_to_dut <= "F";
    @(posedge clk) byte_to_dut <= " ";
    @(posedge clk) byte_to_dut <= "4";
    @(posedge clk) byte_to_dut <= "\n";
    
    @(posedge clk) byte_to_dut <= "R";
    @(posedge clk) byte_to_dut <= "1";
    @(posedge clk) byte_to_dut <= "2";
    @(posedge clk) byte_to_dut <= "0";
    @(posedge clk) byte_to_dut <= "\n";
    
    @(posedge clk) en_to_dut   <= 1'b0;
    
    repeat (1000000) @(posedge clk);
    $stop;
end


//-----------------------------------------------------------------------------------------------------------------------------
// for generate UART TX for uart2axi4, and receive UART RX for uart2axi4
//-----------------------------------------------------------------------------------------------------------------------------
uart_tx #(
    .CLK_FREQ                  ( CLK_FREQ             ),
    .BAUD_RATE                 ( UART_BAUD_RATE       ),
    .PARITY                    ( UART_PARITY          ),
    .STOP_BITS                 ( 1                    ),
    .BYTE_WIDTH                ( 1                    ),
    .FIFO_EA                   ( 18                   ),
    .EXTRA_BYTE_AFTER_TRANSFER ( ""                   ),
    .EXTRA_BYTE_AFTER_PACKET   ( ""                   )
) u_uart_tx (
    .rstn                      ( rstn                 ),
    .clk                       ( clk                  ),
    .i_tready                  (                      ),
    .i_tvalid                  ( en_to_dut            ),
    .i_tdata                   ( byte_to_dut          ),
    .i_tkeep                   ( 1'b1                 ),
    .i_tlast                   ( 1'b0                 ),
    .o_uart_tx                 ( uart_to_dut          )
);

uart_rx #(
    .CLK_FREQ                  ( CLK_FREQ             ),
    .BAUD_RATE                 ( UART_BAUD_RATE       ),
    .PARITY                    ( UART_PARITY          ),
    .FIFO_EA                   ( 0                    )
) u_uart_rx (
    .rstn                      ( rstn                 ),
    .clk                       ( clk                  ),
    .i_uart_rx                 ( uart_from_dut        ),
    .o_tready                  ( 1'b1                 ),
    .o_tvalid                  ( en_from_dut          ),
    .o_tdata                   ( byte_from_dut        ),
    .o_overflow                (                      )
);


//-----------------------------------------------------------------------------------------------------------------------------
// design under test (DUT)
//-----------------------------------------------------------------------------------------------------------------------------
uart2axi4 #(
    .CLK_FREQ                  ( CLK_FREQ             ),
    .BAUD_RATE                 ( UART_BAUD_RATE       ),
    .PARITY                    ( UART_PARITY          ),
    .BYTE_WIDTH                ( 4                    )
) u_uart2axi4 (
    .rstn                      ( rstn                 ),
    .clk                       ( clk                  ),
    // AXI4 master ----------------------
    .awready                   ( 1'b1                 ),
    .awvalid                   (                      ),
    .awaddr                    (                      ),
    .awlen                     (                      ),
    .wready                    ( 1'b1                 ),
    .wvalid                    (                      ),
    .wlast                     (                      ),
    .wdata                     (                      ),
    .bready                    (                      ),
    .bvalid                    ( 1'b1                 ),
    .arready                   ( 1'b1                 ),
    .arvalid                   (                      ),
    .araddr                    (                      ),
    .arlen                     (                      ),
    .rready                    (                      ),
    .rvalid                    ( 1'b1                 ),
    .rlast                     ( 1'b0                 ),
    .rdata                     ( 'h12345678           ),
    // UART ----------------------
    .i_uart_rx                 ( uart_to_dut          ),
    .o_uart_tx                 ( uart_from_dut        )
);


endmodule
