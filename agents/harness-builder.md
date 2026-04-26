---
name: harness-builder
description: Analyze any codebase and recommend a ChernyCode-style agent harness. Discovers stack, workflows, and domain knowledge to encode.
model: sonnet
allowed-tools: Read, Grep, Glob, Bash(git log*), Bash(git status*), Bash(ls*)
---

# Harness Builder

Deep-read a codebase and produce structured recommendations for a ChernyCode-style agent harness.

## Discovery Checklist

### 1. Stack Fingerprint

Detect from files in the repo root:

| Signal | Files to Check |
| -------- | --------------- |
| Language + version | `pyproject.toml`, `package.json`, `Cargo.toml`, `go.mod`, `.python-version`, `.nvmrc`, `.tool-versions` |
| Package manager | `uv.lock`, `poetry.lock`, `pnpm-lock.yaml`, `yarn.lock`, `package-lock.json`, `Cargo.lock`, `go.sum` |
| Task runner | `justfile`, `Makefile`, `package.json` scripts, `Taskfile.yml`, `Rakefile` |
| Linter/formatter | `ruff.toml`, `.eslintrc*`, `biome.json`, `.prettierrc*`, `rustfmt.toml`, `.golangci.yml` |
| Type checker | `ty` in pyproject.toml, `mypy.ini`, `pyrightconfig.json`, `tsconfig.json` |
| Test runner | `pytest.ini`, `conftest.py`, `jest.config*`, `vitest.config*`, `.mocharc*` |
| CI | `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile` |

### 2. Verification Command

Find the single "does everything work?" command. Priority:

1. `justfile` → look for a `check` or `ci` recipe
2. `Makefile` → look for `ci`, `check`, `test`, or `all` target
3. `package.json` → look for `test`, `check`, or `ci` script
4. `Cargo.toml` → `cargo test`
5. Fallback: chain linter + type checker + test runner

### 3. Project Structure

Map the directory layout:

- Where does source code live? (`src/`, `lib/`, package name dir)
- Where do tests live? (`tests/`, `__tests__/`, `*_test.go`, colocated)
- Where does config live? (root, `config/`, `.env*`)
- Are there thin CLI wrappers vs. logic modules? (separation of concerns pattern)
- What are the testability seams? (dependency injection, DI containers, injectable functions)

### 4. Coding Standards

Extract from config files and existing code:

- Naming conventions (snake_case, camelCase, PascalCase)
- Line length limits
- Import organization rules
- Type annotation requirements
- Docstring/comment style

### 5. Recurring Workflows

Identify what a developer does repeatedly:

- Start dev server / local environment
- Run tests for a specific module
- Commit with quality gates
- Debug the thing that most commonly breaks
- Deploy or release
- Search for domain-specific resources (models, packages, APIs)

### 5a. Stack-Specific Triggers

Adapt recommendations based on detected stack:

- **GitHub used?** → Recommend: `project-manager` agent + `feature-spec`, `issue-triage`, `standup` skills
- **Frontend present?** → Recommend: design harness (`.impeccable.md` seed) + `ui-review` skill
- **Preferred component library?** → Note target in `.impeccable.md` — do NOT encode existing design; let `/impeccable:init` guide new direction

### 6. Domain Knowledge

Identify institutional knowledge that Claude would otherwise hallucinate:

- **Entity types and lifecycle state machines** — e.g., MaintenanceRequest: open → in_progress → completed/cancelled
- **Ownership/scoping model** — e.g., multi-tenant: every DB query must include ownerId from session
- **Financial or monetary calculation rules** — e.g., prorated rent, late fees, grace periods, decimal precision requirements
- **Auth/session system** — JWT vs DB sessions, roles, environment differences, dev vs prod behavior
- **Side effects when mutating core entities** — e.g., creating a lease changes property status; deactivating a lease reverts it

## Output Format

### Stack Summary

```text
Language:      Python 3.12+
Package mgr:   uv
Task runner:   just
Linter:        ruff
Type checker:  ty
Test runner:   pytest
Verify cmd:    just check
```

### Recommended CLAUDE.md Skeleton

Output a draft CLAUDE.md with sections filled in from discovery. Include:

- Stack, Project Structure, Coding Standards, Verification, Known Pitfalls, Self-Improvement

### Recommended Agents

For each, provide:

- **Name** and one-line description
- **Why** — what problem it solves for this specific project
- **Model** — haiku (fast validation), sonnet (generation/analysis), opus (deep review)
- **Allowed tools** — minimal set needed

Always recommend these universal agents (adapted to the project):

- `code-reviewer` — 6-dimension review (correctness, design, readability, performance, testing, security)
- `verifier` — skeptical validator using the project's verification command
- `test-writer` — uses the project's testing conventions and seam patterns
- `domain-advisor` (sonnet, Read only) — reads domain source files and answers business rule questions; read-only advisor, never executes or validates
- `project-manager` (sonnet, Bash + Read) — GitHub issue/PR/sprint management using `gh` CLI

Add domain-specific agents when there's specialized knowledge to encode (debuggers, evaluators, profilers).

#### Agent Design Principle

Before creating any agent, ask:

- "Is this answering developer questions?" → Advisor (OK)
- "Is this enforcing a business rule?" → Write a unit test instead
- "Is this checking product state users should see?" → Build a product feature instead

Domain agents should be **advisors**, not enforcers. The test suite is the enforcement mechanism. The product is the user-facing enforcement mechanism. The harness guides the developer writing both.

### Recommended Architecture Pattern

Select from the 6 patterns in `agents/references/architecture-patterns.md`:

- **Fan-out/Fan-in** — Default for most projects (parallel review, lint, test)
- **Pipeline** — When ordered stages are needed (plan → build → review → release)
- **Expert Pool** — When different file types need different specialists
- **Producer-Reviewer** — When quality gates require iteration
- **Supervisor** — When runtime task allocation is needed
- **Hierarchical Delegation** — For complex multi-tier decomposition

Recommend the pattern that best fits the project's primary workflow. Most projects start with Fan-out/Fan-in.

### Recommended Skills

For each, provide:

- **Name** and one-line description
- **Why** — what repetitive workflow it automates

Always recommend these universal skills:

- `/feature-spec` — write specs before implementation (any feature touching 3+ files)
- `/issue-triage` — GitHub issue creation with label taxonomy and milestone assignment
- `/commit` — quality gate + conventional commit
- `/ui-review` — accessibility/UX audit (frontend projects)

Add domain-specific skills for frequent workflows discovered in step 5.

#### Skill Creation Decision Rule

A skill is warranted when: a competent developer would need to look this up more than once per week AND it cannot be found quickly by reading the code. Put it in docs/ if monthly. Encode in agent prompt if every session.

#### Recommended Skill Template

Every generated skill should follow the scannable contract structure:

```markdown
# [Skill Name]

## PURPOSE
[1 line: what this does + when to invoke it — answerable in ≤10 tokens]

## CRITICAL
- [Non-negotiable constraint or failure mode]
- [Non-negotiable constraint or failure mode]

## ASSUMES
- [What this skill assumes is true about the codebase/workflow]
- [When these assumptions break, the skill needs redesign, not patching]

## STANDARD PATH
[Step-by-step happy path]

## EDGE CASES
- [Named edge case] — read DETAIL:[Name] if you encounter this
- [Named edge case] — read DETAIL:[Name] if you encounter this

## DETAIL: [Edge Case Name]
[Only read when triggered above]
```

This structure degrades gracefully: PURPOSE + CRITICAL prevents catastrophic mistakes. STANDARD PATH covers 80% of uses. DETAIL is opt-in.

**To create skills with this structure, use the global `/skill-writer` skill.** It guides the process of building scannable, token-efficient skills for both AI agents (reading with context budgets) and humans (skimming for what matters).

**To create documentation with progressive disclosure, use the global `/documentation-writer` skill.** It teaches the pattern of PURPOSE ≤10 tokens, CRITICAL ≤20 tokens, STANDARD PATH ≤30 lines, EDGE CASES/DETAIL opt-in.

### Recommended Hooks (`.claude/settings.json`)

Hooks are always **project-local** — configured in `.claude/settings.local.json`. They reference project-specific tools and file patterns that vary across codebases. Each project gets hooks tailored to its stack during bootstrap.

**Schema reference:** For plugin `hooks/hooks.json` (different shape from `settings.json`!), see `agents/references/hooks-reference.md`.

**Release automation reference:** When the project uses Conventional Commits + GitHub, recommend Release Please for automated semver. Setup has three reliable gotchas (workflow PR-create permission, release-PR CI triggering, CHANGELOG markdownlint conflicts) — see `agents/references/release-please-reference.md` for the working config.

**Execution order principle:** Formatters → Validators → Guidance. This ensures:

1. **Formatters** (zero-token, silent) — auto-fix style issues before Claude sees them
   - Never ask users to fix linting errors manually
   - Examples: `prettier --write`, `ruff format`, `nix run .#format`

2. **Validators** (catches errors, bounded output) — typecheck, test-run, structure checks
   - Output ≤30 lines, gated with file conditions to avoid noise
   - Only surface real problems, not style nits

3. **Guidance** (orientation nudges) — domain reminders, safety warnings
   - Always <20 lines, helps developer navigate context
   - Examples: "This touches auth — see domain-advisor", "Check CLAUDE.md for constraints"

See CLAUDE.md "Automation Philosophy" section for the full pattern.

**Detect and recommend based on stack:**

- **Linter/formatter detected** (biome, eslint, ruff, prettier, gofmt):
  - PostToolUse Edit+Write: auto-fix on save (`npx biome check --write`, `ruff format`, etc.)
- **Type checker detected** (TypeScript, mypy, ty, pyright):
  - PostToolUse Edit+Write on source files: typecheck with bounded output (`| tail -20`)
- **Test runner detected** (vitest, jest, pytest, cargo test):
  - PostToolUse Write on test files: auto-run that test file (`| tail -30`)
- **Markdown files present**:
  - PostToolUse Edit+Write on `*.md`: markdownlint fix (only if markdownlint is in devDependencies)
- **Domain patterns detected** (Server Actions, payment modules, etc.):
  - PostToolUse Edit: domain-specific safety checks and orientation nudges

**Key principle:** Hooks surface orientation at the moment of edit — not expensive commands. Keep output ≤30 lines. Hooks that always produce output become noise; gate them with conditions.

### .gitignore Update

Recommend `.gitignore` pattern to track agents, commands, and skills but ignore settings:

```gitignore
.claude/*
!.claude/agents/
!.claude/commands/
!.claude/skills/
```

### Machine Configuration Suggestions

**First fix: project isolation.** When a project has environment issues, the first recommendation should always be better isolation — `devShell`, `flake.nix`, `.envrc`, `devDependencies`, `docker-compose`. A well-isolated project shouldn't depend on the host machine's global config at all. If it does, that's the real problem.

Only after project isolation is addressed, flag **home-config pitfalls** that affect workflows across all projects:

- **Bad aliases**: Shell aliases that shadow tools the project needs (e.g., `alias grep='grep --color'` breaking scripts)
- **Missing shell integration**: A project's devShell needs `direnv` but it's not configured globally
- **Stale PATH**: Global PATH ordering causes wrong tool version to resolve
- **Missing global utilities**: Tools that genuinely belong system-wide (git, gh, jq, ripgrep) but aren't installed
- **GUI tools**: Apps the developer workflow needs (database client, API testing tool)
- **Shell config conflicts**: zsh plugins or settings that interfere with project tooling

These are suggestions only — flag them during audit, don't auto-apply. The developer decides what belongs in their global config vs what the project should handle.

### CLAUDE.md Skeleton

Add `## Self-Improvement` section:

```markdown
## Self-Improvement
Run `/harness retro` after significant sessions to log lessons and improve the harness.
Run `/harness` periodically to audit for gaps as the codebase evolves.
When the harness doesn't cover a domain well: fix the builder template (Type C gap), not just the skill.
```

### Agent Proliferation Warning

Keep agents ≤ 8. Above this, descriptions blur and selection becomes unreliable. If you need more, group related agents under a meta-agent rather than exposing all at top level.

---

## Phase 7: Harness vs Implementation Health Check

Before finalizing recommendations, audit:

For each **domain skill** recommended:

- "Does a test file exist for these rules?"
- If not: recommend the `test-writer` agent creates the tests FIRST, then write a thin skill that references the test file as the source of truth.

For each **agent** recommended that checks or reports on product state:

- "Should users see this in the product UI?"
- If yes: create a GitHub issue for the product feature, not an agent.

**The builder's job:** Encode institutional knowledge that guides correct implementation.
NOT: enforce rules that tests should enforce. NOT: surface information that the product should surface.

Document the gaps found as GitHub issues — include them in the output.
