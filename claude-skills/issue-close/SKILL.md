---
name: issue-close
description: >-
  Close a GitHub issue with discipline — resolved, superseded, or duplicate.
  Pre-flights body + comments, migrates substance before destroying context,
  cross-links both directions.
argument-hint: "<#> | supersede <closing#> <canonical#> | dedupe <dup#> <keeper#>"
effort: low
allowed-tools: Bash(gh issue *), Bash(gh api *), Bash(gh label *), Bash(gh repo *), Read, Edit, Write
---

# /issue-close — Close an Issue with Context Preserved

Close as resolved (default), superseded, or duplicate — never silently, never before mining the comment thread.

## PURPOSE

Close issues without losing substance from comment threads or stranding readers.

## CRITICAL

- **Always fetch body + comments before closing** — comments often carry the latest understanding; the body alone lies. `gh issue view --json comments` returns the first 100 comments; paginate via `gh api` for longer threads (see pre-flight note).
- **Migrate substance before destroying context** — never close-as-superseded until the closing thread's substance is mined and moved to the canonical issue.
- **Preview before applying** — show the planned close comment (and any migration comment) to the user and require confirmation before running `gh issue close` or `gh issue comment`.
- **Cross-link both directions** — both issues reference each other after the close.
- **Never silent close** — every close carries a comment stating resolution / reason.

## ASSUMES

- `gh` CLI authenticated; all referenced issue numbers accessible.

## STANDARD PATH

### 1. Pre-flight

```bash
gh issue view <#> --json title,body,state,labels,comments
```

Read the **comments** field, not just the body. See DETAIL: What To Mine From Comments.

For `supersede` and `dedupe`, pre-flight **both** issues.

> **Note:** `gh issue view --json comments` returns at most the first 100 comments. If the thread is longer, paginate via
> `gh api /repos/<owner>/<repo>/issues/<#>/comments?per_page=100&page=N` (or `gh api --paginate`) before mining substance.

### 2. Pick the mode

| Arg form | Mode |
| --- | --- |
| `<#>` | `resolve` — fixed / wontfix / invalid / no-repro |
| `supersede <closing#> <canonical#>` | another issue captures the work; substance migration required |
| `dedupe <duplicate#> <keeper#>` | outright duplicate; no migration |

### 3. Mode: resolve

Identify resolution: fixed (PR / commit), wontfix (with reason), invalid (with reason), no-repro (with what was tried). See DETAIL: Resolution Comment Templates.

**Preview**: show the drafted close comment to the user. Wait for confirmation. Then:

```bash
gh issue close <#> --comment "..."
```

### 4. Mode: supersede

1. Mine the closing issue's comment thread for substance not already on the canonical (alternative approaches, file:line samples, post-filing corrections, cross-links).
2. Draft the migration comment for `canonical#` (preserves substance with attribution, cross-links source) and the close comment for `closing#` (states *why* superseded, cross-links `canonical#`, notes the original thread remains readable).
3. **Preview both drafted comments to the user.** Wait for explicit confirmation before posting either.
4. Apply:

   ```bash
   gh issue comment <canonical#> --body "..."
   gh issue close <closing#> --comment "..."
   ```

### 5. Mode: dedupe

1. Confirm genuine overlap, not just keyword similarity.
2. Keeper is usually older + more discussion. Cross-link from keeper *only* if the duplicate adds context (different repro, different reporter).
3. **Preview the drafted close comment** to the user. Wait for confirmation. Then:

```bash
gh issue close <duplicate#> --comment "Duplicate of #<keeper>. <Optional: what's preserved>"
```

## EDGE CASES

- [Closing issue is in a different repo from canonical] — read DETAIL: Cross-Repo References
- [Thread has 100+ comments] — read DETAIL: Sampling Long Threads
- [Triagers added scope-narrowing labels post-filing] — read DETAIL: Respecting Late Labels
- [Resolution comment templates] — read DETAIL: Resolution Comment Templates

---

## DETAIL: What To Mine From Comments

When pre-flighting, scan for:

- Alternative approaches / options proposed in replies
- Post-filing corrections ("this was wrong, the real issue is …")
- File:line samples added later
- Cross-links to other issues / PRs
- Labels added by triagers that hint at scope

For `supersede`, every item above that isn't already on `canonical#` is a migration candidate.

---

## DETAIL: Resolution Comment Templates

**Fixed by PR/commit:**

```text
Resolved in #<pr> (commit <sha>). <One sentence on what changed.>
```

**Wontfix:**

```text
Closing as wontfix. <Reason — design constraint, scope, deprecated path.>
If circumstances change, reopen with new context.
```

**Invalid:**

```text
Closing as invalid. <Why — misconfigured environment, expected behavior, etc.>
```

**No-repro:**

```text
Cannot reproduce on <env / commit>. Tried: <steps>. Reopen with a minimal
repro if you hit this again.
```

---

## DETAIL: Cross-Repo References

`gh` accepts `owner/repo#N` in issue bodies and comments. Before migrating across repos:

- Confirm both repos are accessible (`gh repo view`).
- Use the full `owner/repo#N` form in both directions.
- Watch for private-repo links the other side can't read.

---

## DETAIL: Sampling Long Threads

For 100+ comments, sample by chronological clusters:

- **Most recent few** — usually capture current state.
- **Oldest** — set the original framing.
- **Middle** — often noise; spot-check for migration candidates.

When in doubt, show the user a sampled list of candidates and ask before migrating.

---

## DETAIL: Respecting Late Labels

Labels added by triagers after filing are part of the effective scope. When superseding:

- Carry forward priority / area labels onto `canonical#` if it doesn't already have them.
- Mention the source of the label change in the migration comment.

## RELATED

- `/issue-create` — File a new issue.
- `/issue-update` — Reopen, edit body, post comment, retag.
- `/issue-restructure` — Split / merge issues.
- `/pr-comments` — Sibling discipline for PR review threads.
