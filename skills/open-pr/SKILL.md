---
name: open-pr
description: >-
  Open a PR for the current feature branch — validate, self-review, simplify,
  organize commits, push, create the PR, wait for CI and review, then address
  feedback. Use when implementation is complete and ready for review.
argument-hint: "[base branch]"
model: sonnet
allowed-tools: Bash(gh pr *), Bash(gh api *), Bash(gh run *), Bash(git status), Bash(git diff *), Bash(git log *), Bash(git add *), Bash(git commit *), Bash(git push *), Bash(git branch *), Bash(git stash *), Bash(git checkout *), Bash(git reset *), Bash(git rev-list *), Bash(git rev-parse *), Bash(${CLAUDE_PLUGIN_ROOT}/skills/open-pr/*), Bash(${CLAUDE_PLUGIN_ROOT}/skills/shared/discover-verification-cmd.sh*), Bash(${CLAUDE_PLUGIN_ROOT}/skills/shared/resolve-github-context.sh*), Read
---

# /open-pr — Open a Pull Request

Take the current feature branch from "implementation done" to "PR open, CI green, first-round review addressed."

## Phase 1: Pre-flight

1. **Ensure feature branch** — auto-create if on `main`:

   ```bash
   branch=$(${CLAUDE_PLUGIN_ROOT}/skills/open-pr/ensure-feature-branch.sh)
   ```

   The script handles three scenarios automatically:
   - **Unpushed commits on main** → infers branch name from commit, creates branch, resets main
   - **Staged/unstaged changes** → stashes, creates branch, pops
   - **Clean state** → exits 1 ("No changes to create a PR from.")

2. **Determine base branch** — use `$ARGUMENTS` if provided, otherwise `main`.

3. **Discover and run validation:**

   ```bash
   cmd=$(${CLAUDE_PLUGIN_ROOT}/skills/shared/discover-verification-cmd.sh)
   eval "$cmd"
   ```

   **ALL must pass.** Fix any failures before proceeding.

4. **Check for existing PR**:

   ```bash
   gh pr view --json number,url,state
   ```

   If a PR already exists and is open, auto-delegate to `/review-pr` — do not stop and tell the user.

## Phase 2: Self-review

Review **every change** in the diff:

```bash
git diff <base>...HEAD
git diff
git diff --cached
```text

Check for:

- Bugs, logic errors, edge cases, missing null checks
- Missing error handling
- Security concerns (secrets, injection, unsafe deserialization)
- Missing or inadequate tests
- Leftover debug code (`print()`, `console.log`, `TODO`/`FIXME` without issue refs)
- Code quality and naming consistency

Fix any issues found, then re-run validation.

## Phase 3: Simplify (Optional)

Review for opportunities to simplify:

- Reuse opportunities (existing utilities that could replace new code)
- Dead code or unnecessary complexity
- Duplication within the changeset

If improvements are found, apply them and re-run validation.

Note: This phase is optional and relies on manual review or the `/simplify` skill if available in your Claude Code environment.

## Phase 4: Organize commits

1. Review current state:

   ```bash
   git log <base>..HEAD --oneline
   git status
   ```

1. Organize changes into logical commits:
   - If all uncommitted: group into meaningful commits (separate feature from tests, refactoring from new functionality)
   - If commits exist and are well-organized: just commit remaining changes
   - If messy (WIP, fixup): clean up

2. **Stage specific files** — never use `git add -A` or `git add .`

3. Use conventional commit format with HEREDOC:

   ```bash
   git commit -m "$(cat <<'EOF'
   feat(scope): short description

   Optional longer explanation.

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"
   ```

## Phase 5: Push and create PR

1. Push:

   ```bash
   git push -u origin <branch>
   ```

2. Create PR with HEREDOC body:

   ```bash
   gh pr create --base <base> --title "feat(scope): short description" --body "$(cat <<'EOF'
   ## Summary
   - Bullet points describing what this PR does

   ## Test plan
   - [ ] How to verify the changes work

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   EOF
   )"
   ```

3. Print the PR URL.

## Phase 6: Wait for CI

```bash
${CLAUDE_PLUGIN_ROOT}/skills/open-pr/poll-ci.sh <number>
```

Exit 0 = passed, exit 1 = failed (fix, commit, push, re-poll), exit 2 = timeout.

**If a check fails:** fetch logs with `gh run view <run-id> --log-failed`, fix, validate locally, commit (specific files), push, resume waiting.

## Phase 7: Wait for review

**Always use the polling script** — never check for review comments with `gh pr view --json`. That endpoint only returns top-level PR comments, not inline review comments attached to code lines. The polling script uses the correct API (`gh api repos/.../pulls/.../comments`).

```bash
ctx=$(${CLAUDE_PLUGIN_ROOT}/skills/shared/resolve-github-context.sh <number>)
owner_repo=$(echo "$ctx" | jq -r '"\(.owner)/\(.repo)"')
${CLAUDE_PLUGIN_ROOT}/skills/open-pr/poll-review.sh "$owner_repo" <number>
```

Outputs: `approved`, `comments`, or `timeout` (exit 2).

- **approved** → tell user and stop
- **comments** → proceed to Phase 8
- **timeout** → tell user "CI green, PR open, no review comments yet" and stop

## Phase 8: Address review comments

Invoke `/review-pr` to handle all review comments:

```bash
/review-pr <number>
```text

**Do not duplicate the review-comment workflow** — always delegate to `/review-pr`.

## Phase 9: Summary

Print:

- PR URL
- Number of commits
- CI status
- Review comments addressed (if any)
- Current PR state

## Important Rules

- **Never dismiss review findings** — Code quality concerns are the entire point of code review. Never rationalize skipping them ("not blocking", "acceptable", "good for future refinement"). Every finding gets fixed, deferred with a tracked issue, or discussed with the reviewer. "CI is green" and "tests pass" do not override review feedback.
- **Never merge with unaddressed comments** — All review comments must be resolved before merging. No exceptions.
- **Validate before opening** — verification must pass before creating the PR
- **Self-review is mandatory** — always review the full diff
- **Simplify is mandatory** — always run `/simplify` before opening
- **Logical commits** — organize into meaningful commits, not one giant squash
- **No shortcuts** — never use `--no-verify`, `noqa`, or `type: ignore`
- **Fix CI in-place** — don't close and re-open
- **Stage specific files** — never `git add -A` or `git add .`
- **HEREDOC for messages** — always use HEREDOC for commit messages and PR bodies
- **File issues for deferred work** — if self-review finds out-of-scope issues, create GitHub issues before opening
- **Delegate to /review-pr** — don't duplicate the comment-response workflow

## Related Skills

- `/review-pr` — Address review feedback (fix, commit, push, reply)
- `/commit` — Quality-gated conventional commits
- `/simplify` — Code simplification pass
