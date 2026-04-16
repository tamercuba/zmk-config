SHELL    := /run/current-system/sw/bin/bash
REPO     := tamercuba/zmk-config
FIRMWARE := firmware
MOUNT    := /mnt/nicenano

.PHONY: download flash left right

# Baixa o artifact da build mais recente e extrai em ./firmware/
download:
	@echo "══════════════════════════════════════"
	@echo "  Baixando firmware..."
	@echo "══════════════════════════════════════"
	@rm -rf $(FIRMWARE)
	@gh run download --repo $(REPO) --name firmware -D $(FIRMWARE)
	@echo "✓ Firmware disponível em ./$(FIRMWARE)/"

# Flasha os dois lados em sequência: direito primeiro, depois esquerdo
flash: right left
	@echo ""
	@echo "══════════════════════════════════════"
	@echo "  Ambos os lados flashados com sucesso!"
	@echo "══════════════════════════════════════"

right:
	$(call flash-side,DIREITO,corne_right-nice_nano_v2-zmk.uf2)

left:
	$(call flash-side,ESQUERDO,corne_left-nice_nano_v2-zmk.uf2)

# Faz polling por qualquer block device com VID 239a + model nRF_UF2
define find-nrf-device
$$(while true; do \
  found=$$(lsblk -rno NAME | grep -v '[0-9]$$' | while read dev; do \
    vendor=$$(udevadm info /dev/$$dev 2>/dev/null | grep 'ID_USB_VENDOR_ID=' | cut -d= -f2); \
    model=$$(udevadm info /dev/$$dev 2>/dev/null | grep 'ID_USB_MODEL=' | cut -d= -f2); \
    if [[ "$$vendor" == "239a" && "$$model" == "nRF_UF2" ]]; then echo "$$dev"; break; fi; \
  done); \
  if [[ -n "$$found" ]]; then echo "$$found"; break; fi; \
  printf "."; sleep 1; \
done)
endef

define flash-side
	@echo ""
	@echo "══════════════════════════════════════"
	@echo "  LADO $(1)"
	@echo "  Conecte o teclado e dê dois cliques"
	@echo "  rápidos no botão reset..."
	@echo "══════════════════════════════════════"
	@printf "Aguardando bootloader Adafruit nRF UF2"; \
	 device=$(find-nrf-device); echo; \
	 echo "→ Dispositivo encontrado: /dev/$$device"; \
	 echo "→ Montando em $(MOUNT)..."; \
	 sudo mount /dev/$$device $(MOUNT); \
	 echo "→ Copiando $(2)..."; \
	 sudo cp $(FIRMWARE)/$(2) $(MOUNT)/ && sync; \
	 echo "✓ Lado $(1) flashado!"
endef
