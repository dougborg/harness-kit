# Design Principles

Patterns to follow when designing or reviewing harness skills and agents.

## Contents

- [Skills Over Commands](#skills-over-commands)
- [Progressive Disclosure and File Size](#progressive-disclosure-and-file-size)
- [Scripts Over Inline Bash](#scripts-over-inline-bash)
- [User Prompts: Only Ask When Necessary](#user-prompts-only-ask-when-necessary)
- [Composition Over Duplication](#composition-over-duplication)
- [Prerequisite Automation](#prerequisite-automation)

## Skills Over Commands

Commands are legacy in Claude Code — skills supersede them. Always use skills.

- Skills support user-level scope and plugin distribution; commands do not
- Skills support subdirectories with supporting files; commands are single flat files
- Skills have richer frontmatter (`context: fork`, `user-invocable`, etc.)
- If a skill and command share the same name, the skill takes precedence

**Plugin distribution:** Skills and agents are distributed via the harness-kit plugin. `/harness bootstrap` copies them into the project's `.claude/` directory so they're committed and portable.

**Project-local extension pattern:** When a project needs to customize an upstream skill, modify the local copy and mark it as `modified: true` in `.harness-lock.json`. `/harness update` will warn before overwriting modified files.

## Progressive Disclosure and File Size

Skill content stays in context for the whole session once loaded, and after compaction only the first slice of each skill is re-attached. Size is a correctness concern, not just tidiness.

- **Keep SKILL.md under 500 lines.** Past that, split topic- or mode-specific depth into sibling reference files in the skill's own directory.
- **References are exactly one level deep.** Every reference file must be linked directly from SKILL.md. A reference file that links to another reference file is a bug — Claude previews unfamiliar files with `head -100` and will act on incomplete information.
- **Any reference file over 100 lines needs a table of contents** at the top, so a partial read still reveals the file's full scope.
- SKILL.md keeps the routing plus anything that applies across modes; each reference file must stand alone for its own job.
- When two reference files need the same rule, restate the one-line version in both rather than cross-linking them.

## Scripts Over Inline Bash

**Inline bash in skills is a smell.** It costs tokens on every invocation, drifts between skills, and is untestable. Extract it into scripts.

- Scripts go in the skill's directory (alongside SKILL.md); cross-skill scripts are canonical in `skills/shared/` and reached from each consumer through a relative symlink (`ln -s ../shared/script.sh skills/<skill>/script.sh`), so every reference is `${CLAUDE_SKILL_DIR}/script.sh`
- **Extract if:** block has conditionals, loops, pipes, arithmetic, multi-step sequences, or error-prone syntax
- **Leave inline if:** single straightforward command (e.g., `git status`, `nix flake check`)
- When fixing a bug in inline bash, always extract to a script rather than patching in place
- Add scripts to the skill's `allowed-tools` frontmatter: `Bash(${CLAUDE_SKILL_DIR}/script.sh*)`

## User Prompts: Only Ask When Necessary

**Never ask users to do things you can do yourself.**

Skills should minimize user interaction. Only ask for:

- **Destructive confirmations** — Operations that can't be undone (deletes, force pushes, system changes)
- **Critical decisions** — Mutually exclusive choices with real trade-offs
- **Secrets/auth** — Information only the user has (credentials, API keys)

**Auto-execute safe operations:**

- Run prerequisite checks and steps automatically (e.g., `/switch` runs `/pre-flight` without asking)
- Gather information yourself (git status, file contents, harness state)
- Provide discoveries and options; confirm only on destructive actions

**Example:**

```text
❌ Bad: "Have you staged your changes? (yes/no)"
✅ Good: [auto-check git status, report findings, only ask if deploy needed]

❌ Bad: "Should I run validation? (yes/no)"
✅ Good: [run validation, report results, only ask if issues found]

✅ OK to ask: "This will force-push main. Confirm? (yes/no)" [truly destructive]
```

## Composition Over Duplication

When a global skill already exists, project-local versions should:

- Extend with project-specific flavor (domain context, custom checks)
- Reference the global skill for the core protocol
- Add value, don't reimplement

Example: `/commit` (upstream) handles conventional format; project-local `/commit` adds project-specific quality gates (e.g., `nix flake check`, `cargo clippy`, `npm run lint`).

## Prerequisite Automation

If a skill has prerequisites (e.g., `/switch` requires `/pre-flight`):

1. **Check if already done** — Look for artifacts, state signals
2. **Do it yourself** — Auto-run if needed
3. **Only ask** if impossible to verify or execute

Never:

```text
❌ "Have you run /pre-flight? (yes/no)"
```

Instead:

```text
✅ Check git status → if clean and validated, proceed
✅ If not validated, run /pre-flight automatically → then proceed
```
