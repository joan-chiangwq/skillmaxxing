---
name: auto-compact
description: Summarises the active conversation into a structured markdown file in compacted/ when context crosses a configurable percentage threshold, or on manual invocation. Stores YYYY-MM-DD-<topic-slug>.md in the working repository.
type: skill
output_dir: null
---

## 1. Skill identity

- **name**: `auto-compact`
- **description**: Summarises the active conversation into a structured markdown file in `compacted/` when context crosses a configurable percentage threshold, or on manual invocation. Stores `YYYY-MM-DD-<topic-slug>.md` in the working repository.
- **type**: skill
- **output_dir**: null (Global install — `~/.claude/skills/auto-compact/`)

---

## 2. Trigger conditions

- User invokes `/auto-compact` manually (bypasses threshold check)
- A Claude Code hook fires when context usage reaches or exceeds the configured percentage threshold (default 80%)
- User says "compact this conversation", "save context", "summarise and clear"
- Any invocation where the user asks to preserve context before clearing

---

## 3. Persona

Omitted — this is a task-oriented summarisation skill. No specialist human role is implied.

---

## 4. Inputs and outputs

**Inputs**
- Full conversation history (all messages in the current context window)
- Any open files or diffs currently loaded into context
- Configuration: threshold percentage (default 80%), exclusion list (files or content to skip), output folder (default `compacted/`)

**Outputs**
- A structured markdown file written to `compacted/YYYY-MM-DD-<topic-slug>.md` in the active working repository
- Inline warning to the user (auto path only) before generation begins
- Post-generation prompt instructing the user to clear context and paste the file to resume

---

## 5. Workflow

### Diagram

```
        ◇ invocation path? ◇
               │
    ┌── auto ──┤── manual ─────────────────────────┐
    │          │                                    │
    ▼          │                                    ▼
◇ context ≥   │                    ┌──────────────────────┐
  threshold? ◇ │                    │ [1] Collect conv +   │
    │          │                    │     open files       │
    no         │                    └──────────┬───────────┘
    │          │                               │
    ▼          │                               │
◆ END ◆        │                               │
               │                               │
    auto: yes  │                               │
    │          │                               │
    ▼          ▼                               │
┌──────────────────────┐                       │
│ [1] Warn user inline │                       │
│     "Context at X%"  │                       │
└──────────┬───────────┘                       │
           │                                   │
           ▼                                   │
┌──────────────────────┐                       │
│ [2] Collect conv +   │                       │
│     open files       │                       │
└──────────┬───────────┘                       │
           │                                   │
           └───────────────────────────────────┘
                                │
                                ▼
               ◇ compacted/ file exists? ◇
                                │
                  ┌── yes ──────┤── no ─────────────┐
                  │             │                    │
                  ▼             │                    ▼
     ╔══════════════════════╗   │   ┌──────────────────────┐
     ║ <HUMAN: overwrite or ║   │   │ [3] Generate markdown │
     ║  save as new?>       ║   │   │     summary           │
     ╚══════════┬═══════════╝   │   └──────────┬───────────┘
                │               │               │
         ┌── abort ──▶ ◆ END ◆  │               │
         │              │       │               │
         overwrite/new  │       │               │
         │              ▼       ▼               │
         └─────────────────────────────────────┘
                                │
                                ▼
                  ┌──────────────────────┐
                  │ [3/4] Generate       │
                  │       markdown       │
                  │       summary        │
                  └──────────┬───────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │ [4/5] Write file to  │
                  │       compacted/     │
                  └──────────┬───────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │ [5/6] Prompt user to │
                  │       clear context  │
                  │       and resume     │
                  └──────────┬───────────┘
                             │
                             ▼
                         ◆ END ◆
```

### Protocol

1. **Determine invocation path.** If triggered by a hook, check whether context usage is at or above the configured threshold (default 80%). If below, exit silently — do not warn, do not generate. If at or above, proceed. If triggered manually via `/auto-compact`, skip the threshold check and proceed unconditionally.

2. **Warn the user (auto path only).** Emit one inline line: "Context at X% — above the N% threshold. Compacting now." Do not emit this on the manual path.

3. **Collect inputs.** Read the full conversation history. Identify any open files or diffs in context. Apply the exclusion list — skip any files or content the user has marked as excluded.

4. **Check for an existing summary file.** Look for any `.md` file in `compacted/` matching today's date and topic slug. If one exists, present a human gate: "compacted/<filename> already exists — overwrite or save as new? (1) overwrite (2) save as new (3) abort". On abort, exit. On overwrite, replace the file. On save as new, auto-increment a suffix (`-2`, `-3`, etc.).

5. **Generate the markdown summary.** Produce a structured document with four sections:
   - `## Goals` — what the user was trying to accomplish in this session
   - `## Decisions made` — concrete choices made, with brief rationale
   - `## Open questions` — unresolved items the user should address next
   - `## Files in context` — list of files loaded during the session (names and purpose)

   If a field is unknown (e.g. a file's purpose was never stated), record "not captured" rather than inventing content.

6. **Write the file.** Create the `compacted/` folder in the active working repository if it does not exist. Write the summary to `compacted/YYYY-MM-DD-<topic-slug>.md`. Derive the topic slug from the dominant subject of the conversation (2–4 words, kebab-case).

7. **Prompt the user to resume.** Emit: "Summary saved to compacted/<filename>. Clear your context and paste the file contents to resume."

---

## 6. Reference files

None required.

---

## 7. Scripts

None required.

---

## Approved test pairs

### Pair A — Happy path

**(1) Prompt:** Context is at 85% — threshold is 80%. Summarise this conversation and save to compacted/.

**(2) Expected output:** Agent warns inline ("Context at 85%, above the 80% threshold — compacting now"), checks for an existing file in `compacted/`, generates a structured markdown file with four sections (Goals, Decisions made, Open questions, Files in context), writes it to `compacted/2026-05-29-smart-compact.md`, then prompts: "Summary saved to compacted/2026-05-29-smart-compact.md. Clear your context and paste the file contents to resume."

**(3) Actual output:** Agent generated the summary and wrote it to `compacted/2026-05-29-smart-compact.md`. Surfaced an unresolved open question about filename format (resolved in spec: `YYYY-MM-DD-<topic-slug>.md`). Auto path triggered correctly.

---

### Pair B — Edge case

**(1) Prompt:** User manually invokes `/auto-compact` when context is at 30% and a `compacted/2026-05-29-compact.md` file already exists.

**(2) Expected output:** Agent bypasses threshold (manual path), detects existing file, presents overwrite gate, on "save as new" auto-increments filename to `2026-05-29-compact-2.md`, writes four-section summary, prompts user to clear context.

**(3) Actual output:** Threshold correctly bypassed at 30% (manual path). Overwrite gate triggered — three options presented. On "save as new", auto-incremented to `2026-05-29-compact-2.md`. All four required sections present. Gap handled correctly — unknown filename recorded as "not captured" rather than invented.
