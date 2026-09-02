# harness-kit

@AGENTS.md

Claude Code-specific development and distribution notes follow. Shared project
expectations are defined in `AGENTS.md` above.

## What This Is

A collection of shared skills plus Claude Code-specific agent and packaging adapters:

- **Meta-harness** (`/harness`) — audit, bootstrap, update, retro, and hoist modes
- **PR workflows** — `/open-pr`, `/review-pr`, `/pr-comments`, `/rebase`
- **Multi-agent coordination** — `/agent-standup` reconciles ownership, handoffs, and merge order across agents and operators
- **Code review** — 6-dimension structured review (code-reviewer agent + skill)
- **Skill authoring** — `/skill-writer`, `/documentation-writer`
- **Validation** — Stack-agnostic verifier agent with auto-discovered verification command

## Plugin Structure

```text
.claude-plugin/          Plugin manifest and marketplace config
skills/                  Canonical open-format skills used by Codex
  <skill>/*.md           Reference files, siblings of SKILL.md (one level deep only)
claude-skills/           Generated Claude projection; never edit directly
scripts/shared/          Cross-skill shell scripts
agents/                  Agent .md files
  references/            Reference docs for agents
hooks/                   hooks.json for lifecycle hooks
```

## Development

This repo dogfoods its own harness. Use `/harness audit` to validate.

### Conventions for authoring skills

Two path-scoped rules load automatically when you touch skills or hooks, so
they are not repeated here. After changing `skills/`, run
`scripts/generate-claude-skills.sh`; `just check` verifies the projection.

### Validation

```bash
claude plugin validate .
```

## Distribution

```bash
/plugin marketplace add dougborg/harness-kit
/plugin install harness-kit@harness-kit
```

Users then run `/harness bootstrap` or `$harness bootstrap` to populate both
Claude Code and Codex project-local harness directories.

## Compact instructions

When compacting, always preserve: the tracking issue/PR numbers for in-flight
work, the state of every open PR (draft / awaiting CI / awaiting review /
approved / blocked) and whether a merge train is in flight, decisions made and
their rationale, the current task list (done / in-flight / next), and any
discovered gotchas. Drop file contents, tool output, and exploration dead ends
— they can be re-derived from git, gh, and the tracking issue's checkpoint
comment.
