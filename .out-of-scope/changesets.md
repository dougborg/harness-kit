# Changesets for releases

harness-kit does not use changesets to version or release itself.

## Why this is out of scope

Releases come from release-please, driven by the conventional commits that
CI already enforces. A changeset file per PR would duplicate the commit
message as a second source of release notes.

## Prior requests

- #111: "epic: integrate mattpocock/skills" (its "Not adopting" list)
