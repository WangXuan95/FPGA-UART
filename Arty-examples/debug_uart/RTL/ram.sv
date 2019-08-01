module ram #(
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

logic [DATA_LEN-1:0] ram [RAM_SIZE];

initial rd_data = 0;

always @ (posedge clk)
    rd_data <= ram[rd_addr];

always @ (posedge clk)
    if(wr_req)
        ram[wr_addr] <= wr_data;

endmodule
