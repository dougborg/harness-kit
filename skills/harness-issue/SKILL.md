---
name: harness-issue
description: >-
  File a bug report, idea, or proposed change against the upstream harness repo
  resolved from the project's config, from any project that uses harness-kit.
  Two modes: open an Issue, or open a PR with a draft fix. Searches for
  duplicates first and always shows the proposed content before filing.
argument-hint: "[issue|pr]"
allowed-tools: Bash(gh issue *), Bash(gh pr *), Bash(gh repo *), Bash(gh api *), Bash(git status), Bash(git diff *), Bash(git log *), Bash(${CLAUDE_PLUGIN_ROOT}/skills/harness-issue/*), Read, Edit, Write
---

# /harness-issue — File feedback or a fix on the upstream harness

Open an Issue (for bugs, gaps, ideas) or a Pull Request (for a concrete fix) against the upstream harness repository, from any project that uses harness-kit.

## PURPOSE

Close the loop between projects that consume harness-kit and the harness itself. When a downstream project hits a bug, finds a gap, or invents an improvement worth sharing, this skill turns that learning into upstream Issues or PRs without leaving the project.

## CRITICAL

- **Always search for duplicates first** — file a *new* Issue/PR only after checking open and recent closed items match nothing relevant. Comment on an existing thread when one exists rather than fragmenting discussion.
- **Always show the proposed content before filing** — preview the title and body to the user, get confirmation. Never `gh issue create` / `gh pr create` silently.
- **Never invent reproduction details** — if you don't know which harness-kit version, skill, or commit triggered the finding, ask or mark as unknown. Don't fabricate context to look thorough.
- **PR mode delegates to /open-pr inside the upstream workspace** — don't reimplement validation/self-review/CI-poll. Prepare the workspace, switch into it, and invoke /open-pr there.
- **Respect the upstream config** — read the upstream repo from `.claude/harness-upstream` (with lock file fallback). Do not hardcode `dougborg/harness-kit` in any user-visible message.

## ASSUMES

- `gh` CLI is installed and authenticated against an account with access to the upstream repo
- Project is running inside Claude Code (so the user can confirm prompts)
- For PR mode: the user has push access to the upstream (or their own fork — see EDGE CASES)

## STANDARD PATH

### 1. Resolve upstream

```bash
upstream=$(${CLAUDE_PLUGIN_ROOT}/skills/harness-issue/resolve-upstream.sh)
echo "Filing against $upstream"
```

The script reads `.claude/harness-upstream`, then `.harness-lock.json`, then falls back to the built-in default. `$HARNESS_UPSTREAM` overrides for one-off use.

### 2. Choose mode

If `$ARGUMENTS` is `issue` or `pr`, use it. Otherwise ask:

> "Issue (describe a bug/gap/idea) or PR (propose a concrete change)?"

### 3. Gather context

From the conversation, extract:

- **What** — the finding in one sentence
- **Where** — which skill, agent, hook, script, or doc is affected (file path + line if known)
- **Why it matters** — concrete impact (broke a workflow, surprised a user, blocked a feature)
- **How to repro / suggested fix** — minimal repro for bugs; sketch of a fix for ideas

If any of these are unknown, ask the user or mark `(unknown)` in the issue body — don't fabricate.

### 4. Search for duplicates

```bash
gh issue list -R "$upstream" --state all --limit 20 --search "<keywords>"
gh pr list    -R "$upstream" --state all --limit 20 --search "<keywords>"
```

Show the user any matches that look related. Ask: *file new*, *comment on existing*, or *abort*. If the user picks an existing thread, post a comment via `gh issue comment` / `gh pr comment` and stop.

### 5a. Issue mode

Compose the title (≤70 chars) and body. Body template:

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

Show the user the full title + body, get confirmation, then:

```bash
gh issue create -R "$upstream" --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)"
```

Print the resulting issue URL.

### 5b. PR mode

1. **Pick a branch name** — short, descriptive (e.g. `fix/hooks-reference-typo`, `feat/issue-template-for-retro`).

2. **Prepare the upstream workspace**:

   ```bash
   workspace=$(${CLAUDE_PLUGIN_ROOT}/skills/harness-issue/prepare-pr-workspace.sh "$upstream" "<branch>")
   cd "$workspace"
   ```

   The script clones the upstream (or reuses an existing checkout under `~/.cache/harness-issue/`), refuses if it would clobber unrelated state, fast-forwards the default branch, and creates the new branch.

3. **Apply the change** in `$workspace`. This is normal editing in the upstream repo's working copy. Make the change minimal and focused — link back to the downstream context in the commit body, not in code comments.

4. **Hand off to /open-pr** from inside `$workspace` so the standard validation, self-review, and CI-poll flow runs against the upstream's verification command:

   ```text
   /open-pr
   ```

   In the PR body, include a "Source context" footer matching the Issue mode template above.

### 6. Return

Print: the upstream repo, the mode, and the issue/PR URL. If the user picked "comment on existing," print the comment URL.

## EDGE CASES

- **No push access to upstream** — `gh repo fork --remote` first, then push to the fork. The PR workflow stays the same; `gh pr create` cross-repo PRs by default.
- **Sensitive context in the finding** — if the repro mentions internal paths, customer names, or secrets, sanitize before filing. Ask the user explicitly when unsure.
- **Already-merged or already-fixed-on-main** — `git log` in the upstream workspace before filing. If the issue is already addressed in `main` (just not released), tell the user instead of filing.
- **Many small findings at once** (e.g. retro produced 5) — file each as its own Issue/PR. One Issue per finding keeps triage clean. Batch only when items are genuinely a single concern.

## RELATED

- `/harness retro` — surfaces upstream-worthy findings during post-session review and invokes this skill on each
- `/harness hoist` — already-modified upstream files in your project that should be hoisted back. `harness-issue` complements hoist for findings that aren't yet a code diff.
- `/open-pr` — used inside the upstream workspace during PR mode

## CONFIG

- `.claude/harness-upstream` — one line, `owner/repo`. Overrides the default and the lock file.
- `$HARNESS_UPSTREAM` — environment override for one-off invocations or CI.
- `$HARNESS_UPSTREAM_WORKSPACE` — root path for cached upstream checkouts (default `${XDG_CACHE_HOME:-~/.cache}/harness-issue`).
