# harness-kit

harness-kit is a self-improving agent harness for Claude Code and Codex. The
shared skill catalog lives in `skills/`; host-specific packaging and agent
configuration adapt that catalog without forking its workflow guidance.

## Development

- Run `just check` before considering a change complete.
- Keep reusable executable helpers in `scripts/shared/`; Codex packaging does
  not preserve skill symlinks.
- Keep `SKILL.md` files under 500 lines and move deeper material into directly
  linked sibling references.
- Shared skills must identify host-specific behavior explicitly. Do not imply
  that Claude `allowed-tools` frontmatter restricts Codex; Codex authorization
  comes from its sandbox and approval policy.
- Use `/name` when documenting Claude Code invocation and `$name` when
  documenting Codex invocation. In shared prose, prefer “the `name` skill.”
- Keep Claude-only behavior, such as quota inspection through `claude -p`, out
  of Codex workflows.

## Repository layout

- `.claude-plugin/` packages the Claude Code plugin and marketplace. Its
  generated skill projection lives in `claude-skills/`; edit `skills/` and run
  `scripts/generate-claude-skills.sh` instead of editing the projection.
- `.codex-plugin/` packages the Codex plugin.
- `.agents/plugins/` contains the repository Codex marketplace.
- `agents/` contains Claude Code subagent definitions.
- `.codex/agents/` contains Codex subagent definitions.
- `hooks/` contains plugin lifecycle hooks backed by scripts in
  `scripts/shared/`.

## Compact instructions

When compacting, preserve tracking issue and PR numbers, the state of every
open PR, decisions and rationale, the current task list, and discovered
gotchas. Re-derive file contents and repository state from git and GitHub.
