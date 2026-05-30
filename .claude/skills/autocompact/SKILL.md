---
name: autocompact
description: >
  Compresses conversation context into structured 200–400 token markdown
  snapshots using information extraction, not summarization. Invoke with
  /autocompact (Manual), auto-fires at a configurable context threshold,
  or use flags: --load (latest snapshot), --load-select (choose snapshot),
  --change-config (update threshold and context window size).
model: claude-sonnet-4-6
---

# Autocompact

## Usage

**Invoke**: `/autocompact [--load | --load-select | --change-config]`

- `/autocompact` → Manual mode — compress context now
- `/autocompact --load` → Load latest snapshot from `/compacted/`
- `/autocompact --load-select` → Choose a snapshot to load from a numbered list
- `/autocompact --change-config` → Update threshold and context window size
- Context window reaches configured threshold → Auto mode fires automatically
- User asks to "compact", "compress context", or "save session" → Manual mode

## Inputs

| Name | Format | Source |
|------|--------|--------|
| flag | `--load`, `--load-select`, `--change-config`, or none | invocation args |
| conversation history | in-memory context | Claude's active session (Manual / Auto) |
| snapshot file | `.md` file in `/compacted/` | disk, read on Load modes |
| config | `threshold` (integer %) + `context_limit` (integer tokens) | `~/.claude/skills/autocompact/config.json`; set on first activation via interview |

## Outputs

| Name | Format | Destination |
|------|--------|-------------|
| snapshot | bullet-compressed `.md`, 200–400 tokens | `/compacted/<YYYY-MM-DD>-N.md` |
| token warning | inline message | displayed when output exceeds 500 tokens |
| ready signal | inline message | displayed after Auto mode writes snapshot |
| file list | numbered list | displayed in Load Select mode |
| config confirmation | inline message | displayed after config change |

## Step-by-step protocol

**Step 1 — Parse invocation**
Read the invocation. Detect flag if present: `--load`, `--load-select`, or `--change-config`. No flag + no threshold reached → Manual. Context threshold reached → Auto.

**Step 2 — First activation check (all modes)**
Read `~/.claude/skills/autocompact/config.json`. If the file does not exist or is missing either `threshold` or `context_limit`, this is the first ever activation: run the config interview (see below). Store both values to `~/.claude/skills/autocompact/config.json`. Emit "Autocompact configured. Threshold: X%, context window: Yk tokens. Auto mode will fire at X% usage." then EXIT — do not compact, do not proceed to Step 3. On all subsequent invocations, read both values from the config and skip this step.

**Config interview** (used in Step 2 and Step 4):
Present two questions in sequence. Show current values in parentheses when re-configuring; show defaults when first-run.

Q1 — Context window size:
```
Context window size?
  [1] 200k — standard  (default for most models, or usage credits not enabled)
  [2] 1M   — extended  (Opus 4.x, or Sonnet 4.6 with usage credits enabled)
```
Wait for user to enter 1 or 2. Map: 1 → 200000, 2 → 1000000.

Q2 — Auto-compact threshold:
```
Auto-compact threshold?
  [1] 70%
  [2] 80%  (default)
  [3] 90%
  [4] Custom
```
Wait for user to enter 1–4. If 4, prompt: "Enter percentage (1–99):". Accept integer. Store as `threshold`.

**Step 3 — Route by mode**
Branch to the correct steps based on the detected mode:
- `--change-config` → Steps 4–5
- `--load-select` → Steps 6–8
- `--load` → Steps 9–10
- Auto → Steps 11–16
- Manual → Steps 13–15

**Step 4 (--change-config) — Run config interview**
Read current values from `~/.claude/skills/autocompact/config.json` and display them as "(current: X)" in each question. Run the config interview. Write both values back to `~/.claude/skills/autocompact/config.json`.

**Step 5 (--change-config) — Confirm**
Emit one line: "Config updated. Threshold: X%, context window: Yk tokens." Exit.

**Step 6 (--load-select) — Check and list snapshots**
Check whether `/compacted/` exists and contains `.md` files. If not: warn "No snapshots found" and exit. List all `.md` files sorted by date descending then N descending. Present a numbered list to the user.

**Step 7 (--load-select) — Human selects file**
Wait for the user to choose a number from the list. Read the selected file.

**Step 8 (--load-select) — Restore context**
Summarise the snapshot contents to the user so the session can resume. Exit.

**Step 9 (--load) — Find and load latest**
Check whether `/compacted/` exists and contains `.md` files. If not: warn "No snapshots found" and exit. Scan all `.md` files, sort by date descending then N descending. Read the latest file.

**Step 10 (--load) — Restore context**
Summarise the snapshot contents to the user so the session can resume. Exit.

**Step 11 (Auto only) — Check context percentage**
Read the current context window usage. If below threshold, exit silently. If at or above threshold, continue.

**Step 12 (Auto only) — Announce**
Emit one line: "Context at X%. Compacting now…"

**Step 13 (Manual / Auto) — Extract and classify context**
Treat compression as information extraction, not summarization. Apply the six-section schema (see `refs/snapshot-schema.md`):
- Discard filler, acknowledgements, repeated context, and superseded facts
- Keep only the final state of any evolving fact
- Emit noun phrases and key-value pairs only — no prose sentences
- facts: explicit key-value pairs for all specific values (names, numbers, paths, versions, thresholds)
- state: exactly one line — format must be `<past participle>; next: <imperative verb phrase>` (e.g. `decisions finalised; next: scaffold the project`)
- tone: hard cap at three bullets

**Step 14 — Token check**
Estimate the token count of the drafted snapshot. If > 500: warn the user with the actual count and recommend Claude's native compact. Do not write. Exit. If ≤ 500: proceed.

**Step 15 — Write snapshot**
Check whether `/compacted/` exists in the working repo. If not, create it. Obtain today's date by running: date +%Y-%m-%d. Use the shell output as the date prefix — do not infer it from conversation context or system messages. Count existing `.md` files with today's date prefix to determine N (1 if none). Write the snapshot to `/compacted/<YYYY-MM-DD>-N.md`. Confirm written.

**Step 16 (Auto only) — Signal ready**
Emit one line: "Done. Ready to clear and load."

## Auto mode — hook setup

Auto mode requires a Stop hook in `~/.claude/settings.json`. The hook runs `scripts/check-and-fire.sh` after every Claude response. The script reads the actual context occupancy from the session transcript and, when the threshold is hit, **blocks the stop** and returns `{"decision":"block","reason":...}`. A Stop hook's plain stdout is not visible to Claude — `decision: block` is the only channel that reaches the model. Claude Code feeds `reason` back to Claude as a continuation instruction, so Claude invokes the autocompact skill and writes a snapshot before fully stopping.

Writing a snapshot does **not** shrink the live context window — it only captures it to disk. The actual reduction happens when the user runs `/clear` then `/autocompact --load`. Auto mode therefore auto-*captures*; the reset stays manual.

**Loop safety.** The hook fires at most once per session per high-water episode, via three independent guards: (1) it never blocks when `stop_hook_active` is true (the continuation a block triggers); (2) a per-session marker in `~/.claude/skills/autocompact/.state/` suppresses re-firing until context drops back below threshold; (3) every non-firing path is a silent `exit 0`. The marker is cleared (re-armed) once usage falls below threshold, e.g. after a `/clear`.

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/skills/autocompact/scripts/check-and-fire.sh"
          }
        ]
      }
    ]
  }
}
```

**Token cost of the hook:** zero — the shell script runs outside Claude's context. Tokens are only used when `/autocompact` fires.

**Context estimation:** the script reads the true context occupancy from the last API response in the transcript JSONL (`.message.usage`), summing `input_tokens + cache_read_input_tokens + cache_creation_input_tokens` against the configured `context_limit`. The cache fields are essential — with prompt caching, `input_tokens` alone is near-zero because most context is served from cache. If a transcript has no usage data, the script falls back to a coarse character-count heuristic (~4 chars/token), which may fire slightly early or late. Falls back to 200000 if `context_limit` is not set in config.

## References

- `refs/snapshot-schema.md` — six-section schema definition with per-section contracts, extraction rules, and example output
- `scripts/check-and-fire.sh` — Stop hook script; reads true context occupancy from the transcript and, when the threshold is hit, blocks the stop with `{"decision":"block","reason":...}` to make Claude invoke autocompact. Uses `context_limit` from config for the denominator. Fires once per high-water episode via `stop_hook_active` + a per-session marker
