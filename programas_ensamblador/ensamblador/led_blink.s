# ==============================================================================
# led_blink.s - Programa en Ensamblador RISC-V (RV32I) para FemtoRV32
# ==============================================================================
# Controla los LEDs de la Tang Primer 20K a través de Memory-Mapped I/O.
# Dirección física de los LEDs: 0x00010000
# ==============================================================================

.section .text._start
.global _start

_start:
    # 1. Inicializar el puntero de pila (Stack Pointer)
    # El tope de la BRAM de 1KB está en 0x00000400 (crece hacia abajo)
    li sp, 0x00000400

    # 2. Guardar la dirección base de los LEDs en el registro s0
    # 0x00010000 (bits [17:16] = 2'b01 en el decodificador del SoC)
    lui s0, 0x10

main_loop:
    # --- Paso 1: Encender patrón 1 (0b0101 = 5) ---
    li   t1, 0x5
    sw   t1, 0(s0)            # Escribe en 0x00010000
    jal  ra, delay            # Llama a la subrutina de retardo

    # --- Paso 2: Encender patrón 2 (0b1010 = 10) ---
    li   t1, 0xA
    sw   t1, 0(s0)            # Escribe en 0x00010000
    jal  ra, delay            # Llama a la subrutina de retardo

    # --- Paso 3: Encender todos los LEDs (0b1111 = 15) ---
    li   t1, 0xF
    sw   t1, 0(s0)            # Escribe en 0x00010000
    jal  ra, delay

    # --- Paso 4: Apagar todos los LEDs (0b0000 = 0) ---
    li   t1, 0x0
    sw   t1, 0(s0)            # Escribe en 0x00010000
    jal  ra, delay

    # Repetir indefinidamente
    j    main_loop

# ==============================================================================
# Subrutina: delay
# ==============================================================================
# Decrementa un contador para generar una pausa visible al ojo humano.
# A 27 MHz, aproximadamente 2.000.000 de iteraciones tardan ~300-400 ms.
# ==============================================================================
delay:
    li   t0, 100000
delay_loop:
    addi t0, t0, -1
    bnez t0, delay_loop
    ret
