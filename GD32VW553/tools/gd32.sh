#!/usr/bin/env bash
# Ejecuta un comando con el toolchain Nuclei (GCC + OpenOCD con driver gd32vw55x) primero en el PATH.
# Aislado a propósito: el riscv64-unknown-elf-gcc de apt (FPGA/FemtoRV) se llama igual y es otro.
# Uso: tools/gd32.sh make all | tools/gd32.sh make flash | tools/gd32.sh make monitor
# Rutas por defecto sobreescribibles: NUCLEI_TOOL_ROOT=/otra/ruta tools/gd32.sh make all
export NUCLEI_TOOL_ROOT="${NUCLEI_TOOL_ROOT:-$HOME/.local/opt/nuclei}"
export NUCLEI_SDK_ROOT="${NUCLEI_SDK_ROOT:-$HOME/src/nuclei-sdk}"
export PATH="$NUCLEI_TOOL_ROOT/gcc/bin:$NUCLEI_TOOL_ROOT/openocd/bin:$PATH"
# El GDB de Nuclei enlaza ncurses 5; en Ubuntu 24.04 hay que traer esas libs aparte (carpeta compat/)
export LD_LIBRARY_PATH="$NUCLEI_TOOL_ROOT/compat${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$@"
