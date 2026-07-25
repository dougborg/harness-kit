---
name: skill-writer
description: >-
  Writes and reviews Claude Code skills (SKILL.md) and subagents (agents/*.md)
  for this plugin and for projects bootstrapped from it. Covers choosing how
  prescriptive to be, writing the description field that controls when a skill
  fires, splitting content across reference files, the allowed-tools vs tools
  frontmatter distinction, and harness-kit's own conventions (shared scripts,
  plugin.json registration, ${CLAUDE_PLUGIN_ROOT} paths). Use when creating a
  new skill or agent, editing an existing one, or deciding whether something
  should be a skill, an agent, a script, or nothing at all.
disable-model-invocation: true
allowed-tools: Glob, Grep, Read, Write, Edit
---

# /skill-writer — Authoring Skills and Agents

Claude already knows the skill format. This skill exists for the judgment calls
the format does not make for you: how prescriptive to be, what earns a place in
a file that stays in context all session, and the conventions specific to this
repo.

## First, decide whether to write one at all

A skill is worth writing when the task recurs, and when Claude's default
behavior on it is wrong or under-informed. If default performance is already
good, a skill that restates the obvious makes output worse, not better — it
spends context and over-constrains a capable model.

Prefer the smallest thing that works:

| Need | Reach for |
| --- | --- |
| A fixed sequence of commands | A script in `skills/shared/` |
| Project facts Claude must always know | `CLAUDE.md` |
| A repeatable multi-step workflow the user invokes | A skill |
| Wide reads/searches whose output should stay out of the main context | An agent |
| Something that must happen automatically, every time | A hook |

## Match specificity to fragility

The central authoring decision is **degrees of freedom** — how much latitude to
leave. Set it per-instruction, based on how fragile the operation is, not by
applying one uniform level to a whole file.

- **High freedom** — prose, heuristics, a stated goal. Use when several
  approaches are valid and the right one depends on context. "Summarize what
  changed and why, in the reviewer's terms."
- **Medium freedom** — a preferred pattern with room to vary: pseudocode, a
  parameterized script, a worked example to adapt.
- **Low freedom** — exact commands, explicit ordering, "do not add flags to
  this command." Use when the operation is fragile, when consistency across
  runs matters, or when a specific sequence must hold.

The test: a narrow bridge with cliffs on both sides gets guardrails; an open
field gets a direction to walk in. Over-guardrailing an open field is the more
common failure here — it reads as thorough and degrades results.

Corollary: skills written for older models are often too prescriptive for
current ones. When editing an existing skill, actively look for instructions to
**delete**, and check whether default behavior is already better than what the
skill mandates.

## Every line is a recurring cost

Once a skill loads, its content stays in context for the rest of the session.
After auto-compaction, Claude Code re-attaches only the **first 5,000 tokens**
of each invoked skill, inside a **25,000-token** combined budget filled
most-recent-first — an oversized skill gets truncated mid-file and pushes older
skills out entirely.

So: state what to do rather than narrating how or why. Challenge each line —
does it justify its cost? Assume the reader is smart.

The real limits, and the only ones worth quoting:

| Thing | Limit |
| --- | --- |
| SKILL.md body | Under 500 lines — split into sibling files past that |
| `description` | 1,024 characters |
| `description` + `when_to_use` combined | 1,536 characters in the skill listing |
| Post-compaction re-attachment | First 5,000 tokens per skill, 25,000 total |

There is no prescribed section schema and no per-section token budget. Use the
headings the content actually needs.

## Structure: a default, not a contract

A workflow skill usually wants: what this is for, the constraints that would
cause real damage if violated, the happy path, then the exceptions. That
ordering is a good default because a reader who stops early still has the
important parts.

Adapt it freely. Named sections beat generic ones — `## Check the budget` tells
a skimmer more than `## STANDARD PATH`. A reference skill may be a table and
nothing else. A skill with one instruction should be one paragraph.

Two things genuinely help on complex tasks and are worth including when they
apply:

- **A copyable checklist** for multi-step work, so progress is trackable.
- **A feedback loop** — run the validator, fix what it reports, repeat until
  clean. Give Claude something to check its own work against.

**Examples are not bloat.** When output quality depends on matching a shape —
commit messages, review comments, generated files — showing an input/output
pair is the most token-efficient instruction available.

## Frontmatter

```yaml
---
name: skill-name
description: >-
  What it does and when to use it, third person, with the words a user would
  actually say.
allowed-tools: Read, Grep, Bash(git log*)
---
```

### The description decides whether the skill ever fires

It is the only part Claude sees before deciding to load the skill, so it must
carry **what it does** and **when to use it**, written in third person, with
specific trigger terms a user would actually type. Vague descriptions produce
skills that never fire; overly narrow ones fire only on exact phrasing.

- Weak: "Helps with commits."
- Strong: "Creates conventional commits with quality gates — runs validation,
  stages, and writes the message. Use when committing changes, or when the user
  asks to commit, stage, or write a commit message."

An optional `when_to_use` field can carry trigger phrasing separately; keep the
two together under 1,536 characters.

### Control who invokes the skill

`description` (and `when_to_use`) load into context on **every request** so
Claude can decide whether to invoke the skill. `disable-model-invocation: true`
hides the skill from Claude entirely until the user types `/name` — dropping
its context cost to zero. It stays in the `/` menu; `user-invocable: false` is
the field that hides it from the menu.

Default to setting it on any skill with side effects that the user should time
deliberately — filing issues, writing docs, generating files. **Before you set
it, grep for the skill name across `skills/` and `agents/`.** If another skill
tells Claude to invoke this one mid-workflow, restricting it breaks that chain
silently — `just check` validates schema, not behavior. In this repo `/commit`,
`/open-pr`, `/review-pr`, `/harness-issue`, and `/harness` are all invoked by
other skills and must stay model-invocable. A restricted skill also cannot be
preloaded into a subagent via an agent's `skills:` field.

`paths:` scopes auto-activation to matching globs — the opposite lever from
`disable-model-invocation`, so pick one per skill. Measured caveat: a skill
carrying `paths:` stops registering as a slash command, so the user loses
`/name`. Only worth it for a skill nobody invokes by name.

### `context: fork` — run the skill in a subagent

```yaml
context: fork
agent: harness-kit:code-reviewer   # optional: which agent to fork into
background: false
```

Right for skills that read widely and return a report. Four constraints:

- The fork sees **no conversation history**. A skill that depends on "what we
  were just doing" is not a candidate — say so in its ASSUMES.
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

### `allowed-tools` (skills) vs `tools` (agents)

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

## Splitting across files

SKILL.md is the navigation layer. When it outgrows ~500 lines, move depth into
sibling files and link to them by name and purpose, so Claude can tell whether
a file is worth opening.

```text
skills/my-skill/
  SKILL.md          Navigation + the path most runs take
  reference.md      Full detail, loaded on demand
  scripts/run.sh    Executable steps, not pasted into the body
```

Two rules make this work:

- **One level deep.** References from SKILL.md only. Nested references get
  partially read (`head -100`) and yield incomplete information.
- **Table of contents past 100 lines.** A partial read of a long reference
  should still reveal its full scope.

Agent reference docs in this repo live in `agents/references/` and follow the
same rules.

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

## harness-kit conventions

- **Extract inline bash into `skills/shared/`.** Anything beyond a couple of
  lines, or reused across skills, becomes a script there — it gets ShellCheck
  coverage from `just check` and can be tested. Reference it as
  `${CLAUDE_PLUGIN_ROOT}/skills/shared/name.sh` and add the matching
  `Bash(${CLAUDE_PLUGIN_ROOT}/skills/shared/name.sh*)` entry to `allowed-tools`.
- **Always use `${CLAUDE_PLUGIN_ROOT}` paths**, never relative or absolute
  ones. `/harness bootstrap` rewrites them to `.claude/...` when copying skills
  into a project.
- **Register new skills and agents in `.claude-plugin/plugin.json`** under
  `skills` / `agents`. An unregistered file will not load.
- **Run `just check`** before committing — plugin validation, hook schema
  checks, ShellCheck, markdownlint, and whitespace hygiene.
- **Skill directory name must match the frontmatter `name`.**

## Evaluate before you elaborate

Before writing extensive instructions, write three concrete tasks the skill
should handle and run them **without** the skill. That baseline tells you what
Claude already does well — which is exactly what the skill should not repeat.
Then add only the instructions that move a failing case, and re-run.

Test across model tiers when the skill will be used by more than one: what
reads as over-explaining to Opus can be the necessary detail for Haiku.

## Anti-patterns

- Offering several options with no default. Pick one; mention alternatives only
  if the choice is genuinely situational.
- Time-sensitive content ("as of the March release", "the new API"). If old
  behavior must be documented, put it in an `<details>` block labelled as
  historical.
- Inconsistent terminology — one name per concept, throughout.
- Windows-style paths.
- Restating general good practice Claude already follows.

## Templates

Starting points, not schemas. Delete any heading the skill does not need.

### Skill

```markdown
---
name: skill-name
description: >-
  What it does, and when to use it — third person, with trigger terms.
allowed-tools: Read, Write, Bash(git add*), Bash(git commit*)
---

# /skill-name — Short Title

One or two sentences: what this is for and when it applies.

## <Constraints that cause real damage if violated>

## <The path most runs take>

## <Exceptions, named so a skimmer can tell if they are in one>

## Related

- `/other-skill` — how it connects
```

### Agent

```markdown
---
name: agent-name
description: >-
  What this agent analyzes or does, and when to dispatch it. Include
  <example> blocks showing the invoking exchange.
tools: Read, Grep, Glob
---

# Agent Name

What this agent is for, and what it returns to its caller.

## <How it works — checklist, dimensions, or procedure>

## Output format

<The exact shape of the report the caller receives>
```

## Related

- `/documentation-writer` — human-facing docs (README, guides, reference)
- `/harness audit` — audits skills and agents in a project
- `agents/references/hooks-reference.md` — hooks.json schema, events, gotchas

## Sources

- [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- [Claude Code skills](https://code.claude.com/docs/en/skills)
- [Prompting Claude Fable 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5)
