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
	output reg [7:0] 	red_out,                         
	output reg [7:0] 	green_out,
	output reg [7:0] 	blue_out,             
	
	input  [9:0] 		pixel_x_i,              // X pixel coordinate 
	input  [9:0] 		pixel_y_i,                  
	input  [2:0]        pixel_c_i,         
	input  		        pixel_write,
	
	input [2:0] 		trail_len,
	input 				blur_on,
	
	input 				clk_74a,
	input	[31:0]		bridge_addr,
	input					bridge_wr,
	input	[31:0]		bridge_wr_data
	
	
);
             
	
	wire use_debugs = 1'b0;						// 0 = do not use corner/line debugs, 1 = use them
	
	// X width = 768, Y height = 720
	// X and Y coords are flipped relative to modern displays, so X and Y are flipped going into the multiplies.
	// X is also inverted.	
	wire [9:0] xcoord = xprod[15:6];			// multiply X coord by 0.75
	wire [9:0] ycoord = yprod[15:6];			// multiply Y coord by 0.703125
	
	// X scaling
	wire [9:0] xmula = pixel_y;
	wire [5:0] xmulb = 6'd45;	
	wire [15:0] xprod = xmula * xmulb;
	
	// Y scaling
	wire [9:0] ymula = ~pixel_x;
	wire [5:0] ymulb = 6'd45;
	wire [15:0] yprod = ymula * ymulb;
	
	reg [1:0] pa_del;								// detect pixel_available edges
	reg [2:0] frame_odd_d;						// synchronize and detect every other frame
	reg [1:0] cpu_stall_d;						// detect rising edge of cpu stall signal
	
	
	reg [9:0] pixel_x;							// pixel X coord to write to FIFO
	reg [9:0] pixel_y;							// pixel Y coord to write to FIFO
	reg write_fifo;								// high to write word to FIFO
	reg [3:0] stuffstate;						// debug pixel stuffer state
	reg [3:0] ss_wait;							// wait for same
	reg [9:0] pixtest;							// we increment this so we have a pixel that moves once every frame for debug
	
	reg [7:0] needlecnt;							// needle ship count
	reg [7:0] wedgecnt;							// wedge ship count
	
	reg [39:0] w_coord;							// wedge's coords (scaled and unscaled)
	reg [39:0] n_coord;
	reg [2:0]  pixel_c;
	
	// CPU clock domain
	always @ (posedge clk_sys)
	begin
	
        pixel_x <= pixel_x_i;
        pixel_y <= pixel_y_i;
        pixel_c <= pixel_c_i;
        write_fifo <= pixel_write;
	end	
		
	
	wire [9:0] curr_x;		// current X coord from the FIFO
	wire [9:0] curr_y;		// current Y coord from the FIFO
	wire [2:0] curr_color;	// current object type. we will unscale the ships
	
	reg rdreq;
	wire rdempty;
	wire wr_full;
	
	
	
	fifo_video thingera (
									.wrclk	(clk_sys),
									.data		({pixel_c, pixel_x, pixel_y}),
									.wrreq	(write_fifo & ~wr_full),	// prevent the FIFO overflowing (this should never happen (tm))
									.wrfull  (wr_full),
									
									.rdclk	(clk),
									.rdreq	(rdreq),
									.rdempty	(rdempty),
									.q			({curr_color, curr_y, curr_x})
							  );


	
	
	
	localparam numbuffs = 8'd8;			// number of buffers
	reg [3:0] ob_buf;							// we need to set this to the number of bits for buffer count
	reg [3:0] ob_count;						// and this too
	reg [3:0] bufcount;						// buffer counter
	wire bufbit = vertical_counter[4];	// bit we use to swap buffers
	localparam dimline = 12'd737;			// do the dimming on one of the non-visble lines
	localparam startline = 12'd12;		// the line DE starts on, because we need to preroll for the first line buffer to fill
	localparam cv_lowbit = 'd4;			// lowest bit to check on the vertical counter
	
	// trail length
	reg [9:0] phos_dim;
	always
	case(trail_len[2:0])
	3'h0 : phos_dim <= 10'h3fe;
	3'h1 : phos_dim <= 10'd64;
	3'h2 : phos_dim <= 10'd32;
	3'h3 : phos_dim <= 10'd16;
	3'h4 : phos_dim <= 10'd8;
	3'h5 : phos_dim <= 10'd4;
	3'h6 : phos_dim <= 10'd2;
	3'h7 : phos_dim <= 10'd1;
	endcase
		
	localparam phos_full = 10'h3ff;							// maximum brightness
	
	wire [34:0] pa_out [numbuffs-1:0];	// bram port A out
	wire [34:0] pb_out [numbuffs-1:0];	// bram port B out (not used)
	reg [9:0] ramcnta;						// bram port A address 
	reg [9:0] ramcntb;						// bram port B address
	reg pb_wren [numbuffs-1:0];			// bram port B write
	reg [34:0] pb_in [numbuffs-1:0];		// bram port B in
		
	// buffer bits:
	// 34:32 - color of the pixel 
	// 31 - pixel is unrendered.  we clear this when it is sent to a line buffer
	// 30 - pixel used.  when we use a pixel, this is set (since there's no other way to tell from the coords)
	// 29 - pixel visible. set = pixel will be sent to line buffers. clear = pixel is not scanned out
	// 28:20 - pixel brightness.  Technically bit 29 is part of this too, and we decrement it to dim it out
	// 19:10 - Y coordinate
	// 9:0 - X coordinate
	
	genvar i;
	generate
		for (i = 0; i < numbuffs; i=i+1)
		begin : ramgen
			rendram rr_gen (
			.clock(clk),
			.data_a(35'h0000_0000), .address_a(ramcnta), .wren_a(1'b0), .q_a(pa_out[i]),
			.data_b(pb_in[i]), .address_b(ramcntb), .wren_b(pb_wren[i]), .q_b(pb_out[i])
			);
		end
	endgenerate
	
	
	reg [numbuffs-1:0] foundit;			// set = we found the pixel in this particular buffer
	reg [9:0] minbrite [numbuffs-1:0];	// dimmest pixel in each buffer
	reg [9:0] mb_add [numbuffs-1:0];		// address of dimmest pixel
	reg [3:0] state;							// state
	reg [7:0] j;
	reg [9:0] oldestbrite;					// dimmest pixel on all buffers
	reg [9:0] ob_add;							// address of same
	reg [9:0] ramcnta_d;						// delayed version of port A address (so the address matches the output data)
	reg pipehold;								// hold off pipeline evaluation for the first cycle
	
	reg fifovalid;								// we have valid pixels in the FIFO
	reg [9:0] fifo_x;							// X coord of eval pixel
	reg [9:0] fifo_y;							// Y coord of eval pixel
	reg [2:0] fifo_c;							// Y coord of eval pixel

	reg whichbuf;								// which of the two buffers we are working on
	reg [7:0] pixout;							// pixel to write to
	reg [9:0] out_x;							// its X coord
	reg [9:0] out_y;							// its Y coord
	reg [2:0] out_c;							// its Y coord
	reg pixwrite, pixwrite_d;				// toggle for pixel writing into line buffers

	
	
	// counter pipeline:
	//
	// ramcnta	ramcnta_d	pipehold
	// 0			x				1
	// 1			0				0
	// 2			1				0
	// 3			2				0
	// 4			3				0
	// ...
	// 3fe		3fd			0
	// 3ff		3fe			0
	// 0			3ff			0
	
	
	always @ (posedge clk)
	begin
	
		
		
		if (~|vertical_counter)										// we will do 1 complete search on every scanline, even if there's no pixels left.
		begin
			state <= 4'h1;
			bufcount <= 0;												// which buffer we will scan into our line buffers
		end
		else
		case (state)
		// run this every scanline until we run out of lines
		4'h1 :	begin
						
						if (horizontal_counter == 1)
						begin
							
							whichbuf <= bufbit;												// select which buffer we will render, and which we will fill
							ramcnta <= 0;
							
							fifovalid <= ~rdempty & cpu_stall_d[1];					// if we have a valid entry or not, and we will only do reads every other frame so our scale values can populate
							{fifo_c, fifo_y, fifo_x} <= {curr_color, curr_y, curr_x};		// everything else
							rdreq <= ~rdempty & cpu_stall_d[1];							// next entry if there is one (and we finished rendering)
							
							for (j = 0; j < numbuffs; j = j + 1)
							begin
								foundit[j] <= 1'b0;											// reset the found flag
								minbrite[j] <= 10'h3ff;										// set min brightness to max brightness
							end
							
							pipehold <= 1'b1;
							state <= 4'h2;
						 
						 end
						 
					end
		
		// pixel update state; we can through all pixels in all buffers looking for the correct one, if present
		// also the pixel scanout is done here too.  and the dimming is done on one of the vblank lines.
		4'h2 :	begin
						rdreq <= 1'b0;

						ramcnta_d <= ramcnta;	// the ram counter is delayed 1 clock because of the bram.  so we will add a delay here, too
						ramcntb <= ramcnta_d;	// ram write port's address

						if (~pipehold)
						for (j = 0; j < numbuffs; j = j + 1)
						begin
							casex({
										(vertical_counter == dimline), (fifovalid & ({ fifo_y, fifo_x} == pa_out[j][19:0])),
										((vertical_counter[10:cv_lowbit] == pa_out[bufcount][19:10+cv_lowbit]) & (j == bufcount)), pa_out[j][31:29]
									})
							
							// pixel is being replaced. mark it as unrendered and used
							6'b01x_x1x :	begin
													pb_in[j] <= {fifo_c, 2'b11, phos_full, fifo_y, fifo_x};
													pb_wren[j] <= 1'b1;
													foundit[j] <= 1'b1;
												end
											
							// we scanned out the pixel which we previously marked as "unrendered" so mark it as rendered
							6'b001_1xx :	begin
													pb_in[j] <= {fifo_c, 1'b0, pa_out[j][30:0]};
													pb_wren[j] <= 1'b1;
												end
												
							// do phosphor dim, but only if we are marked "rendered" and we have not hit 0
							// also, the first step is always 1 so that we will see the blue for 2 full frames, to prevent it flickering if it is being redrawn
							6'b1xx_0x1 :	begin
													pb_in[j][34:32] <= {pa_out[j][34:32]};
													pb_in[j][31:30] <= {1'b0, pa_out[j][30]};
													pb_in[j][19:0] <= pa_out[j][19:0];
													casex({&pa_out[j][29:20], 1'b0, pa_out[j][29:20]} - {1'b0, phos_dim})
													12'b1xxx_xxxx_xxxx : pb_in[j][29:20] <= 10'h3fe;								// subtract 1 on the first go
													12'b00xx_xxxx_xxxx : pb_in[j][29:20] <= (pa_out[j][29:20] - phos_dim);	// no underflow
													12'b01xx_xxxx_xxxx : pb_in[j][29:20] <= 10'h0;									// underflow
													endcase
													pb_wren[j] <= 1'b1;
												end
							
							// dimmed to minimum value so peg it at 0
							6'b1xx_0x0 :	begin
													pb_in[j] <= {35'h0};		// reset the coord too so we can see it on the tapper
													pb_wren[j] <= 1'b1;
												end
							
							// we wrote this but haven't rendered it yet, so mark it rendered
							6'b1xx_1xx :	begin
													pb_in[j] <= {pa_out[j][34:32], 1'b0, pa_out[j][30:0]};
													pb_wren[j] <= 1'b1;
												end
							
							// not writing for whatever reason, so clear the bit
							default :	begin
												pb_wren[j] <= 1'b0;
											end
							endcase
							
							// search for the dimmest pixel in all of our buffers and save it and its address
							if ((pa_out[j][29:20] < minbrite[j]) & ~pipehold)
							begin
								minbrite[j] <= pa_out[j][29:20];
								mb_add[j] <= ramcnta_d;
							end
						
						end

						// we have to not do any processing on the FIRST clock of this state
						pipehold <= 1'b0;
						
						// this pixel will be sent to the line buffers for scanout
						{out_c, pixout, out_y, out_x} <= {pa_out[bufcount][34:32], pa_out[bufcount][28:21], pa_out[bufcount][19:0]};
						
						// we will only write it to the buffers if it is in range for the buffer
						if ((vertical_counter[10:cv_lowbit] == pa_out[bufcount][19:10+cv_lowbit]) & pa_out[bufcount][29]) pixwrite <= ~pixwrite;

						// do all pixels
						ramcnta <= ramcnta + 1'b1;
						if (~|ramcnta & ~pipehold) state <= 4'h3;
					
					end
		
		// stop writing, and some some other minor cleanup things
		4'h3 :	begin
						
						for (j = 0; j < numbuffs; j = j + 1)
						begin
							
							pb_wren[j] <= 1'b0;			// stop writing if need be
						
						end
						
						casex({(vertical_counter == dimline), |foundit | ~fifovalid})
						2'b1x : state <= 4'h0;			// this is the last processed line, so we're done. go to idle						
						2'b01 : state <= 4'h1;			// we found the pixel so we are done for this line
						2'b00 : state <= 4'h4;
						endcase
						
						oldestbrite <= 10'h3ff;			// get ready for the next step
						ob_count <= 0;
						
						bufcount <= bufcount + 1'b1;	// step to the next buffer
						
					end
		
		
		// find the dimmest pixel across all buffers
		4'h4 :	begin
						if (minbrite[ob_count] < oldestbrite)
						begin
							oldestbrite <= minbrite[ob_count];
							ob_add <= mb_add[ob_count];
							ob_buf <= ob_count;
						end
						ob_count <= ob_count + 1'b1;
						if (&ob_count) state <= 4'h5;						
					end
		
		// you are the dimmest pixel. goodbye!
		4'h5 :	begin
						pb_in[ob_buf] <= {fifo_c, 2'b11, phos_full, fifo_y, fifo_x};	// mark it as unrendered and used
						ramcntb <= ob_add;
						pb_wren[ob_buf] <= 1'b1;
						state <= 4'h6;
					end

		// stop writing and finish up
		4'h6 :	begin
						pb_wren[ob_buf] <= 1'b0;
						state <= 4'h1;
					end
		
		
		endcase

		
		
		pixwrite_d <= pixwrite;
		
		if (~whichbuf)
		begin
			// writing pixels into buffer A on even sets
			buf_a_wr <= (pixwrite ^ pixwrite_d);
			buf_a_dat <= {out_c, pixout};
			buf_a_add <= {out_y[cv_lowbit-1:0], out_x};
			// reading out pixels from buffer B on even sets
			buf_b_add <= {vertical_counter[cv_lowbit-1:0], (horizontal_counter[9:0] - 10'd8)};
			buf_out <= buf_b_out;
		end
		else
		begin
			// writing pixels into buffer B on odd sets
			buf_b_wr <= (pixwrite ^ pixwrite_d);
			buf_b_dat <= {out_c, pixout};
			buf_b_add <= {out_y[cv_lowbit-1:0], out_x};
			// reading out pixels from buffer A on odd sets
			buf_a_add <= {vertical_counter[cv_lowbit-1:0], (horizontal_counter[9:0] - 10'd8)};
			buf_out <= buf_a_out;
		end
		
		// buffer clearing address and enable
		buf_c_add <= {vertical_counter[cv_lowbit-1:0], (horizontal_counter[9:0] - 10'd16)};
		buf_c_wr <= (horizontal_counter >= 11'd16);
		
	
	end
	
	
	// line buffers
	
	reg [10:0] buf_out;
	reg [13:0] buf_c_add;
	reg buf_c_wr;
	
	reg [10:0] buf_a_dat;
	reg [13:0] buf_a_add;
	reg buf_a_wr;
	wire [10:0] buf_a_out;
	wire [10:0] buf_a_outb;
	
		
	linebuf thingerb (	.clock(clk),
								.data_a(buf_a_dat), .address_a(buf_a_add), .wren_a(buf_a_wr), .q_a(buf_a_out),
								.data_b(8'h0), .address_b(buf_c_add), .wren_b(buf_c_wr & whichbuf), .q_b(buf_a_outb)
							);
							
	reg [7:0] buf_b_dat;
	reg [13:0] buf_b_add;
	reg buf_b_wr;
	wire [7:0] buf_b_out;
	wire [7:0] buf_b_outb;
	
		
	linebuf thingerc (	.clock(clk),
								.data_a(buf_b_dat), .address_a(buf_b_add), .wren_a(buf_b_wr), .q_a(buf_b_out),
								.data_b(8'h0), .address_b(buf_c_add), .wren_b(buf_c_wr & ~whichbuf), .q_b(buf_b_outb)
							);
							
							
	
	// colour LUT
	
	wire [23:0] output_color;
	
	// we write to this on address range #1000_0000 to #1000_ffff Tho this is a 8bit addressable LUT we have to treat every
	// entry as a 32bit word
	wire write_clut_en = bridge_wr && (bridge_addr[31:16] == 16'h1000); 

	color_lut thingerd_red (
		.write_clk		(clk_74a),
		.write_address	(bridge_addr[9:2]),
		.write_data		(bridge_wr_data),
		.write_enable	(write_clut_en),
		.read_clk		(clk),
		.input_index	(buf_out),
		.output_color	(output_color[23:16])
	);
		
	color_lut thingerd_green (
		.write_clk		(clk_74a),
		.write_address	(bridge_addr[9:2]),
		.write_data		(bridge_wr_data),
		.write_enable	(write_clut_en),
		.read_clk		(clk),
		.input_index	(buf_out),
		.output_color	(output_color[15:8])
	);

	color_lut thingerd_blue (
		.write_clk		(clk_74a),
		.write_address	(bridge_addr[9:2]),
		.write_data		(bridge_wr_data),
		.write_enable	(write_clut_en),
		.read_clk		(clk),
		.input_index	(buf_out),
		.output_color	(output_color[7:0])
	);	

							
	// final blur operation.  we will do a 3*3 blur.
	// the edges of this are dirty, but since we're cropping them off, it doesn't matter.
	// this blur feature isn't being used right now, we need to improve it if there's time.
	
	reg [23:0] linebufa [1023:0];
	reg [23:0] linebufb [1023:0];
	reg [23:0] linebufc [1023:0];
	
	reg [23:0] pix [8:0];
	
	wire [9:0] writeline = (horizontal_counter[9:0] - 10'd3);

	reg [11:0] gauss_ra, gauss_rb, gauss_rc, gauss_r;
	reg [11:0] gauss_ga, gauss_gb, gauss_gc, gauss_g;
	reg [11:0] gauss_ba, gauss_bb, gauss_bc, gauss_b;
	
	
	
	always @ (posedge clk)
	begin	
	
		// generate a 3*3 pixel block:
		// 012
		// 345
		// 678
		
		
		pix[2] <= pix[1];
		pix[1] <= pix[0];
		pix[0] <= linebufa[horizontal_counter[9:0]];
		
		pix[5] <= pix[4];
		pix[4] <= pix[3];
		pix[3] <= linebufb[horizontal_counter[9:0]];
		
		pix[8] <= pix[7];
		pix[7] <= pix[6];
		pix[6] <= linebufc[horizontal_counter[9:0]];
							
		if (~horizontal_counter[10])
		begin
			
			linebufa[writeline] <= ((output_color[23] | ~blur_on) ? output_color : {1'b0, output_color[23:17], 1'b0, output_color[15:9], 1'b0, output_color[7:1]});
			linebufb[writeline] <= pix[2];
			linebufc[writeline] <= pix[5];
			
		end

		gauss_ra <= {4'h0, pix[0][7:0]      } + {3'h0, pix[1][7:0], 1'b0} + {4'h0, pix[2][7:0]      };
		gauss_rb <= {3'h0, pix[3][7:0], 1'b0} + {2'h0, pix[4][7:0], 2'b0} + {3'h0, pix[5][7:0], 1'b0};
		gauss_rc <= {4'h0, pix[6][7:0]      } + {3'h0, pix[7][7:0], 1'b0} + {4'h0, pix[8][7:0]      };
		
		gauss_r <= gauss_ra + gauss_rb + gauss_rc;
		

		gauss_ga <= {4'h0, pix[0][15:8]      } + {3'h0, pix[1][15:8], 1'b0} + {4'h0, pix[2][15:8]      };
		gauss_gb <= {3'h0, pix[3][15:8], 1'b0} + {2'h0, pix[4][15:8], 2'b0} + {3'h0, pix[5][15:8], 1'b0};
		gauss_gc <= {4'h0, pix[6][15:8]      } + {3'h0, pix[7][15:8], 1'b0} + {4'h0, pix[8][15:8]      };
		
		gauss_g <= gauss_ga + gauss_gb + gauss_gc;


		gauss_ba <= {4'h0, pix[0][23:16]      } + {3'h0, pix[1][23:16], 1'b0} + {4'h0, pix[2][23:16]      };
		gauss_bb <= {3'h0, pix[3][23:16], 1'b0} + {2'h0, pix[4][23:16], 2'b0} + {3'h0, pix[5][23:16], 1'b0};
		gauss_bc <= {4'h0, pix[6][23:16]      } + {3'h0, pix[7][23:16], 1'b0} + {4'h0, pix[8][23:16]      };
		
		gauss_b <= gauss_ba + gauss_bb + gauss_bc;
		
		
		// final RGB
		case(blur_on)
		1'b0 : {blue_out, green_out, red_out} <= pix[4];
		1'b1 : {blue_out, green_out, red_out} <= {(gauss_b[11] ? 8'hff : gauss_b[10:3]), (gauss_g[11] ? 8'hff : gauss_g[10:3]), (gauss_r[11] ? 8'hff : gauss_r[10:3])};
		endcase

		
	end


							
endmodule

module rendram (
	address_a,
	address_b,
	clock,
	data_a,
	data_b,
	wren_a,
	wren_b,
	q_a,
	q_b);

	input	[9:0]  address_a;
	input	[9:0]  address_b;
	input	  clock;
	input	[34:0]  data_a;
	input	[34:0]  data_b;
	input	  wren_a;
	input	  wren_b;
	output	reg [34:0]  q_a;
	output	reg [34:0]  q_b;

reg [34:0] mem [1023:0];

always @(posedge clock) begin
    if (wren_a) mem[address_a] <= data_a;
    if (wren_b) mem[address_b] <= data_b;
    q_a <= mem[address_a];
    q_b <= mem[address_b];
end

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
	output	reg [10:0]  q_a;
	output	reg [10:0]  q_b;

reg [10:0] mem [16383:0];

always @(posedge clock) begin
    if (wren_a) mem[address_a] <= data_a;
    if (wren_b) mem[address_b] <= data_b;
    q_a <= mem[address_a];
    q_b <= mem[address_b];
end

endmodule

module color_lut (
	input                  write_clk,
	input [7:0]            write_address,
	input [31:0]           write_data,
	input                  write_enable,
	input                  read_clk,
	input [7:0]            input_index,
	output reg [7:0]       output_color
	);



reg [7:0] mem [255:0];

always @(posedge write_clk) begin
    if (write_enable) mem[write_address] <= write_data;
end

always @(posedge read_clk) begin
    output_color <= mem[input_index];
end

endmodule

module fifo_video (
	data,
	rdclk,
	rdreq,
	wrclk,
	wrreq,
	q,
	rdempty,
	rdfull,
	rdusedw,
	wrfull);

	input	[22:0]  data;
	input	  rdclk;
	input	  rdreq;
	input	  wrclk;
	input	  wrreq;
	output	[22:0]  q;
	output	  rdempty;
	output	  rdfull;
	output	[8:0]  rdusedw;
	output	  wrfull;

//   FIFO_DUALCLOCK_MACRO  #(
//      .ALMOST_EMPTY_OFFSET(9'h080), // Sets the almost empty threshold
//      .ALMOST_FULL_OFFSET(9'h080),  // Sets almost full threshold
//      .DATA_WIDTH(23),   // Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
//      .DEVICE("7SERIES"),  // Target device: "7SERIES" 
//      .FIFO_SIZE ("18Kb"), // Target BRAM: "18Kb" or "36Kb" 
//      .FIRST_WORD_FALL_THROUGH ("TRUE") // Sets the FIFO FWFT to "TRUE" or "FALSE" 
//   ) Write_fifo_mask_00 (
////      .ALMOSTEMPTY(ALMOSTEMPTY), // 1-bit output almost empty
////      .ALMOSTFULL(ALMOSTFULL),   // 1-bit output almost full
//      .DO(q),                   // Output data, width defined by DATA_WIDTH parameter
//      .EMPTY(rdempty),             // 1-bit output empty
//      .FULL(rdfull),               // 1-bit output full
//      .RDCOUNT(rdusedw),         // Output read count, width determined by FIFO depth
////      .RDERR(RDERR),             // 1-bit output read error
////      .WRCOUNT(WRCOUNT),         // Output write count, width determined by FIFO depth
////      .WRERR(WRERR),             // 1-bit output write error
//      .DI(data),                   // Input data, width defined by DATA_WIDTH parameter
//      .RDCLK(rdclk),             // 1-bit input read clock
//      .RDEN(rdreq),               // 1-bit input read enable
//      .RST(~reset_l),                 // 1-bit input reset
//      .WRCLK(wrclk),             // 1-bit input write clock
//      .WREN(wrreq)                // 1-bit input write enable
//   );
   
   assign wrfull = rdfull;

endmodule

							
