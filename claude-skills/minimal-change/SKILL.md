---
name: minimal-change
description: >-
  Finds the smallest change that actually solves the problem: question whether
  the code needs to exist, then reach for existing code, the standard library,
  native platform features, and installed dependencies before writing
  anything new. Use when choosing how to implement a change, before adding a
  dependency or an abstraction, when simplifying a diff before review, and
  when the user asks for the simplest solution or complains about
  over-engineering.
---

# Minimal Change

The best code is code that never has to be written, read, or maintained.
Minimal means efficient, not careless: understand the problem fully first,
then build the least that solves it.

## Read first

Read the task and every file the change touches, and trace the real flow end
to end, before choosing an approach. The smallest diff in the wrong place is a
second bug. Done when you can name each place the change has to touch and
why.

## Climb the ladder

Stop at the first rung that holds:

1. **Does this need to exist?** If the need is speculative, skip it and say so
   in one line.
2. **Is it already in this codebase?** Reuse the helper, type, or pattern that
   lives a few files over; reimplementing it is the most common waste.
3. **Does the standard library do it?** Use it.
4. **Does a native platform feature cover it?** `<input type="date">` over a
   picker library, CSS over JavaScript, a database constraint over
   application code.
5. **Does an installed dependency solve it?** Use it. A new dependency for
   what a few lines can do is a cost, not a shortcut.
6. **Can it be one line?** Write one line.
7. **Only then** write the minimum code that works.

When two rungs work, take the higher one. When two standard-library options
are the same size, take the one that is correct on edge cases: minimal means
less code, not a flimsier algorithm.

## Keep it small

- Add an abstraction only when something varies: an interface gets a second
  implementation, a factory a second product, a config value a second
  setting.
- Leave scaffolding for later to later.
- Prefer deletion to addition, boring to clever, and fewer files.
- For a large request, ship the minimal version and name what you left out in
  the same response ("Did X; Y covers it. Need full X? Say so.").

## Never cut these

Input validation at trust boundaries, error handling that prevents data loss,
security measures, accessibility basics, calibration knobs for real hardware,
and anything the user explicitly asked for. If the user wants the full
version, build it.

Non-trivial logic (a branch, a loop, a parser, a money or security path)
leaves one runnable check behind: the smallest test that fails if the logic
breaks. Trivial one-liners need none.

## Mark deliberate shortcuts

When a simplification has a real ceiling (a global lock, an O(n²) scan, a
naive heuristic), say so in a comment naming the ceiling and when to revisit
it:

```python
# shortcut: global lock; switch to per-account locks if throughput matters
```

The `shortcut:` prefix keeps these findable, so a deferral can't quietly
become permanent.

## Report

Code first, then at most three short lines: what you skipped and when to add
it (`skipped: X, add when Y`). Give a full explanation only when the user asks
for one.

Done when the change solves the problem, each earlier rung was checked and
ruled out, and every deliberate shortcut is marked.
