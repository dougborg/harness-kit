# Design it twice

Your first interface idea is unlikely to be the best (Ousterhout). When the
user wants to explore alternatives for a module, design it several radically
different ways in parallel and compare. Uses the vocabulary in
[SKILL.md](SKILL.md).

## 1. Frame the problem

Write a short explanation for the user: the constraints any interface must
meet, the dependencies it relies on and their categories (in-process, local
stand-in, remote but owned, true external), and a rough code sketch that makes
the constraints concrete. It is not a proposal. Show it, then start step 2
straight away so the user reads while the subagents work.

## 2. Dispatch three or more subagents

Give each a technical brief (file paths, coupling, dependency category, what
sits behind the seam) plus the vocabulary from SKILL.md and the project's
`GLOSSARY.md` terms, and a different constraint:

- Minimize the interface: one to three entry points, maximum leverage each.
- Maximize flexibility: support many use cases and extension.
- Optimize the most common caller: make the default case trivial.
- Where it applies, design around ports and adapters for cross-seam
  dependencies.

Each returns: the interface (types, methods, parameters, invariants, ordering,
error modes); a usage example; what the implementation hides; the dependency
strategy and adapters; and where leverage is high or thin.

## 3. Compare and recommend

Present the designs one at a time, then compare them on depth (leverage at the
interface), locality (where change concentrates), and seam placement. Finish
with a firm recommendation, or a hybrid when parts of different designs
combine well. Done when the user has a recommendation they can accept or
argue with, not a menu.
