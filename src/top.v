///////////////////////////////////////////////////////////////////////////////////////////////////
// Company: <Name>
//
// File: top.v
// File history:
//      <Revision number>: <Date>: <Comments>
//      <Revision number>: <Date>: <Comments>
//      <Revision number>: <Date>: <Comments>
//
// Description: 
//
// <Description here>
//TA Drive: 0 mA
//TA Pulse: 250 탎

//Seed DDS: 0 mA (Limit 80mA)
//Seed CW: 140 mA (Limit 140mA)

//Pulse width limit, upper: 0탎
//Pulse width limit, upper: 225탎
//Period limit: 22500탎
//Drive current: 5500mA
//CW Current: 160mA
//PWM Current: 80mA

//
// Targeted device: <Family::ProASIC3> <Die::A3PN010> <Package::48 QFN>
// Author: <Name>
//
/////////////////////////////////////////////////////////////////////////////////////////////////// 
`timescale 1ns / 1ps

module top( 
    input     rstn,                 // Pin 8
    input     system_reset_n,       // Pin 38

    input     clk_25mhz,            // Pin 1
	input     TA_pos_pwr_good,      // Pin 15
	input     TA_neg_pwr_good,      // Pin 14

    input     trigger,              // Pin 48
    input     TA_EE_shutdown,       // Pin 42
    input     TA_OPT_shutdown,      // Pin 43
	
	output    sck,                  // Pin 67
	output    mosi,                 // Pin 69    
	output    ss,                   // Pin 68
	output    ldac_n,               // Pin 66
	
	output    laser_disable_led_n,   // Pin 12
	//output    TA_laser_disable,      // Pin 87-low active
	output    pulse,                  // Pin 87

	input     adc_sdo,        	       // Pin 84
	output    adc_sck,         	   // Pin 81
	output    adc_convert,     	   // Pin 71
	
    inout     scl,             	   // Pin 57
    inout     sda,             	   // Pin 58
	
	input     cw_compared,            // Pin 70
	input     pwm_compared,           // Pin 63
	output    cw_over_current_led_n,  // Pin 64
	output    pwm_over_current_led_n, // Pin 65

    output    heartbeat_n,            // Pin 54
	output    cw_active_led_n,        // Pin 10
	output    modulate_active_led_n,  // Pin 9
		
	inout     mcu_gpio,               // Pin 7

	inout     TA_spare1,          	  // Pin 18
	inout     TA_spare2,          	  // Pin 19
	inout     TA_spare3,          	  // Pin 20
	inout     TA_spare4,          	  // Pin 21
	
	inout     TA_gpio1,           	  // Pin 53
	inout     TA_gpio2,           	  // Pin 51
	inout     TA_gpio3,           	  // Pin 52
	inout     TA_gpio4,           	  // Pin 41
	
	inout     OPT_gpio1,             // Pin 83
	inout     OPT_gpio2,             // Pin 75
	inout     OPT_gpio3,             // Pin 74
	inout     OPT_gpio4              // Pin 78
	

);

wire        buf_rstn;
wire        buf_clk;
wire        buf_sclk;
wire        buf_miso;
wire        buf_laser_active;
wire        adc_data_valid;
wire [15:0] adc_voltage_data;
wire [15:0] adc_current_data;
wire [7:0]  status;

wire [23:0] pulse_width;
wire [23:0] period;
wire [15:0] drive_current;
wire [15:0] drive_current_limit;
wire [15:0] pwm_current_limit;
wire [15:0] cw_current_limit;
wire [15:0] adc_current_limit;
wire [15:0] static_control;
wire [15:0] dynamic_control;
wire        over_current_limit;
wire [31:0] laser_fired_count;

wire [15:0] pwm_mon_current_limit;
wire [15:0] cw_mon_current_limit;

wire pwm_cw_control_select;
wire drive_current_update;
wire pwm_cw_mode_select;
wire auto_run;
wire mon_limit_update;
wire sw_trigger;
wire test_mode;
wire pulse_active;
wire period_active;
wire trigger_ext,all_trigger;
wire data_valid;
wire laser_on;
wire shutdown;
wire [15:0] adc_peak_data;
wire lock;

///////////////// reg 20 //////////////////////
assign pwm_cw_mode_select   = static_control[0];
assign cw_active_n          = !static_control[1];
assign modulate_active_n    = !static_control[2];
assign laser_disable        = static_control[3];
assign test_mode            = static_control[7];
 
///////////////// reg 22 //////////////////////
assign mon_limit_update     = dynamic_control[1];
assign laser_fired_count_reset = dynamic_control[0];

assign over_current_shutdown_n  = !(over_current_limit);
assign TA_laser_disable = !(over_current_limit);

//assign TA_spare2              = pulse_active;
//assign TA_spare1              = period_active;
//assign TA_spare1              = sck;
assign TA_spare1              = pulse;
//assign TA_spare2              = shutdown;
assign TA_spare2              = TA_EE_shutdown;
//assign TA_spare3              = ss;
assign TA_spare3              = trigger;
assign TA_spare4              = TA_OPT_shutdown;
//assign TA_spare4              = ldac_n;
assign TA_gpio1               = 0;
assign TA_gpio2               = 0;
assign TA_gpio3               = 0;
assign TA_gpio4               = 0;
assign OPT_gpio1              = 0;
assign OPT_gpio2              = 0;
assign OPT_gpio3              = 0;
assign OPT_gpio4              = 0;

assign laser_disable_led_n = !laser_on;

assign status = {5'h0,TA_EE_shutdown,TA_OPT_shutdown,laser_on};
assign mcu_gpio              = 0;

//assign buf_rstn = rstn  & system_reset_n;
assign shutdown = TA_EE_shutdown | TA_OPT_shutdown;

reset_generator reset_generator( 
    .rstn      		(rstn),
    .system_reset_n (system_reset_n),
    .clk       		(buf_clk),
    .reset_n   		(reset_n)
);

PLL PLL( 
    .RST    (!rstn),
    .CLKI   (clk_25mhz),
    .CLKOP  (buf_clk),
    .LOCK   (lock)
);

heart_beat heart_beat( 
    .rstn      (reset_n),
    .clk       (buf_clk),
    .heartbeat (heartbeat_n)
);

i2c_slave_top i2c_slave_top (
	.rstn 					(reset_n),
	.clk 					(buf_clk),
	
	.scl 					(scl),
	.sda 					(sda),
	
	.laser_fired_count      (laser_fired_count),
	.revision     			(8'h3),
	.minor      			(8'h0),
	.major      			(8'h0),
	.ID      				(8'h2),

    .adc_voltage_data 		(adc_voltage_data),
    .adc_peak_data 		    (adc_peak_data),
    .status 				(status),
	
    .pulse_width 			(pulse_width),
    .period     			(period),
    .drive_current         (drive_current),
	.drive_current_update  (drive_current_update),

    .drive_current_limit   (drive_current_limit),
    .pwm_mon_current_limit (pwm_mon_current_limit),
    .cw_mon_current_limit  (cw_mon_current_limit),
    .dynamic_control 	   (dynamic_control),
    .static_control 	   (static_control)

);
         
		 
driver_control driver_control(
    .rstn               			(reset_n),
    .clk                			(buf_clk),

    .test_mode 			            (test_mode),
    .pwm_cw_mode_select 			(pwm_cw_mode_select),

    .trigger            			(trigger),
    .shutdown                      (shutdown),
    .laser_fired_count_reset	    (laser_fired_count_reset),

    .pulse_width        			(pulse_width),
    .period             			(period),
	
    .drive_current			        (drive_current),
    .drive_current_limit			(drive_current_limit),
    .drive_current_update 	        (drive_current_update),

    .mosi               			(mosi),
    .ss                 			(ss),
    .sck                			(sck),
    .ldac_n             			(ldac_n),
	
    .pulse		       			    (pulse),
    .pulse_active       			(pulse_active),
    .period_active      			(period_active),
    .all_trigger      			    (all_trigger),
    .trigger_ext      			    (trigger_ext),
    .force_trigger      		    (force_trigger),
    .laser_on      		            (laser_on),
	.laser_fired_count      	    (laser_fired_count)

	);
	
adc_control adc_control( 
    .rstn                   (reset_n),
    .clk                    (buf_clk),

    .pwm_cw_mode_select     (pwm_cw_mode_select),
	
    .pwm_mon_current_limit  (pwm_mon_current_limit),
    .cw_mon_current_limit   (cw_mon_current_limit),
    .mon_limit_update       (mon_limit_update),
    .adc_status_clear       (adc_status_clear),

    .adc_data_valid         (adc_data_valid),
    .adc_voltage_data       (adc_voltage_data),
	
    .adc_sdo                (adc_sdo),
    .adc_sck                (adc_sck),
    .adc_convert            (adc_convert),

    .adc_peak_data          (adc_peak_data)

);

endmodule

