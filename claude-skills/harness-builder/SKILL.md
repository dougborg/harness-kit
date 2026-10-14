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
command such as a test suite, linter, or build. The agent sorts what it
recommends into facts, project-local content, and the generic set of
harness-kit skills and agents. This skill writes only the project-local
Claude Code files. `/harness bootstrap` (or `$harness bootstrap` on Codex)
runs the same agent as its first step, then writes the facts and vendors the
generic set for both hosts; use it for a full setup, and this skill when you
want the recommendation and a Claude-side starting point.

What the agent tends to recommend, and how to read it, is in
[recommendations.md](recommendations.md).

## 1. Run the agent

Dispatch the `harness-builder` agent on the current codebase. Pass it the
absolute paths of the harness skill's catalogs so it recommends from them
rather than from memory: `external-plugins.md`, `architecture-patterns.md`,
`hooks-reference.md`, and `release-please-reference.md`. The harness skill sits
beside this one, in `${CLAUDE_SKILL_DIR}/../harness/`, in the plugin and in a
vendored snapshot alike. Also pass the generic names it can choose from: the
skill folders beside this one and the plugin's agents.

Done when the agent has returned its report and the report does not say the
catalogs were missing; if it does, dispatch it again with the paths. When the
report misreads the stack, use the questions under "Stack detection" in
recommendations.md and fold the answers in.

## 2. Review the recommendations

The report covers:

- **Stack**: language, frameworks, and the verification command.
- **Facts**: the verification command as `[facts] verification_command`,
  then the prose for `AGENTS.md`'s `## Project facts` section.
- **Agents**: the analytical work to hand off, split into generic
  (code-reviewer, verifier) and project-local (test-writer, domain-advisor).
  Judge roles and model tiers against "Agents" in recommendations.md.
- **Skills**: the workflows to provide, split into the generic set (always
  `/commit`, plus GitHub and frontend tools when detected) and project-local
  skills. "Skills" in recommendations.md covers when a need is a fact and
  when it is a local skill.
- **Hooks**: formatters, validators, and guidance for auto-fixing. "Hooks" in
  recommendations.md has a working example; the reasoning behind the stages
  is in `${CLAUDE_SKILL_DIR}/../harness/hooks-patterns.md`.
- **Domain knowledge**: entity types, ownership, the auth and session system,
  and the side effects of mutating core entities.

Prefer the generic skills (`/commit`, `/review-pr`) the agent points to,
with the project's facts stated for them, over generating new ones. Done
when every recommendation is either accepted or explained away to the user.

## 3. Customize

Remove the agents and skills the project doesn't need, add project-specific
agents or constraints, and put the project's actual domain rules into
`CLAUDE.md` in place of boilerplate. Done when the user approves the trimmed
list.

## 4. Generate the files

After approval, generate the project-local content only:

- `.claude/agents/*.md`, one per project-local agent, with its tool
  permissions and domain context.
- `.claude/skills/*/SKILL.md`, one per project-local skill, with
  `allowed-tools` and a description that says what it does and when.
- `CLAUDE.md`, the harness documentation, with the facts.
- `.gitignore` updates.

The generic set is never copied by hand; `/harness bootstrap` vendors it.

Then run the project's verification command to confirm the setup works. On a
Nix flake, `git add` the new files first, because flakes only see tracked
files. Done when every approved file exists and the verification command
passes.

## Related

- `/harness`: audits harness quality, and bootstraps both hosts.
- `/skill-writer`: well-structured skills.
