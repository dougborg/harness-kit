---
name: issue-create
description: >-
  Files a new GitHub issue: searches for duplicates, picks focused vs umbrella
  scope, applies real labels, and previews before posting. Use when the user
  asks to file, open, or track an issue, and when another workflow needs to
  record deferred work, a bug found mid-task, or a follow-up as an issue.
allowed-tools: Bash(gh issue *), Bash(gh search *), Bash(gh label list*), Read
---

# Issue Create

File one issue without fragmenting a discussion that already exists. The user
sees the title, body, and labels before anything is posted.

## 1. Search for duplicates

```bash
gh search issues "<keywords>" --repo <owner>/<repo>
gh issue list --repo <owner>/<repo> --search "<keywords>" --state all
```

Read each candidate's body and comments; a title alone misleads.

- **Same work:** comment on it with your context and a cross-link instead,
  after showing the user that comment, and stop. Fragmenting discussion
  across near-duplicates costs more than over-linking.
- **Adjacent but distinct:** file the new issue and cross-link both
  directions.
- **Unclear:** show both to the user and ask.

When the caller names an issue as a known source (an issue being split, say),
it is adjacent by definition: link it, and file.

Done when every candidate is classed as same, adjacent, or unrelated.

## 2. Decide scope

File **focused** by default: one fix, one file or tight area, one PR closes
it. File an **umbrella**, tracked with checkboxes, when the work spans three
or more files or domains, you expect two or more PRs against it, or triage
needs a single anchor for related conversations. When in doubt, file focused:
splitting an umbrella later is cheap, and so is merging focused issues (the
issue-restructure skill, which the user runs).

Done when you can say which shape this is and why.

## 3. Pick labels

```bash
gh label list --repo <owner>/<repo>
```

Apply kind (`bug`, `enhancement`, `chore`), area, and priority (`p0`–`p3`)
from labels that exist. When none fits, file without it and add a line to the
body: "No `area:*` label exists yet; suggest creating one." Leave
`gh label create` to the maintainer, because the label set is a repo-config
decision.

Done when every label you plan to apply appears in `gh label list`.

## 4. Draft and preview

Write the body: context, current behaviour, expected behaviour, `file:line`
references, and cross-links to related issues and PRs. For each adjacent
issue from step 1, draft the one-line comment that will link it back to the
new issue. Show the user the title, body, labels, and those link-back
comments.

Done when the user confirms the draft.

## 5. File

```bash
gh issue create --repo <owner>/<repo> --title "..." --body "..." --label "..."
gh issue comment <adjacent#> --repo <owner>/<repo> --body "Related: #<new>"   # per adjacent issue
```

Done when you've printed the new issue's URL, and every adjacent issue from
step 1 links back to it.

## Related

- `issue-close` — close as resolved, superseded, or duplicate.
- `issue-update` — edit the body or labels, comment, reopen.
- `issue-restructure` — split one issue into many, or merge many into one.
- `harness-issue` — file upstream against harness-kit specifically.
