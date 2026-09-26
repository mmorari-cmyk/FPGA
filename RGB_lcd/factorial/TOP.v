`timescale 1ns/1ns

module TOP (
    input        CLK,          // Reloj externo 27 MHz (Pin H11)
    input        RESET,        // Boton de reset (Pin T10 - S0)
    input  [2:0] BUTTONS,      // 3 Botones de usuario: S1 (T3), S2 (T2), S3 (D7)
    output [3:0] LEDS,         // 4 LEDs de usuario (N16, N14, L14, L16)
    
    // Interfaz de Pantalla RGB LCD de 40 pines
    output [4:0] lcd_r,
    output [5:0] lcd_g,
    output [4:0] lcd_b,
    output       lcd_de,
    output       lcd_hsync,
    output       lcd_vsync,
    output       lcd_clk,
    output       lcd_bl
);

    // =========================================================================
    // 1. Reloj del Procesador y Reloj de Pantalla
    // =========================================================================
    wire clk_cpu, resetn;
    Clockworks CW (
        .CLK(CLK),
        .RESET(RESET),
        .clk(clk_cpu),
        .resetn(resetn)
    );

    wire clk_lcd;
    pll_40m pll_inst (
        .clkin(CLK),
        .clkout(clk_lcd)
    );

    // Sincronizador de reset para el dominio de 40 MHz de la pantalla
    reg rst_lcd_n_meta = 1'b0;
    reg rst_lcd_n      = 1'b0;
    always @(posedge clk_lcd or negedge resetn) begin
        if (!resetn) begin
            rst_lcd_n_meta <= 1'b0;
            rst_lcd_n      <= 1'b0;
        end else begin
            rst_lcd_n_meta <= 1'b1;
            rst_lcd_n      <= rst_lcd_n_meta;
        end
    end

    // =========================================================================
    // 2. Bus de la CPU FemtoRV32
    // =========================================================================
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    reg  [31:0] mem_rdata;
    wire [3:0]  mem_wmask;
    wire        mem_rstrb;
    wire is_writing = |mem_wmask;
    wire is_reading = mem_rstrb;

    FemtoRV32 CPU (
        .clk(clk_cpu),
        .reset(resetn),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask),
        .mem_rdata(mem_rdata),
        .mem_rstrb(mem_rstrb),
        .mem_rbusy(1'b0),
        .mem_wbusy(1'b0)
    );

    // =========================================================================
    // 3. Decodificador de Memoria (MMIO)
    // =========================================================================
    wire sel_ram  = (mem_addr[17:16] == 2'b00); // 0x0000_xxxx: 1KB BRAM
    wire sel_gpio = (mem_addr[17:16] == 2'b01); // 0x0001_xxxx: LEDs y Botones
    wire sel_lcd  = (mem_addr[17:16] == 2'b11); // 0x0003_xxxx: Registro Color LCD

    // =========================================================================
    // 4. Memoria RAM (firmware en Ensamblador)
    // =========================================================================
    wire [31:0] ram_rdata;
    bram_hex #(
        .MEM_SIZE(256),
        .HEX_FILE("firmware.hex")
    ) RAM (
        .clk(clk_cpu),
        .mem_addr(mem_addr),
        .mem_rdata(ram_rdata),
        .cs(sel_ram),
        .rd(is_reading),
        .wr(is_writing),
        .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask)
    );

    // =========================================================================
    // 5. Periférico GPIO (Escritura = LEDs, Lectura = Botones)
    // =========================================================================
    reg [3:0] led_reg = 4'b0001;
    always @(posedge clk_cpu) begin
        if (!resetn)
            led_reg <= 4'b0001;
        else if (sel_gpio && is_writing)
            led_reg <= mem_wdata[3:0];
    end
    assign LEDS = ~led_reg; // LEDs activos en bajo en Tang Primer

    // =========================================================================
    // 6. Periférico LCD (Color RGB y Modo de Texto OSD)
    // =========================================================================
    reg [23:0] lcd_color_reg = 24'h00FF00; // Inicia en verde
    reg [1:0]  lcd_mode_reg  = 2'd1;        // Inicia en modo 1: "1! = 1"
    always @(posedge clk_cpu) begin
        if (!resetn) begin
            lcd_color_reg <= 24'h00FF00;
            lcd_mode_reg  <= 2'd1;
        end else if (sel_lcd && is_writing) begin
            lcd_color_reg <= mem_wdata[23:0];
            if (mem_wdata[25:24] != 2'b00)
                lcd_mode_reg <= mem_wdata[25:24];
            else if (mem_wdata[16]) // Rojo (0xFF0000)
                lcd_mode_reg <= 2'd2; // 2! = 2
            else if (mem_wdata[0])  // Azul (0x0000FF)
                lcd_mode_reg <= 2'd3; // 3! = 6
            else
                lcd_mode_reg <= 2'd1; // 1! = 1
        end
    end

    // Multiplexor de lectura de la CPU
    always @(*) begin
        if (sel_ram)
            mem_rdata = ram_rdata;
        else if (sel_gpio)
            // Bit [3:0] = LEDs actuales, Bit [6:4] = 3 Botones (invertidos: 1=presionado)
            mem_rdata = {25'b0, ~BUTTONS[2:0], led_reg};
        else if (sel_lcd)
            mem_rdata = {6'b0, lcd_mode_reg, lcd_color_reg};
        else
            mem_rdata = 32'b0;
    end

    // =========================================================================
    // 7. Generador de Sincronismo y Barrido de Video con OSD
    // =========================================================================
    assign lcd_bl = 1'b1; // Encender backlight

    wire [23:0] lcd_rgb_out;
    wire [11:0] xpos, ypos;
    wire [23:0] osd_rgb;

    lcd_osd osd_inst (
        .xpos(xpos),
        .ypos(ypos),
        .mode(lcd_mode_reg),
        .bg_color(lcd_color_reg),
        .rgb_out(osd_rgb)
    );

    lcd_ctrl lcd_ctrl_inst (
        .clk(clk_lcd),
        .rst_n(rst_lcd_n),
        .lcd_data(osd_rgb), // Conectado a la salida del OSD
        .lcd_clk(lcd_clk),
        .lcd_hs(lcd_hsync),
        .lcd_vs(lcd_vsync),
        .lcd_de(lcd_de),
        .lcd_rgb(lcd_rgb_out),
        .lcd_xpos(xpos),
        .lcd_ypos(ypos)
    );

    // Mapeo RGB888 a RGB565: Tomar los bits más significativos (MSB) de cada componente
    assign lcd_r[4:0] = lcd_rgb_out[23:19];
    assign lcd_g[5:0] = lcd_rgb_out[15:10];
    assign lcd_b[4:0] = lcd_rgb_out[7:3];

endmodule

// =============================================================================
// Módulo: lcd_osd - Generador de Texto OSD en Pantalla 800x480
// Dibuja en grande y centrado:
//   Modo 1: "1! = 1"
//   Modo 2: "2! = 2"
//   Modo 3: "3! = 6"
// =============================================================================
module lcd_osd (
    input  wire [11:0] xpos,
    input  wire [11:0] ypos,
    input  wire [1:0]  mode,       // 1: "1! = 1", 2: "2! = 2", 3: "3! = 6"
    input  wire [23:0] bg_color,   // Color de fondo
    output wire [23:0] rgb_out     // Salida de color
);

    // Caja de texto centrada en 800x480:
    // Ancho: 6 caracteres * 64 px = 384 px (X: 208 a 591)
    // Alto:  128 px (Y: 176 a 303)
    wire in_box = (xpos >= 12'd208 && xpos < 12'd592) &&
                  (ypos >= 12'd176 && ypos < 12'd304);

    wire [8:0] rel_x = xpos - 12'd208;
    wire [6:0] rel_y = ypos - 12'd176;

    wire [2:0] char_idx = rel_x[8:6]; // 0 a 5 (6 caracteres de 64 px)
    wire [2:0] font_x   = rel_x[5:3]; // 0 a 7 (8 px de escala por bit)
    wire [3:0] font_y   = rel_y[6:3]; // 0 a 15 (16 filas de 8 px de alto)

    localparam GLYPH_SPACE = 3'd0;
    localparam GLYPH_EXCL  = 3'd1;
    localparam GLYPH_EQUAL = 3'd2;
    localparam GLYPH_1     = 3'd3;
    localparam GLYPH_2     = 3'd4;
    localparam GLYPH_3     = 3'd5;
    localparam GLYPH_6     = 3'd6;

    reg [2:0] current_glyph;
    always @(*) begin
        case (char_idx)
            3'd0: begin
                case (mode)
                    2'd2:    current_glyph = GLYPH_2;
                    2'd3:    current_glyph = GLYPH_3;
                    default: current_glyph = GLYPH_1;
                endcase
            end
            3'd1: current_glyph = GLYPH_EXCL;  // '!'
            3'd2: current_glyph = GLYPH_SPACE; // ' '
            3'd3: current_glyph = GLYPH_EQUAL; // '='
            3'd4: current_glyph = GLYPH_SPACE; // ' '
            3'd5: begin
                case (mode)
                    2'd2:    current_glyph = GLYPH_2;
                    2'd3:    current_glyph = GLYPH_6;
                    default: current_glyph = GLYPH_1;
                endcase
            end
            default: current_glyph = GLYPH_SPACE;
        endcase
    end

    // ROM de matriz de fuentes 8x16 para los glifos requeridos
    reg [7:0] font_row;
    always @(*) begin
        case (current_glyph)
            GLYPH_SPACE: font_row = 8'h00;

            GLYPH_EXCL: begin // '!'
                case (font_y)
                    4'd1, 4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd7: font_row = 8'b00011000;
                    4'd9, 4'd10:                              font_row = 8'b00011000;
                    default:                                   font_row = 8'h00;
                endcase
            end

            GLYPH_EQUAL: begin // '='
                case (font_y)
                    4'd4, 4'd5: font_row = 8'b01111110;
                    4'd8, 4'd9: font_row = 8'b01111110;
                    default:    font_row = 8'h00;
                endcase
            end

            GLYPH_1: begin // '1'
                case (font_y)
                    4'd1:         font_row = 8'b00001100;
                    4'd2:         font_row = 8'b00011100;
                    4'd3:         font_row = 8'b00111100;
                    4'd4, 4'd5, 4'd6, 4'd7, 4'd8, 4'd9, 4'd10: font_row = 8'b00001100;
                    4'd11, 4'd12: font_row = 8'b00111111;
                    default:      font_row = 8'h00;
                endcase
            end

            GLYPH_2: begin // '2'
                case (font_y)
                    4'd1:         font_row = 8'b00111100;
                    4'd2, 4'd3:   font_row = 8'b01100110;
                    4'd4:         font_row = 8'b00000110;
                    4'd5:         font_row = 8'b00001100;
                    4'd6:         font_row = 8'b00011000;
                    4'd7:         font_row = 8'b00110000;
                    4'd8, 4'd9:   font_row = 8'b01100000;
                    4'd10, 4'd11: font_row = 8'b01111110;
                    default:      font_row = 8'h00;
                endcase
            end

            GLYPH_3: begin // '3'
                case (font_y)
                    4'd1:         font_row = 8'b00111100;
                    4'd2:         font_row = 8'b01100110;
                    4'd3:         font_row = 8'b00000110;
                    4'd4:         font_row = 8'b00001100;
                    4'd5:         font_row = 8'b00011100;
                    4'd6:         font_row = 8'b00000110;
                    4'd7:         font_row = 8'b00000110;
                    4'd8, 4'd9:   font_row = 8'b01100110;
                    4'd10, 4'd11: font_row = 8'b00111100;
                    default:      font_row = 8'h00;
                endcase
            end

            GLYPH_6: begin // '6'
                case (font_y)
                    4'd1:         font_row = 8'b00111100;
                    4'd2, 4'd3:   font_row = 8'b01100000;
                    4'd4:         font_row = 8'b01111100;
                    4'd5, 4'd6, 4'd7, 4'd8, 4'd9: font_row = 8'b01100110;
                    4'd10, 4'd11: font_row = 8'b00111100;
                    default:      font_row = 8'h00;
                endcase
            end

            default: font_row = 8'h00;
        endcase
    end

    // El pixel está encendido si el bit correspondiente en la fila de fuente es 1
    wire pixel_on = in_box & font_row[3'd7 - font_x];

    // Texto en blanco puro (0xFFFFFF), fondo según bg_color
    assign rgb_out = pixel_on ? 24'hFFFFFF : bg_color;

endmodule
