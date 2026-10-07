# Staging large changes and fixing mistakes

Staging many files by category, committing part of a file, and undoing or
amending a commit.

## Staging many files

Review by category, then stage and commit one category at a time:

```bash
git status --short                          # see all changes
git diff --stat                             # summary by file

git add src/config.ts src/settings.ts       # configuration
git add docs/*.md                           # documentation
git diff --cached                           # review staged
git commit -m "..."
```

Each commit should be coherent. Config, docs, and a bug fix make three
commits, not one, which keeps history readable and reverts simple.

## Staging part of a file

Use it when one file holds unrelated changes, when splitting work into
several commits, or to leave out debugging code added by accident.

An agent has no terminal for interactive prompts, so it builds the patch
itself and applies it to the index:

```bash
git diff <file> > <patch-file>   # then edit <patch-file> down to the wanted hunks
git apply --cached <patch-file>
git diff --cached                # review the staged hunks
git commit -m "feat: related change"
```

Staging the whole file is the simpler route when every hunk belongs in the
commit. `git add --patch <file>` is interactive ('y' stages a hunk, 'n' skips
it) and is for a person at a terminal; in Claude Code they can run it with
`! git add --patch <file>`.

## Undo the last commit, keeping the changes

`git reset` is not pre-approved, so these commands prompt for permission.

```bash
git reset --soft HEAD~1   # undo the commit, keep the changes staged
git reset HEAD            # unstage everything
# fix, then commit again
```

## Amend the last commit

Only for a commit not yet pushed; a pushed commit gets a new commit instead.
A bare `git commit --amend` opens an editor, so pass the message:

```bash
git add <fixed-files>
git commit --amend --no-edit               # keep the message
git commit --amend -m "type(scope): new"   # or replace it
```

## Discard the last commit

```bash
git reset --hard HEAD~1   # discards every change in the last commit
```

This is destructive: the changes are gone. Confirm with the user first; the
permission prompt is a second check.
