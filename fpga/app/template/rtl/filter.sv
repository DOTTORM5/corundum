/* The Filter is the first component on the receiving path */
/* It accepts a packet based on the Ethernet and IP header and on its internal rules configured by the host */
`timescale 1ns / 1ps

module filter #(
    parameter AXIS_DATA_WIDTH = 512,
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
    parameter ETHERNET_HEADER_WIDTH = 112,
    parameter IPV4_HEADER_WIDTH = 160
) (
    input logic clk,
    input logic rst,
    AXIS.s      s_axis,
    AXIS.m      m_axis
);

/* Buffer register to save the incoming packet */
reg [AXIS_DATA_WIDTH-1:0] packet_buffer; 
reg [AXIS_KEEP_WIDTH-1:0] tkeep_buffer;
reg                       tlast_buffer;
/* Flag to inform that a packet arrived */
reg packet_ready;

wire ipv4_packet_valid;
wire ethernet_packet_valid;

reg packet_valid;

reg r_s_axis_tready;
assign s_axis.tready = r_s_axis_tready;

reg [AXIS_DATA_WIDTH-1:0] r_m_axis_tdata;
reg [AXIS_KEEP_WIDTH-1:0] r_m_axis_tkeep;
reg                       r_m_axis_tvalid;
reg                       r_m_axis_tlast;

assign m_axis.tvalid = r_m_axis_tvalid;
assign m_axis.tdata  = r_m_axis_tdata;
assign m_axis.tkeep  = r_m_axis_tkeep;
assign m_axis.tlast  = r_m_axis_tlast;


always_ff @( posedge clk or posedge rst ) begin : data_sampling
    if ( rst ) begin
        packet_buffer <= 'b0;
        packet_ready  <= 1'b0;
        tkeep_buffer  <= 'b0;
        tlast_buffer  <= 1'b0;
    end
    else begin
        if ( s_axis.tvalid & r_s_axis_tready ) begin 
            packet_buffer <= s_axis.tdata;
            packet_ready  <= 1'b1;
            tkeep_buffer  <= s_axis.tkeep;
            tlast_buffer  <= s_axis.tlast;
        end 
        else begin
            packet_buffer <= packet_buffer;
            packet_ready  <= 1'b0;
            tkeep_buffer  <= 'b0;
            tlast_buffer  <= 1'b0;
        end
    end
end

always_ff @( posedge clk or posedge rst ) begin : tready_driver
    if ( rst ) begin
        r_s_axis_tready <= 1'b0;
    end
    else begin
        if ( s_axis.tvalid & ~r_s_axis_tready ) begin
            r_s_axis_tready <= 1'b1;
        end 
        else if ( s_axis.tvalid & r_s_axis_tready ) begin
            r_s_axis_tready <= 1'b1;
        end
        else begin
            r_s_axis_tready <= 1'b0;
        end
    end
end

// always_ff @ ( posedge clk or posedge rst ) begin
//     if ( rst ) begin
//         packet_valid <= 1'b0;
//     end
//     else begin
//         if ( ethernet_packet_valid & ipv4_packet_valid & packet_ready & ~packet_valid) begin
//             packet_valid <= 1'b1;
//         end  
//         else if (tlast_buffer & packet_valid) begin
//             packet_valid <= 1'b0;
//         end
//         else begin
//             packet_valid <= packet_valid;
//         end
//     end
// end

always_latch begin : packet_valid_driver
    if ( rst ) begin
        packet_valid <= 1'b0;
    end
    else begin 
        if ( tlast_buffer ) begin
            packet_valid <= 1'b0;
        end
        else if ( /*ethernet_packet_valid & ipv4_packet_valid &*/ packet_ready & ~packet_valid) begin
            packet_valid <= 1'b1;
        end  
        else begin
            packet_valid <= packet_valid;
            // packet_valid <= 1'b0;
        end
    end
end

ethernet_filter #(
    .ETHERNET_HEADER_WIDTH(ETHERNET_HEADER_WIDTH)
) ethernet_filter_i (
    .clk(clk),
    .rst(rst),
    .ethernet_header(packet_buffer[ETHERNET_HEADER_WIDTH-1:0]),
    .packet_valid(ethernet_packet_valid)
);

ipv4_filter #(
    .IPV4_HEADER_WIDTH(IPV4_HEADER_WIDTH)
) ipv4_filter_i (
    .clk(clk),
    .rst(rst),
    .ipv4_header(packet_buffer[IPV4_HEADER_WIDTH+ETHERNET_HEADER_WIDTH-1:ETHERNET_HEADER_WIDTH]),
    .packet_valid(ipv4_packet_valid)
);


always_ff @( posedge clk or posedge rst ) begin
    if ( rst ) begin
        r_m_axis_tvalid <= 1'b0;
        r_m_axis_tdata  <= 'b0;
        r_m_axis_tkeep  <= 'b0;
        r_m_axis_tlast  <= 1'b0;
    end
    else begin
        if ( ethernet_packet_valid & ipv4_packet_valid & packet_ready & ~packet_valid ) begin
            r_m_axis_tvalid <= 1'b1;
            r_m_axis_tdata  <= packet_buffer;
            r_m_axis_tkeep  <= tkeep_buffer;
            r_m_axis_tlast  <= tlast_buffer;
        end
        else if ( packet_valid /*& m_axis.tready*/ || tlast_buffer ) begin
            r_m_axis_tvalid <= 1'b1;
            r_m_axis_tdata  <= packet_buffer;
            r_m_axis_tkeep  <= tkeep_buffer;
            r_m_axis_tlast  <= tlast_buffer;
        end
        else begin
            r_m_axis_tvalid <= 1'b0;
            r_m_axis_tdata  <= r_m_axis_tdata;
            r_m_axis_tkeep  <= r_m_axis_tkeep;
            r_m_axis_tlast  <= r_m_axis_tlast;
        end
    end
end


endmodule