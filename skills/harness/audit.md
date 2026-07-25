# Audit Mode

The audit protocol for `/harness audit`. Run it on the current project's harness — skills, agents, hooks, and CLAUDE.md.

## Division of labor with `/doctor`

Claude Code ships a bundled `/doctor` skill (alias `/checkup`) that is available in every session, including when `disableBundledSkills` is set. It already diagnoses generic setup health natively. Do not reimplement any of it here.

| Owner | Covers |
| --- | --- |
| `/doctor` | Installation and PATH problems, unused skills and MCP servers, slow hooks, CLAUDE.md boilerplate/bloat, frequently-denied read-only commands |
| `/harness audit` | harness-kit-specific structure, frontmatter validity, description signal quality, provenance (`.harness-lock.json`), cross-skill consistency, gap classification |

If a check you are about to add belongs in the left column, it does not belong in this file.

## Contents

- [1. Run /doctor](#1-run-doctor)
- [2. Detect Project Stack](#2-detect-project-stack)
- [3. Read All Harness Content](#3-read-all-harness-content)
- [4. Check Alignment](#4-check-alignment)
- [5. Check Model Tiering](#5-check-model-tiering)
- [6. Check Gaps](#6-check-gaps)
- [7. Check Frontmatter Validity](#7-check-frontmatter-validity)
- [8. Check Description Signal Quality](#8-check-description-signal-quality)
- [9. Check Size, Splitting, and Inline Bash](#9-check-size-splitting-and-inline-bash)
- [10. Check Internal Consistency](#10-check-internal-consistency)
- [11. Check Harness vs Implementation Health](#11-check-harness-vs-implementation-health)
- [Output Format](#output-format)

## 1. Run /doctor

Invoke `/doctor` first and fold its findings into the audit report under a "Setup health (from /doctor)" heading, attributed to it. Do not re-derive or second-guess those findings; the remaining steps assume they are covered.

If `/doctor` is unavailable in the current session, say so in the report rather than substituting hand-rolled equivalents.

## 2. Detect Project Stack

Find the verification command for this project:

- Check `justfile` for `check` or `ci` recipe
- Check `Makefile` for `ci`, `check`, or `test` target
- Check `package.json` for `test` or `check` script
- Check `Cargo.toml` → `cargo test`
- Check `flake.nix` → `nix flake check`

## 3. Read All Harness Content

- List and read every file in `.claude/agents/` and `.claude/skills/`
- Check for legacy `.claude/commands/` directory — flag for migration to skills
- Check `CLAUDE.md` for harness documentation

## 4. Check Alignment

- Do agent instructions reference the correct verification command?
- Do tool references match what's actually installed?
- Do agents reference correct paths and conventions from CLAUDE.md?
- Is CLAUDE.md present and does it document all agents and skills?
- Does CLAUDE.md include the `<new-diagnostics>` protocol (verify LSP diagnostics with the project's type-check CLI before dismissing as stale)? See the baseline section in `agents/harness-builder.md`.
- Does every skill and agent file appear in `.harness-lock.json`, and does every lock-file entry still exist on disk?

## 5. Check Model Tiering

- `haiku` for fast validation tasks (verifier)
- `sonnet` for generation and analysis (code-reviewer, test-writer)
- `opus` only for deep architectural decisions
- Skills should carry no `model:` at all — they run in the parent conversation
- Flag any mismatch

## 6. Check Gaps

ChernyCode principle: "If you do something more than once a day, make it a skill."

**Universal agents (should exist in every project):**

- Is there a `code-reviewer` agent? (6-dimension review)
- Is there a `verifier` agent? (skeptical validator)
- Is there a `test-writer` agent? (project testing conventions)
- Is there a `domain-advisor` agent? (read-only, answers business rules)

**Stack-dependent:**

- If GitHub is used: `project-manager` agent? + `/feature-spec`, `/issue-triage`, `/standup` skills?
- If frontend present: design harness (`.impeccable.md`) + `/ui-review` skill?

**Bundled-skill and official plugin coverage** (catalog: `agents/references/external-plugins.md`):

- Is a local skill, agent, or script reimplementing something a bundled skill already does (beyond `/doctor` — e.g. `/verify`, `/code-review`, `/security-review`, `/batch`, `/run-skill-generator`)? Recommend delegating. Check the bundled-skills table before any install recommendation
- Would an official Anthropic plugin cover a detected gap? (e.g., Python without `pyright-lsp`, an MCP server without `mcp-server-dev`, a legacy codebase without `code-modernization`) — recommend the install command, don't generate a local equivalent
- Check installed plugins (`claude plugin list`) for **double-coverage**: is both a harness-kit skill and an overlapping official plugin active (e.g., `code-reviewer` + `code-review`, `/commit` + `commit-commands`)? Recommend picking one — with a one-line comparison — or documenting the composition in CLAUDE.md
- Does CLAUDE.md's "External plugins" section reflect what's actually installed?

**Project-specific:**

- Is there a `/commit` skill with quality gates?
- Are there domain-specific debug skills for things that most commonly break?
- Do project-local skills compose with global skills rather than duplicating them?
- Is there a legacy `.claude/commands/` directory? (flag for migration to skills)

**Automation (Hooks):**

- Are PostToolUse hooks configured in `.claude/settings.local.json`?
- Do hooks follow Formatters → Validators → Guidance order?
- Are formatters configured for the project stack (ruff, prettier, nix-fmt, markdownlint)?
- Is there a Stop hook for session-end guidance (e.g., suggest `/harness retro` after large sessions)?
- Do all hook commands exit 0 on success **and on no-op**? Ask of every hook: "what happens when this has nothing to do?" If the answer is "it exits non-zero," it needs fixing — use `if [ cond ]; then action; fi`, never `[ cond ] && action`.

Hook *latency* is `/doctor`'s job — don't time hooks here.

## 7. Check Frontmatter Validity

The field name differs by file type and **the wrong one is silently ignored** — this is the failure mode that let every "read-only" agent in harness-kit run unrestricted for months. Check mechanically, per file:

| File | Valid | Invalid |
| --- | --- | --- |
| `skills/*/SKILL.md` | `name`, `description`, `when_to_use`, `allowed-tools`, `disallowed-tools`, `argument-hint`, `disable-model-invocation`, `user-invocable`, `context`, `agent`, `background`, `effort`, `paths` | `tools:`, `disallowedTools:`, `model:` |
| `agents/*.md` | `name`, `description`, `tools`, `disallowedTools`, `model`, `memory`, `isolation`, `permissionMode` | `allowed-tools:` |

Flag, at high priority:

- `allowed-tools:` in an agent file, or `tools:` in a skill file — the restriction is not in force
- An agent whose prose or description promises "read-only" / "advisory" but has no `tools:` key — no key means **every tool is inherited**, not none
- `Bash(pattern*)` scoping inside an agent's `tools:` — agents accept bare tool names only; the scoped entry does not match and the grant silently fails
- Non-existent tool names — `Task` is the common one (subagent dispatch is not granted via frontmatter); also flag anything not in the current tool set
- Skill directory name not matching the frontmatter `name`
- A skill or agent file missing from `.claude-plugin/plugin.json` (plugin repos only) — it will not load

Then apply the permission review:

- Do agents have only the tools they need? A reviewer should not have `Write`; a verifier should not have `Write` or `Edit`
- Is a side-effecting skill (one that writes files, pushes, comments, or opens PRs) missing `disable-model-invocation`? Skills that must only run when the user asks for them should not be model-invocable
- Conversely: does a skill carry `disable-model-invocation` while **another skill instructs Claude to invoke it** (`grep -rn '/skill-name' skills/ agents/`)? That chain is silently broken — either drop the field or reword the caller to hand off to the user. Same for a restricted skill named in an agent's `skills:` field, which cannot preload it
- Does a `context: fork` skill depend on conversation history, or run `background: true` while needing tools outside the background-subagent set? Both fail silently

## 8. Check Description Signal Quality

The `description` is the only thing Claude sees before deciding to load a skill, so it is where signal is won or lost. Flag:

- Missing or empty `description`
- `description` over **1,024 characters**
- `description` + `when_to_use` over **1,536 characters** combined — the skill listing truncates past this
- A description that says only *what* it does but not *when* to use it, or vice versa
- Vague descriptions with no trigger terms a user would actually type ("Helps with commits") — these produce skills that never fire
- Descriptions so narrow they only fire on exact phrasing
- Two skills whose descriptions overlap enough that the model cannot tell them apart — pick a distinguishing clause for each

`/skill-writer` has the worked weak/strong examples.

## 9. Check Size, Splitting, and Inline Bash

The only real limits worth enforcing. There is **no section schema and no per-section token budget** — do not flag a skill for lacking particular headings.

- Is any `SKILL.md` body over **500 lines**? Split topic- or mode-specific depth into sibling reference files
- Are reference files **exactly one level deep** from SKILL.md? A reference that links to another reference gets partially read (`head -100`) and yields incomplete information — flag any second hop
- Does every reference file over **100 lines** have a table of contents? A partial read must still reveal the file's full scope
- Do skills reference file paths rather than inlining code?
- Is any skill duplicating content from another skill? (creates drift)
- **Any inline bash block with logic** (conditionals, loops, pipes)? → Extract to a script in the skill's directory
- **Any inline bash duplicated across skills?** → Extract to `skills/shared/`
- **Any inline command previously fixed for wrong syntax?** → Extract to prevent recurrence

## 10. Check Internal Consistency

Contradiction between a skill and the guidance it cites is the failure mode that makes a harness actively harmful — the model gets two rules and picks arbitrarily. Heuristic, imperfect, still worth running:

- Does a skill assert a rule that the skill it links to (or CLAUDE.md) contradicts? Quote both sides in the finding
- Does a skill still cite a section, filename, or field that no longer exists in its target?
- Is one concept named two ways across skills? Pick one name and use it throughout
- Does an agent's description promise behavior its `tools:` cannot perform?
- Do two skills prescribe different procedures for the same operation (e.g. two different commit flows)?

## 11. Check Harness vs Implementation Health

**For domain skills:** Does a test file encode these rules as executable specs? If the harness is the only place a rule is enforced, it's in the wrong place.

**For agents:** Is the agent an advisor (reads, answers, guides — fine), an enforcer (checks state, validates data — should be a test), or compensating for a missing product feature (should be a dashboard alert)?

## Output Format

For each finding:

- **Gap/Issue**: what's missing or misaligned
- **Fix**: specific change to make
- **Priority**: high / medium / low
- **Type**: A/B/C gap classification

Separate the two kinds of finding, and say which is which:

- **Defects** — mechanically checkable: invalid frontmatter, over a documented limit, a reference two levels deep, a missing table of contents.
- **Recommendations** — judgment calls: description vagueness, gap coverage, suspected contradictions.

Audit is advisory. It does not block a merge on a judgment call.
