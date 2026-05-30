#!/usr/bin/env bash
# Autocompact uninstaller
#
# Usage: bash uninstall.sh
#        curl -fsSL https://raw.githubusercontent.com/joan-chiangwq/skillmaxxing/main/.claude/skills/autocompact/uninstall.sh | bash
#
# What this does:
#   1. Removes ~/.claude/skills/autocompact/
#   2. Removes the Stop hook from ~/.claude/settings.json

set -euo pipefail

INSTALL_DIR="$HOME/.claude/skills/autocompact"
SETTINGS_FILE="$HOME/.claude/settings.json"
HOOK_CMD="bash ~/.claude/skills/autocompact/scripts/check-and-fire.sh"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓${NC}  $1"; }
warn() { echo -e "${YELLOW}  ⚠${NC}  $1"; }
err()  { echo -e "${RED}  ✗${NC}  $1"; }
hr()   { echo "  ────────────────────────────────────────"; }

echo ""
echo "  Uninstalling autocompact..."
echo ""
hr

# ── 1. Remove skill files ─────────────────────────────────────────────────────
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    ok "Removed $INSTALL_DIR"
else
    warn "Skill directory not found — already removed"
fi

# ── 2. Remove Stop hook from ~/.claude/settings.json ─────────────────────────
if [ ! -f "$SETTINGS_FILE" ]; then
    warn "No settings.json found — nothing to clean up"
else
    if ! command -v jq &>/dev/null; then
        err "jq not found — cannot auto-remove hook."
        echo ""
        echo "  Remove it manually: open ~/.claude/settings.json and delete"
        echo "  the entry containing:"
        echo "    \"command\": \"$HOOK_CMD\""
        echo ""
    elif ! jq empty "$SETTINGS_FILE" 2>/dev/null; then
        err "$SETTINGS_FILE contains invalid JSON — skipping hook removal."
        echo "  Fix the file manually and delete the entry containing:"
        echo "    \"command\": \"$HOOK_CMD\""
    else
        HOOK_COUNT=$(jq --arg cmd "$HOOK_CMD" \
            '[.hooks.Stop[]?.hooks[]? | select(.type == "command" and .command == $cmd)] | length' \
            "$SETTINGS_FILE" 2>/dev/null || echo "0")

        if [ "$HOOK_COUNT" -eq 0 ]; then
            warn "Stop hook not found in settings.json — already removed"
        else
            TMP=$(mktemp)
            jq --arg cmd "$HOOK_CMD" '
                .hooks.Stop |= (
                    map(
                        .hooks = ([.hooks[]? | select(.type != "command" or .command != $cmd)])
                    )
                    | map(select((.hooks | length) > 0))
                )
                | if (.hooks.Stop | length) == 0 then del(.hooks.Stop) else . end
                | if ((.hooks // {}) | length) == 0 then del(.hooks) else . end
            ' "$SETTINGS_FILE" > "$TMP"
            mv "$TMP" "$SETTINGS_FILE"
            ok "Stop hook removed from $SETTINGS_FILE"
        fi
    fi
fi

hr
echo ""
echo "  Autocompact uninstalled."
echo "  Snapshots in your repos' /compacted/ folders were not deleted."
echo ""
