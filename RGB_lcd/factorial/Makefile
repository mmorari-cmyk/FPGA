# ==============================================================================
# Makefile para Sistema RISC-V con Pantalla LCD, LEDs y Botones
# ==============================================================================

PROG    ?= main
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

# 1. Compilar ensamblador RISC-V a firmware.hex
asm: $(PROG).s
	@echo "==> [Paso 1/4] Ensamblando $(PROG).s para RISC-V..."
	$(DOCKER_CMD) bash -c '\
		riscv64-unknown-elf-gcc -T link.ld -march=rv32i -mabi=ilp32 -ffreestanding -nostdlib -o firmware.elf $(PROG).s && \
		riscv64-unknown-elf-objcopy -O binary firmware.elf firmware.bin && \
		hexdump -v -e "1/4 \"%08x\n\"" firmware.bin > firmware.hex \
	'
	@echo " [OK] firmware.hex generado."

# 2. Sintetizar con Yosys
synth: asm
	@echo "==> [Paso 2/4] Sintetizando SoC + Pantalla con Yosys..."
	$(DOCKER_CMD) yosys -p "read_verilog -I. -I/soc/hw -I/soc/hw/modules TOP.v lcd_ctrl.v pll_40m.v /soc/hw/modules/Clockworks.v /soc/hw/modules/femtorv32_quark.v /soc/hw/modules/bram_hex.v; synth_gowin -top TOP -json TOP_synth.json"

# 3. Place & Route con nextpnr
pnr: synth
	@echo "==> [Paso 3/4] Enrutando con nextpnr-himbaechel..."
	$(DOCKER_CMD) nextpnr-himbaechel \
		--json TOP_synth.json \
		--write TOP_pnr.json \
		--device GW2A-LV18PG256C8/I7 \
		--vopt family=GW2A-18 \
		--vopt cst=soc_lcd.cst

# 4. Generar Bitstream (.fs)
bitstream: pnr
	@echo "==> [Paso 4/4] Empaquetando bitstream TOP.fs..."
	$(DOCKER_CMD) gowin_pack -d GW2A-18 -o TOP.fs TOP_pnr.json
	@echo "=================================================="
	@echo " [OK] Bitstream generado: TOP.fs"
	@echo "=================================================="

# 5. Flashear a la SRAM de la FPGA
flash: bitstream
	@echo "==> Flasheando Tang Primer 20K..."
	$(DOCKER_CMD) openFPGALoader -b tangprimer20k TOP.fs

# Flashear persistente a la Flash ROM interna
flash-rom: bitstream
	@echo "==> Flasheando Tang Primer 20K (Flash ROM)..."
	$(DOCKER_CMD) openFPGALoader -b tangprimer20k -f TOP.fs

detect:
	$(DOCKER_CMD) openFPGALoader -b tangprimer20k --detect

clean:
	rm -f firmware.elf firmware.bin firmware.hex TOP_synth.json TOP_pnr.json TOP.fs
