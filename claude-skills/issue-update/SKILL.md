---
name: issue-update
description: >-
  Updates an existing GitHub issue: edits the body, posts a comment, retags,
  or reopens, acknowledging stale framing instead of silently rewriting it, and
  previews before applying. Use when the user asks to update, comment on,
  relabel, or reopen an issue, or when a workflow needs to post a progress
  checkpoint to a tracking issue.
argument-hint: "<#> | reopen <#>"
allowed-tools: Bash(gh issue *), Bash(gh api *), Bash(gh label list*), Read
---

# Issue Update

Keep an issue accurate as understanding changes, without erasing the history
that produced it. A reader arriving cold should see the current truth; a
reader following the thread should see how it got there.

`<#>` updates an open issue; `reopen <#>` reopens a closed one with new
context.

## 1. Read the whole thread

```bash
gh issue view <#> --json title,body,state,labels,comments
```

The comments often hold the latest framing, so the body alone can mislead.
Note alternative approaches, corrections, `file:line` samples, cross-links,
and labels added after filing. `--json comments` returns at most the first
100; for a longer thread, fetch them all so a late change of framing isn't
missed:

```bash
gh api --paginate "repos/<owner>/<repo>/issues/<#>/comments"
```

Done when you've read every comment, and can say what the thread currently
believes.

## 2. Update an open issue

Pick the change:

| Situation | Action |
| --- | --- |
| The original framing is wrong | Edit the body **and** comment acknowledging the change |
| New information builds on the framing | Comment only |
| The body is wrong but its history should stay visible | Edit the body under a "Note:" header; the comment links to the old framing |
| Scope or priority shifted, the text is fine | Labels only |

When you correct framing, say what was wrong rather than rewriting silently.
Open the new body with a note, so cold readers know it's current, thread
readers see what shifted and why, and nobody re-litigates the original:

```markdown
> **Note:** Original framing assumed all suppliers had a stable `code` field.
> Corrected after #123: the field is nullable for legacy imports. Rewritten
> below.

## What
<corrected body>
```

Check labels against `gh label list`. For a label that doesn't exist, skip it
and suggest it in the comment ("Suggest adding an `area:foo` label; it
doesn't exist yet"). Leave `gh label create` to the maintainer, because the
label set is a repo-config decision.

If the thread surfaced related issues or PRs that don't link back, draft a
one-line cross-link comment for each of them too.

Show the user the drafted body, the comment, the label diff, and any
cross-link comments, and wait for confirmation: an edit can overwrite
framing. Then run only the commands that apply:

```bash
gh issue edit <#> --body "$(cat <<'EOF'
<new body>
EOF
)"
gh issue comment <#> --body "..."
gh issue edit <#> --add-label "..." --remove-label "..."
gh issue comment <related#> --body "Related: #<#> ..."   # per cross-link
```

Done when the confirmed changes are applied and every newly found related
issue or PR links both ways.

## 3. Reopen a closed issue

1. Confirm why it closed, from the thread: the resolution comment, a label,
   or the linked PR.
2. If a merged PR closed it but the problem persists (a regression, a partial
   fix, scope found after merge), read that PR's diff and comments to confirm
   what it actually shipped. When the gap has a different root cause, a fresh
   issue that links back is usually cleaner than a reopen: call the Skill tool
   with "issue-create" instead and stop here.
3. Draft a comment saying what changed and why the close was premature or no
   longer applies. After a merged PR, name the gap precisely: "PR #X shipped Y,
   but Z still reproduces because …".
4. Show the user the comment, and wait for confirmation. Reopen with the
   comment attached, so the reopen is never silent:

   ```bash
   gh issue reopen <#> --comment "..."
   ```

5. If the scope shifted, preview the label diff and apply it.

Done when the issue is open with a comment explaining why, and its labels
match its scope.

## Related

- `issue-create` — file a new issue.
- `issue-close` — close as resolved, superseded, or duplicate.
- `issue-restructure` — split or merge issues.
