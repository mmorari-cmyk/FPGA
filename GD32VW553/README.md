# GD32VW553 — Microcontrolador RISC-V

> Carpeta autocontenida: todo lo de la GD32VW553 vive aquí (incluido su `.vscode/` y `.gitignore`).
> No depende del `Makefile` ni del `.vscode/` de la raíz, que siguen siendo los de la Tang Primer 20K.

Segunda placa del curso: **立创·GD32VW553 (LCSC/JLC)**, núcleo Nuclei N300 (RV32IMAFDC) a 160 MHz, 4 MB de flash, Wi-Fi/BLE.
A diferencia de la Tang Primer 20K, aquí el hardware está fijo en el silicio: se programa en C y se graba por JTAG.

## Contenido

| Archivo | Qué hace |
|---|---|
| `main.c` | **Traductor Morse** en los dos sentidos: texto por UART → LED, y botón → texto por UART |
| `ejemplos/led_boton.c` | LED que parpadea + contador por UART; el botón alterna la velocidad (500 ms / 100 ms) |
| `ejemplos/morse.c` | Copia del traductor Morse |
| `tools/gd32.sh` | Pone el toolchain de Nuclei primero en el PATH solo para un comando |
| `.vscode/` | Botones de compilar / grabar / monitor y depuración con F5 (Cortex-Debug) |

Solo se compila `main.c`. Para usar un ejemplo, cópialo encima de `main.c`.

## Recursos de la placa

| Recurso | Pin | Detalle |
|---|---|---|
| LED1 | PC13 | activo en alto |
| Botón KEY_UP | PA0 | presionado = 3,3 V → entrada con pull-down |
| UART (CH340) | USART0: TX PB15, RX PA8 | 115200 baudios; `printf` sale por aquí |
| JTAG | GND, TDI, TCK, TMS, TDO, 3V3 | conectado al WCH-LinkE |

Wiki oficial: [wiki.lckfb.com — GD32VW553](https://wiki.lckfb.com/zh-hans/gd32vw553/)

## Cadena de herramientas

```
main.c ──(riscv64-unknown-elf-gcc)──► gd32_app.elf ──(OpenOCD + JTAG)──► flash del GD32VW553
                                                        │
                                  WCH-LinkE en modo DAP (CMSIS-DAP)

printf() ──► USART0 ──► CH340 ──► /dev/ttyUSB0 ──► monitor serie
```

- **Nuclei SDK** en `~/src/nuclei-sdk`
- **Toolchain Nuclei** (GCC + OpenOCD con driver `gd32vw55x`) en `~/.local/opt/nuclei`

Si están en otra ruta: `NUCLEI_SDK_ROOT=... NUCLEI_TOOL_ROOT=... tools/gd32.sh make all`.

> El WCH-LinkE sale de fábrica en modo RISC-V (solo chips WCH). Para el GD32 se usa **modo DAP**:
> mantener presionado **ModeS** al conectar el USB. `lsusb` debe mostrar `1a86:8012`.

## Uso

```bash
git clone https://github.com/mmorari-cmyk/FPGA.git
cd FPGA/GD32VW553
tools/gd32.sh make all       # compilar → gd32_app.elf
tools/gd32.sh make flash     # grabar por JTAG y verificar (debe decir "Verified OK")
tools/gd32.sh make monitor   # monitor serie a 115200 (salir con Ctrl+C)
```

En VS Code hay que abrir **esta carpeta** (`code FPGA/GD32VW553`), no la raíz del repo: así cargan
las tareas de `GD32VW553/.vscode/` y no se mezclan con las de la FPGA.
`Ctrl+Shift+B` compila y F5 depura (se detiene en `main`).

## Errores comunes

| Mensaje | Causa | Solución |
|---|---|---|
| `unable to find a matching CMSIS-DAP device` | WCH-LinkE desconectado o en modo RISC-V | `lsusb` → debe ser `1a86:8012`; cambiar de modo con ModeS |
| `Could not identify target` | OpenOCD ve el adaptador pero no el chip | revisar cables JTAG, GND y que la placa esté alimentada |
| `Permission denied: /dev/ttyUSB0` | permisos del puerto serie | agregar el usuario al grupo `dialout` o instalar la regla udev |
| Compila con el GCC equivocado | no se usó `tools/gd32.sh` | ejecutar siempre a través del script |
