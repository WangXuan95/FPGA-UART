
module tb_axis_inc_source # (
    parameter    BYTE_WIDTH = 4
) (
    input  wire                    rstn,
    input  wire                    clk,
    // AXI-stream master
    input  wire                    o_tready,
    output reg                     o_tvalid,
    output reg  [8*BYTE_WIDTH-1:0] o_tdata,
    output reg  [  BYTE_WIDTH-1:0] o_tkeep,
    output reg                     o_tlast
);



//-----------------------------------------------------------------------------------------------------------------------------
// function : generate random unsigned integer
//-----------------------------------------------------------------------------------------------------------------------------
function  [31:0] randuint;
    input [31:0] min;
    input [31:0] max;
begin
    randuint = $random;
    if ( min != 0 || max != 'hFFFFFFFF )
        randuint = (randuint % (1+max-min)) + min;
end
endfunction



initial {o_tvalid, o_tdata, o_tkeep, o_tlast} = 0;

reg [BYTE_WIDTH-1:0] keep = 0;
reg [7:0] next_byte = 8'h0;

reg [31:0] delay = 100000;

integer i;

always @ (posedge clk or negedge rstn)
    if (~rstn) begin
        {o_tvalid, o_tdata, o_tkeep, o_tlast} <= 0;
        next_byte = 8'h0;
        delay <= 100000;
    end else begin
        if (delay > 0) begin
            delay <= delay - 1;
        end else begin
            if (o_tready | ~o_tvalid) begin
                if ( randuint(0,4) == 0 ) begin
                    o_tvalid <= 1'b1;
                    keep = randuint(0, 'hFFFFFFFF);
                    for (i=0; i<BYTE_WIDTH; i=i+1) begin
                        if (keep[i]) begin
                            o_tdata[i*8 +: 8] <= next_byte;
                            next_byte = next_byte + 8'd1;
                        end
                    end
                    o_tkeep <= keep;
                    o_tlast <= (randuint(0,100) == 0);
                end else begin
                    o_tvalid <= 1'b0;
                end
            end
        end
    end


endmodule 
