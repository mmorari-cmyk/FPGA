// ==============================================================================
// Contador de 4 Bits con Divisor de Frecuencia y Control Up/Down
// ==============================================================================

module counter_4bit (
    input wire clk,          // Reloj de entrada (27 MHz)
    input wire rst,          // Botón de reset (asume lógica activa en alto)
    input wire btn_up,       // Botón de incremento (asume lógica activa en alto)
    input wire btn_down,     // Botón de decremento (asume lógica activa en alto)
    output wire [3:0] leds   // Salida a 4 LEDs (lógica activa en bajo)
);

    // Parámetro para el divisor de frecuencia (27,000,000 ciclos = 1 segundo)
    parameter CLK_FREQ = 27_000_000;

    // Registros internos
    reg [24:0] clk_div = 0;  // Contador de 25 bits para soportar hasta 33.5 millones
    reg [3:0] count_reg = 0; // Registro interno para el valor del contador

    // Generación del pulso de habilitación (tick) de 1 segundo
    wire tick = (clk_div == CLK_FREQ - 1);

    // Bloque del divisor de frecuencia
    always @(posedge clk) begin
        if (rst) begin
            clk_div <= 0;
        end else if (tick) begin
            clk_div <= 0;
        end else begin
            clk_div <= clk_div + 1;
        end
    end

    // Bloque del contador de 4 bits
    always @(posedge clk) begin
        if (rst) begin
            count_reg <= 4'b0000;
        end else if (tick) begin
            // Evalúa el estado de los botones cada segundo exacto
            if (btn_up && !btn_down) begin
                count_reg <= count_reg + 1'b1;
            end else if (btn_down && !btn_up) begin
                count_reg <= count_reg - 1'b1;
            end
            // Si ambos o ninguno están presionados, mantiene el valor
        end
    end

    // Asignación a los LEDs: se invierte el registro para lógica activa en bajo
    // (0 en el registro = 1 en el pin = LED apagado; 1 en el registro = 0 en el pin = LED encendido)
    assign leds = ~count_reg;

endmodule
