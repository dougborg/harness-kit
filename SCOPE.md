# Scope

harness-kit is a self-improving agent harness for Claude Code and Codex. It
ships one skill catalog, canonical in `skills/`, grouped into topic areas:
engineering, meta, orchestration, project management, thinking, and writing.
Host-specific packaging adapts that catalog; it never forks the guidance.

## In scope

- **Skills and agents** that help an agent do real work in any of the topic
  areas, on both hosts. A Claude-only or Codex-only skill says so.
- **The meta-harness**: auditing, bootstrapping, updating, and improving a
  project's own harness, including retros that file findings back here.
- **Workflow guardrails**: hooks, scripts, and checks that make a skill's
  promise hold, such as CI polling and review gates.
- **Ports from other skill collections**, rewritten in the house style, when
  they fill a gap the catalog has.

## Out of scope

- **A second copy of something a host already does.** A built-in command, a
  permission rule, or an official plugin that covers the need wins.
- **Overlaps with an existing skill.** Improve the existing one instead.
- **One person's workflow tweak or config option.** Put it in your project's
  `AGENTS.md` or `CLAUDE.md`, or in a local skill.

## Already decided

Each file in [`.out-of-scope/`](./.out-of-scope/) records one rejected idea
and why. Read them before filing:

- [`changesets.md`](./.out-of-scope/changesets.md)
- [`chief-of-staff.md`](./.out-of-scope/chief-of-staff.md)
- [`em-dash-ban.md`](./.out-of-scope/em-dash-ban.md)
- [`git-guardrails.md`](./.out-of-scope/git-guardrails.md)
- [`per-skill-docs-pages.md`](./.out-of-scope/per-skill-docs-pages.md)

## Deferred

Not rejected, just not yet. These don't go in `.out-of-scope/`:

- **mattpocock/skills `writing-fragments`, `writing-shape`, `writing-beats`**:
  still in upstream's `in-progress/`; ported once upstream promotes them.

## Filing

Issues track changes to harness-kit. The strongest report names a real
session where a skill fell short: what ran, what happened, what you expected.
From a project that uses harness-kit, the `harness-issue` skill files one in
that shape for you.
