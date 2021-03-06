/**
 * This file is part of LISNoC.
 * 
 * LISNoC is free hardware: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as 
 * published by the Free Software Foundation, either version 3 of 
 * the License, or (at your option) any later version.
 *
 * As the LGPL in general applies to software, the meaning of
 * "linking" is defined as using the LISNoC in your projects at
 * the external interfaces.
 * 
 * LISNoC is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public 
 * License along with LISNoC. If not, see <http://www.gnu.org/licenses/>.
 * 
 * =================================================================
 * 
 * Simple (software-controlled) message passing module.
 * 
 * (c) 2012-2013 by the author(s)
 * 
 * Author(s): 
 *    Stefan Wallentowitz, stefan.wallentowitz@tum.de
 *
 */

/**
 *
 *                   +-> Input path <- packet buffer <-- NoC
 *                   |    * raise interrupt (!empty)
 * Bus interface --> +    * read size flits from packet buffer
 *                   |
 *                   +-> Output path -> packet buffer --> NoC 
 *                        * set size
 *                        * write flits to packet buffer
 * 
 */

module dbgnoc_na_input(/*AUTOARG*/
   // Outputs
//   noc_out_flit, noc_out_valid, 
	noc_in_ready, bus_data_out, bus_ack,
   irq, bus_full_packet,
   // Inputs
   clk, rst, 
//	noc_out_ready, 
	noc_in_flit, noc_in_valid, 
	bus_addr, bus_we, bus_en //bus_data_in
   );

   parameter noc_data_width = 16;
   parameter noc_type_width = 2;
   localparam noc_flit_width = noc_data_width + noc_type_width;

   parameter  fifo_depth = 16;
   localparam size_width = clog2(fifo_depth+1);
   
   input clk;
   input rst;

   // NoC interface
//   output [noc_flit_width-1:0] noc_out_flit;
//   output                      noc_out_valid;
//   input                       noc_out_ready;

   input [noc_flit_width-1:0] noc_in_flit;
   input                      noc_in_valid;
   output                     noc_in_ready;

   // Bus side (generic)
   input [5:0]                     bus_addr;
   input                           bus_we;
   input                           bus_en;
//   input [noc_data_width-1:0]      bus_data_in;
   output reg [noc_data_width-1:0] bus_data_out;
   output reg                      bus_ack;

   output                          irq;
	output reg						     bus_full_packet;
   
   // Connect from the outgoing state machine to the packet buffer   
//   wire                        out_ready;
//   reg                         out_valid;
//   wire [noc_flit_width-1:0]   out_flit;
//   reg [1:0]                   out_type;

   reg                         in_ready;
   wire                        in_valid;
   wire [noc_flit_width-1:0]   in_flit;

   assign irq = in_valid;

   // If the output type width is larger than 2 (e.g. multicast support)
   // the respective bits are set to zero.
   // Concatenate the type and directly forward the bus input to the
   // packet buffer
//   generate
//      if (noc_type_width>2) begin
//         assign out_flit = { {{noc_type_width-2}{1'b0}}, out_type, bus_data_in };
//      end else begin
//         assign out_flit = { out_type, bus_data_in };
//      end
//   endgenerate
   
//   reg out_ack;
   reg in_ack;
   reg status_ack;

   reg [noc_data_width-1:0] in_data;
   reg [noc_data_width-1:0] status_data;
   
   // Multiplex acks and data
   always @(*) begin
      bus_ack = 0;
      bus_data_out = 16'hx;
      
      if (bus_en) begin
         if (bus_we) begin
//           bus_ack = out_ack;
			  bus_ack = 1'b0;
         end else begin
            // 0x10-0x1f are status
            if (bus_addr[4]) begin
               bus_ack = status_ack;
               bus_data_out = status_data;
            end else begin
               bus_ack = in_ack;
               bus_data_out = in_data;
            end
         end
      end
   end
   
   /**
    * Simple writes to the any address (use 0x0)
    *  * Start transfer and set size S
    *  * For S flits: Write flit
    */

   // State register
//   reg [1:0]                  state_out;
//   reg [1:0]                  nxt_state_out;

   reg                        state_in;
   reg                        nxt_state_in;

   // Size register that is also used to count down the remaining
   // flits to be send out
//   reg [size_width-1:0]       size_out;
//   reg [size_width-1:0]       nxt_size_out;

   wire [size_width-1:0]      size_in;
   
   // States of output state machine
//   localparam OUT_IDLE    = 0;
//   localparam OUT_FIRST   = 1;
//   localparam OUT_PAYLOAD = 2;

   // States of input state machine
   localparam IN_IDLE = 0;
   localparam IN_FLIT = 1;

   // Combinational part of input state machine
   always @(*) begin
      in_ready = 1'b0;
      in_ack = 1'b0;
      in_data = 16'hx;
      nxt_state_in = state_in;
		bus_full_packet = 1'b0;

      case(state_in)
        IN_IDLE: begin
           bus_full_packet = 1'b1;
			  if (bus_en && !bus_we) begin
              if (in_valid) begin
                 in_data = size_in;
                 in_ack = 1'b1;
                 if (size_in!=0) begin
                    nxt_state_in = IN_FLIT;
                 end
              end else begin
                 in_data = 0;
                 in_ack = 1'b1;
                 nxt_state_in = IN_IDLE;
              end
           end else begin
              nxt_state_in = IN_IDLE;
           end
        end
        IN_FLIT: begin
           if (bus_en && !bus_we) begin
              in_data = in_flit[noc_data_width-1:0];
              in_ready = 1'b1;
              in_ack = 1'b1;
              if (size_in==1) begin
                 nxt_state_in = IN_IDLE;
              end else begin
                 nxt_state_in = IN_FLIT;
              end
           end else begin
              nxt_state_in = IN_FLIT;
           end
        end // case: IN_FLIT
        default: begin
           in_data = 16'hx;
        end
      endcase
   end   

   // Combinational part of output state machine
//   always @(*) begin
//      // default values
//      out_valid = 1'b0; // no flit
//      nxt_size_out = size_out;  // keep size
//      out_ack = 1'b0;   // don't acknowledge
//      out_type = 2'bxx; // Default is undefined
//      
//      
//      case(state_out)
//        OUT_IDLE: begin
//           // Transition from IDLE to FIRST
//           // when write on bus, which is the size
//           if (bus_we && bus_en) begin
//              // Store the written value as size
//              nxt_size_out = bus_data_in[size_width-1:0];
//              // Acknowledge to the bus
//              out_ack = 1'b1;
//              nxt_state_out = OUT_FIRST;
//           end else begin
//              nxt_state_out = OUT_IDLE;
//           end
//        end
//        OUT_FIRST: begin
//           // The first flit is written from the bus now.
//           // This can be either the only flit (size==1)
//           // or a further flits will follow.
//           // Forward the flits to the packet buffer.
//           if (bus_we && bus_en) begin
//              // When the bus writes, the data is statically assigned
//              // to out_flit. Set out_valid to signal the flit should
//              // be output
//              out_valid = 1'b1;
//              
//              // The type is either SINGLE (size==1) or HEADER
//              if (size_out==1) begin
//                 out_type = 2'b11;
//              end else begin
//                 out_type = 2'b01;
//              end
//
//              if (out_ready) begin
//                 // When the output packet buffer is ready this cycle
//                 // the flit has been stored in the packet buffer
//
//                 // Decrement size
//                 nxt_size_out = size_out-1;
//                 
//                 // Acknowledge to the bus
//                 out_ack = 1'b1;
//
//                 if (size_out==1) begin
//                    // When this was the only flit, go to IDLE again
//                    nxt_state_out = OUT_IDLE;
//                 end else begin
//                    // Otherwise accept further flis as payload
//                    nxt_state_out = OUT_PAYLOAD;
//                 end
//              end else begin // if (out_ready)
//                 // If the packet buffer is not ready, we simply hold
//                 // the data and valid and wait another cycle for the
//                 // packet buffer to become ready
//                 nxt_state_out = OUT_FIRST;
//              end
//           end else begin // if (bus_we && bus_en)
//              // Wait for the bus
//              nxt_state_out = OUT_FIRST;
//           end
//        end
//        OUT_PAYLOAD: begin
//           // After the first flit (HEADER) further flits are
//           // forwarded in this state. The essential difference to the
//           // FIRST state is in the output type which can here be
//           // PAYLOAD or LAST
//           if (bus_we && bus_en) begin
//              // When the bus writes, the data is statically assigned
//              // to out_flit. Set out_valid to signal the flit should
//              // be output
//              out_valid = 1'b1;
//
//              // The type is either LAST (size==1) or PAYLOAD
//              if (size_out==1) begin
//                 out_type = 2'b10;
//              end else begin
//                 out_type = 2'b00;
//              end
//
//              if (out_ready) begin
//                 // When the output packet buffer is ready this cycle
//                 // the flit has been stored in the packet buffer
//
//                 // Decrement size
//                 nxt_size_out = size_out-1;
//                 
//                 // Acknowledge to the bus
//                 out_ack = 1'b1;
//
//                 if (size_out==1) begin
//                    // When this was the last flit, go to IDLE again
//                    nxt_state_out = OUT_IDLE;
//                 end else begin
//                    // Otherwise accept further flis as payload
//                    nxt_state_out = OUT_PAYLOAD;
//                 end
//              end else begin // if (out_ready)
//                 // If the packet buffer is not ready, we simply hold
//                 // the data and valid and wait another cycle for the
//                 // packet buffer to become ready                
//                 nxt_state_out = OUT_PAYLOAD;
//              end
//           end else begin // if (bus_we && bus_en)
//              // Wait for the bus
//              nxt_state_out = OUT_PAYLOAD;
//           end
//        end
//        default: begin
//           // Defaulting to go to idle
//           nxt_state_out = OUT_IDLE;
//        end
//      endcase
//   end

   // Sequential part of both state machines
   always @(posedge clk) begin
      if (rst) begin
//         state_out <= OUT_IDLE; // Start in idle state
         // size does not require a reset value (not used before set)
         state_in <= IN_IDLE;
      end else begin
         // Register combinational values
//         state_out <= nxt_state_out;
//         size_out <= nxt_size_out;
         state_in <= nxt_state_in;
      end
   end

   /**
    * Read from the following addresses gives status and parameters
    *  0x10: Output packet buffer empty
    *  0x14: Output state
    */   

   localparam READ_OUT_EMPTY  = 3'h4;
   localparam READ_OUT_STATE  = 3'h5;
   localparam READ_IN_WAITING = 3'h6;
   
   always @(*) begin
      status_ack = 1'b1;
      case(bus_addr[5:2])
//        READ_OUT_EMPTY: begin
//           // When we are not in the middle of a message and there is
//           // no packet pending (noc_out_valid is then statically
//           // high), the buffer is empty
//           status_data = {15'h0,((state_out==OUT_IDLE) & !noc_out_valid)};
//        end
//        READ_OUT_STATE: begin
//           // assign state
//           status_data = state_out;
//        end
        READ_IN_WAITING: begin
           //
           status_data = in_valid;
        end
        default: begin
           status_data = 32'hx;
        end
      endcase
   end

   // The output packet buffer
//   lisnoc_packet_buffer
//     #(.fifo_depth(fifo_depth),.data_width(noc_data_width))
//   u_packetbuffer_out(// Outputs
//                      .in_ready         (out_ready),
//                      .out_flit         (noc_out_flit[noc_flit_width-1:0]),
//                      .out_valid        (noc_out_valid),
//                      .out_size         (),
//                      // Inputs
//                      .clk              (clk),
//                      .rst              (rst),
//                      .in_flit          (out_flit[noc_flit_width-1:0]),
//                      .in_valid         (out_valid),
//                      .out_ready        (noc_out_ready));
   

   lisnoc_packet_buffer
     #(.fifo_depth(fifo_depth),.data_width(noc_data_width))
   u_packetbuffer_in(// Outputs
                     .in_ready          (noc_in_ready),
                     .out_flit          (in_flit[noc_flit_width-1:0]),
                     .out_valid         (in_valid),
                     .out_size          (size_in),
                     // Inputs
                     .clk               (clk),
                     .rst               (rst),
                     .in_flit           (noc_in_flit[noc_flit_width-1:0]),
                     .in_valid          (noc_in_valid),
                     .out_ready         (in_ready));

   function integer clog2;
      input integer value;
      begin
         value = value-1;
         for (clog2=0; value>0; clog2=clog2+1)
           value = value>>1;
      end
   endfunction

endmodule // lisnoc_mp_simple

// Local Variables:
// verilog-library-directories:("../infrastructure")
// verilog-auto-inst-param-value: t
// End:
