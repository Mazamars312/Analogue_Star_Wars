//
// User core top-level
//
// Star Wars Arcade
//

`default_nettype none

module core_top (

//
// physical connections
//

///////////////////////////////////////////////////
// clock inputs 74.25mhz. not phase aligned, so treat these domains as asynchronous

input   wire            clk_74a, // mainclk1
input   wire            clk_74b, // mainclk1 

///////////////////////////////////////////////////
// cartridge interface
// switches between 3.3v and 5v mechanically
// output enable for multibit translators controlled by pic32

// GBA AD[15:8]
inout   wire    [7:0]   cart_tran_bank2,
output  wire            cart_tran_bank2_dir,

// GBA AD[7:0]
inout   wire    [7:0]   cart_tran_bank3,
output  wire            cart_tran_bank3_dir,

// GBA A[23:16]
inout   wire    [7:0]   cart_tran_bank1,
output  wire            cart_tran_bank1_dir,

// GBA [7] PHI#
// GBA [6] WR#
// GBA [5] RD#
// GBA [4] CS1#/CS#
//     [3:0] unwired
inout   wire    [7:4]   cart_tran_bank0,
output  wire            cart_tran_bank0_dir,

// GBA CS2#/RES#
inout   wire            cart_tran_pin30,
output  wire            cart_tran_pin30_dir,
// when GBC cart is inserted, this signal when low or weak will pull GBC /RES low with a special circuit
// the goal is that when unconfigured, the FPGA weak pullups won't interfere.
// thus, if GBC cart is inserted, FPGA must drive this high in order to let the level translators
// and general IO drive this pin.
output  wire            cart_pin30_pwroff_reset,

// GBA IRQ/DRQ
inout   wire            cart_tran_pin31,
output  wire            cart_tran_pin31_dir,

// infrared
input   wire            port_ir_rx,
output  wire            port_ir_tx,
output  wire            port_ir_rx_disable, 

// GBA link port
inout   wire            port_tran_si,
output  wire            port_tran_si_dir,
inout   wire            port_tran_so,
output  wire            port_tran_so_dir,
inout   wire            port_tran_sck,
output  wire            port_tran_sck_dir,
inout   wire            port_tran_sd,
output  wire            port_tran_sd_dir,
 
///////////////////////////////////////////////////
// cellular psram 0 and 1, two chips (64mbit x2 dual die per chip)

output  wire    [21:16] cram0_a,
inout   wire    [15:0]  cram0_dq,
input   wire            cram0_wait,
output  wire            cram0_clk,
output  wire            cram0_adv_n,
output  wire            cram0_cre,
output  wire            cram0_ce0_n,
output  wire            cram0_ce1_n,
output  wire            cram0_oe_n,
output  wire            cram0_we_n,
output  wire            cram0_ub_n,
output  wire            cram0_lb_n,

output  wire    [21:16] cram1_a,
inout   wire    [15:0]  cram1_dq,
input   wire            cram1_wait,
output  wire            cram1_clk,
output  wire            cram1_adv_n,
output  wire            cram1_cre,
output  wire            cram1_ce0_n,
output  wire            cram1_ce1_n,
output  wire            cram1_oe_n,
output  wire            cram1_we_n,
output  wire            cram1_ub_n,
output  wire            cram1_lb_n,

///////////////////////////////////////////////////
// sdram, 512mbit 16bit

output  wire    [12:0]  dram_a,
output  wire    [1:0]   dram_ba,
inout   wire    [15:0]  dram_dq,
output  wire    [1:0]   dram_dqm,
output  wire            dram_clk,
output  wire            dram_cke,
output  wire            dram_ras_n,
output  wire            dram_cas_n,
output  wire            dram_we_n,

///////////////////////////////////////////////////
// sram, 1mbit 16bit

output  wire    [16:0]  sram_a,
inout   wire    [15:0]  sram_dq,
output  wire            sram_oe_n,
output  wire            sram_we_n,
output  wire            sram_ub_n,
output  wire            sram_lb_n,

///////////////////////////////////////////////////
// vblank driven by dock for sync in a certain mode

input   wire            vblank,

///////////////////////////////////////////////////
// i/o to 6515D breakout usb uart

output  wire            dbg_tx,
input   wire            dbg_rx,

///////////////////////////////////////////////////
// i/o pads near jtag connector user can solder to

output  wire            user1,
input   wire            user2,

///////////////////////////////////////////////////
// RFU internal i2c bus 

inout   wire            aux_sda,
output  wire            aux_scl,

///////////////////////////////////////////////////
// RFU, do not use
output  wire            vpll_feed,


//
// logical connections
//

///////////////////////////////////////////////////
// video, audio output to scaler
output  wire    [23:0]  video_rgb,
output  wire            video_rgb_clock,
output  wire            video_rgb_clock_90,
output  wire            video_de,
output  wire            video_skip,
output  wire            video_vs,
output  wire            video_hs,
    
output  wire            audio_mclk,
input   wire            audio_adc,
output  wire            audio_dac,
output  wire            audio_lrck,

///////////////////////////////////////////////////
// bridge bus connection
// synchronous to clk_74a
output  wire            bridge_endian_little,
input   wire    [31:0]  bridge_addr,
input   wire            bridge_rd,
output  reg     [31:0]  bridge_rd_data,
input   wire            bridge_wr,
input   wire    [31:0]  bridge_wr_data,

///////////////////////////////////////////////////
// controller data
// 
// key bitmap:
//   [0]    dpad_up
//   [1]    dpad_down
//   [2]    dpad_left
//   [3]    dpad_right
//   [4]    face_a
//   [5]    face_b
//   [6]    face_x
//   [7]    face_y
//   [8]    trig_l1
//   [9]    trig_r1
//   [10]   trig_l2
//   [11]   trig_r2
//   [12]   trig_l3
//   [13]   trig_r3
//   [14]   face_select
//   [15]   face_start
//   [31:28] type
// joy values - unsigned
//   [ 7: 0] lstick_x
//   [15: 8] lstick_y
//   [23:16] rstick_x
//   [31:24] rstick_y
// trigger values - unsigned
//   [ 7: 0] ltrig
//   [15: 8] rtrig
//
input   wire    [31:0]  cont1_key,
input   wire    [31:0]  cont2_key,
input   wire    [31:0]  cont3_key,
input   wire    [31:0]  cont4_key,
input   wire    [31:0]  cont1_joy,
input   wire    [31:0]  cont2_joy,
input   wire    [31:0]  cont3_joy,
input   wire    [31:0]  cont4_joy,
input   wire    [15:0]  cont1_trig,
input   wire    [15:0]  cont2_trig,
input   wire    [15:0]  cont3_trig,
input   wire    [15:0]  cont4_trig
    
);

// not using the IR port, so turn off both the LED, and
// disable the receive circuit to save power
assign port_ir_tx = 0;
assign port_ir_rx_disable = 1;
// bridge endianness
assign bridge_endian_little = 0;


// cart is unused, so set all level translators accordingly
// directions are 0:IN, 1:OUT
assign cart_tran_bank3 = 8'hzz;            // these pins are not used, make them inputs
 assign cart_tran_bank3_dir = 1'b0;
 
 assign cart_tran_bank2 = 8'hzz;            // these pins are not used, make them inputs
 assign cart_tran_bank2_dir = 1'b0;
 assign cart_tran_bank1 = 8'hzz;            // these pins are not used, make them inputs
 assign cart_tran_bank1_dir = 1'b0;
 
 assign cart_tran_bank0 = {1'b0, TXDATA, LED, 1'b0};    // LED and TXD hook up here
 assign cart_tran_bank0_dir = 1'b1;
 
 assign cart_tran_pin30 = 1'bz;            // this pin is not used, make it an input
 assign cart_tran_pin30_dir = 1'b0;
 assign cart_pin30_pwroff_reset = 1'b1;    
 
 assign cart_tran_pin31 = 1'bz;            // this pin is an input
 assign cart_tran_pin31_dir = 1'b0;        // input
 // UART
 wire TXDATA;                        // your UART transmit data hooks up here
 wire RXDATA = cart_tran_pin31;        // your UART RX data shows up here
 
 // button/LED
 wire LED;                    // LED hooks up here.  HIGH = light up, LOW = off
 wire BUTTON = cart_tran_bank3[0];    // button data comes out here.  LOW = pressed, HIGH = unpressed

// link port is unused, set to input only to be safe
// each bit may be bidirectional in some applications
assign port_tran_so = 1'bz;
assign port_tran_so_dir = 1'b0;     // SO is output only
assign port_tran_si = 1'bz;
assign port_tran_si_dir = 1'b0;     // SI is input only
assign port_tran_sck = 1'bz;
assign port_tran_sck_dir = 1'b0;    // clock direction can change
assign port_tran_sd = 1'bz;
assign port_tran_sd_dir = 1'b0;     // SD is input and not used

// tie off the rest of the pins we are not using
assign cram0_a = 'h0;
assign cram0_dq = {16{1'bZ}};
assign cram0_clk = 0;
assign cram0_adv_n = 1;
assign cram0_cre = 0;
assign cram0_ce0_n = 1;
assign cram0_ce1_n = 1;
assign cram0_oe_n = 1;
assign cram0_we_n = 1;
assign cram0_ub_n = 1;
assign cram0_lb_n = 1;

assign cram1_a = 'h0;
assign cram1_dq = {16{1'bZ}};
assign cram1_clk = 0;
assign cram1_adv_n = 1;
assign cram1_cre = 0;
assign cram1_ce0_n = 1;
assign cram1_ce1_n = 1;
assign cram1_oe_n = 1;
assign cram1_we_n = 1;
assign cram1_ub_n = 1;
assign cram1_lb_n = 1;

//assign dram_a = 'h0;
//assign dram_ba = 'h0;
//assign dram_dq = {16{1'bZ}};
//assign dram_dqm = 'h0;
//assign dram_clk = 'h0;
//assign dram_cke = 'h0;
//assign dram_ras_n = 'h1;
//assign dram_cas_n = 'h1;
//assign dram_we_n = 'h1;

assign sram_a = 'h0;
assign sram_dq = {16{1'bZ}};
assign sram_oe_n  = 1;
assign sram_we_n  = 1;
assign sram_ub_n  = 1;
assign sram_lb_n  = 1;

assign dbg_tx = 1'bZ;
assign user1 = 1'bZ;
assign aux_scl = 1'bZ;
assign vpll_feed = 1'bZ;

wire clk_mpu = clk_74a;

   wire    					pll_core_locked;
   wire    					pll_core_locked_s;

	reg						sdram_input_valid;
	wire 						sdram_write;
	wire 						sdram_request;
	wire [25:0]   			sdram_address;
	wire [3:0]    			sdram_mask;
	wire [31:0]   			sdram_data_out;
	wire  [31:0]   		sdram_data_in;
	

reg [31:0] setting_reg, setting_reg_temp;
// for bridge write data, we just broadcast it to all bus devices
// for bridge read data, we have to mux it
// add your own devices here
always @(*) begin
    casex(bridge_addr)
    default: begin
        bridge_rd_data <= 0;
    end
    32'hA0xxxxxx: begin
        // example
        // bridge_rd_data <= example_device_data;
        bridge_rd_data <= setting_reg;
    end
    32'hF8xxxxxx: begin
        bridge_rd_data <= cmd_bridge_rd_data;
    end
    endcase
end


reg [7:0] AUDIO_OUT_CIO_0_SHIFT; 
reg [7:0] AUDIO_OUT_CIO_1_SHIFT; 
reg [7:0] AUDIO_OUT_CIO_2_SHIFT; 
reg [7:0] AUDIO_OUT_CIO_3_SHIFT; 
reg [7:0] AUDIO_OUT_SPEECH_SHIFT; 


    reg [7:0]         OPT_0_DATA_IN = 8'b0000_0000; 
    reg [7:0]         OPT_1_DATA_IN = 8'b0000_0000;
    reg               LEFT_F_S 		= 1'b0; 
    reg               RIGHT_F_S 		= 1'b0;  
    reg               SELFTEST 		= 1'b0;  
    reg               SLAM 			= 1'b0;  
    reg               COIN_AUX 		= 1'b0;  
    reg               COIN_L 			= 1'b0;  
    reg               COIN_R 			= 1'b0; 
    reg               LEFT_THUMB 	= 1'b0;  
    reg               RIGHT_THUMB 	= 1'b0;  
    reg               DIAGN 			= 1'b0; 
	 
	 reg [7:0]         ADC_DATA_OUT 	= 8'h80;
    wire              ADCSTART0_WR;
    wire              ADCSTART1_WR;
    wire              ADCSTART2_WR;
	 wire 				 LED3;
	 wire 				 LED2;
	 wire 				 LED1;
	 
	 wire 				 reset_out;


always @(posedge clk_74a) begin
	if (bridge_addr == 32'hA000_0000 && bridge_wr) AUDIO_OUT_CIO_0_SHIFT <= bridge_wr_data;
	if (bridge_addr == 32'hA000_0004 && bridge_wr) AUDIO_OUT_CIO_1_SHIFT <= bridge_wr_data;
	if (bridge_addr == 32'hA000_0008 && bridge_wr) AUDIO_OUT_CIO_2_SHIFT <= bridge_wr_data;
	if (bridge_addr == 32'hA000_000c && bridge_wr) AUDIO_OUT_CIO_3_SHIFT <= bridge_wr_data;
	if (bridge_addr == 32'hA000_0010 && bridge_wr) AUDIO_OUT_SPEECH_SHIFT <= bridge_wr_data;
	if (bridge_addr == 32'hA000_0014 && bridge_wr) OPT_0_DATA_IN <= bridge_wr_data;
	if (bridge_addr == 32'hA000_0018 && bridge_wr) OPT_1_DATA_IN <= bridge_wr_data;
	if (bridge_addr == 32'hA000_001C && bridge_wr) {LEFT_F_S, RIGHT_F_S, SELFTEST, SLAM, COIN_AUX, COIN_L, COIN_R, LEFT_THUMB, RIGHT_THUMB, DIAGN} <= bridge_wr_data;
	if (bridge_addr == 32'hA000_0020 && bridge_wr) ADC_DATA_OUT <= bridge_wr_data;
	if (bridge_rd) begin
		case (bridge_addr[7:0])
			8'h00 : setting_reg_temp <= AUDIO_OUT_CIO_0_SHIFT;
			8'h04 : setting_reg_temp <= AUDIO_OUT_CIO_1_SHIFT;
			8'h08 : setting_reg_temp <= AUDIO_OUT_CIO_2_SHIFT;
			8'h0c : setting_reg_temp <= AUDIO_OUT_CIO_3_SHIFT;
			8'h10 : setting_reg_temp <= AUDIO_OUT_SPEECH_SHIFT;
			8'h14 : setting_reg_temp <= OPT_0_DATA_IN;
			8'h18 : setting_reg_temp <= OPT_1_DATA_IN;
			8'h1C : setting_reg_temp <= {LEFT_F_S, RIGHT_F_S, SELFTEST, SLAM, COIN_AUX, COIN_L, COIN_R, LEFT_THUMB, RIGHT_THUMB, DIAGN};
			8'h20 : setting_reg_temp <= ADC_DATA_OUT;
		endcase
	end
	setting_reg <= setting_reg_temp;
end

//
// host/target command handler
//
    wire            reset_n;                // driven by host commands, can be used as core-wide reset
    wire    [31:0]  cmd_bridge_rd_data;
    
// bridge host commands
// synchronous to clk_74a
    wire            status_boot_done = pll_core_locked_s; 
    wire            status_setup_done = pll_core_locked_s; // rising edge triggers a target command
    wire            status_running = reset_n; // we are running as soon as reset_n goes high

    wire            system_reset_n = reset_n && ~cont1_key[4]; // we are running as soon as reset_n goes high
    wire            dataslot_requestread;
    wire    [15:0]  dataslot_requestread_id;
    wire            dataslot_requestread_ack = 1;
    wire            dataslot_requestread_ok = 1;

    wire            dataslot_requestwrite;
    wire    [15:0]  dataslot_requestwrite_id;
    wire    [31:0]  dataslot_requestwrite_size;
    wire            dataslot_requestwrite_ack = 1;
    wire            dataslot_requestwrite_ok = 1;

    wire            dataslot_update;
    wire    [15:0]  dataslot_update_id;
    wire    [31:0]  dataslot_update_size;
    
    wire            dataslot_allcomplete;

    wire     [31:0] rtc_epoch_seconds;
    wire     [31:0] rtc_date_bcd;
    wire     [31:0] rtc_time_bcd;
    wire            rtc_valid;

    wire            savestate_supported;
    wire    [31:0]  savestate_addr;
    wire    [31:0]  savestate_size;
    wire    [31:0]  savestate_maxloadsize;

    wire            savestate_start;
    wire            savestate_start_ack;
    wire            savestate_start_busy;
    wire            savestate_start_ok;
    wire            savestate_start_err;

    wire            savestate_load;
    wire            savestate_load_ack;
    wire            savestate_load_busy;
    wire            savestate_load_ok;
    wire            savestate_load_err;
    
    wire            osnotify_inmenu;

// bridge target commands
// synchronous to clk_74a

    reg             target_dataslot_read;       
    reg             target_dataslot_write;
    reg             target_dataslot_getfile;    // require additional param/resp structs to be mapped
    reg             target_dataslot_openfile;   // require additional param/resp structs to be mapped
    
    wire            target_dataslot_ack;        
    wire            target_dataslot_done;
    wire    [2:0]   target_dataslot_err;

    reg     [15:0]  target_dataslot_id;
    reg     [31:0]  target_dataslot_slotoffset;
    reg     [31:0]  target_dataslot_bridgeaddr;
    reg     [31:0]  target_dataslot_length;
    
    wire    [31:0]  target_buffer_param_struct; // to be mapped/implemented when using some Target commands
    wire    [31:0]  target_buffer_resp_struct;  // to be mapped/implemented when using some Target commands
    
// bridge data slot access
// synchronous to clk_74a

    wire    [9:0]   datatable_addr;
    wire            datatable_wren;
    wire    [31:0]  datatable_data;
    wire    [31:0]  datatable_q;

core_bridge_cmd icb (

    .clk                ( clk_74a ),
    .reset_n            ( reset_n ),

    .bridge_endian_little   ( bridge_endian_little ),
    .bridge_addr            ( bridge_addr ),
    .bridge_rd              ( bridge_rd ),
    .bridge_rd_data         ( cmd_bridge_rd_data ),
    .bridge_wr              ( bridge_wr ),
    .bridge_wr_data         ( bridge_wr_data ),
    
    .status_boot_done       ( status_boot_done ),
    .status_setup_done      ( status_setup_done ),
    .status_running         ( status_running ),

    .dataslot_requestread       ( dataslot_requestread ),
    .dataslot_requestread_id    ( dataslot_requestread_id ),
    .dataslot_requestread_ack   ( dataslot_requestread_ack ),
    .dataslot_requestread_ok    ( dataslot_requestread_ok ),

    .dataslot_requestwrite      ( dataslot_requestwrite ),
    .dataslot_requestwrite_id   ( dataslot_requestwrite_id ),
    .dataslot_requestwrite_size ( dataslot_requestwrite_size ),
    .dataslot_requestwrite_ack  ( dataslot_requestwrite_ack ),
    .dataslot_requestwrite_ok   ( dataslot_requestwrite_ok ),

    .dataslot_update            ( dataslot_update ),
    .dataslot_update_id         ( dataslot_update_id ),
    .dataslot_update_size       ( dataslot_update_size ),
    
    .dataslot_allcomplete   ( dataslot_allcomplete ),

    .rtc_epoch_seconds      ( rtc_epoch_seconds ),
    .rtc_date_bcd           ( rtc_date_bcd ),
    .rtc_time_bcd           ( rtc_time_bcd ),
    .rtc_valid              ( rtc_valid ),
    
    .savestate_supported    ( savestate_supported ),
    .savestate_addr         ( savestate_addr ),
    .savestate_size         ( savestate_size ),
    .savestate_maxloadsize  ( savestate_maxloadsize ),

    .savestate_start        ( savestate_start ),
    .savestate_start_ack    ( savestate_start_ack ),
    .savestate_start_busy   ( savestate_start_busy ),
    .savestate_start_ok     ( savestate_start_ok ),
    .savestate_start_err    ( savestate_start_err ),

    .savestate_load         ( savestate_load ),
    .savestate_load_ack     ( savestate_load_ack ),
    .savestate_load_busy    ( savestate_load_busy ),
    .savestate_load_ok      ( savestate_load_ok ),
    .savestate_load_err     ( savestate_load_err ),

    .osnotify_inmenu        ( osnotify_inmenu ),
    
    .target_dataslot_read       ( target_dataslot_read ),
    .target_dataslot_write      ( target_dataslot_write ),
    .target_dataslot_getfile    ( target_dataslot_getfile ),
    .target_dataslot_openfile   ( target_dataslot_openfile ),
    
    .target_dataslot_ack        ( target_dataslot_ack ),
    .target_dataslot_done       ( target_dataslot_done ),
    .target_dataslot_err        ( target_dataslot_err ),

    .target_dataslot_id         ( target_dataslot_id ),
    .target_dataslot_slotoffset ( target_dataslot_slotoffset ),
    .target_dataslot_bridgeaddr ( target_dataslot_bridgeaddr ),
    .target_dataslot_length     ( target_dataslot_length ),

    .target_buffer_param_struct ( target_buffer_param_struct ),
    .target_buffer_resp_struct  ( target_buffer_resp_struct ),
    
    .datatable_addr         ( datatable_addr ),
    .datatable_wren         ( datatable_wren ),
    .datatable_data         ( datatable_data ),
    .datatable_q            ( datatable_q )

);
wire 			clk_12;
reg 			clk_6, clk_3;
reg 			clk_1_5;
wire [15:0] sound_audio_output;

    wire [7:0]         V_data_out;
    wire               VGHALT;
    wire              EVGRES_WR;
    wire              EVGGO_WR;

    wire [15:0]       main_cpu_address;
    wire [7:0]        main_cpu_data_out;
    wire              main_cpu_RnW;
	 
	 wire              sound_en_n;
    wire [7:0]        sound_data_out;
	 wire 				 sound_reset_n;
	 
	// the sram port on the MPU will be used for the Video buffer access 
	// and the System ROM/RAM access
	
	// 24'h1000_0000			PROM 0 (16K)				0x4000	R/W
	// 24'h1000_4000			PROM 1 (8K)					0x2000	R/W
	// 24'h1000_6000			PROM 2 (8K)					0x2000	R/W
	// 24'h1000_8000			PROM 3 (8K)					0x2000	R/W
	// 24'h1000_A000			PROM 4 (8K)					0x2000	R/W
	// 24'h1001_0000			matrix Rom 0 (1K)			0x400		R/W
	// 24'h1001_0400			matrix Rom 1 (1K)			0x400		R/W
	// 24'h1001_0800			matrix Rom 2 (1K)			0x400		R/W
	// 24'h1001_0C00			matrix Rom 3 (1K)			0x400		R/W
	// 24'h1002_0000			Vector Rom 0 (4K)			0x1000	R/W
	// 24'h1003_0000			Vector Ram 0 (16K)		0x4000	R/W
	// 24'h1004_0000			Vector_reg					0x4		R/W
	// 24'h1005_0000			Sound Rom 0 (8K)			0x2000	R/W
	// 24'h1005_0000			Sound Rom 1 (8K)			0x2000	R/W
		
	// DMA cache - This will help with the blend modes
	
	// 24'h0030_0000			cache_address				0x1000	R/W
	
	wire [31:0]		mpu_address;
	wire 				mpu_write;
	wire [3:0]		mpu_mask;
	wire 				mpu_request;
	reg  [31:0]		mpu_data_in;
	wire [31:0]		mpu_data_out;
	reg 				mpu_valid;
	wire 				ram_valid;
	wire 				vram_cmd_ready;
	
	wire [31:0] 	APU_MPU_DATA_OUT;
	wire [31:0] 	VECTOR_MPU_DATA_OUT;
	wire [31:0] 	SOUND_MPU_DATA_OUT;
	wire [31:0] 	ram_data_in;
	reg 				mpu_request_reg;
	always @(posedge clk_74a) mpu_request_reg <= mpu_request;
	always @* begin
		casez (mpu_address[31:20])
			12'h800	: mpu_data_in <= APU_MPU_DATA_OUT;
			12'h801	: mpu_data_in <= SOUND_MPU_DATA_OUT;
			default	: mpu_data_in <= ram_data_in;
		endcase
		casez (mpu_address[31:20])
			12'h800	: mpu_valid <= mpu_request_reg;
			12'h801	: mpu_valid <= mpu_request_reg;
			default	: mpu_valid <= ram_valid;
		endcase
	end
	
	 
	


////////////////////////////////////////////////////////////////////////////////////////

// ALU Board

reg [7:0] ADC_DATA_OUT_REG;

always @(posedge clk_3 or negedge reset_n) begin
	if (~reset_n) ADC_DATA_OUT_REG <= 8'h80;
	else if (|{ADCSTART0_WR, ADCSTART1_WR, ADCSTART2_WR}) ADC_DATA_OUT_REG <= ADC_DATA_OUT;
end

ALU_Top ALU_Top(
    .clk_1_5            (clk_1_5),
    .clk_3              (clk_3),
    .clk_6              (clk_6),
    .clk_12             (clk_12),
    .reset_n            (system_reset_n),
    .main_cpu_address   (main_cpu_address),
    .main_cpu_data_out  (main_cpu_data_out),
    .main_cpu_RnW       (main_cpu_RnW),
    .sound_data_out     (sound_data_out),
    .sound_reset_n      (sound_reset_n),
    .ADC_DATA_OUT       (ADC_DATA_OUT_REG),
    .ADCSTART0_WR       (ADCSTART0_WR),
    .ADCSTART1_WR       (ADCSTART1_WR),
    .ADCSTART2_WR       (ADCSTART2_WR),    
    .OPT_0_DATA_IN      (OPT_0_DATA_IN), 
    .OPT_1_DATA_IN      (OPT_1_DATA_IN),
    .LEFT_F_S           (1'b0), 
    .RIGHT_F_S          (1'b0), 
    .SELFTEST           (SELFTEST), 
    .SLAM               (SLAM), 
    .COIN_AUX           (1'b0), 
    .COIN_L             (cont1_key[14]), 
    .COIN_R             (cont1_key[15]),
    .LEFT_THUMB         (cont1_key[8]), 
    .RIGHT_THUMB        (cont1_key[9]), 
    .DIAGN              (DIAGN),
	 .LED3					(LED3),
	 .LED2					(LED2),
	 .LED1					(LED1),
	 .clk_mpu				(clk_mpu),
	 .mpu_address			(mpu_address),
	 .mpu_write				(mpu_write),
	 .mpu_mask				(mpu_mask),
	 .mpu_request			(mpu_request),
	 .mpu_data_in			(APU_MPU_DATA_OUT),
	 .mpu_data_out			(mpu_data_out)
	 
	 
    );    


// Sound board


sound_top sound_top(
    .clk_1_5            		(clk_1_5          ),
    .clk_3              		(clk_3            ),
    .clk_6              		(clk_6            ),
    .clk_12              		(clk_12            ),
    .sound_reset_n      		(system_reset_n && sound_reset_n),
    .sound_read_nwrite  		(main_cpu_RnW     ),
    .cpu_address        		(main_cpu_address ),
    .cpu_data_out       		(main_cpu_data_out),
    .sound_data_out     		(sound_data_out   ),
    .sound_self_test    		(1'b1		),
    .sound_audio_output     	(sound_audio_output),
	 .clk_mpu						(clk_mpu),
	 .mpu_address					(mpu_address		),
	 .mpu_write						(mpu_write			),
	 .mpu_mask						(mpu_mask			),
	 .mpu_request					(mpu_request		),
	 .mpu_data_in					(SOUND_MPU_DATA_OUT		),
	 .mpu_data_out					(mpu_data_out)
);

	i2s i2s (
		.clk_74a						(clk_74a),
		.left_audio					(sound_audio_output),
		.right_audio				(sound_audio_output),
		.audio_mclk					(audio_mclk),
		.audio_dac					(audio_dac),
		.audio_lrck					(audio_lrck)
	);
	 

//////////////////PLL///////////////////////
wire clk_ram_controller;
synch_3 s01(pll_core_locked, pll_core_locked_s, clk_74a);

mf_pllbase mp1 (
    .refclk         				( clk_74a ),
    .rst            				( 0 ),
    
    .outclk_0       				( clk_12 ),
    .outclk_1       				( video_rgb_clock ),
    .outclk_2       				( video_rgb_clock_90 ),
	 .outclk_3						(clk_ram_controller),
    
    .locked         				( pll_core_locked )
);

reg [2:0] count;
reg sdram_delay;

always @(posedge clk_12) begin
	count 	<= count + 1;
	clk_6 	<= count[0] == 0;
	clk_3 	<= count[1:0] == 0;
	clk_1_5 	<= count[2:0] == 0;
end


wire 		[10:0] 	y_count_frame;
wire 		[10:0] 	x_count_frame;
wire 				video_enable_output;
wire 		[23:0]	color_input;
wire [31:0] CORE_OUTPUT;
wire [31:0]	CORE_INPUT;

substitute_mcu_apf_mister substitute_mcu_apf_mister(
	.clk_mpu							(clk_mpu						),
	.clk_sys							(clk_mpu						),
	.reset_n							(system_reset_n			),
	.reset_out						(reset_out					),
	.clk_74a							(clk_74a						),
	.bridge_addr					(bridge_addr				),
	.bridge_rd						(bridge_rd					),
	.bridge_wr						(bridge_wr					),
	.bridge_wr_data				(bridge_wr_data			),		
	.vram_input_valid				(mpu_valid					),
	.vram_write						(mpu_write					),
	.vram_request					(mpu_request				),
	.vram_address					(mpu_address				),
	.vram_mask						(mpu_mask					),
	.vram_data_out					(mpu_data_out				),
	.vram_data_in					(mpu_data_in				),
	.vram_cmd_ready				(vram_cmd_ready),
	.txd								(TXDATA						),
	.rxd								(RXDATA						),
	.CORE_OUTPUT					(CORE_OUTPUT						),
	.CORE_INPUT					   (CORE_INPUT						)
    );

video_sdram_core video_sdram_core (
    .reset_n				(system_reset_n),
    .clk_ram_controller	(clk_ram_controller),
    .video_rgb_clock		(video_rgb_clock),
    .video_rgb				(video_rgb),
    .video_de				(video_de),
    .video_skip			(video_skip),
    .video_vs				(video_vs),
    .video_hs				(video_hs),
	 
	.dram_cke        		( dram_cke ),
	.dram_clk        		( dram_clk ),
	.dram_cas_n      		( dram_cas_n ),
	.dram_ras_n      		( dram_ras_n ),
	.dram_we_n       		( dram_we_n ),
	.dram_ba         		( dram_ba ),
	.dram_a          		( dram_a ),
	.dram_dq         		( dram_dq ),
	.dram_dqm        		( dram_dqm ),
    
    .interrupt				(),
    
    .clk_74a				(clk_mpu),
    .bridge_addr			(mpu_address),
    .bridge_rd				(~mpu_write && mpu_request),
    .bridge_wr				(mpu_write && mpu_request),
    .bridge_mask			(mpu_mask),
    .bridge_wr_data		(mpu_data_out),
    .bridge_rd_data		(ram_data_in),
    .bridge_valid			(ram_valid),
	 .vram_cmd_ready		(vram_cmd_ready)
);
	 
	 
//wire [18:0] address_framebuffer;
//// sdram controller and PLL
//wire [7:0] frame_number;
//wire hold_frame;
//video_module video_module (
//.clk_vga                (video_rgb_clock    ),
//.reset_n                (system_reset_n          ),
//.y_count_frame          (y_count_frame      ),
//.x_count_frame          (x_count_frame      ),
//.address_framebuffer		(address_framebuffer),
//.video_enable_output    (video_enable_output),
//.color_input            (color_input        ),
//.frame_number				(frame_number),
//.hold_frame             (hold_frame    		),
//.video_rgb              (video_rgb          ),
//.video_de               (video_de           ),
//.video_skip             (video_skip         ),
//.video_vs               (video_vs           ),
//.video_hs               (video_hs           )
//
//);
//
//wire pixel_wr_full;
//
//assign CORE_INPUT[7:0] 	= frame_number; 
//assign CORE_INPUT[31]	= pixel_wr_full; 
//
//reg enable_write;
//
//always @(posedge clk_mpu) begin
//	enable_write <= CORE_OUTPUT[23];
//end
//
//
//video_core_pdp video_core_pdp(
//
//	.clk               (video_rgb_clock),                    // 42.4Mz (all video processing)
//	.clk_sys           (clk_mpu),						// 50Mhz (CPU clock)
//	.horizontal_counter(x_count_frame),              
//	.vertical_counter  (y_count_frame),   
//	.enable_video_out  (video_enable_output),
//.address_framebuffer		(address_framebuffer),
//	.reset_l				 (system_reset_n),
//	.hold_frame			 (hold_frame),
//	.red_out           (color_input[23:16]),                         
//	.green_out         (color_input[15: 8]),
//	.blue_out          (color_input[ 7: 0]), 
//	.pixel_x_i         (CORE_OUTPUT[9:0]),              // X pixel coordinate 
//	.pixel_y_i         (CORE_OUTPUT[19:10]),                  
//	.pixel_c_i         (CORE_OUTPUT[22:20]),  
//	.pixel_wr_full		 (pixel_wr_full),
//	.pixel_write       (~enable_write && CORE_OUTPUT[23]),
//	.trail_len         (3'b0),
//	.blur_on           (1'b1)
//	
//	
//);



    
endmodule

