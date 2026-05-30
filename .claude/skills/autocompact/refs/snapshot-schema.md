---
name: snapshot-schema
description: Six-section schema for autocompact snapshots. Defines per-section contracts, extraction rules, hard caps, file header format, token targets, and a worked example.
type: reference
---

# Snapshot Schema

Autocompact snapshots follow a fixed six-section schema. Every section has a contract: what goes in, what stays out, and what format it takes. Apply these contracts without deviation to hit the 200–400 token target.

## File Header

Every snapshot file starts with a two-line header before the first section:

```
generated: <ISO 8601 timestamp, e.g. 2026-05-30T14:22:00Z>
session: <first-six-words-of-first-user-message-hyphenated-lowercase>
```

**File naming**: `/compacted/<YYYY-MM-DD>-N.md` where `N` is an incrementing integer starting at 1 for each calendar day. Count existing files with today's date prefix to determine N. Examples: `2026-05-30-1.md`, `2026-05-30-2.md`, `2026-05-31-1.md`.

**Load mode file selection**: Sort all files in `/compacted/` by date descending then N descending. The latest file is the first result. `--load-select` presents the sorted list numbered from newest to oldest.

Example header:
```
generated: 2026-05-30T14:22:00Z
session: i-want-to-add-dark-mode
```

## Section Contracts

### entities

**Contract**: Named things that appear in the session — people, systems, components, files, services. One bullet per entity. Format: `- <name>: <role or type>, <key attribute>`.

**Hard cap**: None, but omit any entity not referenced in decisions, state, facts, or open items.

**Discard**: Entities mentioned once in passing with no follow-up.

### decisions

**Contract**: Resolved choices. One bullet per decision. Format: `- <topic>: <chosen option> (<reason if stated, ≤5 words>)`.

**Hard cap**: None, but superseded decisions are removed — keep only the final decision per topic.

**Discard**: Tentative suggestions that were later overridden. Draft options that were rejected.

### state

**Contract**: One line only. Format is strict: `<past participle of last completed action>; next: <imperative verb phrase>`. The word `next:` followed by a colon is required — do not substitute "next action is", "next step is", or any other phrasing. Example: `auth decisions finalised; next: scaffold the project`.

**Hard cap**: Exactly one line. No bullets, no sub-items.

**Discard**: Everything that came before the final state. History of how the session arrived here.

### facts

**Contract**: Specific values that must survive context clearing — numbers, strings, paths, versions, identifiers, thresholds. One key-value pair per line. Format: `- <key>: <value>`.

**Hard cap**: None, but only include values that would break continuity if lost.

**Discard**: Values already captured in decisions or state. Prose explanations of values.

### open items

**Contract**: Unresolved questions and pending tasks. One bullet per item. Format: `- <noun phrase or imperative>`.

**Hard cap**: None, but consolidate duplicates and remove items closed during the session.

**Discard**: Items that were resolved during the session.

### tone

**Contract**: How the user communicates — pace, directness, error tolerance, working style. Bullets only.

**Hard cap**: Three bullets maximum. This section must not exceed three items under any circumstances.

**Discard**: Any observation that does not affect how to respond to this user.

## Extraction Rules

1. **Noun phrases over sentences.** Write `cookie: SameSite=Lax`, not "The team decided to use SameSite=Lax for the cookie."
2. **Key-value pairs for facts.** Every specific value (name, number, path, threshold) gets its own `- key: value` line.
3. **Final state only.** If a fact changed during the session, keep only the last value. Remove earlier versions.
4. **Discard filler.** Acknowledgements ("Got it", "Sure", "Of course"), pleasantries, and meta-commentary about the conversation are not extracted.
5. **Discard superseded facts.** If the user changed a decision, keep the new decision only.
6. **No prose.** No full sentences in any section except the single `state` line. Even the `state` line follows a fixed format.

## Token Target and Guard

- **Target**: 200–400 tokens per snapshot.
- **Warn threshold**: If the drafted snapshot exceeds 500 tokens, emit the following warning and do not write the file:

  ```
  Token guard: snapshot is ~<N> tokens (target 200–400, hard limit 500).
  Extraction drifted toward summarization. Recommend Claude native compact for this session.
  ```

- **When the guard triggers**: The most common cause is verbatim content that cannot reduce to noun phrases — code blocks, quoted error messages, long stack traces. Strip or truncate these to identifiers and line numbers, then re-estimate.

## Worked Example

### Raw conversation excerpt

```
User: I want to add dark mode to the app.
Claude: Great. Where do you want the toggle?
User: Top-right nav bar.
Claude: Makes sense. Persist via localStorage?
User: Actually no — we have SSR, so use a cookie.
Claude: Cookie it is. I'll name it `theme`. Flags: SameSite=Lax, Path=/.
User: Perfect. What about the CSS approach?
Claude: I'll use CSS custom properties on a `data-theme` attribute. Here are the variables:
  light: --bg #ffffff, --text #111111, --border #e0e0e0, --accent #3b82f6
  dark:  --bg #1a1a1a, --text #f0f0f0, --border #333333, --accent #60a5fa
User: Looks good. Put the toggle next to the user avatar in the sidebar, not the nav.
Claude: Done. Variables approved. Next: wire the React toggle component.
```

### Extracted snapshot

```
generated: 2026-05-30T14:22:00Z
session: i-want-to-add-dark-mode

## entities
- app: target web project
- theme toggle: UI component, sidebar next to user avatar

## decisions
- persistence: cookie named `theme`, SameSite=Lax, Path=/ (not localStorage; SSR requirement)
- toggle placement: sidebar next to user avatar (not top-right nav bar)
- theming mechanism: CSS custom properties via `data-theme` attribute

## state
CSS variables drafted and approved; next: wire React toggle component

## facts
- light --bg: #ffffff
- light --text: #111111
- light --border: #e0e0e0
- light --accent: #3b82f6
- dark --bg: #1a1a1a
- dark --text: #f0f0f0
- dark --border: #333333
- dark --accent: #60a5fa
- cookie key: theme
- toggle a11y label: "Switch to dark mode" / "Switch to light mode"

## open items
- React toggle component wiring

## tone
- technical, iterative decisions
- preference changes accepted without friction
```

### What was discarded

- "Great. Where do you want the toggle?" — filler, no extractable fact
- Initial toggle placement (top-right nav bar) — superseded by final placement (sidebar)
- localStorage option — rejected, superseded by cookie decision
- Prose explanations of CSS variable rationale — not mentioned; values captured directly as facts
- All acknowledgements and meta-commentary
