---
name: pr-body
description: >-
  The shape of a pull request description: the smallest visual that makes the
  change clear, before-and-after evidence that it works, and a merge-danger
  call (one-way or two-way door, plus blast radius). Use when writing or
  rewriting a PR body, including from open-pr.
---

# PR Body

Write the body with this template. Skip preambles, keep prose brief, and use
the project's terms from `GLOSSARY.md` where it has one.

```markdown
<one or two sentences: what changes and why, linking the issue>

## Summary

<the smallest visual that makes the change clear>

## Evidence

- **Before:** <failing test, error output, screenshot>
- **After:** <passing test, correct output, screenshot>

## Merge danger

**Door:** <one-way or two-way>
<optional: why>

**Blast radius:** <who or what a bad merge would affect>

## Test plan

- [x] <what was verified, and how>

Closes #<issue>
```

## Summary: pick the smallest view

Choose whichever makes the key point clearest; one is usually enough, and
several is the most you'd ever want:

- **Pseudocode** for logic or an algorithm.
- **A call tree** for runtime control flow.
- **A component tree** for UI structure, with the state and module boundaries
  that matter.
- **A shallow file tree** for file responsibilities or a broad refactor.
- **Mermaid** for interaction, control flow, or data flow between parts.
- **A `diff` block** when the point is what changed in a shape that already
  exists, matched to the topic: a component tree, a file layout, a call tree,
  or pseudocode with `+` and `-` lines.
- **A small table** when the change is a set of parallel items (skills,
  endpoints, flags).

```diff
 on(save)
-  write content
+  if content is unchanged
+    return cached result
+  write new content
+  invalidate cache
```

Put each visual next to the sentence it supports, and keep only the calls,
files, and boundaries needed to see the change.

## Evidence

Show it working, before and after. A screenshot is the strongest evidence for
a visual change when the environment can take one. Execution is next: the
exact test that failed and now passes, or command output before and after.
Say what you didn't verify.

## Merge danger

- **Door:** a two-way door is cheap to walk back (revert and redeploy). A
  one-way door isn't: data migrations, destructive actions, published APIs,
  sent messages.
- **Blast radius:** what a bad merge would affect, considered widely:
  consumers of an API, other teams' pipelines, layout on mobile, performance,
  installed users.

Done when the body has a visual, evidence or a stated gap in it, a door and
blast-radius call, and a link to the issue it closes.
