# Dependency batches

Use this guidance when the user asks to work through several dependency PRs.

## Choose the PR structure first

Consider one consolidated PR for related updates that share lockfiles or must
be tested together, especially when every merge triggers a production deploy.
Choose before refreshing and validating every original PR to avoid repeating
the same full CI matrix. Keep updates separate when isolation helps diagnose
a risky migration or the user prefers separate releases. Preserve existing
merge and deployment authorization requirements.

## Preserve the reviewed update set

- Start an isolated branch from the current target branch and record the
  original PR numbers and head commits.
- Include every original manifest change and compatibility fix. A lockfile
  alone may omit a raised minimum dependency requirement.
- Resolve overlapping lockfiles with the package manager while preserving the
  intended versions. Avoid a broad upgrade during conflict resolution.
- Compare resolved package versions and integrity records against the intended
  union of the original updates. Account for removed packages and combined
  peer-dependency contexts; report any additional resolution changes explicitly.
- Verify locked/frozen installation, review the combined dependency graph and
  migration behavior, and run the combined project's required checks. Green CI
  and clean reviews on separate PRs do not cover the consolidated head.

For major or behavior-changing upgrades, apply the code-reviewer skill's dependency guidance before
calling the batch ready. Typechecking and successful installation do not prove
that schema inference or privacy defaults are unchanged.

## Close the originals after merge

Link every superseded PR in the consolidated PR body. After the consolidated
PR actually merges, close the originals with a link to their replacement and
confirm the intended batch is no longer open. Do not close the originals merely
because the replacement PR exists. Merge approval must cover the consolidated
PR; use explicit approval already present in the session without asking again.
