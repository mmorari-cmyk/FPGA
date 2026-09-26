// ==============================================================================
// TOP.v - Módulo Contador de 4 Bits para Tang Primer 20K
// ==============================================================================

module TOP (
    input  wire       clk,         // Reloj 27 MHz (Pin H11)
    input  wire       rst_n,       // Botón S1: Reset (Pin T3, activo en bajo 0=pulsado)
    input  wire       btn_up_n,    // Botón S2: Up (Pin T2, activo en bajo 0=pulsado)
    input  wire       btn_down_n,  // Botón S3: Down (Pin D7, activo en bajo 0=pulsado)
    output wire [3:0] led          // LEDs LD2-LD5 (N16, N14, L14, L16, activos en bajo: 0=ON, 1=OFF)
);

    parameter CLK_FREQ = 27_000_000;

    // 1. Inversión de señales físicas de entrada (Pull-Up: 0=presionado, 1=suelto)
    wire rst      = ~rst_n;
    wire btn_up   = ~btn_up_n;
    wire btn_down = ~btn_down_n;

    // 2. Divisor de frecuencia: 1 pulso (tick) cada 1 segundo (27,000,000 ciclos)
    reg [24:0] clk_div = 0;
    wire tick = (clk_div == CLK_FREQ - 1);

    always @(posedge clk) begin
        if (rst) begin
            clk_div <= 0;
        end else if (tick) begin
            clk_div <= 0;
        end else begin
            clk_div <= clk_div + 1'b1;
        end
    end

    // 3. Captura de pulsaciones (Latch):
    // Garantiza que aunque el usuario presione el botón rápidamente (< 1 s),
    // la orden quede guardada y se ejecute en el siguiente tick de 1 segundo.
    reg up_pending   = 0;
    reg down_pending = 0;

    always @(posedge clk) begin
        if (rst) begin
            up_pending   <= 1'b0;
            down_pending <= 1'b0;
        end else begin
            // Si se presiona el botón en cualquier instante, se registra
            if (btn_up)   up_pending   <= 1'b1;
            if (btn_down) down_pending <= 1'b1;

            // Al cumplirse el segundo se limpia, a menos que siga presionado
            if (tick) begin
                up_pending   <= btn_up;
                down_pending <= btn_down;
            end
        end
    end

    // 4. Contador de 4 bits
    reg [3:0] count_reg = 4'b0000;

    always @(posedge clk) begin
        if (rst) begin
            count_reg <= 4'b0000;
        end else if (tick) begin
            if (up_pending && !down_pending) begin
                count_reg <= count_reg + 1'b1;
            end else if (down_pending && !up_pending) begin
                count_reg <= count_reg - 1'b1;
            end
            // Si ninguno o ambos están pendientes, mantiene el valor
        end
    end

    // 5. Salida a los 4 LEDs (Lógica activa en bajo: 0 enciende, 1 apaga)
    assign led = ~count_reg;

endmodule
