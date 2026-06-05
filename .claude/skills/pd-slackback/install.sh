#!/usr/bin/env bash
# SlackBack installer
#
# Works two ways:
#   curl -fsSL https://raw.githubusercontent.com/joan-chiangwq/skillmaxxing/main/.claude/skills/pd-slackback/install.sh | bash
#   bash install.sh   (from a local clone)
#
# What this does:
#   1. Downloads skill files to ~/.claude/skills/pd-slackback/
#   2. Prints next steps
#
# After install: open Claude Code and run /pd-slackback to get started.

set -euo pipefail

GITHUB_USER="joan-chiangwq"
GITHUB_REPO="skillmaxxing"
GITHUB_BRANCH="main"
RAW="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$GITHUB_BRANCH/.claude/skills/pd-slackback"

INSTALL_DIR="$HOME/.claude/skills/pd-slackback"

# ── Output helpers ────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓${NC}  $1"; }
warn() { echo -e "${YELLOW}  ⚠${NC}  $1"; }
err()  { echo -e "${RED}  ✗${NC}  $1"; }
hr()   { echo "  ────────────────────────────────────────"; }

echo ""
echo "  Installing SlackBack..."
echo ""
hr

# ── 1. Check dependencies ─────────────────────────────────────────────────────
if ! command -v curl &>/dev/null; then
    err "curl is required but not installed."
    echo "  Install curl via your system package manager."
    echo ""
    exit 1
fi
ok "Dependencies OK"

# ── 2. Detect source: local clone or remote download ──────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || echo "")"
USE_LOCAL=false
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/SKILL.md" ]; then
    USE_LOCAL=true
fi

# Complete file manifest — used for REMOTE installs, where raw URLs cannot list
# a directory. Keep this in sync when adding skill files. Local installs mirror
# the whole directory via find (below), so they pick up new files automatically.
MANIFEST=(
    "SKILL.md"
    "README.md"
    "install.sh"
    "refs/pd-company-values.md"
    "refs/sbi-guide.md"
    "refs/360-question.md"
    "refs/project-scope-filter.md"
)

# ── 3. Install skill files ────────────────────────────────────────────────────
mkdir -p "$INSTALL_DIR/refs"

COUNT=0
if [ "$USE_LOCAL" = true ]; then
    while IFS= read -r -d '' src; do
        rel="${src#"$SCRIPT_DIR"/}"
        dest="$INSTALL_DIR/$rel"
        mkdir -p "$(dirname "$dest")"
        if [ "$src" != "$dest" ]; then
            cp "$src" "$dest"
        fi
        COUNT=$((COUNT + 1))
    done < <(find "$SCRIPT_DIR" -type f -not -name "*.json" -print0)
else
    for rel in "${MANIFEST[@]}"; do
        dest="$INSTALL_DIR/$rel"
        mkdir -p "$(dirname "$dest")"
        curl -fsSL "$RAW/$rel" -o "$dest"
        COUNT=$((COUNT + 1))
    done
fi

[ -f "$INSTALL_DIR/install.sh" ] && chmod +x "$INSTALL_DIR/install.sh" || true

ok "Skill files installed ($COUNT files) → $INSTALL_DIR"

# ── Done ──────────────────────────────────────────────────────────────────────
hr
echo ""
echo "  SlackBack installed."
echo ""
echo "  Requirements:"
echo "    - Slack MCP configured in Claude Code (https://mcp.slack.com)"
echo "    - Slack MCP authenticated to your workspace"
echo ""
echo "  Usage:"
echo "    /pd-slackback <colleague name>, <start date> to <end date>"
echo "    /pd-slackback Sandy Wong, Jan 1 2026 to today"
echo ""
