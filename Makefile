# ==============================================================================
# Makefile Raíz para el repositorio FPGA
# Reenvía automáticamente los comandos al proyecto activo (RGB_lcd/factorial)
# ==============================================================================

PROJECT_DIR ?= RGB_lcd/factorial

.PHONY: all flash bitstream asm synth pnr detect clean

all: flash

flash:
	@$(MAKE) -C $(PROJECT_DIR) flash

bitstream:
	@$(MAKE) -C $(PROJECT_DIR) bitstream

asm:
	@$(MAKE) -C $(PROJECT_DIR) asm

synth:
	@$(MAKE) -C $(PROJECT_DIR) synth

pnr:
	@$(MAKE) -C $(PROJECT_DIR) pnr

detect:
	@$(MAKE) -C $(PROJECT_DIR) detect

clean:
	@$(MAKE) -C $(PROJECT_DIR) clean
