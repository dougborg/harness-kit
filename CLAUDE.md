# harness-kit

Self-improving agent harness distributed as a Claude Code plugin.

## What This Is

A collection of skills, agents, and shared utilities for Claude Code that provide:

- **Meta-harness** (`/harness`) — audit, bootstrap, update, retro, and hoist modes
- **PR workflows** — `/open-pr`, `/review-pr`, `/pr-comments`, `/rebase`
- **Code review** — 6-dimension structured review (code-reviewer agent + skill)
- **Skill authoring** — `/skill-writer`, `/documentation-writer`
- **Validation** — Stack-agnostic verifier agent with auto-discovered verification command

## Plugin Structure

```text
.claude-plugin/          Plugin manifest and marketplace config
skills/                  SKILL.md files (auto-discovered by Claude Code)
  <skill>/*.md           Reference files, siblings of SKILL.md (one level deep only)
  shared/                Cross-skill shell scripts
agents/                  Agent .md files
  references/            Reference docs for agents
hooks/                   hooks.json for lifecycle hooks
```

## Development

This repo dogfoods its own harness. Use `/harness audit` to validate.

### Conventions for authoring skills

Two path-scoped rules load automatically when you touch `skills/` (and `hooks/`), so they are not repeated here: `.claude/rules/script-paths.md` (`${CLAUDE_SKILL_DIR}`, shared-script symlinks, `${CLAUDE_PLUGIN_ROOT}`) and `.claude/rules/skill-size.md` (500-line SKILL.md budget, one-level reference files).

### Validation

```bash
claude plugin validate .
```

## Distribution

```bash
/plugin marketplace add dougborg/harness-kit
/plugin install harness-kit@harness-kit
```

Users then run `/harness bootstrap` in their project to populate `.claude/` with selected skills and agents.

## Compact instructions

When compacting, always preserve: the tracking issue/PR numbers for in-flight
work, the state of every open PR (draft / awaiting CI / awaiting review /
approved / blocked) and whether a merge train is in flight, decisions made and
their rationale, the current task list (done / in-flight / next), and any
discovered gotchas. Drop file contents, tool output, and exploration dead ends
— they can be re-derived from git, gh, and the tracking issue's checkpoint
comment.
