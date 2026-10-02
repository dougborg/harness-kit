# Dependency batches

For a request to work through several dependency PRs.

## Choose the PR structure first

Decide before refreshing and validating each original PR, or you repeat the
full CI matrix for nothing. Consolidate related updates that share lockfiles
or must be tested together, especially when every merge deploys. Keep them
separate when isolation helps diagnose a risky migration or the user wants
separate releases.

## Preserve the reviewed update set

- Branch from the current target and record each original PR's number and
  head commit.
- Include every original manifest change and compatibility fix. A lockfile
  alone can drop a raised minimum version.
- Resolve overlapping lockfiles with the package manager, keeping the intended
  versions. Don't run a broad upgrade while resolving conflicts.
- Compare resolved versions and integrity records with the intended union of
  the updates, counting removed packages and combined peer contexts. Report any
  extra resolution changes.
- Run a locked install and the project's required checks on the combined head.
  Green CI on the separate PRs doesn't cover it.

For major or behavior-changing upgrades, apply the code-reviewer skill's
dependency guidance before calling the batch ready.

## Close the originals after merge

Link every superseded PR in the consolidated PR body. Once the consolidated PR
has merged, not merely opened, close each original with a link to it. Merge
approval must cover the consolidated PR; approval already given in the session
counts.
