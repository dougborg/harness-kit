---
name: harness-issue
description: >-
  Files a bug report, idea, or proposed change against the upstream harness
  repo resolved from the project's config, from any project that uses
  harness-kit. Two modes: open an Issue, or open a PR with a draft fix.
  Searches for duplicates first and shows the proposed content before filing.
  Use when a harness skill, agent, hook, script, or doc misbehaves or has a
  gap worth reporting upstream; when the user asks to file harness feedback or
  propose a harness fix; and when a harness retro finds an upstream-worthy
  item.
argument-hint: "[issue|pr]"
allowed-tools: Bash(gh issue *), Bash(gh pr *), Bash(gh repo *), Bash(gh api *), Bash(git status), Bash(git diff *), Bash(git log *), Bash(<skill-dir>/*), Read, Edit, Write
---

# Harness Issue

Turn a lesson from a downstream project into an upstream Issue (a bug, gap,
or idea) or a Pull Request (a concrete fix) on the harness repository, without
leaving the project. It closes the loop between the projects that consume
harness-kit and the harness itself.

It needs `gh`, authenticated with access to the upstream repo, and a user
present to confirm the preview. PR mode also needs push access to the
upstream or to a fork of it.

Two rules hold in every mode. Show the full title and body and get the user's
confirmation before any `gh issue create` or `gh pr create`, so nothing is
filed silently. Write only facts you have: when the harness-kit version,
skill, or commit behind the finding is unknown, ask or write `(unknown)`
rather than inventing context to look thorough.

## 1. Resolve the upstream

```bash
upstream=$(<skill-dir>/resolve-upstream.sh)
```

The script reads `$HARNESS_UPSTREAM`, then `.claude/harness-upstream` (one
line, `owner/repo`), then the first source `repo` in `.harness-lock.json`,
then falls back to its built-in default. Refer to the repo by the resolved
name in every message to the user rather than a hardcoded
`dougborg/harness-kit`. Done when `$upstream` holds an `owner/repo` and you
have told the user which repo you are filing against.

## 2. Choose the mode

Use `$ARGUMENTS` when it is `issue` or `pr`. Otherwise ask: "Issue (describe a
bug, gap, or idea) or PR (propose a concrete change)?" Done when the mode is
set.

## 3. Gather the context

From the conversation, pin down:

- **What**: the finding in one sentence.
- **Where**: the affected skill, agent, hook, script, or doc, with file path
  and line when known.
- **Why it matters**: the concrete impact (broke a workflow, surprised a user,
  blocked a feature).
- **Repro or suggested fix**: a minimal repro for a bug, a sketch of the fix
  for an idea.

Sanitize internal paths, customer names, and secrets before they reach the
draft, and ask the user when you're unsure whether something is sensitive.
Done when each of the four is filled in, asked about, or marked `(unknown)`.

## 4. Search for duplicates

```bash
gh issue list -R "$upstream" --state all --limit 20 --search "<keywords>"
gh pr list    -R "$upstream" --state all --limit 20 --search "<keywords>"
```

Search by topic, not by the title you were about to write: the same work is
often filed under a different framing (an issue saying "the standard is
documented but unenforced" can duplicate one saying "set up the testing
stack"). Try two or three phrasings of the underlying need.

Show the user any related matches and ask: file new, comment on the existing
thread, or abort. Commenting on an existing thread keeps the discussion in one
place: post with `gh issue comment` or `gh pr comment`, then skip to step 6.
Done when the user has chosen, or no open or recently closed item matches.

## 5a. Issue mode

First check the finding isn't already fixed on the default branch, merged but
not yet released: look at the merged PRs from step 4, and search commits
pushed directly:

```bash
gh api -X GET search/commits -f q="repo:$upstream <keywords>" --jq '.items[] | "\(.sha[0:7]) \(.commit.message | split("\n")[0])"'
```

When it is already fixed, tell the user and stop instead of filing.

Compose a title of 70 characters or fewer and this body:

```markdown
## What

<one-paragraph summary>

## Where

- File: `path/to/affected.md`
- Skill / agent: `<name>` (if applicable)
- harness-kit version: `<from .harness-lock.json>` (or `unknown`)

## Why it matters

<impact>

## Repro / suggested fix

<minimal repro or sketch>

## Source context

Surfaced from project `<downstream-repo-name>` (or `unknown`) on `<date>`.
```

Show the user the full title and body, and after they confirm:

```bash
gh issue create -R "$upstream" --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)"
```

Done when the issue exists and you have its URL.

## 5b. PR mode

1. **Name the branch**: short and descriptive, such as
   `fix/hooks-reference-typo` or `feat/issue-template-for-retro`.
2. **Prepare the upstream workspace**:

   ```bash
   workspace=$(<skill-dir>/prepare-pr-workspace.sh "$upstream" "<branch>")
   cd "$workspace"
   ```

   The script clones the upstream, or reuses a checkout under
   `${XDG_CACHE_HOME:-~/.cache}/harness-issue/` (`$HARNESS_UPSTREAM_WORKSPACE`
   overrides the root). It refuses to touch a checkout with unrelated state,
   fast-forwards the default branch, and creates the new branch.

   Without push access to the upstream, fork it now, before anything
   pushes: run `gh repo fork --remote` in `$workspace`, so pushes go to the
   fork. `gh pr create` then opens the PR cross-repo by default.
3. **Check it isn't already fixed**: `git log` in the workspace. When the
   default branch already addresses the finding (merged, just not released),
   tell the user and stop instead of filing.
4. **Apply the change** in `$workspace` as ordinary editing in the upstream
   repo. Keep it minimal and focused, and link back to the downstream context
   in the commit body rather than in code comments.
5. **Open the PR.** From inside `$workspace`, call the Skill tool with
   "open-pr", so the upstream's own validation, self-review, and CI polling
   run against the upstream's verification command. Leave validation,
   self-review, and CI polling to open-pr rather than running them here. Put
   a "Source context" footer in the PR body, matching the Issue mode
   template.

Done when the PR exists and you have its URL.

## 6. Report

Tell the user the upstream repo, the mode, and the URL of the issue, PR, or
comment. Done when all three are reported.

## Several findings at once

When a retro produces several findings, file each as its own Issue or PR so
triage stays clean. Batch them only when they are genuinely one concern.

## Configuration

- `.claude/harness-upstream`: one line, `owner/repo`. Overrides the default
  and the lock file.
- `$HARNESS_UPSTREAM`: environment override for one-off runs or CI.
- `$HARNESS_UPSTREAM_WORKSPACE`: root for cached upstream checkouts (default
  `${XDG_CACHE_HOME:-~/.cache}/harness-issue`).

## Related

- `/harness retro`: surfaces upstream-worthy findings during post-session
  review and hands each one to this skill.
- `/harness hoist`: hoists upstream files your project has already modified.
  This skill complements it for findings that aren't yet a code diff.
- `/open-pr`: runs inside the upstream workspace in PR mode.
