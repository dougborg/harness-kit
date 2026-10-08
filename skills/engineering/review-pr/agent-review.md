# Agent review

The full agent-review workflow: two review passes in parallel, presented side
by side, then either posted (someone else's PR) or fixed (your own PR).

## Contents

- [1. Fetch the PR and its spec](#1-fetch-the-pr-and-its-spec)
- [2. Dispatch the two passes](#2-dispatch-the-two-passes)
- [3. Present the reports](#3-present-the-reports)
- [4. Act on the findings](#4-act-on-the-findings)
- [Large PRs](#large-prs)

## 1. Fetch the PR and its spec

```bash
<shared-scripts-dir>/pr-threads.sh <PR#> context
gh pr view <PR#> --json closingIssuesReferences --jq '.closingIssuesReferences[].number'
gh issue view <issue#> --comments
```

The spec is the bodies of the issues the PR closes. If it closes nothing, use
the PR description and say so in the review.

## 2. Dispatch the two passes

Dispatch the `code-reviewer` agent twice, in parallel where the host supports
subagents (Claude Code's Agent tool, Codex's spawned agents). Without
subagents, run the two passes one after the other, finishing the first report
before reading for the second.

Start each prompt with its pass name on the first line, so the agent knows
which one it is running:

```text
STANDARDS PASS
PR: [title, author, description, labels]
Diff: git diff <base>...HEAD
Existing comments: [any automated reviewer comments]
```

```text
SPEC PASS
PR: [title, author, description]
Diff: git diff <base>...HEAD
Spec: [the closing issues' bodies, or "PR description only"]
```

The standards pass gets no spec, so the two stay independent.

## 3. Present the reports

Put each report under its own heading; don't merge or rerank them:

```text
## Standards
Review Summary · BLOCKING · SUGGESTION · NITPICK · Complexity (C1., ...) · What Looks Good
## Spec
R1., R2., ... with severity and the quoted spec line (or "No spec available")
```

End with one line per axis: its finding count and its worst finding. Don't
pick a single winner across the two.

Severity: Complexity findings count as SUGGESTIONs; smell findings are
SUGGESTIONs or NITPICKs; Spec findings keep the severity the agent gave them.

## 4. Act on the findings

**Someone else's PR**: post one review. Request changes if either axis has a
BLOCKING finding; otherwise approve, or comment if there are only questions.

```bash
gh pr review <PR#> --request-changes --body-file <file>   # or --approve / --comment
```

**Your own PR**: this is the gate before merge, so the findings get fixed:

1. Fix every BLOCKING finding on either axis. Fix each SUGGESTION, or defer it
   to a GitHub issue after searching the backlog for an existing one. Fix each
   NITPICK or note in one line why not; nitpicks don't get issues.
2. Run the project's verification, commit specific files, and push.
3. If the fixes changed behaviour beyond the lines the findings named, re-run
   the pass whose findings you fixed (both if fixes touched both). Stop after
   two rounds and report anything still open.
4. Post one comment headed `## Agent review` (`gh pr comment <PR#>
   --body-file <file>`), so a resumed session can tell the gate ran: a table
   of each finding from both passes, its severity, and its outcome (the fixing
   commit, the deferral issue, or why no change). GitHub does not allow
   approving or requesting changes on your own PR.

Done when neither report has an open BLOCKING finding and every finding has
an outcome in the comment.

## Large PRs

For a PR with many files or thousands of lines:

1. Skip boilerplate: generated code, vendor updates, mass-refactor churn.
2. Sample by category: review logic changes, skip formatting-only files.
3. Take critical paths first: auth, payments, data mutation, API contracts.
4. If a full review would take over an hour, ask the author to split it.

Say what you covered and what you skipped:

```text
This PR is quite large (47 files, 2500 lines). I've reviewed:
- Core auth changes (critical path)
- Data mutation logic (sampled 5 files for pattern)
- Tests (coverage spot-check)

Blocked on: Vendor update changes (auto-generated, skipping).
Recommendation: For future PRs, split refactors by domain
(auth, API, database) for focused reviews.
```
