---
name: issue-restructure
description: Split one GitHub issue into focused replacements, or merge several into one keeper, migrating substance before closing.
argument-hint: "split <#> | merge <#> <#> [#...]"
allowed-tools: Bash(gh issue *), Bash(gh api *), Bash(gh repo *), Bash(gh label *), Read, Edit, Write
---

# Issue Restructure

Change how issues partition the work: one into many (`split`) or many into one
(`merge`), without losing the comment-thread substance the old partition
produced. Both modes migrate before they close, the user previews every title,
body, and label set before anything is filed or closed, and every keeper and
source end up linking to each other.

## 1. Read every involved issue

```bash
gh issue view <#> --json title,body,state,labels,comments
```

For `split`, read `<#>`; for `merge`, read all of them. The comments often
hold the latest framing the body misses. From each, collect what isn't
already on the keeper or replacements:

- alternative approaches proposed in replies;
- corrections after filing ("this was wrong, the real issue is …");
- `file:line` samples added later;
- cross-links to other issues and PRs;
- labels triagers added after filing that hint at scope.

Each is a migration candidate. `--json comments` returns at most the first
100; for a longer thread, page with
`gh api /repos/<owner>/<repo>/issues/<#>/comments?per_page=100&page=N` (or
`gh api --paginate`). For a merge of more than five issues, or issues across
repositories, read [bulk-and-cross-repo.md](bulk-and-cross-repo.md) first.

Done when you have a list of migration candidates for every issue involved.

## 2. Split

1. Confirm `<#>` covers genuinely independent work streams, because splitting
   fragments discussion. Keep one issue when the pieces add up to a single
   PR, when the user only wants sub-tasks (use body checkboxes), or when
   every piece hangs on the same upstream decision (list the options in one
   issue). If it only needs reframing, call the Skill tool with
   "issue-update" instead and stop here.
2. Draft the replacements, each with a clear title, scope, labels, and a link
   back to `<#>`. Place each migration candidate in the replacement it
   belongs to.
3. Show the user the plan and wait for confirmation:

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

4. File the replacements in order, calling the Skill tool with
   "issue-create" once for each, so each gets the same duplicate search,
   labels, and preview.
5. Edit `<#>`'s body to open with "Split into #A, #B, #C", then close it:

   ```bash
   gh issue close <#> --comment "Split into #A / #B / #C — see body for scope each covers."
   ```

Done when every replacement is filed and links back, and `<#>` is closed
pointing at all of them.

## 3. Merge

The inverse of split: each non-keeper is superseded by the keeper.

1. Pick the keeper, in this order: the broadest accurate scope (its framing
   already covers the others), then the most discussion (the longest thread
   stays in place), then the most recent activity, then the lowest number.
   If no issue clearly qualifies, the set probably shouldn't merge: call the
   Skill tool with "issue-create" for a new umbrella, then with
   "issue-close" in `supersede` mode for each old issue, and stop here.
2. Draft **one** consolidated migration comment on the keeper, grouping the
   migrated content by source issue, and a close comment for each
   non-keeper.
3. Show the user every comment and any label change, and wait for
   confirmation.
4. Post the migration comment, then close each non-keeper:

   ```bash
   gh issue close <non-keeper#> --comment "Merged into #<keeper>. <pointer to specific section of migration comment>"
   ```

5. If the keeper's scope grew, update its labels.

Done when every migration candidate is on the keeper, every non-keeper is
closed pointing at it, and the keeper's labels match its scope.

## Related

- `issue-create` — files each replacement during `split`.
- `issue-close` — its `supersede` and `dedupe` modes are what `merge` builds
  on.
- `issue-update` — use it instead of `split` when the issue only needs
  reframing.
