---
name: budget
description: >-
  Check the Claude usage/token budget before dispatching subagents or large
  fan-outs. Reports session and weekly (all-models + per-model) utilization and
  reset times, warns when near a cap, and guides right-sizing, deferring, and
  scheduling a wake-up to resume after a usage-limit reset.
when_to_use: >-
  Before any orchestration-scale work — dispatching subagents, large fan-outs,
  long-running batches — or when the user asks about usage, quota, limits, or
  when the budget resets. A PreToolUse hook also surfaces this automatically.
allowed-tools: Bash(<shared-scripts-dir>/claude-usage-check.sh*), Bash(claude -p*), Read
---

# /budget — Budget-Aware Coordination

> **Claude Code only.** Codex must stop and report that this workflow is not
> supported; never invoke `claude -p` from a Codex session.

Treat the token budget as a managed resource when acting as a
**work-coordination / orchestrator session** — anything that dispatches
subagents, fans out parallel work, or runs long multi-step tasks. Skip this for
quick one-shot conversational turns; it is for orchestration-scale work.

## Check the budget

Read the usage panel non-interactively:

```bash
<shared-scripts-dir>/claude-usage-check.sh
```

It runs `claude -p "/usage"` under the hood (a local panel — no model turn;
undocumented for print mode, so the invocation pins `--model haiku
--max-turns 1` as a cheap guard and fails open if the panel ever goes away),
parses the session and weekly lines (all-models plus any per-model line, e.g.
Fable or Opus depending on plan), and prints a one-line status plus a warning
past the threshold (default 85%; override with `CLAUDE_USAGE_WARN_PCT`).
Results are cached for `CLAUDE_USAGE_TTL` seconds (default 180) so repeated
checks stay cheap.

The `--hook` mode emits a `PreToolUse` JSON envelope and is wired into
`hooks/hooks.json` (matcher `Task|Agent`) so a warning surfaces automatically
before a subagent dispatch. It is warn-only and fail-open — it never blocks a
call.

## Act on it

**Before dispatching a batch of subagents** (a fan-out of two or more, or any
heavy agent), glance at the budget first:

- **Near a cap (>=85% on session or either weekly line):** right-size — fewer,
  smaller, more targeted agents — or defer non-essential ones. Both weekly
  lines count: subagent-heavy work burns the *weekly* budget even on a fresh
  session.
- **Session nearly exhausted with more work than budget:** do not grind to a
  halt mid-task. Bank the remaining/planned work, schedule a wake-up at the
  session reset time (see below), and stop.

## Manage context

**Two different resources.** The percentages above are the *usage quota*
(session and weekly) — how much of your plan's allowance is spent. The *context
window* is separate: it is per-session and refills with compaction. A high
quota percentage says nothing about remaining context, so never stop,
summarize, hand off, or suggest a new session because of it — right-size the
next dispatch and continue. The `--hook` warning carries the same reminder,
since a bare percentage in context is easy to misread as a remaining-context
countdown.

Auto-compact is on by default and cannot be disabled — treat compaction as
routine, not an emergency. The strategy: keep authoritative state **out of the
context window** so the summary only has to preserve pointers.

- **Externalize state to the tracking issue/PR (primary).** At milestones —
  work item finished, decision made, gotcha discovered — bank state to the
  tracking issue or PR (checkpoint comment or body section, e.g. via
  `/issue-update`): done / in-flight / next / decisions. The context then only
  needs "working #N, state is on the issue", which survives any compaction —
  and a fresh session, or a different agent, can resume from it.
- **Steer the summary.** A `## Compact instructions` section in CLAUDE.md
  shapes every compaction (documented); `/compact focus on X` does it one-off.
  Tell it to preserve issue/PR numbers, decisions, and next steps, and to drop
  file contents and tool output. (`PreCompact` hooks can only observe or
  block — they cannot steer content — and blocking auto-compact just hits the
  context wall, so this plugin ships none.)
- **Re-ground after compaction.** A `SessionStart` hook with matcher `compact`
  gets its stdout injected into context right after every compaction
  (documented); this plugin's `hooks/hooks.json` ships one pointing the agent
  back at the tracking issue, live `git`/`gh` state, and this budget check.
- **Keep it lean anyway:** delegate wide reads/searches to subagents (their
  tool output stays out of the main context), don't re-read files you just
  edited, and close out subtasks instead of leaving many half-open. You cannot
  run `/compact` on yourself, so before heavy stretches, state what remains in
  your own output — it gives the summarizer something crisp to keep. To
  compact earlier with smaller summaries, `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`
  exists as an **unofficial** knob — treat it as unstable.

## Resume after a reset

When you stop for budget, schedule a wake-up that reaches the reset time and
carries the resume task in its prompt. On wake, **re-verify** with the check
above before resuming — if still capped, reschedule a short retry and stop. The
wake-up mechanism clamps to <=3600s per hop; for a further-off reset, schedule
the max and re-check on wake.
