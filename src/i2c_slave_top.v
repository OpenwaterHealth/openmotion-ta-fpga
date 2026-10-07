// SPDX-License-Identifier: AGPL-3.0-or-later
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
//
// Targeted device: <Family::ProASIC3> <Die::A3PN010> <Package::48 QFN>
// Author: <Name>
//
/////////////////////////////////////////////////////////////////////////////////////////////////// 
`timescale 1ns / 1ps

module i2c_slave_top( 
    input     	   rstn,                 	 
    input    	   clk,              	     
	
    inout     	   scl,             		 
    inout     	   sda,             		 
			
	input [31:0]  laser_fired_count,
    input [7:0]   revision,
    input [7:0]   minor,
    input [7:0]   major,
    input [7:0]   ID,
	
    input [15:0]  adc_voltage_data,
    input [15:0]  adc_peak_data,
    input [7:0]   status,

    output [23:0] pulse_width,
    output [23:0] period,
    output [15:0] drive_current,
    output         drive_current_update,
    output [15:0] drive_current_limit,
    output [15:0] pwm_mon_current_limit,
    output [15:0] cw_mon_current_limit,
    output [15:0] dynamic_control,
    output [15:0] static_control
            

);

wire start;
wire stop;
wire data_vld;
wire r_w;
wire [7:0] data_in;
wire [7:0] data_out;
wire stretch_on;
		
i2cslave_controller_top i2cslave_controller_top (
	.scl 		(scl),
	.sda 		(sda),
	.clk 		(clk),
	.reset 		(!rstn),
	.stretch_on (stretch_on),
	.data_in 	(data_in),

	.start 		(start),
	.stop 		(stop),
	.data_vld 	(data_vld),
	.r_w 		(r_w),
	.data_out 	(data_out)
);

registers registers(
	.clk 					(clk),
	.rst 					(!rstn),
	.SCL 					(scl),
	.data_to_i2c 			(data_in),
	.start 					(start),
	.stop 					(stop),
	.data_vld 				(data_vld),
	.r_w 					(r_w),
	.i2c_to_data			(data_out),
	.stretch_on             (stretch_on),

	.laser_fired_count 		(laser_fired_count),
	.revision 				(revision),
	.minor 					(minor),
	.major 					(major),
	.ID 					(ID),

	.adc_voltage_data 		(adc_voltage_data),
	.adc_peak_data 		    (adc_peak_data),
	.status 				(status),
	
	.pulse_width 			(pulse_width),
	.period 				(period),
	.drive_current      	(drive_current),
	.drive_current_update  	(drive_current_update),
	.drive_current_limit 	(drive_current_limit),
	
	.pwm_mon_current_limit 	(pwm_mon_current_limit),
	.cw_mon_current_limit 	(cw_mon_current_limit),
	
	.dynamic_control 		(dynamic_control),
	.static_control 		(static_control)
	
);
 

endmodule

