`timescale 1ns / 1ps

module driver_control(
	input         clk, 				// 25Mhz
    input         rstn,

    input         test_mode,
    input         pwm_cw_mode_select,
    input         trigger,
    input         shutdown,
    input         laser_fired_count_reset,

    input [23:0] pulse_width,
    input [23:0] period,

    input [15:0] drive_current,
    input [15:0] drive_current_limit,
    input        drive_current_update,

    output reg   mosi,
    output reg   ss,
    output reg   sck,
    output reg   ldac_n,
	
    output reg   pulse,
    output reg   pulse_active,
    output reg   period_active,
    output reg   trigger_ext,
    output reg   all_trigger,
    output reg   force_trigger,
    output reg   laser_on,
    output reg [31:0] laser_fired_count
	);
	
localparam IDLE            = 0;
localparam WAIT            = 1;
localparam SEND            = 2;
localparam SCK_STATE       = 3;
localparam READY           = 4;
localparam LDAC            = 5;
localparam PULSE_COUNT_ST  = 6;
localparam PERIOD_COUNT_ST = 7;
localparam DONE            = 8;
		
localparam WRITE_INPUT_REGISTER = 4'h3;

reg [3:0]  state=0,cstate=0,dac_state=0,pulse_state=0,out_state=0;
reg [7:0]  count;
reg [23:0] data_temp;
reg [23:0] data;
reg        data_valid,data_valid_reset;
reg        cw_data_valid;
reg        data_ready;
reg        eload;

reg        ss_temp=1;
reg        sck_temp=0;
reg        mosi_temp=0;
reg        ldac_temp=1;
reg        ldac_temp_d=1;

reg [15:0] drive_current_reg,drive_current_limit_reg;
reg [15:0] total_count,dac_count;
reg data_select;
reg data_ready_d;
reg mosi_reset;
reg ss_temp_d;
reg spi_select,select;
reg [15:0] clk_count;
reg [23:0] pulse_count;
reg [23:0] period_d,period_d2;
reg        load_dac,reload_dac;
reg        trigger_ext_rst,all_trigger_d;
reg [7:0]  trigger_count;
reg [23:0] force_trigger_count,force_trigger_count_d,force_trigger_count_d2;
reg index=0;
reg load_dac_d,reload_dac_d;
reg load_dac_register;
reg force_trigger_d,force_trigger_ext;
reg mosi_d1;
reg [7:0] ready_count;
reg drive_current_ready;
reg [7:0] wait_count;

wire pulse_clk;

assign spi_ready = data_ready;

assign pulse_clk = clk_count[2];

always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
           clk_count <= 0;
      end else begin
                  clk_count <= clk_count + 1;
               end
end

always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
           force_trigger_count_d <= 0;
           force_trigger_count_d2 <= 0;
      end else begin
                  force_trigger_count_d <= force_trigger_count;
                  force_trigger_count_d2 <= force_trigger_count_d;
               end
end


always @(posedge pulse_clk or negedge rstn) begin
      if (!rstn) begin
           period_d <= 0;
           period_d2 <= 0;
           force_trigger <= 0;
           force_trigger_d <= 0;
           force_trigger_ext <= 0;
           force_trigger_count <= 0;
      end else begin
				  period_d <= period;
				  period_d2 <= period_d;
				  force_trigger_d <= force_trigger;
				  force_trigger_ext <= force_trigger_d | force_trigger;
                  if (test_mode) begin
					  if (force_trigger_count_d2 >= period_d2) begin
						  force_trigger <= 1;
						  force_trigger_count <= 0;
					  end else begin
								  force_trigger <= 0;
								  force_trigger_count <= force_trigger_count + 1;
							   end
				  end else begin
					          force_trigger_count <= 0;
							  force_trigger <= 0;
							end
               end
end

always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
           all_trigger <= 0;
           all_trigger_d <= 0;
           trigger_ext <= 0;
           trigger_count <= 0;
      end else begin
                   all_trigger <= ((trigger | force_trigger_ext) & (!shutdown));
                   all_trigger_d <= all_trigger;
                   if (!all_trigger_d & all_trigger) trigger_ext <= 1;
                   if (trigger_ext) begin
                       if (trigger_count > 15) begin
                           trigger_count <= 0;
                           trigger_ext <= 0;
                       end else begin
                                  trigger_count <= trigger_count + 1;
                                end
                   end
               end
end

always @(negedge pulse_clk or negedge rstn or posedge laser_fired_count_reset) begin
      if (!rstn | laser_fired_count_reset) begin
           pulse_count <= 0;
           period_active <= 0;
           pulse <= 0;
           pulse_active <= 0;
		   laser_fired_count <= 0;
           ldac_temp <= 1;
           pulse_state <= IDLE;
      end else begin
                  case (pulse_state)
                        IDLE : begin
                                   if (trigger_ext) begin
                                       ldac_temp <= 0;
                                       pulse <= 1;
                                       pulse_active <= 1;
                                       period_active <= 1;
									   laser_fired_count <=  laser_fired_count + 1;

                                       pulse_state <= PULSE_COUNT_ST;
                                   end else ldac_temp <= 1;
                               end
              PULSE_COUNT_ST : begin  //6
                                   if (pulse_count > pulse_width-55) pulse <= 0;
                                 //  if (pulse_count > pulse_width-20) pulse <= 0;
                                   if (pulse_count > pulse_width-2) begin
                                       ldac_temp <= 0;
                                       pulse_active <= 0;
                                       pulse_state <= DONE;
                                   end else ldac_temp <= 1;
								   pulse_count <= pulse_count + 1;
                               end
                        DONE : begin  //8
							      ldac_temp <= 1;								  
								  if (pulse_count > period-2) begin
                                       pulse_count <= 0;
                                       pulse_active <= 0;
                                       period_active <= 0;
                                       pulse_state <= IDLE;
                                  end else pulse_count <= pulse_count + 1;
                               end
                  endcase
               end
end

always @(negedge clk or negedge rstn) begin
		if (!rstn) begin
             mosi <= 0;
        end else begin
                   mosi <= mosi_temp;
                 end
end

always @(posedge clk or negedge rstn) begin
		if (!rstn) begin
             ss <= 0;
             sck <= 0;
             ldac_n <= 0;
        end else begin
				   ss <= ss_temp;
                   sck <= !sck_temp;
                   ldac_n <= ldac_temp;
                 end
end

always @(posedge clk or negedge rstn) begin
		if (!rstn) begin
             total_count <= 0;
             data_select <= 0;
             ss_temp <= 1;
             sck_temp <= 0;
             ss_temp_d <= 0;
             data_valid_reset <= 0;
             mosi_reset <= 0;
             data_ready <= 1;
             cstate <= IDLE;
        end else begin
                      ss_temp_d <= ss_temp;
                      if (!ss_temp_d & ss_temp) mosi_reset <= 1;
                      else mosi_reset <= 0;

                      case (cstate)
                            IDLE : begin
                                        total_count <= 0;
                                        if (data_valid) begin
                                           data_valid_reset <= 1; 
                                           ss_temp <= 0; 
                                           data_ready <= 0;
                                           cstate <= SCK_STATE;
                                        end
                                   end
                       SCK_STATE : begin
						              if (total_count > 1) data_valid_reset <= 0; 

                                      if (total_count > 46) begin
                                          sck_temp <= 0;
                                          cstate <= DONE;
                                      end else begin
                                                    sck_temp <= ~sck_temp;
                                                    total_count <= total_count + 1;
                                               end
                                    end
                        DONE: begin
                                 data_select <= 0;
                                 total_count <= 0;
                                 sck_temp <= 0;
                                 ss_temp <= 1; 
                                 data_ready <= 1;
                                 cstate <= IDLE;
                              end

                    endcase
		end
	end

always @(posedge sck_temp or negedge rstn or posedge mosi_reset) begin
		if (!rstn | mosi_reset) begin
             count <= 22;
             mosi_temp <= 0;
             data_temp <= 0;
             state <= IDLE;
        end else begin
                     case(state)
                          IDLE: begin
                                   if (!ss_temp) begin
                                        mosi_temp <= data[23];
                                        data_temp <= data << 1;
                                        state <= SEND;
                                   end
                                end
                          SEND: begin
                                   mosi_temp <= data_temp[23];
                                   data_temp <= data_temp << 1;
                                   if (count == 0) begin
                                       count <= 22;
                                       state <= DONE;
                                   end else count <= count - 1;
                                end
                          DONE: begin
                                     mosi_temp <= 0;
                                     state <= IDLE;
                                end
                     endcase
		        end
end


always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
             load_dac_register <= 0;
             drive_current_reg <= 0;
			 drive_current_limit_reg <= 16'h8647;   //Drive current: 5500mA
    end else begin
                 drive_current_limit_reg <= drive_current_limit;
                 if (drive_current_update) begin
                     if (drive_current < drive_current_limit_reg) drive_current_reg <= drive_current;
					 else drive_current_reg <= drive_current_limit_reg;
						 
					 load_dac_register <= 1;
                 end else load_dac_register <= 0;
             end
end


always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        index <= 0;
        data <= 0;
        data_valid <= 0;
        laser_on <= 0;
        load_dac_d <= 0;
        ldac_temp_d <= 1;
        reload_dac_d <= 0;
        wait_count <= 0;
		out_state <= IDLE;
    end else begin
			       ldac_temp_d <= ldac_temp;
				   if (data_valid_reset) data_valid <= 0;
				   case (out_state)
						 IDLE : if (!ldac_temp_d & ldac_temp) out_state <= WAIT;
						 WAIT : begin
						          if (wait_count > 8'hF0) begin
									  wait_count <= 0;
									  out_state <= READY;
								  end else wait_count <= wait_count + 1;
								end
				   	    READY : begin
							       out_state <= DONE;
								   case (index)
										 0 : begin
													data <= {4'h3,drive_current_reg,4'h0};
													data_valid <= 1;
													laser_on <= 1;
													index <= 1;
											 end
										 1 : begin
													data <= {4'h3,16'h0,4'h0};
													data_valid <= 1;
													laser_on <= 0;
													index <= 0;
											 end
								   endcase
								 end
						  DONE : out_state <= IDLE;
				  endcase 
					  
		     end
end


endmodule
	