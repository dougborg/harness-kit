---
name: issue-restructure
description: >-
  Restructure the topology of GitHub issues — split one into many focused
  replacements, or merge multiple into one keeper. Migrates substance and
  cross-links before closing anything.
argument-hint: "split <#> | merge <#> <#> [#...]"
disable-model-invocation: true
allowed-tools: Bash(gh issue *), Bash(gh api *), Bash(gh repo *), Bash(gh label *), Read, Edit, Write
---

# /issue-restructure — Split or Merge Issues

Change issue topology: one → many (`split`) or many → one (`merge`). Both modes migrate substance before closing.

## PURPOSE

Reshape how issues partition the work, without losing the comment-thread substance that the original partition produced.

## CRITICAL

- **Pre-flight body + comments on every issue involved** — comments often carry the latest framing the body alone misses. `gh issue view --json comments` returns the first 100 comments; paginate via `gh api` for longer threads (see pre-flight note) — especially relevant during bulk merges.
- **Migrate substance before destroying context** — never close a source issue until its comment-thread contributions are mined and moved to the keeper(s).
- **Preview to user before filing or closing** — show titles, bodies, label sets. No silent restructures.
- **Cross-link both directions** — every keeper references its sources; every source references its keeper(s).

## ASSUMES

- `gh` CLI authenticated; all referenced issue numbers accessible.
- For `merge` of >5 issues, `gh api --paginate` is usable (rate-limit aware).

## STANDARD PATH

### 1. Pre-flight every involved issue

```bash
gh issue view <#> --json title,body,state,labels,comments
```

For `split`: pre-flight `<#>`. For `merge`: pre-flight all `<#>`s. See DETAIL: What To Mine From Comments.

> **Note:** `gh issue view --json comments` returns at most the first 100 comments. For long threads (or any `merge` of >5 issues), paginate via
> `gh api /repos/<owner>/<repo>/issues/<#>/comments?per_page=100&page=N` (or `gh api --paginate`) — see DETAIL: Bulk Merges.

### 2. Pick the mode

| Arg form | Mode |
| --- | --- |
| `split <#>` | one issue → multiple focused replacements |
| `merge <#> <#> [#...]` | multiple issues → one keeper |

### 3. Mode: split

1. Confirm `<#>` genuinely covers separable work. If not, this is `/issue-update`, not split.
2. Draft N focused replacements; each gets a clear title, scope, and back-link to `<#>`.
3. Preview all replacements to the user. Wait for confirmation. See DETAIL: Split Preview Format.
4. File replacements via `/issue-create` (same discipline: dedupe search, labels, preview).
5. Update `<#>` — edit body to add "Split into #A, #B, #C" header, then close:

   ```bash
   gh issue close <#> --comment "Split into #A / #B / #C — see body for scope each covers."
   ```

### 4. Mode: merge

Inverse of split. Treats each non-keeper as a `supersede` against the chosen keeper.

1. Pick the keeper — most discussion, broadest scope, or most active. See DETAIL: Choosing the Keeper.
2. Mine each non-keeper's body + comments for substance not in the keeper.
3. Post **one** consolidated migration comment on the keeper, grouping migrated content by source issue.
4. Close each non-keeper:

   ```bash
   gh issue close <non-keeper#> --comment "Merged into #<keeper>. <pointer to specific section of migration comment>"
   ```

5. Update keeper labels if its scope grew.

## EDGE CASES

- [`<#>` doesn't actually cover separable work] — read DETAIL: When Not To Split
- [No clear keeper among merge candidates] — read DETAIL: Choosing the Keeper
- [>5 issues in a merge — rate limits] — read DETAIL: Bulk Merges
- [Cross-repo split or merge] — read DETAIL: Cross-Repo Restructure

---

## DETAIL: What To Mine From Comments

For each pre-flighted issue, scan for:

- Alternative approaches / options proposed in replies
- Post-filing corrections ("this was wrong, the real issue is …")
- File:line samples added later
- Cross-links to other issues / PRs
- Labels added by triagers that hint at scope

Every item that isn't already on the keeper(s) is a migration candidate.

---

## DETAIL: Split Preview Format

Before filing any replacement, show the user:

```text
Splitting #<src> into:

  #A: <title>
      Scope: <one sentence>
      Labels: <list>

  #B: <title>
      Scope: <one sentence>
      Labels: <list>

  #C: ...

#<src> will be closed with: "Split into #A / #B / #C — ..."
Original body will be edited to point to replacements.
```

Wait for explicit confirmation. Then file in order via `/issue-create`.

---

## DETAIL: When Not To Split

Don't split if:

- The replacements all share a single PR's worth of work — that's one issue.
- The user wants to track sub-tasks — use checkboxes in the body instead.
- The "separate" pieces all depend on the same upstream decision — keep one issue, list the options.

Splitting fragments discussion. Reserve it for genuinely independent work streams.

---

## DETAIL: Choosing the Keeper

When merging, pick the keeper by (in order):

1. **Broadest accurate scope** — the issue whose framing already covers the others.
2. **Most discussion** — preserves the longest comment thread without migration.
3. **Most recent activity** — readers expect current issues to be active.
4. **Lowest issue number** — tiebreaker; older is more canonical.

If no clear keeper exists, the issues probably shouldn't be merged — file a new umbrella via `/issue-create` and supersede each via `/issue-close` instead.

---

## DETAIL: Bulk Merges

For `merge` of >5 issues:

- Use `gh api --paginate` when fetching comment threads to avoid truncation.
- Batch the close operations; insert explicit waits between API calls if you hit `403 rate limit`.
- Consider whether the bulk-merge is hiding a triage problem — if 10 issues describe the same thing, the labeling / template needs work.

---

## DETAIL: Cross-Repo Restructure

Split or merge across repos:

- Confirm both repos are accessible (`gh repo view`).
- Use full `owner/repo#N` references in both directions.
- Cross-repo close is `gh issue close --repo <owner>/<repo> <#>`.
- Watch for private-repo links the other side can't read.

## RELATED

- `/issue-create` — Used inside `split` to file replacements.
- `/issue-close` — `supersede` and `dedupe` modes are the building blocks `merge` reuses.
- `/issue-update` — Use this instead of `split` when the issue just needs reframing.
