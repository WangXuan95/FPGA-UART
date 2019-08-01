module top(
    input  logic clk_100M,
    output logic led0,
    input  logic [3:0] sw,
    input  logic [3:0] btn,
    output logic uart_tx
);

reg [26:0] cnt = '0;
reg [7:0] sendbyte = '0;
wire wreq = (cnt==27'h7ff_ffff);
assign led0 = cnt[26];

always @ (posedge clk_100M)
    cnt++;

always @ (posedge clk_100M)
    sendbyte <= {sw,btn};

uart_tx #(
    .UART_CLK_DIV( 868      ),  // 100MHz / 868 = 115200
    .MODE        ( 3        )   // HEX mode with \n
) uart_tx_i (
    .clk         ( clk_100M ),
    .rst_n       ( 1'b1     ),
    .wreq        ( wreq     ),
    .wgnt        (          ),
    .wdata       ( sendbyte ),
    .o_uart_tx   ( uart_tx  )
);

endmodule
