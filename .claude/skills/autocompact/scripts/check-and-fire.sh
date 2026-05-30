#!/bin/bash
# check-and-fire.sh — Stop hook for autocompact.
# Reads context usage from the transcript, compares to configured threshold,
# and injects a notification for Claude to invoke /autocompact when exceeded.
#
# Install: add to Stop hooks in ~/.claude/settings.json
# Input:   JSON via stdin (Claude Code hook format)
# Output:  notification string on stdout when threshold is hit (exit 0)
#          silent exit 0 when below threshold or not configured

set -euo pipefail

CONFIG="$HOME/.claude/skills/autocompact/config.json"

# Skip silently if not configured yet
if [ ! -f "$CONFIG" ]; then
    exit 0
fi

THRESHOLD=$(jq -r '.threshold // 80' "$CONFIG" 2>/dev/null)
if [ -z "$THRESHOLD" ] || [ "$THRESHOLD" = "null" ]; then
    exit 0
fi

# Read hook input
INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)

if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    exit 0
fi

# Estimate token count from transcript character count (~4 chars per token)
CHAR_COUNT=$(wc -c < "$TRANSCRIPT_PATH")
ESTIMATED_TOKENS=$((CHAR_COUNT / 4))

# Context window for claude-sonnet-4-6 (200k conservative estimate)
CONTEXT_LIMIT=200000

USAGE_PERCENT=$((ESTIMATED_TOKENS * 100 / CONTEXT_LIMIT))

if [ "$USAGE_PERCENT" -ge "$THRESHOLD" ]; then
    echo "[autocompact] Context at ~${USAGE_PERCENT}% (threshold: ${THRESHOLD}%). Invoke /autocompact before responding."
fi

exit 0
