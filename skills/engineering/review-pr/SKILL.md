---
name: review-pr
description: >-
  Reviews a pull request with two code-reviewer passes, standards and spec (on
  your own PR, as the gate before merge: fix the findings and record them), or
  works through unresolved review feedback on an existing PR: fix, commit,
  push, and reply in thread. Use when the user asks to review a PR or address
  review comments, and whenever the open-pr skill reaches its agent review or
  its outside reviews, or finds an open PR already exists.
argument-hint: "[PR number or URL]"
allowed-tools: Bash(gh pr *), Bash(gh api *), Bash(gh repo *), Bash(git status), Bash(git rev-parse *), Bash(git switch *), Bash(git diff *), Bash(git log *), Bash(git show *), Bash(git add *), Bash(git commit *), Bash(git push *), Bash(git rebase *), Bash(git stash *), Bash(git fetch *), Bash(git merge *), Bash(<skill-dir>/*), Bash(<shared-scripts-dir>/*), Read
---

# Review PR

Review a PR with a standards pass and a spec pass, or work through its
unresolved review feedback until every comment has a reply.

These hold for both modes:

- **Every finding and comment gets an outcome:** fixed, deferred to a tracked
  GitHub issue, or discussed with the reviewer. Review concerns are the point
  of review, so "not blocking", "acceptable given dataset size", or "good for
  future refinement" is not an outcome, and green CI or passing tests do not
  override a finding. If you think a finding is wrong, reply saying why.
  Merge only when every comment is resolved.
- **Leave automated findings to the automation.** Codecov, linters, type
  checkers, and CI already flag style, type, and coverage issues; mention one
  only to add context they lack.
- **Explain the impact, not just the change.** "This cuts the loop from O(n²)
  to O(n)" or "isolating the mutation makes it testable", not "break this
  into a function".
- **Fix checks at the cause.** `--no-verify`, `# noqa`, and `type: ignore`
  are not fixes.
- **Stage specific files by name**, never `git add -A` or `git add .`, and
  pass commit messages through a HEREDOC.

## 1. Pick the mode

```bash
gh pr view <PR#> --json state,reviews    # no number: the current branch's PR
```

Take the first that matches:

- **The caller asked for the agent review** (the open-pr skill does once CI
  passes) → [Agent review](#2-agent-review).
- **The caller asked to address feedback** (open-pr does when outside reviews
  arrive), or there are **unresolved comments**, or a **changes-requested**
  review (including one with only a body) →
  [Address feedback](#3-address-feedback).
- **Overall review only**: a reviewer's review is `COMMENTED` with no inline
  comments (`poll-review.sh` reports `summary-only`). Read the body with the
  command in step 3.1, surface it to the user, and stop; there is nothing to
  fix in a loop.
- **No reviews at all** → [Agent review](#2-agent-review).

Done when you have named the mode.

## 2. Agent review

Dispatch the `code-reviewer` agent twice, in parallel: a **standards pass**
(six dimensions, documented standards, smells, complexity) and a **spec pass**
against the issues the PR closes. Present the two reports side by side under
`## Standards` and `## Spec`, never merged or reranked: a change can follow
every standard and still build the wrong thing, or build exactly the right
thing badly.

- **Your own PR** (author matches `gh api user --jq .login`): this is the gate
  before merge. Fix or defer every finding, re-run the pass whose findings you
  fixed, and post an `## Agent review` comment with each finding's outcome.
- **Someone else's PR**: post one `gh pr review`, requesting changes if
  either axis has a BLOCKING finding.

Follow [agent-review.md](agent-review.md) for the fetch commands, the prompt
templates, the report layout, severity rules, the fix loop, and large PRs.
Done when neither report has an open BLOCKING finding and every finding has
an outcome (your own PR), or the review is posted (someone else's).

## 3. Address feedback

Fix, push, then reply to every comment, as one sequence: the replies are what
close the loop for reviewers, so the work isn't done at "pushed". If the PR
has merge conflicts or failing CI, sort those out first with
[recovery.md](recovery.md); merging the base can make comments obsolete.

### 3.0 Branch guard

Run this before fetching any comments: every later step assumes the working
tree is the PR's, and skipping it can push correct-looking fixes to the wrong
PR.

```bash
pr_branch=$(gh pr view <PR#> --json headRefName --jq .headRefName)
current=$(git rev-parse --abbrev-ref HEAD)
```

- **Same branch:** go on.
- **Different, working tree clean** (`git status --porcelain` empty): say
  `Switching from '<current>' to '<pr_branch>' to address PR #<PR#>`, then:

  ```bash
  git switch "$pr_branch"
  # if it doesn't exist locally:
  git fetch origin "$pr_branch" && git switch -c "$pr_branch" --track "origin/$pr_branch"
  ```

- **Different, working tree dirty:** stop without switching, stashing, or
  fetching comments, and tell the user:

  ```text
  PR #<PR#> is on branch '<pr_branch>' but you're on '<current>' with uncommitted changes.
  Commit or stash them, then run 'git switch <pr_branch>' (or re-run /review-pr <PR#>).
  ```

- **PR from a fork** (`gh pr view <PR#> --json headRepositoryOwner` differs
  from the repo owner): the flow above can't check it out; stop and tell the
  user to check it out explicitly (`gh pr checkout <PR#>`).

Done when the current branch is the PR's head branch.

### 3.1 Fetch unresolved comments

```bash
ctx=$(<shared-scripts-dir>/resolve-github-context.sh <PR#>)
owner_repo=$(echo "$ctx" | jq -r '"\(.owner)/\(.repo)"')
<skill-dir>/fetch-unresolved-comments.sh "$owner_repo" <PR#>
```

It returns a JSON array of unresolved comments (id, path, line, body,
author); resolved threads are already filtered out.

An empty array alongside review activity means a summary-only review: an
overall `COMMENTED` review with no inline action items. That isn't an error
or a fix loop. Read the body:

```bash
gh api "repos/<owner>/<repo>/pulls/<PR#>/reviews" \
  --jq '[.[] | select(.state == "COMMENTED" and .body != "")] | last | .body'
```

Present it to the user, decide together whether anything needs action (file
issues for deferred items), and stop there.

Done when you hold the list of unresolved comments.

### 3.2 Triage

Read the code each comment points at and classify it: **fix needed**,
**already fixed** in an earlier commit, or **acknowledge** (valid but
deferred, which needs a GitHub issue). Done when every comment has a class
and every deferral has an issue.

### 3.3 Fix

Make the changes, then discover the verification command and run what it
prints as a **separate** Bash call (`eval` in the same call defeats
`allowed-tools` matching and prompts):

```bash
<shared-scripts-dir>/discover-verification-cmd.sh
```

Done when verification passes in full.

### 3.4 Commit and push

`fixup-and-push.sh` stages only the files you pass, creates a `fixup!`
commit, autosquash-rebases onto the base, and force-pushes with a lease that
survives a GitHub "Update branch" merge. That keeps history clean, with no
"address review" commits. First apply the commit skill's uv.lock drift check:
if `uv.lock` has drifted, add it to the file list and warn the user, as that
skill prescribes.

```bash
# subject inferred from the latest non-merge, non-fixup commit in origin/<base>..HEAD
<skill-dir>/fixup-and-push.sh <baseRefName> <file1> <file2> ...
# or explicit:
<skill-dir>/fixup-and-push.sh <baseRefName> --subject "fix(scope): description" <file1> <file2> ...
```

If it reports `fixup!` commits that didn't squash, recover with
[recovery.md](recovery.md). Done when the script exits 0.

### 3.5 Reply to every comment

Reply on the PR where the fix landed: when fixes go in a follow-up PR, reply
on that PR's comments, and check the PR number before replying (a reply on
the wrong PR is invisible to reviewers). Reply only after the push, so each
reply confirms a live fix. The script checks that the comment belongs to the
PR before posting:

```bash
<shared-scripts-dir>/reply-to-comment.sh <owner>/<repo> <PR#> <comment_id> 'Fixed — [explanation]'
```

Use the shape that fits:

```text
Fixed — [what changed]. [If tests added: Also added tests for X.]
This was addressed in [commit hash] — [brief explanation].
Acknowledged — [reason for deferral]. Tracked in #NNN.
I wasn't able to reproduce this. Can you clarify [specific question]?
```

Done when every comment from 3.1 has a reply.

### 3.6 Resolve threads

Resolving clears the "changes requested" status:

```bash
resolved=$(<shared-scripts-dir>/resolve-all-threads.sh <owner>/<repo> <PR#>)
echo "Resolved $resolved review threads"
```

Done when the script reports the threads resolved.

### 3.7 Summary

Report comments fixed, acknowledged, and already fixed; threads resolved;
the verification result; and anything left unaddressed. Done when the report
is printed.

## Related

- `/code-reviewer` — the standards pass as a standalone review
- `/pr-comments` — a reply-only pass, the alternative to address feedback
- `/commit` — quality-gated conventional commits
- `code-reviewer` agent — runs both passes, spawned by this skill
