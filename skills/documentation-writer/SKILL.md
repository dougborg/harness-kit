---
name: documentation-writer
description: Write scannable, progressive-discovery documentation using layered contract pattern
allowed-tools: Read, Write, Edit
---

# /documentation-writer — Progressive Disclosure Documentation

Write documentation that scales: PURPOSE ≤10 tokens (skim-worthy), CRITICAL ≤20 tokens (failure modes), STANDARD PATH ≤30 lines (80% workflow), DETAIL (opt-in). Full content ≤1500 tokens.

## PURPOSE

Create documentation that readers can scan quickly: short PURPOSE, non-negotiable CRITICAL constraints, happy-path STANDARD PATH, and optional DETAIL sections.

## CRITICAL

- **PURPOSE must answer "what + when" in ≤10 tokens.** If readers need details to understand PURPOSE, rewrite shorter.
- **CRITICAL prevents catastrophic mistakes.** Only include constraints that break things if ignored. Skip nice-to-know rules.
- **STANDARD PATH covers the 80% happy case.** Edge cases link to DETAIL; don't bloat happy path with conditionals.
- **DETAIL sections are opt-in.** Link them from EDGE CASES; don't inline optional content.

## ASSUMES

- Readers have context budgets (agents scanning hundreds of skills, humans skimming quickly)
- Both need to know fast: "Do I need this?" (PURPOSE), "What breaks?" (CRITICAL), "How do I use it?" (STANDARD PATH)
- Detailed examples and edge cases are secondary

## STANDARD PATH

### 1. Frontmatter

Add YAML with name, description, tools:

```yaml
---
name: skill-name
description: [One-liner, <80 chars, specific]
allowed-tools: [Bash(pattern*), Read, Write, ...]
---
```text

Skip `model:` on skills — they run in the parent conversation context, so pinning a model can break long-context sessions. Agents (read-only advisors) get a fresh context and can specify `model:` safely.

### 2. Sections

Write in order: PURPOSE, CRITICAL, ASSUMES, STANDARD PATH, EDGE CASES, DETAIL.

1. **PURPOSE** (≤10 tokens) — What + when
2. **CRITICAL** (≤20 tokens) — Non-negotiable constraints
3. **ASSUMES** (≤10 tokens) — Assumptions, when they break skill needs redesign
4. **STANDARD PATH** (≤30 lines) — Happy path, prose + code blocks
5. **EDGE CASES** — Named links only (- [Case] — read DETAIL: Name)
6. **DETAIL: Name** — Only included if referenced above

### 3. Validate

Run this test for each section:

- PURPOSE: Can someone answer "what + when" in <5 seconds? If no, rewrite.
- CRITICAL: Are ALL items catastrophic if ignored? If any are nice-to-know, move to STANDARD PATH.
- STANDARD PATH: Can 80% of users follow this without edge cases? If <80%, skill does too much.

## EDGE CASES

- [Over-long PURPOSE/CRITICAL] — read DETAIL: Token Budget if you're exceeding limits
- [Skill seems to do multiple things] — read DETAIL: Single Responsibility if it covers too much scope
- [Lots of edge cases] — read DETAIL: Scope Creep if EDGE CASES section is huge

---

## DETAIL: Writing PURPOSE

PURPOSE answers: "What does this do? When would I use it?" in ONE sentence, ≤10 tokens, answerable without reading more.

### Test

Can someone skim PURPOSE (5 seconds) and decide whether to read further? If no, rewrite shorter.

### Examples

| Bad | Good |
| --- | --- |
| "Format code using Prettier" | "Auto-format JavaScript/TypeScript files to maintain consistent style" |
| "Commit changes" | "Create conventional commits with quality gates: validate, stage, commit" |
| "Write documentation" | "Create scannable documentation: PURPOSE ≤10 tokens, CRITICAL constraints, STANDARD PATH 80% workflow, optional DETAIL" |

### Rewrite Technique

Remove adjectives and examples. Answer only: what + when.

---

## DETAIL: Writing CRITICAL

CRITICAL constrains failure modes — things that break catastrophically if ignored.

### Test

For each constraint: "If someone ignores this, does the skill catastrophically fail?" If not, move it to STANDARD PATH or EDGE CASES.

### Examples

| Bad (Nice-to-Know) | Good (Critical) |
| --- | --- |
| "Remember to add tests" | "Never commit secrets. Run `detect-private-key` before staging." |
| "Keep code clean" | "Formatting must run before validators. Validators must gate commits." |
| "Follow conventions" | "All skills must use PURPOSE/CRITICAL/STANDARD PATH structure or audit fails." |

---

## DETAIL: Writing STANDARD PATH

STANDARD PATH is the 80% happy case: step-by-step with prose + code.

### Structure

Mix narrative and code. Each step is 1-2 sentences + example:

1. Section heading: `### 1. [Step Name]`
2. Prose explaining the step (1-2 sentences)
3. Code block starting with ` ```bash ` and ending with ` ``` `
4. Prose explaining what happens next

Example structure:

```bash
### 1. [Step Name]
[Prose: what to do and why]
[command showing the action]
[Prose: what to expect next]
```text

### Target: ≤30 Lines

- 3-5 steps max
- Code examples, not detailed command output
- No conditionals (edge cases reference DETAIL)
- Contiguous happy path (don't branch)

### Test

Can 80% of users follow this without consulting EDGE CASES? If no, skill does too much or needs redesign.

---

## DETAIL: Token Budget

If PURPOSE or CRITICAL are running long:

### PURPOSE Too Long?

1. Rewrite as a question: "What does this do, and when would I use it?"
2. Answer in one sentence, no adjectives, no examples
3. Count tokens (rough: 4 words per token)

### CRITICAL Too Long?

1. You have >3 constraints → skill does too much (split it)
2. Some constraints belong in STANDARD PATH, not CRITICAL
3. Test: Would ignoring this constraint be catastrophic? If not, move it.

---

## DETAIL: Single Responsibility

If the skill covers multiple domains ("format AND test AND commit"), split it.

### Principles

- One skill per responsibility
- STANDARD PATH is a contiguous happy path, not a branching tree
- Reference related skills instead of covering everything

### Test

Can you describe the happy path in 2-3 steps without conditionals? If no, split it.

---

## DETAIL: Scope Creep

If EDGE CASES section has >5 items, skill is doing too much.

### Fix

1. **Split into focused skills** — Each handles one responsibility, references others as related
2. **Move edge cases to FAQ/troubleshooting docs** — Not every edge case belongs in a skill

### Test

Does 80% of users follow the STANDARD PATH? If <80% follow the same path, you're covering too many workflows.

---

## RELATED

- `/skill-writer` — Structure skills using this pattern
- `/harness audit` — Audit skills for progressive disclosure compliance
- `CLAUDE.md` — Project documentation conventions

## SOURCES

- [Progressive Disclosure | ixdf.org](https://ixdf.org/literature/topics/progressive-disclosure)
- [Scannable Web Design | Nielsen Norman](https://www.nngroup.com/articles/scannable-web-design/)
