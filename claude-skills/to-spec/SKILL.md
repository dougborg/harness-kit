---
name: to-spec
description: >-
  Turn the current conversation into a spec and file it as a GitHub issue,
  synthesizing what has already been discussed rather than interviewing again.
argument-hint: "[parent issue]"
disable-model-invocation: true
---

# To Spec

Turn the conversation and your understanding of the codebase into a spec, and
file it as an issue. Synthesize what you already know; the interview already
happened (usually through the grilling skill). Ask only when a gap would make
the spec wrong.

## 1. Ground it in the code

Explore the parts of the codebase the spec touches, if you haven't already.
Use the project's terms from `GLOSSARY.md` throughout, and respect ADRs in the
area. Done when you can name the modules the change touches.

## 2. Agree the test seams

Sketch where the feature will be tested. Prefer existing seams to new ones,
and the highest seam that reaches the behaviour: the fewer seams across the
codebase, the better, and one is ideal. Call the Skill tool with
"codebase-design" if the shape of a module is in question. Done when the user
has confirmed the seams match their expectations.

## 3. Write and file it

Fill the template below, then call the Skill tool with "issue-create" to file
it (duplicate search, labels, preview). Pass the parent issue if the user
named one. Done when the issue exists and its URL is reported.

```markdown
## Problem

The problem, from the user's point of view.

## Solution

The solution, from the user's point of view.

## User stories

A long, numbered list covering every aspect of the feature:

1. As a <actor>, I want <capability>, so that <benefit>.

## Implementation decisions

- The modules built or changed, and the interfaces that change
- Architectural decisions, schema changes, and API contracts
- Technical clarifications from the conversation

Leave out file paths and code: they go stale. The exception is a snippet a
prototype produced that states a decision more precisely than prose (a state
machine, a type shape, a schema); trim it to the decision and note where it
came from.

## Testing decisions

- The agreed seams, and which modules are tested at each
- What makes a good test here (external behaviour, not implementation)
- Prior art: similar tests already in the codebase

## Out of scope

What this spec deliberately leaves out.

## Further notes

Anything else the implementer needs.
```

Next step: the to-tickets skill splits the spec into tickets.
