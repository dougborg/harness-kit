---
name: review-pr
description: Review and address PR feedback using 6-dimensional code review
argument-hint: "[PR number or URL]"
model: haiku
allowed-tools: Bash(gh pr *), Bash(gh api *), Bash(gh repo *), Bash(git status), Bash(git diff *), Bash(git log *), Bash(git show *), Bash(git add *), Bash(git commit *), Bash(git push *), Bash(git rebase *), Bash(git stash *), Bash(git fetch *), Bash(git merge *), Bash(${CLAUDE_PLUGIN_ROOT}/skills/review-pr/*), Bash(${CLAUDE_PLUGIN_ROOT}/skills/shared/*), Bash(${CLAUDE_PLUGIN_ROOT}/skills/pr-comments/reply-to-comment.sh*), Read
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
```text

- **No review comments** → Mode A: Initial review (analyze with code-reviewer agent)
- **Unresolved comments** → Mode B: Address feedback (fix issues, validate, reply)

### 2. Mode A: Initial Review

```bash
gh pr view <PR#> --json title,body,diff
[Invoke code-reviewer agent with PR context]
Organize findings: BLOCKING → SUGGESTION → NITPICK
Post structured review via gh pr review
```text

### 3. Mode B: Address Feedback

```bash
[For each unresolved comment]
1. Read affected code
2. Fix or acknowledge
3. Run project verification (test suite, lint, type-check)
4. Commit, push
5. Reply to EVERY comment in-thread (this step is NOT optional)
```text

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
```text

---

## DETAIL: Conflict Resolution

If the PR has merge conflicts:

```bash
git fetch origin <baseRefName>
git merge origin/<baseRefName>
# Resolve conflicts manually
git add <resolved-files>
git commit -m "Merge branch 'origin/<baseRefName>'"
```text

Then resume review-addressing workflow. **Conflicts can invalidate prior comments** — recheck affected sections.

---

## DETAIL: CI Failures

Check CI status before responding to review comments:

```bash
gh pr view {number} --json mergeable,mergeStateStatus
gh pr checks {number}
```text

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
```text

---

## DETAIL: Comment Response Format

Reply to each comment with one of these patterns:

### Fix Implemented

```text
Fixed — [describe what changed].
[If tests added: Also added tests for X].
```text

### Already Fixed in Prior Commit

```text
This was addressed in [commit hash] — [brief explanation].
```text

### Acknowledged but Deferred

```text
Acknowledged — [reason for deferral].
Tracked in #NNN [link to GitHub issue].
```text

### Cannot Reproduce or Misunderstanding

```text
I wasn't able to reproduce this. Can you clarify [specific question]?
```text

---

## DETAIL: Mode A Workflow

Initial PR review (no comments yet).

### 1. Fetch PR Context

```bash
ctx=$(${CLAUDE_PLUGIN_ROOT}/skills/shared/resolve-github-context.sh <PR#>)
owner_repo=$(echo "$ctx" | jq -r '"\(.owner)/\(.repo)"')
${CLAUDE_PLUGIN_ROOT}/skills/shared/fetch-pr-context.sh "$owner_repo" <PR#>
```text

### 2. Invoke code-reviewer Agent

Pass compiled context:

```text
PR Title: [title]
Author: [author]
Description: [body]
Labels: [labels]
Diff: [patch]
Existing Comments: [any automated reviewer comments]
```text

Agent returns: 6D analysis + findings organized by severity.

### 3. Present Findings

```text
BLOCKING: [list items that must be fixed]
SUGGESTION: [list improvements]
NITPICK: [list nice-to-haves]
✨ What Looks Good: [highlight strengths]
```text

### 4. Post Review

```bash
gh pr review <PR#> --approve    # or --request-changes / --comment
```text

---

## DETAIL: Mode B Workflow

Address unresolved review feedback.

### 1. Fetch Unresolved Comments

```bash
ctx=$(${CLAUDE_PLUGIN_ROOT}/skills/shared/resolve-github-context.sh {number})
owner_repo=$(echo "$ctx" | jq -r '"\(.owner)/\(.repo)"')
${CLAUDE_PLUGIN_ROOT}/skills/review-pr/fetch-unresolved-comments.sh "$owner_repo" {number}
```

Returns JSON array of unresolved comments with id, path, body, author. Resolved threads are already filtered out.

### 2. Triage Each Comment

Read affected code. Classify:

- **fix needed** — code change required
- **already fixed** — issue addressed in prior commit
- **acknowledge** — valid point but deferring (must file GitHub issue)

### 3. Fix All Issues

Make code changes. Validate:

```bash
cmd=$(${CLAUDE_PLUGIN_ROOT}/skills/shared/discover-verification-cmd.sh)
eval "$cmd"   # ALL must pass
```text

### 4. Commit, Rebase, and Push

Use the fixup-and-push script (stages, creates fixup commit, autosquash rebases, force-pushes):

```bash
${CLAUDE_PLUGIN_ROOT}/skills/review-pr/fixup-and-push.sh <baseRefName> "original commit subject" <file1> <file2> ...
```text

### 5. Reply to Each Comment (After Push)

**Verify the PR number first** — confirm you're replying on the correct PR (e.g., via `gh pr view` or the web UI). If fixes were made in a follow-up PR, reply on that PR, not the original.

Use the reply script — it validates the comment belongs to the correct PR before posting:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/pr-comments/reply-to-comment.sh {owner}/{repo} {number} {comment_id} 'Fixed — [explanation]'
```text

**Never reply before pushing** — replies confirm fix is live.

### 6. Resolve Review Threads

After replying to all comments, resolve all review threads to clear the "changes requested" status:

```bash
resolved=$(${CLAUDE_PLUGIN_ROOT}/skills/shared/resolve-all-threads.sh {owner}/{repo} {number})
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
