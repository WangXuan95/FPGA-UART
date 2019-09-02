
module axi_stream_to_uart_tx #(
    parameter CLK_DIV    = 434,
    parameter DATA_WIDTH = 32,
    parameter FIFO_ASIZE = 8
) (
    // AXI-stream (slave) side
    input  logic aclk, aresetn,
    input  logic tvalid, tlast,
    output logic tready,
    input  logic [DATA_WIDTH-1:0] tdata,
    // UART TX signal
    output logic uart_tx
);
localparam TX_WIDTH = (DATA_WIDTH+3) / 4;

function automatic logic [7:0] hex2ascii(input [3:0] hex);
    return (hex<4'hA) ? (hex+"0") : (hex+("A"-8'hA)) ;
endfunction

initial uart_tx = 1'b1;

logic [FIFO_ASIZE-1:0] fifo_rpt='0, fifo_wpt='0;
wire  [FIFO_ASIZE-1:0] fifo_wpt_next = fifo_wpt+1;
logic [31:0] cyccnt=0, hexcnt=0, txcnt=0;
logic [ 7:0] txshift = '1;
logic fifo_tlast;
logic [DATA_WIDTH-1:0] fifo_data;
logic endofline = 1'b0;
logic [TX_WIDTH*4-1:0] data='0;
wire  emptyn = (fifo_rpt != fifo_wpt);
assign  tready = (fifo_rpt != fifo_wpt_next) & aresetn;

always @ (posedge aclk or negedge aresetn)
    if(~aresetn)
        fifo_wpt <= '0;
    else begin
        if(tvalid & tready) fifo_wpt <= fifo_wpt+1;
    end

always @ (posedge aclk or negedge aresetn)
    if(~aresetn)
        cyccnt <= 0;
    else
        cyccnt <= (cyccnt<CLK_DIV-1) ? cyccnt+1 : 0;

always @ (posedge aclk or negedge aresetn)
    if(~aresetn) begin
        fifo_rpt  <= '0;
        endofline <= 1'b0;
        data      <= '0;
        uart_tx   <= 1'b1;
        txshift   <= '1;
        txcnt     <= 0;
        hexcnt    <= 0;
    end else begin
        if( hexcnt>(1+TX_WIDTH) ) begin
            uart_tx   <= 1'b1;
            endofline <= fifo_tlast;
            data                 <= '0;
            data[DATA_WIDTH-1:0] <= fifo_data;
            hexcnt <= hexcnt-1;
        end else if(hexcnt>0 || txcnt>0) begin
            if(cyccnt==CLK_DIV-1) begin
                if(txcnt>0) begin
                    {txshift, uart_tx} <= {1'b1, txshift};
                    txcnt <= txcnt-1;
                end else begin
                    uart_tx <= 1'b0;
                    hexcnt <= hexcnt-1;
                    if(hexcnt>1)
                        txshift <= hex2ascii(data[(hexcnt-1)*4+:4]);
                    else if(endofline)
                        txshift <= "\n";
                    else
                        txshift <=  " ";
                    txcnt <= 11;
                end
            end
        end else if(emptyn) begin
            uart_tx  <= 1'b1;
            hexcnt   <= 2 + TX_WIDTH;
            txcnt    <= 0;
            fifo_rpt <= fifo_rpt+1;
        end
    end

ram_for_axi_stream_to_uart_tx_fifo #(
    .ADDR_LEN  ( FIFO_ASIZE             ),
    .DATA_LEN  ( DATA_WIDTH + 1         )
) ram_for_uart_tx_fifo_inst (
    .clk       ( aclk                   ),
    .wr_req    ( tvalid & tready        ),
    .wr_addr   ( fifo_wpt               ),
    .wr_data   ( {tlast, tdata}         ),
    .rd_addr   ( fifo_rpt               ),
    .rd_data   ( {fifo_tlast,fifo_data} )
);

endmodule






module ram_for_axi_stream_to_uart_tx_fifo #(
    parameter ADDR_LEN = 12,
    parameter DATA_LEN = 8
) (
    input  logic clk,
    input  logic wr_req,
    input  logic [ADDR_LEN-1:0] rd_addr, wr_addr,
    output logic [DATA_LEN-1:0] rd_data,
    input  logic [DATA_LEN-1:0] wr_data
);

localparam  RAM_SIZE = (1<<ADDR_LEN);

logic [DATA_LEN-1:0] mem [RAM_SIZE];

initial rd_data = 0;

always @ (posedge clk)
    rd_data <= mem[rd_addr];

always @ (posedge clk)
    if(wr_req)
        mem[wr_addr] <= wr_data;

endmodule