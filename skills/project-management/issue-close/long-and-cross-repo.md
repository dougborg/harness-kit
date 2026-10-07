# Long threads and cross-repo closes

Read this when a thread runs past 100 comments, or when the issues involved
live in different repositories.

## Sampling a long thread

For 100 or more comments, sample by chronological cluster:

- **The most recent few** usually capture the current state.
- **The oldest** set the original framing.
- **The middle** is often noise; spot-check it for migration candidates.

When unsure what matters, show the user the sampled candidates and ask before
migrating.

## Cross-repo references

`gh` accepts `owner/repo#N` in issue bodies and comments. Before migrating
across repositories:

- confirm both repos are accessible (`gh repo view <owner>/<repo>`);
- use the full `owner/repo#N` form in both directions;
- watch for links into a private repo that readers of the other side can't
  open.
