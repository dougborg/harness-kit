---
name: pr-body
description: >-
  The shape of a pull request description: the smallest visual that makes the
  change clear, evidence that it works, and a merge-danger call (one-way or
  two-way door, plus blast radius). Use when writing or rewriting a PR
  description, and when opening or updating a pull request.
---

# PR Body

Write the body with this template, skipping preambles and keeping prose
brief:

```markdown
<one or two sentences: what changes and why>

## Summary

<the smallest visual that makes the change clear>

## Evidence

- **Before:** <failing test, error output, screenshot>
- **After:** <passing test, correct output, screenshot>
- **Not verified:** <anything you couldn't check, or "nothing">

## Merge danger

**Door:** <one-way or two-way>
<optional: why>

**Blast radius:** <who or what a bad merge would affect>

Closes #<issue>   (Refs #<issue> for partial work; omit when there is none)
```

Scale it to the change: a typo fix or a docs tweak needs the lead sentence and
the link, not a visual or a merge-danger call.

## Summary: pick the smallest view

Choose whichever makes the key point clearest; one is usually enough:

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
a visual change; `gh pr create` can't attach images, so upload it first and
link the hosted URL. Next best is execution: the exact test that failed and
now passes, or command output before and after. Say what you didn't verify.

## Merge danger

- **Door:** a two-way door is cheap to walk back (revert and redeploy). A
  one-way door isn't: data migrations, destructive actions, published APIs,
  sent messages.
- **Blast radius:** what a bad merge would affect, considered widely:
  consumers of an API, other teams' pipelines, layout on mobile, performance,
  installed users.

Done when the body has the sections the change warrants, the evidence names
what was and wasn't verified, and the issue it implements is linked if there
is one.
