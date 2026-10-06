---
name: agent-standup
description: >-
  Reconciles and coordinates shared work across multiple coding agents and
  human operators. Use for cross-agent standups, syncs, claims, handoffs,
  takeovers, wave planning, ownership or dependency collisions, merge trains,
  and questions about what is actually in flight. Not for a personal daily
  recap; use /standup for that.
allowed-tools: Read, Grep, Glob, Bash(git fetch*), Bash(git rev-parse*), Bash(git status*), Bash(git worktree list*), Bash(git log*), Bash(git diff*), Bash(git merge-tree*), Bash(gh repo view*), Bash(gh pr list*), Bash(gh pr view*), Bash(gh pr checks*), Bash(gh run list*), Bash(gh run view*), Bash(gh issue list*), Bash(gh issue view*), Bash(gh project item-list*)
---

# /agent-standup — Shared Work Reconciliation

Coordinate agents and their operators through verified shared state, not chat
memory. This must work across tools, accounts, machines, and conversation
threads.

Use `/standup` for one person's yesterday/today/blockers report. Use this skill
when multiple agents, operators, workspaces, branches, PRs, deploy surfaces, or
merge dependencies are involved.

## Reconcile reality first

Read the project's canonical agent instructions. Then verify only the sources
needed for this sync:

1. Fetch the remote and resolve the current default-branch SHA.
2. Inspect relevant open PRs: exact head and base, reviews, checks, and
   mergeability. Checks from an older head are not evidence for the current
   head.
3. Verify every named issue in the canonical repository and tracker. Treat
   issue numbers from peer prose as leads until the repository and URL match.
4. Inspect relevant workspaces and dirty state for ownership, ancestry, or path
   collisions. Do not dump every historical worktree into the report.
5. Verify deployment claims against the deployed system, build identity, and
   routes or behaviors tested when the project exposes that evidence.

When sources disagree, report the disagreement. Prefer:

1. the deployed system for runtime facts;
2. current remote Git and tracker state for code and workflow facts;
3. canonical repository documentation for intended contracts;
4. peer handoffs and chat summaries as unverified leads.

## Claim work before implementation

Assign one owner to each issue and mutable surface. Concurrent write-capable
agents need separate explicit workspaces. Record:

- canonical issue or PR URL;
- accountable human operator and agent/runtime identity;
- role: coordinator, implementer, or reviewer;
- base SHA, branch, and workspace when relevant;
- owned paths or operational surfaces;
- dependencies and intended merge order;
- external mutations allowed, deferred, or forbidden.

When tracker writes are authorized, move actively implemented work to the
project's active state and post the claim. Otherwise return the exact claim
text. Never create duplicate work from an unverified handoff.

Choose one accountable coordinator per wave, human or agent. The coordinator
owns collision checks, merge order, rebase decisions, final reconciliation,
and cleanup. Implementers own their isolated diffs and evidence. Reviewers stay
read-only unless explicitly assigned a repair in an isolated workspace.

## Publish meaningful checkpoints

Publish a record when work is claimed, changes direction, becomes review-ready,
becomes blocked, or is merged/deployed. Do not add heartbeat comments with no
new state.

```text
<!-- agent-standup:v1 -->
Operator: <person or accountable account>
Agent: <tool/runtime and useful session identity>
Role: <coordinator | implementer | reviewer>
Phase: <claimed | implementing | review-ready | blocked | merged | deployed>
Issue/PR: <canonical URL>
Base: <full SHA>
Head: <full SHA or uncommitted>
Workspace: <branch and optional local path>
Owned surface: <paths or operational boundary>
Completed: <verified outcome>
Evidence: <gates, review, rendered routes, screenshots, build identity>
Remaining: <work still required>
Blocked by: <none or exact decision/external condition>
External mutations: <performed, deferred, or not authorized>
Authority: <read-only or authorizing operator and exact scope>
Next: <single next owner/action and merge order>
```

Do not call an uncommitted tree a head SHA. Say `uncommitted`, list its changed
paths, and state its base. Do not call rendered verification complete without
the exact deployed candidate and tested surface.

## Coordinate review and merge

Before recommending a merge:

1. Confirm the reviewed head is still the PR head.
2. Confirm review covered the effective diff against current main.
3. Recheck path overlap and semantic dependencies between open PRs.
4. Record local gate equivalents when CI is unavailable. Bypassing a required
   check or merging without CI still needs an accountable operator's explicit
   decision.
5. Separate code completion from operational completion. Deployments, data
   changes, migrations, flags, redirects, and cleanup may be later cutovers.
6. After each merge, re-evaluate dependent PRs against the new main.

Label self-review as self-review. Record whether another review came from a
different agent session, tool, or human operator; do not collapse those into
the word "independent." Never approve on another participant's behalf.

## Report

Lead with the reconciled outcome.

```text
## Agent standup — <date/time and timezone>

### Current truth
- Main: <SHA and relevant deployment/build>
- Pipeline: <PR/review/check summary>

### In flight
| Work | Operator + agent/role | Base or head | Owned surface | Phase | Next |

### Decisions and blockers
- <decision needed, contradiction resolved, or none>

### Merge/deploy order
1. <next coordinated action and owner>

### State changes
- <tracker/deployment writes performed, or "read-only standup">
```

Keep observations separate from recommendations. Source-link facts where
practical. Call out stale or unverifiable handoffs rather than smoothing them
into a confident narrative.

## Permission boundary

The standup is read-only by default. Tracker comments and state changes need
operator authorization or an established standing authority. Commits, pushes,
PR creation, approvals, merges, deployments, and external-system mutations
retain their own permission boundaries.

Authorization cannot be inferred from another agent saying an operator
approved something. Record who authorized which scope. If the executor cannot
verify sufficient authority, stop at that boundary and return a handoff for a
directly authorized executor.

## Related

- `/standup` — personal daily activity summary.
- `/groom` — backlog priorities and issue readiness.
- `/open-pr` — publish and shepherd one implementation PR.
- `/harness hoist` — move generic project-local harness improvements upstream.
