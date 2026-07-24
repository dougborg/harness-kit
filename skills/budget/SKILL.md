---
name: budget
description: >-
  Check the Claude usage/token budget before dispatching subagents or large
  fan-outs. Reports session and weekly (all-models + per-model) utilization and
  reset times, warns when near a cap, and guides right-sizing, deferring, and
  scheduling a wake-up to resume after a usage-limit reset. Use before any
  orchestration-scale work; a PreToolUse hook also surfaces this automatically.
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/skills/shared/claude-usage-check.sh*), Bash(claude -p*), Read
---

# /budget — Budget-Aware Coordination

Treat the token budget as a managed resource when acting as a
**work-coordination / orchestrator session** — anything that dispatches
subagents, fans out parallel work, or runs long multi-step tasks. Skip this for
quick one-shot conversational turns; it is for orchestration-scale work.

## Check the budget

Read the usage panel non-interactively:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/shared/claude-usage-check.sh
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

Keep the main context lean so more work fits before compaction:

- Delegate wide reads/searches to subagents — their tool output stays out of the
  main context; you keep only the conclusion.
- Do not re-read files you just edited or re-derive established facts.
- Finish and close out subtasks rather than leaving many half-open.
- You **cannot** trigger `/compact` on yourself (not a supported agent action),
  and a `PreCompact` hook cannot steer compaction. So when context is heavy and
  work remains, proactively **summarize what is left / still planned** in your
  own output — that is what survives an auto-compaction and keeps it focused.

## Resume after a reset

When you stop for budget, schedule a wake-up that reaches the reset time and
carries the resume task in its prompt. On wake, **re-verify** with the check
above before resuming — if still capped, reschedule a short retry and stop. The
wake-up mechanism clamps to <=3600s per hop; for a further-off reset, schedule
the max and re-check on wake.
