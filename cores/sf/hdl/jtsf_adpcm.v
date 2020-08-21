/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 21-8-2020 */

module jtsf_adpcm(
    input           rst,
    input           clk,
    input           cpu_cen,
    input           cenp384, //  384 kHz
    // Interface with second CPU
    input   [7:0]   snd_latch,
    // ADPCM ROM
    output  [15:0]  rom2_addr,
    output          rom2_cs,
    input   [ 7:0]  rom2_data,
    input           rom2_ok,
    `ifdef VERILATOR
    output  [ 3:0]  adpcm_din,
    output          adpcm_irq,
    `endif

    // Sound output
    output signed [12:0] snd
);

// ADPCM CPU
wire signed [11:0] snd0, snd1;
wire        [15:0] A;
reg         [ 7:0] din;
wire        [ 7:0] dout;
reg                last_rom2_cs, int_n;
wire               wr_n, rd_n, iorq_n, rfsh_n, mreq_n, m1_n;

assign rom2_cs   = !mreq_n && rfsh_n;
assign rom2_addr = A;
assign snd       = snd0 + snd1;

always @(*) begin
    din = !iorq_n && !rd_n && !A[0] ? snd_latch : rom2_data;
end

reg [3:0] pcm0_data, pcm1_data;
reg       pcm0_rst,  pcm1_rst;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        pcm0_rst  <= 1'b0;
        pcm1_rst  <= 1'b0;
        pcm0_data <= 4'd0;
        pcm1_data <= 4'd0;
    end else begin
        if( !iorq_n && !wr_n ) begin
            if( !A[0] ) begin
                pcm0_rst  <= dout[7];
                pcm0_data <= dout[3:0];
            end else begin
                pcm1_rst  <= dout[7];
                pcm1_data <= dout[3:0];
            end
        end
    end
end

wire irq_st;

jt5205 u_adpcm0(
    .rst        ( rst |pcm0_rst ),
    .clk        ( clk           ),
    .cen        ( cenp384       ),
    .sel        ( 2'b0          ),
    .din        ( pcm0_data     ),
    .sound      ( snd0          ),
    .irq        ( irq_st        )
);

jt5205 u_adpcm1(
    .rst        ( rst |pcm1_rst ),
    .clk        ( clk           ),
    .cen        ( cenp384       ),
    .sel        ( 2'b0          ),
    .din        ( pcm1_data     ),
    .sound      ( snd1          ),
    .irq        (               )
);

reg last_irq_st;

always @(posedge clk, posedge rst) begin
    if(rst) begin
        int_n <= 1'b1;
    end else begin
        last_irq_st <= irq_st;
        if( !last_irq_st && irq_st )
            int_n <= 1'b0;
        if( !iorq_n && !m1_n )
            int_n <= 1'b1;
    end
end

jtframe_z80_romwait u_cpu(
    .rst_n      ( ~rst        ),
    .clk        ( clk         ),
    .cen        ( cpu_cen     ),
    .cpu_cen    (             ),
    .int_n      ( int_n       ),
    .nmi_n      ( 1'b1        ),
    .busrq_n    ( 1'b1        ),
    .m1_n       ( m1_n        ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     ( rfsh_n      ),
    .halt_n     (             ),
    .busak_n    (             ),
    .A          ( A           ),
    .din        ( din         ),
    .dout       ( dout        ),
    .rom_cs     ( rom2_cs     ),
    .rom_ok     ( rom2_ok     )
);


endmodule // jtgng_sound