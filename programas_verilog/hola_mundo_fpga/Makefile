TOP       ?= TOP
TOOLS_DIR ?= $(abspath ../../Femto_Risc-V_SoC/Tools)

DOCKER_CMD = docker run --rm --privileged \
             -v "$(CURDIR)":/workspace \
             -v "$(TOOLS_DIR)":/workspace/Tools:ro \
             -v /dev/bus/usb:/dev/bus/usb \
             -w /workspace \
             -e PATH="/workspace/Tools/Tang-primer-20k-oss-cad/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
             fpga-toolchain

.PHONY: all synth pnr bitstream flash detect clean

all: flash

synth:
	$(DOCKER_CMD) yosys -p "read_verilog $(TOP).v; synth_gowin -top $(TOP) -json $(TOP)_synth.json"

pnr: synth
	$(DOCKER_CMD) nextpnr-himbaechel \
		--json $(TOP)_synth.json \
		--write $(TOP)_pnr.json \
		--device GW2A-LV18PG256C8/I7 \
		--vopt family=GW2A-18 \
		--vopt cst=tang_primer_20k.cst

bitstream: pnr
	$(DOCKER_CMD) gowin_pack -d GW2A-18 -o $(TOP).fs $(TOP)_pnr.json
	@echo "=================================================="
	@echo " [OK] Bitstream generado: $(TOP).fs"
	@echo "=================================================="

flash: bitstream
	$(DOCKER_CMD) openFPGALoader -b tangprimer20k -m $(TOP).fs

detect:
	$(DOCKER_CMD) openFPGALoader -b tangprimer20k --detect

clean:
	rm -f *_synth.json *_pnr.json *.fs