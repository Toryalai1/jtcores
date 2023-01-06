/*  This file is part of JTGNG.
    JTGNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTGNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTGNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 14-9-2019 */


module jtbiocom_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [ 8:0] V, H;
wire        HINIT;

wire [13:1] cpu_AB;
wire        char_cs, col_uw, col_lw;
wire        flip;
wire [ 7:0] char_dout, scr1_dout, scr2_dout;
wire [15:0] cpu_dout;
wire        rd, cpu_cen;
wire        char_busy, scr1_busy, scr2_busy;
wire        clk_mcu;

// MCU interface
wire [ 7:0] snd_din, snd_dout;
wire        snd_mcu_wr, snd_mcu_rd;
wire        mcu_brn;
wire [ 7:0] mcu_din, mcu_dout;
wire [16:1] mcu_addr;
wire        mcu_wr, mcu_DMAn, mcu_DMAONn;

wire        preLHBL, preLVBL,
            LHBL_obj, LVBL_obj;

wire        video_cen8, cen8, cen3, mcu_cen, cen10, cenfm, cenp384,
            cen_fm, cen_fm2, cen10b;
wire        nc,ncb;

wire RnW;
// sound
wire [7:0] snd_latch;

wire        main_cs, snd_nmi_n;
// OBJ
wire        OKOUT, blcnten, obj_br, bus_ack;
wire [13:1] obj_AB;     // 1 more bit than older games
wire [15:0] oram_dout;

wire [ 1:0] prom_we;
wire        prom_mcu_we  = prom_we[0];
wire        prom_prio_we = prom_we[1];

wire        scr1_cs, scr2_cs;
wire [ 9:0] scr1_hpos, scr1_vpos;
wire [ 8:0] scr2_hpos, scr2_vpos;

assign game_led = 0;
assign clk_mcu = clk24;

jtframe_cen48 u_cen48(
    .clk    ( clk           ),
    .cen16  (               ),
    .cen12  ( pxl2_cen      ),
    .cen12b (               ),
    .cen8   ( video_cen8    ),
    .cen6   ( pxl_cen       ),
    .cen6b  (               ),
    .cen4   (               ),
    .cen4_12(               ),
    .cen3   (               ),
    .cen3b  (               ),
    .cen3q  (               ),
    .cen3qb (               ),
    .cen1p5 (               ),
    .cen1p5b(               )
);

jtframe_cen24 u_cen24(
    .clk    ( clk24     ),
    .cen12  (           ),
    .cen12b (           ),
    .cen6   (           ),
    .cen3   ( cen3      ),
    // Unused:
    .cen6b  (           ),
    .cen1p5 ( mcu_cen   ),
    .cen1p5b(           ),
    .cen8   (           ),
    .cen4   (           ),
    .cen3q  (           ),
    .cen3b  (           ),
    .cen3qb (           )
);

jtframe_cen3p57 #(.CLK24(1)) u_cen3p57(
    .clk        ( clk24     ),       // 48 MHz
    .cen_3p57   ( cen_fm    ),
    .cen_1p78   ( cen_fm2   )
);

jtgng_timer u_timer(
    .clk       ( clk      ),
    .cen6      ( pxl_cen  ),
    .V         ( V        ),
    .H         ( H        ),
    .Hinit     ( HINIT    ),
    .LHBL      ( preLHBL  ),
    .LHBL_obj  ( LHBL_obj ),
    .LVBL      ( preLVBL  ),
    .LVBL_obj  ( LVBL_obj ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          )
);

jtbiocom_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_cenb   (               ),
    // Timing
    .flip       ( flip          ),
    .V          ( V             ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    // sound
    .snd_latch  ( snd_latch     ),
    .snd_nmi_n  ( snd_nmi_n     ),
    // CHAR
    .char_dout  ( { 8'hff, char_dout } ), // upper 8 bits unused
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    // SCROLL 1
    .scr1_dout  ( scr1_dout     ),
    .scr1_cs    ( scr1_cs       ),
    .scr1_busy  ( scr1_busy     ),
    .scr1_hpos  ( scr1_hpos     ),
    .scr1_vpos  ( scr1_vpos     ),
    .scr_bank   (               ),  // only Tiger Road
    // SCROLL 2
    .scr2_dout  ( scr2_dout     ),
    .scr2_cs    ( scr2_cs       ),
    .scr2_busy  ( scr2_busy     ),
    .scr2_hpos  ( scr2_hpos     ),
    .scr2_vpos  ( scr2_vpos     ),
    // OBJ - bus sharing
    .UDSWn      (               ),
    .LDSWn      (               ),
    .obj_AB     ( obj_AB        ),
    .cpu_AB     ( cpu_AB        ),
    .oram_dout  ( oram_dout     ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .obj_br     ( obj_br        ),
    .bus_ack    ( bus_ack       ),
    .col_uw     ( col_uw        ),
    .col_lw     ( col_lw        ),
    // MCU interface
    .mcu_cen    (  mcu_cen      ),
    .mcu_brn    (  mcu_brn      ),
    .mcu_din    (  mcu_din      ),
    .mcu_dout   (  mcu_dout     ),
    .mcu_addr   (  mcu_addr     ),
    .mcu_wr     (  mcu_wr       ),
    .mcu_DMAn   (  mcu_DMAn     ),
    .mcu_DMAONn (  mcu_DMAONn   ),
    // ROM
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .start_button( start_button ),
    .coin_input  ( coin_input   ),
    .joystick1   ( joystick1[5:0] ),
    .joystick2   ( joystick2[5:0] ),

    .RnW        ( RnW           ),
    // DIP switches
    .service    ( service       ),
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw[ 7:0]   ),
    .dipsw_b    ( dipsw[15:8]   )
);

jtbiocom_mcu u_mcu(
    .rst        ( rst24         ),
    .clk        ( clk_mcu       ),
    .rst_cpu    ( rst           ),
    .clk_rom    ( clk           ),
    .clk_cpu    ( clk           ),
    .cen6a      ( mcu_cen       ),       //  6   MHz
    // Main CPU interface
    .DMAONn     ( mcu_DMAONn    ),
    .mcu_din    ( mcu_din       ),
    .mcu_dout   ( mcu_dout      ),
    .mcu_wr     ( mcu_wr        ),   // always write to low bytes
    .mcu_addr   ( mcu_addr      ),
    .mcu_brn    ( mcu_brn       ), // RQBSQn
    .DMAn       ( mcu_DMAn      ),

    // Sound CPU interface
    .snd_din    ( snd_din       ),
    .snd_dout   ( snd_dout      ),
    .snd_mcu_wr ( snd_mcu_wr    ),
    .snd_mcu_rd ( snd_mcu_rd    ),
    // ROM programming
    .prog_addr  ( prog_addr[11:0] ),
    .prom_din   ( prog_data[7:0]  ),
    .prom_we    ( prom_mcu_we     )
);

jtbiocom_sound u_sound (
    .rst            ( rst            ),
    .clk            ( clk24          ),
    .cen_alt        ( cen3           ), // CPU CEN, it should be cen_fm really
    //.cen_alt        ( cen_fm         ), // CPU CEN, it should be cen_fm really
    // cen6    X
    // cen_fm2 X
    // cen_fm  O
    .cen_fm         ( cen_fm         ),
    .cen_fm2        ( cen_fm2        ),
    // Interface with main CPU
    .snd_latch      ( snd_latch      ),
    .nmi_n          ( snd_nmi_n      ),
    // Interface with MCU
    .snd_din        ( snd_din        ),
    .snd_dout       ( snd_dout       ),
    .snd_mcu_wr     ( snd_mcu_wr     ),
    .snd_mcu_rd     ( snd_mcu_rd     ),
    // ROM
    .rom_addr       ( snd_addr       ),
    .rom_data       ( snd_data       ),
    .rom_cs         ( snd_cs         ),
    .rom_ok         ( snd_ok         ),
    // sound output
    .left           ( snd_left       ),
    .right          ( snd_right      ),
    .sample         (     sample     )
);

jtbiocom_video #(
    .OBJ_PAL      (2'b10),
    .PALETTE_PROM (1),
    .SCRWIN       (0)
) u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen12      ( pxl2_cen      ),
    .cen8       ( video_cen8    ),
    .cen6       ( pxl_cen       ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB        ),
    .V          ( V[7:0]        ),
    .H          ( H             ),
    .RnW        ( RnW           ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    // CHAR
    .char_cs    ( char_cs       ),
    .char_dout  ( char_dout     ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_busy  ( char_busy     ),
    .char_ok    ( char_ok       ),
    // SCROLL 1
    .scr1_cs    ( scr1_cs       ),
    .scr1_dout  ( scr1_dout     ),
    .scr1_addr  ( scr1_addr     ),
    .scr1_data  ( scr1_data     ),
    .scr1_busy  ( scr1_busy     ),
    .scr1_hpos  ( scr1_hpos     ),
    .scr1_vpos  ( scr1_vpos     ),
    .scr1_ok    ( scr1_ok       ),
    // SCROLL 2
    .scr2_cs    ( scr2_cs       ),
    .scr2_dout  ( scr2_dout     ),
    .scr2_addr  ( scr2_addr     ),
    .scr2_data  ( scr2_data     ),
    .scr2_busy  ( scr2_busy     ),
    .scr2_hpos  ( scr2_hpos     ),
    .scr2_vpos  ( scr2_vpos     ),
    .scr2_ok    ( scr2_ok       ),
    // OBJ
    .HINIT      ( HINIT         ),
    .obj_AB     ( obj_AB        ),
    .oram_dout  ( oram_dout[11:0] ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .OKOUT      ( OKOUT         ),
    .bus_req    ( obj_br        ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    .col_uw     ( col_uw        ),
    .col_lw     ( col_lw        ),
    .obj_ok     ( obj_ok        ),
    // PROMs
    .prog_addr    ( prog_addr[7:0]),
    .prom_prio_we ( prom_prio_we  ),
    .prom_din     ( prog_data[3:0]),
    // Color Mix
    .preLHBL    ( preLHBL       ),
    .preLVBL    ( preLVBL       ),
    .LHBL_obj   ( LHBL_obj      ),
    .LVBL_obj   ( LVBL_obj      ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .gfx_en     ( gfx_en        ),
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

endmodule
