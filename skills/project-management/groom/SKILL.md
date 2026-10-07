---
name: groom
description: Groom the GitHub backlog into theme buckets, umbrella status, a prioritized PR train, stale flags, and untracked gaps.
context: fork
agent: harness-kit:project-manager
background: false
allowed-tools: Bash(gh issue *), Bash(gh pr *), Bash(gh label *), Bash(gh search *), Bash(gh api *), Bash(git log *), Read, Grep, Glob, Bash(<shared-scripts-dir>/scan-shortcuts.sh*)
---

# Groom

Answer "what should we work on next?" from the whole backlog with an
opinionated brief: theme buckets, umbrella status, a prioritized PR train,
stale flags, and gaps.

On Claude Code this runs forked into the `project-manager` agent, so you are
the project manager, and you see no conversation history: only this file and
what `gh` returns. Derive everything from the backlog; assume no prior
discussion. Your agent instructions own the survey process and the brief's
output contract; this file owns the scope, the shortcut survey, and the
next-actions footer. If that agent isn't installed the fork can't start: drop
`context: fork` and `agent:` from this frontmatter and run the same protocol
inline, with the same output and word cap.

**Read-only.** Close, edit, and comment on nothing; recommend, and let the
user act. Use only the labels, milestones, and priorities the repo already
has.

## 1. Scope the backlog

```bash
gh issue list --state open --limit 100 \
  --json number,title,labels,createdAt,updatedAt,assignees,milestone,body
gh pr list --state open --json number,title,labels,isDraft
```

`--limit 100` truncates silently, so check the true count:

```bash
gh api 'repos/{owner}/{repo}/issues?state=open&per_page=1' --include 2>/dev/null | grep -i '^link:'
```

Past 100, page through with `--limit 100` plus `--search "sort:updated-desc"`
and `sort:updated-asc` passes, or pull per-label slices. A brief that silently
analyzed 100 of 240 issues misleads, so it states the full count and how the
sample was drawn. Grooming pays off from roughly 15 open issues; below that,
read them all directly.

Done when you know the true open-issue count and which issues your sample
covers.

## 2. Survey

Cover, in order:

1. Theme buckets, from labels and title patterns.
2. Umbrella and tracking issues, and each one's progress.
3. A train of 5–10 PRs ordered by leverage, each with about two sentences on
   user-visible value, effort (S/M/L), risk if deferred, and the dependencies
   it unblocks.
4. Stale issues (over 90 days inactive with no open PR), duplicates, and
   superseded issues, each with verifiable evidence (age, duplicate of,
   superseded by) and a disposition. Flag nothing for closing without
   evidence.
5. Gaps: work the project should be tracking but isn't.
6. The shortcut ledger. A fork can't call other skills, so run the
   shortcut-ledger skill's scan directly:

   ```bash
   <shared-scripts-dir>/scan-shortcuts.sh
   ```

   Each hit reads `shortcut: <ceiling> | revisit when <trigger>`. Report the
   totals, and list each marker whose trigger has plainly fired, or that has
   no `revisit when`, as a gap candidate.

Done when every open issue in the sample sits in a bucket, every stale flag
carries evidence, and the shortcut totals are counted.

## 3. Write the brief

Follow the agent's output contract (top-line state, umbrella table, PR train,
stale list, gaps), opinionated, with rationale on every pick, under about
1,500 words. End with a next-actions footer that maps recommendations to the
skills that act on them, in the host's invocation form (`/issue-close` on
Claude Code, `$issue-close` on Codex):

- close stale, duplicate, or superseded issues: `issue-close`, per issue;
- split or merge tangled issues: `issue-restructure`;
- file gaps, including fired or untriggered shortcuts: `issue-create`, per
  gap;
- raw incoming issues awaiting evaluation: `triage`;
- start the train's first PR: the normal feature flow, then `open-pr`.

Run none of them. If the user later wants the brief posted, they name the
umbrella or planning issue, and the issue-update skill posts it there as a
comment; the target is always theirs to pick.

Done when the brief is under the cap and every recommendation has a
rationale and a footer entry.

## Related

- `project-manager` agent — the forked context this skill runs in.
- `standup` — personal daily activity; `agent-standup` — shared ownership
  and handoffs; `groom` — what should change next.
- `to-spec`, `to-tickets` — spec one feature and split it into tickets; groom
  works over the whole backlog.
- `issue-close`, `issue-update`, `issue-restructure`, `issue-create` — act on
  grooming recommendations.
