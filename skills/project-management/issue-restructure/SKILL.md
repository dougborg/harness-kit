---
name: issue-restructure
description: Split one GitHub issue into focused replacements, or merge several into one keeper, migrating substance and cross-linking before closing.
argument-hint: "split <#> | merge <#> <#> [#...]"
allowed-tools: Bash(gh issue *), Bash(gh api *), Bash(gh repo *), Read
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
100; for a longer thread, fetch them all:

```bash
gh api --paginate "repos/<owner>/<repo>/issues/<#>/comments"
```

For a merge of more than five issues, or issues across repositories, read
[bulk-and-cross-repo.md](bulk-and-cross-repo.md) first.

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
   "issue-create" once per replacement, so each gets the same duplicate
   search, labels, and preview. Tell each call that `<#>` is the known source
   being split: an adjacent issue to link, not a duplicate to stop on.
5. Edit `<#>`'s body to open with "Split into #A, #B, #C", then close it:

   ```bash
   gh issue edit <#> --body-file - <<'EOF'
   > Split into #A, #B, #C.

   <original body>
   EOF
   gh issue close <#> --comment "Split into #A / #B / #C — see body for scope each covers."
   ```

Done when every replacement is filed and links back, and `<#>` is closed
pointing at all of them.

## 3. Merge

The inverse of split: each non-keeper is superseded by the keeper.

1. Pick the keeper, in this order: the broadest accurate scope (its framing
   already covers the others), then the most discussion (the longest thread
   stays in place without migration), then the most recent activity
   (readers expect a current issue to be active), then the lowest number
   (older is more canonical). If no issue clearly qualifies, the set
   probably shouldn't merge: call the Skill tool with "issue-create" for a
   new umbrella, then once per old issue with "issue-close" in `supersede`
   mode, and stop here.
2. Draft **one** consolidated migration comment on the keeper, grouping the
   migrated content by source issue and linking each source, and the label
   change if the keeper's scope grew.
3. Show the user the migration comment and the label diff, and wait for
   confirmation. Then post them:

   ```bash
   gh issue comment <keeper#> --body-file - <<'EOF'
   <migration comment>
   EOF
   gh issue edit <keeper#> --add-label "..."   # only if scope grew
   ```

4. Close the non-keepers by calling the Skill tool with "issue-close" once
   per non-keeper, as `supersede <non-keeper#> <keeper#>`. Tell each call the
   substance is already migrated, so it only drafts and previews the close
   comment ("Merged into #<keeper>", with a pointer to that source's section
   of the migration comment).

Done when every migration candidate is on the keeper, the migration comment
links every source, every non-keeper is closed pointing at the keeper, and
the keeper's labels match its scope.

## Related

- `issue-create` — files each replacement during `split`.
- `issue-close` — `merge` closes each non-keeper through its `supersede`
  mode.
- `issue-update` — use it instead of `split` when the issue only needs
  reframing.
