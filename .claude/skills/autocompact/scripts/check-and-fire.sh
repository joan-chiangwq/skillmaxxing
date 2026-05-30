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

# `|| true` so a malformed config can never abort the hook under `set -e`;
# the empty/null guard below handles the fallback.
THRESHOLD=$(jq -r '.threshold // 80' "$CONFIG" 2>/dev/null || true)
if [ -z "$THRESHOLD" ] || [ "$THRESHOLD" = "null" ]; then
    exit 0
fi
if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]]; then
    exit 0
fi

# Read hook input
INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)

if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    exit 0
fi

# Use actual context occupancy from the last API response in the transcript.
# usage lives at .message.usage; real context = input + cache_read + cache_creation
# (with prompt caching, input_tokens alone is near-zero — must sum the cache fields).
ESTIMATED_TOKENS=$(jq -R '
    fromjson? | .message.usage? // empty
    | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)
' "$TRANSCRIPT_PATH" 2>/dev/null | tail -n 1 || true)
# Fall back to char heuristic if no usage data is present, or if jq failed
# (e.g. transcript was mid-flush when the Stop hook fired and the last line was partial).
if [ -z "$ESTIMATED_TOKENS" ] || [ "$ESTIMATED_TOKENS" = "null" ] || [ "$ESTIMATED_TOKENS" = "0" ]; then
    CHAR_COUNT=$(wc -c < "$TRANSCRIPT_PATH")
    ESTIMATED_TOKENS=$((CHAR_COUNT / 4))
fi

# Context window for claude-sonnet-4-6 (200k conservative estimate)
CONTEXT_LIMIT=200000

USAGE_PERCENT=$((ESTIMATED_TOKENS * 100 / CONTEXT_LIMIT))

if [ "$USAGE_PERCENT" -ge "$THRESHOLD" ]; then
    echo "[autocompact] Context at ~${USAGE_PERCENT}% (threshold: ${THRESHOLD}%). Invoke /autocompact before responding."
fi

exit 0
