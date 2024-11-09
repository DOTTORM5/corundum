
`include "axi.svh"

module rule_match_engine (
    input logic clk,
    input logic rst,

    input logic         payload_present_i,
    input logic [7:0]   payload_start_byte_i,

    output logic        match_valid_o,     /* There is a match !!! */
    input  logic        match_ready_i,     /* The packet transmitter is ready to get the match */ 
    output logic [7:0]  match_addr_o,      /* The address where the packet transmitter fetch the data to send */
    output logic [15:0] match_pkt_len_o,   /* The length in byte of the data to send */

    `DEFINE_AXIS_SLAVE_PORT(s),
    `DEFINE_AXIS_MASTER_PORT(m)
); 

/* Buffer register to save the incoming packet */
logic [AXIS_DATA_WIDTH-1:0] packet_buffer; 
logic [AXIS_KEEP_WIDTH-1:0] tkeep_buffer;
logic                       tlast_buffer;
logic [7:0]                 payload_start_byte_buffer;
/* Flag to inform that a packet arrived */
logic packet_ready;


logic [15:0] rule_byte;     /* The byte to be checked in the application payload for the rule match */
logic [2:0]  rule_symbol;   /* The symbol to be used in the rule: 0. ==, 1. >, 2. <, 3. >=, 4. <= */
logic [7:0]  rule_value;    /* The value of the byte in the position rule_byte in the application payload */

// initial begin
//     rule_byte   <= 341;
//     rule_symbol <= 0;
//     rule_value  <= 8'h7d;  /* 0x7d = } */
// end

logic ram_wr_en;
logic [19:0]  ram_wr_addr;
logic [34:0] ram_data_in;
logic [34:0] ram_data_out;
logic [19:0]  ram_rd_addr;

my_block_ram #(
    .DATA_WIDTH(35),
    .ADDR_WIDTH(20)
) block_ram_i (
    .data_in(ram_data_in),
    .read_addr(ram_rd_addr), 
    .write_addr(ram_wr_addr),
    .wr_en(ram_wr_en), 
    .clk(clk),
    .data_out(ram_data_out)
);

always_ff @(posedge clk or posedge rst) begin
    if ( rst ) begin
        rule_byte   <= 14;
        rule_symbol <= 0;
        rule_value  <= 8'h45;  /* 0x7d = } */
        
        ram_data_in <= 'b0; 
        ram_wr_en   <= 1'b0;
        ram_rd_addr <= 'b0;
        ram_wr_addr <= 'b0;
    end
    else begin
        ram_wr_en   <= 1'b1;
        ram_rd_addr <= ram_rd_addr + 1'b1;
        ram_wr_addr <= ram_wr_addr + 1'b1;
        ram_data_in <= ram_data_in + 1'b1;

        // rule_byte   <= ram_data_out[34:19];
        // rule_symbol <= ram_data_out[18:16];
        // rule_value  <= ram_data_out[15:8];
    end
end


/* Matcher */
always_ff @ ( posedge clk or posedge rst ) begin
    if ( rst ) begin
        match_valid_o   <= 1'b0;
        match_addr_o    <= 'b0;
        match_pkt_len_o <= 192;
    end
    else begin
        if ( packet_ready == 1'b1 ) begin
            case (rule_symbol) 
                0 : begin
                    if ( packet_buffer/*[(8*14)+8-1 : 8*14]*/[(payload_start_byte_buffer + rule_byte - (((payload_start_byte_buffer + rule_byte) >> 6) << 6 ))*8 +: 8] == rule_value ) begin
                        match_valid_o   <= 1'b1;
                        match_addr_o    <= ram_data_out[7:0] /*'b0*/;
                        match_pkt_len_o <= 192; 
                    end
                    else begin
                        match_valid_o   <= 1'b0;
                        match_addr_o    <= ram_data_out[7:0] /*'b0*/;
                        match_pkt_len_o <= 'b0;
                    end
                end
                1 : begin
                    if ( packet_buffer[(payload_start_byte_buffer + rule_byte - (64*((payload_start_byte_buffer + rule_byte)/64)))*8 +: 8] > rule_value ) begin
                        // match_valid_o <= 1'b1;
                    end
                    else begin
                        // match_valid_o   <= 1'b0;
                        match_addr_o    <= ram_data_out[7:0] /*'b0*/;
                        match_pkt_len_o <= 'b0;
                    end
                end
                2 : begin 
                    if ( packet_buffer[(payload_start_byte_buffer + rule_byte - (64*((payload_start_byte_buffer + rule_byte)/64)))*8 +: 8] < rule_value ) begin
                        // match_valid_o <= 1'b1;
                    end
                    else begin
                        // match_valid_o   <= 1'b0;
                        match_addr_o    <= ram_data_out[7:0] /*'b0*/;
                        match_pkt_len_o <= 'b0;
                    end
                end
                3 : begin
                    if ( packet_buffer[(payload_start_byte_buffer + rule_byte - (64*((payload_start_byte_buffer + rule_byte)/64)))*8 +: 8] >= rule_value ) begin
                        // match_valid_o <= 1'b1;
                    end
                    else begin
                        // match_valid_o   <= 1'b0;
                        match_addr_o    <= ram_data_out[7:0] /*'b0*/;
                        match_pkt_len_o <= 'b0;
                    end
                end 
                4 : begin
                    if ( packet_buffer[(payload_start_byte_buffer + rule_byte - (64*((payload_start_byte_buffer + rule_byte)/64)))*8 +: 8] <= rule_value ) begin
                        // match_valid_o <= 1'b1;
                    end
                    else begin
                        // match_valid_o   <= 1'b0;
                        match_addr_o    <= ram_data_out[7:0] /*'b0*/;
                        match_pkt_len_o <= 'b0;
                    end
                end
                default: begin
                    match_valid_o   <= 1'b0;
                    match_addr_o    <= 'b0;
                    match_pkt_len_o <= 'b0;
                end 
            endcase
        end
        else begin
            match_valid_o <= 1'b0;
        end
    end
end


always_ff @( posedge clk or posedge rst ) begin : data_sampling
    if ( rst ) begin
        packet_buffer              <= 'b0;
        packet_ready               <= 1'b0;
        tkeep_buffer               <= 'b0;
        tlast_buffer               <= 1'b0;
        payload_start_byte_buffer  <= 'b0;
    end
    else begin
        if ( s_axis_tvalid & s_axis_tready ) begin 
            packet_buffer             <= s_axis_tdata;
            packet_ready              <= 1'b1;
            tkeep_buffer              <= s_axis_tkeep;
            tlast_buffer              <= s_axis_tlast;
            payload_start_byte_buffer <= payload_start_byte_i;
        end 
        else begin
            packet_buffer             <= packet_buffer;
            packet_ready              <= 1'b0;
            tkeep_buffer              <= 'b0;
            tlast_buffer              <= 1'b0;
            payload_start_byte_buffer <= payload_start_byte_buffer;
        end
    end
end

always_ff @( posedge clk or posedge rst ) begin : tready_driver
    if ( rst ) begin
        s_axis_tready <= 1'b0;
    end
    else begin
        if ( s_axis_tvalid & ~s_axis_tready ) begin
            s_axis_tready <= 1'b1;
        end 
        else if ( s_axis_tvalid & s_axis_tready ) begin
            s_axis_tready <= 1'b1;
        end
        else begin
            s_axis_tready <= 1'b0;
        end
    end
end

always_ff @( posedge clk or posedge rst ) begin
    if ( rst ) begin
        m_axis_tvalid <= 1'b0;
        m_axis_tdata  <= 'b0;
        m_axis_tkeep  <= 'b0;
        m_axis_tlast  <= 1'b0;
    end
    else begin
        if ( packet_ready ) begin
            m_axis_tvalid <= 1'b1;
            m_axis_tdata  <= packet_buffer;
            m_axis_tkeep  <= tkeep_buffer;
            m_axis_tlast  <= tlast_buffer;
        end
        else begin
            m_axis_tvalid <= 1'b0;
            m_axis_tdata  <= m_axis_tdata;
            m_axis_tkeep  <= m_axis_tkeep;
            m_axis_tlast  <= m_axis_tlast;
        end
    end
end


endmodule