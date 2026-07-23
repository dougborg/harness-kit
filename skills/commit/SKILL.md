---
name: commit
description: Create conventional commits with quality gates and validation
allowed-tools: Bash(git add*), Bash(git commit*), Bash(git diff*), Bash(git status*), Bash(${CLAUDE_PLUGIN_ROOT}/skills/shared/discover-verification-cmd.sh*), Read
---

# /commit — Quality-Gated Conventional Commits

Create conventional commits with automatic validation and quality gates.

## PURPOSE

Commit changes reliably with validation checks and consistent messaging.

## CRITICAL

- **Never commit secrets** — Run `git diff --cached` before committing. No hardcoded API keys, passwords, credentials, or tokens.
- **Always validate before committing** — Project verification command must pass. No commits that break tests or linting.
- **Message must follow conventional format** — `type(scope): description`. Malformed messages create merge and CI problems downstream.
- **Stage specific files** — Never use `git add -A` or `git add .` blindly. Review `git status` and stage intentionally.

## ASSUMES

- You're in a git repository with a verification command available
- You can identify which files should be committed (no accidental includes)
- You know the type of change: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`

## STANDARD PATH

### 1. Stage Changes

Review and stage files intentionally:

```bash
git status                          # See what changed
git add <file1> <file2> ...         # Stage specific files
git diff --cached                   # Review staged changes
```

**Never:** `git add -A` or `git add .` — stage intentionally.

### 2. Auto-Stage Drifted uv.lock (Python+uv Projects Only)

**Skip this step unless** both `pyproject.toml` and `uv.lock` exist (Python+uv stack).

After staging your intended files, check whether `uv.lock` has unstaged changes:

```bash
git status --porcelain -- uv.lock   # " M" or "MM" = unstaged drift
```

If it does, stage it alongside the commit:

```bash
git add uv.lock
```

**Always warn the user when you do this**, e.g.:

> Staging drifted `uv.lock` alongside this commit: pre-commit hooks that run
> tools under `uv run` regenerate it, and an unstaged `uv.lock` makes
> pre-commit's auto-stash/pop cycle conflict and abort the commit.

Then proceed. See DETAIL: uv.lock Drift for the failure mode this prevents.

### 3. Run Project Validation

Discover and run the verification command:

```bash
cmd=$(${CLAUDE_PLUGIN_ROOT}/skills/shared/discover-verification-cmd.sh)
eval "$cmd"
```

**ALL checks must pass.** No commits that break validation.

### 4. Write Commit Message

Format: `type(scope): description`

Example:

```text
feat(auth): add OAuth2 login flow
```

See DETAIL: Message Format for all types and examples.

### 5. Create Commit

```bash
git commit -m "type(scope): description

Optional detailed explanation here.
Mention related issues: #123, closes #456."
```

For complex messages, use HEREDOC:

```bash
git commit -m "$(cat <<'EOF'
feat(scope): brief description

- Detailed explanation line 1
- Detailed explanation line 2

Closes #NNN
EOF
)"
```

## EDGE CASES

- [Complex commit messages] — Read DETAIL: Message Format (when to use HEREDOC, multi-line bodies)
- [Large changes spanning files] — Read DETAIL: Staging Multiple Files (review each category before committing)
- [Partial file commits] — Read DETAIL: Staging Hunks (commit part of a file)
- [Fixing mistakes] — Read DETAIL: Fixing Commit Mistakes (amend, reset, rebase)
- [Pre-commit aborts with "files were modified by this hook" + uv.lock] — Read DETAIL: uv.lock Drift (stage uv.lock and retry once)

---

## DETAIL: Message Format

### Conventional Commit Types

| Type | Use Case | Example |
| --- | --- | --- |
| `feat` | New feature or capability | `feat(auth): add two-factor authentication` |
| `fix` | Bug fix | `fix(api): handle null responses from upstream` |
| `refactor` | Code restructuring (no behavior change) | `refactor: extract validation into utility` |
| `docs` | Documentation updates | `docs: clarify API rate limits in README` |
| `chore` | Maintenance, dependencies, build | `chore: upgrade prettier to latest` |
| `test` | Test additions or fixes | `test: add edge case coverage for date parsing` |
| `style` | Formatting, missing semicolons (rarely used) | N/A |
| `perf` | Performance improvements (rarely used) | `perf: use memoization for expensive calculation` |

### Scope

Optional, indicates area of change:

- Use project naming conventions: `auth`, `api`, `ui`, `database`, etc.
- Omit for project-wide changes
- Examples: `feat(keyboard): add macro support`, `fix: resolve memory leak`

### Description

- Imperative mood: "add feature" not "added feature" or "adds feature"
- No period at end
- ≤50 characters (aim for ~30)
- Specific: "add password reset flow" not "fix auth stuff"

### Body (Optional)

- Explain **why**, not **what** (code shows the what)
- Wrap at 72 characters
- Separated from subject by blank line
- Link to issues: `Closes #NNN`, `Fixes #NNN`, `Relates to #MMM`

### Example: Good Commit

```text
feat(keyboard): add macro recording and playback

Users can now record key sequences and replay them with a hotkey.
This addresses frequent requests for repetitive key patterns.

Macro storage uses ~/.config/daskeyboard/macros.json for
persistence across sessions.

Testing: Added 12 test cases covering:
- Basic record/playback
- Edge cases (empty macros, special keys)
- Storage persistence

Closes #234
```

### Example: Bad Commit

```text
fix stuff                           ← Too vague
feat: add oauth                     ← Missing scope, too brief
docs: update                        ← What did you update?
refactor(everything): big cleanup   ← Scope "everything" is suspicious
```

---

## DETAIL: Staging Multiple Files

When committing changes across many files:

### Review by Category

```bash
git status | grep -E "modified|new"     # See all changes
git diff --stat                         # Summary by file

# Stage by category
git add programs/zsh.nix programs/vim.nix   # Shell config
git add docs/*.md                           # Documentation
git diff --cached                           # Review staged
git commit -m "..."
```

### Don't Mix Unrelated Changes

Each commit should be coherent:

❌ **Bad**: Single commit with shell config, docs, and bug fix
✅ **Good**: Three separate commits, one for each type of change

This makes history clearer and simplifies reverting if needed.

---

## DETAIL: Staging Hunks

Commit part of a file (not all changes):

```bash
git add --patch <file>              # Interactive hunk selection
# Review each hunk, stage with 'y', skip with 'n'

git diff --cached                   # Review staged hunks
git commit -m "feat: related change"
```

Use when:

- Multiple unrelated changes in one file
- You want to split into multiple commits
- You want to exclude debugging code you accidentally added

---

## DETAIL: Fixing Commit Mistakes

### Undo Last Commit (Keep Changes)

```bash
git reset --soft HEAD~1             # Undo commit, keep staged
git reset HEAD                       # Unstage all
# Now fix and re-commit
```

### Amend Last Commit (Not Yet Pushed)

```bash
git add <fixed-files>
git commit --amend                  # Amend with new changes
# Or: git commit --amend --no-edit   (keep message)
```

**Never amend commits already pushed.** Use a new commit instead.

### Reset to Before Last Commit

```bash
git reset --hard HEAD~1             # Discard all changes in last commit
```

**Use with caution** — this is destructive.

---

## DETAIL: uv.lock Drift

### The Failure Mode

In Python+uv projects with pre-commit, an unstaged `uv.lock` triggers an
auto-stash race that aborts the commit:

1. Pre-commit auto-stashes unstaged changes (including the unstaged `uv.lock` state)
2. A hook runs a tool under `uv run` (e.g., pytest), which re-syncs `uv.lock`
3. Pre-commit pops the stash — the stashed `uv.lock` conflicts with the re-synced one
4. Pre-commit reports "files were modified by this hook" and the commit aborts

Nothing was wrong with the staged content — the abort is purely the stash/pop
conflict. Staging `uv.lock` before committing eliminates the race.

### Why uv.lock Drifts Without You Touching Dependencies

- A sibling-package release on the base branch bumped a workspace version
- `uv run` / `uv sync` re-resolved after a `pyproject.toml` change elsewhere
- A different lockfile revision landed via merge or rebase

The drift is legitimate and belongs in the commit — hiding it just re-triggers
the race on the next commit.

### Recovery (If the Commit Already Aborted)

If you skipped the pre-flight check and hit the failure:

```bash
git status --porcelain -- uv.lock   # confirm uv.lock is in the modified list
git add uv.lock
git commit ...                      # retry once with the same message
```

Warn the user that `uv.lock` was staged, same as in the standard path.

---

## RELATED

- `/review-pr` — Review pull requests
- `/open-pr` — Open PR with validation
- `/rollback` — Recover from failed changes
- [Conventional Commits Spec](https://www.conventionalcommits.org/)
