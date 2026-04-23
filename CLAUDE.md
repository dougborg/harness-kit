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
  shared/                Cross-skill shell scripts
agents/                  Agent .md files
  references/            Reference docs for agents
hooks/                   hooks.json for lifecycle hooks
```

## Development

This repo dogfoods its own harness. Use `/harness audit` to validate.

### Script Path Convention

All script references in skills use `${CLAUDE_PLUGIN_ROOT}/skills/...` paths. When `/harness bootstrap` copies skills to a project's `.claude/`, these paths are rewritten to `.claude/skills/...`.

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
