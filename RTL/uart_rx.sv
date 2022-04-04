
//--------------------------------------------------------------------------------------------------------
// Module  : uart_rx
// Type    : synthesizable, IP's top
// Standard: SystemVerilog 2005 (IEEE1800-2005)
// Function: convert UART RX signal to bytes
// UART format: 8 data bits
//--------------------------------------------------------------------------------------------------------

module uart_rx #(
    parameter CLK_DIV = 434,     // UART baud rate = clk freq/CLK_DIV. for example, when clk=50MHz, CLK_DIV=434, then baud=50MHz/434=115200
    parameter PARITY  = "NONE"   // "NONE", "ODD" or "EVEN"
) (
    input  wire       rstn,
    input  wire       clk,
    // uart rx input signal
    input  wire       i_uart_rx,
    // user interface
    output reg  [7:0] rx_data,
    output reg        rx_en
);

initial {rx_data, rx_en} = '0;


reg        rxbuff = 1'b1;

always @ (posedge clk or negedge rstn)
    if(~rstn)
        rxbuff <= 1'b1;
    else
        rxbuff <= i_uart_rx;




reg [31:0] cyc = 0;
reg        cycend = 1'b0;
reg [ 5:0] rxshift = '0;

wire rbit = rxshift[2] & rxshift[1] | rxshift[1] & rxshift[0] | rxshift[2] & rxshift[0] ;

always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        cyc <= 0;
        cycend <= 1'b0;
        rxshift <= '0;
    end else begin
        cyc <= (cyc+1<CLK_DIV) ? cyc + 1 : 0;
        cycend <= 1'b0;
        if( cyc == (CLK_DIV/4)*0 || cyc == (CLK_DIV/4)*1 || cyc == (CLK_DIV/4)*2 || cyc == (CLK_DIV/4)*3 ) begin
            cycend <= 1'b1;
            rxshift <= {rxshift[4:0], rxbuff};
        end
    end




reg [4:0] cnt = '0;
enum logic [2:0] {S_IDLE, S_DATA, S_PARI, S_OKAY, S_FAIL} stat = S_IDLE;

always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        {rx_data, rx_en} <= '0;
        cnt  <= '0;
        stat <= S_IDLE;
    end else begin
        rx_en <= 1'b0;
        if( cycend ) begin
            case(stat)
                S_IDLE: begin
                    cnt <= '0;
                    if(rxshift == 6'b111_000) stat <= S_DATA;
                end
                S_DATA: begin
                    cnt <= cnt + 5'd1;
                    if(cnt[1:0] == '1) rx_data <= {rbit, rx_data[7:1]};
                    if(cnt      == '1) stat <= (PARITY=="NONE") ? S_OKAY : S_PARI;
                end
                S_PARI: begin
                    cnt <= cnt + 5'd1;
                    if(cnt[1:0] == '1) stat <=((PARITY=="EVEN") ^ rbit ^ (^rx_data)) ? S_OKAY : S_FAIL;
                end
                S_OKAY: begin
                    cnt <= cnt + 5'd1;
                    if(cnt[1:0] == '1) begin
                        rx_en <= rbit;
                        stat <= rbit ? S_IDLE : S_FAIL;
                    end
                end
                S_FAIL: if(rxshift[2:0] == '1) stat <= S_IDLE;
            endcase
        end
    end

endmodule
