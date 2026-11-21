module tb_Parameterized_Synchronous_FIFO;

localparam DATA_WIDTH = 32;

reg 					   clk					;
reg 					   rst_n				;

reg [DATA_WIDTH - 1 : 0]   wr_data				;
reg 					   wr_en				;
wire 					   full	    			;
wire 					   almost_full	    	;
wire 					   AF_threshold_alert	;

wire [DATA_WIDTH - 1 : 0]  rd_data	    		;
reg 					   rd_en				;
wire 					   empty				;
wire 					   almost_empty			;
wire 					   AE_threshold_alert	;

Parameterized_Synchronous_FIFO #(
    .FIFO_DEPTH   (1024         ),
    .DATA_WIDTH   (DATA_WIDTH   ),
    .AF           (10           ),
    .AE           (10           ),
    .AF_THRESHOLD (1000         ),
    .AE_THRESHOLD (100          )
) Parameterized_Synchronous_FIFO_inst
(
	.clk				(clk				),
	.rst_n				(rst_n				),
	.wr_data			(wr_data			),
	.wr_en				(wr_en				),
	.full				(full				),
	.almost_full		(almost_full		),
	.AF_threshold_alert	(AF_threshold_alert	),
	.rd_data			(rd_data			),
	.rd_en				(rd_en				),
	.empty				(empty  			),
	.almost_empty		(almost_empty  		),
	.AE_threshold_alert	(AE_threshold_alert )
);


reg [2:0] state = 3'd0;
reg [DATA_WIDTH - 1 : 0] read_counter;

parameter   FULL_WRITE      = 3'd0  ,
            FULL_READ       = 3'd1  ,
            OVERFLOW_WRITE  = 3'd2  ,
            OVERFLOW_READ   = 3'd3  ,
            SIM_READ_WRITE  = 3'd4  ;

always #5 clk = ~clk;

initial begin
    clk = 0;
    rst_n = 1;
    
    // RESET
    #100;
    rst_n = 0;
    #100;
    rst_n = 1;
end


always@(negedge clk) begin
    if(!rst_n) begin
        wr_data         <= 0;
        wr_en           <= 0;
        rd_en           <= 0;
        read_counter    <= 0;
        state           <= 3'd0;
    end
    
    else begin
        case (state)
        
            FULL_WRITE: begin
                if(wr_data == 1024) begin
//                    wr_data <= 0;
                    wr_en 	<= 0;
                    state 	<= FULL_READ;
                end
                
                else begin
                        wr_data <= wr_data + 1;
                        wr_en 	<= 1;
                end
            end
            
            
            FULL_READ: begin
                if(read_counter == 1024) begin
                    read_counter <= {DATA_WIDTH{1'b0}};
                    rd_en 		 <= 0;
                    state 		 <= OVERFLOW_WRITE;
                end
                else begin
                    read_counter <= read_counter + 1;
                    rd_en 		 <= 1;
                end
            end
            
            OVERFLOW_WRITE: begin
                if(wr_data == 4000) begin
//                    wr_data <= 0;
                    wr_en 	<= 0;
                    state 	<= OVERFLOW_READ;
                end
                    
                else begin
                    wr_data <= wr_data + 1;
                    wr_en 	<= 1;
                end
            end

            OVERFLOW_READ: begin
				if(read_counter == 2000) begin
                    read_counter <= {DATA_WIDTH{1'b0}};
                    rd_en <= 0;
                    state <= SIM_READ_WRITE;
                end
                else begin
                    read_counter <= read_counter + 1;
                    rd_en 		 <= 1;
                end
             end
            
            SIM_READ_WRITE: begin
                wr_data <= wr_data + 1;
                wr_en 	<= 1;
                if(wr_data >= 4010) begin
                    rd_en 	<= 1;
                end
                else begin
                    rd_en <= 0;
                end
            end

        endcase
    end
end

endmodule