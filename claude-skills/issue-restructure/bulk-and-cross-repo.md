# Bulk merges and cross-repo restructures

Read this before merging more than five issues, or when a split or merge
spans repositories.

## Bulk merges

For a merge of more than five issues:

- Fetch comment threads with `gh api --paginate` so none are truncated.
- Batch the closes, and wait between API calls if you hit `403 rate limit`.
- Ask whether the merge hides a triage problem: if ten issues describe the
  same thing, the labelling or the issue template needs work. Say so to the
  user.

## Cross-repo split or merge

- Confirm both repos are accessible (`gh repo view <owner>/<repo>`).
- Use full `owner/repo#N` references in both directions.
- Close across repos with `gh issue close --repo <owner>/<repo> <#>`.
- Watch for links into a private repo that readers of the other side can't
  open.
