module Video_access_core (
	input						chip_clk,					
	input						reset_n,						
	output reg				burst_rd,             
   output reg				burst_wr,              
   output reg	[31:0]	burst_addr,            
   output reg 	[10:0]	burst_len,             
   output reg 	[3:0]		burst_mask,            
   output reg				burst_strobe,          
   output reg 	[15:0]	burst_data,            
   input		  	[15:0]	burst_q,               
   input						burst_data_valid,      
   input				        burst_data_done,       
   input						burst_ready,   
	
	input 		[10:0]	x_count_frame,
	input 		[10:0]	y_count_frame,
	
	output reg	[13:0]	address_a,					
	output reg	[1:0]		byteena_a,					
	output reg				wren_a,						
	output reg	[15:0]	data_a,						
	input			[15:0]	q_a,
	input						base_new,
	input			[31:0]	base_address_read,		
	input			[31:0]	base_address_write,		
	input			[31:0]	decrease_value,				
	output reg				base_done				
);


parameter		idle					=	0,
					read_request		=	1,
					read_process		=	2,
					write_back_req		=	3,
					write_back_proc	=	4,
					wait_process		=	5;
//
reg [2:0]		ram_state;

reg [25:0]		base_address_read_repeat;
reg [25:0]		base_address_write_repeat;
reg [31:0] 		decrease_value_repeat;

wire [10:0] 	y_count_frame_clocked;
wire [10:0] 	x_count_frame_clocked;

reg  [3:0]		y_count_frame_location;

synch_3 #(.WIDTH(11)) s02(y_count_frame, y_count_frame_clocked, chip_clk);
synch_3 #(.WIDTH(11)) s03(x_count_frame, x_count_frame_clocked, chip_clk);

always @(posedge chip_clk or negedge reset_n) begin
	if (~reset_n) begin
		ram_state 			<= 0;
		burst_rd 			<= 0;
		burst_wr 			<= 0;
		burst_len 			<= 11'd1024;
		burst_addr			<= 26'h0;
		burst_mask			<= 4'b1111;
		burst_data			<= 'd0;
		burst_strobe		<= 0;
		address_a			<= 'd0;
		byteena_a			<= 'd0;
		wren_a				<= 'b0;
		data_a				<= 'd0;
		base_done			<= 'b0;
		base_address_read_repeat	<= 'd0;
		base_address_write_repeat	<= 'd0;
		decrease_value_repeat		<= 'd0;
		y_count_frame_location		<= 'd0;
	end
	else begin
		burst_rd <= 0;
		burst_wr <= 0;
		burst_strobe			<= 0;
		wren_a					<=	1'b0;
		case (ram_state)
			idle		: begin
//				burst_addr <= base_address_read;
				if (base_new) begin
					base_address_read_repeat	<= 'd0;
					base_address_write_repeat	<= base_address_write;
					decrease_value_repeat		<= decrease_value;
					base_done						<= 'b0;
					burst_addr						<= 'b0;
				end
				else begin
					burst_addr <= base_address_read_repeat;
				end
				if (y_count_frame_clocked == 3 && x_count_frame_clocked <= 720) begin
					ram_state 						<= read_request;
					y_count_frame_location		<= 'd0;
				end
			end
			read_request : begin
				burst_rd 						<= 1;
				ram_state 						<= read_process;
				address_a					<= {y_count_frame_location, 10'd0};
			end
			read_process : begin	
				if (burst_data_valid) begin
//					burst_len 					<= burst_len + 1;
					if (wren_a) address_a		<= {y_count_frame_location, (address_a[9:0] + 10'h1)};					
					byteena_a					<= 2'b11;					
					wren_a						<=	1'b1;						
					data_a						<= burst_q;	
				end
				if (burst_data_done) begin
					ram_state 					<= wait_process;
					burst_addr 					<= burst_addr + burst_len;
					y_count_frame_location	<= y_count_frame_location + 1;
				end
			end
			
			write_back_req : begin
//				 ram_state 	<= write_back_proc;
//				 burst_wr 	<= 1;
//				 burst_len	<= 0;
				 
			end
			write_back_proc : begin
//				process_writing 	<= 1;
//				burst_strobe		<= 1;
//				if (burst_len < 11'h2D0) begin				
//					if (burst_ready) begin
//						burst_len 			<= burst_len + 1;
//						burst_strobe		<= 1;
//					end
//				end
//				else begin
//                    burst_len 			<= 11'h2D0;
//                    burst_strobe		<= 0;
//                    ram_state 			<= idle;
//                end 
			end
			wait_process : begin
				if (y_count_frame_clocked >= 720) begin
					ram_state 	<= idle;
					base_done 	<= 'b1;
				end
				else begin
//					if (x_count_frame_clocked <= 3) begin
                    
//					address_a					<= {y_count_frame_location, 10'd0};
						case (y_count_frame_location)
							'h0 : if (y_count_frame_clocked[3:0] != 4'hf) ram_state <= read_request;
							'h1 : if (y_count_frame_clocked[3:0] != 4'h0) ram_state <= read_request;
							'h2 : if (y_count_frame_clocked[3:0] != 4'h1) ram_state <= read_request;
							'h3 : if (y_count_frame_clocked[3:0] != 4'h2) ram_state <= read_request;
							'h4 : if (y_count_frame_clocked[3:0] != 4'h3) ram_state <= read_request;
							'h5 : if (y_count_frame_clocked[3:0] != 4'h4) ram_state <= read_request;
							'h6 : if (y_count_frame_clocked[3:0] != 4'h5) ram_state <= read_request;
							'h7 : if (y_count_frame_clocked[3:0] != 4'h6) ram_state <= read_request;
							'h8 : if (y_count_frame_clocked[3:0] != 4'h7) ram_state <= read_request;
							'h9 : if (y_count_frame_clocked[3:0] != 4'h8) ram_state <= read_request;
							'hA : if (y_count_frame_clocked[3:0] != 4'h9) ram_state <= read_request;
							'hB : if (y_count_frame_clocked[3:0] != 4'hA) ram_state <= read_request;
							'hC : if (y_count_frame_clocked[3:0] != 4'hB) ram_state <= read_request;
							'hD : if (y_count_frame_clocked[3:0] != 4'hC) ram_state <= read_request;
							'hE : if (y_count_frame_clocked[3:0] != 4'hD) ram_state <= read_request;
							'hF : if (y_count_frame_clocked[3:0] != 4'hE) ram_state <= read_request;
						endcase
//					end
				end
			end
			default : ram_state <= 0;
		endcase
	end
end

endmodule