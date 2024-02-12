`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.05.2023 21:46:45
// Design Name: 
// Module Name: divider_core
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


module divider_core(
    input               clk_6,
    input               reset_n,
    input               DVSRH_WR,
    input               DVSRL_WR,
    input               DVDDH_WR,
    input               DVDDL_WR,
    
    input  [7:0]        cpu_data_in,
    
    output [7:0]    REH_DATA_OUT,
    output [7:0]    REL_DATA_OUT
    
    );


reg [7:0]   DVSRH = 0;
reg [7:0]   DVSRL = 0;
reg [7:0]   DVDDH = 0;
reg [7:0]   DVDDL = 0;

always @(posedge clk_6 or negedge reset_n) begin
    if (!reset_n) begin
        DVSRH <=0;
        DVSRL <=0;
        DVDDH <=0;
        DVDDL <=0;
    end
    else begin
        if(DVSRH_WR) DVSRH <= cpu_data_in;
        if(DVSRL_WR) DVSRL <= cpu_data_in;
        if(DVDDH_WR) DVDDH <= cpu_data_in;
        if(DVDDL_WR) DVDDL <= cpu_data_in;
    end
end

reg [7:0]   counter;
reg         DVSRL_WR_REG;
reg         REN = 0;
reg         SREN = 0;

parameter timing = 32'd33;

always @(posedge clk_6 or negedge reset_n) begin
    if (~reset_n) begin
        counter <= timing;
        REN     <= 0;
        DVSRL_WR_REG <= 0;
        SREN <= 0;
    end
    else begin
        DVSRL_WR_REG <= DVSRL_WR;
        SREN <= 0;
        if (~DVSRL_WR && DVSRL_WR_REG) begin
            counter <= 1;
            REN     <= 0;
            SREN    <= 1;
        end
        else if (counter < timing) begin  
            counter <= counter + 1;
            REN     <= 1;        
        end 
        else begin 
            REN     <= 0; 
        end   
    end
end

reg [15:0]  m_dvd_shift;
reg [15:0]  m_divisor;
wire         overflow;
reg         div_fake;
reg [15:0]  m_quotient_shift;
wire [15:0] sum;

assign {REH_DATA_OUT, REL_DATA_OUT} = m_quotient_shift; 

assign {overflow, sum} = m_dvd_shift + (m_divisor ^ 16'hffff) + 1;

always @(posedge clk_6 or negedge reset_n) begin
    if (~reset_n) begin
        m_dvd_shift       <= 'd0;
        m_quotient_shift    <= 'd0;
        div_fake        <= 'd0;
    end
    else begin
        if (DVSRL_WR) begin
            m_quotient_shift    <= 0;
            m_dvd_shift         <= {DVSRH, DVSRL};
        end
        else if (DVDDL_WR) begin
            m_divisor <= {DVDDH, DVDDL};
        end
        else if (|{REN}) begin
            if(~counter[0]) begin
                m_dvd_shift <= overflow ? {sum[14:0], 1'b0} : {m_dvd_shift[14:0], 1'b1};
                m_quotient_shift <= {m_quotient_shift, overflow};
            end
        end
    end
end




endmodule