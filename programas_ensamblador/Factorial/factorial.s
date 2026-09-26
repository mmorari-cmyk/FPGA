# ==============================================================================
# factorial.s - Cálculo de Factorial en RISC-V (RV32I) para FemtoRV32
# ==============================================================================
# Target: Tang Primer 20K (4 LEDs de usuario en dirección MMIO 0x00010000)
# CPU: FemtoRV32 Quark (RV32I puro - Multiplicación resuelta por software)
# ==============================================================================

    .section .text._start
    .global _start

_start:
    # 1. Inicializar puntero de pila (tope de 1KB BRAM)
    li sp, 0x00000400

    # 2. Dirección base MMIO de los LEDs (0x00010000)
    lui s0, 0x10

main_loop:
    # Secuencia en los 4 LEDs:
    # 1! = 1 -> LEDs: [0 0 0 1]
    # 2! = 2 -> LEDs: [0 0 1 0]
    # 3! = 6 -> LEDs: [0 1 1 0]

    # --- Calcular y mostrar 1! ---
    li   a0, 1
    jal  ra, calc_factorial
    sw   a0, 0(s0)            # Escribe el resultado en los LEDs
    jal  ra, delay

    # --- Calcular y mostrar 2! ---
    li   a0, 2
    jal  ra, calc_factorial
    sw   a0, 0(s0)
    jal  ra, delay

    # --- Calcular y mostrar 3! ---
    li   a0, 3
    jal  ra, calc_factorial
    sw   a0, 0(s0)
    jal  ra, delay

    # --- Pausa con LEDs apagados antes de reiniciar ciclo ---
    li   t1, 0x0
    sw   t1, 0(s0)
    jal  ra, delay

    j    main_loop

# ==============================================================================
# Función: calc_factorial
# Entrada: a0 = n
# Salida:  a0 = n!
# ==============================================================================
calc_factorial:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s1, 8(sp)
    sw   s2, 4(sp)

    mv   s1, a0               # s1 = n
    li   s2, 1                # s2 = acumulador (inicia en 1)

fact_loop:
    blez s1, fact_done        # Si n <= 0, finaliza
    mv   a0, s2               # a0 = multiplicando
    mv   a1, s1               # a1 = multiplicador
    jal  ra, multiply         # a0 = s2 * s1
    mv   s2, a0               # nuevo acumulador
    addi s1, s1, -1           # n = n - 1
    j    fact_loop

fact_done:
    mv   a0, s2               # Retorna resultado en a0
    lw   ra, 12(sp)
    lw   s1, 8(sp)
    lw   s2, 4(sp)
    addi sp, sp, 16
    ret

# ==============================================================================
# Función: multiply (Multiplicación por software para RV32I)
# Entrada: a0 = multiplicando, a1 = multiplicador
# Salida:  a0 = a0 * a1
# ==============================================================================
multiply:
    mv   t2, a0               # t2 = base
    li   a0, 0                # acumulador = 0
mult_loop:
    blez a1, mult_done        # Si multiplicador <= 0, salir
    add  a0, a0, t2           # acumulador += base
    addi a1, a1, -1           # multiplicador--
    j    mult_loop
mult_done:
    ret

# ==============================================================================
# Subrutina: delay (~600-700 ms a 27 MHz)
# ==============================================================================
delay:
    li   t0, 3000000
delay_loop:
    addi t0, t0, -1
    bnez t0, delay_loop
    ret