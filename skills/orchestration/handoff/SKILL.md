---
name: handoff
description: Write a handoff document so another session, host, or person can continue the work.
argument-hint: "[what the next session is for]"
---

# Handoff

Write a document that lets a fresh agent, another host, or a colleague
continue this work. A handoff buys **portability**: use it when the work is
moving to a new host (Claude Code to Codex or back), another directory or
repo, another person, or a side task split off mid-phase. To keep going in the
same place, the ask-harness skill's phase-boundary guide usually points to a
cheaper move.

## 1. Write it

Write `handoff-<slug>.md` to the operating system's temp directory (`$TMPDIR`,
else `/tmp`; `%TEMP%` on Windows), not the workspace, and report its absolute
path. If the user said what the next session is for, write for that. Cover:

- **Goal and destination**: what this work is for, and what done looks like.
- **Where it stands**: what's finished, what's in flight, the branch, open PRs
  and their state.
- **Decisions and why**, including approaches tried and dropped.
- **Next steps**, in order, and anything blocked and on what.
- **Gotchas** you found that the next agent would otherwise rediscover.
- **Suggested skills** for the next agent to call through the Skill tool.

Point at what already exists (issues, PRs, specs, ADRs, commits, files) by
URL or path rather than copying it in. Redact secrets, tokens, and personal
data, since the document may become another agent's prompt. Done when the
file exists, every next step names what it starts from, and nothing secret is
in it.

## 2. Hand it over

Commit and push first if the next session starts in a new worktree or another
checkout: it begins from the repository, not from this session's uncommitted
changes.

- **Another person or host**: give the path. To start a new session from it,
  the recipient runs `claude -- "$(cat <path>)"` or `codex -- "$(cat <path>)"`
  in the repository.
- **A fresh background session**, when the user asks for one. On Claude Code:

  ```bash
  claude --bg --worktree "<slug>" --name "<descriptive name>" -- "$(cat <path>)"
  ```

  `--worktree` keeps the new session's edits off this one's files, and
  `"$(cat <path>)"` passes the document without the shell running anything
  inside it. The session starts in the permission mode from the user's
  settings, and it can't answer a permission prompt until someone attaches;
  manage it with `claude agents`, `claude attach`, and `claude logs`.

  On Codex, run it non-interactively in a new managed worktree, as a
  background process:

  ```bash
  codex exec --worktree -- "$(cat <path>)"
  ```

  It runs until the task is done, under the user's sandbox and approval
  settings.

Done when the user has the path, or the background session's id.
