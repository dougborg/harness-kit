# ADR format

ADRs live in `docs/adr/` (or the repo's existing decisions folder) as
`0001-slug.md`, `0002-slug.md`, and so on. In a repo with several contexts,
an ADR that concerns one context sits in a `docs/adr/` beside that context's
`GLOSSARY.md`. Number a new one by scanning for the
highest existing number and adding one.

## Template

```md
# {Short title of the decision}

{One to three sentences: the context, what was decided, and why.}
```

That is the whole format. The value is recording that a decision was made and
why. Add a section only when it earns its place:

- **Status** (`proposed`, `accepted`, `superseded by ADR-NNNN`) when decisions
  get revisited
- **Considered options** when the rejected alternatives are worth remembering
- **Consequences** when a downstream effect isn't obvious

## When a decision deserves one

All three must hold:

1. **Hard to reverse.** Changing your mind later costs something real. If it
   is cheap to undo, skip the ADR: you'll just undo it.
2. **Surprising without context.** A future reader would ask "why on earth is
   it done this way?" If nobody would wonder, there is nothing to explain.
3. **A real trade-off.** There were genuine alternatives, and one was chosen
   for specific reasons. With no real alternative, there is nothing to record
   beyond "we did the obvious thing".

Typical qualifiers: architectural shape (monorepo, event-sourced writes),
integration patterns between contexts, technology choices with lock-in,
ownership and scope boundaries (including the explicit "no"s), deliberate
deviations from the obvious path, constraints the code can't show (compliance,
partner SLAs), and alternatives rejected for non-obvious reasons.
