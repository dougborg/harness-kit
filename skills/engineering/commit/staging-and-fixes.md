# Staging large changes and fixing mistakes

Staging many files by category, committing part of a file, and undoing or
amending a commit.

## Staging many files

Review by category, then stage and commit one category at a time:

```bash
git status | grep -E "modified|new"         # see all changes
git diff --stat                             # summary by file

git add programs/zsh.nix programs/vim.nix   # shell config
git add docs/*.md                           # documentation
git diff --cached                           # review staged
git commit -m "..."
```

Each commit should be coherent. Shell config, docs, and a bug fix make three
commits, not one, which keeps history readable and reverts simple.

## Staging part of a file

```bash
git add --patch <file>   # interactive: 'y' stages a hunk, 'n' skips it
git diff --cached        # review the staged hunks
git commit -m "feat: related change"
```

Use it when one file holds unrelated changes, when splitting work into
several commits, or to leave out debugging code added by accident.

## Undo the last commit, keeping the changes

```bash
git reset --soft HEAD~1   # undo the commit, keep the changes staged
git reset HEAD            # unstage everything
# fix, then commit again
```

## Amend the last commit

Only for a commit not yet pushed; a pushed commit gets a new commit instead.

```bash
git add <fixed-files>
git commit --amend            # amend with the new changes
git commit --amend --no-edit  # or keep the message
```

## Discard the last commit

```bash
git reset --hard HEAD~1   # discards every change in the last commit
```

This is destructive: the changes are gone. Confirm with the user first.
