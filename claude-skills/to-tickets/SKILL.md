---
name: to-tickets
description: >-
  Break a spec, plan, or conversation into tracer-bullet tickets, each a thin
  end-to-end slice that declares what blocks it, filed as GitHub sub-issues
  with native blocking links.
argument-hint: "[spec issue]"
disable-model-invocation: true
---

# To Tickets

Break the work into **tickets**: thin **tracer-bullet** slices, each cutting
end to end through every layer it needs, each declaring the tickets that
**block** it.

## 1. Gather context

Work from the conversation. If the user passed a spec issue, read its body and
comments (`gh issue view <n> --comments`). Explore the codebase if you haven't,
and use the project's `GLOSSARY.md` terms in every title. Look for
**prefactoring** that makes the work easier: make the change easy, then make
the easy change. Done when you know which modules the work touches.

## 2. Draft the slices

Each ticket:

- cuts a narrow but complete path through every layer (schema, API, UI,
  tests), never one horizontal layer;
- is demoable or verifiable on its own;
- fits in one fresh agent session;
- lists the tickets that must finish before it can start. Prefactoring comes
  first.

**Wide refactors are the exception.** A mechanical change whose blast radius
fans across the codebase (renaming a column, retyping a shared symbol) can't
land green as one slice. Sequence it as **expand-contract**: first add the new
form beside the old; then migrate callers in batches sized by blast radius
(per package or directory), each batch its own ticket blocked by the expand;
then delete the old form in a ticket blocked by every batch. When even a batch
can't stay green alone, let the batches share an integration branch that
blocks a final integrate-and-verify ticket.

## 3. Check the breakdown with the user

Show a numbered list: each ticket's title, what blocks it, and the end-to-end
behaviour it delivers. Ask whether the granularity is right, whether each
blocking edge is real, and what to merge or split. Ask as the grilling skill
does (`AskUserQuestion` on Claude Code). Done when the user approves the
breakdown.

## 4. File them

File in dependency order, blockers first, so each ticket can reference real
issue numbers. With a spec issue, make each ticket its sub-issue and use
GitHub's native blocking links:

```bash
gh issue create --title "<title>" --body-file <file> \
  --parent <spec> --blocked-by <n>,<n>
```

Without a spec issue, drop `--parent`. Apply the repo's existing labels
(`gh label list`); leave the spec issue itself unchanged.

```markdown
## What to build

The end-to-end behaviour this ticket makes work, from the user's point of
view, not a layer-by-layer list.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2
```

Leave out file paths and code, as in the spec, except a decision-bearing
snippet from a prototype.

Done when every approved ticket is filed with its parent and blocking links,
and you've reported the **frontier**: the tickets with no open blockers, ready
to start now.
