`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 30.01.2024 15:07:43
// Design Name: 
// Module Name: linebuffer_draw
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

module linedraw (
  input go,
  input reset_l,
  output busy,
  input wrready,
  input [9:0] stax,
  input [9:0] stay,
  input [9:0] endx,
  input [9:0] endy,
  output wr,
  output [9:0] addr_x,
  output [9:0] addr_y,
  input pclk
  );

parameter [3:0] IDLE = 4'd0;
parameter [3:0] RUN = 4'd1;
parameter [3:0] RUN_DOT = 4'd2;
parameter [3:0] RUN_H_STRAIGHT = 4'd3;
parameter [3:0] RUN_V_STRAIGHT = 4'd4;
parameter [3:0] RUN_ANGLE_SETUP1 = 4'd5;
parameter [3:0] RUN_ANGLE_SETUP2 = 4'd6;
parameter [3:0] RUN_ANGLE_SETUP3 = 4'd7;
parameter [3:0] RUN_ANGLE_DRAW = 4'd8;
parameter [3:0] RUN_ANGLE_DRAW_STRAGHT = 4'd9;
parameter [3:0] DONE = 4'd10;

reg  [3:0]      state = 0;
reg  [3:0]      state_c = 0;
reg  [9:0]      x = 0, y = 0;
reg  [9:0]      x1 = 0, y1 = 0;
reg  [9:0]      x2 = 0, y2 = 0;
reg  [10:0]     px;
reg  [10:0]     py;
wire [9:0]      next_y, next_x;
reg  [10:0]     dx, dy;
reg             right, down;
wire            in_line;
reg             in_loop;
reg             in_setup;

reg     [10:0]   right_reg;
reg     [10:0]   down_reg;
reg             d_direction;
reg             d_equal;
wire            d_add;

wire complete   = ( (x2 == x1) && (y2 == y1) );
wire same_x     = stax == endx;
wire same_y     = stay == endy;

always @(posedge pclk or negedge reset_l) begin
    if (!reset_l) begin
        in_loop         <= 0;
        state_c         <= 0;
        x1              <= 0;
        y1              <= 0;
        x2              <= 0;
        y2              <= 0;
        right           <= 0;
        down            <= 0;
        px              <= 0;
        py              <= 0;
        dx              <= 0;
        dy              <= 0;
        d_direction     <= 0;
        in_setup        <= 0;
        d_equal         <= 0;
    end
    else begin
        in_loop <= 0;
        in_setup <= 0;
        case (state_c)
            IDLE : begin 
                if (go) begin
                    if (same_x) begin
                        state_c <= RUN_H_STRAIGHT; 
                        in_loop <= 1;
                    end
                    else if (same_y) begin
                        state_c <= RUN_V_STRAIGHT; 
                        in_loop <= 1;
                    end
                    else if (same_y && same_x) begin
                        state_c <= RUN_DOT; 
                        in_loop <= 1;
                    end
                    else begin
                        state_c <= RUN_ANGLE_SETUP1;
                        in_setup <= 1;
                    end
                end
                else begin
                    state_c <= IDLE;
                end
                x1 <= stax;
                y1 <= stay;
                x2 <= endx;
                y2 <= endy;
                right <= endx <= stax;//~right_wire[9];
                down  <= endy <= stay;//~down_wire[9];
            end
            RUN :   
                if (complete) begin
                state_c   <= DONE;
                end
            RUN_H_STRAIGHT : begin 
                in_loop <= 1;
                if (wrready) y1 <= down ? y1 - 1 : y1 + 1;
                if (complete && wrready) begin
                    state_c   <= DONE;
                end
            end
            RUN_V_STRAIGHT : begin 
                in_loop <= 1;
                if (wrready) x1 <= right ? x1 - 1 : x1 + 1;
                if (complete && wrready) begin
                    state_c   <= DONE;
                end
            end
            RUN_DOT : begin 
                in_loop <= 1;
                if (wrready) begin
                    state_c   <= DONE;
                end
            end
            RUN_ANGLE_SETUP1 : begin
                in_setup <= 1;
                down_reg    <= y2 - y1;
                right_reg   <= x2 - x1;
                state_c     <= RUN_ANGLE_SETUP2;
            end
            RUN_ANGLE_SETUP2 : begin
                in_setup <= 1;
                state_c   <= RUN_ANGLE_SETUP3;
                dx <= right_reg[10] ? -right_reg: right_reg;
                dy <= down_reg[10]  ? -down_reg : down_reg;
            end
            RUN_ANGLE_SETUP3 : begin
                in_setup <= 1;
                if ((dy == dx) || (!(dy + 1) == !(dx + 1))) state_c   <= RUN_ANGLE_DRAW_STRAGHT; 
                else state_c   <= RUN_ANGLE_DRAW;
//                state_c   <= RUN_ANGLE_DRAW;
                px      <= px[10:0] + (2*(dy-dx));
                py      <= py[10:0] + (2*(dx-dy));
            end
            RUN_ANGLE_DRAW : begin
                in_loop <= 1;
                if (wrready) x1     <= ~d_direction ? next_x : ~right ? (x1 + in_loop) : (x1 - in_loop);
                if (wrready) y1     <=  d_direction ? next_y : ~down  ? (y1 + in_loop) : (y1 - in_loop);
                if (wrready) px     <= px[10] ? px[10:0] + (2*(dy-dx)) : px + (2 * dy);
                if (wrready) py     <= py[10] ? py[10:0] + (2*(dx-dy)) : py + (2 * dx);
                if (|{d_direction && (x1 == x2), ~d_direction && (y1 == y2)} && wrready) begin
                    state_c   <= DONE;
                end
            end
            RUN_ANGLE_DRAW_STRAGHT : begin
                in_loop <= 1;
                if (wrready) x1     <= ~right ? (x1 + in_loop) : (x1 - in_loop);
                if (wrready) y1     <= ~down  ? (y1 + in_loop) : (y1 - in_loop);
                if ((x1 == x2) && wrready) begin
                    state_c   <= DONE;
                end
            end
            default : begin
                state_c   <= IDLE;
            end
        endcase
    end
 end

assign next_x = ~right ? (x1 + py[10]) : (x1 - py[10]);
assign next_y = ~down  ? (y1 + px[10]) : (y1 - px[10]);

assign busy = in_loop || in_setup;
assign wr = in_loop && wrready;
assign addr_x = x1;
assign addr_y = y1;

endmodule