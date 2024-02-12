`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.05.2023 18:30:25
// Design Name: 
// Module Name: ttl_74164
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


module ttl_74164(
    input               clk,
    input               A,
    input               B,
    input               clr_n,
    output reg [7:0]    out  = 0
    );
    
always @(posedge clk or negedge clr_n) begin
    if (!clr_n) out <= 'h0;
    else begin
        out[0] <= A && B;
        out[1] <= out[0];
        out[2] <= out[1];
        out[3] <= out[2];
        out[4] <= out[3];
        out[5] <= out[4];
        out[6] <= out[5];
        out[7] <= out[6];
    end
end
endmodule
