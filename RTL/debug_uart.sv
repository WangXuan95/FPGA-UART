// Debug UART
// Function: convert UART to a read&write master interface,
//           typically used for debugging and system monitor
//           for example: connect this module to a RAM to monitor or modify RAM data
//

module debug_uart #(
    parameter  UART_RX_CLK_DIV = 108, // 50MHz/4/115200Hz=108
    parameter  UART_TX_CLK_DIV = 434, // 50MHz/1/115200Hz=434
    parameter  WRITE_TIMEOUT   = 200, // wait for wgnt cycles
    parameter  READ_TIMEOUT    = 200, // wait for rgnt cycles
    parameter  ADDR_BYTE_WIDTH = 4,
    parameter  DATA_BYTE_WIDTH = 4,
    parameter  bit READ_IMM    = 0    // 0: read after rgnt : Capture rdata in the next clock cycle of rgnt=1
                                      // 1: read immediately: Capture rdata in the clock cycle of rgnt=1
)(
    input  logic clk, rst_n,
    
    output logic wreq,
    input  logic wgnt,
    output logic [ADDR_BYTE_WIDTH*8-1:0] waddr,
    output logic [DATA_BYTE_WIDTH*8-1:0] wdata,
    
    output logic rreq,
    input  logic rgnt,
    output logic [ADDR_BYTE_WIDTH*8-1:0] raddr,
    input  logic [DATA_BYTE_WIDTH*8-1:0] rdata, // NOTE: rdata will app
    
    input  logic uart_rx,
    output logic uart_tx
);

localparam MSG_LEN = 10;
localparam TX_LEN = (DATA_BYTE_WIDTH*2>MSG_LEN) ? DATA_BYTE_WIDTH*2 : MSG_LEN;

localparam logic [MSG_LEN*8-1:0] MSG_TIMEOUT    = "timeout!  ";
localparam logic [MSG_LEN*8-1:0] MSG_INVALID    = "invalid!  ";
localparam logic [MSG_LEN*8-1:0] MSG_WRITE_DONE = "write done";

initial begin
    wreq = '0;
    waddr = '0;
    wdata = '0;
    rreq = '0;
    raddr = '0;
    uart_tx = 1'b1;
end

logic [31:0] bus_time = '0;
logic [ADDR_BYTE_WIDTH*8-1:0] taddr = '0;
logic [DATA_BYTE_WIDTH*8-1:0] wdatareg = '0;
logic [10*(TX_LEN+1)-1:0] txdata = '0;
logic [31:0] txcnt = '0;
logic [31:0] txcyclecnt = '0;
enum  {NEW, ADDR, EQUAL, DATA, FINAL, TRASH, READ, READOUT, WRITE, UARTTX} fsm = NEW;

function automatic logic iswhite(input [7:0] ch);
    return (ch==" "  || ch=="\t" );
endfunction

function automatic logic isnewline(input [7:0] ch);
    return (ch=="\r"  || ch=="\n" );
endfunction

function automatic logic ishexdigit(input [7:0] ch);
    return ( (ch>="0" && ch<="9" ) || (ch>="a" && ch<="f" ) || (ch>="A" && ch<="F" ) );
endfunction

function automatic logic [3:0] ascii2hex(input [7:0] ch);
    logic [7:0] rxbinary;
    if(ch>="0" && ch<="9" ) begin
        rxbinary = ch - "0";
    end else if(ch>="a" && ch<="f" ) begin
        rxbinary = ch - "a" + 8'd10;
    end else if(ch>="A" && ch<="F" ) begin
        rxbinary = ch - "A" + 8'd10;
    end else begin
        rxbinary = 8'h0;
    end
    return rxbinary[3:0];
endfunction

function automatic logic [7:0] hex2ascii(input [3:0] hex);
    return (hex<4'hA) ? (hex+"0") : (hex+("A"-8'hA)) ;
endfunction

task automatic ReadBusAction(input req=1'b0, input [ADDR_BYTE_WIDTH*8-1:0] addr='0);
    rreq  <= req;
    raddr <= addr;
endtask

task automatic WriteBusAction(input req=1'b0, input [ADDR_BYTE_WIDTH*8-1:0] addr='0, input [DATA_BYTE_WIDTH*8-1:0] data='0);
    wreq  <= req;
    waddr <= addr;
    wdata <= data;
endtask

task automatic TxClear();
    txdata <= '0;
    txcnt <= '0;
    txcyclecnt = '0;
endtask

task automatic TxLoadMessage(input [MSG_LEN*8-1:0] msg);
    for(int ii=0; ii<TX_LEN; ii++) begin
        if(ii<MSG_LEN)
            txdata[ii*10+:10] <= {1'b1, msg[(8*(MSG_LEN-1-ii))+:8], 1'b0};
        else
            txdata[ii*10+:10] <= {1'b1, " "  , 1'b0};
    end
    txdata[(TX_LEN+0)*10+:10] <= {1'b1, "\n" , 1'b0};
    txcnt <= (TX_LEN+2)*10;
    txcyclecnt = 0;
endtask

task automatic TxLoadData(input [DATA_BYTE_WIDTH*8-1:0] data);
    for(int ii=0; ii<TX_LEN; ii++) begin
        if(ii<DATA_BYTE_WIDTH*2)
            txdata[ii*10+:10] <= {1'b1, hex2ascii(data[(4*(DATA_BYTE_WIDTH*2-1-ii))+:4]), 1'b0};
        else
            txdata[ii*10+:10] <= {1'b1, " "  , 1'b0};
    end
    txdata[(TX_LEN+0)*10+:10] <= {1'b1, "\n" , 1'b0};
    txcnt <= (TX_LEN+2)*10;
    txcyclecnt = 0;
endtask

task automatic TxIter();
    if((++txcyclecnt)>=UART_TX_CLK_DIV) begin
        txcnt <= txcnt-1;
        txcyclecnt = 0;
        {txdata, uart_tx} <= {1'b1, txdata};
    end
endtask


// --------------------------------------------------------------------------------------
//  handle UART RX
// --------------------------------------------------------------------------------------
logic [ 5:0] shift = '0, rx_status = '0;
logic [31:0] rxcyclecnt = 0;
logic last_busy=1'b0, uart_rx_reg = 1'b1, rxready = 1'b0;
logic [7:0] databuf='0, rxdata='0;

wire rxbusy = (rx_status!=6'h0);
wire rx_bit = (shift[0]&shift[1]) | (shift[0]&uart_rx_reg) | (shift[1]&uart_rx_reg);

always @ (posedge clk or negedge rst_n)
    if(~rst_n) begin
        uart_rx_reg <= 1'b1;
        rxready <= 1'b0;
        last_busy <= 1'b0;
    end else begin
        uart_rx_reg <= uart_rx;
        rxready <= (~rxbusy & last_busy);
        last_busy <= rxbusy;
    end

always @ (posedge clk or negedge rst_n)
    if(~rst_n) begin
        rxcyclecnt = 0;
        rx_status = '0;
        databuf = '0;
        rxdata = '0;
        shift = '0;
    end else begin
        if( (++rxcyclecnt) >= UART_RX_CLK_DIV ) begin
            rxcyclecnt = 0;
            if(~rxbusy) begin
                if(shift == 6'b111000)
                    rx_status <= 6'h1;
            end else begin
                if(rx_status[5] == 1'b0) begin
                    if(rx_status[1:0] == 2'b11)
                        databuf <= {rx_bit, databuf[7:1]};
                    rx_status <= rx_status + 6'h1;
                end else begin
                    if(rx_status<62) begin
                        rx_status <= 6'd62;
                        rxdata <= databuf;
                    end else begin
                        rx_status <= rx_status + 6'd1;
                    end
                end
            end
            shift <= shift<<1;
            shift[0] <= uart_rx_reg;
        end
    end


// --------------------------------------------------------------------------------------
//  main FSM
// --------------------------------------------------------------------------------------
always @ (posedge clk or negedge rst_n)
    if(~rst_n) begin
        ReadBusAction();
        WriteBusAction();
        TxClear();
        {taddr,wdatareg} <= '0;
        bus_time = '0;
        uart_tx <= 1'b1;
    end else begin
        case(fsm)
        NEW: begin
            ReadBusAction();
            WriteBusAction();
            TxClear();
            {taddr,wdatareg} <= '0;
            bus_time = '0;
            uart_tx <= 1'b1;
            if(rxready) begin
                if(ishexdigit(rxdata)) begin
                    fsm <= ADDR;
                    taddr[3:0] <= ascii2hex(rxdata);
                end else if(~iswhite(rxdata) & ~isnewline(rxdata))
                    fsm <= TRASH;
            end
        end
        ADDR: if(rxready) begin
            if (isnewline(rxdata))
                fsm <= READ;
            else if(ishexdigit(rxdata))
                taddr <= {taddr, ascii2hex(rxdata)};
            else if(iswhite(rxdata))
                fsm <= EQUAL;
            else
                fsm <= TRASH;
        end
        EQUAL: if(rxready) begin
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
        DATA: if(rxready) begin
            if( isnewline(rxdata) )
                fsm <= WRITE;
            else if( ishexdigit(rxdata) )
                wdatareg <= {wdatareg, ascii2hex(rxdata)};  // get a data
            else if( iswhite(rxdata) )
                fsm <= FINAL;
            else
                fsm <= TRASH;
        end
        FINAL: if(rxready) begin
            if( isnewline(rxdata) )
                fsm <= WRITE;
            else if( iswhite(rxdata) )
                fsm <= FINAL;
            else 
                fsm <= TRASH;
        end
        TRASH: if(rxready) begin
            if( isnewline(rxdata) ) begin
                fsm <= UARTTX;
                TxLoadMessage(MSG_INVALID);
            end
        end
        READ: begin
            if(rreq & rgnt) begin
                ReadBusAction();
                if(READ_IMM) begin
                    fsm  <= UARTTX;
                    TxLoadData(rdata);
                end else
                    fsm  <= READOUT;
            end else begin
                if( (bus_time++) < READ_TIMEOUT )
                    ReadBusAction(1, taddr); // maintain bus read
                else begin
                    ReadBusAction();
                    fsm  <= UARTTX;
                    TxLoadMessage(MSG_TIMEOUT);
                end
            end
        end
        READOUT: begin
            fsm  <= UARTTX;
            TxLoadData(rdata);
        end
        WRITE: begin
            if(wreq & wgnt) begin
                WriteBusAction();
                fsm  <= UARTTX;
                TxLoadMessage(MSG_WRITE_DONE);
            end else begin
                if( (bus_time++) < WRITE_TIMEOUT )
                    WriteBusAction(1, taddr, wdatareg); // maintain bus write
                else begin
                    WriteBusAction();
                    fsm  <= UARTTX;
                    TxLoadMessage(MSG_TIMEOUT);
                end
            end
        end
        UARTTX: begin
            if(txcnt>0)
                TxIter();
            else begin
                uart_tx <= 1'b1;
                fsm <= NEW;
            end
        end
        default: fsm <= NEW;
        endcase
    end

endmodule
