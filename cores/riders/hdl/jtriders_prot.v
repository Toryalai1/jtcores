/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 13-7-2024 */

module jtriders_prot(
    input                rst,
    input                clk,

    input         [13:1] addr,
    // input         [ 1:0] dsn,
    input         [15:0] din,
    output reg    [15:0] dout,
    input                cpu_we,
    input                ram_we,

    output               irqn,
    output               BRn,
    input                BGn,
    output               BGACKn
);

localparam [13:1] DATA = 13'h2d05, // 5a0a>>1
                  CMD  = 13'h2c7e, // 58fc>>1
                  V0   = 13'h2c0c, // 5818>>1
                  V1   = 13'h2e58, // 5cb0>>1
                  V2   = 13'h2064; // 40c8>>1

reg [15:0] cmd, data, v0, v1, v2, vx;
reg [ 5:0] calc;

assign irqn = 1; // always high on the PCB

// To do
assign BRn    = 1;
assign BGACKn = 1;

always @* begin
    vx = (v2-32)>>3;
    vx = { 5'd0, vx[4:0], 6'd0 };
    vx = vx + v1 + v2 - 16'd6;
    vx = vx>>3;
    vx = vx+16'd12;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        { cmd, data, v0, v1, v2 } <= 0;
    end else if(ram_we) begin
        case(addr)
            DATA: data <= din;
            CMD:  cmd  <= din;
            V0:   v0   <=-din;
            V1:   v1   <= din;
            V2:   v2   <= din;
            default:;
        endcase
    end
end

always @(posedge clk) begin
    calc <= vx[5:0];
    case(cmd)
        16'h100b: dout <= 16'h64;
        16'h6003: dout <= {12'd0,data[3:0]};
        16'h6004: dout <= {11'd0,data[4:0]};
        16'h6000: dout <= {15'd0,data[  0]};
        16'h0000: dout <= { 8'd0,data[7:0]};
        16'h6007: dout <= { 8'd0,data[7:0]};
        16'h8abc: dout <= {10'd0,calc};
        default:  dout <= 0;
    endcase
end

endmodule