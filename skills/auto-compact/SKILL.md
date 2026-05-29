---
name: auto-compact
description: Summarises the active conversation into a structured markdown file in compacted/ when context crosses a configurable percentage threshold, or on manual invocation. Stores YYYY-MM-DD-<topic-slug>.md in the working repository. Use when context is filling up or when you want to preserve a decision trail before clearing.
model: claude-sonnet-4-6
---

## Usage

**Invoke**: `/auto-compact [--change-threshold [N]]` — run without args to compact, or pass `--change-threshold` to update the threshold.

- Slash command `/auto-compact`
- Slash command `/auto-compact --change-threshold` — prompts for a new threshold value
- Slash command `/auto-compact --change-threshold 70` — sets threshold to 70 directly
- Natural-language: "compact this conversation", "save context", "summarise and clear", "preserve context before clearing"
- Natural-language: "change the compact threshold", "update auto-compact threshold to N"
- Automatic: hook fires when context usage reaches or exceeds the configured threshold. Configure the hook in `settings.json` under the `stop` event — the payload delivers `context_usage_percent` as a JSON field via stdin.

## Inputs

| Name | Format | Source |
|------|--------|--------|
| conversation history | all messages in the active context window | prior context |
| open files / diffs | any files currently loaded in context | prior context |
| context_usage_percent | JSON number (0–100), auto path only | hook payload via stdin |
| threshold | percentage integer | `~/.claude/skills/auto-compact/config.json` |

## Outputs

| Name | Format | Destination |
|------|--------|-------------|
| summary file | markdown, four sections | `compacted/YYYY-MM-DD-<topic-slug>.md` in the active working repository |
| inline warning | one-line text | shown inline (auto path only) |
| resume prompt | one-line text | shown inline after file is written |
| config file | JSON | `~/.claude/skills/auto-compact/config.json` (written once on first run) |

## Progress emission

Emit `Step X/8 — <title>` at the start of each step, unconditionally.

## Step-by-step protocol

**Step 1 — Load or create configuration**

Check whether the invocation includes `--change-threshold`.

- **`--change-threshold N` present** (N is an integer 1–99): write `{"threshold": N}` to `~/.claude/skills/auto-compact/config.json`. Emit: "Threshold updated to N%." Exit — do not compact.
- **`--change-threshold` present without N**: read the current threshold from `config.json` (use 80 if the file is absent). Prompt: "New threshold percentage? (current: X%)" Wait for an integer 1–99. Write `{"threshold": N}` to `config.json`. Emit: "Threshold updated to N%." Exit — do not compact.

If `--change-threshold` is not present, continue below.

Check whether `~/.claude/skills/auto-compact/config.json` exists.

- **File exists**: read `threshold` from it. Produce: configuration object.
- **File absent**: prompt the user once:

  > "auto-compact needs a one-time setup. What context percentage should trigger automatic compaction? (default: 80)"

  Accept any integer 1–99; use 80 if the user presses enter without a value. Write `{"threshold": <value>}` to `config.json`. Emit: "Configuration saved."

  Produce: configuration object with `threshold`.

**Step 2 — Determine invocation path**

Check whether the skill was invoked by a hook or by the user directly.

- **Hook (auto path)**: read `context_usage_percent` from the hook payload (delivered as JSON via stdin). If the value is below `threshold` from Step 1, exit silently — emit nothing, write nothing. If at or above the threshold, proceed to Step 3.
- **Slash command (manual path)**: skip the threshold check. Proceed directly to Step 4.

Produce: a confirmed path label (`auto` or `manual`).

**Step 3 — Warn the user (auto path only)**

Read: path label from Step 2; `context_usage_percent` and `threshold` from Step 1. This step runs only when the label is `auto`.

Emit one line: "Context at X% — above the N% threshold. Compacting now."

Do not emit this on the manual path.

**Step 4 — Collect inputs**

Read the conversation and open files in two sub-steps:

1. **Read conversation**: collect all messages in the active context window. Produce: ordered list of conversation messages.
2. **Identify files**: list any open files or diffs currently loaded in context. Produce: file list with names and purpose.

Produce: a collected input set (conversation messages + file list).

**Step 5a — Derive topic slug**

Read the collected input set from Step 4. Identify the dominant subject of the conversation (2–4 words, kebab-case). If the conversation covers multiple unrelated topics, use the most recent one.

Produce: topic slug (e.g. `auth-middleware-rewrite`).

**Step 5 — Check for an existing summary file**

Read: topic slug from Step 5a. Look for any `.md` file in `compacted/` matching today's date and that topic slug. If none exists, proceed to Step 6.

If one exists, present a human gate:

> "compacted/<filename> already exists — what should I do?
> (1) overwrite  (2) save as new  (3) abort"

- `abort` → exit, write nothing.
- `overwrite` → replace the existing file in Step 6.
- `save as new` → scan `compacted/` for existing files matching `YYYY-MM-DD-<slug>-N.md` for today's date; take the highest N found (default 1 if none); increment by 1; write the new file in Step 6.

Produce: a resolved output path.

**Step 6 — Generate the markdown summary**

Read the collected input set from Step 4, the topic slug from Step 5a, and the resolved output path from Step 5. Generate in two sub-steps:

1. **Construct filename**: combine today's date and the topic slug into `YYYY-MM-DD-<topic-slug>.md`. Produce: resolved filename.
2. **Generate document**: produce a structured markdown document with exactly six sections:
   - `## Goals` — what the user was trying to accomplish in this session
   - `## Decisions made` — concrete choices made, with brief rationale
   - `## Open questions` — unresolved items the user should address next
   - `## Files in context` — list of files loaded during the session (names and purpose)
   - `## Commands run` — shell commands or tool calls executed, in order, with outcomes
   - `## Errors encountered` — errors or failures seen, with the resolution or current status

   If a field is unknown, record "not captured" — never invent content.

Produce: a completed markdown document held in memory.

**Step 7 — Write summary file**

Create `compacted/` in the active working repository if it does not exist. If no working repository is detected, write to `./compacted/` in the current directory.

Write the generated document to the resolved output path. If the write fails (permission denied, disk full, or path conflict), emit: "Write failed: <error>. Check permissions on compacted/ and retry." Do not proceed to Step 8.

Produce: the written markdown file at `compacted/<filename>`.

**Step 8 — Prompt user to resume**

Read: written filename from Step 7.

Emit: "Summary saved to compacted/<filename>. Run `/clear` to clear your context, then paste the file contents to resume."

Produce: resume prompt shown inline.
