# Recovery while addressing feedback

Read this when a PR you're addressing feedback on has merge conflicts or
failing CI, or when `fixup-and-push.sh` leaves a `fixup!` commit unsquashed.

## Contents

- [Merge conflicts and failing CI](#merge-conflicts-and-failing-ci)
- [Autosquash no-op](#autosquash-no-op)

## Merge conflicts and failing CI

Settle conflicts and build failures before replying to review comments: after
merging the base, some comments may no longer apply.

Check the state:

```bash
gh pr view <PR#> --json mergeable,mergeStateStatus
gh pr checks <PR#>
```

**Conflicts:** merge the base, resolve, and commit.

```bash
git fetch origin <baseRefName>
git merge origin/<baseRefName>
# resolve the conflicts
git add <resolved-files>
git commit -m "Merge branch 'origin/<baseRefName>'"
```

Conflicts can invalidate earlier comments, so recheck the sections they touch
before resuming.

**Code failures** (lint, types, tests): fix them now, run the project's
verification locally, then commit, rebase, and push.

**Infrastructure failures** (a flaky job, a runner timeout): note it in your
reply, link an infrastructure ticket if there is one, and carry on with the
review rather than blocking on it.

Done when the PR is mergeable and every remaining CI failure is either fixed
or noted as infrastructure.

## Autosquash no-op

`fixup-and-push.sh` creates `fixup! <subject>` and runs
`git rebase --autosquash origin/<base>`. Autosquash only folds the fixup into
a commit with that subject **inside the rebase range**. If the matching
commit is already on the base, or the subject collides with a base-branch
commit, the rebase reports success and leaves the `fixup!` commit dangling
on the branch, where CI and history readers see the noise. The script checks
for this after the rebase, prints the recovery below, and exits non-zero
without pushing (dougborg/harness-kit#40, #42).

Squash it by hand. The script's printed recovery writes the editor to
`/tmp`; put it in the repository's git directory instead, where no other
session can overwrite it. Get the path with
`git rev-parse --absolute-git-dir` and write it in place of `<git-dir>`.
`cat`, `chmod`, and `env` fall outside this skill's `allowed-tools`, so expect
a permission prompt for each.

```bash
cat > <git-dir>/squash-fixup.sh <<'SH'
#!/bin/bash
sed -i.bak '/fixup!/s/^pick /fixup /' "$1"
SH
chmod +x <git-dir>/squash-fixup.sh
env GIT_SEQUENCE_EDITOR=<git-dir>/squash-fixup.sh git rebase -i origin/<base>
```

Two details matter:

- **`env GIT_SEQUENCE_EDITOR=...`**: the inline `VAR=value command` form is
  fragile across shells and some wrapper setups; `env` always exports the
  variable to the child process.
- **The loose sed pattern**: the rebase todo format varies
  (`pick <sha> <subject>` by default, `pick <sha> # <subject>` in some
  configs). Matching any `pick` line that contains `fixup!` works with either
  and is harder to no-op silently than a regex tied to one shape.

Check that nothing is left:

```bash
git log origin/<base>..HEAD --format=%s | grep -c '^fixup!' || true
# expected: 0
```

A nonzero count means the pattern didn't match: compare it with
`git log --format='%s' | head` and rerun. Then push the way the script does,
leasing against the branch's fresh remote tip so a GitHub "Update branch"
merge doesn't reject the push as stale:

```bash
git fetch origin <branch>
git push --force-with-lease="<branch>:$(git rev-parse --verify refs/remotes/origin/<branch>)" origin <branch>
```

Done when the count is 0 and the branch is pushed.
