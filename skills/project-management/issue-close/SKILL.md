---
name: issue-close
description: >-
  Closes a GitHub issue as resolved, superseded, or duplicate: reads the body
  and comments, migrates anything still live, cross-links both directions, and
  previews before closing. Use when the user asks to close an issue, when work
  that resolves one has merged, or when grooming finds a duplicate or
  superseded issue.
argument-hint: "<#> | supersede <closing#> <canonical#> | dedupe <dup#> <keeper#>"
effort: low
allowed-tools: Bash(gh issue *), Bash(gh api *), Bash(gh repo *), Read
---

# Issue Close

Close an issue without losing what its thread learned or stranding the people
who read it. Every close carries a comment stating the resolution, and the
user sees each comment before it posts.

| Arguments | Mode |
| --- | --- |
| `<#>` | **resolve**: fixed, wontfix, invalid, or no-repro |
| `supersede <closing#> <canonical#>` | another issue captures the work; migrate substance first |
| `dedupe <duplicate#> <keeper#>` | an outright duplicate; no migration |

## 1. Read the whole thread

```bash
gh issue view <#> --json title,body,state,labels,comments
```

Read both issues for `supersede` and `dedupe`. The comments often hold the
latest understanding, so the body alone can mislead. Look for:

- alternative approaches proposed in replies;
- corrections after filing ("this was wrong, the real issue is …");
- `file:line` samples added later;
- cross-links to other issues and PRs;
- labels triagers added after filing, which are part of the effective scope.

`--json comments` returns at most the first 100; for a longer thread, fetch
them all before mining:

```bash
gh api --paginate "repos/<owner>/<repo>/issues/<#>/comments"
```

For threads past 100 comments and issues in another repo, read
[long-and-cross-repo.md](long-and-cross-repo.md).

Done when you've read every comment on every issue involved, or, for a
thread past 100 comments, sampled it as the reference describes.

## 2. Resolve

Name the resolution and draft the comment:

```text
Resolved in #<pr> (commit <sha>). <One sentence on what changed.>
```

```text
Closing as wontfix. <Reason: design constraint, scope, deprecated path.>
If circumstances change, reopen with new context.
```

```text
Closing as invalid. <Why: misconfigured environment, expected behaviour, etc.>
```

```text
Cannot reproduce on <env / commit>. Tried: <steps>. Reopen with a minimal
repro if you hit this again.
```

Show the user the comment and wait for confirmation, then:

```bash
gh issue close <#> --comment "..."
```

Done when the issue is closed with a comment naming its resolution.

## 3. Supersede

Migrate before closing: once the closing issue is shut, its substance is
effectively lost to anyone reading the canonical one.

1. From step 1, list every item on `closing#` not already on `canonical#`.
   Each is a migration candidate. Carry late priority and area labels onto
   `canonical#` if it lacks them, and say in the migration comment where the
   label change came from. When the caller says the substance is already
   migrated (a merge posts one consolidated comment first), confirm it is on
   `canonical#` and skip the migration comment.
2. Draft the migration comment for `canonical#`, preserving the substance with
   attribution and linking back to `closing#`. Draft the close comment for
   `closing#`: why it's superseded, a link to `canonical#`, and a note that
   the original thread stays readable.
3. Show the user both comments and the label diff for `canonical#`, and wait
   for confirmation before applying any of them.
4. Apply:

   ```bash
   gh issue comment <canonical#> --body "..."
   gh issue edit <canonical#> --add-label "..."   # only if labels carry over
   gh issue close <closing#> --comment "..."
   ```

Done when every migration candidate is on `canonical#`, and each issue links
to the other.

## 4. Dedupe

1. Confirm the overlap is genuine, not keyword similarity.
2. The keeper is usually the older issue with more discussion. Cross-link from
   the keeper only when the duplicate adds context, such as a different repro
   or reporter.
3. Show the user the close comment, and the keeper comment if there is one,
   and wait for confirmation, then:

   ```bash
   gh issue comment <keeper#> --body "..."   # only if the duplicate adds context
   gh issue close <duplicate#> --comment "Duplicate of #<keeper>. <Optional: what's preserved>"
   ```

Done when the duplicate is closed pointing at the keeper, and any context it
added is linked from the keeper.

## Related

- `issue-create` — file a new issue.
- `issue-update` — reopen, edit the body, comment, retag.
- `issue-restructure` — split or merge issues.
- `pr-comments` — the same discipline for PR review threads.
