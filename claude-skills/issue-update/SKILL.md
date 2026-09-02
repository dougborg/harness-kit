---
name: issue-update
description: >-
  Update an existing GitHub issue — edit body, post a comment, retag, or
  reopen. Pre-flights body + comments; acknowledges stale framing instead of
  silently rewriting.
argument-hint: "<#> | reopen <#>"
allowed-tools: Bash(gh issue *), Bash(gh api *), Bash(gh label *), Bash(gh repo *), Read, Edit, Write
disable-model-invocation: true
---

# /issue-update — Update or Reopen an Issue

Modify an open issue in place (body / comment / labels) or reopen a closed one with new context — without silently rewriting the original framing.

## PURPOSE

Keep issues accurate as understanding evolves, without erasing the history that produced the current state.

## CRITICAL

- **Always fetch body + comments before editing** — the comment thread often holds the latest framing; the body alone lies. `gh issue view --json comments` returns the first 100 comments; paginate via `gh api` for longer threads (see pre-flight note).
- **Never silently rewrite** — when correcting framing, acknowledge what was wrong (e.g., "Note: original framing assumed X, corrected after Y").
- **Preview before applying** — show drafted body / comment / label diff to the user and require confirmation before running `gh issue edit`, `gh issue comment`, or `gh issue reopen`.
- **Cross-link newly discovered related issues / PRs** — both directions.
- **Reopen carries a comment** — never silent reopen; explain what changed.

## ASSUMES

- `gh` CLI authenticated; issue accessible.
- Existing labels discoverable via `gh label list`.

## STANDARD PATH

### 1. Pre-flight

```bash
gh issue view <#> --json title,body,state,labels,comments
```

Read **comments**, not just body. Note alternative approaches, corrections, file:line samples, cross-links, late labels.

> **Note:** `gh issue view --json comments` returns at most the first 100 comments. Sample/paginate via
> `gh api /repos/<owner>/<repo>/issues/<#>/comments?per_page=100&page=N` (or `gh api --paginate`) before editing
> when the thread is long — otherwise late framing changes can be missed.

### 2. Pick the mode

| Arg form | Mode |
| --- | --- |
| `<#>` | `update` an open issue (body / comment / labels) |
| `reopen <#>` | reopen a closed issue with new context |

### 3. Mode: update

Decide: edit body / post comment / both / labels-only. See DETAIL: Choosing Edit vs Comment.

**Preview**: show the drafted new body, comment text, and label diff to the user. Wait for explicit confirmation before applying — edits can overwrite framing. Then run only the applicable command(s):

```bash
gh issue edit <#> --body "$(cat <<'EOF'
> **Note:** Original framing assumed X. Corrected after #123.

## What
<corrected body>
EOF
)"
gh issue comment <#> --body "..."
gh issue edit <#> --add-label "..." --remove-label "..."
```

Cross-link any newly discovered related issues / PRs.

### 4. Mode: reopen

1. Confirm closure reason from the pre-flight (resolution comment, label, linked PR).
2. Compose a comment with new context: what changed, why the original close was premature or no longer applies.
3. **Preview the drafted reopen comment** to the user. Wait for confirmation. Then reopen with the comment attached:

   ```bash
   gh issue reopen <#> --comment "..."
   ```

4. Update labels if scope shifted (preview the label diff first).

## EDGE CASES

- [Body is wrong but history should stay visible] — read DETAIL: Choosing Edit vs Comment
- [Scope shifted significantly] — read DETAIL: Acknowledging Stale Framing
- [Closed by a merged PR but issue persists] — read DETAIL: Reopen After PR Merge
- [Adding labels that don't exist yet] — read DETAIL: Missing Labels

---

## DETAIL: Choosing Edit vs Comment

| Situation | Action |
| --- | --- |
| Original framing is wrong | Edit body **and** comment acknowledging the change |
| New info builds on existing framing | Comment only |
| Body is wrong, history should stay visible | Edit body with "Note:" header; comment links to old framing |
| Scope / priority shifted, text fine | Labels only |

The principle: readers arriving cold should see current truth; readers tracking history should see how we got here.

---

## DETAIL: Acknowledging Stale Framing

When editing a body to correct framing, preserve the correction trail:

```markdown
> **Note:** Original framing assumed all suppliers had a stable `code` field.
> Corrected after #123 — the field is nullable for legacy imports. Rewritten
> below.

## What
<corrected body>
```

This:

- Tells cold readers the body is current.
- Tells thread readers what shifted and why.
- Prevents future contributors from re-litigating the original framing.

---

## DETAIL: Reopen After PR Merge

If the closing PR shipped but the issue persists (regression, partial fix, scope creep discovered post-merge):

1. Read the merged PR's diff and comments — confirm what it actually shipped.
2. State the gap precisely in the reopen comment: "PR #X shipped Y but Z still reproduces because …"
3. Consider whether the right move is `reopen` or a fresh issue (`/issue-create`) that links back. Fresh issue is usually cleaner if the gap has a different root cause.

---

## DETAIL: Missing Labels

If you want to add a label that doesn't exist:

- Skip it and mention in the comment: "Suggest adding `area:foo` label — doesn't exist yet."
- Don't `gh label create` from this skill; that's a repo-config decision.

## RELATED

- `/issue-create` — File a new issue.
- `/issue-close` — Close as resolved / superseded / duplicate.
- `/issue-restructure` — Split / merge issues.
