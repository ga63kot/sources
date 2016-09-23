// Copyright 2016 by the authors
//
// Copyright and related rights are licensed under the Solderpad
// Hardware License, Version 0.51 (the "License"); you may not use
// this file except in compliance with the License. You may obtain a
// copy of the License at http://solderpad.org/licenses/SHL-0.51.
// Unless required by applicable law or agreed to in writing,
// software, hardware and materials distributed under this License is
// distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS
// OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the
// License.
//
// Authors:
//    Stefan Wallentowitz <stefan@wallentowitz.de>

import dii_package::dii_flit;

module osd_debug_processor
  #(
    parameter REG_ADDR_WIDTH = 5, // the address width of the core register file
    parameter XLEN = 64
    )
   (
    input                       clk, rst,

    input [9:0]                 id,

    input dii_flit              debug_in,
    output                      debug_in_ready,
    output dii_flit             debug_out,
    input                       debug_out_ready,

    input                       trace_valid,
    input [15:0]                trace_id,
    input [XLEN-1:0]            trace_value,

    output                      trace_reg_enable,
    output [REG_ADDR_WIDTH-1:0] trace_reg_addr
    );

   logic        reg_request;
   logic        reg_write;
   logic [15:0] reg_addr;
   logic [1:0]  reg_size;
   logic [15:0] reg_wdata;
   logic        reg_ack;
   logic        reg_err;
   logic [15:0] reg_rdata;

   logic                   stall;

   dii_flit dp_out, dp_in;
   logic        dp_out_ready, dp_in_ready;

   osd_regaccess_layer
     #(.MODID(16'h7), .MODVERSION(16'h0),
       .MAX_REG_SIZE(16), .CAN_STALL(1))
   u_regaccess(.*,
               .module_in (dp_out),
               .module_in_ready (dp_out_ready),
               .module_out (dp_in),
               .module_out_ready (dp_in_ready));

   always @(*) begin
      reg_ack = 1;
      reg_rdata = 'x;
      reg_err = 0;

      case (reg_addr)
        16'h200: reg_rdata = 16'(XLEN);
        default: reg_err = reg_request;
      endcase // case (reg_addr)
   end // always @ (*)


   logic [1:0] dbgnoc_in_valid = 0;
   assign dbgnoc_in_valid [1] = dp_in.valid;

   debug_coprocessor
   u_debug_coprocessor(
		// Outputs
		.dbgnoc_in_ready (dp_in_ready),
		.dbgnoc_out_flit (dp_out),
		.dbgnoc_out_valid (dp_out.valid),
		.trace (),		

		// Inputs
		.clk (clk),
		.rst (rst),
		.rst_sys (0),
		.dbgnoc_in_flit (dp_in),
		.dbgnoc_in_valid (dbgnoc_in_valid),
		.dbgnoc_out_ready (dp_out_ready)
   		);
   // Outputs
//   dbgnoc_in_ready, dbgnoc_out_flit, dbgnoc_out_valid, trace,
   // Inputs
//   clk, rst, rst_cpu, rst_sys, dbgnoc_in_flit, dbgnoc_in_valid, dbgnoc_out_ready
//   cpu_stall

endmodule // osd_stm