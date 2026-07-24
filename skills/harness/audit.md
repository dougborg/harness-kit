# Audit Mode

The 10-step audit protocol for `/harness audit`. Run it on the current project's harness — skills, agents, hooks, and CLAUDE.md.

## Contents

- [1. Detect Project Stack](#1-detect-project-stack)
- [2. Read All Harness Content](#2-read-all-harness-content)
- [3. Check Alignment](#3-check-alignment)
- [4. Check Model Tiering](#4-check-model-tiering)
- [5. Check Gaps](#5-check-gaps)
- [6. Check Tool Permissions](#6-check-tool-permissions)
- [7. Check Agent Purpose (Advisor vs Enforcer)](#7-check-agent-purpose-advisor-vs-enforcer)
- [8. Check Token Efficiency](#8-check-token-efficiency)
- [9. Check Harness vs Implementation Health](#9-check-harness-vs-implementation-health)
- [10. Check Skill Structure (Scannable Contract)](#10-check-skill-structure-scannable-contract)
- [Output Format](#output-format)

## 1. Detect Project Stack

Find the verification command for this project:

- Check `justfile` for `check` or `ci` recipe
- Check `Makefile` for `ci`, `check`, or `test` target
- Check `package.json` for `test` or `check` script
- Check `Cargo.toml` → `cargo test`
- Check `flake.nix` → `nix flake check`

## 2. Read All Harness Content

- List and read every file in `.claude/agents/` and `.claude/skills/`
- Check for legacy `.claude/commands/` directory — flag for migration to skills
- Check `CLAUDE.md` for harness documentation

## 3. Check Alignment

- Do agent instructions reference the correct verification command?
- Do tool references match what's actually installed?
- Do agents reference correct paths and conventions from CLAUDE.md?
- Is CLAUDE.md present and does it document all agents and skills?
- Does CLAUDE.md include the `<new-diagnostics>` protocol (verify LSP diagnostics with the project's type-check CLI before dismissing as stale)? See the baseline section in `agents/harness-builder.md`.

## 4. Check Model Tiering

- `haiku` for fast validation tasks (verifier)
- `sonnet` for generation and analysis (code-reviewer, test-writer)
- `opus` only for deep architectural decisions
- Flag any mismatch

## 5. Check Gaps

ChernyCode principle: "If you do something more than once a day, make it a skill."

**Universal agents (should exist in every project):**

- Is there a `code-reviewer` agent? (6-dimension review)
- Is there a `verifier` agent? (skeptical validator)
- Is there a `test-writer` agent? (project testing conventions)
- Is there a `domain-advisor` agent? (read-only, answers business rules)

**Stack-dependent:**

- If GitHub is used: `project-manager` agent? + `/feature-spec`, `/issue-triage`, `/standup` skills?
- If frontend present: design harness (`.impeccable.md`) + `/ui-review` skill?

**Official plugin coverage** (catalog: `agents/references/external-plugins.md`):

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
- Formatters (silent, zero-token): auto-fix style issues on every Edit/Write
- Validators (bounded, gated): check for errors, surface only real problems
- Guidance (≤20 lines): orient developer with context reminders
- Are formatters configured for the project stack (ruff, prettier, nix-fmt, markdownlint)?
- Is there a Stop hook for session-end guidance (e.g., suggest `/harness retro` after large sessions)?
- Do all hook commands exit 0 on success **and on no-op**? Ask of every hook: "what happens when this has nothing to do?" If the answer is "it exits non-zero," it needs fixing — use `if [ cond ]; then action; fi`, never `[ cond ] && action`.

## 6. Check Tool Permissions

- Do agents have only the tools they need?
- A reviewer should not have `Write`
- A verifier should not have `Write` or `Edit`
- Test-writers need `Write` but only for test files

## 7. Check Agent Purpose (Advisor vs Enforcer)

For each agent:

- **Advisor** (reads, answers questions, guides): OK
- **Enforcer** (checks state, validates data, reports problems): should be a test or product feature
- **Compensating for missing product feature**: should be a dashboard alert, not an agent

**Gap classification:**

- Type A: Content gap in an existing skill (fix the skill)
- Type B: Skill missing entirely (add the skill)
- Type C: The builder template would not have generated this (fix the builder — double-loop)

## 8. Check Token Efficiency

- Skills reference file paths rather than inlining code?
- Any skill duplicating content from another skill? (creates drift)
- Any skill requiring full read to be useful? (violates progressive contract)
- Any skill over ~1500 tokens? (doing too much — split it)
- Is any SKILL.md over 500 lines? Split mode- or topic-specific depth into sibling reference files, exactly one level deep, and give any reference file over 100 lines a table of contents
- **Any inline bash block with logic** (conditionals, loops, pipes)? → Extract to a script in the skill's directory
- **Any inline bash duplicated across skills?** → Extract to `skills/shared/`
- **Any inline command previously fixed for wrong syntax?** → Extract to prevent recurrence

**Progressive Disclosure (scannable contract):**

- Are skills using PURPOSE ≤10 tokens (answerable without reading more)?
- Are skills using CRITICAL ≤20 tokens (non-negotiable constraints first)?
- Are skills using STANDARD PATH ≤30 lines (covers 80% of use cases)?
- Are EDGE CASES and DETAIL sections opt-in only (linked, not inlined)?
- Reference `/documentation-writer` and `/skill-writer` skills for structure guidance

## 9. Check Harness vs Implementation Health

**For domain skills:** Does a test file encode these rules as executable specs? If the harness is the only place a rule is enforced, it's in the wrong place.

**For agents:** Does the agent report conditions users should see in the product? If yes, that's a missing product feature.

## 10. Check Skill Structure (Scannable Contract)

- `## PURPOSE` line? (answerable in ≤10 tokens)
- `## CRITICAL` block? (negative constraints first)
- PURPOSE → CRITICAL → STANDARD PATH → EDGE CASES structure?
- DETAIL sections opt-in only?
- Use `/documentation-writer` and `/skill-writer` to create new skills/agents with proper structure

## Output Format

For each finding:

- **Gap/Issue**: what's missing or misaligned
- **Fix**: specific change to make
- **Priority**: high / medium / low
- **Type**: A/B/C gap classification
