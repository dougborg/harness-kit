---
name: open-pr
description: >-
  Open a PR for the current feature branch — validate, self-review, simplify,
  organize commits, push, create the PR, wait for CI, run an independent agent
  review and fix its findings, then answer any outside (Copilot or human)
  review.
when_to_use: >-
  When implementation is complete and ready for review — the user asks to open,
  raise, or submit a PR — and when /harness-issue hands off in PR mode.
argument-hint: "[base branch]"
allowed-tools: Bash(gh pr *), Bash(gh api *), Bash(gh run *), Bash(git status), Bash(git diff *), Bash(git log *), Bash(git add *), Bash(git commit *), Bash(git push *), Bash(git branch *), Bash(git stash *), Bash(git checkout *), Bash(git reset *), Bash(git rev-list *), Bash(git rev-parse *), Bash(${CLAUDE_SKILL_DIR}/*), Bash(${CLAUDE_SKILL_DIR}/*), Read
---

# /open-pr — Open a Pull Request

Take the current feature branch from "implementation done" to "PR open, CI green, reviewed, findings addressed."

## PURPOSE

Ship a feature branch end-to-end: validate, self-review, push, create PR, wait for CI, run our own agent review, and answer outside review when there is any.

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
3. **Simplify** — hold the diff against `minimal-change`'s ladder
4. **Organize commits** — logical commits; mechanics via `/commit`'s standard path
5. **Push and create PR** — `gh pr create` with HEREDOC body
6. **Wait for CI** — `poll-ci.sh`; fix in place if anything fails
7. **Agent review** — `review-pr` Mode A runs the standards and spec passes; fix findings, record them on the PR
8. **Outside reviews** — `poll-review.sh` returns at once when nobody is expected; answer any via `review-pr`
9. **Summary** — report PR URL, CI status, review outcome

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

## Phase 3: Simplify

Call the Skill tool with "minimal-change" and hold the diff against its
ladder: could each addition be deleted, or replaced by existing code, the
standard library, a native platform feature, or an installed dependency?
Apply the cuts, keep everything under the skill's "Always keep", and mark any
deliberate shortcut in the skill's `shortcut:` format. Re-run validation after any change. Done
when every addition in the diff has been checked against the ladder.

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
   the commit skill), conventional message format, and HEREDOC commit
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

   Closes #<issue>

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   EOF
   )"
   ```

   Link the issue the branch implements with `Closes #<issue>` (or `Refs #<issue>` when it only partly addresses it). Phase 7's agent review uses the closing issues as its spec; without one it can only check the diff against the PR description.

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

- Continue from whichever phase the fresh state indicates (CI running → keep waiting; CI failed → fix; CI green → Phase 7). Phase 7 is done if the PR already has an `## Agent review` comment newer than the latest push (`gh pr view <number> --json comments,commits`); then go to Phase 8.

When scheduling a wakeup, phrase the prompt as the **goal**, not a task reference: `"PR #<n>: continue /open-pr Phase 6 CI wait — re-check gh pr checks and proceed"`, never `"check poll task <id>"`. The same rules apply to any long-running poll in this skill, including Phase 8's outside-review wait.

## Phase 7: Agent review

Our own review is the gate. Outside reviewers are not guaranteed: many repos have no required reviewers and Copilot review is often requested by hand. The Phase 2 read-through is the implementer checking its own work; this phase adds an independent reader with a fresh context.

Call the Skill tool with "review-pr", passing the PR number. On a PR you authored it runs Mode A as a self-review gate: the `code-reviewer` agent runs a standards pass and a spec pass (against the PR's linked issues) on `<base>...HEAD`, you fix the findings, and the outcome is posted to the PR.

When the fixes are pushed, wait for CI again (Phase 6) so the summary reports the CI result for the reviewed code.

Done when the latest agent review has no BLOCKING findings, every finding has an outcome, CI is green on the final push, and the PR carries an `## Agent review` comment listing each finding and its outcome.

## Phase 8: Outside reviews

Check for Copilot or human review with the polling script. It queries review threads and review states through GraphQL; `gh pr view --json` returns only top-level comments and misses inline review threads.

```bash
ctx=$(${CLAUDE_SKILL_DIR}/resolve-github-context.sh <number>)
owner_repo=$(echo "$ctx" | jq -r '"\(.owner)/\(.repo)"')
${CLAUDE_SKILL_DIR}/poll-review.sh "$owner_repo" <number>
```

The script waits only when a review is actually expected: someone is in the PR's pending review requests (up to its timeout), or Copilot reviews this repo's PRs automatically (until Copilot lands, at most `POLL_REVIEW_COPILOT_WAIT` seconds after the PR opened). Otherwise it returns `none` immediately. When it does wait, the Bash-timeout and wakeup-resume rules from Phase 6 apply: run it with an explicit Bash `timeout` above the script's own, or with `run_in_background: true`.

It prints exactly one state:

| State | Exit | Next |
| --- | --- | --- |
| `none` | 3 | Nothing from outside reviewers to act on: nobody was expected, or Copilot already reviewed and its threads are handled. Go to Phase 9 |
| `comments` / `changes-requested` | 0 | Call the Skill tool with "review-pr" to work through them (Mode B) |
| `summary-only` | 0 | A COMMENTED review with no inline comments (common for Copilot follow-ups). Read the body, surface it, act only on what the user agrees needs action |
| `approved` | 0 | Report it and go to Phase 9 |
| `timeout` | 2 | An expected reviewer (requested, or automatic Copilot) has not arrived. Report that the agent review is done and outside review is pending |
| `error` | 4 | The GitHub API kept failing; stderr has the details. Fix auth or the PR reference and re-run |

Read a `summary-only` body with:

```bash
gh api "repos/$owner_repo/pulls/<number>/reviews" \
  --jq '[.[] | select(.state == "COMMENTED" and .body != "")] | last | .body'
```

## Phase 9: Summary

Print:

- PR URL
- Number of commits
- CI status
- Agent review: findings by severity and their outcomes
- Outside review: state from Phase 8, and comments addressed (if any)
- Current PR state

## Important Rules

- **Never dismiss review findings** — Code quality concerns are the entire point of code review. Never rationalize skipping them ("not blocking", "acceptable", "good for future refinement"). Every finding gets fixed, deferred with a tracked issue, or discussed with the reviewer. "CI is green" and "tests pass" do not override review feedback.
- **Never merge with unaddressed comments** — All review comments must be resolved before merging. No exceptions.
- **Validate before opening** — verification must pass before creating the PR
- **Self-review is mandatory** — always review the full diff
- **Simplify every diff** — see Phase 3
- **Logical commits** — organize into meaningful commits, not one giant squash
- **No bypassed checks** — never use `--no-verify`, `noqa`, or `type: ignore`
- **Fix CI in-place** — don't close and re-open
- **Stage specific files** — never `git add -A` or `git add .`
- **HEREDOC for messages** — always use HEREDOC for commit messages and PR bodies
- **File issues for deferred work** — if self-review finds out-of-scope issues, create GitHub issues before opening
- **Delegate to /review-pr** — both the agent review (Mode A) and outside comments (Mode B); don't duplicate either workflow here

## Related Skills

- `/review-pr` — Agent review (Mode A) and addressing review feedback (Mode B)
- `/commit` — Quality-gated conventional commits
- `/minimal-change` — The ladder Phase 3 applies
