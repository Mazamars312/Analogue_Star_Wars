`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.05.2023 23:38:21
// Design Name: 
// Module Name: matrix_controller
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


module matrix_controller(
    input               clk_12,
    input               clk_3,
    input               reset_n,
    
    input               MW0_WR,
    input               MW1_WR,
    input               MW2_WR,
    input               MBRAM_WR,
    input [15:0]        CPU_address,
    input [7:0]         CPU_data_in,
    output [7:0]        MBRAM_DATA_OUT,   
    output              MATH_RUN,
    
    input               MACFLAG,
    output              IP8,
    output              LAC,
    output              CLEARACC,
    output              LDC,
    output              LDB,
    output              LDA,
    input [15:0]        MDB_IN,
    output [15:0]       MDB_RAM
);
    
    wire [10:0]     MA_ADDRESS; // this is the matrix
    
    wire [9:0]      MPA;
    wire [15:0]     IP;
    wire [8:0]      BIC;
    wire            MHALT;
    wire            LW;
    
    wire            INCBIC;
    assign          IP8 = IP[8];
    
    matrix_ram matrix_ram (
        .clk_a      (clk_12),
        .address_a  (CPU_address[11:0]),
        .write_a    (MBRAM_WR),
        .data_a     (CPU_data_in),
        .q_a        (MBRAM_DATA_OUT),
        
        .clk_b      (clk_12),
        .address_b  (MA_ADDRESS),
        .write_b    (LW),
        .data_b     (MDB_IN),
        .q_b        (MDB_RAM)
    );
    
    matrix_rom matrix_rom (
        .clk_a      (clk_12),
        .address_a  (MPA),
        .q_a        (IP)
    );
    
    matrix_clock matrix_clock (
        .clk_12         (clk_12),
        .reset_n        (reset_n),  
        .MW0_WR         (MW0_WR),
        .MACFLAG        (MACFLAG),
        .M_HALT         (MHALT),
        .WP             (WP),
        .MATH_RUN       (MATH_RUN)
    );
    
    matrix_processer_address_selector matrix_processer_address_selector (
        .IP     (IP),
        .BIC    (BIC),
        .MA     (MA_ADDRESS)
    );
    
    matrix_instruction_strobe matrix_instruction_strobe (
        .WP             (WP        ), 
        .IP8            (IP[8]       ),
        .IP9            (IP[9]       ),
        .IP10           (IP[10]      ),
        .IP11           (IP[11]      ),
        .IP12           (IP[12]      ),
        .IP13           (IP[13]      ),
        .IP14           (IP[14]      ),
        .IP15           (IP[15]      ),
        .LW             (LW      ),
        .LAC            (LAC     ),
        .MHALT          (MHALT   ),
        .INCBIC         (INCBIC  ),
        .CLEARACC       (CLEARACC),
        .LDC            (LDC     ),
        .LDB            (LDB     ),
        .LDA            (LDA     )
    );
    
    
    matrix_processer_address_counter matrix_processer_address_counter (
        .clk            (clk_12),
        .reset_n        (reset_n), 
        .MW0_WR         (MW0_WR),
        .cpu_write_data (CPU_data_in),  
        .WP             (WP),
        .MPA            (MPA)
    );
    
    matrix_block_index matrix_block_index ( 
        .clk            (clk_12),
        .reset_n        (reset_n), 
        .MW1_WR         (MW1_WR),
        .MW2_WR         (MW2_WR),
        .INCBIC         (INCBIC),
        .cpu_write_data (CPU_data_in),               
        .BIC            (BIC)
    );
    
endmodule


module matrix_block_index ( 
    input               clk,
    input               reset_n,
    input               MW1_WR,
    input               MW2_WR,
    input               INCBIC,
    input [7:0]         cpu_write_data,               
    output reg [8:0]    BIC = 0
);

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        BIC <= 9'b0;
    end
    else begin
        if (INCBIC) BIC <= BIC +1;
        else if (MW2_WR) BIC[7:0] <= cpu_write_data; 
        else if (MW1_WR) BIC[8] <= cpu_write_data[1];  
    end
end

endmodule

module matrix_processer_address_counter (
    input               clk,
    input               reset_n,
    input               MW0_WR,
    input [7:0]         cpu_write_data,  
    input               WP,
                 
    output reg [9:0]    MPA
);

always @(posedge clk or negedge reset_n) begin
    if (~reset_n) begin
        MPA = 0;
    end
    else begin
        if (MW0_WR) begin
            MPA[9] <= cpu_write_data[7];
            MPA[8] <= cpu_write_data[6];
            {MPA[7:0]} <= {cpu_write_data[5:0], 2'b00};
        end
        if (WP) begin
            {MPA[7:0]} <= {MPA[7:0]} + 1;
        end
    end
end

endmodule

module matrix_instruction_strobe (

    input               WP, 
    input               IP8,
    input               IP9,
    input               IP10,
    input               IP11,
    input               IP12,
    input               IP13,
    input               IP14,
    input               IP15,
                 
    output              LW,
    output              LAC,
    output              MHALT,
    output              INCBIC,
    output              CLEARACC,
    output              LDC,
    output              LDB,
    output              LDA
);


assign LAC        = &{IP8, WP};
assign LW         = &{IP9, WP};
assign MHALT      = &{IP10, WP};
assign INCBIC     = &{IP11, WP};
assign CLEARACC   = &{IP12, WP};
assign LDC        = &{IP13, WP};
assign LDB        = &{IP14, WP};
assign LDA        = &{IP15, WP};

endmodule

module matrix_processer_address_selector (

    input [7:0]  IP,
    input [8:0]  BIC,
    output reg [10:0] MA
);

always @* begin
    MA[10:7] <= BIC[8:5];
    MA[6] <= IP[7] ? IP[6] : BIC[4];
    MA[5] <= IP[7] ? IP[5] : BIC[3];
    MA[4] <= IP[7] ? IP[4] : BIC[2];    
    MA[3] <= IP[7] ? IP[3] : BIC[1];    
    MA[2] <= IP[7] ? IP[2] : BIC[0];
    MA[1:0] <= IP[1:0];
end

endmodule


module matrix_clock (
    input               clk_12,  
    input               reset_n,
    input               MW0_WR,
    input               MACFLAG,
    input               M_HALT,
    
    output              WP,
    output reg          MATH_RUN
);



reg [7:0] internal_counter = 0;
reg MATH_RUN_REG;
reg WR_REG;

always @(posedge clk_12 or negedge reset_n) begin
    if (~reset_n) begin
        internal_counter <= 0;
        MATH_RUN_REG <= 0;
    end
    else begin
        WR_REG <= 0;
        if (MATH_RUN && MACFLAG && ~M_HALT) begin
            internal_counter <= internal_counter + 1;
            if (internal_counter == 3) begin
                WR_REG <= 1;
                internal_counter <= 0;
            end
        end
    end
end

reg MW0_WR_reg;
reg M_HALT_reg;
always @(posedge clk_12 or negedge reset_n) begin
    if (~reset_n) begin
        MATH_RUN <= 0;
        MW0_WR_reg <= 0;
        M_HALT_reg <= 0;
    end
    else begin
        MW0_WR_reg <= MW0_WR;
        M_HALT_reg <= M_HALT;
        if (~MW0_WR && MW0_WR_reg) MATH_RUN <= 1;
        else if (M_HALT && ~M_HALT_reg) MATH_RUN <= 0;
    end
end

assign WP = &{MATH_RUN, WR_REG, MACFLAG};

endmodule


module matrix_ram (
    input               clk_a,    
    input [11:0]        address_a, 
    input               write_a,   
    input [7:0]         data_a,    
    output [7:0]    		q_a,       
    
    input               clk_b,    
    input [10:0]        address_b, 
    input               write_b,   
    input [15:0]        data_b,    
    output [15:0]   		q_b
    
);

//reg [7:0] memory0 [2047:0];
//reg [7:0] memory1 [2047:0];


//integer k;
//initial
//begin
//for (k = 0; k < 2048; k = k + 1)
//begin
//    memory0[k] = 'b0;
//    memory1[k] = 'b0;
////    mem[k+1] = 8'b11011101;
//end
//end

wire [15:0] data_a_out;

Matrix_ram_intel Matrix_ram_intel (
	.clock_a		(clk_a),
	.address_a	    (address_a[11:1]),
	.byteena_a	    ({address_a[0], ~address_a[0]}),
	.wren_a		    (write_a),
	.data_a		    ({2{data_a}}),
	.q_a				(data_a_out),
	.clock_b			(clk_b),
	.address_b	    (address_b[10:0]),
	.data_b		    (data_b),
	.wren_b		    (write_b),
	.q_b			(q_b));
	
assign q_a = address_a[0] ? data_a_out[15:8] : data_a_out[7:0];

//always @(posedge clk_a) begin
//    if (write_a && ~address_a[0]) memory[address_a[11:1]][ 7:0] <= data_a;
//    if (write_a &&  address_a[0]) memory[address_a[11:1]][15:8] <= data_a; 
//    q_a <= ~address_a[0] ? memory[address_a[11:1]][ 7:0] : memory[address_a[11:1]][15:8];
//end
//
//always @(posedge clk_b) begin
//    if (write_b) memory[address_b][ 7:0] <= data_b[7:0];
//    if (write_b) memory[address_b][15:8] <= data_b[15:8]; 
//    q_b <= memory[address_b];
//end

endmodule
