---
name: skill-writer
description: >-
  Writes and reviews shared agent skills plus Claude Code Markdown and Codex
  TOML subagents for this plugin and bootstrapped projects. Covers choosing how
  prescriptive to be, the house writing style, whether a skill is user- or
  model-invoked and how skills call each other, writing the description field
  that controls when a skill fires, splitting content across reference files,
  the allowed-tools vs tools frontmatter distinction, and harness-kit's own
  conventions (shared scripts, dual plugin registration and host-specific
  script paths). Use when creating a new skill or agent, editing an existing
  one, or deciding whether something should be a skill, an agent, a script, or
  nothing at all.
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
| A fixed sequence of commands | A script in `scripts/shared/` |
| Project facts Claude must always know | `CLAUDE.md` |
| A repeatable workflow, or discipline the agent should reach for mid-task | A skill |
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

So: state what to do, with the reason in a clause rather than a narrative.
Challenge each line — does it justify its cost? Assume the reader is smart.

The real limits, and the only ones worth quoting:

| Thing | Limit |
| --- | --- |
| SKILL.md body | Under 500 lines — split into sibling files past that |
| `description` | 1,024 characters |
| `description` + `when_to_use` combined | 1,536 characters in the skill listing |
| Post-compaction re-attachment | First 5,000 tokens per skill, 25,000 total |

There is no prescribed section schema and no per-section token budget. Use the
headings the content actually needs.

## Writing the body

The house style is short plain prose. These levers decide whether an agent
takes the same path through a skill every run.

- **Give each step a completion criterion.** End every step on the condition
  that tells the agent it is done ("done when every captured value has a
  destination"). A vague bound ("once you understand the code") invites the
  agent to finish early, pulled by the steps it can see ahead. Sharpen the
  bound first; split later steps into another skill or subagent only when the
  rush persists. A demanding criterion ("every modified model accounted for")
  drives more legwork than "produce a change list".
- **Use leading words.** A compact concept the model already knows (_tight_
  loop, _tracer bullet_, _frontier_, _red_) anchors a whole region of behavior
  in one token. Repeat the word, not a sentence restating it. Prefer an
  existing word over a coined one: a coinage recruits no prior knowledge, so
  you pay for its definition. Look for a triad spelled out at three sites, or
  a sentence gesturing at one idea, and collapse it into the word.
- **State the behavior you want.** A prohibition puts the forbidden behavior
  into context and makes it more available. Write "write one-line comments",
  not "don't write long comments". Keep a prohibition only as a hard guardrail
  with no positive phrasing, and pair it with the target.
- **Write in a normal register.** Current Claude and GPT models follow
  instructions closely; CRITICAL, MUST, NEVER, and ALWAYS in capitals make them
  overtrigger and overapply. Give the rule plus a one-clause reason instead.
  Reach for stronger wording only as a targeted fix after testing shows the
  agent skipping that specific rule.
- **Delete no-ops.** Test each sentence: does it change behavior versus the
  model's default? If not, delete the whole sentence. A word too weak to beat
  the default ("be thorough") is also a no-op; the fix is a stronger leading
  word ("relentless"), not more words.
- **Let the environment be the source of truth.** A skill that restates
  `package.json` scripts, config, or `--help` output is a cache that goes
  stale. Write down what the agent cannot find by looking: the unwritten
  convention, the reason behind a choice, the gotcha no config confesses.
- **Prune sediment.** Stale layers settle because adding feels safe and
  removing feels risky. Every edit is a chance to delete a line that no longer
  bears on what the skill does.

Each meaning lives in one place. Restating a rule in a second skill doubles its
maintenance and inflates its weight; point at the owner instead.

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

`paths:` scopes auto-activation to matching globs. Measured caveat: a skill
carrying `paths:` stops registering as a slash command, so the user loses
`/name`. Only worth it for a skill nobody invokes by name.

Skill-execution fields (`context: fork`, `effort:`, `model:`), the
`allowed-tools` (skills) vs `tools` (agents) distinction, and when to reach for
a subagent at all live in [frontmatter-and-agents.md](frontmatter-and-agents.md).
Read it before setting any of them: the wrong field name is silently ignored,
and an agent with no `tools:` key inherits every tool.

## Invocation and composition

Every skill is one of two kinds, decided by who can start it:

- **Model-invoked** skills hold reusable discipline or reference: how to
  review, how to write a commit, how to file an issue. The agent can reach for
  them mid-task, and other skills can call them. The description is
  model-facing: lead with the job, then the distinct situations that should
  trigger it, one trigger per situation. It loads on every request, so it is a
  permanent context cost paid for discoverability.
- **User-invoked** skills are workflows the human times: grooming a backlog,
  restructuring issues, generating a logo. Only the human typing `/name` can
  start one; no agent and no other skill can. The description is a one-line
  summary for a person browsing the menu, and costs no context.

The test is whether the agent could usefully reach for the skill on its own,
or another skill must. If yes, keep it model-invoked; a skill that previews
its side effects before acting (`issue-create`, `issue-close`) is safe to
leave reachable. If it only ever fires by hand, make it user-invoked.

A user-invoked skill may call model-invoked skills, never another user-invoked
one. When a step needs a user-invoked skill as a precondition, tell the user to
run it rather than calling it.

**Gating an action must not gate the knowledge needed to design for it.** A
user-invoked skill is invisible while the agent designs, so guidance needed
before the action (how to pick a print orientation, how to plan a migration)
lives in a model-invoked skill or reference doc, and the user-invoked skill
keeps only the action.

### Declaring it

`agents/openai.yaml` beside each `SKILL.md` is the single source of truth.
User-invoked skills set:

```yaml
policy:
  allow_implicit_invocation: false
```

Codex reads that policy directly. The Claude generator derives
`disable-model-invocation: true` from it, so shared `SKILL.md` frontmatter
stays free of Claude-only fields. A skill hidden from Codex only because it
needs Claude Code (such as `budget`) is listed in the generator's
`claude_only` set instead. Every `openai.yaml` also carries
`interface.display_name` and `interface.short_description` for the Codex
picker. The Claude menu still shows a user-invoked skill;
`user-invocable: false` is the separate field that hides it there.

### Calling another skill

Write the call as an instruction to use the Skill tool: `Call the Skill tool
with "commit"`. Naming the tool fires it far more reliably than a bare `/commit`
in prose, and a bare name carries no host-specific slash syntax. One skill per
call: a step that needs two says `Call the Skill tool twice, for "grilling" and
"domain-modeling"`. Shared reference lives in the skill that owns it; other
skills reach it by calling that skill, not by linking into its folder.

Router prose that only lists skills for a human to pick from (`## Related`
sections) is not a call and keeps `/name` labels.

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

## harness-kit conventions

- **Extract inline bash into a script.** Anything beyond a couple of lines
  becomes a script — it gets ShellCheck coverage from `just check` and can be
  tested. A script used by one skill lives in that skill's directory; anything
  reused across skills is canonical in `scripts/shared/`.
- Address skill-local scripts as `${CLAUDE_SKILL_DIR}/name.sh`. Address scripts reused
  by multiple skills as `${CLAUDE_SKILL_DIR}/name.sh`; they stay canonical in
  `scripts/shared/`. The Claude projection adds matching runtime paths to
  `allowed-tools`. Codex plugin packaging omits skill symlinks, so do not use
  symlinks as the distribution mechanism.
- **Never put `eval` in the same command as an allowed script call.** Claude
  Code cannot statically analyze a command containing `eval`, so no
  `allowed-tools` rule matches and it prompts on every run. `var=$(script.sh)`
  and `script.sh --flag arg` both match fine; `cmd=$(script.sh); eval "$cmd"`
  does not. Split it into two calls.
- A shared script that calls a sibling resolves it beside the canonical script;
  see `scripts/shared/resolve-all-threads.sh`.
- Register canonical skills through `.codex-plugin/plugin.json`, regenerate
  `claude-skills/`, and register the projection in
  `.claude-plugin/plugin.json`. Claude agents use the Claude manifest; Codex
  agents are project TOMLs installed by bootstrap.
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

Copyable skill and agent skeletons live in [templates.md](templates.md).

## Related

- `/documentation-writer` — human-facing docs (README, guides, reference)
- `/harness audit` — audits skills and agents in a project
- `agents/references/hooks-reference.md` — hooks.json schema, events, gotchas

## Sources

- [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- [Claude Code skills](https://code.claude.com/docs/en/skills)
- [Prompting Claude Fable 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5)
- [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) (dial back aggressive emphasis)
- [skill-creator](https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md)
- [GPT-5 prompting guide](https://developers.openai.com/cookbook/examples/gpt-5/gpt-5_prompting_guide)
- [Agent Skills specification](https://agentskills.io/specification)
- [mattpocock/skills `writing-for-agents`](https://github.com/mattpocock/skills/tree/main/skills/productivity/writing-for-agents) (MIT): completion criteria, leading words, negation, no-ops, and the invocation split; see `CREDITS.md`
