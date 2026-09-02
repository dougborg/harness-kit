---
name: review-pr
description: >-
  Reviews a pull request across six dimensions, or works through unresolved
  review feedback on an existing PR — fix, commit, push, and reply in thread.
when_to_use: >-
  When the user asks to review a PR or address review comments, and whenever
  /open-pr reaches its review-comment phase or finds an open PR already exists.
argument-hint: "[PR number or URL]"
allowed-tools: Bash(gh pr *), Bash(gh api *), Bash(gh repo *), Bash(git status), Bash(git rev-parse *), Bash(git switch *), Bash(git diff *), Bash(git log *), Bash(git show *), Bash(git add *), Bash(git commit *), Bash(git push *), Bash(git rebase *), Bash(git stash *), Bash(git fetch *), Bash(git merge *), Bash(${CLAUDE_SKILL_DIR}/*), Bash(${CLAUDE_SKILL_DIR}/*), Read
---

# /review-pr — Structured PR Review

Review a PR using 6 dimensions or address unresolved review feedback systematically.

## PURPOSE

Analyze code changes thoroughly and respond to review comments without missing issues or duplicating automated findings.

## CRITICAL

- **Never dismiss review findings** — Code quality concerns are the entire point of code review. Never rationalize skipping them ("not blocking", "acceptable given dataset size", "good for future refinement"). Every finding gets fixed, deferred with a tracked issue, or explicitly discussed with the reviewer. "CI is green" and "tests pass" do not override review feedback. Merging with unaddressed findings is forbidden.
- **Never merge without addressing all comments** — Every comment must be resolved (fixed, acknowledged with issue link, or discussed) before merging. No exceptions. If you think a finding is wrong, reply explaining why — don't silently skip it.
- **Never duplicate automated findings** — Codecov, linters, type checkers, and CI checks already flag style/type/coverage issues. Skip these unless adding important context.
- **Explain the "why", not just the "what"** — Comments like "break this into a function" are weak. Explain impact: "This reduces complexity from O(n²) to O(n)" or "Improves testability by isolating mutation logic."
- **Use the review prompt template** (in DETAIL) for consistency across reviews
- **Reply to EVERY comment — automatically** — Fix → push → reply is ONE atomic sequence. Never stop after pushing. The replies are what close the loop for reviewers. Nothing left hanging or unaddressed.
- **Fix first, reply after push** — Confirm the fix is live before responding. But never stop at "fix pushed" — the replies are mandatory, not a follow-up task.
- **Reply to the correct PR** — When fixes are made in a follow-up PR, reply on THAT PR's comments, not the original. When fetching review comments or selecting comment IDs (e.g., via `gh pr view` or `gh api repos/{owner}/{repo}/pulls/{number}/comments`), always verify the PR number matches the PR you're actually working on. Replying to the wrong PR is invisible to reviewers and leaves the actual PR unaddressed.

## ASSUMES

- You have GitHub CLI (`gh`) installed and authenticated
- The PR exists and is accessible to you
- Project has a verification command (test suite, linter, type checker)

## STANDARD PATH

### 1. Identify PR and Mode

```bash
/review-pr [PR#]                    # Or: /review-pr (current branch)
gh pr view <PR#> --json state,reviews
```

- **No review comments** → Mode A: Initial review (analyze with code-reviewer agent)
- **Unresolved comments** → Mode B: Address feedback (fix issues, validate, reply)
- **Overall review only** (a reviewer's review has state `COMMENTED` but zero inline comments — `poll-review.sh` reports `summary-only`) → read the review body, surface it to the user, and stop. There are no comments to address, so do NOT run the Mode B fix loop. See DETAIL: Mode B Workflow, "Summary-only reviews".

### 2. Mode A: Initial Review

```bash
gh pr view <PR#> --json title,body,diff
[Invoke code-reviewer agent with PR context]
Organize findings: BLOCKING → SUGGESTION → NITPICK
Post structured review via gh pr review
```

### 3. Mode B: Address Feedback

```bash
0. Branch guard: verify current branch == PR head branch (auto-switch if clean, STOP if dirty)
[For each unresolved comment]
1. Read affected code
2. Fix or acknowledge
3. Run project verification (test suite, lint, type-check)
4. Commit, push
5. Reply to EVERY comment in-thread (this step is NOT optional)
```

**Steps 4-5 are atomic.** Never finish at "pushed fixes" — always continue to reply to every comment before reporting done. See DETAIL: Mode B Workflow.

## EDGE CASES

- [Large PRs with many files] — Read DETAIL: Handling Large PRs (sample files, skip boilerplate)
- [Merge conflicts during review] — Read DETAIL: Conflict Resolution (fetch base, merge, resolve)
- [CI failures blocking review] — Read DETAIL: CI Failures (distinguish code vs. infrastructure issues)
- [Review prompt template] — Read DETAIL: Review Prompt Template (consistency guide)
- [Responding to comments] — Read DETAIL: Comment Response Format (fix/deferred/already-fixed patterns)

---

## DETAIL: Handling Large PRs

For PRs with many changed files or thousands of lines:

1. **Skip boilerplate** — Auto-generated code, vendor updates, large diffs from mass refactoring
2. **Sample by category** — Review logic changes, skip formatting-only files
3. **Focus on critical paths** — Auth, payments, data mutation, API contracts first
4. **Ask for split if necessary** — If review is >1 hour, ask author to break into smaller PRs

**Example:**

```text
This PR is quite large (47 files, 2500 lines). I've reviewed:
- Core auth changes (critical path)
- Data mutation logic (sampled 5 files for pattern)
- Tests (coverage spot-check)

Blocked on: Vendor update changes (auto-generated, skipping).
Recommendation: For future PRs, split refactors by domain
(auth, API, database) for focused reviews.
```

---

## DETAIL: Conflict Resolution

If the PR has merge conflicts:

```bash
git fetch origin <baseRefName>
git merge origin/<baseRefName>
# Resolve conflicts manually
git add <resolved-files>
git commit -m "Merge branch 'origin/<baseRefName>'"
```

Then resume review-addressing workflow. **Conflicts can invalidate prior comments** — recheck affected sections.

---

## DETAIL: CI Failures

Check CI status before responding to review comments:

```bash
gh pr view {number} --json mergeable,mergeStateStatus
gh pr checks {number}
```

**If code-related** (lint, type, test failure):

1. Fix immediately
2. Run project verification locally
3. Commit, rebase, push

**If infrastructure-related** (flaky CI, timeout, infrastructure issue):

1. Document in response
2. Don't block on it
3. Link to infrastructure ticket if available

**Always resolve conflicts and build failures before addressing review comments** — they may no longer apply after merging base branch.

---

## DETAIL: Review Prompt Template

Use this structure for consistent, thorough reviews (avoid repeating automated findings):

```markdown
# Review: [PR Title]

## What This Changes

[1-2 sentences summarizing the change and its impact]

## 6-Dimensional Analysis

### ✅ Correctness
- [Semantic correctness, type safety, logic]
- [Any potential bugs or edge cases]

### ✅ Design
- [Architecture, interfaces, patterns vs. project conventions]
- [Trade-offs and alternatives considered?]

### ✅ Readability
- [Naming clarity, documentation, code flow]
- [Any confusing sections?]

### ✅ Performance
- [Efficiency, algorithms, resource usage]
- [Any obvious optimizations possible?]

### ✅ Testing
- [Test coverage for new code]
- [Edge cases and error conditions covered?]

### ✅ Security
- [Input validation, auth, secrets, injection risks]
- [Any exposed internals or vulnerabilities?]

## Findings

### 🚫 BLOCKING (must fix before merge)
[Only items that break functionality or violate critical constraints]

### ⚠️ SUGGESTION (worth addressing)
[Improvements that enhance quality, maintainability, or safety]

### 💬 NITPICK (nice-to-have)
[Style, naming, minor clarity suggestions]

### ✨ What Looks Good
[Highlight strong aspects: good patterns, clever solutions, solid testing]

## Summary
- Verdict: Approved / Changes requested / Comment
- Ready to merge after addressing blocking items
```

---

## DETAIL: Comment Response Format

Reply to each comment with one of these patterns:

### Fix Implemented

```text
Fixed — [describe what changed].
[If tests added: Also added tests for X].
```

### Already Fixed in Prior Commit

```text
This was addressed in [commit hash] — [brief explanation].
```

### Acknowledged but Deferred

```text
Acknowledged — [reason for deferral].
Tracked in #NNN [link to GitHub issue].
```

### Cannot Reproduce or Misunderstanding

```text
I wasn't able to reproduce this. Can you clarify [specific question]?
```

---

## DETAIL: Mode A Workflow

Initial PR review (no comments yet).

### 1. Fetch PR Context

```bash
ctx=$(${CLAUDE_SKILL_DIR}/resolve-github-context.sh <PR#>)
owner_repo=$(echo "$ctx" | jq -r '"\(.owner)/\(.repo)"')
${CLAUDE_SKILL_DIR}/fetch-pr-context.sh "$owner_repo" <PR#>
```

### 2. Invoke code-reviewer Agent

Pass compiled context:

```text
PR Title: [title]
Author: [author]
Description: [body]
Labels: [labels]
Diff: [patch]
Existing Comments: [any automated reviewer comments]
```

Agent returns: 6D analysis + findings organized by severity.

### 3. Present Findings

```text
BLOCKING: [list items that must be fixed]
SUGGESTION: [list improvements]
NITPICK: [list nice-to-haves]
✨ What Looks Good: [highlight strengths]
```

### 4. Post Review

```bash
gh pr review <PR#> --approve    # or --request-changes / --comment
```

---

## DETAIL: Mode B Workflow

Address unresolved review feedback.

### 0. Branch Guard: Ensure You're on the PR's Head Branch

**Run this BEFORE fetching any comments.** Every later Mode B step assumes the local working tree matches the PR — skipping this check can produce successfully-pushed wrong fixes on the wrong PR.

```bash
pr_branch=$(gh pr view {number} --json headRefName --jq .headRefName)
current=$(git rev-parse --abbrev-ref HEAD)
```

- **If `$pr_branch` == `$current`** — proceed to step 1.
- **If they differ and the working tree is clean** (`git status --porcelain` is empty) — auto-switch. Print what you're doing first, e.g. `Switching from '<current>' to '<pr_branch>' to address PR #{number}`, then:

  ```bash
  git switch "$pr_branch"
  # If the branch doesn't exist locally:
  git fetch origin "$pr_branch" && git switch -c "$pr_branch" --track "origin/$pr_branch"
  ```

- **If they differ and the working tree is dirty** — STOP. Do not switch, do not stash, do not fetch comments. Tell the user:

  ```text
  PR #{number} is on branch '<pr_branch>' but you're on '<current>' with uncommitted changes.
  Commit or stash them, then run 'git switch <pr_branch>' (or re-run /review-pr {number}).
  ```

- **If the PR is from a fork** (`gh pr view {number} --json headRepositoryOwner` differs from the repo owner) — the local checkout flow above won't work; STOP and tell the user to check the fork branch out explicitly (e.g. `gh pr checkout {number}`).

### 1. Fetch Unresolved Comments

```bash
ctx=$(${CLAUDE_SKILL_DIR}/resolve-github-context.sh {number})
owner_repo=$(echo "$ctx" | jq -r '"\(.owner)/\(.repo)"')
${CLAUDE_SKILL_DIR}/fetch-unresolved-comments.sh "$owner_repo" {number}
```

Returns JSON array of unresolved comments with id, path, line, body, author. Resolved threads are already filtered out.

#### Summary-only reviews (empty array with review activity)

If the array is empty but a reviewer did post a review — e.g. `/open-pr` Phase 7 returned `summary-only` — the reviewer left only an overall `COMMENTED` review with no inline action items. This is not an error and not a fix loop:

```bash
gh api "repos/{owner}/{repo}/pulls/{number}/reviews" \
  --jq '[.[] | select(.state == "COMMENTED" and .body != "")] | last | .body'
```

Read the body, present it to the user, and decide together whether anything needs action (file issues for deferred items). Then stop — do not proceed to steps 2–6.

### 2. Triage Each Comment

Read affected code. Classify:

- **fix needed** — code change required
- **already fixed** — issue addressed in prior commit
- **acknowledge** — valid point but deferring (must file GitHub issue)

### 3. Fix All Issues

Make code changes. Validate:

```bash
${CLAUDE_SKILL_DIR}/discover-verification-cmd.sh
```

Run the command it prints as a **separate** Bash call — ALL must pass. Never
`eval` it in the same call; that defeats `allowed-tools` matching and prompts.

### 4. Commit, Rebase, and Push

Use the fixup-and-push script (stages, creates fixup commit, autosquash rebases, force-pushes).

**First, run `/commit`'s uv.lock drift check** (STANDARD PATH step 2 / DETAIL: uv.lock Drift in `skills/commit/SKILL.md`) — the script stages only the files you pass it, so if `uv.lock` has drifted, add it to the file list below and warn the user, exactly as `/commit` prescribes.

```bash
# Subject is now optional — inferred from the latest non-merge, non-fixup
# commit in `origin/<baseRefName>..HEAD`. Pass `--subject "..."` to override.
${CLAUDE_SKILL_DIR}/fixup-and-push.sh <baseRefName> <file1> <file2> ...
# or explicit:
${CLAUDE_SKILL_DIR}/fixup-and-push.sh <baseRefName> --subject "fix(scope): description" <file1> <file2> ...
```

(If autosquash silently fails to squash — leaving a dangling `fixup!` commit on the branch — see [DETAIL: Manual Recovery from Autosquash No-op](#detail-manual-recovery-from-autosquash-no-op) below.)

### 5. Reply to Each Comment (After Push)

**Verify the PR number first** — confirm you're replying on the correct PR (e.g., via `gh pr view` or the web UI). If fixes were made in a follow-up PR, reply on that PR, not the original.

Use the reply script — it validates the comment belongs to the correct PR before posting:

```bash
${CLAUDE_SKILL_DIR}/reply-to-comment.sh {owner}/{repo} {number} {comment_id} 'Fixed — [explanation]'
```

**Never reply before pushing** — replies confirm fix is live.

### 6. Resolve Review Threads

After replying to all comments, resolve all review threads to clear the "changes requested" status:

```bash
resolved=$(${CLAUDE_SKILL_DIR}/resolve-all-threads.sh {owner}/{repo} {number})
echo "Resolved $resolved review threads"
```

### 7. Summary

Print results:

- Fixed: X comments
- Acknowledged: Y comments
- Already fixed: Z comments
- Threads resolved: X
- Validation: PASSED/FAILED
- Any unaddressed items

---

## DETAIL: Manual Recovery from Autosquash No-op

### When This Happens

`fixup-and-push.sh` creates a `fixup! <subject>` commit and then runs `git rebase --autosquash origin/<base>`. Autosquash only squashes when a commit matching `<subject>` exists **within the rebase range** (i.e., on the feature branch, not yet on the base). If the matching commit was already merged to base — or the subject collides with a base-branch commit — autosquash silently does nothing: the rebase reports success, but the `fixup!` commit remains as a dangling commit on the branch. CI sees an unsquashed `fixup!` commit and history reviewers see noise.

Tracked as dougborg/harness-kit#40 (detect-and-infer fix coming to `fixup-and-push.sh`); the companion `fetch-unresolved-comments.sh` thread-selection bug was #41 (already fixed).

### Recovery Procedure

```bash
# Recover from autosquash no-op by manually squashing the fixup commit.
# Two gotchas:
#   1. Use `env` so GIT_SEQUENCE_EDITOR is exported portably across shells.
#   2. The rebase-todo line format varies (`pick <sha> <subject>` is the
#      default; some configs emit `pick <sha> # <subject>`). Match any
#      `pick` line containing `fixup!` so the script works regardless.
cat > /tmp/squash-fixup.sh <<'SH'
#!/bin/bash
sed -i.bak '/fixup!/s/^pick /fixup /' "$1"
SH
chmod +x /tmp/squash-fixup.sh
env GIT_SEQUENCE_EDITOR=/tmp/squash-fixup.sh git rebase -i origin/<base>
```

### Why These Two Details Matter

- **`env GIT_SEQUENCE_EDITOR=...`** — The shell-inline `VAR=value command` form is fragile across shells and certain wrapper setups. Using `env` is portable and always exports the variable correctly to the child process.
- **Why the flexible sed pattern?** — `git rebase -i`'s todo format varies (`pick <sha> <subject>` is the default, but some configs emit `pick <sha> # <subject>` with a separator). A pattern that matches any `pick` line containing `fixup!` works regardless of the format — and is harder to silently no-op than a tighter regex tied to one shape.

### Verification

After the rebase completes, confirm no `fixup!` commits remain on the branch:

```bash
git log origin/<base>..HEAD --format=%s | grep -c '^fixup!' || true
# Expected: 0
```

If the count is nonzero, the script didn't match — re-check the sed pattern against `git log --format='%s' | head` and rerun.

---

## IMPORTANT RULES

- **Never dismiss findings** — Every review finding gets fixed or deferred with an issue. Never rationalize merging with unaddressed comments.
- **Never merge with open comments** — All comments resolved before merge. No exceptions.
- **Never duplicate automated findings** — Linters, type checkers, CI checks already flag these
- **Explain the why** — Don't just say "improve this", explain impact (perf, complexity, testability)
- **Reply to every comment — automatically** — Push + reply is atomic. Never stop at "pushed". Nothing left hanging.
- **Fix first, reply after** — Push must complete before replying. But replying is mandatory, not a separate task.
- **Clean history** — Use fixup + autosquash, no "address review" commits
- **No shortcuts** — Never use `--no-verify`, `# noqa`, `type: ignore`
- **Deferred work needs issues** — Acknowledged items must link to `gh issue create` ticket
- **Stage specific files** — Never `git add -A` or `git add .`
- **Use HEREDOC** — Pass commit messages via HEREDOC (not inline)

---

## RELATED

- `/code-reviewer` — 6-dimensional review reference
- `/pr-comments` — Systematic reply workflow (alternative to this skill's Mode B)
- `/commit` — Quality-gated conventional commits
- `code-reviewer` agent — Automated 6D analysis (spawned by this skill)
