---
name: issue-create
description: >-
  File a new GitHub issue with duplicate search, scope decision, label
  discovery, and preview before posting. Prevents fragmented or silently-filed
  issues.
allowed-tools: Bash(gh issue *), Bash(gh search *), Bash(gh label *), Bash(gh repo *), Read, Edit, Write
disable-model-invocation: true
---

# /issue-create — File a New GitHub Issue

Search for duplicates, decide scope, pick labels, preview the body to the user, then file.

## PURPOSE

File new issues without fragmenting discussion or losing scope clarity.

## CRITICAL

- **Search for duplicates first** — comment on an existing thread instead of fragmenting.
- **Preview before filing** — show title + body + labels to the user. No silent `gh issue create`.
- **Pick scope deliberately** — focused vs umbrella. Default focused.
- **Use real labels** — discover via `gh label list`. Never invent labels.

## ASSUMES

- `gh` CLI authenticated; repo accessible.
- Repo has labels worth using (skill auto-discovers).

## STANDARD PATH

### 1. Search for duplicates

```bash
gh search issues "<keywords>" --repo <owner>/<repo>
gh issue list --repo <owner>/<repo> --search "<keywords>" --state all
```

If a relevant issue exists, comment there instead and stop. See DETAIL: Duplicate Handling.

### 2. Decide scope

Focused ("fix X in file Y") vs umbrella (cross-cutting, with checkboxes). Prefer focused unless the work spans multiple PRs.

### 3. Pick labels

```bash
gh label list --repo <owner>/<repo>
```

Apply: kind (`bug` / `enhancement` / `chore`), area (`mcp-server` / `client` / etc.), priority (`p0`/`p1`/`p2`/`p3`).

### 4. Draft body

Include: context, current behavior, expected behavior, file:line refs, cross-links to related issues / PRs.

### 5. Preview to user

Show title + body + labels. Wait for confirmation.

### 6. File

```bash
gh issue create --repo <owner>/<repo> --title "..." --body "..." --label "..."
```

Print the URL.

## EDGE CASES

- [Existing issue found during search] — read DETAIL: Duplicate Handling
- [Scope unclear — focused or umbrella?] — read DETAIL: Scope Decision
- [Labels missing for the area] — read DETAIL: Missing Labels

---

## DETAIL: Duplicate Handling

When `gh search` surfaces a candidate:

1. Read the candidate's body + comments — don't judge by title alone.
2. If it covers the same work: comment there with your context, cross-link, stop.
3. If it's adjacent but distinct: file new, cross-link both directions in body.
4. If unclear: show both to the user and ask.

Fragmenting discussion across near-duplicates is worse than over-linking.

---

## DETAIL: Scope Decision

**Focused** — one fix, one file or one tight area, one PR closes it. Default.

**Umbrella** — cross-cutting, multiple PRs, tracked via checkboxes. Use when:

- Work genuinely spans 3+ files or domains
- You expect 2+ PRs against it
- Triage needs a single anchor for related conversations

When in doubt, file focused. Splitting an umbrella later is cheap; merging focused issues later is also cheap (`/issue-restructure merge`).

---

## DETAIL: Missing Labels

If the repo has no label matching the area / kind / priority:

- File without that label rather than inventing one.
- Mention in the body: "No `area:*` label exists yet — suggest creating one."
- Don't `gh label create` from this skill — that's a repo-config decision for the maintainer.

## RELATED

- `/issue-close` — Close an issue (resolved / superseded / duplicate).
- `/issue-update` — Edit body / labels, reopen, comment.
- `/issue-restructure` — Split one issue into many, or merge many into one.
- `/harness-issue` — File upstream against harness-kit specifically.
