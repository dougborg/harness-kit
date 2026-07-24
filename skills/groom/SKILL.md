---
name: groom
description: >-
  Groom the GitHub backlog: bucket open issues by theme, survey umbrellas and
  dependencies, recommend a prioritized 5-10 PR train with rationale, flag
  stale issues, and surface untracked gaps. Read-only analysis via the
  project-manager agent; the user decides what to act on.
allowed-tools: Bash(gh issue *), Bash(gh pr *), Bash(gh label *), Bash(gh search *), Bash(gh api *), Bash(git log *), Read, Grep, Glob, Agent
---

# /groom — Backlog Grooming and Prioritization

Turn 50+ open issues into an opinionated plan: theme buckets, umbrella status, a prioritized PR train, stale flags, and gaps.

## PURPOSE

Answer "what should we work on next?" from the whole backlog.

## CRITICAL

- **Read-only** — never close, edit, or comment on issues from this skill. Recommend; the user acts (via `/issue-close`, `/issue-update`).
- **Opinionated output, ~1500-word cap** — ranked lists and firm picks, not menus. Every recommendation carries rationale.
- **Evidence for every stale flag** — no "close #N" without a verifiable reason (age, duplicate of, superseded by).
- **Use the repo's real taxonomy** — labels, milestones, and priorities discovered from the repo, never invented.

## ASSUMES

- `gh` CLI authenticated; repo accessible with issues enabled.
- Backlog is large enough to need grooming (roughly 15+ open issues — below that, just read them).
- The `project-manager` agent is available (harness-kit plugin or `.claude/agents/project-manager.md`); the skill degrades to inline analysis without it.

## STANDARD PATH

### 1. Scope the backlog

```bash
gh issue list --state open --limit 100 \
  --json number,title,labels,createdAt,updatedAt,assignees,milestone,body
gh pr list --state open --json number,title,labels,isDraft
```

Note the issue count and whether the 100-issue limit truncated the list (see EDGE CASES).

### 2. Delegate to the project-manager agent

Launch the `project-manager` agent with this brief (fill the brackets):

> Groom the backlog of [owner/repo] ([N] open issues, [M] open PRs). Read CLAUDE.md for project conventions. Then: (1) bucket open issues by theme using labels and title patterns; (2) identify umbrella/tracking issues and per-umbrella progress; (3) recommend a prioritized train of 5-10 PRs, ordered by leverage, with ~2 sentences of rationale each covering user-visible value, effort (S/M/L), risk if deferred, and dependencies unblocked; (4) flag stale issues (>90 days inactive with no open PR), duplicates, and superseded issues, each with evidence and a disposition; (5) identify gaps — work the project should be tracking but isn't. Return the grooming brief in your standard format, capped at ~1500 words.

The agent's instructions define the output contract (top-line state, umbrella table, PR train, stale list, gaps).

### 3. Present the brief

Relay the agent's brief verbatim, then add a short next-actions footer mapping recommendations to skills:

- Close stale/duplicate/superseded → `/issue-close` per issue
- Split or merge tangled issues → `/issue-restructure`
- File gap issues → `/issue-create` per gap
- Start the train's first PR → normal feature flow, then `/open-pr`

Do not execute any of these automatically.

## EDGE CASES

- [More than 100 open issues] — read DETAIL: Large Backlogs
- [project-manager agent unavailable] — read DETAIL: Inline Fallback
- [User wants the brief posted to GitHub] — read DETAIL: Publishing the Brief

---

## DETAIL: Large Backlogs

`gh issue list --limit 100` truncates silently. Check the true count first:

```bash
gh api 'repos/{owner}/{repo}/issues?state=open&per_page=1' --include 2>/dev/null | grep -i '^link:'
```

If the backlog exceeds 100, page through with `--limit 100` plus `--search "sort:updated-desc"` and `sort:updated-asc` passes, or pull per-label slices. Tell the agent the full count and how the sample was drawn — a brief that silently analyzed 100 of 240 issues is misleading.

---

## DETAIL: Inline Fallback

If the `project-manager` agent is not installed, run the same protocol inline in the parent conversation: follow steps 1–7 of the agent's survey process (context, backlog pull, theme buckets, umbrellas, scored PR train, stale flags, gaps) and emit the same output format under the same ~1500-word cap. The contract is identical; only the execution context differs.

---

## DETAIL: Publishing the Brief

Posting the brief as a comment on a tracking issue is deliberately out of scope for the automatic path (read-only principle). If the user asks for it after reviewing the brief, use `/issue-update` to post it as a comment on the umbrella or planning issue they name — never pick the target issue yourself.

## RELATED

- `project-manager` agent — runs the analysis; this skill enforces the prompt shape and output contract
- `/standup` — daily-shaped (what changed since yesterday); `/groom` is roadmap-shaped (what should change next)
- `/feature-spec` — spec one feature; `/groom` operates over the whole backlog
- `/issue-close`, `/issue-update`, `/issue-restructure`, `/issue-create` — act on grooming recommendations
