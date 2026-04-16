SHELL    := /bin/bash
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

# Aguarda novo device aparecer, verifica que é UF2, monta e flasha
define flash-side
	@echo ""
	@echo "══════════════════════════════════════"
	@echo "  LADO $(1)"
	@echo "  Conecte o teclado e dê dois cliques"
	@echo "  rápidos no botão reset..."
	@echo "══════════════════════════════════════"
	@before=$$(lsblk -rno NAME | sort); \
	 printf "Aguardando dispositivo"; \
	 while [[ "$$(lsblk -rno NAME | sort)" == "$$before" ]]; do printf "."; sleep 1; done; echo; \
	 device=$$(comm -13 <(echo "$$before") <(lsblk -rno NAME | sort) | grep -v '[0-9]$$' | head -1); \
	 if [[ -z "$$device" ]]; then echo "ERRO: nenhum dispositivo detectado."; exit 1; fi; \
	 echo "→ Dispositivo detectado: /dev/$$device"; \
	 vendor=$$(udevadm info /dev/$$device | grep 'ID_USB_VENDOR_ID' | cut -d= -f2); \
	 model=$$(udevadm info /dev/$$device | grep 'ID_USB_MODEL=' | cut -d= -f2); \
	 echo "→ USB: vendor=$$vendor model=$$model"; \
	 if [[ "$$vendor" != "239a" || "$$model" != "nRF_UF2" ]]; then \
	   echo "ERRO: dispositivo não é o bootloader Adafruit nRF UF2 (vendor=$$vendor model=$$model)."; \
	   exit 1; \
	 fi; \
	 echo "→ Bootloader Adafruit nRF UF2 confirmado."; \
	 echo "→ Montando em $(MOUNT)..."; \
	 sudo mount /dev/$$device $(MOUNT); \
	 echo "→ Copiando $(2)..."; \
	 sudo cp $(FIRMWARE)/$(2) $(MOUNT)/ && sync; \
	 echo "✓ Lado $(1) flashado!"
endef
