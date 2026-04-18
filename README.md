# zmk-config

My setup for building ZMK firmware locally using Nix — no CI required.

## Adding a new keyboard

1. Create `config/<shield>.keymap` and `config/<shield>.conf`
2. Add the target to `build.yaml`
3. Read the docs:
   - [Keymaps](https://zmk.dev/docs/keymaps)
   - [Behaviors](https://zmk.dev/docs/keymaps/behaviors)
   - [Config options](https://zmk.dev/docs/config)

## Build & flash

```bash
nix develop      # only if direnv isnt working

zmk-build        # compile all targets → firmware/
zmk-flash        # flash to keyboard
```
