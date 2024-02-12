`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.05.2023 00:27:36
// Design Name: 
// Module Name: matrix_processer
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


module matrix_processer(
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
    output              MATH_RUN
    );
    
    reg                 MACFLAG;
    wire                IP8;
    wire                LAC;
    wire                CLEARACC;
    wire                LDC;
    wire                LDB;
    wire                LDA;
    reg  [31:0]         MDB_IN;
    wire [15:0]         MDB_RAM;

    reg [15:0] register_a = 0;
    reg [15:0] register_b = 0; 
    reg [15:0] register_c = 0;   
    
    reg MACFLAG_REG;

    always @(posedge clk_12 or negedge reset_n) begin
        if (~reset_n) MACFLAG_REG <= 'b1;
        else begin
            MACFLAG_REG <= MACFLAG;
        end
    end

    always @(posedge clk_12 or negedge reset_n) begin
        if (~reset_n) register_a <= 'b0;
        else begin
            if (LDA) register_a <= MDB_RAM;
            else if (register_a[15] && ~MACFLAG_REG && MACFLAG) register_a <= 16'hFFFF;
        end
    end

    always @(posedge clk_12 or negedge reset_n) begin
        if (~reset_n) register_b <= 'b0;
        else begin
            if (LDB) register_b <= MDB_RAM;
            else if (register_b[15] && ~MACFLAG_REG && MACFLAG) register_b <= 16'hFFFF;
        end
    end

    always @(posedge clk_12 or negedge reset_n) begin
        if (~reset_n) register_c <= 'b0;
        else begin
            if (LDC) register_c <= MDB_RAM;
        end
    end

    reg [31:0] register_a_b = 0;
    reg [31:0] register_a_b_c = 0;
    reg [31:0] register_a_b_c_final = 0;
    always @(posedge clk_12) begin
        register_a_b            <= {{16{register_a[15]}},register_a} - {{16{register_b[15]}},register_b};
        register_a_b_c          <= {{16{register_c[15]}},register_c} * {register_a_b};
        register_a_b_c_final    <= register_a_b_c + 1;
    end

    always @(posedge clk_12 or negedge reset_n) begin
        if (~reset_n) MDB_IN <= 'b0;
        else begin
            if      (CLEARACC)  MDB_IN <= 'b0;
            else if (IP8) MDB_IN <= {MDB_RAM, 16'd0};
            else if (MACFLAG && ~MACFLAG_REG) MDB_IN <= {register_a_b_c_final[29:0],2'd0} + MDB_IN;
        end
    end

    reg [4:0]   counter;
    reg         LDC_REG;
    
    always @(posedge clk_12 or negedge reset_n) begin
        if (~reset_n) begin 
            counter <= 'b11111;
            MACFLAG <= 1'b1;
            LDC_REG <= 1'b1;
        end
        else begin
            LDC_REG <= LDC;
            if (LDC && ~LDC_REG) begin
                counter <= 0;
                MACFLAG <= 1'b0;
            end
            else if (&counter) begin
                MACFLAG <= 1'b1;
            end
            else counter <= counter + 1;
        end
    end

    matrix_controller matrix_controller(
        .clk_12             (clk_12),
        .clk_3              (clk_3),
        .reset_n            (reset_n),
        .MW0_WR             (MW0_WR),
        .MW1_WR             (MW1_WR),
        .MW2_WR             (MW2_WR),
        .MBRAM_WR           (MBRAM_WR),
        .CPU_address        (CPU_address),
        .CPU_data_in        (CPU_data_in),
        .MBRAM_DATA_OUT     (MBRAM_DATA_OUT),   
        .MATH_RUN           (MATH_RUN),
        .IP8                (IP8),
        .MACFLAG            (MACFLAG ),
        .LAC                (LAC     ),
        .CLEARACC           (CLEARACC),
        .LDC                (LDC     ),
        .LDB                (LDB     ),
        .LDA                (LDA     ),
        .MDB_IN             (MDB_IN[31:16]),
        .MDB_RAM            (MDB_RAM   )
    );
    
endmodule



