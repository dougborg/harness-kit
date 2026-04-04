---
name: rebase
description: >-
  Rebase a feature branch onto a target branch, resolving conflicts
  intelligently. Use when a branch is behind and needs updating.
argument-hint: "[target branch]"
model: sonnet
allowed-tools: Bash(git rebase*), Bash(git fetch*), Bash(git status*), Bash(git diff*), Bash(git log*), Bash(git add*), Bash(git stash*), Bash(git branch*), Bash(git rev-parse*), Bash(git merge-base*), Bash(git show*), Bash(git checkout*), Bash(GIT_SEQUENCE_EDITOR*), Bash(${CLAUDE_PLUGIN_ROOT}/skills/rebase/*), Bash(${CLAUDE_PLUGIN_ROOT}/skills/shared/discover-verification-cmd.sh*), Bash(${CLAUDE_PLUGIN_ROOT}/skills/shared/is-branch-shared.sh*), Read, Grep, Glob
---

# /rebase — Rebase Branch onto Target

Rebase the current feature branch onto a target branch, handling conflicts automatically with full context awareness.

## PURPOSE

Update a feature branch by replaying its commits onto a target branch (default: `origin/main`), resolving any conflicts intelligently.

## CRITICAL

- **Never rebase shared/published branches** — Only rebase local feature branches. If the branch has been pushed and others are working on it, confirm with the user first.
- **Stash or commit uncommitted changes first** — Dirty working tree will cause rebase to fail. Stash automatically if needed.
- **Understand both sides of every conflict** — Read `git log` for the target branch changes to the conflicting file before resolving. Never blindly pick one side.
- **Never use `--no-verify`** — Hooks exist for a reason. Fix issues, don't skip them.
- **Verify after rebase** — Run the project's validation command after rebase completes to catch integration issues.

## ASSUMES

- You're on a feature branch (not `main`)
- The target branch exists and is fetchable
- You have permission to rewrite local history

## STANDARD PATH

### 1. Pre-flight checks

Run the pre-flight script (validates branch, fetches remote, checks for collaboration, stashes if needed):

```bash
target=$(${CLAUDE_PLUGIN_ROOT}/skills/rebase/preflight.sh "${ARGUMENTS:-origin/main}")
```

The script exits 1 if on main/master or if other authors are detected on a published branch. It prints the target branch to stdout and stash info to stderr.

### 2. Assess the rebase

```bash
${CLAUDE_PLUGIN_ROOT}/skills/rebase/assess.sh "$target"
```

Shows commits to replay, files that may conflict, and the merge base.

### 3. Attempt the rebase

```bash
git rebase $target
```

If this succeeds cleanly, skip to step 5.

### 4. Resolve conflicts (if any)

When rebase stops for conflicts:

```bash
# See which files have conflicts
git diff --name-only --diff-filter=U
```

For each conflicting file, follow the sequence in DETAIL: Resolving Individual Conflicts. Then:

```bash
git rebase --continue
```

Repeat if subsequent commits also conflict.

### 5. Post-rebase verification

```bash
# Verify commit history looks right
git log --oneline $target..HEAD

# Restore stashed changes if we stashed in step 1
[ -n "$STASH_REF" ] && git stash pop "$STASH_REF"
```

Run the project's validation command:

```bash
cmd=$(${CLAUDE_PLUGIN_ROOT}/skills/shared/discover-verification-cmd.sh)
eval "$cmd"
```

Report validation results. If validation fails, the rebase is complete but the branch has integration issues that need fixing.

### 6. Summary

Print:

- Number of commits rebased
- Number of conflicts resolved (if any)
- Files that had conflicts (if any)
- Validation result (pass/fail)
- Whether force-push is needed (`git push --force-with-lease` reminder)

## EDGE CASES

- [Rebase aborted mid-way] — Read DETAIL: Aborting a Rebase
- [Resolving individual conflicts] — Read DETAIL: Resolving Individual Conflicts
- [Complex conflict patterns] — Read DETAIL: Conflict Strategies
- [Squashing during rebase] — Read DETAIL: Non-Interactive Squash

---

## DETAIL: Aborting a Rebase

If a rebase is going badly and you need to start over:

```bash
git rebase --abort
```

This restores the branch to its pre-rebase state. Use when:

- Conflicts are too complex to resolve in context
- You realize the wrong target branch was used
- The user asks to stop

Always check for a rebase in progress before starting a new one:

```bash
# Check if a rebase is already in progress
git rev-parse -q --verify REBASE_HEAD >/dev/null 2>&1
```

---

## DETAIL: Resolving Individual Conflicts

For each conflicting file discovered by `git diff --name-only --diff-filter=U`:

1. **Read the conflict markers** — Use `Read` to see the full file with `<<<<<<<`, `=======`, `>>>>>>>` markers
2. **Understand the target branch changes** — Run `git log -p $target -- <file>` to see what changed on the target and why
3. **Understand our changes** — Run `git show REBASE_HEAD -- <file>` to see what changed in the commit being replayed
4. **Resolve** — Edit the file to integrate both sets of changes. Preserve intent from both sides when possible. Remove all conflict markers.
5. **Stage** — `git add <file>`

After all conflicts in the current commit are resolved, run `git rebase --continue` to move to the next commit.

---

## DETAIL: Conflict Strategies

### Binary files

Binary files can't be merged. Choose one side:

```bash
# NOTE: In rebase, --ours/--theirs are swapped from merge semantics!
git checkout --ours <file>      # Keep target branch version (branch we're rebasing onto)
git checkout --theirs <file>    # Keep rebased commit version (our changes being replayed)
git add <file>
```

**Default to `--theirs`** (keep rebased commit version) for most binaries, since we're replaying our commits. Only ask the user if the file is manually-edited content with ambiguous intent (e.g., images, documents).

### Lock files (pnpm-lock.yaml, package-lock.json, Cargo.lock)

Regenerate rather than merge:

```bash
git checkout --theirs pnpm-lock.yaml   # Take target's version
pnpm install                            # Regenerate with our deps
git add pnpm-lock.yaml
```

### Auto-generated files

For files like `flake.lock`, `.terraform.lock.hcl`, or similar — take the target version and regenerate:

```bash
git checkout --theirs <lockfile>
# Run the appropriate regeneration command
git add <lockfile>
```

### Deleted vs Modified

When one side deleted a file and the other modified it:

```bash
# Check what each side did
git log --oneline --follow $target -- <file>   # Was it deleted on target?
git log --oneline HEAD -- <file>                # Did we modify it?
```

If target deleted it intentionally (refactor, migration), accept the deletion. If our changes are important, keep the file and adapt.

---

## DETAIL: Non-Interactive Squash

Use the squash script for non-interactive operations:

```bash
# Squash all commits into one
${CLAUDE_PLUGIN_ROOT}/skills/rebase/squash.sh squash $target

# Drop a specific commit by SHA
${CLAUDE_PLUGIN_ROOT}/skills/rebase/squash.sh drop $target <short-sha>

# Reword a commit
${CLAUDE_PLUGIN_ROOT}/skills/rebase/squash.sh reword $target <short-sha>
```

The script automatically detects your sed flavor (GNU or BSD) and applies the correct `sed -i` syntax.

---

## RELATED

- `/commit` — Quality-gated conventional commits
- `/open-pr` — Open PR with validation (often follows rebase)
- `/review-pr` — Address review feedback
