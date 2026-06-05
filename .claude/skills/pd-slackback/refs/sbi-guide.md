---
name: SBI Guide
description: SBI model structure and extraction rules for evidence-based review writing
type: reference
---

## SBI Model Overview

SBI stands for Situation, Behavior, Impact. It is a structured format for capturing observable professional moments in a way that is specific, verifiable, and free from inferred motivation. Use SBI to transform raw Slack messages into review-ready evidence blocks in Step 6.

## The Three Components

| Component | Definition | Key constraint |
|-----------|------------|----------------|
| **Situation** | The context or challenge that existed at the time | Must be specific: include date, channel or project, and what was at stake |
| **Behavior** | What the colleague specifically said or did | Must be observable, not inferred — describe the action, not the intention behind it |
| **Impact** | The result or outcome that followed | Must be traceable to the behavior — avoid generic claims like "it helped the team" |

## Extraction Rules

1. **One block per moment.** Each SBI block covers a single, bounded event. Do not collapse multiple separate contributions into one block — reviewers cannot verify compound claims.
2. **Behavior from evidence, not inference.** Use what the person actually typed, posted, or did. Do not attribute motivation ("she did this because she cares about quality"). Describe the act.
3. **Situation must be grounded.** Vague situations make the behavior unverifiable. Include the project name, the date or date range, the channel, and the problem being addressed.
4. **Impact must be traceable.** The impact must follow from the specific behavior described. If you cannot trace the causal link, the impact claim is too weak to include. Note the gap explicitly.
5. **Discard social messages.** Messages that do not constitute a professional act (emoji reactions, lunch plans, off-topic chat) produce no SBI block. Do not manufacture a block from thin material.
6. **Mark evidence gaps explicitly.** If the Slack evidence shows a situation and behavior but no traceable impact, write: `Impact: [Not traceable from available Slack data — consider supplementing with direct observation or stakeholder input]`.

## Block Format

```
**Situation**: [Specific context — project, date, channel, what was at stake]
**Behavior**: [What the person said or did — observable, specific, quoted where possible]
**Impact**: [The result that followed — traceable to the behavior; or flag the gap]
```

## Quality Checklist

Before finalising an SBI block, verify:
- [ ] Situation names a specific project, date, and channel (not "a recent project")
- [ ] Behavior uses the person's own words or a precise description of their action
- [ ] Behavior contains no inferred motivation ("she wanted to", "he tried to")
- [ ] Impact is causally linked to the behavior (not just temporally adjacent)
- [ ] The block could be verified by a third party reading the Slack thread

## Worked Example

**Raw Slack evidence**: In #schema-migration (March 12 2026), Marcus Lee posted a detailed migration plan for the payments schema, identified three edge cases the original spec had missed, and offered to pair with the backend team before cutover.

**SBI block**:

**Situation**: During the payments schema migration in March 2026, the backend team was preparing for a cutover that the original spec had not fully accounted for edge cases in.

**Behavior**: In #schema-migration on March 12, Marcus posted a complete migration plan, enumerated three specific edge cases absent from the original spec, and offered to pair with the backend team to resolve them before cutover.

**Impact**: The edge cases were addressed before cutover, preventing a class of runtime errors that would have required a rollback. [Traceable from follow-up thread confirming the fix.]
