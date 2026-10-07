---
name: implement-spec
description: Build a whole spec's tickets in parallel subagents, onto one integration branch.
argument-hint: "<spec issue>"
allowed-tools: Read, Grep, Glob, Bash(gh issue *), Bash(gh pr create*), Bash(gh pr ready*), Bash(gh pr view*), Bash(git switch*), Bash(git branch*), Bash(git merge*), Bash(git push*), Bash(git worktree*), Bash(git status*), Bash(git log*), Bash(${CLAUDE_SKILL_DIR}/sub-issue-frontier.sh*)
disable-model-invocation: true
---

# Implement Spec

Build every ticket of a spec, as filed by the to-tickets skill, onto one
**integration branch**. The tickets aren't a list but a **task graph**: each
names the tickets that block it, so there is always a **frontier** of tickets
ready to start. Run implementers across the frontier in parallel; as each
lands, the frontier moves.

This needs subagents that can work in their own git worktrees (Claude Code's
Agent tool with worktree isolation, or Codex's spawned agents). Without them,
work the tickets one at a time with the implement skill instead.

Keep traffic to and from subagents small. Point at the spec, the ticket, notes,
and commits rather than pasting their contents.

## 1. Read the graph

Read the spec and list its tickets with
`${CLAUDE_SKILL_DIR}/sub-issue-frontier.sh <spec>`. On Claude Code, call the
Skill tool with "budget" before a large fan-out. Done when you know the
frontier and how many implementers to run at once.

## 2. Explore once (optional)

When several tickets need the same reading (code areas, external docs), have
one exploration subagent write its notes to a directory outside the repo that
every later subagent can read. Done when the notes' path is ready to hand to
the implementers.

## 3. Create the integration branch

Branch from the base and push it. Done when the branch exists on the remote.

## 4. Run implementers across the frontier

For each frontier ticket, claim it (`gh issue edit <n> --add-assignee @me`),
then re-read its assignees: assigning never fails when someone else is already
on it, so if anyone else is, leave it and take the next. Start an implementer
subagent for each claimed ticket in its own worktree and branch, in the
background where the host allows. Each implementer:

- checks that its worktree is based on the integration branch, and resets onto
  it if not;
- calls the Skill tool with "tdd" to build the ticket, and calls it again with
  "minimal-change" before adding a dependency or an abstraction;
- runs the project's verification;
- merges the integration branch's latest tip into its own branch before
  reporting done.

Done when every frontier ticket has an implementer running or reported done
(or blocked, with the reason).

## 5. Merge as they land

When an implementer reports done, merge its branch into the integration branch
with a merger subagent, resolving conflicts there, and run verification on the
result. After the first merge, if the repo closes work through pull requests
(or the user wants one), open a draft PR from the integration branch that
closes the spec and its tickets, with a body in the pr-body skill's shape.
Otherwise call the Skill tool with "issue-close" for each ticket as it lands.
If a merge unblocks tickets, start implementers for the new frontier. Done when
every ticket is merged and either linked from the draft PR or closed.

## 6. Review and finish

With a draft PR, mark it ready, then call the Skill tool with "review-pr",
asking for the agent review (its standards and spec passes against the whole
spec), and fix their findings
in a single implementer subagent. Without one, report the integration branch.
Done when the review gate is met (or the branch is reported), CI is green, and
every implementer worktree is removed (`git worktree remove`).
