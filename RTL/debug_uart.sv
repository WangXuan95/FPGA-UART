
//--------------------------------------------------------------------------------------------------------
// Module  : debug_uart
// Type    : synthesizable, IP's top
// Standard: SystemVerilog 2005 (IEEE1800-2005)
// Function: convert UART command to a bus read&write action,
//           typically used for debugging and system monitor
//           for example: 1. connect debug_uart to a RAM to monitor and modify RAM data
//                        2. connect debug_uart to a SoC's bus to debug SoC
// UART format: 8 data bits, no parity bit
//--------------------------------------------------------------------------------------------------------

module debug_uart #(
    parameter  UART_CLK_DIV = 434, // UART baud rate = clk freq/UART_CLK_DIV. for example, when clk=50MHz, UART_CLK_DIV=434 , then baud=50MHz/434=115200
    parameter  AWIDTH       = 4,   // address width = 4bytes = 32bits
    parameter  DWIDTH       = 4,   // data width = 4bytes = 32bits
    parameter  WR_TIMEOUT   = 500, // wait for wr_rdy cycles
    parameter  RD_TIMEOUT   = 500, // wait for rd_rdy cycles
    parameter  READ_IMM     = 0    // 0: read after rd_rdy: Capture rd_data in the next clock cycle of rd_rdy=1
                                   // 1: read immediately : Capture rd_data in the clock cycle of rd_rdy=1
)(
    input  wire                rstn,
    input  wire                clk,
    // UART
    input  wire                i_uart_rx,
    output reg                 o_uart_tx,
    // bus write interface
    output reg                 wr_en,
    input  wire                wr_rdy,
    output reg  [AWIDTH*8-1:0] wr_addr,
    output reg  [DWIDTH*8-1:0] wr_data,
    // bus read  interface
    output reg                 rd_en,
    input  wire                rd_rdy,
    output reg  [AWIDTH*8-1:0] rd_addr,
    input  wire [DWIDTH*8-1:0] rd_data
);

initial {wr_en, wr_addr, wr_data} = '0;
initial {rd_en, rd_addr} = '0;
initial o_uart_tx = 1'b1;

localparam MSG_LEN = 7;
localparam TX_LEN = (DWIDTH*2>MSG_LEN) ? DWIDTH*2 : MSG_LEN;

localparam logic [MSG_LEN*8-1:0] MSG_TIMEOUT = "timeout";
localparam logic [MSG_LEN*8-1:0] MSG_INVALID = "invalid";
localparam logic [MSG_LEN*8-1:0] MSG_WR_DONE = "wr done";




// --------------------------------------------------------------------------------------
//  functions
// --------------------------------------------------------------------------------------
function automatic logic iswhite(input [7:0] ch);
    return ( ch==8'h20  || ch==8'h09 );
endfunction

function automatic logic isnewline(input [7:0] ch);
    return ( ch==8'h0D  || ch==8'h0A );
endfunction

function automatic logic ishexdigit(input [7:0] ch);
    return ( ( ch>=8'h30 && ch<=8'h39 ) || ( ch>=8'h61 && ch<=8'h66 ) || ( ch>=8'h41 && ch<=8'h46 ) );
endfunction

function automatic logic [3:0] ascii2hex(input [7:0] ch);
    logic [7:0] rxbin;
    if         ( ch>=8'h30 && ch<=8'h39 ) begin
        rxbin = ch - 8'h30;
    end else if( ch>=8'h61 && ch<=8'h66 ) begin
        rxbin = ch - 8'h61 + 8'd10;
    end else if( ch>=8'h41 && ch<=8'h46 ) begin
        rxbin = ch - 8'h41 + 8'd10;
    end else begin
        rxbin = 8'h0;
    end
    return rxbin[3:0];
endfunction

function automatic logic [7:0] hex2ascii (input [3:0] hex);
    return {4'h3, hex} + ((hex<4'hA) ? 8'h0 : 8'h7) ;
endfunction




// --------------------------------------------------------------------------------------
//  handle UART RX
// --------------------------------------------------------------------------------------
reg        rx_buff = 1'b1;
always @ (posedge clk or negedge rstn)
    if(~rstn)
        rx_buff <= 1'b1;
    else
        rx_buff <= i_uart_rx;

reg [31:0] rxcyc = 0;
reg        rxcycend = 1'b0;
reg [ 5:0] rxshift = '0;
wire rbit = rxshift[2] & rxshift[1] | rxshift[1] & rxshift[0] | rxshift[2] & rxshift[0] ;
always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        rxcyc <= 0;
        rxcycend <= 1'b0;
        rxshift <= '0;
    end else begin
        rxcyc <= (rxcyc+1<UART_CLK_DIV) ? rxcyc + 1 : 0;
        rxcycend <= 1'b0;
        if( rxcyc == (UART_CLK_DIV/4)*0 || rxcyc == (UART_CLK_DIV/4)*1 || rxcyc == (UART_CLK_DIV/4)*2 || rxcyc == (UART_CLK_DIV/4)*3 ) begin
            rxcycend <= 1'b1;
            rxshift <= {rxshift[4:0], rx_buff};
        end
    end

reg       rxen = '0;
reg [7:0] rxdata = '0;
reg [4:0] rxcnt = '0;
enum logic [1:0] {S_IDLE, S_DATA, S_OKAY, S_FAIL} stat = S_IDLE;
always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        {rxdata, rxen} <= '0;
        rxcnt  <= '0;
        stat <= S_IDLE;
    end else begin
        rxen <= 1'b0;
        if( rxcycend ) begin
            case(stat)
                S_IDLE: begin
                    rxcnt <= '0;
                    if(rxshift == 6'b111_000) stat <= S_DATA;
                end
                S_DATA: begin
                    rxcnt <= rxcnt + 5'd1;
                    if(rxcnt[1:0] == '1) rxdata <= {rbit, rxdata[7:1]};
                    if(rxcnt      == '1) stat <= S_OKAY;
                end
                S_OKAY: begin
                    rxcnt <= rxcnt + 5'd1;
                    if(rxcnt[1:0] == '1) begin
                        rxen <= rbit;
                        stat <= rbit ? S_IDLE : S_FAIL;
                    end
                end
                S_FAIL: if(rxshift[2:0] == '1) stat <= S_IDLE;
            endcase
        end
    end







// --------------------------------------------------------------------------------------
//  tasks for bus actions
// --------------------------------------------------------------------------------------
task automatic ReadBusAction(input req=1'b0, input [AWIDTH*8-1:0] addr='0);
    rd_en  <= req;
    rd_addr <= addr;
endtask

task automatic WriteBusAction(input req=1'b0, input [AWIDTH*8-1:0] addr='0, input [DWIDTH*8-1:0] data='0);
    wr_en  <= req;
    wr_addr <= addr;
    wr_data <= data;
endtask



// --------------------------------------------------------------------------------------
//  tasks for UART TX
// --------------------------------------------------------------------------------------
reg [11*(TX_LEN+1)-1:0] txdata = '0;
reg              [31:0] txcnt = 0;
reg              [31:0] txcyc = 0;

task automatic TxClear;
    txdata <= '0;
    txcnt <= 0;
    txcyc <= 0;
endtask

task automatic TxLoadMessage(input [MSG_LEN*8-1:0] msg);
    for(int ii=0; ii<TX_LEN; ii++)
        txdata[ii*11+:11] <= (ii<MSG_LEN ) ? {1'b1, msg[(8*(MSG_LEN-1-ii))+:8], 2'b01} : '1;
    txdata[TX_LEN*11+:11] <= {1'b1, 8'h0A, 2'b01};
    txcnt <= (TX_LEN+2)*11;
    txcyc <= 0;
endtask

task automatic TxLoadData(input [DWIDTH*8-1:0] data);
    for(int ii=0; ii<TX_LEN; ii++)
        txdata[ii*11+:11] <= (ii<DWIDTH*2) ? {1'b1, hex2ascii(data[(4*(DWIDTH*2-1-ii))+:4]), 2'b01} : '1;
    txdata[TX_LEN*11+:11] <= {1'b1, 8'h0A, 2'b01};
    txcnt <= (TX_LEN+2)*11;
    txcyc <= 0;
endtask

task automatic TxIter;
    if( (1+txcyc) < UART_CLK_DIV ) begin
        txcyc <= txcyc + 1;
    end else begin
        txcyc <= 0;
        txcnt <= txcnt-1;
        {txdata, o_uart_tx} <= {1'b1, txdata};
    end
endtask




// --------------------------------------------------------------------------------------
//  main FSM
// --------------------------------------------------------------------------------------
reg           [AWIDTH*8-1:0] taddr = '0;
reg           [DWIDTH*8-1:0] wdatareg = '0;
reg                   [31:0] bus_time = 0;
enum logic [3:0] {NEW, ADDR, EQUAL, DATA, FINAL, TRASH, READ, READOUT, WRITE, UARTTX} fsm = NEW;

always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        o_uart_tx <= 1'b1;
        ReadBusAction();
        WriteBusAction();
        TxClear;
        {taddr, wdatareg} <= '0;
        bus_time <= 0;
        fsm <= NEW;
    end else begin
        case(fsm)
        NEW:
            begin
                ReadBusAction();
                WriteBusAction();
                TxClear;
                {taddr,wdatareg} <= '0;
                bus_time <= 0;
                if(rxen) begin
                    if(ishexdigit(rxdata)) begin
                        fsm <= ADDR;
                        taddr[3:0] <= ascii2hex(rxdata);
                    end else if(~iswhite(rxdata) & ~isnewline(rxdata))
                        fsm <= TRASH;
                end
            end
        ADDR:
            if(rxen) begin
                if (isnewline(rxdata))
                    fsm <= READ;
                else if(ishexdigit(rxdata))
                    taddr <= {taddr[AWIDTH*8-5:0], ascii2hex(rxdata)};
                else if(iswhite(rxdata))
                    fsm <= EQUAL;
                else
                    fsm <= TRASH;
            end
        EQUAL:
            if(rxen) begin
                if ( isnewline(rxdata) )
                    fsm <= READ;
                else if( ishexdigit(rxdata) ) begin
                    fsm <= DATA;  // get a data
                    wdatareg[3:0] <= ascii2hex(rxdata);  // get a data
                end else if( iswhite(rxdata) )
                    fsm <= EQUAL;
                else
                    fsm <= TRASH;
            end
        DATA:
            if(rxen) begin
                if( isnewline(rxdata) )
                    fsm <= WRITE;
                else if( ishexdigit(rxdata) )
                    wdatareg <= {wdatareg[DWIDTH*8-5:0], ascii2hex(rxdata)};  // get a data
                else if( iswhite(rxdata) )
                    fsm <= FINAL;
                else
                    fsm <= TRASH;
            end
        FINAL:
            if(rxen) begin
                if( isnewline(rxdata) )
                    fsm <= WRITE;
                else if( iswhite(rxdata) )
                    fsm <= FINAL;
                else 
                    fsm <= TRASH;
            end
        TRASH:
            if(rxen) begin
                if( isnewline(rxdata) ) begin
                    fsm <= UARTTX;
                    TxLoadMessage(MSG_INVALID);
                end
            end
        READ:
            if(rd_en & rd_rdy) begin
                ReadBusAction();
                if(READ_IMM==0) begin
                    fsm  <= READOUT;
                end else begin
                    fsm  <= UARTTX;
                    TxLoadData(rd_data);
                end
            end else begin
                if( bus_time < RD_TIMEOUT )
                    ReadBusAction(1, taddr); // maintain bus read
                else begin
                    ReadBusAction();
                    fsm  <= UARTTX;
                    TxLoadMessage(MSG_TIMEOUT);
                end
                bus_time <= bus_time + 1;
            end
        READOUT:
            begin
                fsm  <= UARTTX;
                TxLoadData(rd_data);
            end
        WRITE:
            if(wr_en & wr_rdy) begin
                WriteBusAction();
                fsm  <= UARTTX;
                TxLoadMessage(MSG_WR_DONE);
            end else begin
                if( bus_time < WR_TIMEOUT )
                    WriteBusAction(1, taddr, wdatareg); // maintain bus write
                else begin
                    WriteBusAction();
                    fsm  <= UARTTX;
                    TxLoadMessage(MSG_TIMEOUT);
                end
                bus_time <= bus_time + 1;
            end
        default:      // UARTTX
            if(txcnt>0) begin
                TxIter;
            end else begin
                fsm <= NEW;
            end
        endcase
    end


endmodule
