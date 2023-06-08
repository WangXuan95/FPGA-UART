
//--------------------------------------------------------------------------------------------------------
// Module  : uart_rx
// Type    : synthesizable, IP's top
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: input  UART signal,
//           output AXI-stream (1 byte data width)
//--------------------------------------------------------------------------------------------------------

module uart_rx #(
    // clock frequency
    parameter  CLK_FREQ  = 50000000,     // clk frequency, Unit : Hz
    // UART format
    parameter  BAUD_RATE = 115200,       // Unit : Hz
    parameter  PARITY    = "NONE",       // "NONE", "ODD", or "EVEN"
    // RX fifo depth
    parameter  FIFO_EA   = 0             // 0:no fifo   1,2:depth=4   3:depth=8   4:depth=16  ...  10:depth=1024   11:depth=2048  ...
) (
    input  wire        rstn,
    input  wire        clk,
    // UART RX input signal
    input  wire        i_uart_rx,
    // output AXI-stream master. Associated clock = clk. 
    input  wire        o_tready,
    output reg         o_tvalid,
    output reg  [ 7:0] o_tdata,
    // report whether there's a overflow
    output reg         o_overflow
);



//---------------------------------------------------------------------------------------------------------------------------------------------------------------
// Generate fractional precise upper limit for counter
//---------------------------------------------------------------------------------------------------------------------------------------------------------------
localparam  BAUD_CYCLES      = ( (CLK_FREQ*10*2 + BAUD_RATE) / (BAUD_RATE*2) ) / 10 ;
localparam  BAUD_CYCLES_FRAC = ( (CLK_FREQ*10*2 + BAUD_RATE) / (BAUD_RATE*2) ) % 10 ;

localparam           HALF_BAUD_CYCLES =  BAUD_CYCLES    / 2;
localparam  THREE_QUARTER_BAUD_CYCLES = (BAUD_CYCLES*3) / 4;

localparam [9:0] ADDITION_CYCLES = (BAUD_CYCLES_FRAC == 0) ? 10'b0000000000 :
                                   (BAUD_CYCLES_FRAC == 1) ? 10'b0000010000 :
                                   (BAUD_CYCLES_FRAC == 2) ? 10'b0010000100 :
                                   (BAUD_CYCLES_FRAC == 3) ? 10'b0010010010 :
                                   (BAUD_CYCLES_FRAC == 4) ? 10'b0101001010 :
                                   (BAUD_CYCLES_FRAC == 5) ? 10'b0101010101 :
                                   (BAUD_CYCLES_FRAC == 6) ? 10'b1010110101 :
                                   (BAUD_CYCLES_FRAC == 7) ? 10'b1101101101 :
                                   (BAUD_CYCLES_FRAC == 8) ? 10'b1101111011 :
                                  /*BAUD_CYCLES_FRAC == 9)*/ 10'b1111101111 ;

wire [31:0] cycles [9:0];

assign cycles[0] = BAUD_CYCLES + (ADDITION_CYCLES[0] ? 1 : 0);
assign cycles[1] = BAUD_CYCLES + (ADDITION_CYCLES[1] ? 1 : 0);
assign cycles[2] = BAUD_CYCLES + (ADDITION_CYCLES[2] ? 1 : 0);
assign cycles[3] = BAUD_CYCLES + (ADDITION_CYCLES[3] ? 1 : 0);
assign cycles[4] = BAUD_CYCLES + (ADDITION_CYCLES[4] ? 1 : 0);
assign cycles[5] = BAUD_CYCLES + (ADDITION_CYCLES[5] ? 1 : 0);
assign cycles[6] = BAUD_CYCLES + (ADDITION_CYCLES[6] ? 1 : 0);
assign cycles[7] = BAUD_CYCLES + (ADDITION_CYCLES[7] ? 1 : 0);
assign cycles[8] = BAUD_CYCLES + (ADDITION_CYCLES[8] ? 1 : 0);
assign cycles[9] = BAUD_CYCLES + (ADDITION_CYCLES[9] ? 1 : 0);



//---------------------------------------------------------------------------------------------------------------------------------------------------------------
// Input beat
//---------------------------------------------------------------------------------------------------------------------------------------------------------------
reg        rx_d1 = 1'b0;

always @ (posedge clk or negedge rstn)
    if (~rstn)
        rx_d1 <= 1'b0;
    else
        rx_d1 <= i_uart_rx;



//---------------------------------------------------------------------------------------------------------------------------------------------------------------
// count continuous '1'
//---------------------------------------------------------------------------------------------------------------------------------------------------------------
reg [31:0] count1 = 0;

always @ (posedge clk or negedge rstn)
    if (~rstn) begin
        count1 <= 0;
    end else begin
        if (rx_d1)
            count1 <= (count1 < 'hFFFFFFFF) ? (count1 + 1) : count1;
        else
            count1 <= 0;
    end



//---------------------------------------------------------------------------------------------------------------------------------------------------------------
// main FSM
//---------------------------------------------------------------------------------------------------------------------------------------------------------------
localparam [ 3:0] TOTAL_BITS_MINUS1 = (PARITY == "ODD" || PARITY == "EVEN") ? 4'd9 : 4'd8;

localparam [ 1:0] S_IDLE     = 2'd0 ,
                  S_RX       = 2'd1 ,
                  S_STOP_BIT = 2'd2 ;

reg        [ 1:0] state   = S_IDLE;
reg        [ 8:0] rxbits  = 9'b0;
reg        [ 3:0] rxcnt   = 4'd0;
reg        [31:0] cycle   = 1;
reg        [32:0] countp  = 33'h1_0000_0000;       // countp>=0x100000000 means '1' is majority       , countp<0x100000000 means '0' is majority
wire              rxbit   = countp[32];            // countp>=0x100000000 corresponds to countp[32]==1, countp<0x100000000 corresponds to countp[32]==0

wire [ 7:0] rbyte   = (PARITY == "ODD" ) ? rxbits[7:0] : 
                      (PARITY == "EVEN") ? rxbits[7:0] : 
                    /*(PARITY == "NONE")*/ rxbits[8:1] ;

wire parity_correct = (PARITY == "ODD" ) ? ((~(^(rbyte))) == rxbits[8]) : 
                      (PARITY == "EVEN") ? (  (^(rbyte))  == rxbits[8]) : 
                    /*(PARITY == "NONE")*/      1'b1                    ;


always @ (posedge clk or negedge rstn)
    if (~rstn) begin
        state    <= S_IDLE;
        rxbits   <= 9'b0;
        rxcnt    <= 4'd0;
        cycle    <= 1;
        countp   <= 33'h1_0000_0000;
    end else begin
        case (state)
            S_IDLE : begin
                if ((count1 >= THREE_QUARTER_BAUD_CYCLES) && (rx_d1 == 1'b0))  // receive a '0' which is followed by continuous '1' for half baud cycles
                    state <= S_RX;
                rxcnt  <= 4'd0;
                cycle  <= 2;                                                   // we've already receive a '0', so here cycle  = 2
                countp <= (33'h1_0000_0000 - 33'd1);                           // we've already receive a '0', so here countp = initial_value - 1
            end
            
            S_RX :
                if ( cycle < cycles[rxcnt] ) begin                             // cycle loop from 1 to cycles[rxcnt]
                    cycle  <= cycle + 1;
                    countp <= rx_d1 ? (countp + 33'd1) : (countp - 33'd1);
                end else begin
                    cycle  <= 1;                                               // reset counter
                    countp <= 33'h1_0000_0000;                                 // reset counter
                    
                    if ( rxcnt < TOTAL_BITS_MINUS1 ) begin                     // rxcnt loop from 0 to TOTAL_BITS_MINUS1
                        rxcnt <= rxcnt + 4'd1;
                        if ((rxcnt == 4'd0) && (rxbit == 1'b1))                // except start bit, but get '1'
                            state <= S_IDLE;                                   // RX failed, back to IDLE
                    end else begin
                        rxcnt <= 4'd0;
                        state <= S_STOP_BIT;
                    end
                    
                    rxbits <= {rxbit, rxbits[8:1]};                            // put current rxbit to MSB of rxbits, and right shift other bits
                end
            
            default :  // S_STOP_BIT
                if ( cycle < THREE_QUARTER_BAUD_CYCLES) begin                  // cycle loop from 1 to THREE_QUARTER_BAUD_CYCLES
                    cycle <= cycle + 1;
                end else begin
                    cycle <= 1;                                                // reset counter
                    state <= S_IDLE;                                           // back to IDLE
                end
        endcase
    end



//---------------------------------------------------------------------------------------------------------------------------------------------------------------
// RX result byte
//---------------------------------------------------------------------------------------------------------------------------------------------------------------
reg       f_tvalid = 1'b0;
reg [7:0] f_tdata  = 8'h0;

always @ (posedge clk or negedge rstn)
    if (~rstn) begin
        f_tvalid <= 1'b0;
        f_tdata  <= 8'h0;
    end else begin
        f_tvalid <= 1'b0;
        f_tdata  <= 8'h0;
        if (state == S_STOP_BIT) begin
            if ( cycle < THREE_QUARTER_BAUD_CYCLES) begin
            end else begin
                if ((count1 >= HALF_BAUD_CYCLES) && parity_correct) begin  // stop bit have enough '1', and parity correct
                    f_tvalid <= 1'b1;
                    f_tdata  <= rbyte;                                     // received a correct byte, output it
                end
            end
        end
    end



//---------------------------------------------------------------------------------------------------------------------------------------------------------------
// RX fifo
//---------------------------------------------------------------------------------------------------------------------------------------------------------------
wire f_tready;

generate if (FIFO_EA <= 0) begin          // no RX fifo
    
    assign       f_tready = o_tready;
    always @ (*) o_tvalid = f_tvalid;
    always @ (*) o_tdata  = f_tdata;

end else begin                            // TX fifo

    localparam        EA     = (FIFO_EA <= 2) ? 2 : FIFO_EA;

    reg  [7:0] buffer [ ((1<<EA)-1) : 0 ];

    localparam [EA:0] A_ZERO = {{EA{1'b0}}, 1'b0};
    localparam [EA:0] A_ONE  = {{EA{1'b0}}, 1'b1};

    reg  [EA:0] wptr      = A_ZERO;
    reg  [EA:0] wptr_d1   = A_ZERO;
    reg  [EA:0] wptr_d2   = A_ZERO;
    reg  [EA:0] rptr      = A_ZERO;
    wire [EA:0] rptr_next = (o_tvalid & o_tready) ? (rptr+A_ONE) : rptr;

    assign f_tready = ( wptr != {~rptr[EA], rptr[EA-1:0]} );

    always @ (posedge clk or negedge rstn)
        if (~rstn) begin
            wptr    <= A_ZERO;
            wptr_d1 <= A_ZERO;
            wptr_d2 <= A_ZERO;
        end else begin
            if (f_tvalid & f_tready)
                wptr <= wptr + A_ONE;
            wptr_d1 <= wptr;
            wptr_d2 <= wptr_d1;
        end

    always @ (posedge clk)
        if (f_tvalid & f_tready)
            buffer[wptr[EA-1:0]] <= f_tdata;

    always @ (posedge clk or negedge rstn)
        if (~rstn) begin
            rptr <= A_ZERO;
            o_tvalid <= 1'b0;
        end else begin
            rptr <= rptr_next;
            o_tvalid <= (rptr_next != wptr_d2);
        end

    always @ (posedge clk)
        o_tdata <= buffer[rptr_next[EA-1:0]];

    initial o_tvalid = 1'b0;
    initial o_tdata  = 8'h0;
end endgenerate



//---------------------------------------------------------------------------------------------------------------------------------------------------------------
// detect RX fifo overflow
//---------------------------------------------------------------------------------------------------------------------------------------------------------------
initial o_overflow = 1'b0;

always @ (posedge clk or negedge rstn)
    if (~rstn)
        o_overflow <= 1'b0;
    else
        o_overflow <= (f_tvalid & (~f_tready));



//---------------------------------------------------------------------------------------------------------------------------------------------------------------
// parameter checking
//---------------------------------------------------------------------------------------------------------------------------------------------------------------
initial begin
    if (BAUD_CYCLES < 10) begin $error("invalid parameter : BAUD_CYCLES < 10, please use a faster driving clock"); $stop; end
    
    $display("uart_rx :           parity = %s" , PARITY );
    $display("uart_rx :     clock period = %.0f ns   (%-10d Hz)" , 1000000000.0/CLK_FREQ  , CLK_FREQ );
    $display("uart_rx : baud rate period = %.0f ns   (%-10d Hz)" , 1000000000.0/BAUD_RATE , BAUD_RATE);
    $display("uart_rx :      baud cycles = %-10d"    , BAUD_CYCLES );
    $display("uart_rx : baud cycles frac = %-10d"    , BAUD_CYCLES_FRAC  );
    
    if (PARITY == "ODD" || PARITY == "EVEN") begin
        $display("uart_rx :             __      ____ ____ ____ ____ ____ ____ ____ ____________ ");
        $display("uart_rx :        wave   \\____/____X____X____X____X____X____X____X____X____/   ");
        $display("uart_rx :        bits   | S  | B0 | B1 | B2 | B3 | B4 | B5 | B6 | B7 | P  |   ");
        $display("uart_rx : time_points  t0   t1   t2   t3   t4   t5   t6   t7   t8   t9   t10  ");
        $display("uart_rx :");
    end else begin
        $display("uart_rx :             __      ____ ____ ____ ____ ____ ____ ____ _______ ");
        $display("uart_rx :        wave   \\____/____X____X____X____X____X____X____X____/   ");
        $display("uart_rx :        bits   | S  | B0 | B1 | B2 | B3 | B4 | B5 | B6 | B7 |   ");
        $display("uart_rx : time_points  t0   t1   t2   t3   t4   t5   t6   t7   t8   t9   ");
        $display("uart_rx :");
    end
end

generate genvar index;
    for (index=0; index<=9; index=index+1) begin : print_and_check_time
        localparam cycles_acc = ( (index >= 0) ? (BAUD_CYCLES + (ADDITION_CYCLES[0] ? 1 : 0)) : 0 )
                              + ( (index >= 1) ? (BAUD_CYCLES + (ADDITION_CYCLES[1] ? 1 : 0)) : 0 )
                              + ( (index >= 2) ? (BAUD_CYCLES + (ADDITION_CYCLES[2] ? 1 : 0)) : 0 )
                              + ( (index >= 3) ? (BAUD_CYCLES + (ADDITION_CYCLES[3] ? 1 : 0)) : 0 )
                              + ( (index >= 4) ? (BAUD_CYCLES + (ADDITION_CYCLES[4] ? 1 : 0)) : 0 )
                              + ( (index >= 5) ? (BAUD_CYCLES + (ADDITION_CYCLES[5] ? 1 : 0)) : 0 )
                              + ( (index >= 6) ? (BAUD_CYCLES + (ADDITION_CYCLES[6] ? 1 : 0)) : 0 )
                              + ( (index >= 7) ? (BAUD_CYCLES + (ADDITION_CYCLES[7] ? 1 : 0)) : 0 )
                              + ( (index >= 8) ? (BAUD_CYCLES + (ADDITION_CYCLES[8] ? 1 : 0)) : 0 )
                              + ( (index >= 9) ? (BAUD_CYCLES + (ADDITION_CYCLES[9] ? 1 : 0)) : 0 ) ;
        
        localparam real ideal_time_ns  = ((index+1)*1000000000.0/BAUD_RATE);
        localparam real actual_time_ns = (cycles_acc*1000000000.0/CLK_FREQ);
        localparam real uncertainty    = (1000000000.0/CLK_FREQ);
        localparam real error          = ( (ideal_time_ns>actual_time_ns) ? (ideal_time_ns-actual_time_ns) : (-ideal_time_ns+actual_time_ns) ) + uncertainty;
        localparam real relative_error_percent = (error / (1000000000.0/BAUD_RATE)) * 100.0;
        
        initial if (PARITY == "ODD" || PARITY == "EVEN" || index < 9) begin
            $display("uart_rx : t%-2d- t0 = %.0f ns (ideal)  %.0f +- %.0f ns (actual).   error=%.0f ns   relative_error=%.3f%%" ,
                (index+1) ,
                ideal_time_ns ,
                actual_time_ns,
                uncertainty,
                error,
                relative_error_percent
            );
            
            if ( relative_error_percent > 8.0 ) begin $error("relative_error is too large"); $stop; end   // if relative error larger than 8%
        end
    end
endgenerate


endmodule
