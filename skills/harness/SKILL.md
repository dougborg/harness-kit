---
name: harness
description: Self-improving meta-harness for auditing, bootstrapping, and improving agent harnesses
allowed-tools: Bash(ls*), Bash(grep*), Bash(git*), Bash(${CLAUDE_PLUGIN_ROOT}/skills/shared/discover-verification-cmd.sh*), Read, Glob, Write, Edit
---

# /harness — Self-Improving Meta-Harness

Unified command for harness management. Auto-detects mode or use subcommands to audit, bootstrap, retro, or hoist agent harnesses.

## PURPOSE

Establish quality gates on agent harnesses — skills, agents, hooks, and documentation — to catch gaps and inconsistencies before they affect productivity.

## CRITICAL

- **Never ship a skill without /harness audit passing** — Audit gates on PURPOSE/CRITICAL/STANDARD PATH structure and tool correctness
- **Audit gates prevent silent failures** — Missing agents, duplicate skills, broken hooks, wrong models — audit finds them
- **Harness quality === agent quality** — Skills teach and guide; if skills are poorly structured or out-of-date, agents will follow bad patterns

## ASSUMES

- You have `.claude/` directory with agents, skills, or both (or you're bootstrapping a new project)
- You can run the verification command for your project stack (cargo test, npm test, nix flake check, etc.)
- The harness-kit plugin is installed (provides base skills/agents and this `/harness` skill)
- `.harness-lock.json` tracks which files came from upstream vs project-local

## STANDARD PATH

Auto-detect and run the appropriate mode:

```bash
/harness              # Auto-detect: bootstrap if no harness, audit if exists
/harness audit        # Run 10-step audit on current harness
/harness bootstrap    # Analyze project, install skills/agents from plugin, generate project-specific additions
/harness update       # Pull latest from upstream sources, smart-merge with local changes
/harness add <repo>   # Add skills from another plugin marketplace
/harness retro        # Post-session retrospective
/harness hoist        # Propose upstream PR for generic improvements
```

If no `.claude/` → runs `bootstrap` (generates harness). If `.claude/` exists → runs `audit` (validates quality).

## EDGE CASES

- [Auditing existing harness] — Read DETAIL: Audit Mode (10-step protocol)
- [Setting up new project] — Read DETAIL: Bootstrap Mode (scaffolding workflow)
- [Syncing with upstream] — Read DETAIL: Update Mode (pull latest, smart-merge)
- [Adding external skills] — Read DETAIL: Add Mode (multi-source skill installation)
- [Session reflection] — Read DETAIL: Retro Mode (identify gaps and improvements)
- [Sharing generic tools] — Read DETAIL: Hoist Mode (propose upstream improvements)
- [Design guidance] — Read DETAIL: Design Principles (patterns for skill/agent design)
- [Hook exits non-zero on no-op] — Read DETAIL: Hook Exit Code Safety

---

## DETAIL: Audit Mode

Run the 10-step audit protocol on the current project's harness. **Default mode when `.claude/` exists.**

### 1. Detect Project Stack

Find the verification command for this project:

- Check `justfile` for `check` or `ci` recipe
- Check `Makefile` for `ci`, `check`, or `test` target
- Check `package.json` for `test` or `check` script
- Check `Cargo.toml` → `cargo test`
- Check `flake.nix` → `nix flake check`

### 2. Read All Harness Content

- List and read every file in `.claude/agents/` and `.claude/skills/`
- Check for legacy `.claude/commands/` directory — flag for migration to skills
- Check `CLAUDE.md` for harness documentation

### 3. Check Alignment

- Do agent instructions reference the correct verification command?
- Do tool references match what's actually installed?
- Do agents reference correct paths and conventions from CLAUDE.md?
- Is CLAUDE.md present and does it document all agents and skills?

### 4. Check Model Tiering

- `haiku` for fast validation tasks (verifier)
- `sonnet` for generation and analysis (code-reviewer, test-writer)
- `opus` only for deep architectural decisions
- Flag any mismatch

### 5. Check Gaps

ChernyCode principle: "If you do something more than once a day, make it a skill."

**Universal agents (should exist in every project):**

- Is there a `code-reviewer` agent? (6-dimension review)
- Is there a `verifier` agent? (skeptical validator)
- Is there a `test-writer` agent? (project testing conventions)
- Is there a `domain-advisor` agent? (read-only, answers business rules)

**Stack-dependent:**

- If GitHub is used: `project-manager` agent? + `/feature-spec`, `/issue-triage`, `/standup` skills?
- If frontend present: design harness (`.impeccable.md`) + `/ui-review` skill?

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
- Do all hook commands exit 0 on success AND on no-op? (see DETAIL: Hook Exit Code Safety)

### 6. Check Tool Permissions

- Do agents have only the tools they need?
- A reviewer should not have `Write`
- A verifier should not have `Write` or `Edit`
- Test-writers need `Write` but only for test files

### 7. Check Agent Purpose (Advisor vs Enforcer)

For each agent:

- **Advisor** (reads, answers questions, guides): OK
- **Enforcer** (checks state, validates data, reports problems): should be a test or product feature
- **Compensating for missing product feature**: should be a dashboard alert, not an agent

**Gap classification:**

- Type A: Content gap in an existing skill (fix the skill)
- Type B: Skill missing entirely (add the skill)
- Type C: The builder template would not have generated this (fix the builder — double-loop)

### 8. Check Token Efficiency

- Skills reference file paths rather than inlining code?
- Any skill duplicating content from another skill? (creates drift)
- Any skill requiring full read to be useful? (violates progressive contract)
- Any skill over ~1500 tokens? (doing too much — split it)
- **Any inline bash block with logic** (conditionals, loops, pipes)? → Extract to a script in the skill's directory
- **Any inline bash duplicated across skills?** → Extract to `skills/shared/`
- **Any inline command previously fixed for wrong syntax?** → Extract to prevent recurrence

**Progressive Disclosure (scannable contract):**

- Are skills using PURPOSE ≤10 tokens (answerable without reading more)?
- Are skills using CRITICAL ≤20 tokens (non-negotiable constraints first)?
- Are skills using STANDARD PATH ≤30 lines (covers 80% of use cases)?
- Are EDGE CASES and DETAIL sections opt-in only (linked, not inlined)?
- Reference `/documentation-writer` and `/skill-writer` skills for structure guidance

### 9. Check Harness vs Implementation Health

**For domain skills:** Does a test file encode these rules as executable specs? If the harness is the only place a rule is enforced, it's in the wrong place.

**For agents:** Does the agent report conditions users should see in the product? If yes, that's a missing product feature.

### 10. Check Skill Structure (Scannable Contract)

- `## PURPOSE` line? (answerable in ≤10 tokens)
- `## CRITICAL` block? (negative constraints first)
- PURPOSE → CRITICAL → STANDARD PATH → EDGE CASES structure?
- DETAIL sections opt-in only?
- Use `/documentation-writer` and `/skill-writer` to create new skills/agents with proper structure

### Output Format

For each finding:

- **Gap/Issue**: what's missing or misaligned
- **Fix**: specific change to make
- **Priority**: high / medium / low
- **Type**: A/B/C gap classification

---

## DETAIL: Bootstrap Mode

Analyze the project, install skills/agents from the harness-kit plugin, and generate project-specific additions. **Auto-triggers when `.claude/` directory doesn't exist or is empty.**

### Workflow

1. **Spawn `harness-builder` agent** — It analyzes the codebase and returns:
   - Stack summary (language, toolchain, verification command)
   - Draft CLAUDE.md skeleton
   - **Recommended architecture pattern** (from `agents/references/architecture-patterns.md`)
   - **Recommended agents** with model + allowed-tools (always includes code-reviewer, verifier, test-writer, domain-advisor; adds project-manager if GitHub detected)
   - **Recommended skills from harness-kit:** which of the plugin's base skills to copy into the project
   - **Recommended external sources:** additional plugin marketplaces based on stack (e.g., Vercel skills for React, impeccable for frontend)
   - **Project-specific skills** to generate (domain workflows, custom checks)
   - Recommended hooks (PostToolUse: formatters → validators → guidance; Stop: session-end guidance)
   - Domain knowledge (entity types, ownership model, business rules)

2. **Present recommendations for approval:**
   - **Stack:** one-line summary + architecture pattern
   - **Skills from harness-kit to install:** table with name, purpose, why this project needs it
   - **External sources to add:** marketplace repos with rationale
   - **Project-specific skills to generate:** table with name, purpose
   - **Agents to create:** table with name, purpose, model
   - **Domain knowledge:** institutional rules the harness should encode
   - **Hooks to configure:** execution order and commands

3. **Do NOT write any files until the user approves.**

4. **After approval, install and generate:**
   - Copy approved skills from `${CLAUDE_PLUGIN_ROOT}/skills/` to `.claude/skills/`
   - Copy approved agents from `${CLAUDE_PLUGIN_ROOT}/agents/` to `.claude/agents/`
   - Copy `skills/shared/` scripts to `.claude/skills/shared/`
   - Rewrite `${CLAUDE_PLUGIN_ROOT}` references to `.claude` in copied files
   - Generate project-specific agents (domain-advisor, etc.) in `.claude/agents/`
   - Generate project-specific skills in `.claude/skills/`
   - Write `CLAUDE.md` with all sections filled in
   - Configure hooks in `.claude/settings.local.json`
   - Create `.harness-lock.json` tracking provenance of every installed file
   - Write `.claude/harness-upstream` (one line: `owner/repo`) so `/harness-issue` knows where to file feedback. Use the source repo from the lock file (default `dougborg/harness-kit`).
   - Update `.gitignore` (add `.claude/settings.local.json` if it contains secrets)
   - Never generate `.claude/commands/` — commands are legacy

5. **Run verification command** to confirm nothing broke.

### Lock File Creation

The `.harness-lock.json` file is created during bootstrap and tracks every file's provenance:

```json
{
  "sources": {
    "harness-kit": { "version": "0.1.0", "installed": "2026-04-04", "repo": "dougborg/harness-kit" }
  },
  "files": {
    ".claude/skills/commit/SKILL.md": { "source": "harness-kit", "modified": false },
    ".claude/agents/code-reviewer.md": { "source": "harness-kit", "modified": false },
    ".claude/agents/domain-advisor.md": { "source": "local" }
  }
}
```

The `repo` field on each source records the GitHub upstream so `/harness-issue` and `/harness hoist` can route feedback and proposed changes to the right place. Omit `repo` for purely local sources.

This file should be committed — it lets teammates run `/harness update` to sync.

### Agent Recommendations

- **Always include:** `code-reviewer` (6D review), `verifier` (validation), `test-writer` (testing), `domain-advisor` (read-only business rules)
- **If GitHub:** Add `project-manager` (issue/PR/sprint management via `gh` CLI)
- **If frontend:** Add `/ui-review` skill for accessibility audits

---

## DETAIL: Update Mode

Pull latest changes from upstream sources and smart-merge with local modifications. **Run after the harness-kit plugin is updated.**

### Steps

1. **Read `.harness-lock.json`** — Get current source versions and file provenance.

2. **Check for upstream updates:**
   - Compare plugin version (`${CLAUDE_PLUGIN_ROOT}` has the latest) vs lock file version
   - List files that differ between plugin and project `.claude/`

3. **For each upstream file:**
   - `modified: false` → **Overwrite** with latest from plugin. Silent.
   - `modified: true` → **Show diff** between upstream and local. Ask user:
     - Accept upstream (overwrite local changes)
     - Keep local (skip this file)
     - Merge manually (show both versions)
   - `source: "local"` → **Never touch**. These are project-specific.

4. **Check for new upstream files** — Files in the plugin that aren't in the lock file yet. Offer to install them.

5. **Update `.harness-lock.json`** — New version, updated timestamps, modified flags.

6. **Show changelog** — Summary of what was updated, what was skipped, what's new.

---

## DETAIL: Add Mode

Add skills from another plugin marketplace into the project's `.claude/`.

### Add procedure

```bash
/harness add vercel-labs/agent-skills
```

1. **Check if marketplace is already added:**

   ```bash
   claude plugin marketplace list
   ```

   If not, instruct user: `/plugin marketplace add vercel-labs/agent-skills`

2. **Browse available skills** from the marketplace.

3. **User selects** which skills to install into `.claude/`.

4. **Copy selected skills** to `.claude/skills/`.

5. **Update `.harness-lock.json`** with new source and file entries.

6. **Run verification command** to confirm nothing broke.

---

## DETAIL: Retro Mode

Post-session retrospective to identify gaps and improvements in the harness. **Run after significant sessions to capture learnings.**

### Retro procedure

1. **Analyze recent changes:**

   ```bash
   git log --since="8 hours ago" --oneline
   ```

   What domains were touched? What changed?

2. **Reflect on skill usage:**
   - Which skills/agents were used?
   - Which were needed but missing?
   - Which gave wrong or outdated guidance?

3. **Identify gaps and classify:**
   - Type A: Existing skill needs content update (fix the local skill, mark as modified in lock file)
   - Type B: New skill needed (create in `.claude/skills/`, add to lock as `source: "local"`)
   - Type C: Builder template would not have generated this correctly → fix the upstream harness (most valuable — prevents the gap in every future project)
   - Type D: Lightweight pattern — a learned heuristic that doesn't warrant a full skill (store in memory or `.claude/patterns/`)

   **Promotion heuristic:** Before classifying as Type D, ask: *would this prevent the same mistake in another project, or for another agent?* If yes, escalate to A/B/C — encode it in a skill, not memory. Memories are session/user-scoped and fade; skills persist and ship to every consumer of the harness. Type D is for pattern learnings genuinely scoped to *this* project's quirks.

4. **Propose 1-3 improvements** as specific, actionable changes.

5. **Promotion pass — what belongs upstream?** For *every* finding (not just Type C), ask: would this prevent the same problem in another harness-kit consumer? If yes, mark it as upstream-worthy. Common cases:
   - Type C — by definition belongs upstream
   - Type A on a file sourced from upstream (per `.harness-lock.json`) — the upstream skill is wrong, not just your local copy
   - Type B that's generic — a new skill that has nothing project-specific in it should be proposed upstream as a new skill, not kept local
   - Type D — patterns rarely belong upstream; keep local unless the pattern is genuinely cross-project

6. **Surface upstream candidates and confirm with the user before filing.** Show each upstream-worthy finding and ask per item: file as Issue, open as PR, hoist a local fix, or skip. Then act:
   - **Issue / PR** → invoke `/harness-issue` (configurable upstream; defaults to harness-kit)
   - **Hoist local fix** → invoke `/harness hoist` for cases where you already have a working local diff to propose back
   - **Skip / keep local** → no upstream action; leave a note in the retro summary so it's not forgotten next session

7. **For Type D patterns:** Save as a brief markdown note. Patterns are lighter than skills — they capture heuristics like "in this codebase, always check X before Y" or "this API returns 404 for deleted resources, not 410." Store in memory files or a `.claude/patterns/` directory.

---

## DETAIL: Hoist Mode

Propose improvements to the upstream harness-kit plugin (or other upstream sources) when a project-local skill improvement is generic enough to benefit all projects.

### Hoist procedure

1. **Read the lock file** — `.harness-lock.json` tells you which files came from which upstream source and whether they've been modified.

2. **Inventory project harness** — Read every file in project `.claude/agents/` and `.claude/skills/`.

3. **For each modified or local file, ask:**
   - Is this improvement generic (no domain entities, no project paths)?
   - If yes: which upstream source should it go to? (check lock file provenance)
   - If partially generic: extract the generic improvement, keep project-specific parts local

4. **Classify** each candidate:
   - **Modified upstream file**: The improvement should be proposed as a PR to the upstream repo
   - **New generic skill**: Should be proposed as an addition to the upstream repo
   - **Partially generic**: Extract generic principles into a PR, keep domain parts local
   - **Project-specific**: Stays local, no hoist needed

5. **Propose changes** (prefer fewer, better upstream skills over more):
   - PRs to existing upstream skills (merge useful patterns)
   - New upstream skills only when nothing existing covers the area
   - Project-local files to simplify after upstream accepts the improvement

6. **After approval**: Clone the upstream repo, create a branch, apply changes, open a PR via `gh`.

### Principles

- The upstream harness grows by getting *better*, not *bigger*. Prefer improving existing skills over adding new ones.
- A mature harness is smaller than a young one — upstream AND in projects.
- After hoisting, actively recommend simplifying project-local skills now covered by the improved upstream. Fewer files = less drift.
- **Composition over duplication**: Project-local skills extend upstream skills with project-specific flavor. The upstream skill defines the protocol; the local skill adds domain checks and context.

---

## DETAIL: Design Principles

When designing or reviewing harness skills and agents, follow these principles:

### Skills Over Commands

Commands are legacy in Claude Code — skills supersede them. Always use skills.

- Skills support user-level scope and plugin distribution; commands do not
- Skills support subdirectories with supporting files; commands are single flat files
- Skills have richer frontmatter (`context: fork`, `user-invocable`, etc.)
- If a skill and command share the same name, the skill takes precedence

**Plugin distribution:** Skills and agents are distributed via the harness-kit plugin. `/harness bootstrap` copies them into the project's `.claude/` directory so they're committed and portable.

**Project-local extension pattern:** When a project needs to customize an upstream skill, modify the local copy and mark it as `modified: true` in `.harness-lock.json`. `/harness update` will warn before overwriting modified files.

### Scripts Over Inline Bash

**Inline bash in skills is a smell.** It costs tokens on every invocation, drifts between skills, and is untestable. Extract it into scripts.

- Scripts go in the skill's directory (alongside SKILL.md) or `skills/shared/` for cross-skill use
- **Extract if:** block has conditionals, loops, pipes, arithmetic, multi-step sequences, or error-prone syntax
- **Leave inline if:** single straightforward command (e.g., `git status`, `nix flake check`)
- When fixing a bug in inline bash, always extract to a script rather than patching in place
- Add scripts to the skill's `allowed-tools` frontmatter: `Bash(${CLAUDE_PLUGIN_ROOT}/skills/shared/script.sh*)`

### User Prompts: Only Ask When Necessary

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

### Composition Over Duplication

When a global skill already exists, project-local versions should:

- Extend with project-specific flavor (domain context, custom checks)
- Reference the global skill for the core protocol
- Add value, don't reimplement

Example: `/commit` (upstream) handles conventional format; project-local `/commit` adds project-specific quality gates (e.g., `nix flake check`, `cargo clippy`, `npm run lint`).

### Prerequisite Automation

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

### Automation-First Hooks

**Principle:** Don't ask users to do things we can automate.

**Schema reference:** For the correct shape of plugin `hooks/hooks.json` (including the common plugin-vs-settings.json gotcha), see `agents/references/hooks-reference.md`. Validate locally with `just validate-hooks`.

#### PostToolUse Hooks

Configure in `.claude/settings.local.json` to auto-fix on every file edit:

1. **Formatters** (stage 1) — Silent, zero-token cost
   - Run formatters auto-fix before Claude sees edited files
   - Examples: `nix run ".#format"`, `prettier --write`, `ruff check --fix`
   - Never ask users to fix linting errors manually

2. **Validators** (stage 2) — Bounded output (≤30 lines), gated with conditions
   - Check for errors after formatting
   - Examples: `nix flake check`, `type checking`, `test running`
   - Only show real problems, not noise
   - Use conditions to surface only relevant checks

3. **Guidance** (stage 3) — Context reminders (≤20 lines)
   - Orient developers with skill/doc references
   - Examples: "Check CLAUDE.md for domain constraints", "This touches auth — see domain-advisor"
   - Always helpful, never noisy

#### Stop Hooks

Configure session-end hooks for retrospective nudges:

```json
"Stop": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "changed=$( { git diff --name-only 2>/dev/null; git diff --name-only --cached 2>/dev/null; git log --diff-filter=ACMR --name-only --pretty=format: --since='4 hours ago' 2>/dev/null; } | sort -u | wc -l | tr -d ' '); if [ \"$changed\" -gt 3 ]; then echo \"💡 Session touched $changed files — consider /harness retro to capture learnings\"; fi"
      }
    ]
  }
]
```

**Purpose:** After large sessions (>3 files changed), remind the user to run `/harness retro` to capture learnings before context is lost. Counts unstaged, staged, and recently committed files to capture the full session scope.

**Exit code safety:** See DETAIL: Hook Exit Code Safety — all hooks must exit 0 on both success and no-op.

**Note:** This hook is provided by the harness-kit plugin. Projects only need to override it in `.claude/settings.local.json` if they want different behavior.

#### Why This Matters

- Formatters fix before Claude reads → zero tokens, no suggestion waste
- Tests and linters enforce rules; harness provides guidance
- Stop hooks capture learnings that would otherwise be lost between sessions
- Users only see real problems and useful guidance, never pedantic style issues

Use `/documentation-writer` and `/skill-writer` to create well-structured docs that scale context-efficiently. Update CLAUDE.md with "Automation Philosophy" section documenting this approach.

---

## Self-Corrective Improvement

When you encounter a behavioral gap during any session (not just harness work):

1. **Fix the immediate issue** in the current task
2. **Determine scope** — upstream (generic workflow, benefits all projects) or project-local (domain-specific)?
3. **Spawn a background subagent** to make the fix while you continue working:

**Upstream fix** — clone the harness-kit repo (or other upstream source), fix, and open a PR:

```text
Agent(
  description: "fix harness gap: [brief description]",
  run_in_background: true,
  prompt: "Fix [gap] in harness-kit.
    1. git clone --depth 1 https://github.com/dougborg/harness-kit /tmp/harness-fix
    2. cd /tmp/harness-fix && git checkout -b fix/[name]
    3. Fix skills/[skill]/SKILL.md or agents/[agent].md. If fixing inline bash,
       extract to a script instead of patching in place.
    4. Commit, push, open PR with gh
    5. Clean up: rm -rf /tmp/harness-fix"
)
```

**Project-local fix** — fix `.claude/{skills,agents}/` directly in the current repo, commit normally. Mark the file as `modified: true` in `.harness-lock.json`.

**Continue working** — the upstream PR will be reviewed and merged separately. After merge, `/harness update` will pull the fix into all projects.

Behavioral gaps get encoded in skills via PRs, not memories. Memories fade; skills persist. Inline bash gets extracted into scripts.

---

## DETAIL: Hook Exit Code Safety

Claude Code treats any non-zero exit code from a hook as a failure. This is a common pitfall with conditional hooks — the command works correctly but reports an error.

**The problem:**

```bash
# BAD: exits 1 when condition is false ([ ] returns 1, && short-circuits)
[ "$changed" -gt 3 ] && echo "message"
```

**The fix — use `if/then/fi`:**

```bash
# GOOD: if/then/fi always exits 0 when condition is false
if [ "$changed" -gt 3 ]; then echo "message"; fi
```

**Alternative — append `|| true`:**

```bash
# OK: forces exit 0, but less readable
[ "$changed" -gt 3 ] && echo "message" || true
```

**Audit rule:** For every hook command, ask: "What happens when this has nothing to do?" If the answer is "it exits non-zero," it needs fixing.

**Common patterns that silently fail:**

| Pattern | Problem | Fix |
| --- | --- | --- |
| `[ test ] && action` | Exit 1 when test is false | `if [ test ]; then action; fi` |
| `grep pattern file` | Exit 1 when no match | `grep pattern file \|\| true` |
| `command \| head -1` | Exit 141 (SIGPIPE) on some systems | Pipe to `head -1 \|\| true` |

---

## Andon Cord Pattern

Any time during a session, flag a suspect skill:

```markdown
> ⚠️ FLAGGED: [brief reason this guidance may be outdated or wrong]
```

Lightweight in-flight signal that feeds the next audit. Don't stop work — just flag it.

---

## RELATED

- `harness-builder` agent — Used by bootstrap mode to analyze codebases and recommend harness setup
- `/documentation-writer` — Write scannable, progressive-disclosure docs
- `/skill-writer` — Create well-structured skills with PURPOSE/CRITICAL/STANDARD PATH
