# ==============================================================================
# Makefile para proyectos en Ensamblador RISC-V sobre FemtoRV32 (Tang Primer 20K)
# ==============================================================================

PROG    ?= factorial
SOC_DIR ?= $(abspath ../../Femto_Risc-V_SoC)

DOCKER_CMD = docker run --rm --privileged \
             -v "$(CURDIR)":/workspace \
             -v "$(SOC_DIR)":/soc:ro \
             -v /dev/bus/usb:/dev/bus/usb \
             -w /workspace \
             -e PATH="/soc/Tools/Tang-primer-20k-oss-cad/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
             fpga-toolchain

.PHONY: all asm synth pnr bitstream flash flash-rom clean detect

all: flash

# 1. Compilar ensamblador -> ELF -> BIN -> HEX (firmware.hex)
asm: $(PROG).s
	@echo "==> Ensamblando $(PROG).s para RISC-V (RV32I)..."
	$(DOCKER_CMD) bash -c '\
		riscv64-unknown-elf-gcc -T link.ld -march=rv32i -mabi=ilp32 -ffreestanding -nostdlib -o firmware.elf $(PROG).s && \
		riscv64-unknown-elf-objcopy -O binary firmware.elf firmware.bin && \
		hexdump -v -e "1/4 \"%08x\n\"" firmware.bin > firmware.hex \
	'
	@echo " [OK] firmware.hex generado correctamente."

# 2. Sintetizar el procesador SoC en la FPGA con el firmware.hex incrustado
synth: asm
	@echo "==> Sintetizando el procesador RISC-V con Yosys..."
	$(DOCKER_CMD) yosys -p "read_verilog -I/soc/hw -I/soc/hw/modules /soc/hw/*.v /soc/hw/modules/*.v; synth_gowin -top TOP -json TOP_synth.json"

# 3. Place & Route
pnr: synth
	@echo "==> Enrutando en la FPGA con nextpnr-himbaechel..."
	$(DOCKER_CMD) nextpnr-himbaechel \
		--json TOP_synth.json \
		--write TOP_pnr.json \
		--device GW2A-LV18PG256C8/I7 \
		--vopt family=GW2A-18 \
		--vopt cst=/soc/hw/constraints/tang_primer_20k.cst

# 4. Empaquetar Bitstream (.fs)
bitstream: pnr
	@echo "==> Generando bitstream TOP.fs..."
	$(DOCKER_CMD) gowin_pack -d GW2A-18 -o TOP.fs TOP_pnr.json
	@echo "=================================================="
	@echo " [OK] Bitstream generado: TOP.fs"
	@echo "=================================================="

# 5. Cargar a la FPGA (SRAM rápida)
flash: bitstream
	@echo "==> Flasheando Tang Primer 20K (SRAM)..."
	$(DOCKER_CMD) openFPGALoader -b tangprimer20k TOP.fs

# 6. Cargar a la Flash interna (Persistente al reiniciar)
flash-rom: bitstream
	@echo "==> Flasheando Tang Primer 20K (Flash ROM)..."
	$(DOCKER_CMD) openFPGALoader -b tangprimer20k -f TOP.fs

# Detección de la placa
detect:
	$(DOCKER_CMD) openFPGALoader -b tangprimer20k --detect

clean:
	rm -f firmware.elf firmware.bin firmware.hex TOP_synth.json TOP_pnr.json TOP.fs *.log
