/* ============================================================
 *   Traductor Morse — 立创·GD32VW553 (LCSC)
 *   ============================================================
 *   Funciona en los dos sentidos:
 *   1) TEXTO → LUZ: escribes una frase en el monitor serie y
 *      presionas Enter. La placa la traduce a Morse, la muestra
 *      como puntos y rayas y la "dice" con el LED (PC13).
 *   2) BOTÓN → TEXTO: tocas Morse con KEY_UP (PA0). Un toque
 *      corto es un punto y uno largo una raya. Al hacer una pausa
 *      la placa traduce la letra y la imprime en el monitor.
 *   ============================================================ */


/* ------------------------------------------------------------
 *   1. INCLUDES
 * ------------------------------------------------------------ */

#include <stdio.h>                  /* printf: imprime por el UART al monitor serie */
#include <string.h>                 /* strcmp: comparar textos (para descifrar letras) */
#include "nuclei_sdk_soc.h"         /* SDK del chip: pines, relojes, UART y SysTimer */


/* ------------------------------------------------------------
 *   2. DEFINES: pines y tiempos
 *   En Morse todo se mide en "unidades" de tiempo:
 *     punto = 1 unidad encendido     raya = 3 unidades encendido
 *     pausa entre punto/raya = 1     pausa entre letras = 3
 *     pausa entre palabras = 7
 * ------------------------------------------------------------ */

#define LED_PORT     GPIOC          /* LED1 en PC13... */
#define LED_PIN      GPIO_PIN_13    /* ...se enciende con 1 */
#define KEY_PORT     GPIOA          /* Botón KEY_UP en PA0... */
#define KEY_PIN      GPIO_PIN_0     /* ...presionado = 1 */

#define UNIT_MS      150            /* Duración de 1 unidad Morse al transmitir (150 ms) */
#define DEBOUNCE_MS  20             /* Tiempo que el botón debe estar quieto para creerle */

/* Al leer el botón, los humanos no somos exactos: usamos límites con margen */
#define DASH_MIN_MS  300            /* Toque de 300 ms o más = raya; menos = punto */
#define LETTER_GAP_MS 700           /* Pausa de 700 ms sin tocar = terminó la letra */
#define WORD_GAP_MS  2000           /* Pausa de 2 s sin tocar = terminó la palabra (espacio) */

#define LINE_MAX     64             /* Máximo de caracteres por frase escrita */
#define SYMBOLS_MAX  6              /* Máximo de puntos/rayas por letra (los números usan 5) */
#define RX_BUF_SIZE  128            /* Letras recibidas que se pueden guardar mientras el programa está ocupado */


/* ------------------------------------------------------------
 *   3. TABLA MORSE
 *   Un arreglo de textos: la posición 0 es la A, la 1 la B...
 *   y después vienen los números 0 a 9.
 *   "const" = no cambia nunca, así que se queda en la memoria
 *   flash y no gasta RAM.
 * ------------------------------------------------------------ */

static const char *const MORSE_LETTERS[26] = {
    ".-",   "-...", "-.-.", "-..",  ".",    "..-.", "--.",  "....", /* A B C D E F G H */
    "..",   ".---", "-.-",  ".-..", "--",   "-.",   "---",  ".--.", /* I J K L M N O P */
    "--.-", ".-.",  "...",  "-",    "..-",  "...-", ".--",  "-..-", /* Q R S T U V W X */
    "-.--", "--.."                                                  /* Y Z             */
};

static const char *const MORSE_DIGITS[10] = {
    "-----", ".----", "..---", "...--", "....-",                    /* 0 1 2 3 4 */
    ".....", "-....", "--...", "---..", "----."                     /* 5 6 7 8 9 */
};


/* ------------------------------------------------------------
 *   4. FUNCIONES DE APOYO: UART Y TIEMPO
 *   Problema: el UART del chip guarda UNA sola letra. A 115200
 *   baudios llega una letra cada ~87 microsegundos; si el programa
 *   está esperando (delay) y no la lee a tiempo, la siguiente la
 *   pisa y se pierde.
 *   Solución: un "buffer circular" (una fila de espera) y una
 *   función de espera propia que, mientras espera, sigue sacando
 *   letras del UART y las guarda en la fila.
 * ------------------------------------------------------------ */

static char rx_buf[RX_BUF_SIZE];                                /* La fila de letras recibidas */
static uint32_t rx_head = 0;                                    /* Dónde se guarda la próxima letra que llega */
static uint32_t rx_tail = 0;                                    /* Dónde está la próxima letra por leer */

/* Pasar al buffer todo lo que el UART tenga recibido. Se llama muy seguido */
static void uart_poll(void)
{
    while (usart_flag_get(USART0, USART_FLAG_RBNE) == SET) {    /* RBNE = "hay una letra recibida" */
        char c = (char)(usart_data_receive(USART0) & 0xFF);     /* Sacarla del UART (8 bits) */
        uint32_t next = (rx_head + 1) % RX_BUF_SIZE;            /* Siguiente posición; % hace que dé la vuelta al llegar al final */
        if (next != rx_tail) {                                  /* Si la fila no está llena... */
            rx_buf[rx_head] = c;                                /* ...guardar la letra */
            rx_head = next;
        }
    }
    if (usart_flag_get(USART0, USART_FLAG_ORERR) == SET) {      /* ORERR = se perdió una letra (llegó otra antes de leerla) */
        usart_flag_clear(USART0, USART_FLAG_ORERR);             /* Limpiar el error; si no, el UART deja de recibir */
    }
}

/* Sacar una letra de la fila. Devuelve la letra, o -1 si la fila está vacía */
static int uart_getc(void)
{
    uart_poll();                                                /* Primero traer lo que haya llegado */
    if (rx_tail == rx_head) {                                   /* Inicio = fin → fila vacía */
        return -1;
    }
    char c = rx_buf[rx_tail];                                   /* Tomar la letra más antigua */
    rx_tail = (rx_tail + 1) % RX_BUF_SIZE;                      /* Avanzar (y dar la vuelta si toca) */
    return (int)(unsigned char)c;
}

/* Enviar UNA letra por el UART al instante (printf a veces la guarda hasta ver un "\n") */
static void uart_putc(char c)
{
    while (usart_flag_get(USART0, USART_FLAG_TBE) == RESET) {   /* TBE = "el UART está libre para enviar" */
        uart_poll();                                            /* Mientras espera, no dejar de recibir */
    }
    usart_data_transmit(USART0, (uint16_t)c);                   /* Mandar el carácter */
}

/* Esperar "ms" milisegundos SIN dejar de revisar el UART.
   Reemplaza a delay_1ms(), que mientras espera no hace nada más.
   Usa el SysTimer: un contador del núcleo RISC-V que sube solo,
   SOC_TIMER_FREQ veces por segundo (reloj del chip / 4 = 40 MHz). */
static void wait_ms(uint32_t ms)
{
    uint64_t start = SysTimer_GetLoadValue();                   /* Leer el contador ahora */
    uint64_t ticks = (uint64_t)ms * (SOC_TIMER_FREQ / 1000);    /* Cuántas cuentas equivalen a "ms" */
    while (SysTimer_GetLoadValue() - start < ticks) {           /* Hasta que haya subido lo suficiente... */
        uart_poll();                                            /* ...seguir recibiendo letras */
    }
}


/* ------------------------------------------------------------
 *   5. FUNCIONES DE APOYO: TRADUCIR
 * ------------------------------------------------------------ */

/* Letra → Morse. Devuelve el texto de puntos y rayas, o NULL si no existe */
static const char *char_to_morse(char c)
{
    if (c >= 'a' && c <= 'z') {                                 /* Minúscula → mayúscula */
        c = (char)(c - 'a' + 'A');                              /* En ASCII están separadas por 32 */
    }
    if (c >= 'A' && c <= 'Z') {
        return MORSE_LETTERS[c - 'A'];                          /* 'A'-'A'=0, 'B'-'A'=1 ... posición en la tabla */
    }
    if (c >= '0' && c <= '9') {
        return MORSE_DIGITS[c - '0'];                           /* Igual para los números */
    }
    return NULL;                                                /* Signo que no está en la tabla */
}

/* Morse → letra. Busca en las tablas; devuelve '?' si no la encuentra */
static char morse_to_char(const char *code)
{
    for (int i = 0; i < 26; i++) {                              /* Recorrer las 26 letras */
        if (strcmp(code, MORSE_LETTERS[i]) == 0) {              /* strcmp da 0 cuando son iguales */
            return (char)('A' + i);                             /* Posición 0 → 'A', 1 → 'B'... */
        }
    }
    for (int i = 0; i < 10; i++) {                              /* Recorrer los 10 números */
        if (strcmp(code, MORSE_DIGITS[i]) == 0) {
            return (char)('0' + i);
        }
    }
    return '?';                                                 /* Combinación que no existe */
}


/* ------------------------------------------------------------
 *   6. TEXTO → LUZ
 * ------------------------------------------------------------ */

/* Encender el LED "units" unidades y luego apagarlo 1 unidad (la pausa entre símbolos) */
static void led_pulse(uint32_t units)
{
    gpio_bit_set(LED_PORT, LED_PIN);                            /* Encender */
    wait_ms(units * UNIT_MS);                                   /* Punto = 1 unidad, raya = 3 */
    gpio_bit_reset(LED_PORT, LED_PIN);                          /* Apagar */
    wait_ms(UNIT_MS);                                           /* Pausa de 1 unidad */
}

/* Traducir y transmitir una frase completa con el LED */
static void send_text(const char *text)
{
    printf("Morse: ");
    for (int i = 0; text[i] != '\0'; i++) {                     /* Recorrer letra por letra hasta el final */
        if (text[i] == ' ') {                                   /* Espacio = pausa entre palabras */
            printf("/ ");                                       /* En Morse escrito se marca con "/" */
            wait_ms(4 * UNIT_MS);                               /* 7 en total: ya se esperaron 3 al cerrar la letra anterior */
            continue;                                           /* Pasar a la siguiente letra */
        }

        const char *code = char_to_morse(text[i]);              /* Buscar el código de la letra */
        if (code == NULL) {                                     /* Signo raro (ñ, tilde, coma...) */
            printf("? ");
            continue;                                           /* Se salta */
        }

        printf("%s ", code);                                    /* Mostrar los puntos y rayas */
        fflush(stdout);                                         /* Mandarlo ya, sin esperar el fin de línea */
        for (int j = 0; code[j] != '\0'; j++) {                 /* Recorrer cada punto o raya */
            led_pulse(code[j] == '.' ? 1 : 3);                  /* Punto: 1 unidad · Raya: 3 unidades */
        }
        wait_ms(2 * UNIT_MS);                                   /* Pausa entre letras = 3 (1 ya se esperó en led_pulse) */
    }
    printf("\r\nListo.\r\n> ");
    fflush(stdout);                                             /* Mostrar el "> " ya, sin esperar un salto de línea */
}


/* ------------------------------------------------------------
 *   7. BOTÓN: leerlo sin rebotes, sin bloquear el programa
 *   Se llama una vez por milisegundo. Solo acepta un cambio
 *   cuando el botón lleva DEBOUNCE_MS seguidos en el mismo
 *   valor, así los rebotes (que duran pocos ms) se ignoran.
 * ------------------------------------------------------------ */

static int key_update(void)
{
    static int stable = 0;                                      /* Estado aceptado: 0 suelto, 1 presionado */
    static uint32_t count = 0;                                  /* ms seguidos que la lectura lleva distinta */

    int raw = (gpio_input_bit_get(KEY_PORT, KEY_PIN) == SET);   /* Lectura cruda del pin */

    if (raw != stable) {                                        /* La lectura no coincide con lo aceptado */
        if (++count >= DEBOUNCE_MS) {                           /* ¿Ya lleva suficientes ms así? */
            stable = raw;                                       /* Sí: el cambio es real */
            count = 0;
        }
    } else {
        count = 0;                                              /* Volvió al valor de antes: era rebote */
    }
    return stable;
}


/* ------------------------------------------------------------
 *   8. INICIALIZACIÓN DEL HARDWARE
 * ------------------------------------------------------------ */

static void board_init(void)
{
    rcu_periph_clock_enable(RCU_GPIOC);                         /* Reloj del puerto C (LED) */
    rcu_periph_clock_enable(RCU_GPIOA);                         /* Reloj del puerto A (botón) */

    gpio_mode_set(LED_PORT, GPIO_MODE_OUTPUT, GPIO_PUPD_NONE, LED_PIN);             /* LED como salida */
    gpio_output_options_set(LED_PORT, GPIO_OTYPE_PP, GPIO_OSPEED_25MHZ, LED_PIN);   /* Push-pull */
    gpio_bit_reset(LED_PORT, LED_PIN);                                              /* Arrancar apagado */

    gpio_mode_set(KEY_PORT, GPIO_MODE_INPUT, GPIO_PUPD_PULLDOWN, KEY_PIN);          /* Botón como entrada con pull-down */

    /* El UART (USART0, 115200) ya lo configuró el SDK antes de main() */
}


/* ------------------------------------------------------------
 *   9. PROGRAMA PRINCIPAL
 *   Cada vuelta del while dura ~1 ms. En cada vuelta:
 *   a) revisa si llegó texto del PC
 *   b) revisa el botón y mide cuánto dura cada toque y cada pausa
 * ------------------------------------------------------------ */

int main(void)
{
    char line[LINE_MAX];                                        /* Frase que se está escribiendo en el PC */
    uint32_t line_len = 0;                                      /* Cuántas letras lleva */

    char symbols[SYMBOLS_MAX + 1];                              /* Puntos y rayas tocados con el botón (+1 para el '\0') */
    uint32_t symbols_len = 0;                                   /* Cuántos lleva */

    int key_before = 0;                                         /* Estado del botón en la vuelta anterior */
    uint32_t press_ms = 0;                                      /* Cuánto lleva presionado */
    uint32_t idle_ms = 0;                                       /* Cuánto lleva suelto */
    int word_open = 0;                                          /* 1 = se escribió algo con el botón y falta el espacio */

    board_init();

    printf("\r\n=== Traductor Morse GD32VW553 ===\r\n");
    printf("Escribe una frase y presiona Enter -> el LED la transmite.\r\n");
    printf("O toca Morse con KEY_UP: corto = punto, largo = raya.\r\n> ");
    fflush(stdout);                                             /* Mostrar el "> " ya */

    while (1) {

        /* ---------- a) TEXTO DESDE EL PC ---------- */
        int c = uart_getc();                                    /* ¿Llegó una letra? */
        if (c == '\r' || c == '\n') {                           /* Enter: la frase terminó */
            if (line_len > 0) {                                 /* Si no está vacía... */
                line[line_len] = '\0';                          /* ...cerrar el texto (en C termina con '\0') */
                printf("\r\n");
                send_text(line);                                /* ...traducir y transmitir */
                line_len = 0;                                   /* Empezar una frase nueva */
            }
        } else if (c == 8 || c == 127) {                        /* Backspace (el código cambia según la terminal) */
            if (line_len > 0) {
                line_len--;                                     /* Borrar la última letra guardada */
                printf("\b \b");                                /* Borrarla también en la pantalla */
                fflush(stdout);
            }
        } else if (c >= 32 && c < 127 && line_len < LINE_MAX - 1) {   /* Letra imprimible y hay espacio */
            line[line_len++] = (char)c;                         /* Guardarla */
            uart_putc((char)c);                                 /* Eco: mostrarla en la pantalla mientras escribes */
        }

        /* ---------- b) MORSE CON EL BOTÓN ---------- */
        int key = key_update();                                 /* Estado del botón ya sin rebotes */

        if (key) {                                              /* Presionado */
            gpio_bit_set(LED_PORT, LED_PIN);                    /* El LED copia el botón: ves lo que tocas */
            press_ms++;                                         /* Contar cuánto dura el toque */
            idle_ms = 0;
        } else {                                                /* Suelto */
            gpio_bit_reset(LED_PORT, LED_PIN);

            if (key_before) {                                   /* Se acaba de soltar: terminó un toque */
                char s = (press_ms >= DASH_MIN_MS) ? '-' : '.'; /* Largo = raya, corto = punto */
                if (symbols_len < SYMBOLS_MAX) {
                    symbols[symbols_len++] = s;                 /* Guardarlo en la letra actual */
                }
                uart_putc(s);                                   /* Mostrar el punto o raya al instante */
                press_ms = 0;
            }

            idle_ms++;                                          /* Contar cuánto lleva la pausa */

            if (symbols_len > 0 && idle_ms == LETTER_GAP_MS) {  /* Pausa larga: la letra terminó */
                symbols[symbols_len] = '\0';                    /* Cerrar el texto */
                printf(" = %c\r\n", morse_to_char(symbols));    /* Traducir e imprimir */
                symbols_len = 0;                                /* Empezar una letra nueva */
                word_open = 1;                                  /* Hay una palabra en curso */
            }

            if (word_open && idle_ms == WORD_GAP_MS) {          /* Pausa aún más larga: terminó la palabra */
                printf("(espacio)\r\n> ");
                fflush(stdout);
                word_open = 0;
            }
        }
        key_before = key;                                       /* Recordar el estado para la próxima vuelta */

        wait_ms(1);                                             /* Base de tiempo: cada vuelta = 1 ms (recibiendo mientras espera) */
    }
}