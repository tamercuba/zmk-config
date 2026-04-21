#!/usr/bin/env bash
# Generates SVG keymap diagram for the Corne and updates README.md.

set -euo pipefail

BOLD_GREEN='\033[1;32m'
RESET='\033[0m'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCS_DIR="$REPO_ROOT/docs"
CONFIG="$REPO_ROOT/scripts/keymap-drawer.yaml"

mkdir -p "$DOCS_DIR"

echo -e "${BOLD_GREEN}Drawing corne...${RESET}"
keymap -c "$CONFIG" parse -z "$REPO_ROOT/config/corne.keymap" \
    | keymap -c "$CONFIG" draw - \
    > "$DOCS_DIR/corne.svg"
echo "  → docs/corne.svg"

python3 - "$REPO_ROOT" <<'EOF'
import re, sys, os

repo_root = sys.argv[1]
readme_path = os.path.join(repo_root, 'README.md')

section = '<!-- KEYMAP-DRAWER:START -->\n'
section += '<details>\n<summary><b>corne</b></summary>\n\n![corne keymap](docs/corne.svg)\n\n</details>\n\n'
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
