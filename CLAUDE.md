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

### Script Path Convention

Skills address their own files as `${CLAUDE_SKILL_DIR}/<script>.sh` — the runtime substitutes the directory the skill was actually loaded from, so the same path works in the plugin cache and in a project's `.claude/skills/`. Nothing rewrites paths at install time.

A script used by one skill lives in that skill's directory. A script used by several stays canonical in `skills/shared/`, and each consumer gets a **relative** symlink:

```bash
ln -s ../shared/discover-verification-cmd.sh skills/commit/discover-verification-cmd.sh
```

Git stores these as mode `120000`, so they survive clone and `/plugin install`; `cp -R` preserves them, and the relative target resolves in either layout because `shared/` is always copied alongside. Never dereference them (`cp -RL`) — that reintroduces the duplicate copies this avoids.

Two rules that fail silently if broken:

- The `allowed-tools` Bash rule and the body must spell the path **identically**. The rule is matched as a literal string after substitution; any divergence prompts for permission on every invocation while still appearing to work.
- A shared script that invokes a sibling must resolve `$0` through symlinks before taking its `dirname` (see `skills/shared/resolve-all-threads.sh`), or it will look for the sibling in the consuming skill's directory.

`${CLAUDE_PLUGIN_ROOT}` remains correct in `hooks/hooks.json` (no skill context) and where a skill genuinely means the plugin tree — `/harness bootstrap` copying from it, `/harness update` comparing against it.

### Skill Size and Reference Files

Keep each `SKILL.md` under 500 lines. Split deeper material into reference `.md` files that sit **next to** the SKILL.md and are linked directly from it — exactly one level deep. A reference file must never link to another reference file; Claude previews unfamiliar files with `head -100` and would act on incomplete content. Any reference file over 100 lines needs a table of contents at the top.

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
