`include "axi.svh"

module memory_fetcher (
    input   logic        clk,
    input   logic        rst,

    input   logic        match_valid_i,
    output  logic        match_ready_o,
    input   logic [7:0]  match_addr_i,
    input   logic [15:0] match_pkt_len_i,

    `DEFINE_AXIS_MASTER_PORT(m)
); 

localparam S_IDLE = 1'b0;   
localparam S_BUSY = 1'b1;  /* Serving a match */


logic current_state;
logic next_state;

logic [15:0] seg_tx_cnt; /* 64 bytes segment transmitted */
logic [7:0]  match_addr_buffer; 
logic [15:0] match_pkt_len_buffer;

logic [7:0]  rd_addr_ram;
logic [AXIS_DATA_WIDTH-1:0] data_out_ram;


always_ff @ ( posedge clk or posedge rst ) begin
    if ( rst ) begin
        current_state <= S_IDLE;
    end
    else begin
        current_state <= next_state;
    end
end

always_comb begin
    next_state = current_state;

    case (current_state)
        
        S_IDLE : begin
            if ( match_valid_i == 1'b1 ) begin
                next_state = S_BUSY;
            end
            else begin
                next_state = current_state;
            end
        end 
        
        S_BUSY : begin
            if ( seg_tx_cnt >= /*$ceil*//*(match_pkt_len_buffer/64)*/ 10 ) begin
                next_state = S_IDLE;
            end
            else begin
                next_state = current_state;
            end
        end
    endcase
end

always_ff @ ( posedge clk or posedge rst ) begin
    if ( rst ) begin
        match_addr_buffer      <= 'b0; 
        match_pkt_len_buffer   <= 'b0;
    end
    else begin
        if ( current_state == S_IDLE && match_valid_i == 1'b1 ) begin
            match_addr_buffer      <= match_addr_i; 
            match_pkt_len_buffer   <= match_pkt_len_i;
        end
        else begin
            match_addr_buffer      <= match_addr_buffer; 
            match_pkt_len_buffer   <= match_pkt_len_buffer;
        end
    end
end

always_ff @ ( posedge clk or posedge rst ) begin
    if ( rst ) begin
        seg_tx_cnt <= 'b0;
    end
    else begin
        if ( current_state == S_BUSY ) begin
            seg_tx_cnt <= seg_tx_cnt + 1'b1;
        end
        else if (current_state == S_IDLE) begin
            seg_tx_cnt <= 'b0;
        end
        else begin
            seg_tx_cnt <= 'b0;
        end
    end
end

always_ff @ ( posedge clk or posedge rst ) begin
    if ( rst ) begin
        rd_addr_ram <= 'b0;
    end
    else begin
        if ( current_state == S_IDLE && match_valid_i == 1'b1 ) begin
            rd_addr_ram <= match_addr_i;
        end
        else if ( current_state == S_BUSY && m_axis_tready ) begin
            rd_addr_ram <= rd_addr_ram + 1;
        end
        else if (current_state == S_IDLE) begin
            rd_addr_ram <= 'b0;
        end
        else begin
            rd_addr_ram <= 'b0;
        end
    end
end


always_ff @ ( posedge clk or posedge rst ) begin
    if ( rst ) begin
        m_axis_tvalid <= 1'b0;
        m_axis_tdata  <= 'b0;
        m_axis_tkeep  <= 'b0;
        m_axis_tlast  <= 1'b0;
    end
    else begin
        if ( current_state == S_BUSY /*&& seg_tx_cnt != 5*/ ) begin
            m_axis_tvalid <= 1'b1;
            m_axis_tdata  <= data_out_ram;
            m_axis_tkeep  <= { AXIS_KEEP_WIDTH { 1'b1 } };
            m_axis_tlast  <= 1'b1;
        end
        // else if ( current_state == S_BUSY && seg_tx_cnt == 5 ) begin
        //     m_axis_tvalid <= 1'b1;
        //     m_axis_tdata  <= data_out_ram;
        //     m_axis_tkeep  <= { AXIS_KEEP_WIDTH { 1'b1 } };
        //     m_axis_tlast  <= 1'b1;
        // end
        else if ( current_state == S_IDLE )  begin
            m_axis_tvalid <= 1'b0;
            m_axis_tdata  <= 'b0;
            m_axis_tkeep  <= { AXIS_KEEP_WIDTH { 1'b0 } };
            m_axis_tlast  <= 1'b0;
        end
    end
end

reg [7:0] ram_wr_addr; 
reg [AXIS_DATA_WIDTH-1:0] ram_data_in;
reg ram_wr_en;

always_ff @ (posedge clk or posedge rst) begin
    if ( rst ) begin
        ram_wr_en   <= 'b1;
        ram_wr_addr <= 'b0;
        ram_data_in <= 512'h9921400a9a210a08010100007eff00021880e0547408d90a65a7f4c4401f0100007f0100007f3acf06400040316c8a0100450008000000000000000000000000/*ram_data_in + { {AXIS_DATA_WIDTH/2{1'b1}} , {AXIS_DATA_WIDTH/2{1'b0}} }*/ ;
    end 
    else begin
        ram_wr_addr <= ram_wr_addr + 1'b1;
        ram_wr_en   <= 1'b1;
        ram_data_in <= 512'h9921400a9a210a08010100007eff00021880e0547408d90a65a7f4c4401f0100007f0100007f3acf06400040316c8a0100450008000000000000000000000000/*ram_data_in + { {AXIS_DATA_WIDTH/2{1'b1}} , {AXIS_DATA_WIDTH/2{1'b0}} }*/ ;
    end
end

lut_ram #(
    .DATA_WIDTH(AXIS_DATA_WIDTH),
    .ADDR_WIDTH(8)
) packet_memory (
    .rst(rst),
    .data_in(ram_data_in),
    .read_addr(rd_addr_ram), 
    .write_addr(ram_wr_addr),
    .wr_en(ram_wr_en), 
    .clk(clk),
    .data_out(data_out_ram)
);

endmodule