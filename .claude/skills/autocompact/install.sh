#!/usr/bin/env bash
# Autocompact installer
#
# Works two ways:
#   curl -fsSL https://raw.githubusercontent.com/YOUR_USER/autocompact/main/install.sh | bash
#   bash install.sh   (from a local clone)
#
# What this does:
#   1. Downloads skill files to ~/.claude/skills/autocompact/
#   2. Wires a Stop hook into ~/.claude/settings.json
#   3. Prints next steps
#
# After install: run /autocompact once in Claude Code to set your threshold.

set -euo pipefail

GITHUB_USER="joan-chiangwq"
GITHUB_REPO="skillmaxxing"
GITHUB_BRANCH="main"
RAW="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$GITHUB_BRANCH/.claude/skills/autocompact"

INSTALL_DIR="$HOME/.claude/skills/autocompact"
SETTINGS_FILE="$HOME/.claude/settings.json"
HOOK_CMD="bash ~/.claude/skills/autocompact/scripts/check-and-fire.sh"

# ── Output helpers ────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓${NC}  $1"; }
warn() { echo -e "${YELLOW}  ⚠${NC}  $1"; }
err()  { echo -e "${RED}  ✗${NC}  $1"; }
hr()   { echo "  ────────────────────────────────────────"; }

echo ""
echo "  Installing autocompact..."
echo ""
hr

# ── 1. Check dependencies ─────────────────────────────────────────────────────
for cmd in curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
        err "$cmd is required but not installed."
        echo ""
        case "$cmd" in
            jq)
                echo "  Install jq:"
                echo "    macOS:           brew install jq"
                echo "    Linux (apt):     sudo apt-get install jq"
                echo "    Linux (dnf):     sudo dnf install jq"
                echo "    Windows winget:  winget install jqlang.jq"
                echo "    Windows choco:   choco install jq"
                echo "    Windows scoop:   scoop install jq"
                ;;
            curl)
                echo "  Install curl via your system package manager."
                ;;
        esac
        echo ""
        exit 1
    fi
done
ok "Dependencies OK"

# ── 2. Detect source: local clone or remote download ──────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || echo "")"
USE_LOCAL=false
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/SKILL.md" ]; then
    USE_LOCAL=true
fi

download_file() {
    local remote_path="$1"
    local dest="$2"
    if [ "$USE_LOCAL" = true ]; then
        cp "$SCRIPT_DIR/$remote_path" "$dest"
    else
        curl -fsSL "$RAW/$remote_path" -o "$dest"
    fi
}

# ── 3. Install skill files ────────────────────────────────────────────────────
mkdir -p "$INSTALL_DIR/refs"
mkdir -p "$INSTALL_DIR/scripts"

download_file "SKILL.md"                      "$INSTALL_DIR/SKILL.md"
download_file "refs/snapshot-schema.md"       "$INSTALL_DIR/refs/snapshot-schema.md"
download_file "scripts/check-and-fire.sh"     "$INSTALL_DIR/scripts/check-and-fire.sh"
chmod +x "$INSTALL_DIR/scripts/check-and-fire.sh"

ok "Skill files installed → $INSTALL_DIR"

# ── 4. Wire Stop hook into ~/.claude/settings.json ───────────────────────────
mkdir -p "$(dirname "$SETTINGS_FILE")"

if [ ! -f "$SETTINGS_FILE" ]; then
    echo '{}' > "$SETTINGS_FILE"
fi

if ! jq empty "$SETTINGS_FILE" 2>/dev/null; then
    err "$SETTINGS_FILE contains invalid JSON — aborting to avoid data loss."
    echo "  Fix the file manually, then re-run install.sh."
    exit 1
fi

ALREADY=$(jq --arg cmd "$HOOK_CMD" \
    '[.hooks.Stop[]?.hooks[]? | select(.type == "command" and .command == $cmd)] | length' \
    "$SETTINGS_FILE" 2>/dev/null || echo "0")

if [ "$ALREADY" -gt 0 ]; then
    warn "Stop hook already present — skipping"
else
    TMP=$(mktemp)
    jq --arg cmd "$HOOK_CMD" \
        '.hooks.Stop = ((.hooks.Stop // []) + [{"matcher": "", "hooks": [{"type": "command", "command": $cmd}]}])' \
        "$SETTINGS_FILE" > "$TMP"
    mv "$TMP" "$SETTINGS_FILE"
    ok "Stop hook added → $SETTINGS_FILE"
fi

# ── 5. Validate ───────────────────────────────────────────────────────────────
jq -e --arg cmd "$HOOK_CMD" \
    '[.hooks.Stop[]?.hooks[]? | select(.type == "command" and .command == $cmd)] | length > 0' \
    "$SETTINGS_FILE" > /dev/null
ok "Settings validated"

# ── Done ──────────────────────────────────────────────────────────────────────
hr
echo ""
echo "  Autocompact installed."
echo ""
echo "  Next step: run /autocompact once in Claude Code"
echo "  to set your context threshold (default: 80%)."
echo "  Auto mode is active in all repos after that."
echo ""
