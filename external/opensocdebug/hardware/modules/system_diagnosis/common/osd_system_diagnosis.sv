`include "optimsoc_def.vh"
`include "dbg_config.vh"
`include "diagnosis_config.vh"

import dii_package::dii_flit;

module osd_system_diagnosis
  #(parameter SYSTEMID='x,
    parameter NUM_MOD='x,
    parameter MAX_PKT_LEN=8)
   (input clk, rst,

    input [9:0] id,

    input dii_flit debug_in, output debug_in_ready,
    output dii_flit debug_out, input debug_out_ready,
    // System Interface
    input [103-1:0] trace [0:0],

    input [32-1:0]  wb_adr_i,
    input [4-1:0]   wb_sel_i,
    input           wb_we_i,


    output sys_rst,
    output cpu_rst);

   logic        reg_request;
   logic        reg_write;
   logic [15:0] reg_addr;
   logic [1:0]  reg_size;
   logic [15:0] reg_wdata;
   logic        reg_ack;
   logic        reg_err;
   logic [15:0] reg_rdata;

   logic [15:0] config_reg [`DIAGNOSIS_CONF_FLITS_PER_ENTRY*`DIAGNOSIS_PC_EVENTS_MAX*2-1:0];
   logic [`DIAGNOSIS_CONF_FLITS_PER_ENTRY*16*`DIAGNOSIS_PC_EVENTS_MAX*2-1:0] conf_mem;  

   logic [1:0]  rst_vector;
   assign sys_rst = rst_vector[0] | rst;
   assign cpu_rst = rst_vector[1] | rst;
   
   osd_regaccess
       #(.MODID(16'h6), .MODVERSION(16'h0),
       .MAX_REG_SIZE(16))
   u_regaccess(.*,
               .stall ());
   
   always @(*) begin
      reg_ack = 1;
      reg_rdata = 'x;
      reg_err = 0;

      case (reg_addr)
        16'h200: reg_rdata = 16'h0;
        16'h201: reg_rdata = 16'h0;

//        default: reg_err = reg_request;
	default: reg_err = 0;
      endcase // case (reg_addr)
   end // always @ (*)

   always_ff @(posedge clk)
     if (rst)
       rst_vector <= 2'b00;
     else
       if (reg_request & reg_write & (reg_addr == 16'h203))
         rst_vector <= reg_wdata[1:0];

// Assigning Config Register
   always_ff @(posedge clk)
       if (reg_request & reg_write & (reg_addr >= 16'h200))
         config_reg[reg_addr-16'h200] <= reg_wdata;

   for (genvar i = 0 ; i <= `DIAGNOSIS_CONF_FLITS_PER_ENTRY*`DIAGNOSIS_PC_EVENTS_MAX*2; i = i + 1) begin
   	assign conf_mem[16*i+15:16*i] = config_reg[i];
   end 



// System Signals
   // Monitor system behavior in simulation
   parameter NUM_CORES=1;
//   parameter DEBUG_TRACE_EXEC_WIDTH=103;
   wire [`DEBUG_TRACE_EXEC_WIDTH*NUM_CORES-1:0] trace_array [0:NUM_CORES-1];
   assign trace_array = trace;

   wire                                        trace_enable   [0:NUM_CORES-1] /*verilator public_flat_rd*/;
   wire [31:0]                                 trace_insn     [0:NUM_CORES-1] /*verilator public_flat_rd*/;
   wire [31:0]                                 trace_pc       [0:NUM_CORES-1] /*verilator public_flat_rd*/;
   wire                                        trace_wben     [0:NUM_CORES-1];
   wire [4:0]                                  trace_wbreg    [0:NUM_CORES-1];
   wire [31:0]                                 trace_wbdata   [0:NUM_CORES-1];
   wire [31:0]                                 trace_r3       [0:NUM_CORES-1] /*verilator public_flat_rd*/;

   wire [NUM_CORES-1:0]                         termination;

   genvar i;
   generate
      for (i = 0; i < NUM_CORES; i = i + 1) begin
         assign trace_enable[i] = trace_array[i][`DEBUG_TRACE_EXEC_ENABLE_MSB:`DEBUG_TRACE_EXEC_ENABLE_LSB];
         assign trace_insn[i] = trace_array[i][`DEBUG_TRACE_EXEC_INSN_MSB:`DEBUG_TRACE_EXEC_INSN_LSB];
         assign trace_pc[i] = trace_array[i][`DEBUG_TRACE_EXEC_PC_MSB:`DEBUG_TRACE_EXEC_PC_LSB];
         assign trace_wben[i] = trace_array[i][`DEBUG_TRACE_EXEC_WBEN_MSB:`DEBUG_TRACE_EXEC_WBEN_LSB];
         assign trace_wbreg[i] = trace_array[i][`DEBUG_TRACE_EXEC_WBREG_MSB:`DEBUG_TRACE_EXEC_WBREG_LSB];
         assign trace_wbdata[i] = trace_array[i][`DEBUG_TRACE_EXEC_WBDATA_MSB:`DEBUG_TRACE_EXEC_WBDATA_LSB];
      end
   endgenerate

  // System Diagnosis Module Implementation
   diagnosis_system_P_without_snapshot
   u_diagnosis_system_P_without_snapshot(
	// Inputs	
	.clk (clk),
	.rst (rst),
	.time_global (1),
	.traceport_flat (trace),
	.dbgnoc_in_flit (debug_in),
	.dbgnoc_in_valid (1),
	.dbgnoc_out_ready (debug_out_ready),
	.conf_mem (conf_mem),
	// Outputs
   	.dbgnoc_in_ready (debug_in_ready),
	.dbgnoc_out_flit (debug_out),
	.dbgnoc_out_valid ()	
   );
endmodule
