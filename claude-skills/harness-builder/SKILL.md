---
name: harness-builder
description: Analyze a codebase and recommend an agent harness (agents, skills, hooks).
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(git log*), Bash(git status*), Bash(git add*), Bash(ls*)
disable-model-invocation: true
---

# Harness Builder

Get a harness recommendation tailored to this codebase (agents, skills, hooks,
and a `CLAUDE.md` skeleton) instead of starting from scratch. The
`harness-builder` agent reads the stack, workflows, and domain; you review,
trim, and then generate the files. Use it early in a project's setup. Its
recommendations are starting points that you are expected to customize.

It needs a git repository (the agent reads history) and a verification
command such as a test suite, linter, or build. The files it generates are
the Claude Code side only. `/harness bootstrap` (or `$harness bootstrap` on
Codex) runs the same agent as its first step and then installs for both
Claude Code and Codex, with `.harness-lock.json` provenance; use it for a
full two-host setup, and this skill when you want the recommendation and a
Claude-side starting point.

What the agent tends to recommend, and how to read it, is in
[recommendations.md](recommendations.md).

## 1. Run the agent

Dispatch the `harness-builder` agent on the current codebase. Pass it the
absolute paths of the harness skill's catalogs so it recommends from them
rather than from memory: `external-plugins.md`, `architecture-patterns.md`,
`hooks-reference.md`, and `release-please-reference.md`. The harness skill sits
beside this one, in `${CLAUDE_SKILL_DIR}/../harness/`, in the plugin and in project
copies alike.

Done when the agent has returned its report and the report does not say the
catalogs were missing; if it does, dispatch it again with the paths. When the
report misreads the stack, use the questions under "Stack detection" in
recommendations.md and fold the answers in.

## 2. Review the recommendations

The report covers:

- **Stack**: language, frameworks, and the verification command.
- **Agents**: the analytical work to hand off (always code-reviewer, verifier,
  test-writer, and domain-advisor). Judge roles and model tiers against
  "Agents" in recommendations.md.
- **Skills**: the workflows to provide (always `/commit`, plus GitHub and
  frontend tools when detected). "Skills" in recommendations.md covers when
  to extend a global skill and when to write a local one.
- **Hooks**: formatters, validators, and guidance for auto-fixing. "Hooks" in
  recommendations.md has a working example; the reasoning behind the stages
  is in `${CLAUDE_SKILL_DIR}/../harness/hooks-patterns.md`.
- **Domain knowledge**: entity types, ownership, the auth and session system,
  and the side effects of mutating core entities.

Prefer the existing global skills (`/commit`, `/review-pr`) the agent points
to, extended with project-specific variants, over generating new ones. Done
when every recommendation is either accepted or explained away to the user.

## 3. Customize

Remove the agents and skills the project doesn't need, add project-specific
agents or constraints, and put the project's actual domain rules into
`CLAUDE.md` in place of boilerplate. Done when the user approves the trimmed
list.

## 4. Generate the files

After approval, generate:

- `.claude/agents/*.md`, one per agent, with its tool permissions and domain
  context.
- `.claude/skills/*/SKILL.md`, one per skill, with `allowed-tools` and a
  description that says what it does and when.
- `CLAUDE.md`, the harness documentation.
- `.gitignore` updates.

Then run the project's verification command to confirm the setup works. On a
Nix flake, `git add` the new files first, because flakes only see tracked
files. Done when every approved file exists and the verification command
passes.

## Related

- `/harness`: audits harness quality, and bootstraps both hosts.
- `/skill-writer`: well-structured skills.
