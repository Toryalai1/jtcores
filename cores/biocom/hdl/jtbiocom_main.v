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
    Date: 12-9-2019 */

// Bionic Commando: Main CPU


module jtbiocom_main(
    input              rst,
    input              clk,
    input              clk_mcu,
    output             cen12,
    output             cen12b,
    (*direct_enable *) output cpu_cen,
    // Timing
    output  reg        flip,
    input   [8:0]      V,
    input              LHBL,
    input              LVBL,
    // Sound
    output  reg  [7:0] snd_latch,
    //output  reg  [7:0] snd_hack,
    output  reg        snd_nmi_n,
    // Characters
    input        [7:0] char_dout,
    output      [15:0] cpu_dout,
    output  reg        char_cs,
    input              char_busy,
    // scroll
    input   [7:0]      scr1_dout,
    input   [7:0]      scr2_dout,
    output  reg        scr1_cs,
    output  reg        scr2_cs,
    input              scr1_busy,
    input              scr2_busy,
    output reg [9:0]   scr1_hpos,
    output reg [9:0]   scr1_vpos,
    output reg [8:0]   scr2_hpos,
    output reg [8:0]   scr2_vpos,
    // cabinet I/O
    input   [5:0]      joystick1,
    input   [5:0]      joystick2,
    input   [1:0]      start_button,
    input   [1:0]      coin_input,
    // BUS sharing
    output  [13:1]     cpu_AB,
    output  [15:0]     oram_dout,
    input   [13:1]     obj_AB,
    output             RnW,
    output  reg        OKOUT,
    input              obj_br,   // Request bus
    output             bus_ack,  // bus acknowledge for Object engine
    input              blcnten,  // bus line counter enable
    // MCU interface
    input              mcu_cen,
    input              mcu_brn,
    input      [ 7:0]  mcu_dout,
    output reg [ 7:0]  mcu_din,
    input      [16:1]  mcu_addr,
    input              mcu_wr,
    input              mcu_DMAn,
    output  reg        mcu_DMAONn,
    // Palette
    output             col_uw,
    output             col_lw,
    // ROM access
    output  reg        rom_cs,
    output      [17:1] rom_addr,
    input       [15:0] rom_data,
    input              rom_ok,
    // DIP switches
    input              dip_pause,
    input    [7:0]     dipsw_a,
    input    [7:0]     dipsw_b
);

wire [19:1] A;
wire [3:0] ncA;

`ifdef SIMULATION
wire [24:0] A_full = {ncA, A,1'b0};
`endif
wire [15:0] wram_dout;
reg  [15:0] cpu_din;
wire        BRn, BGACKn, BGn;
reg         io_cs, ram_cs, obj_cs, col_cs;
reg         scr1hpos_cs, scr2hpos_cs, scr1vpos_cs, scr2vpos_cs;
wire        ASn;

wire mreq_n, rfsh_n, busak_n;
reg  BERRn;

// high during DMA transfer
wire BUSn, UDSn, LDSn;
wire UDSWn = RnW | UDSn;
wire LDSWn = RnW | LDSn;

assign BUSn    = ASn | (LDSn & UDSn);
assign col_uw  = col_cs & ~UDSWn;
assign col_lw  = col_cs & ~LDSWn;
assign cpu_cen = cen12;

wire CPUbus = !blcnten && mcu_DMAn; // main CPU in control of the bus
reg  [16:1] mcu_addr_s;
wire [16:1] Aeff   = CPUbus ? A[16:1] : mcu_addr_s;

always @(posedge clk) mcu_addr_s <= mcu_addr; // synchronizer

always @(*) begin
    ram_cs        = 1'b0;
    obj_cs        = 1'b0;
    col_cs        = 1'b0;
    io_cs         = 1'b0;
    char_cs       = 1'b0;
    scr1_cs       = 1'b0;
    scr2_cs       = 1'b0;
    OKOUT         = 1'b0;
    mcu_DMAONn    = 1'b1;   // for once, I leave the original active low setting
    scr1vpos_cs   = 1'b0;
    scr2vpos_cs   = 1'b0;
    scr1hpos_cs   = 1'b0;
    scr2hpos_cs   = 1'b0;

    if( !CPUbus || A[19:17]==3'b111 )
        case( Aeff[16:14] )  // 111X
            3'd0:   obj_cs  = 1'b1; // E_0000
            3'd1:   io_cs   = 1'b1; // E_4000
            3'd2: if( !UDSWn && !LDSWn && Aeff[4]) begin // E_8010
                // scrpt_cs
                // $display("SCRPTn");
                case( A[3:1]) // SCRPTn in the schematics
                        3'd0: scr1hpos_cs = 1'b1;
                        3'd1: scr1vpos_cs = 1'b1;
                        3'd2: scr2hpos_cs = 1'b1;
                        3'd3: scr2vpos_cs = 1'b1;
                        3'd4: begin
                            OKOUT       = 1'b1;
                            //$display("OKOUT");
                        end
                        3'd5: begin
                            mcu_DMAONn  = 1'b0; // to MCU
                            //$display("mcu_DOMAONn");
                        end
                    default:;
                endcase
            end
            3'd3:   char_cs = 1'b1; // E_C000
            3'd4:   scr1_cs = 1'b1; // F_0000
            3'd5:   scr2_cs = 1'b1; // F_4000
            3'd6:   col_cs  = 1'b1; // F_8000
            3'd7:   ram_cs  = 1'b1; // F_C000
        endcase
end

always @(*) begin
    rom_cs        = 1'b0;
    BERRn         = 1'b1;
    // address decoder is not shared with MCU contrary to the original design
    if( CPUbus ) case(A[19:18])
            2'd0: rom_cs = 1'b1;
            2'd1, 2'd2: BERRn = ASn;
        endcase
end

// SCROLL H/V POSITION
always @(posedge clk, posedge rst) begin
    if( rst ) begin        
        scr1_hpos <= 10'd0;
        scr1_vpos <= 10'd0;
        scr2_hpos <= 9'd0;
        scr2_vpos <= 9'd0;
    end else if(cpu_cen) begin
        if( scr1hpos_cs && !RnW) scr1_hpos <= cpu_dout[9:0];
        if( scr1vpos_cs && !RnW) scr1_vpos <= cpu_dout[9:0];
        if( scr2hpos_cs && !RnW) scr2_hpos <= cpu_dout[8:0];
        if( scr2vpos_cs && !RnW) scr2_vpos <= cpu_dout[8:0];
    end
end

// special registers
always @(posedge clk) begin
    if( rst ) begin
        flip         <= 1'b0;
        snd_latch    <= 8'b0;
        snd_nmi_n    <= 1'b1;
    end
    else if(cpu_cen) begin
        snd_nmi_n  <= 1'b1;
        if( !UDSWn && io_cs)
            case( { A[1]} )
                1'b0: flip      <= cpu_dout[8];
                1'b1: begin
                    // sound latch is updated here on the actual PCB
                    // however, the main CPU software never writes a
                    // value here. This is only used to trigger the NMI
                    // in practice
                    snd_latch <= cpu_dout[7:0]; // real PCB behaviour
                    snd_nmi_n  <= 1'b0;
                end
            endcase
        // Hack to capture the sound code that is sent to the MCU
        // if( !LDSWn && work_A==13'h1ffc && ram_cs)
        //     snd_hack <= cpu_dout[7:0]; // hack
    end
end

reg [15:0] cabinet_input;

always @(*) /*if(cpu_cen)*/ begin
    cabinet_input = (!mcu_DMAn ? mcu_addr[1] : A[1]) ?
        { dipsw_b, dipsw_a } :
        { coin_input[0], coin_input[1],        // COINS
          start_button[0], start_button[1],    // START
          { joystick1[3:0], joystick1[4], joystick1[5]},   //  2 buttons
          { joystick2[3:0], joystick2[4], joystick2[5]} };
end

/////////////////////////////////////////////////////
// MCU DMA data output mux

always @(posedge clk_mcu) begin
    mcu_din <= cpu_din[7:0];
end

/////////////////////////////////////////////////////
// Work RAM, 16kB
wire [1:0] wram_dsn = {2{ram_cs}} & ~{UDSWn, LDSWn};
wire       wmcu_wr  = mcu_wr & ram_cs;

jtframe_dual_ram16 #(.aw(13)) u_work_ram (
    .clk0   ( clk            ),
    .clk1   ( clk_mcu        ),
    // Port 0: CPU
    .data0  ( cpu_dout       ),
    .addr0  ( Aeff[13:1]     ),
    .we0    ( wram_dsn       ),
    .q0     ( wram_dout      ),
    // Port 1: MCU
    .data1  ( { 8'hff, mcu_dout} ) ,
    .addr1  ( mcu_addr[13:1] ),
    .we1    ( {1'b0,wmcu_wr} ),
    .q1     (                )
);

/////////////////////////////////////////////////////
// Object RAM, 4kB
assign cpu_AB = Aeff[13:1];

wire [10:0] oram_addr = blcnten ? obj_AB[11:1] : Aeff[11:1];
wire [ 1:0] oram_dsn = {2{obj_cs}} & ~{UDSWn, LDSWn};
wire        omcu_wr  = mcu_wr & obj_cs;

jtframe_dual_ram16 #(.aw(11)) u_obj_ram (
    .clk0   ( clk            ),
    .clk1   ( clk_mcu        ),
    // Port 0: CPU or Object DMA
    .data0  ( cpu_dout       ),
    .addr0  ( oram_addr      ),
    .we0    ( oram_dsn       ),
    .q0     ( oram_dout      ),
    // Port 1: MCU
    .data1  ( { 8'hff, mcu_dout} ) ,
    .addr1  ( mcu_addr[11:1] ),
    .we1    ( {1'b0,omcu_wr} ),
    .q1     (                )
);

// Data bus input
reg  [ 7:0] video_dout;
wire        video_cs = char_cs | scr2_cs | scr1_cs;
reg  [15:0] owram_dout;
wire        owram_cs = obj_cs | ram_cs;

always @(posedge clk) begin
    case( {scr2_cs, scr1_cs} )
        2'b10:   video_dout <= scr2_dout;
        2'b01:   video_dout <= scr1_dout;
        default: video_dout <= char_dout;
    endcase
    owram_dout <= obj_cs ? oram_dout : wram_dout;
end

always @(*)
    case( {owram_cs, video_cs, io_cs} )
        3'b100:  cpu_din = owram_dout;
        3'b010:  cpu_din = { 8'hff, video_dout };
        3'b001:  cpu_din = cabinet_input;
        default: cpu_din = rom_data;
    endcase

assign rom_addr = A[17:1];

// DTACKn generation
wire       inta_n;
reg  [7:0] io_busy_cnt;
wire       io_busy = io_busy_cnt[0];
wire       bus_cs    = |{ rom_cs, scr1_cs, scr2_cs, char_cs };
// io_busy must be bus_legit or it will halt the machine
wire       bus_legit = |{scr1_busy, scr2_busy, char_busy, io_busy};
wire       bus_busy  = |{ rom_cs & ~rom_ok, bus_legit };

// DTACK is also held down during IO access in order to make
// the NMI request to the Z80 CPU long enough
// If the Z80 misses these requests it will not play any sound at all.
always @(posedge clk, posedge rst) begin : io_busy_gen
    reg       last_iocs;
    if( rst ) begin
        io_busy_cnt <= 8'd0;
        last_iocs   <= 1'b0;
    end else if(cpu_cen) begin
        last_iocs <= io_cs;
        if( io_cs && !last_iocs ) 
            io_busy_cnt <= ~8'd0;
        else 
            io_busy_cnt <= io_busy_cnt>>1;
    end
end

wire DTACKn;

jtframe_68kdtack u_dtack( // cen = 12MHz
    .rst        ( rst        ),
    .clk        ( clk        ),
    .num        ( 5'd1       ),
    .den        ( 5'd4       ),
    .cpu_cen    ( cen12      ),
    .cpu_cenb   ( cen12b     ),
    .bus_cs     ( bus_cs     ),
    .bus_busy   ( bus_busy   ),
    .bus_legit  ( bus_legit  ),
    .ASn        ( ASn        ),
    .DSn        ({UDSn,LDSn} ),
    .DTACKn     ( DTACKn     )
);

// interrupt generation
reg        int1, int2;
wire [2:0] FC;
assign inta_n = ~&{ FC[2], FC[1], FC[0], ~ASn }; // interrupt ack.

always @(posedge clk, posedge rst) begin : int_gen
    reg last_LVBL, last_V256;
    if( rst ) begin
        int1 <= 1'b1;
        int2 <= 1'b1;
    end else begin
        last_LVBL <= LVBL;
        last_V256 <= V[8];

        if( !inta_n ) begin
            int1 <= 1'b1;
            int2 <= 1'b1;
        end
        else if(dip_pause) begin
            if( V[8] && !last_V256 ) int2 <= 1'b0;
            if( !LVBL && last_LVBL ) int1 <= 1'b0;
        end
    end
end

// Original design uses HALT signal instead of BR/BG/BGACK triad
// but fx68k does not support it, so HALT operation is implemented
// through regular bus arbitrion

wire [1:0] dev_br = { ~mcu_brn, obj_br };
assign bus_ack = ~BGACKn;

jtframe_68kdma #(.BW(2)) u_arbitration(
    .clk        (  clk          ),
    .rst        (  rst          ),
    .cen        (  cen12b       ),
    .cpu_BRn    (  BRn          ),
    .cpu_BGACKn (  BGACKn       ),
    .cpu_BGn    (  BGn          ),
    .cpu_ASn    (  ASn          ),
    .cpu_DTACKn (  DTACKn       ),
    .dev_br     (  dev_br       )
);

fx68k u_cpu(
    .clk        ( clk         ),
    .extReset   ( rst         ),
    .pwrUp      ( rst         ),
    .enPhi1     ( cen12       ),
    .enPhi2     ( cen12b      ),
    .HALTn      ( 1'b1        ),

    // Buses
    .eab        ( { ncA, A }  ),
    .iEdb       ( cpu_din     ),
    .oEdb       ( cpu_dout    ),


    .eRWn       ( RnW         ),
    .LDSn       ( LDSn        ),
    .UDSn       ( UDSn        ),
    .ASn        ( ASn         ),
    .VPAn       ( inta_n      ),
    .FC0        ( FC[0]       ),
    .FC1        ( FC[1]       ),
    .FC2        ( FC[2]       ),

    .BERRn      ( BERRn       ),
    // Bus arbitrion
    .BRn        ( BRn         ),
    .BGACKn     ( BGACKn      ),
    .BGn        ( BGn         ),

    .DTACKn     ( DTACKn      ),
    .IPL0n      ( 1'b1        ),
    .IPL1n      ( int1        ),
    .IPL2n      ( int2        ),

    // Unused
    .oRESETn    (             ),
    .oHALTEDn   (             ),
    .VMAn       (             ),
    .E          (             )
);

endmodule