# uv.lock drift

Why a drifted `uv.lock` aborts commits in Python + uv projects, why it drifts,
and how to recover.

## The failure mode

With pre-commit, an unstaged `uv.lock` triggers an auto-stash race that
aborts the commit:

1. Pre-commit auto-stashes unstaged changes, including the unstaged
   `uv.lock` state.
2. A hook runs a tool under `uv run` (pytest, say), which re-syncs `uv.lock`.
3. Pre-commit pops the stash, and the stashed `uv.lock` conflicts with the
   re-synced one.
4. Pre-commit reports "files were modified by this hook" and the commit
   aborts.

Nothing was wrong with the staged content; the abort is purely the stash/pop
conflict. Staging `uv.lock` before committing removes the race.

## Why uv.lock drifts without dependency changes

- A sibling-package release on the base branch bumped a workspace version.
- `uv run` or `uv sync` re-resolved after a `pyproject.toml` change
  elsewhere.
- A different lockfile revision landed through a merge or rebase.

The drift is legitimate and belongs in the commit. Leaving it unstaged only
re-triggers the race on the next commit.

## Recovery after an aborted commit

```bash
git status --porcelain -- uv.lock   # confirm uv.lock is in the modified list
git add uv.lock
git commit ...                      # retry once with the same message
```

Tell the user that `uv.lock` was staged, as in the pre-flight check.
