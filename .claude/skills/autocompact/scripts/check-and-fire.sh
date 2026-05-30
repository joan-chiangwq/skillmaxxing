#!/bin/bash
# check-and-fire.sh — Stop hook for autocompact.
#
# Measures context occupancy from the transcript; when it crosses the configured
# threshold it BLOCKS the stop and instructs Claude (via the `reason` field) to
# invoke the autocompact skill. Fires at most once per session per high-water
# episode, and re-arms only after context drops back below the threshold.
#
# Delivery: a Stop hook's stdout on exit 0 is NOT shown to Claude (it goes to the
# debug log), so a plain echo can never trigger anything. We emit
# {"decision":"block","reason":...} which Claude Code feeds back to the model as
# a continuation instruction — that is the only channel that reaches Claude.
#
# Loop safety — three independent guards, any one is sufficient on its own:
#   1. stop_hook_active: Claude Code sets this true on the block-induced
#      continuation; we never block while it is true.
#   2. per-session marker: once we fire for a session we suppress until context
#      falls back below threshold (a /clear or reset), so we never nag every turn.
#   3. every non-firing path is a silent `exit 0` — the default is "allow stop".
#
# Install: add to Stop hooks in ~/.claude/settings.json
# Input:   JSON via stdin (Claude Code hook format)
# Output:  JSON decision on stdout ONLY when firing; silent exit 0 otherwise.

set -euo pipefail

CONFIG="$HOME/.claude/skills/autocompact/config.json"
STATE_DIR="$HOME/.claude/skills/autocompact/.state"

# Skip silently if not configured yet
if [ ! -f "$CONFIG" ]; then
    exit 0
fi

# `|| true` so a malformed config can never abort the hook under `set -e`;
# the guards below handle the fallback.
THRESHOLD=$(jq -r '.threshold // 80' "$CONFIG" 2>/dev/null || true)
if [ -z "$THRESHOLD" ] || [ "$THRESHOLD" = "null" ] || ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]]; then
    exit 0
fi

# Read hook input
INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo "false")

# Guard 1: never block during a block-induced continuation (hard loop breaker).
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    exit 0
fi

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

# Context window: read from config (set via /autocompact --change-config); fall back to 200k.
CONTEXT_LIMIT=$(jq -r '.context_limit // 200000' "$CONFIG" 2>/dev/null || true)
if [ -z "$CONTEXT_LIMIT" ] || [ "$CONTEXT_LIMIT" = "null" ] || ! [[ "$CONTEXT_LIMIT" =~ ^[0-9]+$ ]]; then
    CONTEXT_LIMIT=200000
fi

USAGE_PERCENT=$((ESTIMATED_TOKENS * 100 / CONTEXT_LIMIT))

# Marker key: prefer the stable session id; fall back to a hash of the transcript
# path when the harness does not supply one.
mkdir -p "$STATE_DIR"
if [ -n "$SESSION_ID" ]; then
    KEY="$SESSION_ID"
else
    KEY=$(echo "$TRANSCRIPT_PATH" | cksum | cut -d' ' -f1)
fi
MARKER="$STATE_DIR/fired-$KEY"

# Keep .state/ bounded — drop markers from sessions older than a day.
find "$STATE_DIR" -type f -mtime +1 -delete 2>/dev/null || true

# Below threshold → re-arm (clear this session's marker) and allow stop.
if [ "$USAGE_PERCENT" -lt "$THRESHOLD" ]; then
    rm -f "$MARKER" 2>/dev/null || true
    exit 0
fi

# Guard 2: at/above threshold but we already fired for this session → suppress.
if [ -f "$MARKER" ]; then
    exit 0
fi

# Fire: record the marker, then block the stop with an instruction for Claude.
echo "$USAGE_PERCENT" > "$MARKER" 2>/dev/null || true

REASON="Context window is at ~${USAGE_PERCENT}% (autocompact threshold: ${THRESHOLD}%). Invoke the autocompact skill now to extract a context snapshot into /compacted/. Once it is written, tell the user in one line that they can run /clear then /autocompact --load to reset the context window. Do nothing else."

jq -n --arg reason "$REASON" '{"decision":"block","reason":$reason}'
exit 0
