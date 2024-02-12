`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.05.2023 18:48:07
// Design Name: 
// Module Name: sound_top
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


module sound_top(
    input               clk_1_5,
    input               clk_3,
    input               clk_6,
    input               clk_12,
    input               sound_reset_n,
    input               sound_read_nwrite,
    input  [15:0]       cpu_address,
    input  [7:0]        cpu_data_out,
    output [7:0]        sound_data_out,
    
    input               sound_self_test,
    
    output reg [15:0]   sound_audio_output,
    
    input 				clk_mpu,
    input [31:0]		mpu_address,
    input 				mpu_write,
    input [3:0]			mpu_mask,
    input 				mpu_request,
    input [31:0]		mpu_data_out,
    output reg [31:0]	mpu_data_in
    );
    
	 // Delayed reset core
	 reg [3:0] cnt_reset = 0;
	 reg sound_reset_int_n = 0;
	 
	 always @(posedge clk_1_5 or negedge sound_reset_n) begin
		if (!sound_reset_n) begin
			sound_reset_int_n <= 0;
			cnt_reset			<= 0;
		end
		else begin
			if (&cnt_reset) begin
				sound_reset_int_n	<= 1;
			end
			else begin
				cnt_reset			<= cnt_reset + 1;
				sound_reset_int_n <= 0;
			end
		end	 
	 end
	 
	 
    wire [13:0] O_TMS5220_SPKR;
    
    wire    [15:0]  sound_cpu_address;
    reg     [7:0]   sound_cpu_data_in;
    wire    [7:0]   sound_cpu_data_out;
    wire            sound_cpu_RnW;
    
    reg     [7:0]   SIN_DATA;
    wire    [7:0]   PIA_DATA_OUT;
    wire    [7:0]   CIO_0_DATA_OUT;
    wire    [7:0]   CIO_1_DATA_OUT;
    wire    [7:0]   CIO_2_DATA_OUT;
    wire    [7:0]   CIO_3_DATA_OUT;
    
    
    wire    [7:0]   PRAM_DATA_OUT;
    wire    [7:0]   SROM_DATA_OUT;
    
    wire            SIRQ_N;
    reg    [7:0]    SOUT_DATA;
    reg             SOUT_REG_READY;
    reg             SIN_REG_READY;
    
    assign sound_data_out = ~cpu_address[0] ? SOUT_DATA : {SIN_REG_READY, SOUT_REG_READY, 6'b0};
 
    
    always @* begin
        casez({sound_cpu_address[14:11],sound_cpu_address[4:3]})
            {4'b0001, 2'bzz}	: sound_cpu_data_in <= SIN_DATA;
            {4'b0010, 2'bzz} 	: sound_cpu_data_in <= PIA_DATA_OUT;
            {4'b0011, 2'b00} 	: sound_cpu_data_in <= CIO_0_DATA_OUT;
            {4'b0011, 2'b01} 	: sound_cpu_data_in <= CIO_1_DATA_OUT;
            {4'b0011, 2'b10} 	: sound_cpu_data_in <= CIO_2_DATA_OUT;
            {4'b0011, 2'b11} 	: sound_cpu_data_in <= CIO_3_DATA_OUT;
            {4'b01zz, 2'bzz} 	: sound_cpu_data_in <= PRAM_DATA_OUT;
				{4'b1zzz, 2'bzz} 	: sound_cpu_data_in <= SROM_DATA_OUT;
            default  			: sound_cpu_data_in <= 8'h00;
        endcase
    end
    
//    wire ram_access      =   sound_cpu_address[14:13] == 2'b01; 
//    wire rom_access      =   sound_cpu_address[14]; 
//    wire CIO_0_access    =   {sound_cpu_address[14:11],sound_cpu_address[4:3]} == 6'b001100; 
//    wire CIO_1_access    =   {sound_cpu_address[14:11],sound_cpu_address[4:3]} == 6'b001101; 
//    wire CIO_2_access    =   {sound_cpu_address[14:11],sound_cpu_address[4:3]} == 6'b001110; 
//    wire CIO_3_access    =   {sound_cpu_address[14:11],sound_cpu_address[4:3]} == 6'b001111; 
//    wire PIA_access      =   {sound_cpu_address[14:11]} == 4'b0010; 
//    wire SIN_access      =   {sound_cpu_address[14:11]} == 4'b0001; 
    
// SIN and SOUT Regs


always @(posedge clk_12 or negedge sound_reset_n) begin
	if (~sound_reset_n) begin
		SIN_REG_READY 	<= 0;
		SIN_DATA			<= 0;
	end
	else if (clk_1_5) begin
		if ((cpu_address[15:8] == 8'h44 && !cpu_address[0]) && !sound_read_nwrite) begin
			SIN_REG_READY 	<= 1;
			SIN_DATA 		<= cpu_data_out;
		end
		else if ((sound_cpu_address[14:11] == 4'b0001) && sound_cpu_RnW) 	
			SIN_REG_READY <= 0;
	end
end


always @(posedge clk_12 or negedge sound_reset_n) begin
	if (~sound_reset_n) begin
		SOUT_REG_READY <= 0;
		SOUT_DATA <= 0;
	end
	else if (clk_1_5) begin
		if (sound_cpu_address[14:11] == 4'b0000 && !sound_cpu_RnW) begin
			SOUT_REG_READY <= 1;
			SOUT_DATA 		<= sound_cpu_data_out;
		end
		else if ((cpu_address[15:8] == 8'h44 && !cpu_address[0]) && sound_read_nwrite)  		
			SOUT_REG_READY <= 0;
	end
end


//// CPU, ROM, RAM 
 
    mc6809e mc6809e(
    .D      (sound_cpu_data_in),
    .DOut   (sound_cpu_data_out),
    .ADDR   (sound_cpu_address),
    .RnW    (sound_cpu_RnW),
    .E      (clk_1_5),
    .Q      (clk_3),
    .nIRQ   (SIRQ_N),
    .nFIRQ  (1'b1),
    .nNMI   (1'b1),
    .nHALT  (1'b1),	 
    .nRESET (sound_reset_int_n)

    );
    
Sound_RAM Sound_RAM(
    .clk			(clk_12),
    .address	(sound_cpu_address[10:0]),
    .write		(sound_cpu_address[14:13] == 2'b01 && !sound_cpu_RnW && clk_1_5),
    .data		(sound_cpu_data_out),
    .q			(PRAM_DATA_OUT)
    );


Sound_program_rom_1 Sound_program_rom_1(
    .clk        (clk_12),
    .address    (sound_cpu_address[13:0]),
    .data       (SROM_DATA_OUT)
    );
    
wire [5:0]  AUDIO_OUT_CIO_0, AUDIO_OUT_CIO_1, AUDIO_OUT_CIO_2, AUDIO_OUT_CIO_3;

POKEY CIO_0 (
    .ADDR       ({sound_cpu_address[5], sound_cpu_address[2], sound_cpu_address[1], sound_cpu_address[0]}),
    .DIN        (sound_cpu_data_out),
    .DOUT       (CIO_0_DATA_OUT),
    .DOUT_OE_L  (),
    .RW_L       (sound_cpu_RnW),
    .CS         (sound_cpu_address[14:11] == 4'b0011 && sound_cpu_address[4:3] == 2'b00),
    .CS_L       (1'b0),
    .AUDIO_OUT  (AUDIO_OUT_CIO_0),
    .PIN        (8'h00),
    .ENA        (clk_1_5),
    .CLK        (clk_12)
);

POKEY CIO_1 (
    .ADDR       ({sound_cpu_address[5], sound_cpu_address[2], sound_cpu_address[1], sound_cpu_address[0]}),
    .DIN        (sound_cpu_data_out),
    .DOUT       (CIO_1_DATA_OUT),
    .DOUT_OE_L  (),
    .RW_L       (sound_cpu_RnW),
    .CS         (sound_cpu_address[14:11] == 4'b0011 && sound_cpu_address[4:3] == 2'b01),
    .CS_L       (1'b0),
    .AUDIO_OUT  (AUDIO_OUT_CIO_1),
    .PIN        (8'h00),
    .ENA        (clk_1_5),
    .CLK        (clk_12)
);

POKEY CIO_2 (
    .ADDR       ({sound_cpu_address[5], sound_cpu_address[2], sound_cpu_address[1], sound_cpu_address[0]}),
    .DIN        (sound_cpu_data_out),
    .DOUT       (CIO_2_DATA_OUT),
    .DOUT_OE_L  (),
    .RW_L       (sound_cpu_RnW),
    .CS         (sound_cpu_address[14:11] == 4'b0011 && sound_cpu_address[4:3] == 2'b10),
    .CS_L       (1'b0),
    .AUDIO_OUT  (AUDIO_OUT_CIO_2),
    .PIN        (8'h00),
    .ENA        (clk_1_5),
    .CLK        (clk_12)
);
   
POKEY CIO_3 (
    .ADDR       ({sound_cpu_address[5], sound_cpu_address[2], sound_cpu_address[1], sound_cpu_address[0]}),
    .DIN        (sound_cpu_data_out),
    .DOUT       (CIO_3_DATA_OUT),
    .DOUT_OE_L  (),
    .RW_L       (sound_cpu_RnW),
    .CS         (sound_cpu_address[14:11] == 4'b0011 && sound_cpu_address[4:3] == 2'b11),
    .CS_L       (1'b0),
    .AUDIO_OUT  (AUDIO_OUT_CIO_3),
    .PIN        (8'h00),
    .ENA        (clk_1_5),
    .CLK        (clk_12)
);
	
/*********************************************************

    Speech Core

*********************************************************/

    wire [7:0]  pa_dir;
    wire [7:0]  pb_dir;
    wire [7:0]  pa_out;
    wire [7:0]  pb_out;
    wire [7:0]  pa;
    wire [7:0]  pb;
    wire [7:0]  TMS5220_data_out;
    wire        O_RDYn;
    
    assign pa[7] = SIN_REG_READY;
    assign pa[6] = SOUT_REG_READY;
    assign pa[5] = pa_dir[5] ? pa_out[5] : 1'b0;
    assign pa[4] = sound_self_test;
    assign pa[3] = pa_dir[3] ? pa_out[4] : 1'b0;
    assign pa[2] = O_RDYn;
    assign pa[1] = pa_out[1];
    assign pa[0] = pa_out[0];
    
    assign pb[7] = pb_dir[7] ? pb_out[7] : TMS5220_data_out[7];
    assign pb[6] = pb_dir[6] ? pb_out[6] : TMS5220_data_out[6];
    assign pb[5] = pb_dir[5] ? pb_out[5] : TMS5220_data_out[5];
    assign pb[4] = pb_dir[4] ? pb_out[4] : TMS5220_data_out[4];
    assign pb[3] = pb_dir[3] ? pb_out[3] : TMS5220_data_out[3];
    assign pb[2] = pb_dir[2] ? pb_out[2] : TMS5220_data_out[2];
    assign pb[1] = pb_dir[1] ? pb_out[1] : TMS5220_data_out[1];
    assign pb[0] = pb_dir[0] ? pb_out[0] : TMS5220_data_out[0];
    
    r6532 r6532(
		.phi2    (clk_1_5),
		.res_n   (sound_reset_n),
		.CS1     (sound_cpu_address[14:11] == 4'b0010),
		.CS2_n   (1'b0),
		.RS_n    (sound_cpu_address[7]),
		.R_W     (sound_cpu_RnW),
		.addr    (sound_cpu_address[6:0]),
		.dataIn  (sound_cpu_data_out),
		.dataOut (PIA_DATA_OUT),
		.pa      (pa),
		.pa_out  (pa_out),
		.pa_dir  (pa_dir),
		.pb      (pb),
		.pb_out  (pb_out),
		.pb_dir  (pb_dir),
		.IRQ_n   (SIRQ_N)
	);
	

	wire [3:0] cnt_sound;
	wire 			reload;
	
ttl_74161 ttl_74161_sound_sp_clock
(
  .Clear_bar	(1'b1),
  .Load_bar		(~reload),
  .ENT			(1'b1),
  .ENP			(1'b1),
  .D				({4'b0111}),
  .Clk			(clk_6),
  .RCO			(reload),
  .Q				(cnt_sound)
);

    TMS5220 TMS5220(
        .I_OSC      (cnt_sound[2]),
        .I_ENA      (sound_reset_n),
        .I_WSn      (pa_out[0]),
        .I_RSn      (pa_out[1]),
        .I_DATA     (1'b1),
        .I_TEST     (1'b1),
        .I_DBUS     (pb_out),
        
        .O_DBUS     (TMS5220_data_out),
        .O_RDYn     (O_RDYn),
        .O_INTn     (),
        .O_SPKR     (O_TMS5220_SPKR)
    );
	
/*********************************************************

    Audio Mixer

*********************************************************/
reg [15:0]	AUDIO_OUT_CIO_0_reg;
reg [15:0]	AUDIO_OUT_CIO_1_reg;
reg [15:0]	AUDIO_OUT_CIO_2_reg;
reg [15:0]	AUDIO_OUT_CIO_3_reg;
reg [15:0]	O_TMS5220_SPKR_reg;

always @(posedge clk_6) begin
	AUDIO_OUT_CIO_0_reg <= AUDIO_OUT_CIO_0 << 7;
	AUDIO_OUT_CIO_1_reg <= AUDIO_OUT_CIO_1 << 7;
	AUDIO_OUT_CIO_2_reg <= AUDIO_OUT_CIO_2 << 7;
	AUDIO_OUT_CIO_3_reg <= AUDIO_OUT_CIO_3 << 7;
	O_TMS5220_SPKR_reg  <= {O_TMS5220_SPKR , 2'b0} & {16{~pa_out[5]}};


end


always @(posedge clk_6)     sound_audio_output <= 
                            AUDIO_OUT_CIO_0_reg +
                            AUDIO_OUT_CIO_1_reg +
                            AUDIO_OUT_CIO_2_reg +
                            AUDIO_OUT_CIO_3_reg +
                            O_TMS5220_SPKR_reg;
    
endmodule
