TOP       ?= top
TOOLS_DIR ?= $(abspath ../../Femto_Risc-V_SoC/Tools)

DOCKER_CMD = docker run --rm --privileged \
             -v "$(CURDIR)":/workspace \
             -v "$(TOOLS_DIR)":/workspace/Tools:ro \
             -v /dev/bus/usb:/dev/bus/usb \
             -w /workspace \
             -e PATH="/workspace/Tools/Tang-primer-20k-oss-cad/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
             fpga-toolchain

.PHONY: all synth pnr bitstream flash flash-prebuilt detect clean

all: flash

# Flashea el bitstream precompilado directamente para prueba rápida de hardware
flash-prebuilt:
	$(DOCKER_CMD) openFPGALoader -b tangprimer20k -m rgb_lcd.fs

synth:
	$(DOCKER_CMD) yosys -p "read_verilog top.v lcd_ctrl.v lcd_data.v pll_40m.v; synth_gowin -top $(TOP) -json $(TOP)_synth.json"

pnr: synth
	$(DOCKER_CMD) nextpnr-himbaechel \
		--json $(TOP)_synth.json \
		--write $(TOP)_pnr.json \
		--device GW2A-LV18PG256C8/I7 \
		--vopt family=GW2A-18 \
		--vopt cst=rgb_lcd.cst

bitstream: pnr
	$(DOCKER_CMD) gowin_pack -d GW2A-18 -o $(TOP).fs $(TOP)_pnr.json
	@echo "=================================================="
	@echo " [OK] Bitstream generado: $(TOP).fs"
	@echo "=================================================="

# Si existe top.fs (tu compilación) flashea ese, sino flashea el precompilado rgb_lcd.fs a la SRAM
flash:
	@if [ -f "$(TOP).fs" ]; then \
		echo "Flasheando bitstream generado ($(TOP).fs)..."; \
		$(DOCKER_CMD) openFPGALoader -b tangprimer20k -m $(TOP).fs; \
	elif [ -f "rgb_lcd.fs" ]; then \
		echo "Flasheando bitstream de prueba (rgb_lcd.fs)..."; \
		$(DOCKER_CMD) openFPGALoader -b tangprimer20k -m rgb_lcd.fs; \
	else \
		echo "No se encontró ningún archivo .fs. Ejecutá 'make bitstream' primero."; \
	fi

flash-rom:
	$(DOCKER_CMD) openFPGALoader -b tangprimer20k -f $(TOP).fs

detect:
	$(DOCKER_CMD) openFPGALoader -b tangprimer20k --detect

clean:
	rm -f *_synth.json *_pnr.json top.fs
