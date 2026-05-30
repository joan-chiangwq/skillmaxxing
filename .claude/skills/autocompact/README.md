# Autocompact

A Claude Code skill that compresses conversation context into structured 200–400 token snapshots — 4–5× smaller than native compact — without sacrificing memory recall.

Native compact treats compression as summarization and produces prose averaging 800–2,000 tokens. Autocompact treats it as information extraction: content is classified into a fixed schema and emitted as noun phrases and key-value pairs. Only the final state of any evolving fact is kept. Superseded decisions are discarded.

---

## Installation

### Option 1 — Install script (macOS / Linux / Windows WSL)

```bash
curl -fsSL https://raw.githubusercontent.com/joan-chiangwq/skillmaxxing/main/.claude/skills/autocompact/install.sh | bash
```

Downloads all skill files to `~/.claude/skills/autocompact/` and wires the Stop hook into `~/.claude/settings.json`. No repo clone needed. Run the same command to update.

**Requires:** `jq` and `curl`. Install `jq` for your platform:

| Platform | Command |
|----------|---------|
| macOS | `brew install jq` |
| Linux (apt) | `sudo apt-get install jq` |
| Linux (dnf) | `sudo dnf install jq` |
| Windows (winget) | `winget install jqlang.jq` |
| Windows (Chocolatey) | `choco install jq` |
| Windows (Scoop) | `scoop install jq` |

> **Windows:** run from Git Bash, WSL, or MSYS2. The auto mode hook also requires bash — Claude Code on Windows uses Git Bash or WSL to run hook scripts.

### Option 2 — Clone the repo

```bash
git clone --branch main --single-branch https://github.com/joan-chiangwq/skillmaxxing.git
```

Skills under `.claude/skills/` register automatically when Claude Code is opened in the cloned directory. No extra configuration needed for manual and load modes. To enable auto mode globally, run `bash install.sh` from inside the clone.

---

## After installing

Run `/autocompact` once in Claude Code. You will be prompted to set your context threshold (default: 80%). Auto mode is active across all repos after that.

---

## Usage

| Command | What it does |
|---------|-------------|
| `/autocompact` | Compress context now (Manual mode) |
| `/autocompact --load` | Load the latest snapshot and resume session |
| `/autocompact --load-select` | Choose which snapshot to load from a numbered list |
| `/autocompact --change-config` | Update threshold and context window size |

Auto mode fires without any command — when context hits your configured threshold, Claude writes a snapshot automatically. Run `/clear` then `/autocompact --load` to actually reset the context window.

---

## How it works

### Snapshot format

Every snapshot is a structured markdown file saved to `/compacted/<YYYY-MM-DD>-N.md` in the working repo.

```
generated: 2026-05-30T14:22:00Z
session: i-want-to-add-dark-mode

## entities
- theme toggle: UI component, sidebar next to user avatar

## decisions
- persistence: cookie named `theme`, SameSite=Lax, Path=/ (not localStorage; SSR requirement)
- toggle placement: sidebar next to user avatar (not top-right nav bar)

## state
CSS variables drafted and approved; next: wire React toggle component

## facts
- light --accent: #3b82f6
- dark --accent: #60a5fa
- cookie key: theme

## open items
- React toggle component wiring

## tone
- technical, iterative decisions
- preference changes accepted without friction
```

Six sections, always in this order:

| Section | What goes in | Hard cap |
|---------|-------------|----------|
| **entities** | Named things referenced in the session | None — omit anything not cross-referenced |
| **decisions** | Resolved choices, final state only | None — superseded choices are removed |
| **state** | One line: `<past participle>; next: <imperative>` | Exactly one line |
| **facts** | Specific values as key-value pairs | None — only values that break continuity if lost |
| **open items** | Unresolved questions and pending tasks | None — remove closed items |
| **tone** | How the user communicates | Three bullets maximum |

### Extraction rules

- **Noun phrases only** — no prose sentences anywhere except the `state` line
- **Final state only** — if a fact changed three times, only the last answer survives
- **Discard filler** — acknowledgements, pleasantries, and meta-commentary are not extracted
- **Key-value pairs for facts** — `pyjwt-version: 2.8.0`, not "We decided to use PyJWT version 2.8.0"

### Token guard

If the snapshot exceeds 500 tokens, autocompact warns and recommends falling back to Claude's native compact instead of writing a bloated file. Target is 200–400 tokens.

### Auto mode

Auto mode uses a Stop hook — a shell script that runs after every Claude response at zero token cost. When context exceeds your threshold, the hook **blocks the stop** and returns `{"decision":"block","reason":...}`; Claude Code feeds the reason back to the model, so Claude invokes autocompact and writes a snapshot before stopping. (A Stop hook's plain stdout is invisible to the model — `decision: block` is the only channel that reaches Claude.)

Writing a snapshot captures your context to disk; it does not shrink the live window. To actually reduce context, run `/clear` then `/autocompact --load`. The hook fires **once per high-water episode** — it never re-fires while `stop_hook_active` is set, a per-session marker suppresses repeats, and it re-arms once context drops back below threshold (e.g. after `/clear`). No nested loop.

- **Hook cost:** zero tokens (runs outside Claude's context)
- **Compact cost:** ~1,000–2,000 tokens per firing (same as running `/autocompact` manually)
- **Threshold config:** stored globally at `~/.claude/skills/autocompact/config.json` — applies across all repos

Context measurement reads the true token occupancy reported by the API in the transcript (`input_tokens + cache_read_input_tokens + cache_creation_input_tokens`) against a 200k baseline. It falls back to a coarse character-count heuristic (~4 chars/token) only when a transcript has no usage data.

---

## First-time flow

```
User:  /autocompact

Claude: This is the first time autocompact has been activated.
        What context threshold? [default: 80%]

User:  75%

Claude: Autocompact configured. Threshold set to 75%.
        Auto mode will fire at 75% context usage across all repos.
```

Setup is a one-time prompt. All subsequent `/autocompact` invocations go straight to compacting.

---

## Load a previous session

After clearing context:

```
User:  /autocompact --load

Claude: Loading latest snapshot: /compacted/2026-05-30-2.md

        Session restored. Here's where we left off:
        [summary of snapshot contents]
        Ready to continue.
```

Use `--load-select` to pick from a list when you have multiple snapshots and want an older one.

---

## File structure

```
autocompact/
├── install.sh                  ← run this to install
├── README.md                   ← this file
├── SKILL.md                    ← skill protocol (loaded by Claude Code)
├── refs/
│   └── snapshot-schema.md      ← six-section schema contracts and worked example
└── scripts/
    └── check-and-fire.sh       ← Stop hook script for auto mode
```

---

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/joan-chiangwq/skillmaxxing/main/.claude/skills/autocompact/uninstall.sh | bash
```

Removes `~/.claude/skills/autocompact/` and cleans the Stop hook out of `~/.claude/settings.json` automatically. Snapshots already saved in your repos' `/compacted/` folders are not deleted.
