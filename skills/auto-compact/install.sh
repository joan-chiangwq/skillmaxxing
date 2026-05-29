#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="$HOME/.claude/skills/auto-compact"
SETTINGS="$HOME/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing auto-compact..."

# 1. Copy SKILL.md
mkdir -p "$SKILL_DIR"
cp "$SCRIPT_DIR/SKILL.md" "$SKILL_DIR/SKILL.md"
echo "  Copied SKILL.md → $SKILL_DIR/SKILL.md"

# 2. Wire the Stop hook into settings.json
HOOK_COMMAND="echo '{\"context_usage_percent\": \$CLAUDE_CONTEXT_USAGE_PERCENT}' | claude /auto-compact"

if [[ ! -f "$SETTINGS" ]]; then
  # No settings file — write one from scratch
  cat > "$SETTINGS" <<EOF
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOK_COMMAND"
          }
        ]
      }
    ]
  }
}
EOF
  echo "  Created $SETTINGS with Stop hook"
elif ! grep -q "auto-compact" "$SETTINGS"; then
  # Settings file exists but hook is not present — merge it in with python
  python3 - "$SETTINGS" "$HOOK_COMMAND" <<'PYEOF'
import json, sys

settings_path = sys.argv[1]
hook_command = sys.argv[2]

with open(settings_path) as f:
    settings = json.load(f)

hook_entry = {
    "matcher": "",
    "hooks": [{"type": "command", "command": hook_command}]
}

hooks = settings.setdefault("hooks", {})
stop_hooks = hooks.setdefault("Stop", [])

# Guard: don't add a duplicate
if not any(
    any(h.get("command", "") == hook_command for h in e.get("hooks", []))
    for e in stop_hooks
):
    stop_hooks.append(hook_entry)

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PYEOF
  echo "  Merged Stop hook into $SETTINGS"
else
  echo "  Stop hook already present in $SETTINGS — skipping"
fi

echo ""
echo "Done. auto-compact is ready."
echo "  Auto-trigger: fires when context reaches 80% (edit $CONFIG to change)."
echo "  Manual:       run /auto-compact in any Claude Code session."
