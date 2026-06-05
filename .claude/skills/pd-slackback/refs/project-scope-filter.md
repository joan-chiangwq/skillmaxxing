---
name: Project Scope Filter
description: Rules for classifying messages as project-scoped or social in Step 4
type: reference
---

## Purpose

The project scope filter determines which Slack messages qualify as review evidence. It runs in two stages: source scoping (Step 3) restricts which conversations to retrieve at all; content classification (Step 4) then discards social or off-topic messages from within those conversations.

## Stage 1 — Source Scope (applied in Step 3)

Only retrieve messages from these two source types. Discard everything else before content classification begins.

| Source type | Inclusion rule |
|-------------|----------------|
| Direct messages (DMs) | Any DM thread between the current user and the named colleague |
| Channel threads | Threads in any channel where (a) the colleague posted or replied, AND (b) the current user is @mentioned in the thread OR has themselves replied to it |

**Excluded by source scope:**
- Channel threads the colleague participated in but where the user has no direct involvement (no @mention, no reply)
- Group DMs that do not include both the user and the colleague
- Threads where only the user is present and the colleague is merely referenced by name

## Stage 2 — Content Classification (applied in Step 4)

From the source-scoped messages, classify each message as RETAIN or DISCARD based on content.

## Classification Decision Tree

```
Is the message in an explicitly off-topic channel (#random, #off-topic, #fun, #memes, social DMs)?
  → YES: DISCARD (social channel)
  → NO: continue

Is the message content exclusively social/casual?
  → YES: DISCARD (see social signal list below)
  → NO: continue

Does the message relate to a project, incident, decision, deliverable, or cross-team coordination?
  → YES: RETAIN (project-scoped)
  → NO: DISCARD (insufficient signal)
```

## Social Signals — Discard on Any Match

| Signal type | Examples |
|-------------|----------|
| Food / lunch coordination | "Anyone want to grab lunch?", "What are people doing for food?", "+1 for tacos" |
| Emoji-only reactions | A message body that is only emoji characters with no text content |
| Holiday / personal greetings | "Happy Friday!", "Hope everyone has a great long weekend", "Happy birthday [name]" |
| Personal banter | Off-topic jokes, memes, GIFs with no project context, unrelated life updates |
| Generic affirmations | "+1", "lgtm" without a document or PR reference, "sounds good" with no traceable work item |
| Event coordination (non-work) | Team social invitations, lunch orders, coffee meetups |

## Project-Scope Signals — Retain on Any Match

| Signal type | Examples |
|-------------|----------|
| Technical work | Architecture discussion, PR review comment, bug investigation, performance analysis |
| Incident response | Incident timeline, hypothesis posting, resolution steps, post-mortem participation |
| Cross-team coordination | Dependency alignment, API contract discussion, launch readiness checks |
| Decision-making | Options analysis, recommendation with rationale, design trade-off discussion |
| Deliverable references | Spec review, doc feedback, data model discussion, roadmap input |
| Unblocking | Answering a technical question from another team, providing missing context, connecting stakeholders |
| Process or quality improvement | Proposing a change to a workflow, raising a gap in a process, filing a retrospective item |

## Edge Cases

| Situation | Classification |
|-----------|----------------|
| Message is a thread reply to a project-scoped thread, but the reply itself is brief ("thanks!", "on it") | DISCARD — the reply alone carries no behavioral evidence |
| Message mentions a project name but content is off-topic small talk | DISCARD — project name reference alone is insufficient |
| Message is in a social channel but contains substantive technical content | RETAIN — content overrides channel classification; note the channel in the summary |
| Message is an emoji reaction only, attached to a technical post | DISCARD — emoji reactions are not observable behaviors for review purposes |
| Message contains both project content and social content in the same post | RETAIN the project-relevant portion; strip the social portion when writing the SBI block |

## Worked Example

**Retrieved messages for Sarah Chen, Feb 2026:**

| Message | Classification | Reason |
|---------|----------------|--------|
| "Anyone up for lunch at noon?" | DISCARD | Food coordination |
| "Posted the incident timeline in #incidents — tagging @on-call" | RETAIN | Incident response |
| "🎉🎉🎉" (reaction to launch announcement) | DISCARD | Emoji-only |
| "Here are three hypotheses for the DB latency spike, ranked by likelihood: ..." | RETAIN | Technical investigation |
| "Happy Lunar New Year everyone!" | DISCARD | Personal greeting |
| "I can take the schema migration review — I'll post comments by EOD" | RETAIN | Cross-team coordination / deliverable commitment |

**Result**: 3 messages retained, 3 discarded. Proceed to Step 6 with retained messages only.
