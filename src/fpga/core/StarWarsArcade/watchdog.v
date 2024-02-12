`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.05.2023 17:22:45
// Design Name: 
// Module Name: watchdog
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


module watchdog(
    input   reset_n,
    output  reg reset_int_n,
    input   clk_3,
    input   WDCLR,
    input   WDDIS_N,
    input   IRQCLR,
    output  reg IRQ_N  = 1
    );
    
    
    reg [12:0] counter_int;
    
    wire reset_int_count =  reset_n; //(counter_int == 32'd8192) |
    
    always @(posedge clk_3 or negedge reset_n) begin
        if (~reset_n) begin
            counter_int <= 0;
        end
        else begin
            counter_int <= counter_int + 1;
        end    
    end
	 
	 reg counter_int_reg_12;
    
    always @(posedge clk_3 or negedge reset_int_n) begin
        if (~reset_int_n) begin
            IRQ_N <= 1;
        end
        else begin
				counter_int_reg_12 <= counter_int[12];
            if (IRQCLR) IRQ_N <= 1;
            else if (counter_int[12] && ~counter_int_reg_12) IRQ_N <= 0;
        end
    end
    
    reg [16:0] counter_watch_dog;
    
    wire reset_watchdog = WDCLR || ~reset_n ; // || counter_watch_dog == 32'd24576
    
    always @(posedge clk_3 or posedge reset_watchdog) begin
        if (reset_watchdog) begin
            counter_watch_dog <= 0;
        end
        else begin
             counter_watch_dog <= counter_watch_dog + 1;
        end
    end
    

//    wire reset_process = reset_n ;
//    wire counter_watch_dog_reg = counter_watch_dog == 32'd24575;
    
    always @(posedge clk_3 or negedge reset_n) begin
        if (~reset_n) reset_int_n <= 1'b0;
        else reset_int_n <= reset_int_n <= 1'b1;
    end
    
endmodule
