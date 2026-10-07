---
name: to-tickets
description: Split a spec into tracer-bullet sub-issues with blocking links.
argument-hint: "[spec issue]"
allowed-tools: Read, Grep, Glob, Bash(gh issue *), Bash(gh label *), Bash(${CLAUDE_SKILL_DIR}/sub-issue-frontier.sh*)
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

Done when every slice has a title, its blockers, and the end-to-end behaviour
it delivers, and each fits one session.

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
gh issue create --title "<title>" --parent <spec> --blocked-by <n>,<n> \
  --body-file - <<'EOF'
<ticket body>
EOF
```

Without a spec issue, drop `--parent`. `--parent` and `--blocked-by` need
`gh` 2.94 or later; with an older `gh`, put `Part of #<spec>` and
`Blocked by: #<n>, #<n>` at the top of each body instead. Apply the repo's existing labels
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
to start now (`${CLAUDE_SKILL_DIR}/sub-issue-frontier.sh <spec>`).

Next step: suggest the user run the implement skill for one ticket at a time,
or the implement-spec skill to build the whole graph in parallel.
