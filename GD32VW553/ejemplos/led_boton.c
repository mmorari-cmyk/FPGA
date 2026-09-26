/* ============================================================
 *   LED + botón + UART — 立创·GD32VW553 (LCSC)
 *   ============================================================
 *   El LED1 (PC13) parpadea y por el UART (USART0 → CH340 →
 *   /dev/ttyUSB0, 115200) se imprime un contador. Cada pulsación
 *   del botón KEY_UP (PA0) cambia la velocidad del parpadeo
 *   entre lento (500 ms) y rápido (100 ms). El botón se lee por
 *   flanco de subida con antirrebote por software, así que
 *   mantenerlo presionado cuenta como una sola pulsación.
 *   ============================================================ */


/* ------------------------------------------------------------
 *   1. INCLUDES: traer herramientas
 *   <...> = librería estándar de C · "..." = archivos del SDK
 * ------------------------------------------------------------ */

#include <stdio.h>                  /* printf: aquí no sale a la pantalla sino al UART → monitor serie */
#include "nuclei_sdk_soc.h"         /* SDK del chip: pines (gpio_), relojes (rcu_), esperas (delay_1ms) */


/* ------------------------------------------------------------
 *   2. DEFINES: ponerle nombre a los números
 *   #define es un "buscar y reemplazar" antes de compilar.
 *   Si el LED cambia de pin, se cambia solo aquí.
 * ------------------------------------------------------------ */

#define LED_PORT    GPIOC           /* El LED está en el puerto C... */
#define LED_PIN     GPIO_PIN_13     /* ...pin 13 (PC13). Se enciende con 1 (3,3 V) */
#define KEY_PORT    GPIOA           /* El botón KEY_UP está en el puerto A... */
#define KEY_PIN     GPIO_PIN_0      /* ...pin 0 (PA0). Presionado = 3,3 V */
#define DEBOUNCE_MS 10              /* Milisegundos que dura el "rebote" del botón (ver sección 4) */


/* ------------------------------------------------------------
 *   3. board_init(): preparar el hardware
 *   static = esta función solo se usa dentro de este archivo.
 *   void   = no recibe nada y no devuelve nada.
 * ------------------------------------------------------------ */

static void board_init(void)
{
    /* Encender el reloj de los puertos. El chip arranca con todo apagado para
       ahorrar energía: un puerto sin reloj ignora todo lo que le escribas.
       Si el LED no prende, esto es lo primero que hay que revisar. */
    rcu_periph_clock_enable(RCU_GPIOC);                     /* Reloj del puerto C (LED) */
    rcu_periph_clock_enable(RCU_GPIOA);                     /* Reloj del puerto A (botón) */

    /* LED como SALIDA: el chip pone el voltaje en el pin (0 V o 3,3 V) */
    gpio_mode_set(LED_PORT,                                 /* Puerto C */
                  GPIO_MODE_OUTPUT,                         /* Modo salida */
                  GPIO_PUPD_NONE,                           /* Sin resistencia interna: una salida no la necesita */
                  LED_PIN);                                 /* Pin 13 */

    gpio_output_options_set(LED_PORT,                       /* Puerto C */
                            GPIO_OTYPE_PP,                  /* Push-pull: puede dar 3,3 V y también 0 V */
                            GPIO_OSPEED_25MHZ,              /* Velocidad del cambio; para un LED da igual */
                            LED_PIN);                       /* Pin 13 */

    gpio_bit_reset(LED_PORT, LED_PIN);                      /* reset = 0 V → el LED arranca apagado */

    /* Botón como ENTRADA: el chip lee el voltaje del pin.
       El botón conecta PA0 a 3,3 V al presionarlo, pero suelto no lo conecta
       a nada: el pin quedaría "flotando" y leería 0 y 1 al azar. El pull-down
       es una resistencia interna que lo jala suavemente a 0 V:
           suelto = 0     presionado = 1 */
    gpio_mode_set(KEY_PORT,                                 /* Puerto A */
                  GPIO_MODE_INPUT,                          /* Modo entrada */
                  GPIO_PUPD_PULLDOWN,                       /* Resistencia interna a 0 V */
                  KEY_PIN);                                 /* Pin 0 */
}


/* ------------------------------------------------------------
 *   4. key_pressed_edge(): leer el botón BIEN
 *   Resuelve dos problemas de los botones:
 *   - REBOTE: al presionarlo, la lámina de metal rebota unos
 *     milisegundos y el chip ve 0 1 0 1 1 1 (pulsaciones falsas).
 *   - NIVEL: mientras lo mantienes presionado, "¿está presionado?"
 *     responde "sí" miles de veces por segundo.
 *   Devuelve 1 SOLO en el instante en que pasa de suelto a
 *   presionado (flanco de subida). Si lo mantienes 5 segundos,
 *   devuelve 1 una sola vez. Es la misma idea que el "hit" del
 *   juego de la FPGA.
 * ------------------------------------------------------------ */

static int key_pressed_edge(void)
{
    /* static dentro de una función = la variable NO se borra al salir.
       Recuerda su valor entre una llamada y la siguiente, así la función
       sabe cómo estaba el botón la vez anterior. */
    static int last_state = 0;                              /* Último estado confirmado: 0 suelto, 1 presionado */

    int now = (gpio_input_bit_get(KEY_PORT, KEY_PIN) == SET);   /* Leer el pin ahora: SET → 1, RESET → 0 */

    if (now != last_state) {                                /* ¿Cambió respecto a la última vez? */
        delay_1ms(DEBOUNCE_MS);                             /* Puede ser rebote: esperar 10 ms a que se calme... */
        now = (gpio_input_bit_get(KEY_PORT, KEY_PIN) == SET);   /* ...y volver a leer */

        if (now != last_state) {                            /* ¿Sigue cambiado? Entonces el cambio es real */
            last_state = now;                               /* Guardar el nuevo estado */
            return now;                                     /* 1 = se acaba de presionar · 0 = se soltó (no nos interesa) */
        }
    }
    return 0;                                               /* No hubo una pulsación nueva */
}


/* ------------------------------------------------------------
 *   5. main(): el programa principal
 *   Antes de llegar aquí, el SDK ya configuró el reloj del chip
 *   (160 MHz) y el UART para que printf funcione.
 * ------------------------------------------------------------ */

int main(void)
{
    /* uint32_t = entero sin signo de 32 bits (0 a ~4.000 millones).
       En embebidos se usa porque dice exactamente cuántos bits ocupa;
       un "int" puede medir distinto según el chip. */
    uint32_t count = 0;                                     /* Cuántas veces ha parpadeado el LED */
    uint32_t period_ms = 500;                               /* Cada cuántos ms cambia el LED (500 = lento) */
    uint32_t elapsed = 0;                                   /* Cronómetro: ms desde el último cambio del LED */

    board_init();                                           /* Preparar LED y botón (sección 3) */

    /* \r\n = volver al inicio de la línea + bajar una línea (el monitor serie necesita los dos) */
    printf("\r\nGD32VW553 lista. Presiona KEY_UP para cambiar la velocidad.\r\n");

    /* Bucle infinito: un microcontrolador nunca termina, no hay un sistema
       operativo al cual volver. Cada vuelta dura ~1 ms. */
    while (1) {

        if (key_pressed_edge()) {                           /* ¿Se acaba de presionar el botón? */
            /* "if" en una línea: si vale 500 ahora vale 100, si no vale 500 */
            period_ms = (period_ms == 500) ? 100 : 500;
            /* %lu = aquí va un número "unsigned long"; el (unsigned long) convierte la variable a ese tipo */
            printf("Boton: periodo = %lu ms\r\n", (unsigned long)period_ms);
        }

        /* Esperar SOLO 1 ms y no 500 ms. Con delay_1ms(500) el chip quedaría
           bloqueado medio segundo sin leer el botón y las pulsaciones se
           perderían. Con 1 ms + cronómetro revisa el botón cada milisegundo
           y el LED igual cambia cada period_ms: programación NO bloqueante. */
        delay_1ms(1);

        if (++elapsed >= period_ms) {                       /* Sumar 1 ms al cronómetro. ¿Ya pasó el período? */
            elapsed = 0;                                    /* Reiniciar el cronómetro */
            gpio_bit_toggle(LED_PORT, LED_PIN);             /* toggle = invertir: prendido ↔ apagado */
            /* count++ usa el valor y DESPUÉS suma 1: imprime 0, 1, 2... */
            printf("Parpadeo %lu\r\n", (unsigned long)count++);
        }
    }
}
