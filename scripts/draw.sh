#!/usr/bin/env bash
# Generates SVG keymap diagrams for all keyboards and updates README.md.

set -euo pipefail

BOLD_GREEN='\033[1;32m'
RESET='\033[0m'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCS_DIR="$REPO_ROOT/docs"
GLOBAL_CONFIG="$REPO_ROOT/scripts/keymap-drawer.yaml"

mkdir -p "$DOCS_DIR"

for keymap_file in "$REPO_ROOT"/config/*.keymap; do
    keyboard="$(basename "$keymap_file" .keymap)"
    kb_config="$REPO_ROOT/scripts/${keyboard}.yaml"
    svg="$DOCS_DIR/${keyboard}.svg"

    echo -e "${BOLD_GREEN}Drawing ${keyboard}...${RESET}"

    # Merge global + per-keyboard configs into a temp file (keymap only accepts one -c)
    merged_config="$(mktemp /tmp/keymap-drawer-XXXXXX.yaml)"
    trap "rm -f '$merged_config'" EXIT
    python3 - "$GLOBAL_CONFIG" "$kb_config" > "$merged_config" <<'PYEOF'
import sys, yaml

def deep_merge(base, new):
    result = dict(base)
    for k, v in new.items():
        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = deep_merge(result[k], v)
        else:
            result[k] = v
    return result

merged = {}
for path in sys.argv[1:]:
    try:
        with open(path) as f:
            merged = deep_merge(merged, yaml.safe_load(f) or {})
    except FileNotFoundError:
        pass

print(yaml.dump(merged, default_flow_style=False))
PYEOF

    keymap -c "$merged_config" parse -z "$keymap_file" \
        | keymap -c "$merged_config" draw - \
        > "$svg"

    echo "  → docs/${keyboard}.svg"
done

python3 - "$REPO_ROOT" <<'EOF'
import re, sys, os, glob

repo_root = sys.argv[1]
readme_path = os.path.join(repo_root, 'README.md')

svgs = sorted(glob.glob(os.path.join(repo_root, 'docs', '*.svg')))
section = '<!-- KEYMAP-DRAWER:START -->\n'
for svg in svgs:
    name = os.path.splitext(os.path.basename(svg))[0]
    section += f'<details>\n<summary><b>{name}</b></summary>\n\n![{name} keymap](docs/{name}.svg)\n\n</details>\n\n'
section += '<!-- KEYMAP-DRAWER:END -->'

with open(readme_path, 'r') as f:
    content = f.read()

pattern = r'<!-- KEYMAP-DRAWER:START -->.*?<!-- KEYMAP-DRAWER:END -->'
if re.search(pattern, content, flags=re.DOTALL):
    new_content = re.sub(pattern, section, content, flags=re.DOTALL)
else:
    new_content = content.rstrip() + '\n\n## Keymap Diagrams\n\n' + section + '\n'

with open(readme_path, 'w') as f:
    f.write(new_content)

print('README.md updated.')
EOF
