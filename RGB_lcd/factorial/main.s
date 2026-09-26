# ==============================================================================
# main.s - Cálculo de Factorial en RISC-V con LEDs, Botones y Texto OSD en LCD
# ==============================================================================
# Plataforma: Tang Primer 20K (FemtoRV32 Quark RV32I)
#
# Mapeo MMIO:
#   0x00010000 -> GPIO:
#                 [sw] Bits [3:0] -> 4 LEDs (valor binario del factorial)
#                 [lw] Bits [6:4] -> 3 Botones (invertidos, 1=presionado):
#                                   Bit 4 = S1 (Pin T3)
#                                   Bit 5 = S2 (Pin T2)
#                                   Bit 6 = S3 (Pin D7)
#   0x00030000 -> LCD Control / OSD:
#                 [sw] Bits [23:0]  -> Color RGB de fondo
#                 [sw] Bits [25:24] -> Modo de texto OSD:
#                                      01: "1! = 1"
#                                      10: "2! = 2"
#                                      11: "3! = 6"
#
# Estados del Sistema:
#   - Reposo (sin botones): N = 1 -> 1! = 1 (LEDs: 0001, Pantalla Verde, Texto "1! = 1")
#   - Pulsar S1:           N = 2 -> 2! = 2 (LEDs: 0010, Pantalla Roja,  Texto "2! = 2")
#   - Pulsar S2:           N = 3 -> 3! = 6 (LEDs: 0110, Pantalla Azul,  Texto "3! = 6")
# ==============================================================================

.section .text._start
.global _start

_start:
    # 1. Puntero de Pila (Stack Pointer) a 1KB
    li   sp, 0x00000400

    # 2. Direcciones base MMIO
    lui  s0, 0x10             # s0 = 0x00010000 (GPIO: LEDs y Botones)
    lui  s1, 0x30             # s1 = 0x00030000 (Color LCD y Modo OSD)

main_loop:
    # --- Leer estado de los botones físicos ---
    lw   t0, 0(s0)            # Leer registro GPIO
    srli t0, t0, 4            # Desplazar a bits [2:0]
    andi t0, t0, 0x7          # Aislar los 3 botones

    # Caso 1: Botón S1 presionado (Pin T2 o Pin T3) -> Calcular 2!
    andi t1, t0, 0x3
    bnez t1, caso_s1

    # Caso 2: Botón S2 presionado (Pin D7) -> Calcular 3!
    andi t1, t0, 0x4
    bnez t1, caso_s2

    # Caso Reposo (ningún botón presionado) -> Calcular 1!
    li   a0, 1                # N = 1
    jal  ra, calc_factorial   # a0 = 1! = 1
    sw   a0, 0(s0)            # LEDs = 0001 (LED 0 ON)
    li   t2, 0x0100FF00       # Modo 1 ("1! = 1") + Fondo Verde (0x00FF00)
    sw   t2, 0(s1)
    j    main_loop

caso_s1:
    # N = 2 -> 2! = 2
    li   a0, 2
    jal  ra, calc_factorial   # a0 = 2! = 2
    sw   a0, 0(s0)            # LEDs = 0010 (LED 1 ON)
    li   t2, 0x02FF0000       # Modo 2 ("2! = 2") + Fondo Rojo (0xFF0000)
    sw   t2, 0(s1)
    j    main_loop

caso_s2:
    # N = 3 -> 3! = 6
    li   a0, 3
    jal  ra, calc_factorial   # a0 = 3! = 6
    sw   a0, 0(s0)            # LEDs = 0110 (LEDs 1 y 2 ON)
    li   t2, 0x030000FF       # Modo 3 ("3! = 6") + Fondo Azul (0x0000FF)
    sw   t2, 0(s1)
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
