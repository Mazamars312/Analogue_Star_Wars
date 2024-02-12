`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.05.2023 15:15:44
// Design Name: 
// Module Name: ALU_Top
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


module ALU_Top(
    input               clk_1_5,
    input               clk_3,
    input               clk_6,
    input               clk_12,
    input               reset_n,
    
    output [15:0]       main_cpu_address,
    output [7:0]        main_cpu_data_out,
    output              main_cpu_RnW,
//    
//    input [7:0]         V_data_out,
//    input               VGHALT,
//    output              EVGRES_WR,
//    output              EVGGO_WR,
    
    input [7:0]         sound_data_out,
    output              sound_reset_n,
    
    input [7:0]         ADC_DATA_OUT,
    output              ADCSTART0_WR,
    output              ADCSTART1_WR,
    output              ADCSTART2_WR,
    
    input [7:0]         OPT_0_DATA_IN, 
    input [7:0]         OPT_1_DATA_IN,
    input               LEFT_F_S, 
    input               RIGHT_F_S, 
    input               SELFTEST, 
    input               SLAM, 
    input               COIN_AUX, 
    input               COIN_L, 
    input               COIN_R,
    input               LEFT_THUMB, 
    input               RIGHT_THUMB, 
    input               DIAGN,
	 
    output reg 			LED3,      
    output reg 			LED2,    
    output reg 			LED1,

	 input 					clk_mpu, 
	 input [31:0]			mpu_address,
	 input 					mpu_write,
	 input [3:0]			mpu_mask,
	 input 					mpu_request,
	 input [31:0]			mpu_data_out,
	 output reg [31:0]	mpu_data_in
    );
    
    reg [7:0]   main_cpu_data_in;
    wire        IRQ_N;
	 reg 			 VGHALT;
	 
	 wire vram_write			 = clk_1_5 && !main_cpu_RnW && |{main_cpu_address[15:12] == 4'h0, main_cpu_address[15:12] == 4'h1, main_cpu_address[15:12] == 4'h2};
    wire NOVRAM_WR          = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:8] == 8'b01000101;
    assign EVGGO_WR         = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:5] == 11'b01000110000;
    assign EVGRES_WR        = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:5] == 11'b01000110001;
    wire WDCLR_WR           = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:5] == 11'b01000110010;
    wire IRQCLR_WR          = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:5] == 11'b01000110011;
    
    wire COINCNTR2_WR       = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:5] == 11'b01000110100 && main_cpu_address[2:0] == 3'b000;
    wire COINCNTR1_WR       = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:5] == 11'b01000110100 && main_cpu_address[2:0] == 3'b001;
    wire LED3_WR            = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:5] == 11'b01000110100 && main_cpu_address[2:0] == 3'b010;
    wire LED2_WR            = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:5] == 11'b01000110100 && main_cpu_address[2:0] == 3'b011;
    wire MPAGE_WR           = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:5] == 11'b01000110100 && main_cpu_address[2:0] == 3'b100;
    wire PRNGCLR_WR         = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:5] == 11'b01000110100 && main_cpu_address[2:0] == 3'b101;
    wire LED1_WR            = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:5] == 11'b01000110100 && main_cpu_address[2:0] == 3'b110;
    wire RECALL_WR          = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:5] == 11'b01000110100 && main_cpu_address[2:0] == 3'b111;

    wire NSTORE_WR          = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:5] == 11'b01000110101;
    
    assign ADCSTART0_WR     = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:0] == 16'h4700;
    assign ADCSTART1_WR     = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:0] == 16'h4701;
    assign ADCSTART2_WR     = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:0] == 16'h4702;
    
    assign sound_reset_n    = !(clk_1_5 && !main_cpu_RnW && main_cpu_address[15:5] == 11'b01000110111); 
    
    // 0x47zz
    wire MW0_WR             = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:0] == 16'h4700;
    wire MW1_WR             = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:0] == 16'h4701;
    wire MW2_WR             = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:0] == 16'h4702;
    wire PRNG_WR            = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:0] == 16'h4703;
    wire DVSRH_WR           = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:0] == 16'h4704;
    wire DVSRL_WR           = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:0] == 16'h4705;
    wire DVDDH_WR           = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:0] == 16'h4706;
    wire DVDDL_WR           = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:0] == 16'h4707;
    // Main Ram
    wire RAM_WR             = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:11]== 5'b01001;
    // Matrix Ram
    wire MBRAM_WR           = clk_1_5 && !main_cpu_RnW && main_cpu_address[15:12]== 4'b0101;
    // External Controlls
    
    wire MATH_RUN;
//    wire [7:0] OPT_0_DATA_OUT;
//    wire [7:0] OPT_1_DATA_OUT;
    wire [3:0] NOVRAM_DATA_OUT;
    wire [7:0] REH_DATA_OUT, REL_DATA_OUT;
    reg  [7:0] PRNG_DATA_OUT;
    wire [7:0] RAM_DATA_OUT;
    wire [7:0] MBRAM_DATA_OUT;
    wire [7:0] ROM0_DATA_OUT;
    wire [7:0] ROM1_DATA_OUT;
    wire [7:0] ROM2_DATA_OUT;
    wire [7:0] ROM3_DATA_OUT;
    wire [7:0] ROM4_DATA_OUT;
	 wire [7:0] cpu_vram_data_out;
	 wire [7:0] cpu_vrom_data_out;
	 
	 reg [7:0]	main_cpu_data_in_rom;
	 reg [7:0]	main_ram_wire;
	 reg [7:0]  feactures_wire;
	 reg [7:0]	devide_memory;
	 reg [7:0]	options_memory;

	 
	 always @* begin
        casez(main_cpu_address[7:4])
            4'h0,
				4'h1		: options_memory <= {~LEFT_F_S, ~RIGHT_F_S, 1'b1, ~SELFTEST, ~SLAM, ~COIN_AUX, ~COIN_L, ~COIN_R};
				4'h2,
            4'h3 		: options_memory <= {MATH_RUN,   VGHALT, ~LEFT_THUMB, ~RIGHT_THUMB, 1'b1, ~DIAGN, 1'b1, 1'b1};
				4'h4,
            4'h5  	: options_memory <= ~OPT_0_DATA_IN;
				4'h6,
            4'h7  	: options_memory <= ~OPT_1_DATA_IN;
            default  : options_memory <= ADC_DATA_OUT;
        endcase
    end
	 
	 always @* begin
        casez(main_cpu_address[2:0])
            3'b000 	: devide_memory <= REH_DATA_OUT;
            3'b001 	: devide_memory <= REL_DATA_OUT;
            default  : devide_memory <= PRNG_DATA_OUT;
        endcase
    end
	 
	 always @* begin
        casez(main_cpu_address[11:8])
            4'h3 		: feactures_wire <= options_memory;
            4'h4 		: feactures_wire <= sound_data_out;
            4'h5 		: feactures_wire <= {4'b0, NOVRAM_DATA_OUT};
            4'h7 		: feactures_wire <= devide_memory;
            default	: feactures_wire <= RAM_DATA_OUT;
        endcase
    end

	 always @* begin
        casez(main_cpu_address[15:12])
            4'h0,
				4'h1,
				4'h2		: main_cpu_data_in <= cpu_vram_data_out;
				4'h3 		: main_cpu_data_in <= cpu_vrom_data_out;
            4'h4 		: main_cpu_data_in <= feactures_wire;
            4'h5 		: main_cpu_data_in <= MBRAM_DATA_OUT;
				4'h6,
				4'h7		: main_cpu_data_in <= ROM0_DATA_OUT;
				4'h8,
            4'h9 		: main_cpu_data_in <= ROM1_DATA_OUT;
				4'hA,
            4'hB 		: main_cpu_data_in <= ROM2_DATA_OUT;
				4'hC,
            4'hD 		: main_cpu_data_in <= ROM3_DATA_OUT;
				4'hE,
            4'hF 		: main_cpu_data_in <= ROM4_DATA_OUT;
            default  : main_cpu_data_in <= 8'h00;
        endcase
    end
 
// CPU Perfs that are external ( Test and Control Signals 8A
    reg COINCNTR2; 
    reg COINCNTR1; 
    reg MPAGE;     
    reg PRNGCLR;     
    reg RECALL;    
    
    always @(posedge clk_12 or negedge reset_n) begin
        if (~reset_n) begin
            COINCNTR2   <= 0;
            COINCNTR1   <= 0;
            LED3        <= 0;
            LED2        <= 0;
            MPAGE       <= 0;
            PRNGCLR     <= 0;
            LED1        <= 0;    
            RECALL      <= 0;
        end
        else begin
            if (COINCNTR2_WR)   COINCNTR2   <= main_cpu_data_out[7];
            if (COINCNTR1_WR)   COINCNTR1   <= main_cpu_data_out[7];
            if (LED3_WR     )   LED3        <= main_cpu_data_out[7];
            if (LED2_WR     )   LED2        <= main_cpu_data_out[7];
            if (MPAGE_WR    )   MPAGE       <= main_cpu_data_out[7];
            if (PRNGCLR_WR  )   PRNGCLR     <= main_cpu_data_out[7];
            if (LED1_WR     )   LED1        <= main_cpu_data_out[7];
            if (RECALL_WR   )   RECALL      <= main_cpu_data_out[7];
        end
    end 
 
 
   
    // CPU Page 7A
    
mc6809e mc6809e(
    .D      (main_cpu_data_in),
    .DOut   (main_cpu_data_out),
    .ADDR   (main_cpu_address),
    .RnW    (main_cpu_RnW),
    .E      (clk_1_5),
    .Q      (clk_3),
    .nIRQ   (IRQ_N),
    .nFIRQ  (1'b1),
    .nNMI   (1'b1),
    .nHALT  (1'b1),	 
    .nRESET (reset_int_n)
);

//. Watchdog timer and Interrupt unit Page 7A
watchdog watchdog (
    .reset_n        (reset_n),
    .reset_int_n    (reset_int_n),
    .clk_3          (clk_3),
    .WDCLR          (WDCLR_WR),
    .WDDIS_N        (1'b1),
    .IRQCLR         (IRQCLR_WR),
    .IRQ_N          (IRQ_N)
);


    // CPU Ram ( Page B7
CPU_RAM CPU_RAM(
    .clk			(clk_12),
    .address	(main_cpu_address[10:0]),
    .write		(RAM_WR ),
    .data		(main_cpu_data_out),
    .q			(RAM_DATA_OUT)
    );

    // Bankswitch ROM block 0 Page B7
CPU_program_rom_0 CPU_program_rom_0(
    .clk        (clk_12),
    .address    ({MPAGE, main_cpu_address[12:0]}),
    .data       (ROM0_DATA_OUT)
    ); 
    // Rom Block 1 Page B7
CPU_program_rom_1 CPU_program_rom_1(
    .clk        (clk_12),
    .address    (main_cpu_address[12:0]),
    .data       (ROM1_DATA_OUT)
    );  
    
// Rom Block 1 Page B7
CPU_program_rom_2 CPU_program_rom_2(
    .clk        (clk_12),
    .address    (main_cpu_address[12:0]),
    .data       (ROM2_DATA_OUT)
    );  
    
// Rom Block 1 Page B7
CPU_program_rom_3 CPU_program_rom_3(
    .clk        (clk_12),
    .address    (main_cpu_address[12:0]),
    .data       (ROM3_DATA_OUT)
    );  
    
// Rom Block 1 Page B7
CPU_program_rom_4 CPU_program_rom_4(
    .clk        (clk_12),
    .address    (main_cpu_address[12:0]),
    .data       (ROM4_DATA_OUT)
    );  
    // Save memory Page B7
CPU_NVRAM CPU_NVRAM(
    .clk		(clk_12),
    .address	(main_cpu_address[7:0]),
    .write		(NOVRAM_WR),
    .data		(main_cpu_data_out[3:0]),
    .q			(NOVRAM_DATA_OUT)
    ); 
	 
	reg EVGRES_WR_REG, EVGGO_WR_REG, mpu_request_reg;
	
	reg address_00;
	reg address_01;
	reg address_02;
	reg address_03;
	
	reg mpu_write_VRAM;
	reg mpu_write_VROM;
	
	always @* begin
		address_00 <= (mpu_address[31:16] == 20'h8000 && mpu_address[15:12] == 4'h0);
		address_01 <= (mpu_address[31:16] == 20'h8000 && mpu_address[15:12] == 4'h1);
		address_02 <= (mpu_address[31:16] == 20'h8000 && mpu_address[15:12] == 4'h2);
		address_03 <= (mpu_address[31:16] == 20'h8000 && mpu_address[15:12] == 4'h3);
	end
	
	always @(posedge clk_mpu) begin
		mpu_write_VRAM <= |{address_00, address_01, address_02} && mpu_write && mpu_request_reg;
		mpu_write_VROM <=   address_03 && mpu_write && mpu_request_reg;
		mpu_request_reg <= mpu_request;
	end
	
	

	
	wire EVGGO_WR_wire;
	wire EVGRES_WR_wire;
	
	synch_3 s02(EVGGO_WR, EVGGO_WR_wire, clk_mpu);
	synch_3 s03(EVGRES_WR, EVGRES_WR_wire, clk_mpu);
	
	always @(posedge clk_mpu or negedge reset_n) begin
		if (~reset_n) begin
			EVGRES_WR_REG	<=0; 
			EVGGO_WR_REG	<=0;
			VGHALT			<=0;
		end
		else begin
		
			EVGRES_WR_REG	<= EVGRES_WR_wire; 
			EVGGO_WR_REG	<= EVGGO_WR_wire;
			if (mpu_address[23:0] == 24'h00_4000 && mpu_request_reg && mpu_request) VGHALT <= mpu_data_out[0];
			else begin
				if (EVGRES_WR_wire && ~EVGRES_WR_REG) begin
					VGHALT	<= 1;
				end
				if (EVGGO_WR_wire && ~EVGGO_WR_REG) begin
					VGHALT	<= 0;
				end
			end
		
		end
	end
	 
	 wire [31:0] mpu_vrom_data_out, mpu_vram_data_out;
    
	VRAM VRAM(
	.clk_a		(clk_12),
	.address_a	(main_cpu_address[13:0]),
	.write_a		(vram_write),
	.data_a		(main_cpu_data_out),
	.q_a			(cpu_vram_data_out),

	.clk_b		(clk_mpu),
	.address_b	(mpu_address[13:2]),
	.write_b		(mpu_write_VRAM),
	.mask_b		(mpu_mask),
	.data_b		({mpu_data_out[7:0], mpu_data_out[15:8], mpu_data_out[23:16],mpu_data_out[31:24]}),
	.q_b			(mpu_vram_data_out),

	);
 
 
	VROM VROM(
	.clk_a		(clk_12),
	.address_a	(main_cpu_address[11:0]),
	.q_a			(cpu_vrom_data_out),

	.clk_b		(clk_mpu),
	.address_b	(mpu_address[11:2]),
	.write_b		(1'b0),
	.mask_b		(mpu_mask),
	.data_b		({mpu_data_out[7:0], mpu_data_out[15:8], mpu_data_out[23:16],mpu_data_out[31:24]}),
	.q_b			(mpu_vrom_data_out),
	);
   
	always @* begin
		casez(mpu_address[23:0])
			'h004zzz : mpu_data_in <= {VGHALT};
			'h003zzz : mpu_data_in <= {mpu_vrom_data_out[7:0], mpu_vrom_data_out[15:8], mpu_vrom_data_out[23:16],mpu_vrom_data_out[31:24]};
			default 	: mpu_data_in <= {mpu_vram_data_out[7:0], mpu_vram_data_out[15:8], mpu_vram_data_out[23:16],mpu_vram_data_out[31:24]};
		endcase
	end
	
// Pseudo-random Number Gen page 8B

//clk_3
//PRNGCLR
//PRNG_DATA_OUT
//main_cpu_data_out
reg [23:0] pseudo_counter = 0;

always @(posedge clk_3 or negedge reset_n) begin
    if (!reset_n) begin
        pseudo_counter <= 24'hffffff;
    end
    else begin
        if (~PRNGCLR)  pseudo_counter <= {8'hff, 8'hff, 8'hff};
        else pseudo_counter <= {pseudo_counter[22:0], pseudo_counter[5] ^ pseudo_counter[22]};
        PRNG_DATA_OUT <= pseudo_counter[15:8];
    end
end

// Divider unit

divider_core divider_core(
    .clk_6          (clk_6),
    .reset_n        (reset_n),
    .DVSRH_WR       (DVSRH_WR),
    .DVSRL_WR       (DVSRL_WR),
    .DVDDH_WR       (DVDDH_WR),
    .DVDDL_WR       (DVDDL_WR),
    .cpu_data_in    (main_cpu_data_out),
    .REH_DATA_OUT   (REH_DATA_OUT),
    .REL_DATA_OUT   (REL_DATA_OUT)
    );

// Logic latch

matrix_processer matrix_processer(
    .clk_12             (clk_12),
    .clk_3              (clk_3),
    .reset_n            (reset_n),
    .MW0_WR             (MW0_WR),
    .MW1_WR             (MW1_WR),
    .MW2_WR             (MW2_WR),
    .MBRAM_WR           (MBRAM_WR),
    .CPU_address        (main_cpu_address),
    .CPU_data_in        (main_cpu_data_out),
    .MBRAM_DATA_OUT     (MBRAM_DATA_OUT),   
    .MATH_RUN           (MATH_RUN)
    );


endmodule


