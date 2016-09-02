/* 
 This is the toplevel module of the diagnosis system.
 It holds interfaces for the necessary openrisc nodes 
 (program counter, writeback signal etc.) and a debug-NoC
 interface for system configuration and output of 
 snapshot packets.
 The letters at the end of the module name stand for the
 monitor modules that are included. In this system, there
 are available:
 P: Program counter monitor
 R: Function return monitor
 
 Author: Markus Goehrle, <Markus.Goehrle@tum.de>
 */

`include "diagnosis_config.vh"

`include "lisnoc_def.vh"
`include "lisnoc16_def.vh"

module diagnosis_system_PR(/*AUTOARG*/
   // Outputs
   dbgnoc_in_ready, dbgnoc_out_flit, dbgnoc_out_valid,
   // Inputs
   clk, rst, time_global, traceport_flat, dbgnoc_in_flit,
   dbgnoc_in_valid, dbgnoc_out_ready
   );


   /** Configuration memory: 16 bit flits **/
   /** We have currently 3 x 16 bit flits for one config entry (including valid flag).
    Also, the LUT module holds exactly half the config entries of the system.
    This makes a total configuration memory size of 3 x 2 x TOTAL_EVENTS_MAX 
    Furthermore, we have to consider three more flits for CORE_ID, Module_type + version and system on/off flag**/
   localparam CONF_FLITS_PER_ENTRY = `DIAGNOSIS_CONF_FLITS_PER_ENTRY;
   localparam CONF_MEM_SIZE = (2 * CONF_FLITS_PER_ENTRY * `DIAGNOSIS_TOTAL_EVENTS_MAX) + 3;
   localparam CONF_PC_SIZE = `DIAGNOSIS_PC_EVENTS_MAX * CONF_FLITS_PER_ENTRY;
   localparam CONF_FCNRET_SIZE = `DIAGNOSIS_FCNRET_EVENTS_MAX * CONF_FLITS_PER_ENTRY;
   localparam CONF_MEMADDR_SIZE = `DIAGNOSIS_MEMADDR_EVENTS_MAX * CONF_FLITS_PER_ENTRY;
   localparam CONF_LUT_SIZE = `DIAGNOSIS_TOTAL_EVENTS_MAX * CONF_FLITS_PER_ENTRY;
  
 /* Core ID */
   parameter CORE_ID = 16'hx;
   
   
   /** Debug NoC Parameters **/
   parameter DBG_NOC_DATA_WIDTH = `FLIT16_CONTENT_WIDTH;
   parameter DBG_NOC_FLIT_TYPE_WIDTH = `FLIT16_TYPE_WIDTH;
   localparam DBG_NOC_FLIT_WIDTH = DBG_NOC_DATA_WIDTH + DBG_NOC_FLIT_TYPE_WIDTH;
   parameter DBG_NOC_VCHANNELS = 1;
	parameter DBG_NOC_TRACE_VCHANNEL = 0;
   parameter DBG_NOC_CONF_VCHANNEL = 0;
   
   input clk, rst;

   /* mor1kx program counter interface */
   wire [31:0] pc_val;
   wire        pc_enable;

   /* mor1kx writeback register interface */
   wire        wb_enable;
   wire [`DIAGNOSIS_WB_REG_WIDTH-1:0] wb_reg;
   wire [`DIAGNOSIS_WB_DATA_WIDTH-1:0] wb_data;


   /* mor1kx instruction trace interface */
   wire [31:0]                         trace_insn;
   wire                                trace_enable;

   /* interface to global timestamp provider module */
   input [`DIAGNOSIS_TIMESTAMP_WIDTH-1:0] time_global;

   /* Execution traceport in a single signal */
   input [`DEBUG_TRACE_EXEC_WIDTH-1:0]    traceport_flat;
   assign pc_val = traceport_flat[`DEBUG_TRACE_EXEC_PC_MSB:`DEBUG_TRACE_EXEC_PC_LSB];
   assign pc_enable = traceport_flat[`DEBUG_TRACE_EXEC_ENABLE_MSB:`DEBUG_TRACE_EXEC_ENABLE_LSB];
   assign wb_enable = traceport_flat[`DEBUG_TRACE_EXEC_WBEN_MSB:`DEBUG_TRACE_EXEC_WBEN_LSB];
   assign wb_reg = traceport_flat[`DEBUG_TRACE_EXEC_WBREG_MSB:`DEBUG_TRACE_EXEC_WBREG_LSB];
   assign wb_data = traceport_flat[`DEBUG_TRACE_EXEC_WBDATA_MSB:`DEBUG_TRACE_EXEC_WBDATA_LSB];
   assign trace_insn = traceport_flat[`DEBUG_TRACE_EXEC_INSN_MSB:`DEBUG_TRACE_EXEC_INSN_LSB];
   assign trace_enable = traceport_flat[`DEBUG_TRACE_EXEC_ENABLE_MSB:`DEBUG_TRACE_EXEC_ENABLE_LSB];

   /* Debug NoC interface */
   input [DBG_NOC_FLIT_WIDTH-1:0]         dbgnoc_in_flit;
   input [DBG_NOC_VCHANNELS-1:0]          dbgnoc_in_valid;
   output [DBG_NOC_VCHANNELS-1:0]         dbgnoc_in_ready;
   output [DBG_NOC_FLIT_WIDTH-1:0]    dbgnoc_out_flit;
   output [DBG_NOC_VCHANNELS-1:0]     dbgnoc_out_valid;
   input [DBG_NOC_VCHANNELS-1:0]          dbgnoc_out_ready;

 
   
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [31:0]          bv_GPR;                 // From u_LUT of LUT.v
   wire [CONF_MEM_SIZE*16-1:0] conf_mem_flat_out;// From u_packetizer of Packetizer.v
   wire [`DIAGNOSIS_EV_ID_WIDTH-1:0] ev_id;     // From u_LUT of LUT.v
   wire [`DIAGNOSIS_TIMESTAMP_WIDTH-1:0] ev_time;// From u_LUT of LUT.v
   wire                 event_valid_global;     // From u_LUT of LUT.v
   wire [`DIAGNOSIS_EV_ID_WIDTH-1:0] fcnret_ev_id;// From u_fcnreturn_monitor of fcnreturn_monitor.v
   wire [`DIAGNOSIS_TIMESTAMP_WIDTH-1:0] fcnret_ev_time;// From u_fcnreturn_monitor of fcnreturn_monitor.v
   wire                 fcnret_ev_valid;        // From u_fcnreturn_monitor of fcnreturn_monitor.v
   wire [`DIAGNOSIS_WB_REG_WIDTH-1:0] gpr_addr_o;// From u_stack of Stack.v
   wire [`DIAGNOSIS_WB_DATA_WIDTH:0] out_GPR_data;// From u_GPR of GPR.v
   wire                 out_GPR_rdy;            // From u_packetizer of Packetizer.v
   wire [2:0]           out_GPR_type;           // From u_GPR of GPR.v
   wire                 out_GPR_valid;          // From u_GPR of GPR.v
   wire [`DIAGNOSIS_WB_DATA_WIDTH:0] out_stack_data;// From u_stack of Stack.v
   wire                 out_stack_rdy;          // From u_packetizer of Packetizer.v
   wire [2:0]           out_stack_type;         // From u_stack of Stack.v
   wire                 out_stack_valid;        // From u_stack of Stack.v
   wire [`DIAGNOSIS_EV_ID_WIDTH-1:0] pc_ev_id;  // From u_PC_monitor of PC_monitor.v
   wire [`DIAGNOSIS_TIMESTAMP_WIDTH-1:0] pc_ev_time;// From u_PC_monitor of PC_monitor.v
   wire                 pc_ev_valid;            // From u_PC_monitor of PC_monitor.v
   wire [`DIAGNOSIS_WB_DATA_WIDTH-1:0] stackarg_data_o;// From u_GPR of GPR.v
   wire [5:0]           stackargs;              // From u_LUT of LUT.v
   // End of automatics

   /*** Wiring of configuration registers that are stored in the packetizer module ***/
   localparam CONF_DISCOVERY_SIZE = 31; // The first two config flits are for CPUID and Module Type
   localparam CONF_SYSTEMONOFF_LSB = CONF_DISCOVERY_SIZE + 1;
   localparam CONF_SYSTEMONOFF_MSB = CONF_SYSTEMONOFF_LSB + 16 - 1;
   localparam CONF_PC_LSB = CONF_SYSTEMONOFF_MSB + 1;
   localparam CONF_PC_MSB = CONF_PC_LSB + 16*CONF_PC_SIZE - 1;
   localparam CONF_FCNRET_LSB = CONF_PC_MSB + 1;
   localparam CONF_FCNRET_MSB = CONF_FCNRET_LSB + 16*CONF_FCNRET_SIZE - 1;
   localparam CONF_MEMADDR_LSB = CONF_FCNRET_MSB + 1;
   localparam CONF_MEMADDR_MSB = CONF_MEMADDR_LSB + 16*CONF_MEMADDR_SIZE - 1;
   localparam CONF_LUT_LSB = CONF_MEMADDR_MSB + 1;
   localparam CONF_LUT_MSB = CONF_LUT_LSB + 16* CONF_LUT_SIZE - 1;

   wire                 diag_sys_enabled;
   wire [16*CONF_PC_SIZE-1:0] conf_pc_flat_in;
   wire [16*CONF_FCNRET_SIZE-1:0] conf_fcnret_flat_in;
   wire [16*CONF_MEMADDR_SIZE-1:0] conf_memaddr_flat_in;
   wire [16*CONF_LUT_SIZE-1:0]     conf_lut_flat_in;

   assign diag_sys_enabled = conf_mem_flat_out[CONF_SYSTEMONOFF_LSB];
   assign conf_pc_flat_in = conf_mem_flat_out[CONF_PC_MSB:CONF_PC_LSB];
   assign conf_fcnret_flat_in = conf_mem_flat_out[CONF_FCNRET_MSB:CONF_FCNRET_LSB];
   assign conf_memaddr_flat_in = conf_mem_flat_out[CONF_MEMADDR_MSB:CONF_MEMADDR_LSB];
   assign conf_lut_flat_in = conf_mem_flat_out[CONF_LUT_MSB:CONF_LUT_LSB];

   
   PC_monitor
     #(.CONF_PC_SIZE(CONF_PC_SIZE))
     u_PC_monitor(/*AUTOINST*/
                  // Outputs
                  .pc_ev_valid          (pc_ev_valid),
                  .pc_ev_id             (pc_ev_id[`DIAGNOSIS_EV_ID_WIDTH-1:0]),
                  .pc_ev_time           (pc_ev_time[`DIAGNOSIS_TIMESTAMP_WIDTH-1:0]),
                  // Inputs
                  .clk                  (clk),
                  .rst                  (rst),
                  .diag_sys_enabled     (diag_sys_enabled),
                  .conf_pc_flat_in      (conf_pc_flat_in[16*CONF_PC_SIZE-1:0]),
                  .pc_val               (pc_val[31:0]),
                  .pc_enable            (pc_enable),
                  .time_global          (time_global[`DIAGNOSIS_TIMESTAMP_WIDTH-1:0]));


   fcnreturn_monitor
     #(.CONF_FCNRET_SIZE(CONF_FCNRET_SIZE))
     u_fcnreturn_monitor(/*AUTOINST*/
                         // Outputs
                         .fcnret_ev_valid       (fcnret_ev_valid),
                         .fcnret_ev_id          (fcnret_ev_id[`DIAGNOSIS_EV_ID_WIDTH-1:0]),
                         .fcnret_ev_time        (fcnret_ev_time[`DIAGNOSIS_TIMESTAMP_WIDTH-1:0]),
                         // Inputs
                         .clk                   (clk),
                         .rst                   (rst),
                         .diag_sys_enabled      (diag_sys_enabled),
                         .conf_fcnret_flat_in   (conf_fcnret_flat_in[16*CONF_FCNRET_SIZE-1:0]),
                         .pc_val                (pc_val[31:0]),
                         .pc_enable             (pc_enable),
                         .wb_enable             (wb_enable),
                         .wb_reg                (wb_reg[`DIAGNOSIS_WB_REG_WIDTH-1:0]),
                         .wb_data               (wb_data[`DIAGNOSIS_WB_DATA_WIDTH-1:0]),
                         .time_global           (time_global[`DIAGNOSIS_TIMESTAMP_WIDTH-1:0]));

/* LUT AUTO_TEMPLATE(
 .memaddr_ev_valid            (1'b0),
 .memaddr_ev_id               (),
 .memaddr_ev_time             (),
 );*/
   
   LUT
     #(.CONF_LUT_SIZE(CONF_LUT_SIZE))
     u_LUT(/*AUTOINST*/
           // Outputs
           .event_valid_global          (event_valid_global),
           .bv_GPR                      (bv_GPR[31:0]),
           .stackargs                   (stackargs[5:0]),
           .ev_id                       (ev_id[`DIAGNOSIS_EV_ID_WIDTH-1:0]),
           .ev_time                     (ev_time[`DIAGNOSIS_TIMESTAMP_WIDTH-1:0]),
           // Inputs
           .clk                         (clk),
           .rst                         (rst),
           .conf_lut_flat_in            (conf_lut_flat_in[16*CONF_LUT_SIZE-1:0]),
           .pc_ev_valid                 (pc_ev_valid),
           .pc_ev_id                    (pc_ev_id[`DIAGNOSIS_EV_ID_WIDTH-1:0]),
           .pc_ev_time                  (pc_ev_time[`DIAGNOSIS_TIMESTAMP_WIDTH-1:0]),
           .fcnret_ev_valid             (fcnret_ev_valid),
           .fcnret_ev_id                (fcnret_ev_id[`DIAGNOSIS_EV_ID_WIDTH-1:0]),
           .fcnret_ev_time              (fcnret_ev_time[`DIAGNOSIS_TIMESTAMP_WIDTH-1:0]),
           .memaddr_ev_valid            (1'b0),                  // Templated
           .memaddr_ev_id               (),                      // Templated
           .memaddr_ev_time             ());                      // Templated

/* Packetizer AUTO_TEMPLATE(
    .in_GPR_\(.*\) (out_GPR_\1[]),
    .in_stack_\(.*\) (out_stack_\1[]),
 
    );*/
   
   Packetizer
      #(.DBG_NOC_VCHANNELS(DBG_NOC_VCHANNELS),
		  .DBG_NOC_TRACE_VCHANNEL(DBG_NOC_TRACE_VCHANNEL),
        .DBG_NOC_CONF_VCHANNEL(DBG_NOC_CONF_VCHANNEL),
        .CONF_MEM_SIZE(CONF_MEM_SIZE),
        .CORE_ID(CORE_ID)
)
     u_packetizer(/*AUTOINST*/
                  // Outputs
                  .conf_mem_flat_out    (conf_mem_flat_out[CONF_MEM_SIZE*16-1:0]),
                  .in_GPR_rdy           (out_GPR_rdy),           // Templated
                  .in_stack_rdy         (out_stack_rdy),         // Templated
                  .dbgnoc_in_ready      (dbgnoc_in_ready[DBG_NOC_VCHANNELS-1:0]),
                  .dbgnoc_out_flit      (dbgnoc_out_flit[DBG_NOC_FLIT_WIDTH-1:0]),
                  .dbgnoc_out_valid     (dbgnoc_out_valid[DBG_NOC_VCHANNELS-1:0]),
                  // Inputs
                  .clk                  (clk),
                  .rst                  (rst),
                  .event_valid_global   (event_valid_global),
                  .ev_id                (ev_id[`DIAGNOSIS_EV_ID_WIDTH-1:0]),
                  .ev_time              (ev_time[`DIAGNOSIS_TIMESTAMP_WIDTH-1:0]),
                  .in_GPR_data          (out_GPR_data[`DIAGNOSIS_WB_DATA_WIDTH-1:0]), // Templated
                  .in_GPR_type          (out_GPR_type[2:0]),     // Templated
                  .in_GPR_valid         (out_GPR_valid),         // Templated
                  .in_stack_data        (out_stack_data[`DIAGNOSIS_WB_DATA_WIDTH-1:0]), // Templated
                  .in_stack_type        (out_stack_type[2:0]),   // Templated
                  .in_stack_valid       (out_stack_valid),       // Templated
                  .dbgnoc_in_flit       (dbgnoc_in_flit[DBG_NOC_FLIT_WIDTH-1:0]),
                  .dbgnoc_in_valid      (dbgnoc_in_valid[DBG_NOC_VCHANNELS-1:0]),
                  .dbgnoc_out_ready     (dbgnoc_out_ready[DBG_NOC_VCHANNELS-1:0]));


   /* GPR AUTO_TEMPLATE(
    .stackarg_addr_i (gpr_addr_o),
    .bv_valid     (event_valid_global),
    );*/
   GPR
     u_GPR(/*AUTOINST*/
           // Outputs
           .out_GPR_data                (out_GPR_data[`DIAGNOSIS_WB_DATA_WIDTH:0]),
           .out_GPR_type                (out_GPR_type[2:0]),
           .out_GPR_valid               (out_GPR_valid),
           .stackarg_data_o             (stackarg_data_o[`DIAGNOSIS_WB_DATA_WIDTH-1:0]),
           // Inputs
           .clk                         (clk),
           .rst                         (rst),
           .wb_enable                   (wb_enable),
           .wb_reg                      (wb_reg[`DIAGNOSIS_WB_REG_WIDTH-1:0]),
           .wb_data                     (wb_data[`DIAGNOSIS_WB_DATA_WIDTH-1:0]),
           .bv_GPR                      (bv_GPR[31:0]),
           .bv_valid                    (event_valid_global),    // Templated
           .out_GPR_rdy                 (out_GPR_rdy),
           .stackarg_addr_i             (gpr_addr_o));            // Templated

   /* Stack AUTO_TEMPLATE(
    .gpr_data_i (stackarg_data_o),
    .args_valid (event_valid_global),
    .args_in (stackargs),
    );*/
   Stack
     u_stack(/*AUTOINST*/
             // Outputs
             .gpr_addr_o                (gpr_addr_o[`DIAGNOSIS_WB_REG_WIDTH-1:0]),
             .out_stack_data            (out_stack_data[`DIAGNOSIS_WB_DATA_WIDTH:0]),
             .out_stack_type            (out_stack_type[2:0]),
             .out_stack_valid           (out_stack_valid),
             // Inputs
             .clk                       (clk),
             .rst                       (rst),
             .trace_insn                (trace_insn[31:0]),
             .trace_enable              (trace_enable),
             .args_in                   (stackargs),             // Templated
             .args_valid                (event_valid_global),    // Templated
             .gpr_data_i                (stackarg_data_o),       // Templated
             .out_stack_rdy             (out_stack_rdy));
/*
   trafficmonitor
     u_trafficmonitor(
                      // Inputs
                      .clk              (clk),
                      .rst              (rst),
                      .ev_counter (),
                      .event_global     (event_valid_global),
                      .flit_valid       (dbgnoc_out_valid[1]));//1?
   
   */
   endmodule
