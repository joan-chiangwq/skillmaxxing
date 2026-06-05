# SlackBack

A Claude Code skill that drafts evidence-based 360 peer reviews from your real Slack history — no memory required, no vague praise, no blank-page anxiety.

Instead of reconstructing what a colleague did from memory, SlackBack searches your DMs and shared channel threads, filters out social noise, extracts behavioral evidence using the SBI model (Situation → Behavior → Impact), maps each moment to company values, and writes a review draft grounded in what you both actually worked on together.

---

## Requirements

- Claude Code with the [Slack MCP](https://mcp.slack.com) configured and authenticated
- A Slack workspace where you and the colleague share DMs or channel threads

---

## Installation

### Option 1 — Install script (macOS / Linux / Windows WSL)

```bash
curl -fsSL https://raw.githubusercontent.com/joan-chiangwq/skillmaxxing/main/.claude/skills/pd-slackback/install.sh | bash
```

Downloads all skill files to `~/.claude/skills/pd-slackback/`. No repo clone needed. Run the same command to update.

### Option 2 — Clone the repo

```bash
git clone --branch main --single-branch https://github.com/joan-chiangwq/skillmaxxing.git
```

Skills under `.claude/skills/` register automatically when Claude Code is opened in the cloned directory.

---

## Usage

```
/slackback <colleague name>, <start date> to <end date>
```

**Examples:**

```
/slackback Marcus Lee, Jan 1 2026 to Jun 6 2026
```

Also activates when you say:
- "Write a peer review for [name]"
- "Draft a 360 for [name]"
- "Look up what [name] worked on" in a review context

---

## How it works

### Source scoping

SlackBack only retrieves messages where you and the colleague were both directly involved. Two source types qualify:

| Source | Rule |
|--------|------|
| **DMs** | Any direct message thread between you and the colleague |
| **Channel threads** | Threads where the colleague posted or replied, AND you were @mentioned or have replied in the same thread |

Threads where the colleague was active but you had no direct involvement are excluded before any content filtering begins.

### Project-scope filter

After source scoping, every message is classified as RETAIN or DISCARD:

**Discarded:** food and lunch coordination, emoji-only reactions, holiday greetings, personal banter, off-topic channels (#random, #off-topic)

**Retained:** projects, incidents, cross-team coordination, technical decisions, professional deliverables, process improvements

If a thread contains both project content and social content, only the project-relevant portion is used.

### SBI extraction

Each significant professional moment becomes one SBI block:

- **Situation** — the context or challenge that existed
- **Behavior** — what the colleague specifically said or did (observable, not inferred)
- **Impact** — the result or outcome that followed

SBI blocks are built from observed Slack messages, never from impressions or general reputation.

### Company values mapping

Each SBI block is mapped to one or more of the six company values:

| Value | Meaning |
|-------|---------|
| Own It | Taking end-to-end accountability without waiting to be assigned |
| Dive Deep | Engaging at the level of detail that the work actually requires |
| Deliver Value Fast | Moving efficiently from problem identification to resolution |
| Bring Good Vibes | Reducing friction for others; making collaboration easier |
| Raise the Bar | Pushing for structural fixes, not just point solutions |
| Stay Humble | Inviting input, crediting others, treating recommendations as proposals |

### 360 review draft

The draft answers the company 360 question directly:

> "Based on what you've observed of this person, which of their behaviors, skills, knowledge or expertise do you believe helps them to succeed? Provide specific examples and consider the company values."

Every claim in the draft is grounded in a named SBI example. Company values are referenced by exact name. Vague praise without a backing example is never written.

---

## When evidence is thin

If no project-scoped messages are found after filtering, SlackBack refuses to draft and explains exactly what was found and why it doesn't meet the evidence threshold. It then offers four concrete alternatives:

1. **Expand the date range or scope** — try a longer window or different channels
2. **Supplement with other signals** — PRs, tickets, design docs, meeting notes
3. **Request a structured sync** — a short 1-1 with the colleague to gather first-hand examples
4. **Submit a direct-observation note** — an honest "limited visibility" flag in your review tool

---

## Example flow

```
User:  /slackback Marcus Lee, Jan 1 2026 to Jun 6 2026

SlackBack: Usage: /slackback <colleague name>, <start date> to <end date>

           Inputs confirmed — Marcus Lee, Jan 1 2026 to Jun 6 2026.
           Searching Slack...

           [Retrieves DMs and qualifying channel threads]
           [Filters to project-scoped messages]
           [Extracts 5 SBI blocks]
           [Maps to company values]

           ## Collaboration Summary
           | Date | Channel | Topic | Relevance |
           ...

           ## SBI Evidence Blocks
           SBI Block 1 — A/A Test Expedition Type Change (Apr 21, #pd-gis-migration-prod-and-tech)
           Situation: ...
           Behavior: ...
           Impact: ...

           ## Company Values Mapping
           | SBI Block | Values |
           ...

           ## 360 Review Draft
           Working with Marcus Lee on the XXX experiment...
```

---

## What it won't do

- Generate a review from social messages (lunch plans, emoji reactions, holiday greetings)
- Write vague praise ("great team player", "always reliable") without a grounding example
- Post, delete, or modify anything in Slack — read-only throughout
- Run without both a colleague name and a date range
- Handle out-of-scope requests like general Slack search or project status queries

---

## File structure

```
pd-slackback/
├── install.sh                         ← run this to install
├── README.md                          ← this file
├── SKILL.md                           ← skill protocol (loaded by Claude Code)
└── refs/
    ├── pd-company-values.md           ← six company values with definitions
    ├── sbi-guide.md                   ← SBI model structure and extraction rules
    ├── 360-question.md                ← company 360 question and draft structure
    └── project-scope-filter.md       ← message classification rules (two-stage)
```

---

## Uninstall

```bash
rm -rf ~/.claude/skills/pd-slackback/
```
