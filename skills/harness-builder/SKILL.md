---
name: harness-builder
description: Analyze codebase and recommend AI agent harness (agents, skills, hooks)
allowed-tools: Read, Grep, Glob, Bash(git log*), Bash(git status*), Bash(ls*)
---

# /harness-builder — Recommend Agent Harness

Bootstrap an AI agent harness for any codebase. The harness-builder agent analyzes your stack, workflows, and domain to recommend agents, skills, and automation hooks.

## PURPOSE

Get a tailored harness recommendation (agents, skills, hooks, CLAUDE.md skeleton) without starting from scratch.

## CRITICAL

- **Use early in project setup** — Recommendations are starting points, not gospel. Refine based on your actual needs.
- **Recommendations are templates** — You will customize CLAUDE.md, agents, and skills after generation. This is expected.
- **Global skills save work** — The agent recommends using existing global skills (like `/commit`, `/review-pr`) rather than generating new ones. Extend these with project-specific variants.

## ASSUMES

- You're in a project directory with a git repo (harness-builder needs to analyze history)
- You have a verification command available (test suite, linter, build command)
- You're willing to review and customize recommendations before finalizing

## STANDARD PATH

### 1. Invoke harness-builder

```bash
/harness bootstrap       # Triggers harness-builder agent automatically
```text

Or manually:

```bash
[Invoke harness-builder agent on current codebase]
```text

### 2. Review Recommendations

The agent returns:

- **Stack**: Language, frameworks, verification command
- **Agents**: What analytical tasks to automate (always: code-reviewer, verifier, test-writer, domain-advisor)
- **Skills**: What workflows to provide (always: /commit; plus GitHub/frontend tools if detected)
- **Hooks**: Formatters, validators, guidance for auto-fixing
- **Domain knowledge**: Entity types, ownership, auth/session system, mutation side effects

### 3. Customize for Your Context

Adjust recommendations:

- Remove agents/skills you don't need
- Add project-specific agents or constraints
- Update CLAUDE.md with actual domain rules (not boilerplate)

### 4. Generate Files

After approval, agent generates:

- `.claude/agents/*.md` (one per agent, with tool permissions and domain context)
- `.claude/skills/*/SKILL.md` (one per skill, with PURPOSE/CRITICAL/STANDARD PATH)
- `CLAUDE.md` (harness documentation)
- `.gitignore` updates

### 5. Validate

Run verification command to confirm setup works:

```bash
git add . && nix flake check   # Or your stack's validation
```text

## EDGE CASES

- [Interpreting agent recommendations] — Read DETAIL: Agent Recommendations (roles, model choices)
- [Interpreting skill recommendations] — Read DETAIL: Skill Recommendations (when to extend global vs. create local)
- [Interpreting hook patterns] — Read DETAIL: Hook Configuration (formatters, validators, guidance setup)
- [Stack not detected] — Read DETAIL: Stack Detection (what to do if harness-builder misidentifies your stack)

---

## DETAIL: Agent Recommendations

The harness-builder recommends agents based on project type and detected stack.

### Universal Agents (Every Project)

Always recommended:

- **code-reviewer** (Sonnet) — 6-dimensional code review (correctness, design, readability, performance, testing, security)
- **verifier** (Haiku) — Fast validation runner (linter, type checker, test harness)
- **test-writer** (Sonnet) — Generate tests following project conventions
- **domain-advisor** (Sonnet, read-only) — Answer questions about domain rules and entity relationships

### Stack-Dependent Agents

**If GitHub detected:**

- **project-manager** (Sonnet) — Manage issues, PRs, milestones via GitHub CLI

**If frontend detected:**

- Design harness (`.impeccable.md`) — Accessibility and design audit guidelines
- `/ui-review` skill — WCAG 2.1 AA compliance checker

**If database-heavy:**

- **migration-reviewer** (Sonnet) — Validate schema changes and backwards compatibility

### Model Tiering

- **Haiku** — Fast validation (verifier, small utilities)
- **Sonnet** — Generation and analysis (code-reviewer, test-writer, main domain agents)
- **Opus** — Only for deep architectural decisions (rare; usually in CLAUDE.md as override)

---

## DETAIL: Skill Recommendations

The harness-builder recommends skills based on detected workflows and available global skills.

### Universal Skills

Always recommended:

- **`/commit`** — Conventional commits with project-specific quality gates (extends global `/commit`)

### GitHub Projects

If GitHub is detected:

- **`/feature-spec`** — Write feature specs before implementation
- **`/issue-triage`** — Categorize and prioritize issues
- **`/standup`** — Generate daily standup from git + GitHub activity

### Frontend Projects

If frontend is detected:

- **`/ui-review`** — Accessibility and UX audit (WCAG 2.1 AA)

### Composition Over Duplication

**Key principle**: Use global skills + project-local wrappers.

✅ **Good**:

- Global `/commit` handles conventional format
- Project-local `/commit` adds quality gates specific to your stack

✅ **Good**:

- Global `/harness` provides meta-harness framework
- No project-local `/harness` needed (framework is stack-agnostic)

❌ **Bad**:

- Duplicating global `/commit` workflow in project-local skill (creates maintenance burden)

---

## DETAIL: Hook Configuration

Hooks enable zero-token automation: formatters and validators run silently on every file edit, before Claude sees the content.

### Formatters (Silent Auto-Fix)

Run before Claude sees any edits. Examples:

- `nix run ".#format"` — Format Nix files
- `prettier --write` — Format JavaScript/JSON
- `ruff check --fix` — Auto-fix Python linting
- `markdownlint --fix` — Fix Markdown formatting

**Trigger:** Every Edit/Write tool use. **Cost:** Zero tokens (silent, happens before Claude reads).

### Validators (Bounded Error Checks)

Run after formatting. Output ≤30 lines, gated with conditions. Examples:

- `nix flake check` — Nix syntax validation
- `type-check` — TypeScript/mypy type checking
- `cargo test --lib` — Rust unit tests (sampled)
- `npm test -- --coverage` — Test coverage check

**Trigger:** After edit if conditions match (e.g., "if .nix file was changed"). **Cost:** Tokens only if errors found.

### Guidance (Context Reminders)

Orient developers with skill/doc references. Examples:

- "Check CLAUDE.md for domain constraints"
- "This touches auth — run domain-advisor agent"
- "Run /pre-flight before switching"

**Trigger:** After validation, always shown. **Cost:** <20 lines, always helpful, never noisy.

### Example Configuration

```json
{
  "hooks": {
    "PostToolUse": {
      "Edit,Write": [
        {
          "stage": "formatters",
          "name": "format-files",
          "command": "nix run \".#format\" -- {file_path} 2>/dev/null || true"
        },
        {
          "stage": "validators",
          "name": "nix-check",
          "command": "nix flake check --quiet 2>&1 | head -10",
          "condition": "file_matches('**/*.nix')"
        },
        {
          "stage": "guidance",
          "name": "harness-check",
          "command": "echo '📋 Run /harness to audit the agent harness'",
          "condition": "file_in(['.claude/skills/**', '.claude/agents/**'])"
        }
      ]
    }
  }
}
```text

---

## DETAIL: Stack Detection

The harness-builder detects your project stack by looking for:

### Language/Framework Detection

| Detection Method | Detected Stack |
| --- | --- |
| `package.json` + npm scripts | JavaScript/TypeScript/Node.js |
| `Cargo.toml` | Rust |
| `go.mod` | Go |
| `pyproject.toml` or `setup.py` | Python |
| `flake.nix` + `home.nix` | Nix/Home Manager |
| `Makefile` with `ci` target | Generic make-based |
| `justfile` with `check` recipe | Just-based |

### Verification Command Detection

| File | Detection |
| --- | --- |
| `package.json` | `npm test` or `npm run check` |
| `Cargo.toml` | `cargo test` |
| `Makefile` | `make ci` or `make check` |
| `justfile` | `just check` or `just ci` |
| `flake.nix` | `nix flake check` |

### Optional Stack Signals

- **GitHub**: Presence of `.github/workflows/` or `gh` CLI integration
- **Frontend**: Presence of `.impeccable.md` or frontend framework dependencies
- **Database**: Presence of `migrations/`, `schema.sql`, or ORM configs

### If Stack Not Detected

Harness-builder will ask:

1. "What's your primary language/framework?"
2. "How do you run tests/validation?"
3. "What's the main file structure? (src/, app/, lib/)"

Use these answers to customize recommendations before finalizing.

---

## RELATED

- `/harness` — Audit harness quality (gates on PURPOSE/CRITICAL/STANDARD PATH)
- `CLAUDE.md` — Generated harness documentation (customize after generation)
- `/documentation-writer` — Write scannable docs
- `/skill-writer` — Create well-structured skills
