`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.05.2023 01:30:47
// Design Name: 
// Module Name: starwars_top
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


module starwars_top(

    );
    reg               clk_1_5 = 1;
    reg               clk_3 = 1;
    reg               clk_6 = 1;
    reg               clk_12 = 1;
always @* begin
    #5 clk_12 <= !clk_12;
end  

reg [2:0] clock_counter = 0;
always @(posedge clk_12) begin
    clock_counter <= clock_counter + 1;
    case (clock_counter)
        0 : begin
            clk_3 <= 1;
            clk_1_5 <= 1;
            clk_6 <= 1;
        end
        1 : begin
            clk_3 <= 1;
            clk_1_5 <= 1;
            clk_6 <= 0;
        end
        2 : begin
            clk_3 <= 0;
            clk_1_5 <= 1;
            clk_6 <= 1;
        end
        3 : begin
            clk_3 <= 0;
            clk_1_5 <= 1;
            clk_6 <= 0;
        end
        4 : begin
            clk_3 <= 1;
            clk_1_5 <= 0;
            clk_6 <= 1;
        end
        5 : begin
            clk_3 <= 1;
            clk_1_5 <= 0;
            clk_6 <= 0;
        end
        6 : begin
            clk_3 <= 0;
            clk_1_5 <= 0;
            clk_6 <= 1;
        end
        7 : begin
            clk_3 <= 0;
            clk_1_5 <= 0;
            clk_6 <= 0;
        end
    endcase
    
    
end

reg reset_n;
initial begin
    reset_n <= 1'b1;
    #30 reset_n <= 1'b0;
    #100 reset_n <= 1'b1;
end
    wire [15:0]       main_cpu_address;
    wire [7:0]        main_cpu_data_out;
    wire              main_cpu_RnW;
    
    wire [7:0]         V_data_out;
    wire               VGHALT;
    wire              EVGRES_WR;
    wire              EVGGO_WR;
    
    wire              sound_en_n;
    wire [7:0]        sound_data_out;
    
    
    reg [7:0]         ADC_DATA_OUT = 8'h80;
    wire              ADCSTART0_WR;
    wire              ADCSTART1_WR;
    wire              ADCSTART2_WR;
    
    reg [7:0]         OPT_0_DATA_IN = 8'b1111_1111; 
    reg [7:0]         OPT_1_DATA_IN = 8'b1111_1111;
    reg               LEFT_F_S = 'b1; 
    reg               RIGHT_F_S = 'b1;  
    reg               SELFTEST = 'b0;  
    reg               SLAM = 'b1;  
    reg               COIN_AUX = 'b1;  
    reg               COIN_L = 'b1;  
    reg               COIN_R = 'b1; 
    reg               LEFT_THUMB = 'b1;  
    reg               RIGHT_THUMB = 'b1;  
    reg               DIAGN = 'b1; 
    
    reg [7:0]         AUDIO_OUT_CIO_0_SHIFT = 8'h00;
    reg [7:0]         AUDIO_OUT_CIO_1_SHIFT = 8'h00;
    reg [7:0]         AUDIO_OUT_CIO_2_SHIFT = 8'h00;
    reg [7:0]         AUDIO_OUT_CIO_3_SHIFT = 8'h00;
    reg [7:0]         AUDIO_OUT_SPEECH_SHIFT = 8'h00; 
    
    wire [15:0]   sound_audio_output;   
    
ALU_Top ALU_Top(
    .clk_1_5            (clk_1_5),
    .clk_3              (clk_3),
    .clk_6              (clk_6),
    .clk_12             (clk_12),
    .reset_n            (reset_n),
    .main_cpu_address   (main_cpu_address),
    .main_cpu_data_out  (main_cpu_data_out),
    .main_cpu_RnW       (main_cpu_RnW),
    .V_data_out         (V_data_out),
    .VGHALT             (VGHALT),
    .EVGRES_WR          (EVGRES_WR),
    .EVGGO_WR           (EVGGO_WR),
    .sound_en_n         (sound_en_n),
    .sound_data_out     (sound_data_out),
    .sound_reset_n      (sound_reset_n),
    .ADC_DATA_OUT       (ADC_DATA_OUT),
    .ADCSTART0_WR       (ADCSTART0_WR),
    .ADCSTART1_WR       (ADCSTART1_WR),
    .ADCSTART2_WR       (ADCSTART2_WR),    
    .OPT_0_DATA_IN      (OPT_0_DATA_IN), 
    .OPT_1_DATA_IN      (OPT_1_DATA_IN),
    .LEFT_F_S           (LEFT_F_S), 
    .RIGHT_F_S          (RIGHT_F_S), 
    .SELFTEST           (SELFTEST), 
    .SLAM               (SLAM), 
    .COIN_AUX           (COIN_AUX), 
    .COIN_L             (COIN_L), 
    .COIN_R             (COIN_R),
    .LEFT_THUMB         (LEFT_THUMB), 
    .RIGHT_THUMB        (RIGHT_THUMB), 
    .DIAGN              (DIAGN) 
    );    
    
    
    
sound_top sound_top(
    .clk_1_5            (clk_1_5          ),
    .clk_3              (clk_3            ),
    .clk_6              (clk_6            ),
    .sound_reset_n      (~sound_reset_n   ),
    .sound_en_n         (sound_en_n       ),
    .sound_read_nwrite  (main_cpu_RnW     ),
    .cpu_address        (main_cpu_address ),
    .cpu_data_out       (main_cpu_data_out),
    .sound_data_out     (sound_data_out   ),
    .sound_self_test    (1'b1  ),
    
    .sound_audio_output     (sound_audio_output)
);
    
Vector_board Vector_board(
    .clk_12                 (clk_12           ),
    .clk_3                  (clk_3            ),
    .reset_n                (reset_n          ),
    .main_cpu_address       (main_cpu_address ),
    .main_cpu_data_out      (main_cpu_data_out),
    .main_cpu_RnW           (main_cpu_RnW     ),
    .V_data_out             (V_data_out       ),
    .VGHALT                 (VGHALT           ),
    .EVGRES_WR              (EVGRES_WR        ),
    .EVGGO_WR               (EVGGO_WR         )
    );
    
    wire COINCNTR2_WR       = !main_cpu_RnW && main_cpu_address[15:5] == 'b01000110100 && main_cpu_address[2:0] == 3'b000;
    wire COINCNTR1_WR       = !main_cpu_RnW && main_cpu_address[15:5] == 'b01000110100 && main_cpu_address[2:0] == 3'b001;
    wire LED3_WR            = !main_cpu_RnW && main_cpu_address[15:5] == 'b01000110100 && main_cpu_address[2:0] == 3'b010;
    wire LED2_WR            = !main_cpu_RnW && main_cpu_address[15:5] == 'b01000110100 && main_cpu_address[2:0] == 3'b011;
    wire MPAGE_WR           = !main_cpu_RnW && main_cpu_address[15:5] == 'b01000110100 && main_cpu_address[2:0] == 3'b100;
    wire PRNGCLR_WR         = !main_cpu_RnW && main_cpu_address[15:5] == 'b01000110100 && main_cpu_address[2:0] == 3'b101;
    wire LED1_WR            = !main_cpu_RnW && main_cpu_address[15:5] == 'b01000110100 && main_cpu_address[2:0] == 3'b110;
    wire RECALL_WR          = !main_cpu_RnW && main_cpu_address[15:5] == 'b01000110100 && main_cpu_address[2:0] == 3'b111;
    
//    reg [64:0] address_select;
//    always @* begin
//        casez(main_cpu_address)
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001;
//            16'b0000_1zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0010;
//            16'b0001_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0100;
//            16'b0001_1zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1000;
//            16'b0010_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_0000;
//            16'b0010_1zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0010_0000;
//            16'b0011_zzzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0100_0000;
//            16'h4300                : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1000_0000;
//            16'h4320                : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_0000_0000;
//            16'h4340                : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0010_0000_0000;
//            16'h4360                : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0100_0000_0000;
//            16'h4380                : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1000_0000_0000;
//            16'h4400                : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_0000_0000_0000;
//            16'h4401                : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0010_0000_0000_0000;
//            16'h45zz                : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0100_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1000_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_0000_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0010_0000_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0100_0000_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1000_0000_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_0000_0000_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0010_0000_0000_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0100_0000_0000_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1000_0000_0000_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
//            16'b0000_0zzz_zzzz_zzzz : address_select <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
//        endcase
//    end
    
    
endmodule
