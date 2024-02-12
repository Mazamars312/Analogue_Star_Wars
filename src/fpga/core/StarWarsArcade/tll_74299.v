`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.05.2023 18:48:32
// Design Name: 
// Module Name: tll_74299
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


module tll_74299(
    input               clk,
    input               S0,
    input               S1,
    input               DS0,
    input               DS7,
    output              QS0,
    output              QS7,
    input               clr_n,
    input      [7:0]    in,
    output reg [7:0]    out  = 0
    );
    
always @(posedge clk or negedge clr_n) begin
    if (!clr_n) out <= 0;
    else begin
        if (S1 == 1 && S0 == 1) out <= in;
        else if (S1 == 1 && S0 == 0) out <= {out[6:0], DS0}; // shift left
        else if (S1 == 0 && S0 == 1) out <= {DS7, out[7:1]}; // shift Right
        else if (S1 == 0 && S0 == 0) out <= out;
    end
end


assign QS0 = out[0];
assign QS7 = out[7];
endmodule
