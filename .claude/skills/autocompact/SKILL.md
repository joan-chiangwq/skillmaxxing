---
name: autocompact
description: >
  Compresses conversation context into structured 200–400 token markdown
  snapshots using information extraction, not summarization. Invoke with
  /autocompact (Manual), auto-fires at a configurable context threshold,
  or use flags: --load (latest snapshot), --load-select (choose snapshot),
  --change-threshold (update threshold).
model: claude-sonnet-4-6
---

# Autocompact

## Usage

**Invoke**: `/autocompact [--load | --load-select | --change-threshold]`

- `/autocompact` → Manual mode — compress context now
- `/autocompact --load` → Load latest snapshot from `/compacted/`
- `/autocompact --load-select` → Choose a snapshot to load from a numbered list
- `/autocompact --change-threshold` → Update the auto-compact context threshold
- Context window reaches configured threshold → Auto mode fires automatically
- User asks to "compact", "compress context", or "save session" → Manual mode

## Inputs

| Name | Format | Source |
|------|--------|--------|
| flag | `--load`, `--load-select`, `--change-threshold`, or none | invocation args |
| conversation history | in-memory context | Claude's active session (Manual / Auto) |
| snapshot file | `.md` file in `/compacted/` | disk, read on Load modes |
| threshold setting | percentage integer | global config at `~/.claude/skills/autocompact/config.json`; prompted on first ever activation across any repo |

## Outputs

| Name | Format | Destination |
|------|--------|-------------|
| snapshot | bullet-compressed `.md`, 200–400 tokens | `/compacted/<YYYY-MM-DD>-N.md` |
| token warning | inline message | displayed when output exceeds 500 tokens |
| ready signal | inline message | displayed after Auto mode writes snapshot |
| file list | numbered list | displayed in Load Select mode |
| threshold confirmation | inline message | displayed after threshold change |

## Step-by-step protocol

**Step 1 — Parse invocation**
Read the invocation. Detect flag if present: `--load`, `--load-select`, or `--change-threshold`. No flag + no threshold reached → Manual. Context threshold reached → Auto.

**Step 2 — First activation check (all modes)**
Read `~/.claude/skills/autocompact/config.json`. If the file does not exist or contains no `threshold` field, this is the first ever activation across all repos: prompt the user once to set a context threshold percentage (default 80%). Store the value to `~/.claude/skills/autocompact/config.json`. Emit "Autocompact configured. Threshold set to X%. Auto mode will fire at X% context usage." then EXIT — do not compact, do not proceed to Step 3. On all subsequent invocations in any repo, read the threshold from the global config and skip this step.

**Step 3 — Route by mode**
Branch to the correct steps based on the detected mode:
- `--change-threshold` → Steps 4–5
- `--load-select` → Steps 6–8
- `--load` → Steps 9–10
- Auto → Steps 11–15
- Manual → Steps 12–15

**Step 4 (--change-threshold) — Prompt for new threshold**
Read current threshold from `~/.claude/skills/autocompact/config.json`. Ask the user: "New context threshold? (current: X%) [default: 80%]". Accept a percentage integer. Write the new value back to `~/.claude/skills/autocompact/config.json`.

**Step 5 (--change-threshold) — Confirm**
Emit one line: "Threshold updated to X%." Exit.

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
Check whether `/compacted/` exists in the working repo. If not, create it. Count existing `.md` files with today's date prefix to determine N (1 if none). Write the snapshot to `/compacted/<YYYY-MM-DD>-N.md`. Confirm written.

**Step 16 (Auto only) — Signal ready**
Emit one line: "Done. Ready to clear and load."

## Auto mode — hook setup

Auto mode requires a Stop hook in `~/.claude/settings.json`. The hook runs `scripts/check-and-fire.sh` after every Claude response. The script estimates context usage from the session transcript and injects a notification when the threshold is hit. Claude sees the notification and invokes `/autocompact` before answering the next message.

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

**Context estimation:** the script estimates usage from transcript character count (~4 chars/token against a 200k token baseline). This is an approximation; the hook may fire slightly early or late relative to the exact threshold.

## References

- `refs/snapshot-schema.md` — six-section schema definition with per-section contracts, extraction rules, and example output
- `scripts/check-and-fire.sh` — Stop hook script; estimates context usage and injects autocompact notification when threshold is hit
