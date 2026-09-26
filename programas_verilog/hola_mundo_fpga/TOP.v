module TOP (                                                                
    input  wire clk,      // Reloj de 27 MHz (Pin H11)                      
    output wire led       // LED de usuario (Pin N16, activo en bajo)       
);                                                                          
                                                                                
    reg [24:0] contador = 0;                                                
    reg        estado_led = 0;                                              
                                                                                
    always @(posedge clk) begin                                             
        if (contador == 13_500_000 - 1) begin                               
            contador   <= 0;                                                
            estado_led <= ~estado_led;                                      
        end else begin                                                      
            contador   <= contador + 1'b1;                                  
        end                                                                 
    end                                                                     
                                                                                
        // En la Tang Primer 20K los LEDs encienden con 0                       
        assign led = estado_led;                                                
                                                                                
endmodule