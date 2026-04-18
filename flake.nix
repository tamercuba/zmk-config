{
  description = "ZMK config dev shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # ── Build ──────────────────────────────────────────────────────────────

      zmk-build-left = pkgs.writeShellScriptBin "zmk-build-left" ''
        set -e
        ROOT=$(git rev-parse --show-toplevel)
        mkdir -p "$ROOT/firmware"
        cd "$ROOT/.zmk"
        west build -s zmk/app -b nice_nano_v2 -d build/left -- \
          -DSHIELD=corne_left -DZMK_CONFIG="$ROOT/config"
        cp build/left/zephyr/zmk.uf2 "$ROOT/firmware/corne_left-nice_nano_v2-zmk.uf2"
        echo "✓ firmware/corne_left-nice_nano_v2-zmk.uf2"
      '';

      zmk-build-right = pkgs.writeShellScriptBin "zmk-build-right" ''
        set -e
        ROOT=$(git rev-parse --show-toplevel)
        mkdir -p "$ROOT/firmware"
        cd "$ROOT/.zmk"
        west build -s zmk/app -b nice_nano_v2 -d build/right -- \
          -DSHIELD=corne_right -DZMK_CONFIG="$ROOT/config"
        cp build/right/zephyr/zmk.uf2 "$ROOT/firmware/corne_right-nice_nano_v2-zmk.uf2"
        echo "✓ firmware/corne_right-nice_nano_v2-zmk.uf2"
      '';

      zmk-build = pkgs.writeShellScriptBin "zmk-build" ''
        set -e
        ${zmk-build-left}/bin/zmk-build-left
        ${zmk-build-right}/bin/zmk-build-right
        echo ""
        echo "══════════════════════════════════════"
        echo "  Firmware ready in ./firmware/"
        echo "══════════════════════════════════════"
      '';

      zmk-clean = pkgs.writeShellScriptBin "zmk-clean" ''
        ROOT=$(git rev-parse --show-toplevel)
        rm -rf "$ROOT/.zmk/build"
        echo "✓ Build artifacts removed"
      '';

      # ── Flash ──────────────────────────────────────────────────────────────

      # Internal helper (not exposed in PATH): receives SIDE and FILE as args
      flash-side = pkgs.writeShellScript "flash-side" ''
        set -e
        SIDE="$1"
        FILE="$2"
        MOUNT="/mnt/nicenano"
        ROOT=$(git rev-parse --show-toplevel)

        echo ""
        echo "══════════════════════════════════════"
        echo "  $SIDE SIDE"
        echo "  Swap the cable and double-click"
        echo "  the reset button..."
        echo "══════════════════════════════════════"

        sudo -v
        for i in 5 4 3 2 1; do printf "  Starting in $i...\r"; sleep 1; done; echo

        printf "Waiting for Adafruit nRF UF2 bootloader"
        while true; do
          found=$(lsblk -rno NAME | grep -v '[0-9]$' | while read -r dev; do
            vendor=$(udevadm info /dev/"$dev" 2>/dev/null | grep 'ID_USB_VENDOR_ID=' | cut -d= -f2)
            model=$(udevadm info /dev/"$dev" 2>/dev/null | grep 'ID_USB_MODEL=' | cut -d= -f2)
            if [[ "$vendor" == "239a" && "$model" == "nRF_UF2" ]]; then echo "$dev"; break; fi
          done)
          [[ -n "$found" ]] && break
          printf "."
          sleep 1
        done

        echo
        echo "→ Device found: /dev/$found"
        udevadm settle
        echo "→ Mounting at $MOUNT..."
        sudo mount "/dev/$found" "$MOUNT" || { echo "ERROR: mount failed."; exit 1; }
        echo "→ Copying $FILE..."
        sudo cp "$ROOT/firmware/$FILE" "$MOUNT/" && sync || { sudo umount "$MOUNT"; exit 1; }
        echo "✓ $SIDE side flashed!"
      '';

      zmk-flash-right = pkgs.writeShellScriptBin "zmk-flash-right" ''
        ${flash-side} RIGHT corne_right-nice_nano_v2-zmk.uf2
      '';

      zmk-flash-left = pkgs.writeShellScriptBin "zmk-flash-left" ''
        ${flash-side} LEFT corne_left-nice_nano_v2-zmk.uf2
      '';

      zmk-flash = pkgs.writeShellScriptBin "zmk-flash" ''
        set -e
        ${flash-side} RIGHT corne_right-nice_nano_v2-zmk.uf2
        ${flash-side} LEFT  corne_left-nice_nano_v2-zmk.uf2
        echo ""
        echo "══════════════════════════════════════"
        echo "  Both sides flashed successfully!"
        echo "══════════════════════════════════════"
      '';

    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          # ARM toolchain
          gcc-arm-embedded

          # Build tools
          cmake
          ninja
          dtc
          gperf

          # Python + west + Zephyr deps
          (python3.withPackages (p: with p; [
            west
            pyelftools
            pyyaml
            packaging
            setuptools
          ]))

          # Utilities
          git
          wget
          file
          usbutils

          # ZMK commands
          zmk-build-left
          zmk-build-right
          zmk-build
          zmk-clean
          zmk-flash-left
          zmk-flash-right
          zmk-flash
        ];

        shellHook = ''
          export ZEPHYR_TOOLCHAIN_VARIANT=gnuarmemb
          export GNUARMEMB_TOOLCHAIN_PATH=${pkgs.gcc-arm-embedded}

          ROOT=$(git rev-parse --show-toplevel)
          export ZEPHYR_BASE="$ROOT/.zmk/zephyr"
          export CMAKE_PREFIX_PATH="$ZEPHYR_BASE"

          if [ ! -f "$ROOT/.zmk/.setup-complete" ]; then
            echo "Fetching Zephyr and west dependencies..."
            cd "$ROOT/.zmk" && west update && touch .setup-complete
            cd "$ROOT"
          fi
        '';
      };
    };
}
