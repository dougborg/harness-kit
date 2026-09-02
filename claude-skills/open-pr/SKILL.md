---
name: open-pr
description: >-
  Open a PR for the current feature branch — validate, self-review, simplify,
  organize commits, push, create the PR, wait for CI and review, then address
  feedback.
when_to_use: >-
  When implementation is complete and ready for review — the user asks to open,
  raise, or submit a PR — and when /harness-issue hands off in PR mode.
argument-hint: "[base branch]"
allowed-tools: Bash(gh pr *), Bash(gh api *), Bash(gh run *), Bash(git status), Bash(git diff *), Bash(git log *), Bash(git add *), Bash(git commit *), Bash(git push *), Bash(git branch *), Bash(git stash *), Bash(git checkout *), Bash(git reset *), Bash(git rev-list *), Bash(git rev-parse *), Bash(${CLAUDE_SKILL_DIR}/*), Bash(${CLAUDE_SKILL_DIR}/*), Read
---

# /open-pr — Open a Pull Request

Take the current feature branch from "implementation done" to "PR open, CI green, first-round review addressed."

## PURPOSE

Ship a feature branch end-to-end: validate, self-review, push, create PR, wait for CI, address the first round of review.

## CRITICAL

- **Validate before opening** — the project's verification command must pass before `gh pr create`. Don't push broken code.
- **Self-review the full diff** — read every change before opening; never skip this and rely on reviewers.
- **Stage specific files** — never `git add -A` or `git add .`. Intentional staging prevents accidentally committing secrets, scratch files, or unrelated changes.
- **Use polling scripts for CI and review state** — never check review comments with `gh pr view --json`. That endpoint only returns top-level PR comments, not inline review comments attached to code lines. Use `poll-review.sh` which queries review threads and review states via the correct APIs.
- **The Bash tool's default 120s timeout silently kills long polls** — every watch/poll invocation (`poll-ci.sh`, `poll-review.sh`, `gh pr checks --watch`) MUST either pass an explicit Bash `timeout` well above the script's own timeout, or run with `run_in_background: true`. A foreground poll on the default timeout dies mid-wait with truncated output that looks like a status report — and no notification is coming.
- **Never merge with unaddressed review comments** — every comment gets fixed, deferred with a tracked issue, or discussed. CI green does not override review feedback.
- **No `--no-verify`** — never bypass commit hooks, type checkers, or linters. If a check fails, fix the cause.

## STANDARD PATH

The skill runs nine phases. Each phase is short; phase headings below are the navigation index.

1. **Pre-flight** — ensure feature branch, run validation, check for existing PR
2. **Self-review** — read the full diff, check for bugs/secrets/debug code
3. **Simplify (optional)** — reuse, dead code, duplication
4. **Organize commits** — logical commits; mechanics via `/commit`'s standard path
5. **Push and create PR** — `gh pr create` with HEREDOC body
6. **Wait for CI** — `poll-ci.sh`; fix in place if anything fails
7. **Wait for review** — `poll-review.sh`; never skip with `gh pr view`
8. **Address review comments** — delegate to `/review-pr`
9. **Summary** — report PR URL, CI status, comments addressed

## Phase 1: Pre-flight

1. **Ensure feature branch** — auto-create if on `main`:

   ```bash
   branch=$(${CLAUDE_SKILL_DIR}/ensure-feature-branch.sh)
   ```

   The script handles three scenarios automatically:
   - **Unpushed commits on main** → infers branch name from commit, creates branch, resets main
   - **Staged/unstaged changes** → stashes, creates branch, pops
   - **Clean state** → exits 1 ("No changes to create a PR from.")

2. **Determine base branch** — use `$ARGUMENTS` if provided, otherwise `main`.

3. **Discover and run validation:**

   ```bash
   ${CLAUDE_SKILL_DIR}/discover-verification-cmd.sh
   ```

   Then run the command it prints as a **separate** Bash call — never `eval` it
   in the same call, which defeats `allowed-tools` matching and prompts.

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
```

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

2. Organize changes into logical commits:
   - If all uncommitted: group into meaningful commits (separate feature from tests, refactoring from new functionality)
   - If commits exist and are well-organized: just commit remaining changes
   - If messy (WIP, fixup): clean up

3. **Create each commit via `/commit`'s STANDARD PATH** — it owns the commit
   mechanics: intentional staging (never `git add -A` or `git add .`), the
   uv.lock drift check for Python+uv projects (see DETAIL: uv.lock Drift in
   `skills/commit/SKILL.md`), conventional message format, and HEREDOC commit
   creation. Validation already ran in Phase 1 — skip `/commit`'s validation
   step unless code changed since.

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
${CLAUDE_SKILL_DIR}/poll-ci.sh <number> [timeout-seconds]
```

Exit 0 = passed, exit 1 = failed (fix, commit, push, re-poll), exit 2 = script timeout — CI is **still running**, not done; re-poll.

### Outliving the Bash tool timeout (REQUIRED)

`poll-ci.sh` waits up to 300s by default (pass a second argument for longer), but the Bash tool's **default 120s timeout kills the call first** — silently. The truncated output (a heartbeat listing pending checks) is NOT a result, and no completion notification will ever arrive from a killed foreground call. Every invocation MUST use one of:

1. **Foreground with explicit timeout** — set the Bash tool `timeout` parameter comfortably above the script's own timeout, e.g. `timeout: 600000` (ms) for the default 300s script timeout, or `timeout: 900000` with `poll-ci.sh <number> 720` for slow CI. The script — not the Bash tool — must be the one that decides when to give up, so a timeout always produces an explicit exit 2.
2. **Background** — invoke with `run_in_background: true`. The Bash call returns immediately and you are re-invoked when the poll completes; read the final output then.

Interpreting output: `poll-ci.sh` ends every terminal outcome with a `CI RESULT:` line. If the output you see ends with a `CI POLL:` heartbeat instead, the process was killed mid-wait — CI state is unknown. Re-poll; never report "waiting for the monitor" and stop.

**If a check fails:** fetch logs with `gh run view <run-id> --log-failed`, fix, validate locally, commit (specific files), push, resume waiting.

### Resuming after a wakeup or notification

If you backgrounded a poll and return later via a scheduled wakeup or task notification, the prompt you wrote was frozen at scheduling time. By the time it fires, task IDs and the state it describes are often stale — a force-push starts a new CI run, a finished poll task no longer exists. On resume:

- **Do not trust remembered task IDs** or the state claimed by the wakeup prompt.
- **Re-derive state fresh** from GitHub:

  ```bash
  gh pr checks <number>
  gh pr view <number> --json state,reviews,mergeStateStatus
  ```

- Continue from whichever phase the fresh state indicates (CI running → keep waiting; CI failed → fix; CI green → Phase 7).

When scheduling a wakeup, phrase the prompt as the **goal**, not a task reference: `"PR #<n>: continue /open-pr Phase 6 CI wait — re-check gh pr checks and proceed"`, never `"check poll task <id>"`. The same rules apply to any long-running poll in this skill, including Phase 7's review wait.

## Phase 7: Wait for review

**Always use the polling script** — never check for review comments with `gh pr view --json`. That endpoint only returns top-level PR comments, not inline review comments attached to code lines. The polling script uses the correct APIs (GraphQL review threads + review states).

```bash
ctx=$(${CLAUDE_SKILL_DIR}/resolve-github-context.sh <number>)
owner_repo=$(echo "$ctx" | jq -r '"\(.owner)/\(.repo)"')
${CLAUDE_SKILL_DIR}/poll-review.sh "$owner_repo" <number>
```

The Bash-timeout and wakeup-resume rules from Phase 6 apply here too — `poll-review.sh` waits even longer than `poll-ci.sh`, so it MUST also run with an explicit Bash `timeout` above the script's own, or with `run_in_background: true`.

Outputs exactly one state:

- **approved** (exit 0) → tell user and stop
- **changes-requested** (exit 0) → a reviewer requested changes — proceed to Phase 8
- **comments** (exit 0) → new actionable inline threads (unresolved, and the last comment is not yours — threads you already replied to don't re-trigger) — proceed to Phase 8
- **summary-only** (exit 0) → a reviewer posted a COMMENTED review with **no inline comments** (common for Copilot follow-up passes). Read the review body and surface it to the user — there is no fixup loop to run:

  ```bash
  gh api "repos/$owner_repo/pulls/<number>/reviews" \
    --jq '[.[] | select(.state == "COMMENTED" and .body != "")] | last | .body'
  ```

  Decide with the user whether anything in the summary needs action; otherwise stop.

- **timeout** (exit 2) → tell user "CI green, PR open, no review comments yet" and stop

**Wait for Copilot:** the script does not report `timeout` until the Copilot review bot has left a review or the PR is older than `POLL_REVIEW_COPILOT_WAIT` seconds (default 300, measured from PR creation). Copilot reviews typically land 2–5 minutes after PR open — never conclude "no review" before that window passes. Repos without Copilot review are covered by the same window: the hold simply expires.

## Phase 8: Address review comments

Invoke `/review-pr` to handle all review comments:

```bash
/review-pr <number>
```

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
- **Simplify is encouraged but optional** — Phase 3; use `/simplify` if it would
  meaningfully reduce duplication or dead code, otherwise skip
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
