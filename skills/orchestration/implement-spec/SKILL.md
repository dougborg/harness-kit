---
name: implement-spec
description: Build a whole spec's tickets in parallel subagents, onto one integration branch.
argument-hint: "<spec issue>"
allowed-tools: Read, Grep, Glob, Bash(gh issue *), Bash(gh pr *), Bash(git *), Bash(<shared-scripts-dir>/sub-issue-frontier.sh*)
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
`<shared-scripts-dir>/sub-issue-frontier.sh <spec>`. On Claude Code, check the
budget skill before a large fan-out. Done when you know the frontier and how
many implementers to run at once.

## 2. Explore once (optional)

When several tickets need the same reading (code areas, external docs), have
one exploration subagent write its notes to a directory outside the repo that
every later subagent can read. Done when the notes' path is ready to hand to
the implementers.

## 3. Create the integration branch

Branch from the base. Once the first ticket has merged into it, open a draft PR
that closes the spec and its tickets, with a body in the pr-body skill's shape.
Done when the branch exists.

## 4. Run implementers across the frontier

For each frontier ticket, claim it (`gh issue edit <n> --add-assignee @me`) and
start an implementer subagent in its own worktree and branch, in the
background where the host allows. Each implementer:

- checks that its worktree is based on the integration branch, and resets onto
  it if not;
- calls the Skill tool with "tdd" to build the ticket, and "minimal-change"
  before adding dependencies or abstractions;
- runs the project's verification;
- merges the integration branch's latest tip into its own branch before
  reporting done.

## 5. Merge as they land

When an implementer reports done, merge its branch into the integration branch
with a merger subagent, resolving conflicts there, and run verification on the
result. Close the ticket the way the repo closes work (the draft PR's closing
links, or the issue-close skill). If that unblocks tickets, start implementers
for the new frontier. Done when every ticket is merged and closed.

## 6. Review and finish

Mark the draft PR ready, then call the Skill tool with "review-pr" for the
standards and spec passes against the whole spec. Fix their findings in a
single implementer subagent. Done when the review gate is met, CI is green, and
every implementer worktree is removed (`git worktree remove`).
