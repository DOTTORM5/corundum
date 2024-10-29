`timescale 1ns / 1ps

module my_block_ram #(
    parameter DATA_WIDTH=35,
    parameter ADDR_WIDTH=20
)(
    input  logic [(DATA_WIDTH-1):0] data_in,
    input  logic [(ADDR_WIDTH-1):0] read_addr, write_addr,
    input  logic wr_en, clk,
    output logic [(DATA_WIDTH-1):0] data_out
);

(* dont_touch = "True" *)(* keep = "True"*)(* ram_style = "block" *) reg [DATA_WIDTH-1:0] ram[0:2**ADDR_WIDTH-1];

reg read_addr_buff;

always @ (posedge clk ) begin
    read_addr_buff <= read_addr;
    if (wr_en) begin
        ram[write_addr] <= data_in;
    end
end

assign data_out = ram[read_addr_buff];

endmodule