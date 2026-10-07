---
name: harness-builder
description: Analyze a codebase and recommend an agent harness (agents, skills, hooks).
allowed-tools: Read, Grep, Glob, Bash(git log*), Bash(git status*), Bash(ls*)
disable-model-invocation: true
---

# Harness Builder

Get a harness recommendation tailored to this codebase (agents, skills, hooks,
and a `CLAUDE.md` skeleton) instead of starting from scratch. The
`harness-builder` agent reads the stack, workflows, and domain; you review,
trim, and then generate the files. Use it early in a project's setup. Its
recommendations are starting points that you are expected to customize.

It needs a git repository (the agent reads history) and a verification
command such as a test suite, linter, or build. `/harness bootstrap` (or
`$harness bootstrap` on Codex) runs the same agent as its first step and then
installs; use this skill when you want the recommendation on its own.

What the agent tends to recommend, and how to read it, is in
[recommendations.md](recommendations.md): agents and model tiers, skills,
hook stages with an example configuration, and what to do when it misreads
the stack.

## 1. Run the agent

Dispatch the `harness-builder` agent on the current codebase. Pass it the
absolute paths of the harness skill's catalogs so it recommends from them
rather than from memory: `external-plugins.md`, `architecture-patterns.md`,
`hooks-reference.md`, and `release-please-reference.md`. The harness skill sits
beside this one, in `${CLAUDE_SKILL_DIR}/../harness/`, in the plugin and in project
copies alike.

Done when the agent has returned its report and the report does not say the
catalogs were missing; if it does, dispatch it again with the paths.

## 2. Review the recommendations

The report covers:

- **Stack**: language, frameworks, and the verification command.
- **Agents**: the analytical work to hand off (always code-reviewer, verifier,
  test-writer, and domain-advisor).
- **Skills**: the workflows to provide (always `/commit`, plus GitHub and
  frontend tools when detected).
- **Hooks**: formatters, validators, and guidance for auto-fixing.
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

- `/harness`: audits harness quality (frontmatter validity, size limits,
  description signal).
- `CLAUDE.md`: the generated harness documentation; customize it after
  generation.
- `/documentation-writer`: scannable docs.
- `/skill-writer`: well-structured skills.
