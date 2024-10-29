`timescale 1ns/1ps

module ethernet_filter #(
    parameter ETHERNET_HEADER_WIDTH = 112
) (
    input logic clk,
    input logic rst,
    input logic [ETHERNET_HEADER_WIDTH-1:0] ethernet_header,
    
    output logic packet_valid
);

reg [ETHERNET_HEADER_WIDTH-1:0] ethernet_header_rules [0:0];
reg r_packet_valid;

assign packet_valid = r_packet_valid;

always_comb begin
    foreach ( ethernet_header_rules[i] ) begin
        if ( /*ethernet_header[47:0] == ethernet_header_rules[i][47:0] && ethernet_header[111:96] == ethernet_header_rules[i][111:96]*/ 1 ) begin
            r_packet_valid <= 1'b1;
            break;
        end
        else begin
            r_packet_valid <= 1'b0;
        end
    end
end
    
endmodule