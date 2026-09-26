TARGET = gd32_app

NUCLEI_SDK_ROOT ?= $(HOME)/src/nuclei-sdk
SOC = gd32vw55x
DOWNLOAD = flashxip

SRCDIRS = .
INCDIRS = .

include $(NUCLEI_SDK_ROOT)/Build/Makefile.base

SERIAL_PORT ?= /dev/ttyUSB0
BAUD ?= 115200

# Grabar sin GDB: más rápido y verifica la flash
.PHONY: flash monitor
flash: $(TARGET_ELF)
	openocd -f $(OPENOCD_CFG) -c "program $(TARGET_ELF) verify reset exit"

# Monitor serie del CH340 (salir con Ctrl+C)
monitor:
	stty -F $(SERIAL_PORT) $(BAUD) raw -echo
	cat $(SERIAL_PORT)
