`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.01.2024 20:29:32
// Design Name: 
// Module Name: VIdeo_core_fb_sdram
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


////////////////////////////////////////////////////////////////////////////////////////



// video generation
// ~12,288,000 hz pixel clock
//
// we want our video mode of 320x240 @ 60hz, this results in 204800 clocks per frame
// we need to add hblank and vblank times to this, so there will be a nondisplay area. 
// it can be thought of as a border around the visible area.
// to make numbers simple, we can have 400 total clocks per line, and 320 visible.
// dividing 204800 by 400 results in 512 total lines per frame, and 288 visible.
// this pixel clock is fairly high for the relatively low resolution, but that's fine.
// PLL output has a minimum output frequency anyway.
module video_sdram_core (
	input               	reset_n,
	input 					clk_ram_controller,
	input               	video_rgb_clock,
	output [23:0]       	video_rgb,
	output              	video_de,
	output              	video_skip,
	output              	video_vs,
	output              	video_hs,
	 
	output  [12:0]  		dram_a,
	output  [1:0]   		dram_ba,
	inout   [15:0]  		dram_dq,
	output  [1:0]   		dram_dqm,
	output          		dram_clk,
	output          		dram_cke,
	output          		dram_ras_n,
	output          		dram_cas_n,
	output          		dram_we_n,
    
	output reg          	interrupt,

	input               	clk_74a,
	input [31:0]        	bridge_addr,
	input               	bridge_rd,
	input               	bridge_wr,
	input [3:0]         	bridge_mask,
	input [31:0]        	bridge_wr_data,
	output reg [31:0]   	bridge_rd_data,
	output reg          	bridge_valid,
	output reg 				vram_cmd_ready
);

    reg [25:0]  ram1_word_addr;
    reg         ram1_word_wr;
    reg         ram1_word_rd;
    reg [3:0]   ram1_word_mask;
    reg [31:0]  ram1_word_data;
    wire [31:0] ram1_word_q;
    wire        ram1_word_busy;
    
    reg [7:0]   frame_count;
    reg [15:0]  VID_V_BPORCH        = 'd10;
    reg [15:0]  VID_V_ACTIVE        = 'd720;
    reg [15:0]  VID_V_TOTAL         = 'd1024;
    reg [15:0]  VID_H_BPORCH        = 'd10;
    reg [15:0]  VID_H_ACTIVE        = 'd720;
    reg [15:0]  VID_H_TOTAL         = 'd813;
    reg [15:0]  VID_V_BPORCH_REG    = 'd10;
    reg [15:0]  VID_V_ACTIVE_REG    = 'd720;
    reg [15:0]  VID_V_TOTAL_REG     = 'd1024;
    reg [15:0]  VID_H_BPORCH_REG    = 'd10;
    reg [15:0]  VID_H_ACTIVE_REG    = 'd720;
    reg [15:0]  VID_H_TOTAL_REG     = 'd813;
    reg [31:0]  VID_BASE_ADD        = 'd0;
    reg [31:0]  VID_BASE_ADD_REG    = 'd0;
    
    reg [9:0]   x_count;
    reg [9:0]   y_count;
    
    wire signed [9:0]  visible_x = x_count - VID_H_BPORCH;
    wire signed [9:0]  visible_y = y_count - VID_V_BPORCH;

    reg [23:0]  vidout_rgb;
    reg         vidout_de, vidout_de_1;
    reg         vidout_skip;
    reg         vidout_vs;
    reg         vidout_hs, vidout_hs_1;
    
    
    reg             screen_border = 1; // driven by BRIDGE clk_74a 
    wire            screen_border_s;
synch_3 s1(screen_border, screen_border_s, video_rgb_clock);

wire bridge_busy_wire;
synch_3 bridge_busy_signal(ram1_word_busy, bridge_busy_wire, clk_74a);

    reg             next_line;
    wire            next_line_s;
synch_3 s3(next_line, next_line_s, clk_ram_controller);

    reg             new_frame;
    wire            new_frame_s;
synch_3 s4(new_frame, new_frame_s, clk_ram_controller);

    reg             linebuf_toggle;
    wire            linebuf_toggle_s;
synch_3 s9(linebuf_toggle, linebuf_toggle_s, clk_ram_controller);

always @(posedge video_rgb_clock or negedge reset_n) begin

    if(~reset_n) begin
        x_count <= 0;
        y_count <= 0;
		  safe_change <= 1;
        
    end else begin
        vidout_de <= 0;
        vidout_skip <= 0;
        vidout_vs <= 0;
        vidout_hs <= 0;
        safe_change <= 0;
        vidout_hs_1 <= vidout_hs;
        vidout_de_1 <= vidout_de;
		  
        if(y_count == 0) begin
		  safe_change <= 1;
        end
        // signals for the ram interface
        new_frame <= 0;
        next_line <= 0;
        
        // x and y counters
        x_count <= x_count + 1'b1;
        if(x_count == VID_H_TOTAL-1) begin
            x_count <= 0;
            
            y_count <= y_count + 1'b1;
            if(y_count == VID_V_TOTAL-1) begin
                y_count <= 0;
            end
        end
        
        // generate sync 
        if(x_count == 0 && y_count == 0) begin
            // sync signal in back porch
            // new frame
            vidout_vs <= 1;
            new_frame <= 1;
            
            frame_count <= frame_count + 1'b1;
        end
        
        // we want HS to occur a bit after VS, not on the same cycle
        if(x_count == 3) begin
            // sync signal in back porch
            // new line
            vidout_hs <= 1;
            
            // trigger the next_line signal 1 line ahead of the first visible line, to account for buffering
            if(y_count >= VID_V_BPORCH-1 && y_count < VID_V_ACTIVE+VID_V_BPORCH) begin
                next_line <= 1;
                linebuf_toggle <= linebuf_toggle ^ 1;
            end
        end
            
        // generate scanline buffer addressing
        // because our scanline BRAM is registered, it has an additional cycle of latency, 
        // so we must start incrementing its address a cycle early
        if(x_count >= VID_H_BPORCH-1) begin
            linebuf_rdaddr <= linebuf_rdaddr + 1'b1;
        end else begin
            linebuf_rdaddr <= 0;
        end
        
        // inactive screen areas are black
        vidout_rgb <= 24'h0;
        // generate active video
        if(x_count >= VID_H_BPORCH && x_count < VID_H_ACTIVE+VID_H_BPORCH) begin

            if(y_count >= VID_V_BPORCH && y_count < VID_V_ACTIVE+VID_V_BPORCH) begin
                // data enable. this is the active region of the line
                vidout_de <= 1;
                
                // convert RGB565 to RGB888
                vidout_rgb[23:16] <= {linebuf_q[14:10], linebuf_q[14:12]};
                vidout_rgb[15:8]  <= {linebuf_q[9:5], linebuf_q[9:7]};
                vidout_rgb[7:0]   <= {linebuf_q[4:0], linebuf_q[4:2]};
            

            end 
        end
        
        
    end
end





    reg             display_enable = 1;
    reg             display_enable_REG = 1;
    reg             display_enable_gated = 1;
    wire            display_enable_s;
synch_3 s5(display_enable_gated, display_enable_s, clk_ram_controller);


    reg     [3:0]   rr_state;
    localparam      RR_STATE_0 = 'd0;
    localparam      RR_STATE_1 = 'd1;
    localparam      RR_STATE_2 = 'd2;
    localparam      RR_STATE_3 = 'd3;
    localparam      RR_STATE_4 = 'd4;
    localparam      RR_STATE_5 = 'd5;
    localparam      RR_STATE_6 = 'd6;
    localparam      RR_STATE_7 = 'd7;
    localparam      RR_STATE_8 = 'd8;
    localparam      RR_STATE_9 = 'd9;
    localparam      RR_STATE_10 = 'd10;
    
    reg     [10:0]  rr_line;
    
// fsm to handle reading ram 
//
// reset linecount on vsync, and fetch line buffers on hsync, in a pingpong buffer

reg safe_change;
always @(posedge clk_ram_controller) begin
    ram1_burst_rd <= 0;
    linebuf_wren <= 0;
    
    case(rr_state)
    RR_STATE_0: begin
        
        rr_state <= RR_STATE_1;
    end
    RR_STATE_1: begin
        
        if(new_frame_s) begin
            rr_line <= 'd0;
        end
        
        if(next_line_s && display_enable_s) begin
            // increment the line we will fetch next cycle
            rr_line <= rr_line + 1'b1;
            
            ram1_burst_rd <= 1'b1;
            // when displaying a contiguous buffer, we must determine the scanline
            // address with a multiplier. a better way is to fix the scanlines onto a 1024-word alignment
            // and correct the addressing as data is copied in.
            ram1_burst_addr <= VID_BASE_ADD + rr_line * VID_H_ACTIVE; 
            ram1_burst_len <= 1024;
            ram1_burst_32bit <= 0;
            
            linebuf_wraddr <= -1;
            
            rr_state <= RR_STATE_2;
        end
    end
    RR_STATE_2: begin
        if(ram1_burst_data_valid) begin
            // ram data is valid, write into the line buffer
            linebuf_data <= ram1_burst_data;
            linebuf_wraddr <= linebuf_wraddr + 1'b1;
            linebuf_wren <= 1;
        
        end
        if(ram1_burst_data_done) begin
            rr_state <= RR_STATE_1;
        end
    
    end
    endcase

end




initial begin
    display_enable <= 1;
end

reg [3:0] state;
reg bridge_busy_reg;
    
always @(posedge clk_74a) begin
    ram1_word_rd <= 0;
    ram1_word_wr <= 0;
    // wait til we are out of reset to start scanning out the display and hitting ram
    display_enable_gated <= reset_n;
    if (safe_change) begin
        display_enable  <= display_enable_REG;
        VID_V_BPORCH    <= VID_V_BPORCH_REG;    
        VID_V_ACTIVE    <= VID_V_ACTIVE_REG;
        VID_V_TOTAL     <= VID_V_TOTAL_REG;
        VID_H_BPORCH    <= VID_H_BPORCH_REG;
        VID_H_ACTIVE    <= VID_H_ACTIVE_REG;
        VID_H_TOTAL     <= VID_H_TOTAL_REG;
        VID_BASE_ADD    <= VID_BASE_ADD_REG;
    end
    // handle memory mapped I/O from pocket
    //
	 bridge_busy_reg <= bridge_busy_wire;
	 case (state)
	 4'd0 : begin
		 bridge_valid  <= 0;
		 vram_cmd_ready <= 1;
		 if(bridge_wr) begin
			  casex(bridge_addr[31:24])
			  8'h00,
			  8'h01,
			  8'h02,
			  8'h03: begin
					// 64mbyte sdram mapped at 0x0
			  
					// the ram controller's word port is 32bit aligned
					ram1_word_wr <= 1;
					ram1_word_addr <= bridge_addr[25:2];
					ram1_word_data <= bridge_wr_data;
					ram1_word_mask <= bridge_mask;
					bridge_valid  <= 0;
					state <= 1;
					vram_cmd_ready <= 0;
			  end
			  8'h04: begin
					bridge_valid  <= 1;
					case (bridge_addr[7:0])
						 8'h00 : display_enable_REG  <= bridge_wr_data;
						 8'h04 : VID_V_BPORCH_REG    <= bridge_wr_data;
						 8'h08 : VID_V_ACTIVE_REG    <= bridge_wr_data;
						 8'h0c : VID_V_TOTAL_REG     <= bridge_wr_data;
						 8'h10 : VID_H_BPORCH_REG    <= bridge_wr_data;
						 8'h14 : VID_H_ACTIVE_REG    <= bridge_wr_data;
						 8'h18 : VID_H_TOTAL_REG     <= bridge_wr_data;
						 8'h1c : VID_BASE_ADD_REG    <= bridge_wr_data;
					endcase
			  end
			  
			  endcase
		 end
		 if(bridge_rd) begin
			  casez(bridge_addr[31:24])
			  8'h00,
			  8'h01,
			  8'h02,
			  8'h03: begin
					// start new read
					ram1_word_rd <= 1;                  
					// convert from byte address to word address
					ram1_word_addr <= bridge_addr[25:2]; 
					// output the last value read. the requested value will be returned in time for the next read
					bridge_rd_data <= ram1_word_q; 
					vram_cmd_ready <= 0;
					state <= 1;
			  end
			  8'h04: begin
					bridge_valid  <= 1;
					case (bridge_addr[7:0])
						 8'h00 : bridge_rd_data <= display_enable_REG;
						 8'h04 : bridge_rd_data <= VID_V_BPORCH_REG;
						 8'h08 : bridge_rd_data <= VID_V_ACTIVE_REG;
						 8'h0c : bridge_rd_data <= VID_V_TOTAL_REG;
						 8'h10 : bridge_rd_data <= VID_H_BPORCH_REG;
						 8'h14 : bridge_rd_data <= VID_H_ACTIVE_REG;
						 8'h18 : bridge_rd_data <= VID_H_TOTAL_REG;
						 8'h1c : bridge_rd_data <= VID_BASE_ADD_REG;
						 8'h20 : bridge_rd_data <= frame_count;
					endcase
			  end
			  endcase
			  
		 end
	 end
	 4'd1 : begin
		if (~bridge_busy_wire && bridge_busy_reg) begin
			state <= 0;
			vram_cmd_ready <= 1;
			bridge_valid  <= 1;
		end
	 end
	
    endcase
end




///////////////////////////////////////////////
// clk_12288 drives the pingpong toggle for the line buffer.
// however, we need to use this toggle in the other clock domain, clk_ram_controller.
// so it's necessary to use a synchronizer to bring this into the other clock domain.


    reg     [9:0]   linebuf_rdaddr;
    wire    [10:0]  linebuf_rdaddr_fix = (linebuf_toggle ? linebuf_rdaddr : (linebuf_rdaddr + 'd1024));
    wire    [15:0]  linebuf_q;
    
    reg     [9:0]   linebuf_wraddr;
    wire    [10:0]  linebuf_wraddr_fix = (linebuf_toggle_s ? (linebuf_wraddr + 'd1024) : linebuf_wraddr);
    reg     [15:0]  linebuf_data;
    reg             linebuf_wren;

bram_block_dp #( 
   .DATA(16),
   .ADDR(10)
)  mf_linebuf_inst ( 
    .a_clk       ( video_rgb_clock ),
    .a_addr      ( linebuf_rdaddr_fix ),
    .a_dout      ( linebuf_q ),
    
    .b_clk     ( clk_ram_controller ),
    .b_addr      ( linebuf_wraddr_fix ),
    .b_din       ( linebuf_data ),
    .b_wr        ( linebuf_wren )
);


    reg             ram1_burst_rd; // must be synchronous to clk_ram
    reg     [24:0]  ram1_burst_addr;
    reg     [10:0]  ram1_burst_len;
    reg             ram1_burst_32bit;
    wire    [31:0]  ram1_burst_data;
    wire            ram1_burst_data_valid;
    wire            ram1_burst_data_done;
    
    wire            ram1_burstwr;
    wire    [24:0]  ram1_burstwr_addr;
    wire            ram1_burstwr_ready;
    wire            ram1_burstwr_strobe;
    wire    [15:0]  ram1_burstwr_data;
    wire            ram1_burstwr_done;
    


    io_main_sdram io_main_sdram (
        .controller_clk ( clk_ram_controller ),
        .chip_clk       ( clk_ram_controller ),
        .clk_90         ( clk_ram_controller ),
        .reset_n        ( 1'b1 ), // fsm has its own boot reset
        
        .phy_cke        ( dram_cke ),
        .phy_clk        ( dram_clk ),
        .phy_cas        ( dram_cas_n ),
        .phy_ras        ( dram_ras_n ),
        .phy_we         ( dram_we_n ),
        .phy_ba         ( dram_ba ),
        .phy_a          ( dram_a ),
        .phy_dq         ( dram_dq ),
        .phy_dqm        ( dram_dqm ),
        
        .burst_rd           ( ram1_burst_rd ),
        .burst_addr         ( ram1_burst_addr ),
        .burst_len          ( ram1_burst_len ),
        .burst_32bit        ( ram1_burst_32bit ),
        .burst_data         ( ram1_burst_data ),
        .burst_data_valid   ( ram1_burst_data_valid ),
        .burst_data_done    ( ram1_burst_data_done ),
    
        .burstwr        ( ram1_burstwr ),
        .burstwr_addr   ( ram1_burstwr_addr ),
        .burstwr_ready  ( ram1_burstwr_ready ),
        .burstwr_strobe ( ram1_burstwr_strobe ),
        .burstwr_data   ( ram1_burstwr_data ),
        .burstwr_done   ( ram1_burstwr_done ),
        
        .word_rd    ( ram1_word_rd ),
        .word_wr    ( ram1_word_wr ),
        .word_addr  ( ram1_word_addr ),
        .word_data  ( ram1_word_data ),
        .word_mask  ( ram1_word_mask ),
        .word_q     ( ram1_word_q ),
        .word_busy  ( ram1_word_busy )
            
    );
    
assign video_rgb = vidout_rgb;
assign video_de = vidout_de;
assign video_skip = vidout_skip;
assign video_vs = vidout_vs;
assign video_hs = vidout_hs;
endmodule

//
// io_sdram
//
// 2019-2022 Analogue
//

module io_main_sdram (

input   wire            controller_clk,
input   wire            chip_clk,
input   wire            clk_90,
input   wire            reset_n,

output  reg             phy_cke,
output  wire            phy_clk,
output  wire            phy_cas,
output  wire            phy_ras,
output  wire            phy_we,
output  reg     [1:0]   phy_ba,
output  reg     [12:0]  phy_a,
inout   wire    [15:0]  phy_dq,
output  reg     [1:0]   phy_dqm,

input   wire            burst_rd, // must be synchronous to clk_ram
input   wire    [24:0]  burst_addr,
input   wire    [10:0]  burst_len,
input   wire            burst_32bit,
output  reg     [31:0]  burst_data,
output  reg             burst_data_valid,
output  reg             burst_data_done,

input   wire            burstwr,
input   wire    [24:0]  burstwr_addr,
output  reg             burstwr_ready,
input   wire            burstwr_strobe,
input   wire    [15:0]  burstwr_data,
input   wire            burstwr_done,

input   wire            word_rd, // can be from other clock domain. we synchronize these
input   wire            word_wr,
input   wire    [23:0]  word_addr,
input   wire    [3:0]   word_mask,
input   wire    [31:0]  word_data,
output  reg     [31:0]  word_q,
output  reg             word_busy
);

    // tristate for DQ
    reg             phy_dq_oe;      
    assign          phy_dq = phy_dq_oe ? phy_dq_out : 16'bZZZZZZZZZZZZZZZZ;
    reg     [15:0]  phy_dq_out;

    reg     [2:0]   cmd;
assign {phy_ras, phy_cas, phy_we} = cmd;

    localparam      CMD_NOP             = 3'b111;
    localparam      CMD_ACT             = 3'b011;
    localparam      CMD_READ            = 3'b101;
    localparam      CMD_WRITE           = 3'b100;
    localparam      CMD_PRECHG          = 3'b010;
    localparam      CMD_AUTOREF         = 3'b001;
    localparam      CMD_LMR             = 3'b000;
    localparam      CMD_SELFENTER       = 3'b001;
    localparam      CMD_SELFEXIT        = 3'b111;

    localparam      CAS                 =   4'd3;   // timings are for 166mhz
    localparam      TIMING_LMR          =   4'd2;   // tLMR = 2ck
    localparam      TIMING_AUTOREFRESH  =   4'd12;  // tRFC = 80
    localparam      TIMING_PRECHARGE    =   4'd3;   // tRP = 18
    localparam      TIMING_ACT_ACT      =   4'd9;   // tRC = 60
    localparam      TIMING_ACT_RW       =   4'd3;   // tRCD = 18
    localparam      TIMING_ACT_PRECHG   =   4'd7;   // tRAS = 42
    localparam      TIMING_WRITE        =   4'd3;   // tWR = 2ck

    reg     [5:0]   state;
    
    localparam      ST_RESET            = 'd0;
    localparam      ST_BOOT_0           = 'd1;
    localparam      ST_BOOT_1           = 'd2;
    localparam      ST_BOOT_2           = 'd3;
    localparam      ST_BOOT_3           = 'd4;
    localparam      ST_BOOT_4           = 'd5;
    localparam      ST_BOOT_5           = 'd6;
    localparam      ST_IDLE             = 'd7;
    
    localparam      ST_WRITE_0          = 'd20;
    localparam      ST_WRITE_1          = 'd21;
    localparam      ST_WRITE_2          = 'd22;
    localparam      ST_WRITE_3          = 'd23;
    localparam      ST_WRITE_4          = 'd24;
    localparam      ST_WRITE_5          = 'd25;
    localparam      ST_WRITE_6          = 'd26;
    
    localparam      ST_READ_0           = 'd30;
    localparam      ST_READ_1           = 'd31;
    localparam      ST_READ_2           = 'd32;
    localparam      ST_READ_3           = 'd33;
    localparam      ST_READ_4           = 'd34;
    localparam      ST_READ_5           = 'd35;
    localparam      ST_READ_6           = 'd36;
    localparam      ST_READ_7           = 'd37;
    localparam      ST_READ_8           = 'd38;
    localparam      ST_READ_9           = 'd39;
    
    localparam      ST_BURSTWR_0        = 'd46;
    localparam      ST_BURSTWR_1        = 'd47;
    localparam      ST_BURSTWR_2        = 'd48;
    localparam      ST_BURSTWR_3        = 'd49;
    localparam      ST_BURSTWR_4        = 'd50;
    localparam      ST_BURSTWR_5        = 'd51;
    localparam      ST_BURSTWR_6        = 'd52;
    localparam      ST_BURSTWR_7        = 'd53;
    
    localparam      ST_REFRESH_0        = 'd60;
    localparam      ST_REFRESH_1        = 'd61;
    
    
    reg     [23:0]  delay_boot;
    reg     [15:0]  dc;
    reg     [9:0]   refresh_count;
    reg             issue_autorefresh;
    
    wire reset_n_s;
synch_3 s1(reset_n, reset_n_s, controller_clk); 

    reg word_rd_queue;
    reg word_wr_queue;
    wire word_rd_s, word_rd_r;
    wire word_wr_s, word_wr_r;
synch_3 s2(word_rd, word_rd_s, controller_clk, word_rd_r);  
synch_3 s3(word_wr, word_wr_s, controller_clk, word_wr_r);  

    wire    [23:0]  word_addr_s;
synch_3 #(.WIDTH(24)) s4(word_addr, word_addr_s, controller_clk);


    wire    [3:0]  word_mask_s;
synch_3 #(.WIDTH(4)) s5(word_mask, word_mask_s, controller_clk);
    wire    [31:0]  word_data_s;
synch_3 #(.WIDTH(32)) s6(word_data, word_data_s, controller_clk);
    
    reg burst_rd_queue;
    reg burstwr_queue;
    
    reg             word_op;
    reg             bram_op;
    reg     [24:0]  addr;
    wire    [9:0]   addr_col9_next_1 = addr[9:0] + 'h1;
    
    reg     [10:0]  length;
    wire    [10:0]  length_next = length - 'h1;
    reg             enable_dq_read, enable_dq_read_1, enable_dq_read_2, enable_dq_read_3, enable_dq_read_4, enable_dq_read_5;
    reg             enable_dq_read_toggle;
    
    reg             enable_data_done, enable_data_done_1, enable_data_done_2, enable_data_done_3, enable_data_done_4;

    reg             read_newrow;
    reg             burstwr_newrow;
    
    
    reg     [15:0]  phy_dq_latched;
always @(posedge controller_clk) begin
    phy_dq_latched <= phy_dq;
end

    
always @(*) begin
    burst_data_done <= enable_data_done_4;
end
initial begin
    state <= ST_RESET;
    phy_cke <= 0;
end
always @(posedge controller_clk) begin
    phy_dq_oe <= 0;
    cmd <= CMD_NOP;
    dc <= dc + 1'b1;
    
    burst_data_valid <= 0;
    burstwr_ready <= 0;
    
    enable_dq_read_5 <= enable_dq_read_4;
    enable_dq_read_4 <= enable_dq_read_3;
    enable_dq_read_3 <= enable_dq_read_2;
    enable_dq_read_2 <= enable_dq_read_1;
    enable_dq_read_1 <= enable_dq_read;
    enable_dq_read <= 0;
    
    enable_data_done_4 <= enable_data_done_3;
    enable_data_done_3 <= enable_data_done_2;
    enable_data_done_2 <= enable_data_done_1;
    enable_data_done_1 <= enable_data_done;
    enable_data_done <= 0;
    
    // delayed by CAS latency for reads
    // this is triggered by the read FSM but delayed by 3 clocks
    // this makes the FSM simple and everybody happy
    if(enable_dq_read_4) begin
        enable_dq_read_toggle <= ~enable_dq_read_toggle;
        
        if(word_op) begin
            if(~enable_dq_read_toggle) begin
                // even cycles 
                word_q[31:16] <= phy_dq;
            end else begin
                // odd cycles
                word_q[15:0] <= phy_dq;
                //word_q_valid <= 1;
            end
        
        end else begin
            if(burst_32bit) begin
                // accumulate high/low word
                if(~enable_dq_read_toggle) begin
                    // even cycles 
                    burst_data[31:16] <= phy_dq;
                end else begin
                    // odd cycles
                    burst_data[15:0] <= phy_dq;
                    burst_data_valid <= 1;
                end
            end else begin
                // 16-bit
                burst_data[15:0] <= phy_dq;
                burst_data_valid <= 1;
            end
        end
    end
    
    
    case(state)
    ST_RESET: begin
        phy_cke <= 0;
        cmd <= CMD_NOP;
        delay_boot <= 0;
        issue_autorefresh <= 0;
        phy_dqm <= 2'b00;
        
        state <= ST_BOOT_0;
    end
    ST_BOOT_0: begin
        delay_boot <= delay_boot + 1'b1;

        if(delay_boot == 30000-16) phy_cke <= 1;
        if(delay_boot == 30000) begin
            // 200uS @ 166mhz
            dc <= 0;
            
            // precharge all
            cmd <= CMD_PRECHG;
            phy_a[10] = 1'b1;
    
            state <= ST_BOOT_1;
        end
    end
    ST_BOOT_1: begin
        if(dc == TIMING_PRECHARGE-1) begin
            dc <= 0;
            cmd <= CMD_AUTOREF;
            
            state <= ST_BOOT_2;
        end
    end
    ST_BOOT_2: begin
        if(dc == TIMING_AUTOREFRESH-1) begin
            dc <= 0;
            cmd <= CMD_AUTOREF;
    
            state <= ST_BOOT_3;
        end
    end
    ST_BOOT_3: begin
        if(dc == TIMING_AUTOREFRESH-1) begin
            dc <= 0;
            cmd <= CMD_LMR;
            phy_ba <= 'b00;
            phy_a <= 13'b000000_011_0_000; // CAS 3, burst length 1, sequential
    
            state <= ST_BOOT_4;
        end
    end
    ST_BOOT_4: begin
        if(dc == TIMING_LMR-1) begin
            dc <= 0;
            cmd <= CMD_LMR;
            phy_ba <= 'b10; // Extended mode register
            phy_a <= 13'b00000_010_00_000; // Self refresh coverage: All banks, 
            // drive strength = 3'b010 (alliance, 50%) 
            state <= ST_BOOT_5;
        end
    end
    ST_BOOT_5: begin
        if(dc == TIMING_LMR-1) begin
            phy_dqm <= 2'b00;
            word_busy <= 0; 
            state <= ST_IDLE;
        end
    end

    
    ST_IDLE: begin
    
        read_newrow <= 0;
        if (~|{word_rd_queue, word_wr_queue}) word_busy <= 0;
        word_op <= 0;
        
        if(issue_autorefresh) begin
            state <= ST_REFRESH_0;
        end else 
        if(burst_rd_queue) begin
            burst_rd_queue <= 0;
            addr <= burst_addr;
            length <= burst_len;
            state <= ST_READ_0;
        end else
        if(burstwr_queue) begin
            burstwr_queue <= 0;
            addr <= burstwr_addr;
            state <= ST_BURSTWR_0;
        end else
        if(word_rd_queue) begin
            word_rd_queue <= 0;
            word_op <= 1;
            addr <= word_addr << 1;
            length <= 2;
            state <= ST_READ_0;
        end else 
        if(word_wr_queue) begin
            word_wr_queue <= 0;
            word_op <= 1;
            addr <= word_addr << 1;
            state <= ST_WRITE_0;
        end 
        
    
    end
    
    
    
    ST_WRITE_0: begin
        dc <= 0;
        
        phy_ba <= addr[24:23];
        phy_a <= addr[22:10]; // A0-A12 column address
        cmd <= CMD_ACT;
        
        state <= ST_WRITE_1;
    end
    ST_WRITE_1: begin
        phy_a[10] <= 1'b0; // no auto precharge
        if(dc == TIMING_ACT_RW-1) begin
            dc <= 0;
            phy_dq_oe <= 1;
            state <= ST_WRITE_2;
        end 
    end
    ST_WRITE_2: begin
        dc <= 0;    
        
        phy_a <= addr[9:0]; // A0-A9 row address
        cmd <= CMD_WRITE;
        phy_dq_oe <= 1;
        phy_dq_out <= word_data_s[31:16];//addr[15:0];//
        phy_dqm     <= ~word_mask_s[3:2];
        addr <= addr + 1'b1;
        
        state <= ST_WRITE_3;    
    end
    ST_WRITE_3: begin
        dc <= 0;    
        
        phy_a <= addr[9:0]; // A0-A9 row address
        cmd <= CMD_WRITE;
        phy_dq_oe <= 1;
        phy_dq_out <= word_data_s[15:0];//16'hABCD; //
        phy_dqm     <= ~word_mask_s[1:0];
        addr <= addr + 1'b1;
        
        state <= ST_WRITE_4;    
    end
    ST_WRITE_4: begin
        if(dc == TIMING_WRITE-1+1) begin
            dc <= 0;
            cmd <= CMD_PRECHG;
            phy_dqm     <= 2'b00;
            phy_a[10] <= 0; // only precharge current bank 
            state <= ST_WRITE_5;    
        end
    end
    ST_WRITE_5: begin
        if(dc == TIMING_PRECHARGE-1) begin // was -3
            state <= ST_IDLE;
        end 
    end
    
    
    ST_READ_0: begin
        dc <= 0;
        
        phy_ba <= addr[24:23];
        phy_a <= addr[22:10]; // A0-A12 column address
        cmd <= CMD_ACT;
        
        state <= ST_READ_1;
    end
    ST_READ_1: begin
        phy_a[10] <= 1'b0; // no auto precharge
        enable_dq_read_toggle <= 0;
        if(dc == TIMING_ACT_RW-1) begin
            dc <= 0;
            state <= ST_READ_2;
        end 
    end
    ST_READ_2: begin
        phy_a <= addr[9:0]; // A0-A9 row address
        cmd <= CMD_READ;
            
        enable_dq_read <= 1;
        
        length <= length - 1'b1;
        addr <= addr + 1'b1;
        
        if(length == 1) begin
            // we just read the last word, bail
            read_newrow <= 0;
            state <= ST_READ_5;
        end else
        if(addr[9:0] == 10'd1023) begin
            // at the end of the row, we must activate next row to continue a read
            read_newrow <= 1;
            state <= ST_READ_5;
        end
    end
    ST_READ_5: begin
        state <= ST_READ_8;
    end
    ST_READ_8: begin
        state <= ST_READ_9;
    end
    ST_READ_9: begin
        state <= ST_READ_6;// hmm do we need this
    end
    ST_READ_6: begin
        if(!read_newrow && !word_op) enable_data_done <= 1;
        dc <= 0;
        cmd <= CMD_PRECHG;
        phy_a[10] <= 0; // only precharge current bank
        state <= ST_READ_7; 
    end
    ST_READ_7: begin
        if(dc == TIMING_PRECHARGE-1) begin
            if(read_newrow) 
                state <= ST_READ_0;
            else
                state <= ST_IDLE;
        end 
    end
    
    ST_BURSTWR_0: begin
        phy_ba <= addr[24:23];
        phy_a <= addr[22:10]; // A0-A12 column address
        cmd <= CMD_ACT;
        state <= ST_BURSTWR_1;
    end
    ST_BURSTWR_1: begin
        cmd <= CMD_NOP;
        state <= ST_BURSTWR_2;
    end
    ST_BURSTWR_2: begin
        cmd <= CMD_NOP;
        state <= ST_BURSTWR_3;
    end
    ST_BURSTWR_3: begin
        burstwr_ready <= 1;
        burstwr_newrow <= 0;
        
        if(burstwr_strobe) begin
        
            phy_a <= addr[9:0]; // A0-A9 row address
            cmd <= CMD_WRITE;
            phy_dq_oe <= 1;
            phy_dq_out <= burstwr_data;
            
            addr <= addr + 1'b1;
            /*if(addr_col9_next_1 == 9'h0) begin
                burstwr_ready <= 0;
                burstwr_newrow <= 1;
                state <= ST_BURSTWR_4;
            end */
        end
        if(burstwr_strobe | burstwr_done) begin
            burstwr_newrow <= 0;
            state <= ST_BURSTWR_4;
        end
    end
    ST_BURSTWR_4: begin
        cmd <= CMD_NOP;
        state <= ST_BURSTWR_5;
    end
    ST_BURSTWR_5: begin
        cmd <= CMD_PRECHG;
        phy_a[10] <= 0; // only precharge current bank 
        state <= ST_BURSTWR_6;
    end
    ST_BURSTWR_6: begin
        cmd <= CMD_NOP;
        state <= ST_BURSTWR_7;  
    end
    ST_BURSTWR_7: begin
        cmd <= CMD_NOP;
        state <= ST_IDLE;   
        if(burstwr_newrow) begin
            state <= ST_BURSTWR_0;
            if(issue_autorefresh) begin
                state <= ST_REFRESH_0;
            end
        end
    end
    
    
    ST_REFRESH_0: begin
        // autorefresh 
        issue_autorefresh <= 0;
        
        cmd <= CMD_AUTOREF;
        dc <= 0;
        state <= ST_REFRESH_1;
    end
    ST_REFRESH_1: begin
        if(dc == TIMING_AUTOREFRESH-1)  begin
            state <= ST_IDLE;
            if(burstwr_newrow) begin
                state <= ST_BURSTWR_0;
            end
        end
    end
    
    endcase
    
    
    // catch incoming events if fsm is busy
    if(word_rd_r) begin
        word_rd_queue <= 1;
        word_busy <= 1;
    end
    if(word_wr_r) begin
        word_wr_queue <= 1;
        word_busy <= 1;
    end
    if(burst_rd) begin
        burst_rd_queue <= 1;
    end
    if(burstwr) begin
        burstwr_queue <= 1;
    end
    
    // autorefresh generator
    refresh_count <= refresh_count + 1'b1;
    if(&refresh_count) begin 
        // every 6.144 uS @ 166mhz
        // note that the number of rows affects how often you must issue a refresh command
        // and this particular sdram has more than usual
        refresh_count <= 0;
        issue_autorefresh <= 1;
    
    end
    
    if(~reset_n_s) begin    
        // reset
        state <= ST_RESET;
        refresh_count <= 0;
    end
end

assign phy_clk = chip_clk;

endmodule

//module synch_3 #(parameter WIDTH = 1) (
//   input  wire [WIDTH-1:0] i,     // input signal
//   output reg  [WIDTH-1:0] o,     // synchronized output
//   input  wire             clk,   // clock to synchronize on
//   output wire             rise,   // one-cycle rising edge pulse
//   output wire             fall    // one-cycle falling edge pulse
//);
//
//reg [WIDTH-1:0] stage_1;
//reg [WIDTH-1:0] stage_2;
//reg [WIDTH-1:0] stage_3;
//
//assign rise = (WIDTH == 1) ? (o & ~stage_3) : 1'b0;
//assign fall = (WIDTH == 1) ? (~o & stage_3) : 1'b0;
//always @(posedge clk) 
//   {stage_3, o, stage_2, stage_1} <= {o, stage_2, stage_1, i};
//   
//endmodule


//module bram_block_dp #(
//   parameter DATA = 32,
//   parameter ADDR = 7
//) (
//   input  wire            a_clk,
//   input  wire            a_wr,
//   input  wire [ADDR-1:0] a_addr,
//   input  wire [DATA-1:0] a_din,
//   output reg  [DATA-1:0] a_dout,
// 
//   input  wire            b_clk,
//   input  wire            b_wr,
//   input  wire [ADDR-1:0] b_addr,
//   input  wire [DATA-1:0] b_din,
//   output reg  [DATA-1:0] b_dout
//);
//
//reg [DATA-1:0] mem [(2**ADDR)-1:0];
// 
//always @(posedge a_clk) begin
//   if(a_wr) begin
//      a_dout <= a_din;
//      mem[a_addr] <= a_din;
//   end else
//      a_dout <= mem[a_addr];
//end
// 
//always @(posedge b_clk) begin
//   if(b_wr) begin
//      b_dout <= b_din;
//      mem[b_addr] <= b_din;
//   end else
//      b_dout <= mem[b_addr];
//end
//
//endmodule
