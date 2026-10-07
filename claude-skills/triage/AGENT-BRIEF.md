# Agent briefs

An agent brief is the comment posted when an issue (or external PR) moves to
`ready-for-agent`. It is the contract an implementing agent works from; the
original body and discussion are background.

## Principles

- **Durable over precise.** The issue may wait for weeks while the code moves.
  Describe interfaces, types, and behavioural contracts by name; leave out
  file paths and line numbers, which go stale.
- **Behaviour, not procedure.** Say what the system should do, not how to edit
  it. "The `SkillConfig` type accepts an optional `schedule` field of type
  `CronExpression`" beats "open src/types/skill.ts and add a field on line
  42".
- **Testable acceptance criteria.** Each one independently checkable.
  "`gh issue list --label needs-triage` returns only issues awaiting
  evaluation" beats "triage works correctly".
- **Explicit scope.** Say what is out of scope, so the agent doesn't gold-plate
  adjacent features.
- **For a PR**, "current behaviour" is the state of the diff, and the brief
  says what is left to do to it: finish it, close gaps, address review points.

## Template

```markdown
## Agent brief

**Category:** bug / enhancement
**Summary:** one line on what needs to happen

**Current behaviour:**
What happens now. For a bug, the broken behaviour; for an enhancement, the
status quo it builds on; for a PR, the state of the diff.

**Desired behaviour:**
What should happen once the work is done, including edge cases and error
conditions.

**Key interfaces:**
- `TypeName` — what changes and why
- `functionName()` — what it returns now vs what it should return

**Acceptance criteria:**
- [ ] Specific, testable criterion
- [ ] Specific, testable criterion

**Out of scope:**
- Something that should not change here
```

## Example (bug)

```markdown
## Agent brief

**Category:** bug
**Summary:** Description truncation cuts mid-word

**Current behaviour:**
Descriptions over 1024 characters are cut at exactly 1024, so they can end
mid-word ("Use when the user wants to confi").

**Desired behaviour:**
Cut at the last word boundary before 1024 characters and append "...".

**Key interfaces:**
- The `SkillMetadata.description` field: no type change; the code that fills it
  must respect word boundaries.

**Acceptance criteria:**
- [ ] Descriptions under 1024 characters are unchanged
- [ ] Longer descriptions end at a word boundary, followed by "..."
- [ ] The result, including "...", is at most 1024 characters

**Out of scope:**
- Changing the 1024-character limit
```
