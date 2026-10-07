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

//`timescale <time_units> / <precision>

module heart_beat( 
    input   rstn,
    input   clk,

    output  heartbeat
);

reg [15:0] count;
reg [15:0] prescale;
wire heartbeat_clk;

assign heartbeat = count[7];
assign heartbeat_clk = prescale[15];

always @(posedge clk,negedge rstn)
begin
    if (!rstn) begin
        prescale <= 0;     
    end else begin
                 prescale <= prescale + 1;
            end
end

always @(posedge heartbeat_clk,negedge rstn)
begin
    if (!rstn) begin
        count <= 0;     
    end else begin
                 count <= count + 1;
            end
end

endmodule

