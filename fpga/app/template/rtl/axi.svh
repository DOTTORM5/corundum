/* AXI Utils */
`ifndef AXI_SVH__
`define AXI_SVH__

localparam int AXIS_DATA_WIDTH = 512;
localparam int AXIS_KEEP_WIDTH = 512/8;


`define DEFINE_AXIS_SLAVE_PORT(port_name) \
    input  logic [AXIS_DATA_WIDTH-1:0]     ``port_name``_axis_tdata,   \
    input  logic [AXIS_DATA_WIDTH/8-1:0]   ``port_name``_axis_tkeep,   \
    input  logic                           ``port_name``_axis_tlast,   \
    output logic                           ``port_name``_axis_tready,  \
    input  logic                           ``port_name``_axis_tvalid   \

`define DEFINE_AXIS_MASTER_PORT(port_name) \
    output logic  [AXIS_DATA_WIDTH-1:0]     ``port_name``_axis_tdata,   \
    output logic  [AXIS_DATA_WIDTH/8-1:0]   ``port_name``_axis_tkeep,   \
    output logic                            ``port_name``_axis_tlast,   \
    input  logic                            ``port_name``_axis_tready,  \
    output logic                            ``port_name``_axis_tvalid   \

`define DECLARE_AXIS_BUS(bus_name) \
    logic  [AXIS_DATA_WIDTH-1:0]     ``bus_name``_axis_tdata;   \
    logic  [AXIS_DATA_WIDTH/8-1:0]   ``bus_name``_axis_tkeep;   \
    logic                            ``bus_name``_axis_tlast;   \
    logic                            ``bus_name``_axis_tready;  \
    logic                            ``bus_name``_axis_tvalid   \


`endif
