`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.01.2024 19:50:40
// Design Name: 
// Module Name: video_module
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


module video_module (
input							clk_vga,
input 						reset_n,

output reg 		[10:0] 	y_count_frame,
output reg 		[10:0] 	x_count_frame,
output reg 					video_enable_output,
input 			[23:0]	color_input,
output reg      [18:0]  address_framebuffer,
output reg					hold_frame,

output reg		[7:0]		frame_number,

output reg 		[23:0]  	video_rgb,
output reg           	video_de,
output reg           	video_skip,
output reg           	video_vs,
output reg           	video_hs

);

// Video Cache address


reg 			vga_line;


reg [10:0]	vga_hi_size;		// horazontal image size	
reg [10:0]	vga_vi_size;		// Verital image size	
reg [10:0]	vga_hs_start;		// horazontal Image location		
reg [10:0]	vga_vs_start;		// Verital Image location
reg [10:0]	vga_hs_length;		// horazontal total Image size
reg [10:0]	vga_vs_length;		// Verital total Image size
reg [10:0]	vga_hs_location;	// horazontal hs signal	
reg [10:0]	vga_vs_location;	// Verital vs signal	

reg [10:0]	hs_count;
reg [10:0] 	vs_count;

// The Pocket we will do a frame of 720*720 but full video image of 1024*740 at 60fps @ 40mhz
// But render at 30 frames

always @(posedge clk_vga or negedge reset_n) begin
	if (~reset_n) begin
		vga_line						<= 0;
		hs_count						<= 0;
		vs_count						<= 0;
		y_count_frame				<= 0;
		x_count_frame				<= 0;
		vga_hi_size					<= 720;		
		vga_vi_size					<= 720;
		video_enable_output		<= 0;
		vga_hs_start				<= 20;		
		vga_vs_start				<= 4;		
		vga_hs_length				<= 1025;		
		vga_vs_length				<= 812;		
		vga_hs_location			<= 5;		
		vga_vs_location			<= 1;	
		video_rgb					<= 0;
		video_de						<= 0;
		video_skip					<= 0;
		video_vs						<= 0;
		video_hs						<= 0;
		frame_number				<= 0;
		hold_frame					<= 1;
		address_framebuffer        <= 0;
	end
	else begin
		video_rgb					<= 0;
		video_de						<= 0;
		video_skip					<= 0;
		video_vs						<= 0;
		video_hs						<= 0;
		x_count_frame				<= 0;
		hs_count						<= hs_count + 1;
		
		if (vs_count >= 1 && vs_count < 812) video_enable_output		<= 1;
		else video_enable_output		<= 0;
		// x counter on frame
		
		if (hs_count == (vga_hs_length)) begin
			hs_count 			<= 0;
			vs_count 			<= vs_count + 1;
		end
		
		// video HS signal and cache address line
		if (hs_count == vga_hs_location) begin
			video_hs <= 1;
		end
		
		// video VS signal
		if ((vs_count == vga_vs_location) && hs_count == 0) begin
			video_vs 				<= 1;
			address_framebuffer      <= 0;
			video_rgb				<= {23'b0, hold_frame};
			frame_number				<= frame_number + 1;
		    hold_frame					<= ~hold_frame;
		end
		
		if ((vs_count >= vga_vs_length) && hs_count == 0) begin
			vs_count 			<= 0;
		end
		
		
		if (vs_count >= (vga_vs_start) && 
			 vs_count <= ((vga_vs_start) + vga_vi_size)) begin
			 if (hs_count == 0) begin
				y_count_frame <= y_count_frame + 1;
			 end
		end
		else begin
			y_count_frame <= 0;
		end
	    
		// video DE signal and video output
		if (vs_count >= vga_vs_start && 
			 vs_count < (vga_vs_start + vga_vi_size) &&
			 hs_count >= vga_hs_start - 2 && 
			 hs_count < (vga_hs_start - 2 + vga_hi_size)) begin
				address_framebuffer             <= address_framebuffer + 1;
				
		end
		if (vs_count >= vga_vs_start && 
			 vs_count < (vga_vs_start + vga_vi_size) &&
			 hs_count >= vga_hs_start && 
			 hs_count < (vga_hs_start + vga_hi_size)) begin
				video_de 						<= 1'b1; // we are only working on the odd frames for 30FPS
				video_rgb[23:16]				<= {color_input[23:16]};
				video_rgb[15: 8]				<= {color_input[15: 8]};
				video_rgb[ 7: 0]				<= {color_input[ 7: 0]};
				
		end
		if (video_de) x_count_frame				<= x_count_frame + 1;
	
	end
end


endmodule