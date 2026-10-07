# Reading the recommendations

What the `harness-builder` agent tends to recommend for each part of a
harness, and how to judge it before generating files.

## Contents

- [Agents](#agents)
- [Skills](#skills)
- [Hooks](#hooks)
- [Stack detection](#stack-detection)

## Agents

The agent picks agents by project type and detected stack.

Every project gets:

- **code-reviewer** (Sonnet): six-dimension review (correctness, design,
  readability, performance, testing, security).
- **verifier** (Haiku): a fast validation runner (linter, type checker, test
  harness).
- **test-writer** (Sonnet): tests that follow the project's conventions.
- **domain-advisor** (Sonnet, read-only): answers questions about domain rules
  and entity relationships.

Depending on the stack:

- **GitHub**: **project-manager** (Sonnet) manages issues, PRs, and milestones
  through the GitHub CLI.
- **Frontend**: a design harness (`.impeccable.md`) with accessibility and
  design audit guidelines, and the `/ui-review` skill for WCAG 2.1 AA checks.
- **Database-heavy**: **migration-reviewer** (Sonnet) validates schema changes
  and backwards compatibility.

Model tiers:

- **Haiku**: fast validation (verifier, small utilities).
- **Sonnet**: generation and analysis (code-reviewer, test-writer, the main
  domain agents).
- **Opus**: only deep architectural decisions. Rare; usually set as an
  override in `CLAUDE.md`.

## Skills

The agent picks skills by detected workflow and by which global skills
already exist.

- **Every project**: `/commit`, conventional commits with the project's own
  quality gates (extends the global `/commit`).
- **GitHub**: `/to-spec` and `/to-tickets` turn a design conversation into a
  spec issue, then tracer-bullet sub-issues; `/issue-create`, `/triage`, and
  `/groom` file issues with real labels, move incoming issues to agent-ready
  briefs, and prioritize the backlog; `/standup` reports from git and GitHub
  activity; `/agent-standup` reconciles ownership and handoffs across agents
  and operators.
- **Frontend**: `/ui-review`, an accessibility and UX audit (WCAG 2.1 AA).

Compose rather than duplicate: a global skill plus a project-local wrapper.

- Good: the global `/commit` handles the conventional format, and a
  project-local `/commit` adds the stack's quality gates.
- Good: the global `/harness` provides the meta-harness framework, and no
  project-local `/harness` is needed, because the framework is
  stack-agnostic.
- Bad: copying the global `/commit` workflow into a project-local skill. Two
  copies drift and double the maintenance.

## Hooks

Hooks give zero-token automation: formatters and validators run on every edit
before Claude reads the result. Recommend them in three stages, in this
order.

**Formatters** fix style silently on every Edit or Write, at zero token cost.
Examples: `nix run ".#format"` for Nix, `prettier --write` for JavaScript and
JSON, `ruff check --fix` for Python, `markdownlint --fix` for Markdown.

**Validators** run after formatting, only when the edited file matches (for
example, a `.nix` file changed), with output capped at 30 lines. They cost
tokens only when they find an error. Examples: `nix flake check`, a TypeScript
or mypy type check, `cargo test --lib` (sampled), `npm test -- --coverage`.

**Guidance** runs last and points the developer at the right skill or doc, in
under 20 lines. Examples: "Check CLAUDE.md for domain constraints", "This
touches auth; ask the domain-advisor agent", "Run /pre-flight before
switching".

Hooks matching the same event run in parallel, so put stages that must run in
order into one script. A `.claude/settings.local.json` entry:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/post-edit.sh" }
        ]
      }
    ]
  }
}
```

And the script, reading the edited path from the hook's JSON input:

```bash
#!/usr/bin/env bash
file=$(jq -r '.tool_input.file_path // empty')
# 1. Formatter: silent, never fails the hook
nix run ".#format" -- "$file" >/dev/null 2>&1 || true
# 2. Validator: only for matching files, bounded output
if [[ "$file" == *.nix ]]; then nix flake check --quiet 2>&1 | head -10; fi
# 3. Guidance: only where it applies
if [[ "$file" == */.claude/skills/* || "$file" == */.claude/agents/* ]]; then
  echo "Run /harness audit to check the agent harness"
fi
exit 0
```

## Stack detection

The agent reads the stack from these files:

| Found | Stack |
| --- | --- |
| `package.json` with npm scripts | JavaScript, TypeScript, Node.js |
| `Cargo.toml` | Rust |
| `go.mod` | Go |
| `pyproject.toml` or `setup.py` | Python |
| `flake.nix` with `home.nix` | Nix / Home Manager |
| `Makefile` with a `ci` target | Generic make-based |
| `justfile` with a `check` recipe | Just-based |

And the verification command from these:

| File | Command |
| --- | --- |
| `package.json` | `npm test` or `npm run check` |
| `Cargo.toml` | `cargo test` |
| `Makefile` | `make ci` or `make check` |
| `justfile` | `just check` or `just ci` |
| `flake.nix` | `nix flake check` |

Optional signals: GitHub (`.github/workflows/` or `gh` CLI use), frontend
(`.impeccable.md` or frontend framework dependencies), database
(`migrations/`, `schema.sql`, or ORM configs).

When the stack isn't detected or is misread, ask the user three questions and
fold the answers into the recommendations before finalizing:

1. What's the primary language or framework?
2. How do you run tests and validation?
3. What's the main file structure (`src/`, `app/`, `lib/`)?
