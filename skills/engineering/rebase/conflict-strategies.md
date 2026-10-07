# Conflict strategies

Set strategies for conflicts that line-by-line resolution doesn't fit.

During a rebase, `--ours` and `--theirs` are swapped from merge semantics:

- `git checkout --ours <file>` keeps the **target** branch's version (the
  branch you're rebasing onto).
- `git checkout --theirs <file>` keeps the **replayed commit's** version
  (your changes).

## Binary files

Binary files can't be merged, so choose a side:

```bash
git checkout --theirs <file>    # keep your version
git add <file>
```

Default to `--theirs`, since you're replaying your own commits. Ask the user
only when the file is hand-edited content with ambiguous intent, such as an
image or a document.

## Lock files

For `pnpm-lock.yaml`, `package-lock.json`, `Cargo.lock`, and the like, take
the target's version and regenerate it with your dependencies rather than
merging by hand:

```bash
git checkout --ours pnpm-lock.yaml   # the target's version
pnpm install                         # regenerate with your deps
git add pnpm-lock.yaml
```

## Other generated files

For `flake.lock`, `.terraform.lock.hcl`, and similar, do the same: take the
target's version and run the file's regeneration command.

```bash
git checkout --ours <lockfile>
# run the regeneration command
git add <lockfile>
```

## Deleted versus modified

When one side deleted a file and the other modified it, check what each did:

```bash
git log --oneline --follow $target -- <file>   # deleted on the target?
git log --oneline HEAD -- <file>                # modified by you?
```

If the target deleted it on purpose (a refactor or migration), accept the
deletion. If your changes matter, keep the file and adapt it.
