module Sound_RAM(
    input               clk,
    input       [10:0]  address,
    input  		    		write,
    input  		 [7:0]   data,
    output reg  [7:0]   q
    );
    
 reg [7:0] CPU_RAM_MEM [2047:0];
integer k;
initial
begin
for (k = 0; k < 2048; k = k + 1)
begin
    CPU_RAM_MEM[k] = 'b0;
//    mem[k+1] = 8'b11011101;
end
end

always @(posedge clk) begin
    if (write) CPU_RAM_MEM[address] <= data;
    q <= CPU_RAM_MEM[address];
end
    
    
endmodule