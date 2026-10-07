---
name: open-pr
description: >-
  Opens a pull request for the current feature branch and sees it through:
  validate, self-review, simplify, organize commits, push, create the PR, wait
  for CI, run an independent agent review and fix its findings, then answer
  any outside (Copilot or human) review. Use when implementation is complete
  and ready for review, when the user asks to open, raise, or submit a PR, and
  when the harness-issue skill hands off in PR mode.
argument-hint: "[base branch]"
allowed-tools: Bash(gh pr *), Bash(gh api *), Bash(gh run *), Bash(git status), Bash(git diff *), Bash(git log *), Bash(git add *), Bash(git commit *), Bash(git push *), Bash(git branch *), Bash(git stash *), Bash(git checkout *), Bash(git reset *), Bash(git rev-list *), Bash(git rev-parse *), Bash(<skill-dir>/*), Bash(<shared-scripts-dir>/*), Read
---

# Open PR

Take the current feature branch from "implementation done" to "PR open, CI
green, reviewed, findings addressed."

These hold for every step:

- **Verification passes before `gh pr create`**, so you never push broken
  code.
- **Self-review every change yourself**; reviewers are a second reader, not
  the first.
- **Every review finding gets an outcome:** fixed, deferred to a tracked
  issue, or discussed with the reviewer. Review concerns are the point of
  review, so "not blocking", "acceptable", or "good for future refinement" is
  not an outcome, and green CI or passing tests do not override a finding.
  Merge only when every comment is resolved.
- **Fix checks at the cause.** Commit hooks, type checkers, and linters run
  every time; `--no-verify`, `noqa`, and `type: ignore` are not fixes.
- **Stage specific files by name**, never `git add -A` or `git add .`, so
  secrets, scratch files, and unrelated changes stay out.
- **Pass commit messages and PR bodies through a HEREDOC.**
- **Read review state with the polling scripts.** `gh pr view --json` returns
  only top-level PR comments and misses inline review threads.
- **Give every long poll a way to outlive the Bash tool.** Its default 120s
  timeout silently kills `poll-ci.sh`, `poll-review.sh`, and
  `gh pr checks --watch`, leaving truncated output that looks like a status
  report, and no notification follows. Pass an explicit Bash `timeout` well
  above the script's own, or run it with `run_in_background: true`.
- **Delegate review to the review-pr skill**, both the agent review and
  outside comments, rather than duplicating either workflow here.

## 1. Pre-flight

1. Make sure you're on a feature branch:

   ```bash
   branch=$(<skill-dir>/ensure-feature-branch.sh)
   ```

   On `main`/`master` (or a Claude Code `worktree-*` branch) it derives a
   branch: unpushed commits on main get a branch named from the commit and
   main is reset; staged or unstaged changes are stashed, moved to a new
   branch, and popped; a clean state exits 1 ("No changes to create a PR
   from.").

2. The base branch is `$ARGUMENTS` if given, otherwise `main`.

3. Discover the verification command, then run the command it prints as a
   **separate** Bash call; `eval` in the same call defeats `allowed-tools`
   matching and prompts every time:

   ```bash
   <shared-scripts-dir>/discover-verification-cmd.sh
   ```

4. Check for an existing PR:

   ```bash
   gh pr view --json number,url,state
   ```

   If one is already open, call the Skill tool with "review-pr" for it rather
   than stopping to tell the user. Name no mode: review-pr picks the agent
   review or addressing feedback from the PR's reviews and unresolved threads.

Done when you're on a feature branch, verification passes in full, and either
no PR is open for it or the open one is in the review-pr skill's hands.

## 2. Self-review

Read every change, committed and not:

```bash
git diff <base>...HEAD
git diff
git diff --cached
```

Look for bugs and unhandled edge cases, missing error handling, security
problems (secrets, injection, unsafe deserialization), missing tests, leftover
debug code (`print()`, `console.log`, `TODO`/`FIXME` without an issue ref),
and naming drift. Fix what you find and re-run verification. For each
out-of-scope problem, call the Skill tool with "issue-create" before opening
the PR: it searches the backlog first, and adding your findings to an
existing issue beats filing a near-duplicate. Done when you have read the
whole diff and every finding is fixed, filed, or commented onto the issue
that already tracks it.

## 3. Simplify

Call the Skill tool with "minimal-change" and hold the diff against its
ladder: could each addition be deleted, or replaced by existing code, the
standard library, a native platform feature, or an installed dependency?
Apply the cuts, keep everything under the skill's "Always keep", and mark any
deliberate shortcut in the skill's `shortcut:` format. Re-run verification
after any change. Done when every addition in the diff has been checked
against the ladder.

## 4. Organize commits

Look at what you have:

```bash
git log <base>..HEAD --oneline
git status
```

Group uncommitted work into logical commits (feature apart from tests,
refactoring apart from new behaviour), not one giant squash. If the existing
commits are already well organized, commit only what remains; if they are
messy (WIP, fixup), clean them up. Create each commit by calling the Skill
tool with "commit": it owns intentional staging, the uv.lock drift check for
Python+uv projects, the conventional message, and HEREDOC creation. Skip its
verification step unless code changed since step 1. Done when `git status` is
clean and every commit is a coherent unit.

## 5. Push and create the PR

```bash
git push -u origin <branch>
```

Call the Skill tool with "pr-body" for the body's shape (a visual summary,
before-and-after evidence, merge danger, test plan). Link the issue the branch
implements with `Closes #<issue>`, or `Refs #<issue>` when it only partly
addresses it: the agent review's spec pass checks the diff against the closing
issues, and without one it has only the PR description.

```bash
gh pr create --base <base> --title "feat(scope): short description" --body "$(cat <<'EOF'
<body in the pr-body shape, ending with the Closes line>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Done when the PR exists and you have printed its URL.

## 6. Wait for CI

```bash
<skill-dir>/poll-ci.sh <number> [timeout-seconds]
```

It waits up to 300s by default. Run it with Bash `timeout: 600000`, or
`timeout: 900000` with `poll-ci.sh <number> 720` for slow CI, so the script
and not the Bash tool decides when to give up and a timeout always produces
an explicit exit 2. Or run it with `run_in_background: true`: the Bash call
returns at once and you are re-invoked when the poll completes; read the
final output then.

| Exit | Meaning | Next |
| --- | --- | --- |
| 0 | All checks passed | Step 7 |
| 1 | A check failed or was cancelled | `gh run view <run-id> --log-failed`, fix, verify locally, commit specific files, push, re-poll |
| 2 | Script timeout: CI is still running or hasn't started (a queued run, a required check that hasn't reported, or a PR head GitHub hasn't updated after a push; the TIMEOUT line names which) | Re-poll; for a stale PR head, close and reopen the PR to resync it |
| 3 | The PR couldn't be read | Check the number and `gh auth status` |
| 4 | CI hasn't finished and the PR conflicts with its base, so GitHub won't run it (finished CI keeps its pass or fail) | Rebase onto the base, resolve, verify locally, push, re-poll; closing and reopening won't help |

Every terminal outcome ends with a `CI RESULT:` line. Output that ends on a
`CI POLL:` heartbeat means the process was killed mid-wait and CI state is
unknown: re-poll rather than reporting "waiting for the monitor" and
stopping. Fix failing CI in place on this PR rather than closing and reopening
it; close and reopen only to resync a stale PR head.

If you return from a scheduled wakeup or a task notification, follow
[resuming.md](resuming.md) before trusting anything the wakeup prompt says.

Done when the latest poll ends `CI RESULT:` with exit 0.

## 7. Agent review

Our own review is the gate. Outside reviewers are not guaranteed: many repos
have no required reviewers, and Copilot review is often requested by hand.
Step 2 was the implementer checking its own work; this step adds an
independent reader with a fresh context.

Call the Skill tool with "review-pr", passing the PR number and asking for
the agent review. On a PR you authored it acts as a self-review gate: the
`code-reviewer` agent runs a standards pass and a spec pass (against the
PR's linked issues) on `<base>...HEAD`, you fix the findings, and the outcome
is posted to the PR. When the fixes are pushed, wait for CI again (step 6) so
the summary reports CI for the reviewed code.

Done when the latest agent review has no BLOCKING findings, every finding has
an outcome, CI is green on the final push, and the PR carries an
`## Agent review` comment listing each finding and its outcome.

## 8. Outside reviews

```bash
ctx=$(<shared-scripts-dir>/resolve-github-context.sh <number>)
owner_repo=$(echo "$ctx" | jq -r '"\(.owner)/\(.repo)"')
<skill-dir>/poll-review.sh "$owner_repo" <number>
```

It queries review threads and review states through GraphQL, and waits only
when a review is actually expected: someone is in the PR's pending review
requests (up to its timeout), or Copilot reviews this repo's PRs
automatically (until Copilot lands, at most `POLL_REVIEW_COPILOT_WAIT`
seconds after the PR opened). Otherwise it returns `none` at once. When it
waits, give it an explicit Bash `timeout` above its own or run it in the
background, as in step 6, and on a wakeup or notification follow
[resuming.md](resuming.md). It prints exactly one state:

| State | Exit | Next |
| --- | --- | --- |
| `none` | 3 | Nothing from outside reviewers to act on: nobody was expected, or Copilot already reviewed and its threads are handled. Go to step 9 |
| `comments` / `changes-requested` | 0 | Call the Skill tool with "review-pr", asking it to address the feedback |
| `summary-only` | 0 | A COMMENTED review with no inline comments (common for Copilot follow-ups). Read the body, surface it, and act only on what the user agrees needs action |
| `approved` | 0 | Report it and go to step 9 |
| `timeout` | 2 | An expected reviewer (requested, or automatic Copilot) hasn't arrived. Report that the agent review is done and outside review is pending |
| `error` | 4 | The GitHub API kept failing; stderr has the details. Fix auth or the PR reference and re-run |

Read a `summary-only` body with:

```bash
gh api "repos/$owner_repo/pulls/<number>/reviews" \
  --jq '[.[] | select(.state == "COMMENTED" and .body != "")] | last | .body'
```

Done when the state is `none`, `approved`, or `timeout`; or it is
`summary-only` and the body has been surfaced and any agreed action taken;
or every outside comment has been answered through the review-pr skill; or
it is `error` and a re-run after fixing auth or the PR reference gave one of
those.

## 9. Summary

Report the PR URL, the number of commits, CI status, the agent review's
findings by severity with their outcomes, the outside-review state and any
comments addressed, and the current PR state. Done when the report is
printed.

## Related

- `/review-pr` — the agent review and addressing review feedback
- `/commit` — quality-gated conventional commits
- `/minimal-change` — the ladder step 3 applies
- `/pr-body` — the PR description shape step 5 uses
