---
name: commit
description: >-
  Creates conventional commits with quality gates — stages intentionally,
  checks for uv.lock drift, runs the project's verification command, and
  writes the message. Owns commit mechanics for the PR workflow skills. Use
  when the user asks to commit, stage, or write a commit message, and when
  another skill (open-pr, review-pr) needs the commit mechanics or the uv.lock
  drift check.
allowed-tools: Bash(git add*), Bash(git commit*), Bash(git diff*), Bash(git status*), Bash(${CLAUDE_SKILL_DIR}/discover-verification-cmd.sh*), Read
---

# Commit

Stage on purpose, verify, and commit with a conventional message. The steps
are exact because staging and pre-commit hooks fail in quiet ways.

## 1. Stage intentionally

```bash
git status                     # see what changed
git add <file1> <file2> ...    # stage the files this commit is about
git diff --cached              # review exactly what will be committed
```

Name each file rather than running `git add -A` or `git add .`, so stray
files stay out. Keep unrelated changes in separate commits. Read the staged
diff for secrets: API keys, passwords, credentials, and tokens stay out of
the commit.

Done when `git diff --cached` shows only the intended change and no secrets.

## 2. Stage a drifted uv.lock (Python + uv only)

Skip this step unless both `pyproject.toml` and `uv.lock` exist. After
staging, check for unstaged drift:

```bash
git status --porcelain -- uv.lock   # " M" or "MM" = unstaged drift
```

If it has drifted, stage it with the commit:

```bash
git add uv.lock
```

Tell the user each time you do this, for example:

> Staging drifted `uv.lock` alongside this commit: pre-commit hooks that run
> tools under `uv run` regenerate it, and an unstaged `uv.lock` makes
> pre-commit's auto-stash/pop cycle conflict and abort the commit.

The drift is legitimate and belongs in the commit; [uv-lock-drift.md](uv-lock-drift.md)
explains the failure mode and why the lock drifts without dependency changes.

Done when `uv.lock` shows no unstaged change, or the step does not apply.

## 3. Run the project's verification

Discover the verification command, then run what it prints as a **separate**
Bash call:

```bash
${CLAUDE_SKILL_DIR}/discover-verification-cmd.sh
```

Keep the discovery and the run in separate calls rather than piping into
`eval`: a command containing `eval` cannot be statically analyzed, so it falls
outside this skill's `allowed-tools` and prompts for permission every time.

Done when every check passes. A commit that breaks tests or linting waits
until they are fixed.

## 4. Write the message

Format: `type(scope): description`, for example `feat(auth): add OAuth2 login
flow`. A malformed message causes merge and CI problems downstream.

- **Type**: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`, and rarely
  `style` or `perf`.
- **Scope**: optional; the area of change in the project's own terms. Omit it
  for project-wide changes.
- **Description**: imperative mood, no trailing period, 50 characters at most
  (aim for about 30), specific.
- **Body**: optional; explains why, wraps at 72 characters, sits after a blank
  line, and links issues (`Closes #NNN`).

[message-format.md](message-format.md) has the types table and good and bad
examples. Done when the subject matches the format and says specifically
what changed.

## 5. Create the commit

```bash
git commit -m "$(cat <<'EOF'
feat(scope): brief description

- Detailed explanation line 1
- Detailed explanation line 2

Closes #NNN
EOF
)"
```

A one-line message can go straight into `git commit -m "type(scope):
description"`; use the HEREDOC for any multi-line body.

If pre-commit aborts with "files were modified by this hook" and `uv.lock` is
in the modified list, stage `uv.lock` (step 2), warn the user, and retry once
with the same message.

Done when `git status` shows the commit landed and nothing intended is left
unstaged.

## When the commit needs more

Read [staging-and-fixes.md](staging-and-fixes.md) to stage a large change by
category, commit part of a file, or undo or amend a commit.

## Related

- `/review-pr`: review pull requests.
- `/open-pr`: open a PR with validation.
- [Conventional Commits spec](https://www.conventionalcommits.org/)
