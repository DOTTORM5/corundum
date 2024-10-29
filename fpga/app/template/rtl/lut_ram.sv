`timescale 1ns / 1ps

module lut_ram #(
    parameter DATA_WIDTH=256,
    parameter ADDR_WIDTH=32
)(
    input  logic rst,
    input  logic [(DATA_WIDTH-1):0] data_in,
    input  logic [(ADDR_WIDTH-1):0] read_addr, write_addr,
    input  logic wr_en, clk,
    output logic [(DATA_WIDTH-1):0] data_out
);

(* rw_addr_collision = "yes" *)(* ram_style = "distributed" *) reg [DATA_WIDTH-1:0] l_ram[0:2**ADDR_WIDTH-1];


always @ (posedge clk ) begin
    if (wr_en) begin
        l_ram[write_addr] <= data_in;
    end
end

assign data_out = l_ram[read_addr];

endmodule