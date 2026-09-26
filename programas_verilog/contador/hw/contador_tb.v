`timescale 1ns / 1ps

module contador_tb;

    reg clk;
    reg rst;
    reg btn_up;
    reg btn_down;
    wire [3:0] leds;

    // Sobrescribimos CLK_FREQ para simulación (10 ciclos en lugar de 27 millones)
    // para poder ver el incremento/decremento en pocos nanosegundos.
    counter_4bit #(
        .CLK_FREQ(10)
    ) uut (
        .clk(clk),
        .rst(rst),
        .btn_up(btn_up),
        .btn_down(btn_down),
        .leds(leds)
    );

    // Reloj: período de ~37 ns (aprox. 27 MHz)
    always #18.5 clk = ~clk;

    initial begin
        $dumpfile("sim.vcd");
        $dumpvars(0, contador_tb);

        // Estado inicial
        clk = 0;
        rst = 1;        // Reset activo (alto)
        btn_up = 0;
        btn_down = 0;

        #100;
        rst = 0;        // Desactivamos reset

        // Habilitamos cuenta ascendente
        #50;
        btn_up = 1;
        #500;           // Esperamos que pasen varios ciclos y ticks

        // Cambiamos a cuenta descendente
        btn_up = 0;
        btn_down = 1;
        #300;

        $finish;
    end

endmodule
