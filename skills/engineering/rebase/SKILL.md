---
name: rebase
description: Rebase the current feature branch onto a target branch (default origin/main) and resolve its conflicts.
argument-hint: "[target branch]"
allowed-tools: Bash(git rebase*), Bash(git fetch*), Bash(git status*), Bash(git diff*), Bash(git log*), Bash(git add*), Bash(git stash*), Bash(git branch*), Bash(git rev-parse*), Bash(git merge-base*), Bash(git show*), Bash(git checkout*), Bash(GIT_SEQUENCE_EDITOR*), Bash(<skill-dir>/*), Bash(<shared-scripts-dir>/*), Read, Grep, Glob
---

# Rebase

Replay the current feature branch's commits onto a target branch (default
`origin/main`), resolving conflicts with both sides understood.

- **Rebase only local feature branches.** If the branch is pushed and others
  work on it, confirm with the user first; the pre-flight script refuses a
  shared branch.
- **Stash uncommitted work before rebasing**, since a dirty tree makes the
  rebase fail; the pre-flight script does it for you.
- **Stash only when `git status --short` shows work to save.** On a clean
  tree `git stash` saves nothing, and a later `git stash pop` pops whatever
  entry is on top, possibly months-old WIP from another branch, causing a
  surprise conflict. To compare against a ref, use `git diff <ref>` or a
  separate `git worktree`, not a stash/pop pair.
- **Resolve each conflict with both sides read.** Picking a side blind drops
  someone's change.
- **Fix hook failures at the cause;** `--no-verify` is not a fix.

## 1. Pre-flight

Check no rebase is already in progress; if this succeeds, one is, so finish
or abort it first:

```bash
git rev-parse -q --verify REBASE_HEAD
```

Then run the pre-flight script. It refuses `main`/`master`, fetches the
target's remote, checks whether other authors share the branch, and stashes
uncommitted work if there is any:

```bash
target=$(<skill-dir>/preflight.sh "${ARGUMENTS:-origin/main}")
```

It exits 1 on a primary branch or a shared published branch. On a shared
branch it names the other authors: stop and ask the user whether to rebase
anyway (they should confirm with those collaborators), merge instead, or
abort. Only on an explicit yes, rerun it as `preflight.sh --allow-shared
<target>`. It prints the target on stdout and, if it stashed, `STASH_REF=<ref>` on stderr; note that
ref for step 5. Shell variables don't survive between Bash calls, so write
the printed target in place of `$target` in later commands. Done when the
script exits 0 and you have the target.

## 2. Assess

```bash
<skill-dir>/assess.sh "$target"
```

It shows the commits to replay, the files that may conflict, and the merge
base. Done when you know how many commits will replay and which files are at
risk.

## 3. Rebase

```bash
git rebase $target
```

Done when it finishes cleanly (go to step 5) or stops on a conflict (step 4).

## 4. Resolve conflicts

List the conflicted files:

```bash
git diff --name-only --diff-filter=U
```

For each one:

1. Read the whole file, conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)
   included.
2. See what the target changed and why: `git log -p $target -- <file>`.
3. See what the replayed commit changed: `git show REBASE_HEAD -- <file>`.
4. Edit the file to keep the intent of both sides, and remove every marker.
5. Stage it: `git add <file>`.

Binary files, lock files, generated files, and delete-versus-modify conflicts
each have a set strategy in
[conflict-strategies.md](conflict-strategies.md); read it when you hit one,
because `--ours` and `--theirs` are swapped during a rebase.

When every file in the current commit is resolved:

```bash
git rebase --continue
```

Repeat for each commit that stops. Done when the rebase completes.

To start over (the conflicts are too tangled to resolve here, the target was
wrong, or the user asks to stop), `git rebase --abort` restores the branch to
its pre-rebase state.

## 5. Verify

```bash
git log --oneline $target..HEAD
```

If step 1 stashed, restore it with the literal ref it printed (`$STASH_REF`
is not set in this shell):

```bash
git stash pop "<STASH_REF from step 1>"
```

Discover the verification command, then run what it prints as a **separate**
Bash call (`eval` in the same call defeats `allowed-tools` matching and
prompts):

```bash
<shared-scripts-dir>/discover-verification-cmd.sh
```

A failure here means the rebase is complete but the branch has integration
problems to fix. Done when the history looks right, any stash is restored,
and you have the verification result.

## 6. Summary

Report the commits rebased, the conflicts resolved and their files, the
verification result, and whether the branch needs
`git push --force-with-lease`. Done when the report is printed.

## Squash, drop, or reword without an editor

`squash.sh` drives `git rebase -i` through `GIT_SEQUENCE_EDITOR`, detecting
GNU or BSD `sed` for the right `sed -i` syntax:

```bash
<skill-dir>/squash.sh squash $target               # squash all commits into one
<skill-dir>/squash.sh drop $target <short-sha>     # drop one commit
<skill-dir>/squash.sh reword $target <short-sha>   # reword one commit
```

## Related

- `/commit` — quality-gated conventional commits
- `/open-pr` — open a PR with validation, often after a rebase
- `/review-pr` — address review feedback
