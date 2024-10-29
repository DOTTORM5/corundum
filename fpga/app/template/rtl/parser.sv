`timescale 1ns/1ps

module parser #(
    parameter AXIS_DATA_WIDTH = 512,
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8
) (

    input logic clk,
    input logic rst,

    /* To signal if there is the application payload in the current 512 bytes and its position (starting byte) */
    output logic payload_present,
    output logic [7:0] payload_start_byte,

    AXIS.s     s_axis,
    AXIS.m     m_axis
);

/* Ethernet header */
/* Destination MAC address       ( 6 bytes ) [ 47  : 0   ] */
/* Source MAC address            ( 6 bytes ) [ 95  : 48  ] */
/* Type - IPv4 = 0x0008          ( 2 bytes ) [ 111 : 96  ] */

/* IPv4 header */
/* Version - IPv4 = 0x4          ( 4 bits  ) [ 119 : 116 ] */
/* Internet Header Length - 0x5  ( 4 bits  ) [ 115 : 112 ] */
/* Type of service - 0x00        ( 1 byte  ) [ 127 : 120 ] */
/* Total length in bytes         ( 2 bytes ) [ 143 : 128 ] */
/* Identification number         ( 2 bytes ) [ 159 : 144 ] */
/* Flags + frag. offset - 0x0040 ( 2 bytes ) [ 175 : 160 ] */
/* TTL - 64 - 0x40               ( 1 byte  ) [ 183 : 176 ] */
/* Protocol - 0x06               ( 1 byte  ) [ 191 : 184 ] */
/* Header checksum               ( 2 bytes ) [ 207 : 192 ] */
/* Source IPv4 address           ( 4 bytes ) [ 239 : 208 ] */
/* Destination IPv4 address      ( 4 bytes ) [ 271 : 240 ] */
/* OPTIONS                       (  VAR - MAX 40 bytes  )  */ 

/* TCP header */ 
/* Source Port Number            ( 2 bytes ) [ 287 : 272 ] */
/* Destination Port Number       ( 2 bytes ) [ 303 : 288 ] */
/* Sequence Number               ( 4 bytes ) [ 335 : 304 ] */ 
/* Ack Number                    ( 4 bytes ) [ 367 : 336 ] */
/* Header length + res flgs      ( 1 byte  ) [ 375 : 368 ] */
/* Res flgs + code bits          ( 1 byte  ) [ 393 : 376 ] */
/* Window                        ( 2 bytes ) [ 409 : 394 ] */
/* Checksum                      ( 2 bytes ) [ 425 : 410 ] */
/* Urgent                        ( 2 bytes ) [ 441 : 426 ] */
/* OPTIONS                       (  VAR - MAX 40 bytes  )  */

/* ICMP header */
/* Type of message               ( 1 byte  ) [ 279 : 272 ] */
/* Code - 0x0                    ( 1 byte  ) [ 287 : 280 ] */
/* Checksum                      ( 2 bytes ) [ 303 : 288 ] */
/* Identifier                    ( 2 bytes ) [ 319 : 304 ] */
/* Sequence number               ( 2 bytes ) [ 335 : 320 ] */

/* Ethernet trailer */
/* FCS (CRC)                     ( 4 bytes ) [ 511 : 480 ] */


/* FSM States */
localparam S_IDLE = 1'b0; /* Idle */ 
localparam S_BUSY = 1'b1; /* A message is being parsed */ 

/* FSM Logic */
reg current_state;
reg next_state;

always_ff @ ( posedge clk or posedge rst ) begin
    if ( rst  ) begin
        current_state <= S_IDLE;
    end
    else begin
        current_state <= next_state;
    end
end

always_comb begin : fsm_logic
    next_state = current_state;
    case (current_state)

        S_IDLE: begin
            if ( s_axis.tvalid /*&& m_axis.tready*/ ) begin
                next_state = S_BUSY;
            end
            else begin
                next_state = current_state;
            end
        end

        S_BUSY: begin
            if ( s_axis.tlast && s_axis.tvalid /*&& m_axis.tready*/ ) begin
                next_state = S_IDLE;
            end
            else begin
                next_state = current_state;
            end
        end
    endcase
end

reg [3:0]    ipv4_header_len;
reg [15:0]   ipv4_total_len;
reg [7:0]    ipv4_protocol;
reg [31:0]   ipv4_src_addr;
reg [31:0]   ipv4_dst_addr;

reg [3:0]    tcp_header_len;

reg [7:0]    total_header_len;
 
/* Counter to track the actual 512 bits burst in a ethernet frame */
reg [4:0]    seg_cnt;

reg r_payload_present;
reg [7:0] r_payload_start_byte;

assign payload_present    =  r_payload_present;
assign payload_start_byte =  r_payload_start_byte;

always_ff @ ( posedge clk or posedge rst ) begin : ipv4_tcp_header_parser
    if ( rst ) begin
        ipv4_header_len  <= 'b0;
        ipv4_total_len   <= 'b0;
        ipv4_protocol    <= 'b0;
        ipv4_src_addr    <= 'b0;
        ipv4_dst_addr    <= 'b0;

        tcp_header_len   <= 'b0;

        total_header_len <= 'b0;
    end
    else begin
        if ( current_state == S_IDLE && s_axis.tvalid == 1'b1 /*&& m_axis.tready == 1'b1*/ ) begin
            ipv4_header_len <= s_axis.tdata[ 115 : 112 ];
            ipv4_total_len  <= { s_axis.tdata[ 135 : 128 ], s_axis.tdata[ 143 : 136 ] };
            ipv4_protocol   <= s_axis.tdata[ 191 : 184 ];
            ipv4_src_addr   <= {s_axis.tdata[ 215 : 208 ], s_axis.tdata[ 223 : 216 ], s_axis.tdata[ 231 : 224 ], s_axis.tdata[ 239 : 232 ]};
            ipv4_dst_addr   <= {s_axis.tdata[ 247 : 240 ], s_axis.tdata[ 255 : 248 ], s_axis.tdata[ 263 : 256 ], s_axis.tdata[ 271 : 264 ]};

            /* here we assume that the ipv4 header is 20 bytes without options and the transport layer is TCP */ 
            if ( s_axis.tdata[ 115 : 112 ] == 4'h5 && s_axis.tdata[ 191 : 184 ] == 8'h06) begin
                tcp_header_len <= s_axis.tdata[ 375 : 372 ];

                total_header_len <= 14 + s_axis.tdata[ 115 : 112 ]*4 + s_axis.tdata[ 375 : 372 ]*4; /* ethernet + ipv4 + tcp */
            end
            else begin
                tcp_header_len <= tcp_header_len;

                total_header_len <= 14 + s_axis.tdata[ 115 : 112 ]*4; /* + ? */ 
            end
        end
        else begin 
            ipv4_header_len  <= ipv4_header_len;
            ipv4_total_len   <= ipv4_total_len;
            ipv4_protocol    <= ipv4_protocol;
            ipv4_src_addr    <= ipv4_src_addr;
            ipv4_dst_addr    <= ipv4_dst_addr;

            tcp_header_len   <= tcp_header_len;

            total_header_len <= total_header_len;
        end
    end
end

always_ff @ ( posedge clk or posedge rst ) begin : payload_finder
    if ( rst ) begin
        r_payload_present     <= 1'b0;
        r_payload_start_byte  <= 'b0;
    end
    else begin
        if ( current_state == S_IDLE && s_axis.tvalid == 1'b1 /*&& m_axis.tready == 1'b1*/ ) begin
            if ( 14 + s_axis.tdata[ 115 : 112 ]*4 + s_axis.tdata[ 375 : 372 ]*4 < 64 ) begin        /* ethernet + ipv4 + tcp */
                r_payload_present     <= 1'b1;
            end
            else begin
                r_payload_present     <= 1'b0;
            end
            r_payload_start_byte  <= 14 + s_axis.tdata[ 115 : 112 ]*4 + s_axis.tdata[ 375 : 372 ]*4 /*+ 1*/;
        end
        else begin
            r_payload_present     <= r_payload_present;
            r_payload_start_byte  <= r_payload_start_byte;
        end
    end
end

always_ff @ ( posedge clk or posedge rst ) begin : seg_cnt_driver
    if ( rst ) begin
        seg_cnt <= 'b0;
    end
    else begin
        if ( current_state == S_IDLE && s_axis.tvalid == 1'b1 /*&& m_axis.tready == 1'b1*/ ) begin
            seg_cnt <= 5'd1;
        end
        else if ( current_state == S_BUSY && s_axis.tvalid == 1'b1 /*&& m_axis.tready == 1'b1*/ ) begin
            seg_cnt <= seg_cnt + 1'b1;
        end
        else begin
            seg_cnt <= seg_cnt;
        end
    end
end


assign m_axis.tvalid = s_axis.tvalid;
assign m_axis.tdata  = s_axis.tdata;
assign m_axis.tkeep  = s_axis.tkeep;
assign m_axis.tlast  = s_axis.tlast;
assign s_axis.tready = m_axis.tready;


endmodule