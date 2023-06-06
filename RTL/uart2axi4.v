
//--------------------------------------------------------------------------------------------------------
// Module  : uart2axi4
// Type    : synthesizable
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: convert UART command to AXI4 read/write action
//--------------------------------------------------------------------------------------------------------

module uart2axi4 #(
    // clock frequency
    parameter  CLK_FREQ   = 50000000,     // clk frequency, Unit : Hz
    // UART format
    parameter  BAUD_RATE  = 115200,       // Unit : Hz
    parameter  PARITY     = "NONE",       // "NONE", "ODD", or "EVEN"
    // AXI4 config
    parameter  BYTE_WIDTH = 2,            // data width (bytes)
    parameter  A_WIDTH    = 32            // address width (bits)
) (
    input  wire                    rstn,
    input  wire                    clk,
    // AXI4 master ----------------------
    input  wire                    awready,  // AW
    output wire                    awvalid,
    output wire      [A_WIDTH-1:0] awaddr,
    output wire             [ 7:0] awlen,
    input  wire                    wready,   // W
    output wire                    wvalid,
    output wire                    wlast,
    output wire [8*BYTE_WIDTH-1:0] wdata,
    output wire                    bready,   // B
    input  wire                    bvalid,
    input  wire                    arready,  // AR
    output wire                    arvalid,
    output wire      [A_WIDTH-1:0] araddr,
    output wire             [ 7:0] arlen,
    output wire                    rready,   // R
    input  wire                    rvalid,
    input  wire                    rlast,
    input  wire [8*BYTE_WIDTH-1:0] rdata,
    // UART ----------------------
    input  wire                    i_uart_rx,
    output wire                    o_uart_tx
);



wire                   rx_valid;
wire            [ 7:0] rx_byte;

uart_rx #(
    .CLK_FREQ                  ( CLK_FREQ             ),
    .BAUD_RATE                 ( BAUD_RATE            ),
    .PARITY                    ( PARITY               ),
    .FIFO_EA                   ( 0                    )
) u_uart_rx (
    .rstn                      ( rstn                 ),
    .clk                       ( clk                  ),
    .i_uart_rx                 ( i_uart_rx            ),
    .o_tready                  ( 1'b1                 ),
    .o_tvalid                  ( rx_valid             ),
    .o_tdata                   ( rx_byte              ),
    .o_overflow                (                      )
);

wire                   rx_space   = (rx_valid && (rx_byte == 8'h20));                        // " "
wire                   rx_newline = (rx_valid && (rx_byte == 8'h0D || rx_byte == 8'h0A));    // \r, \n
wire                   rx_char_w  = (rx_valid && (rx_byte == 8'h57 || rx_byte == 8'h77));    // W, w
wire                   rx_char_r  = (rx_valid && (rx_byte == 8'h52 || rx_byte == 8'h72));    // R, r
wire                   rx_is_hex  = (rx_valid && ((rx_byte>=8'h30 && rx_byte<=8'h39) || (rx_byte>=8'h41 && rx_byte<=8'h46) || (rx_byte>=8'h61 && rx_byte<=8'h66)));    // 0~9, A~F, a~f
wire            [ 3:0] rx_hex     = (rx_byte>=8'h30 && rx_byte<=8'h39) ? rx_byte[3:0] : (rx_byte[3:0] + 4'd9);



reg                    rwtype = 1'b0;
reg      [A_WIDTH-1:0] addr   = 0;
reg             [ 8:0] len    = 9'h0;
reg                    wwen   = 1'b0;
reg [8*BYTE_WIDTH-1:0] wwdata = 0;
reg             [ 7:0] wraddr = 8'h0;


localparam      [ 3:0] S_IDLE        = 4'd0,
                       S_PARSE_ADDR  = 4'd1,
                       S_PARSE_LEN   = 4'd2,
                       S_PARSE_WDATA = 4'd3,
                       S_AXI_RADDR   = 4'd4,
                       S_AXI_WADDR   = 4'd5,
                       S_AXI_RDATA   = 4'd6,
                       S_AXI_WDATA   = 4'd7,
                       S_AXI_B       = 4'd8,
                       S_W_DONE      = 4'd9,
                       S_INVALID     = 4'd10,
                       S_FAILED      = 4'd11;

reg             [ 3:0] state  = S_IDLE;


always @ (posedge clk or negedge rstn)
    if (~rstn) begin
        rwtype <= 1'b0;
        addr   <= 0;
        len    <= 9'h0;
        wwen   <= 1'b0;
        wwdata <= 0;
        wraddr <= 8'h0;
        state  <= S_IDLE;
    end else begin
        case (state)
            
            S_IDLE : begin
                rwtype <= rx_char_w;
                addr   <= 0;
                len    <= 9'h0;
                wwen   <= 1'b0;
                wwdata <= 0;
                wraddr <= 8'h0;
                if (rx_char_w | rx_char_r)
                    state <= S_PARSE_ADDR;
                else if (rx_space | rx_newline)
                    state <= S_IDLE;
                else if (rx_valid)
                    state <= S_INVALID;
            end
            
            S_PARSE_ADDR :
                if (rx_is_hex) begin
                    addr <= (addr << 4);
                    addr[3:0] <= rx_hex;
                end else if (rx_space)
                    state <= rwtype ? S_PARSE_WDATA : S_PARSE_LEN;
                else if (rx_newline)
                    state <= S_FAILED;
                else if (rx_valid)
                    state <= S_INVALID;
            
            S_PARSE_LEN :
                if (rx_is_hex) begin
                    len   <= (len << 4);
                    len[3:0] <= rx_hex;
                end else if (rx_newline) begin
                    len   <= (len >= 9'h100) ? 9'hFF : (len == 9'h0) ? 9'h0 : (len - 9'h1);
                    state <= S_AXI_RADDR;
                end else if (rx_space) begin
                    state <= S_PARSE_LEN;
                end else if (rx_valid) begin
                    state <= S_INVALID;
                end
            
            S_PARSE_WDATA :
                if (rx_is_hex) begin
                    wwen   <= 1'b1;
                    wwdata <= (wwdata << 4);
                    wwdata[3:0] <= rx_hex;
                end else if (rx_space) begin
                    wwen  <= 1'b0;
                    if (wwen) begin
                        wwdata <= 0;
                        len    <= len + 9'd1;
                    end
                end else if (rx_newline) begin
                    if (wwen) begin
                        state <= (               len <  9'h100) ? S_AXI_WADDR : S_FAILED;
                    end else begin
                        state <= (len >= 9'd0 && len <= 9'd100) ? S_AXI_WADDR : S_FAILED;
                        len   <= len - 9'd1;
                    end
                end else if (rx_valid) begin
                    state <= S_INVALID;
                end
            
            S_AXI_RADDR :
                if (arready)
                    state <= S_AXI_RDATA;
            
            S_AXI_WADDR :
                if (awready)
                    state <= S_AXI_WDATA;
            
            S_AXI_RDATA : 
                if (rvalid) begin
                    len <= len - 9'd1;
                    if (rlast || (len==9'd0))
                        state <= S_IDLE;
                end
            
            S_AXI_WDATA :
                if (wready) begin
                    wraddr <= wraddr + 8'd1;
                    if (wraddr >= len[7:0])
                        state <= S_AXI_B;
                end
            
            S_AXI_B :
                if (bvalid)
                    state <= S_W_DONE;
            
            S_W_DONE :
                state <= S_IDLE;
            
            S_INVALID :
                if (rx_newline)
                    state <= S_FAILED;
            
            default : // S_FAILED :
                state <= S_IDLE;
                
        endcase
    end


reg [8*BYTE_WIDTH-1:0] wbuf [0:255];

always @ (posedge clk)
    if ( (state == S_PARSE_WDATA) && (rx_space || rx_newline) && wwen )
        wbuf[len[7:0]] <= wwdata;

wire            [ 7:0] wraddr_next = (wvalid & wready) ? (wraddr + 8'd1) : wraddr;
reg [8*BYTE_WIDTH-1:0] wrdata;

always @ (posedge clk)
    wrdata <= wbuf[wraddr_next];



assign arvalid = (state == S_AXI_RADDR);
assign araddr  = addr;
assign arlen   = len[7:0];

assign awvalid = (state == S_AXI_WADDR);
assign awaddr  = addr;
assign awlen   = len[7:0];

assign rready  = (state == S_AXI_RDATA);

assign wvalid  = (state == S_AXI_WDATA);
assign wlast   = (wraddr >= len[7:0]);
assign wdata   = wrdata;

assign bready  = 1'b1;        // (state == S_AXI_B)





function  [7:0] toHex;
    input [3:0] val;
begin
    toHex = (val <= 4'd9) ? {4'h3, val} : {4'd6, 1'b0, val[2:0]-3'h1};
end
endfunction


wire                      tx_w_done = (state == S_W_DONE);
wire                      tx_failed = (state == S_FAILED);
wire                      tx_number = (rvalid & rready);

wire [8*2*BYTE_WIDTH-1:0] tx_data_failed = 64'h20_64_69_6C_61_76_6E_69;                                            // "invalid"
wire [8*2*BYTE_WIDTH-1:0] tx_data_w_done = 64'h20_20_20_20_79_61_6B_6F;                                            // "okay"
wire [8*2*BYTE_WIDTH-1:0] tx_data_number;

wire                      tx_valid  = tx_failed | tx_w_done | tx_number;
wire [8*2*BYTE_WIDTH-1:0] tx_data   = tx_failed ? tx_data_failed : tx_w_done ? tx_data_w_done : tx_data_number;
wire                      tx_last   = tx_failed ?           1'b1 : tx_w_done ?           1'b1 : (rlast || (len==9'd0));


generate genvar i;
    for (i=0; i<2*BYTE_WIDTH; i=i+1) begin : gen_tx_tdata
        assign tx_data_number[8*i +: 8] = toHex(rdata[4*(2*BYTE_WIDTH-1-i) +: 4]);
    end
endgenerate



uart_tx #(
    .CLK_FREQ                  ( CLK_FREQ               ),
    .BAUD_RATE                 ( BAUD_RATE              ),
    .PARITY                    ( PARITY                 ),
    .STOP_BITS                 ( 4                      ),
    .BYTE_WIDTH                ( 2 * BYTE_WIDTH         ),
    .FIFO_EA                   ( 9                      ),
    .EXTRA_BYTE_AFTER_TRANSFER ( " "                    ),
    .EXTRA_BYTE_AFTER_PACKET   ( "\n"                   )
) u_uart_tx (
    .rstn                      ( rstn                   ),
    .clk                       ( clk                    ),
    .i_tready                  (                        ),
    .i_tvalid                  ( tx_valid               ),
    .i_tdata                   ( tx_data                ),
    .i_tkeep                   ( {(2*BYTE_WIDTH){1'b1}} ),
    .i_tlast                   ( tx_last                ),
    .o_uart_tx                 ( o_uart_tx              )
);


endmodule
