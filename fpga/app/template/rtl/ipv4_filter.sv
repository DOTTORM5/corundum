`timescale 1ns/1ps

module ipv4_filter #(
    parameter IPV4_HEADER_WIDTH = 160
) (
    input logic clk,
    input logic rst,
    input logic [IPV4_HEADER_WIDTH-1:0] ipv4_header,
    
    output logic packet_valid
);

reg [IPV4_HEADER_WIDTH-1:0] ipv4_header_rules [0:0];
reg r_packet_valid;

assign packet_valid = r_packet_valid;

always_comb begin
    foreach ( ipv4_header_rules[i] ) begin
        if ( ipv4_header[7:4] == 4'h4 /*&& ipv4_header[127:96] == ipv4_header_rules[i][127:96]*/ ) begin
            r_packet_valid <= 1'b1;
            break;
        end
        else begin
            r_packet_valid <= 1'b0;
        end
    end
end


endmodule