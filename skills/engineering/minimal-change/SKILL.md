---
name: minimal-change
description: >-
  Finds the smallest change that actually solves a coding problem: question
  whether the code needs to exist, then reach for existing code, the standard
  library, native platform features, and installed dependencies before writing
  anything new. Use before adding a dependency, an abstraction, a config
  option, or a new module; when simplifying a diff before review; and when the
  user asks for the simplest solution or complains about over-engineering. Not
  for trivial edits or for writing prose.
---

# Minimal Change

Understand the problem fully, then build the least that solves it.

## Read first

Read the task and every file the change touches, and trace the real flow end
to end, before choosing an approach. The smallest diff in the wrong place is a
second bug. Done when you can name each place the change has to touch and
why.

## Climb the ladder

The ladder is a reflex, not a research project. Stop at the first rung that
holds:

1. **Does this need to exist?** If the need is speculative, skip it and say so
   in one line.
2. **Is it already in this codebase?** Reuse the helper, type, or pattern that
   lives a few files over; reimplementing it is the most common waste.
3. **Does the standard library do it?** Use it.
4. **Does a native platform feature cover it?** `<input type="date">` over a
   picker library, CSS over JavaScript, a database constraint over
   application code.
5. **Does an installed dependency solve it?** Use it. Add a new dependency
   only when a few lines can't do the job.
6. **Can it be one line?** Write one line.
7. **Only then** write the minimum code that works.

When two rungs work, take the higher one. When two standard-library options
are the same size, take the one that is correct on edge cases: minimal means
less code, not a flimsier algorithm.

Add an abstraction only when something varies: an interface gets a second
implementation, a factory a second product, a config value a second setting.
Prefer fewer files. For a large request, ship the minimal version and name
what you left out ("Did X; Y covers it. Need full X? Say so.").

Done when each addition in the change sits on the highest rung that works.

## Always keep

The ladder never removes these: input validation at trust boundaries, error
handling that prevents data loss, security measures, accessibility basics,
calibration knobs for real hardware, and anything the user explicitly asked
for. If the user wants the full version, build it.

Non-trivial logic (a branch, a loop, a parser, a money or security path)
keeps one runnable check: the smallest test that fails if the logic breaks.
Trivial one-liners need none.

## Mark deliberate shortcuts

When a simplification has a real ceiling (a global lock, an O(n²) scan, a
naive heuristic), mark it with a comment in this shape, using the file's
comment syntax:

```text
<comment> shortcut: <the ceiling> | revisit when <the trigger>
```

```python
# shortcut: one global lock | revisit when write throughput matters
```

```typescript
// shortcut: O(n²) dedupe | revisit when lists exceed ~1k items
```

Done when every shortcut in the change carries both a ceiling and a trigger,
so a later sweep (`grep -rnE '(#|//|--|/\*|<!--) ?shortcut:'`) can list them
and flag any without a trigger.

## Report

Code first, then at most three short lines: what you skipped and when to add
it (`skipped: X, add when Y`). Explanation the user asked for is not padding;
give it in full.
