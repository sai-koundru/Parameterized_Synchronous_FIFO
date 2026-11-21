module Parameterized_Synchronous_FIFO
#(parameter FIFO_DEPTH = 1024, DATA_WIDTH = 32, AF = 10, AE = 10, AF_THRESHOLD = 1000, AE_THRESHOLD = 100)
(
	input  logic 					   clk             		,
	input  logic 					   rst_n           		,
	
	input  logic [DATA_WIDTH - 1 : 0]  wr_data	            ,
	input  logic 					   wr_en             	,
	output logic 					   full	             	,
	output logic 					   almost_full       	,
    output logic 					   AF_threshold_alert	,

	output logic [DATA_WIDTH - 1 : 0]  rd_data              ,
	input  logic 					   rd_en             	,
	output logic 					   empty             	,
	output logic 					   almost_empty      	,
    output logic 					   AE_threshold_alert
);

localparam POINTER_SIZE = $clog2(FIFO_DEPTH);


reg [DATA_WIDTH   - 1 : 0] memory [FIFO_DEPTH - 1 : 0];
reg [POINTER_SIZE - 1 : 0] wr_ptr;
reg [POINTER_SIZE - 1 : 0] rd_ptr;
reg [POINTER_SIZE : 0] data_counter;


assign empty        = (data_counter == 0)  ? 1'b1 : 1'b0;
assign almost_empty = (data_counter <= AE) ? 1'b1 : 1'b0;

assign full         = (data_counter == FIFO_DEPTH) ? 1'b1 : 1'b0;
assign almost_full  = (data_counter >= FIFO_DEPTH - AF) ? 1'b1 : 1'b0;

assign AF_threshold_alert = (data_counter >= AF_THRESHOLD) ? 1'b1 : 1'b0;
assign AE_threshold_alert = (data_counter <= AE_THRESHOLD) ? 1'b1 : 1'b0;


always_ff @(posedge clk or negedge rst_n) begin
	
	if(!rst_n) begin
		rd_data 		<= 0;
		wr_ptr			<= 0;
		rd_ptr			<= 0;
		data_counter 	<= 0;
	end
	
	else begin
		
        if (wr_en && !full) begin
        
            memory[wr_ptr] <= wr_data;
        
            if (wr_ptr == FIFO_DEPTH-1)
                wr_ptr <= 0;
            else
                wr_ptr <= wr_ptr + 1;
        end
        
        
        if (rd_en && !empty) begin
        
            rd_data <= memory[rd_ptr];
        
            if (rd_ptr == FIFO_DEPTH-1)
                rd_ptr <= 0;
            else
                rd_ptr <= rd_ptr + 1;
        end
        
        
        case ({wr_en && !full, rd_en && !empty})
            2'b10: data_counter <= data_counter + 1;
            2'b01: data_counter <= data_counter - 1;
            default: data_counter <= data_counter;
        endcase
	    
	end

end

endmodule