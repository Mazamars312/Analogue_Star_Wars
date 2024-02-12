
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.10.2023 22:12:05
// Design Name: 
// Module Name: video_core_pdp
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module video_core_pdp(

	input 				clk,                    // 42.4Mz (all video processing)
	input 				clk_sys,						// 50Mhz (CPU clock)
	input [10:0] 		horizontal_counter,              
	input [10:0] 		vertical_counter,  
	input [18:0]  address_framebuffer,
	input               video_vs, 
	input 				enable_video_out,
	input 				hold_frame,
	output				pixel_wr_full,
	output reg [7:0] 	red_out,                         
	output reg [7:0] 	green_out,
	output reg [7:0] 	blue_out,             
	input 				reset_l,
	input  [9:0] 		pixel_x_i,              // X pixel coordinate 
	input  [9:0] 		pixel_y_i,                  
	input  [2:0]        pixel_c_i,         
	input  		        pixel_write,
	
	input [2:0] 		trail_len,
	input 				blur_on
	
	
);
             
    integer t;
    
	
	reg [9:0] pixel_x = 0;							// pixel X coord to write to FIFO
	reg [9:0] pixel_y = 0;							// pixel Y coord to write to FIFO
	reg [9:0] pixel_x_d1 = 0;							// pixel X coord to write to FIFO
	reg [9:0] pixel_y_d1 = 0;							// pixel Y coord to write to FIFO
	// X scaling
	wire [9:0] xmula = pixel_y;
	wire [5:0] xmulb = 6'd45;	
	wire [15:0] xprod = xmula * xmulb;	
    // Y scaling
	wire [9:0] ymula = ~pixel_x;
	wire [5:0] ymulb = 6'd45;
	wire [15:0] yprod = ymula * ymulb;
	// X width = 800, Y height = 720
	// X and Y coords are flipped relative to modern displays, so X and Y are flipped going into the multiplies.
	// X is also inverted.	
	wire [9:0] xcoord = xprod[15:6];			// multiply X coord by 0.75
	wire [9:0] ycoord = yprod[15:6];			// multiply Y coord by 0.703125
		

	reg [2:0]  pixel_c = 0;
	reg [2:0]  pixel_c_d1 = 0;
	reg [2:0]  pixel_c_d2 = 0;
	
	reg [18:0] write_address;
	reg			write_fifo_d1, write_fifo_d2;
	reg write_fifo;
	// CPU clock domain
	always @ (posedge clk_sys)
	begin
        pixel_x <= pixel_x_i;
        pixel_y <= pixel_y_i;
        pixel_c <= pixel_c_i;
        write_fifo <= pixel_write;
        pixel_x_d1 <= xcoord;
        pixel_y_d1 <= ycoord;
        pixel_c_d1 <= pixel_c;
		  pixel_c_d2 <= pixel_c_d1;
        write_fifo_d1 <= write_fifo;
        write_fifo_d2 <= write_fifo_d1;
		  write_address <= pixel_x + (pixel_y * 720);
	end	
		
	
	wire [9:0] curr_x;		// current X coord from the FIFO
	wire [9:0] curr_y;		// current Y coord from the FIFO
	wire [2:0] curr_color;	// current object type. we will unscale the ships
	
	reg rdreq = 0;
	wire rdempty;
	wire wr_full;
	wire [4:0] pa_out;
	
	
rendram #(.size(19)) 
rr_gen (
.clock_a(clk),
.clock_b(clk_sys),
.data_a(32'h0000_0000), .address_a(address_framebuffer), .wren_a(1'b0), .q_a(pa_out),
.data_b(pixel_c_d2), .address_b(write_address), .wren_b(write_fifo_d2), .q_b()
);

	
	
	always @ (posedge clk)
	begin	
	
		// generate a 3*3 pixel block:
		// 012
		// 345
		// 678
		
		
//		pix[2] <= pix[1];
//		pix[1] <= pix[0];
//		pix[0] <= linebufa[horizontal_counter[9:0]];
//		
//		pix[5] <= pix[4];
//		pix[4] <= pix[3];
//		pix[3] <= linebufb[horizontal_counter[9:0]];
//		
//		pix[8] <= pix[7];
//		pix[7] <= pix[6];
//		pix[6] <= linebufc[horizontal_counter[9:0]];
//							
//		if (~horizontal_counter[10])
//		begin
//			
//			linebufa[writeline] <= ((~blur_on || output_color[7]) ? output_color : output_color[7:1]);
//			linebufb[writeline] <= pix[2];
//			linebufc[writeline] <= pix[5];
//			
//		end
//
//		gauss_ra <= {4'h0, pix[0][7:0]      } + {3'h0, pix[1][7:0], 1'b0} + {4'h0, pix[2][7:0]      };
//		gauss_rb <= {3'h0, pix[3][7:0], 1'b0} + {2'h0, pix[4][7:0], 2'b0} + {3'h0, pix[5][7:0], 1'b0};
//		gauss_rc <= {4'h0, pix[6][7:0]      } + {3'h0, pix[7][7:0], 1'b0} + {4'h0, pix[8][7:0]      };
//		
//		gauss_r <= gauss_ra + gauss_rb + gauss_rc;
		
	
		
		// final RGB
//		case(blur_on)
//		1'b0 : 
		{blue_out, green_out, red_out} <= {pa_out[2] ? 8'hff : 8'd0, 
		                                   pa_out[1] ? 8'hff : 8'd0, 
		                                   pa_out[0] ? 8'hff : 8'd0};
//		1'b1 : 
//		{blue_out, green_out, red_out} <= {pix[4][10] ? gauss_r[11] ? 8'hff : gauss_r[10:3] : 8'd0 , 
//		                                   pix[4][9]  ? gauss_r[11] ? 8'hff : gauss_r[10:3] : 8'd0 ,
//		                                   pix[4][8]  ? gauss_r[11] ? 8'hff : gauss_r[10:3] : 8'd0 };
//		endcase

		
	end

//    initial begin
//        for(t = 0; t <  numbuffs; t = t + 1) begin
//            pa_in   <= 0;
//            pb_in   <= 0;
//            pa_wren  <= 0;
//            pb_wren  <= 0;
//            foundit  <= 0;
//            minbrite <= 0;
//            mb_add   <= 0;
//        end
//    end
							
endmodule

module rendram #(parameter size = 10)(
	address_a,
	address_b,
	clock_a,
	clock_b,
	data_a,
	data_b,
	wren_a,
	wren_b,
	q_a,
	q_b);

	input	[size-1:0]  address_a;
	input	[size-1:0]  address_b;
	input	  clock_a;
	input	  clock_b;
	input	[4:0]  data_a;
	input	[4:0]  data_b;
	input	  wren_a;
	input	  wren_b;
	output [4:0]  q_a;
	output [4:0]  q_b;

//reg [31:0] mem [2**size -1 :0];
//integer i;
//    initial begin
//        for(i = 0; i <  2**size; i = i + 1) begin
//            mem[i] = 'h0;
//        end
//    end
//always @(posedge clock) begin
//    if (wren_b) mem[address_b[size-1 :0]] <= data_b;
//    q_b <= mem[address_b[size-1 :0]];
//end
//
//always @(posedge clock) begin
//    if (wren_a) mem[address_a[size-1 :0]] <= data_a;
//    q_a <= mem[address_a[size-1 :0]];
//end

altsyncram	altsyncram_component (
				.address_a (address_a[size-1 :0]),
				.address_b (address_b[size-1 :0]),
				.clock0 (clock_a),
				.clock1 (clock_b),
				.data_a (data_a),
				.data_b (data_b),
				.wren_a (wren_a),
				.wren_b (wren_b),
				.q_a (q_a),
				.q_b (q_b),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_a (8'hff),
				.byteena_b (8'hff),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.eccstatus (),
				.rden_a (1'b1),
				.rden_b (1'b1));
	defparam
				altsyncram_component.address_reg_b = "CLOCK1",
		altsyncram_component.byte_size = 8,
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_a = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.indata_reg_b = "CLOCK1",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 2**size,
		altsyncram_component.numwords_b = 2**size,
		altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
		altsyncram_component.outdata_aclr_a = "NONE",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_a = "UNREGISTERED",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.widthad_a = size,
		altsyncram_component.widthad_b = size,
		altsyncram_component.width_a = 3,
		altsyncram_component.width_b = 3,
		altsyncram_component.width_byteena_a = 2,
		altsyncram_component.width_byteena_b = 1,
		altsyncram_component.wrcontrol_wraddress_reg_b = "CLOCK1";

endmodule

module linebuf (
	address_a,
	address_b,
	clock,
	data_a,
	data_b,
	wren_a,
	wren_b,
	q_a,
	q_b);

	input	[13:0]  address_a;
	input	[13:0]  address_b;
	input	  clock;
	input	[10:0]  data_a;
	input	[10:0]  data_b;
	input	  wren_a;
	input	  wren_b;
	output	[10:0]  q_a;
	output	[10:0]  q_b;

//reg [10:0] mem [16383:0];

//integer i;
//    initial begin
//        for(i = 0; i <  16384; i = i + 1) begin
//            mem[i] = 'h0;
//        end
//    end

//always @(posedge clock) begin
//    if (wren_a) mem[address_a] <= data_a;
//    q_a <= mem[address_a];
//end
//
//always @(posedge clock) begin
//    if (wren_b) mem[address_b] <= data_b;
//    q_b <= mem[address_b];
//end

altsyncram	altsyncram_component (
				.address_a (address_a),
				.address_b (address_b),
				.clock0 (clock),
				.clock1 (clock),
				.data_a (data_a),
				.data_b (data_b),
				.wren_a (wren_a),
				.wren_b (wren_b),
				.q_a (q_a),
				.q_b (q_b),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_a (8'hff),
				.byteena_b (8'hff),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.eccstatus (),
				.rden_a (1'b1),
				.rden_b (1'b1));
	defparam
				altsyncram_component.address_reg_b = "CLOCK1",
		altsyncram_component.byte_size = 8,
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_a = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.indata_reg_b = "CLOCK1",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 16384,
		altsyncram_component.numwords_b = 16384,
		altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
		altsyncram_component.outdata_aclr_a = "NONE",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_a = "UNREGISTERED",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.widthad_a = 14,
		altsyncram_component.widthad_b = 14,
		altsyncram_component.width_a = 16,
		altsyncram_component.width_b = 16,
		altsyncram_component.width_byteena_a = 2,
		altsyncram_component.width_byteena_b = 1,
		altsyncram_component.wrcontrol_wraddress_reg_b = "CLOCK1";


endmodule




//module fifo_video (
//	reset_l,
//	data,
//	rdclk,
//	rdreq,
//	wrclk,
//	wrreq,
//	q,
//	rdempty,
//	rdfull,
//	rdusedw,
//	wrfull);
//	input 			reset_l;
//	input	[22:0]  data;
//	input	  rdclk;
//	input	  rdreq;
//	input	  wrclk;
//	input	  wrreq;
//	output	[22:0]  q;
//	output	  rdempty;
//	output	  rdfull;
//	output	[8:0]  rdusedw;
//	output	  wrfull;
//
//
//	dcfifo  dcfifo_component (
//		.aclr (~reset_l),
//		.data (data),
//		.rdclk (rdclk),
//		.rdreq (rdreq),
//		.wrclk (wrclk),
//		.wrreq (wrreq),
//		.q (q),
//		.rdempty (rdempty),
//		.rdfull (rdfull),
//		.rdusedw (rdusedw),
//		.eccstatus (),
//		.wrempty (),
//		.wrfull (wrfull),
//		.wrusedw ());
//defparam
//dcfifo_component.enable_ecc  = "FALSE",
//dcfifo_component.lpm_hint  = "DISABLE_DCFIFO_EMBEDDED_TIMING_CONSTRAINT=TRUE",
//dcfifo_component.lpm_numwords  = 256,
//dcfifo_component.lpm_showahead  = "ON",
//dcfifo_component.lpm_type  = "dcfifo",
//dcfifo_component.lpm_width  = 23,
//dcfifo_component.lpm_widthu  = 8,
//dcfifo_component.overflow_checking  = "ON",
//dcfifo_component.rdsync_delaypipe  = 3,
//dcfifo_component.read_aclr_synch  = "OFF",
//dcfifo_component.underflow_checking  = "ON",
//dcfifo_component.use_eab  = "ON",
//dcfifo_component.write_aclr_synch  = "OFF",
//dcfifo_component.wrsync_delaypipe  = 3;
////assign rdempty = wrfull;
////   FIFO_DUALCLOCK_MACRO  #(
////      .ALMOST_EMPTY_OFFSET(9'h080), // Sets the almost empty threshold
////      .ALMOST_FULL_OFFSET(9'h080),  // Sets almost full threshold
////      .DATA_WIDTH(23),   // Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
////      .DEVICE("7SERIES"),  // Target device: "7SERIES" 
////      .FIFO_SIZE ("18Kb"), // Target BRAM: "18Kb" or "36Kb" 
////      .FIRST_WORD_FALL_THROUGH ("TRUE") // Sets the FIFO FWFT to "TRUE" or "FALSE" 
////   ) Write_fifo_mask_00 (
//////      .ALMOSTEMPTY(ALMOSTEMPTY), // 1-bit output almost empty
//////      .ALMOSTFULL(ALMOSTFULL),   // 1-bit output almost full
////      .DO(q),                   // Output data, width defined by DATA_WIDTH parameter
////      .EMPTY(rdempty),             // 1-bit output empty
////      .FULL(wrfull),               // 1-bit output full
////      .RDCOUNT(rdusedw),         // Output read count, width determined by FIFO depth
//////      .RDERR(RDERR),             // 1-bit output read error
//////      .WRCOUNT(WRCOUNT),         // Output write count, width determined by FIFO depth
//////      .WRERR(WRERR),             // 1-bit output write error
////      .DI(data),                   // Input data, width defined by DATA_WIDTH parameter
////      .RDCLK(rdclk),             // 1-bit input read clock
////      .RDEN(rdreq),               // 1-bit input read enable
////      .RST(~reset_l),                 // 1-bit input reset
////      .WRCLK(wrclk),             // 1-bit input write clock
////      .WREN(wrreq)                // 1-bit input write enable
////   );
//   
//
//endmodule

							

