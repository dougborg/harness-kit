# Frontmatter and agents reference

Detail behind `SKILL.md` for skill-execution fields and subagent design. Read it when a skill needs `context: fork`, tool restrictions, or when writing an agent.

## Contents

- [`context: fork`](#context-fork--run-the-skill-in-a-subagent)
- [`allowed-tools` vs `tools`](#allowed-tools-skills-vs-tools-agents)
- [Skills and agents: isolation, not read-only](#skills-and-agents-isolation-not-read-only)

## `context: fork` — run the skill in a subagent

```yaml
context: fork
agent: harness-kit:code-reviewer   # optional: which agent to fork into
background: false
```

Right for skills that read widely and return a report. Four constraints:

- The fork sees **no conversation history**. A skill that depends on "what we
  were just doing" is not a candidate; say what it needs up front.
- Only works for skills with **explicit instructions**. Guidelines without a
  task give the subagent no actionable prompt.
- A backgrounded fork runs with the **narrower background-subagent tool set** —
  set `background: false` when the skill needs more.
- Forked edits land outside session checkpoints (`/rewind` won't undo them),
  and a forked skill ends skill-stacking: `/a /b` chains stop there.

`effort:` (`low`…`max`) overrides per-skill reasoning depth. Use it where the
work is genuinely mechanical (`low`) or genuinely deep (`high`); otherwise
inherit.

Name in gerund form where it reads naturally (`processing-pdfs`); noun phrases
and command-style names (`open-pr`) are fine. Avoid vague names.

Omit `model:` on skills — they execute in the parent conversation's context,
and pinning a model can break long sessions (e.g. 1M-context Opus). Agents get
a fresh context, so `model:` on an agent is fine.

## `allowed-tools` (skills) vs `tools` (agents)

**The field name differs by file type, and the wrong one is silently ignored.**
This is not cosmetic: every "read-only" agent in this repo carried
`allowed-tools:` for months and ran completely unrestricted, because an agent
with no `tools:` key **inherits every tool**. Omitting it is not a safe
default — it is the permissive default.

| File type | Field | Accepts |
| --- | --- | --- |
| Skill (`SKILL.md`) | `allowed-tools:` | Tool names **and** `Bash(pattern*)` scoping |
| Agent (`agents/*.md`) | `tools:` / `disallowedTools:` | Bare tool names only — **no** `Bash(...)` scoping |

Per-command Bash scoping for an agent belongs in settings permissions or a
`PreToolUse` hook, not in frontmatter. `Task` is not a tool name — subagent
dispatch is not granted this way.

Grant the minimum that works, then test by removing one entry: if it still
works, leave it out.

| Role | Typical grant |
| --- | --- |
| Validator skill | `Bash(just check*)` — scoped, not bare `Bash` |
| Generator skill | `Write(.claude/skills/**)`, `Read`, `Glob` |
| Advisory agent | `Read, Grep, Glob` |
| Reviewing agent | `Read, Grep, Glob, Bash` — never `Write` |

## Skills and agents: isolation, not read-only

Older guidance in this repo claimed agents are advisors that never execute or
modify files. That was never true here, and it is not what subagents are for.

The real trade-off is **isolation and context economy**. A subagent gets its
own context window; its tool output — wide searches, long file reads, verbose
command output — never enters the parent conversation, only its final report
does. That is the reason to reach for one.

Restricting an agent's tools is a separate, deliberate choice you make per
agent, and you make it in `tools:`. `code-reviewer` and `project-manager` are
advisory by design and should hold no write tools; `verifier` and
`harness-builder` legitimately run commands. Write down which one you are
building, and make the frontmatter match — a description promising "read-only"
over inherited-everything tools is a lie the runtime will not catch.

Subagents also support `memory:`, `isolation: worktree`, and `permissionMode:`
when the work needs persistence, a scratch checkout, or different prompting
behavior.
