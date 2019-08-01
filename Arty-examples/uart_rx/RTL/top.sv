module top(
    input  logic clk_100M,
    input  logic btn0,
    input  logic uart_rx,
    output logic [7:0] led
);

wire  rst_n =  ~btn0;

logic recvdone;
logic [7:0] recvbyte;

uart_rx #(
    .CLK_DIV  ( 217       )  // 100MHz/4/217 = 115200
) uart_rx_i (
    .clk      ( clk_100M  ),
    .rst_n    ( rst_n     ),
    .rx       ( uart_rx   ),
    .done     ( recvdone  ),
    .data     ( recvbyte  )  // recvbyte is valid when recvdone=1
);

always @ (posedge clk_100M or negedge rst_n)
    if(~rst_n)
        led <= 8'h0;
    else begin
        if(recvdone)
            led <= recvbyte;  // display recvbyte on 8-bit LED
    end

endmodule
