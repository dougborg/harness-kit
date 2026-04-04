---
name: standup
description: Generate a daily standup report from git history and GitHub activity
model: haiku
allowed-tools: Bash(git log*), Bash(git config*), Bash(gh pr*), Bash(gh issue*), Read
---

# /standup — Daily Standup Report

Generate a standup report summarizing what changed since yesterday.

## PURPOSE

Create a daily standup summary: yesterday's work, today's plans, blockers.

## CRITICAL

- **Report must be honest** — Include blockers, incomplete tasks, and dependencies. Hiding issues delays detection.
- **Time window is consistent** — Always "since yesterday" using git/GitHub timestamps, not manual estimation.

## ASSUMES

- You're in a git repository with GitHub integration
- GitHub CLI (`gh`) is installed and authenticated
- You commit at least daily and assign yourself to issues/PRs

## STANDARD PATH

### 1. Gather Activity

```bash
git log --since="1 day ago" --oneline --author="$(git config user.email)"
gh pr list --author="@me" --state=open
gh issue list --assignee="@me" --state=open
```text

### 2. Format Report

```text
## Standup — [Date]

### Yesterday
- [type]: [one-liner per commit/PR]

### Today
- [planned task from open issues/PRs]

### Blockers
- [none | what's blocking]
```text

### 3. Output

Present the report. Infer "Today" from open PRs and issues.
