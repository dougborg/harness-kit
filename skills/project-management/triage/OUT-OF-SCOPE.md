# The `.out-of-scope/` record

`.out-of-scope/` at the repo root keeps one file per **rejected idea**, so the
reasoning survives the closed issue and a repeat request can be matched to the
earlier decision instead of argued again.

## A file

One file per concept, not per issue, named in short kebab-case
(`dark-mode.md`, `plugin-system.md`). Write it like a short design note: what
the project doesn't do, and a durable reason rooted in scope, a technical
constraint, or a strategic choice. "Too busy right now" is a deferral, not a
rejection, and doesn't belong here.

```markdown
# Dark mode

This project does not support dark mode or user-facing theming.

## Why this is out of scope

The renderer resolves one colour palette at build time, so runtime theming
would need a theme provider around the whole component tree and per-component
theme-aware styles. Theming is a concern for the downstream apps that embed
this output.

## Prior requests

- #42: "Add dark mode support"
- #87: "Night theme for accessibility"
```

## Checking it

During triage, read every file in `.out-of-scope/` and match by concept, not
keyword ("night theme" matches `dark-mode.md`). On a match, show the user the
earlier reasoning and ask whether it still holds:

- **Still holds:** add the new issue to that file's "Prior requests" and close
  it as `wontfix`, linking the file.
- **Reconsider:** delete or update the file; the issue proceeds through normal
  triage. Old issues stay closed as history.
- **Different idea after all:** triage normally.

## Writing to it

Only for a rejected **enhancement** (an issue or an external PR). Not for a
bug closed as `wontfix`, and not for a request closed because the feature
already exists: that would plant false rejections in the record. Append to an
existing file when the concept matches; otherwise create one with its first
prior request.
