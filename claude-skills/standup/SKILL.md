---
name: standup
description: >-
  Daily standup from git history and GitHub activity: what changed since
  yesterday, what's in flight, what's blocked.
effort: low
allowed-tools: Bash(git log*), Bash(git config*), Bash(gh pr*), Bash(gh issue*), Read
disable-model-invocation: true
---

# Standup

One person's report: what changed since yesterday, what's in flight, and
what's blocked. Shared ownership, handoffs, dependency collisions, and merge
coordination across several agents or operators belong to the agent-standup
skill instead.

## 1. Gather activity

```bash
git log --since="1 day ago" --oneline --author="$(git config user.email)"
gh pr list --author="@me" --state=open
gh issue list --assignee="@me" --state=open
```

Take the window from these timestamps, always "since yesterday", rather than
estimating, so every day's report covers the same span. Only commits under
your git email and issues assigned to you show up; when a section comes back
empty, say so rather than filling it from memory.

Done when you have yesterday's commits, your open PRs, and your assigned
issues.

## 2. Write the report

```text
## Standup — [Date]

### Yesterday
- [type]: [one-liner per commit/PR]

### Today
- [planned task from open issues/PRs]

### Blockers
- [none | what's blocking]
```

Infer "Today" from the open PRs and issues. Report blockers, unfinished
tasks, and dependencies plainly: a hidden blocker is one nobody can help with.

Done when every section has an entry, with "none" under Blockers when nothing
blocks.

## Related

- `agent-standup` — reconcile multi-agent and multi-operator work.
