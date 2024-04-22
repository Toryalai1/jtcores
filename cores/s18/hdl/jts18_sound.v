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
    Date: 19-3-2024 */

module jts18_sound(
    input                rst,
    input                clk,

    input                cen_fm,    //  8 MHz
    input                cen_pcm,   // 10 MHz
    input                nmi_n,     // from mapper

    // Mapper device 315-5195
    output               mapper_rd,
    output               mapper_wr,
    output [7:0]         mapper_din,
    input  [7:0]         mapper_dout,
    input                mapper_pbf, // pbf signal == buffer full ?

    // PROM
    input         [ 9:0] prog_addr,
    input                prom_we,
    input         [ 7:0] prog_data,

    // ADPCM RAM
    output        [15:0] pcm_addr,
    output               pcm_cs0,
    output               pcm_cs1,
    input         [ 7:0] pcm_dout,
    output        [ 7:0] pcm_din,

    // Sound output
    output signed [15:0] fm0, fm1,
    output signed [ 7:0] pcm
);

wire        io_wrn, rd_n, wr_n, int_n, mreq_n, iorq_n;
wire [15:0] A;
wire [ 7:0] dout, ram_dout;
reg  [ 7:0] din;
reg         ram_cs, rom_cs;

assign io_wrn     = iorq_n | wr_n;
assign mapper_rd  = mapper_cs && !rd_n;
assign mapper_wr  = mapper_cs && !wr_n;
assign mapper_din = cpu_dout;

// ROM bank address
always @(*) begin
    rom_addr = { 4'd0, A[14:0] };
    if( bank_cs ) begin
        rom_addr[15:14] = rom_msb[1:0];
        casez( ~rom_msb[5:2] ) // A11-A8 refer to the ROM label in the PCB:
            4'b1000: rom_addr[17:16] = 3; // A11 at top
            4'b0100: rom_addr[17:16] = 2; // A10
            4'b0010: rom_addr[17:16] = 1; // A9
            4'b0001: rom_addr[17:16] = 0; // A8
            default: rom_addr[17:16] = 0;
        endcase
            default: // 5521 & 5704
                rom_addr[17:14] = rom_msb[3:0];
        endcase
        rom_addr = rom_addr + 19'h10000;
    end
end

wire underA = A[15:12]<4'ha;
wire underC = A[15:12]<4'hc;

always @(*) begin
    ram_cs  = !mreq_n && &A[15:13];
    bank_cs = !mreq_n && (!underA && underC);
    pcm_cs  = !mreq_n && (!underC && A[15:12]<4'he);
    rom_cs  = !mreq_n &&   underC;

    // Port Map
    { fm0_cs, fm1_cs, breg_cs, mapper_cs } = 0;
    if( !iorq_n && m1_n ) begin
        case( A[7:4] )
            4'h8: fm0_cs    = 1;
            4'h9: fm1_cs    = 1;
            4'ha: breg_cs   = 1;
            4'hc: mapper_cs = 1;
            default:;
        endcase
    end
end


jt12 u_fm0(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen_fm        ),
    .din        ( dout          ),
    .addr       ( A[1:0]        ),
    .cs_n       ( ~fm0_cs       ),
    .wr_n       ( io_wrn        ),

    .dout       ( fm0_dout      ),
    .irq_n      (               ),
    // configuration
    .en_hifi_pcm( 1'b1          ),
    // combined output
    .snd_right  (               ),
    .snd_left   ( fm0           ),
    .snd_sample (               )
);

jt12 u_fm1(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen_fm        ),
    .din        ( cpu_dout      ),
    .addr       ( A[1:0]        ),
    .cs_n       ( ~fm1_cs       ),
    .wr_n       ( io_wrn        ),

    .dout       ( fm1_dout      ),
    .irq_n      ( int_n         ),
    // configuration
    .en_hifi_pcm( 1'b1          ),
    // combined output
    .snd_right  (               ),
    .snd_left   ( fm1           ),
    .snd_sample (               )
);

jtframe_sysz80 #(.RAM_AW(11)) u_cpu(
    .rst_n      ( ~rst        ),
    .clk        ( clk         ),
    .cen        ( cen_fm      ),
    .cpu_cen    (             ),
    .int_n      ( int_n       ),
    .nmi_n      ( nmi_n       ),
    .busrq_n    ( 1'b1        ),
    .m1_n       (             ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     (             ),
    .halt_n     (             ),
    .busak_n    (             ),
    .A          ( A           ),
    .cpu_din    ( din         ),
    .cpu_dout   ( dout        ),
    .ram_dout   ( ram_dout    ),
    // manage access to ROM data from SDRAM
    .ram_cs     ( ram_cs      ),
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom_ok      )
);

endmodule