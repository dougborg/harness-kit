---
name: tdd
description: >-
  Test-driven development with a red-green loop, one vertical slice at a time,
  plus what makes a test worth keeping. Use when building a feature or fixing a
  bug test-first, when the user mentions TDD or red-green-refactor, when
  writing integration tests, and when another skill implements a change at an
  agreed seam.
---

# Test-Driven Development

TDD is the **red → green** loop. This skill is the reference that makes the
loop produce tests worth keeping.

Read the project's `GLOSSARY.md` (if any) so test names use the domain's
words, and respect ADRs in the area you're changing.

## Agree the seams first

A **seam** is the public interface you test at: where you observe behaviour
without reaching inside. Before writing any test, list the seams you intend to
test and confirm them with the user. You can't test everything; agreeing the
seams up front puts the effort on critical paths and complex logic. When the
shape of the interface itself is in question (how deep the module is, where
the seam belongs), call the Skill tool with "codebase-design" for the
vocabulary.

Done when the user has confirmed the seams, or the task names them already.

## The loop

1. **Red.** Write one failing test at an agreed seam, for one behaviour. Done
   when you have run it and seen it fail for the reason you expect.
2. **Green.** Write only enough code to pass it: no code for tests you haven't
   written yet. Done when the test and its neighbours pass.
3. Repeat with the next behaviour.

Work in **vertical slices**: one test, one implementation, then the next, each
test a **tracer bullet** that responds to what the last cycle taught you.
Writing all the tests first and then all the code tests imagined behaviour and
locks in a structure before you understand it.

Refactor after green as its own step, or leave it to review (the
code-reviewer skill), never inside the red-green cycle.

## What a good test is

A good test exercises behaviour through the public interface and reads like a
specification: "user can check out with a valid cart". It survives a rewrite
of the internals because it never looked at them. Examples are in
[tests.md](tests.md); when and how to mock is in [mocking.md](mocking.md).

Three anti-patterns, each with its tell:

- **Implementation-coupled:** mocks internal collaborators, tests private
  methods, or checks results through a side channel (querying the database
  instead of the interface). Tell: it breaks when you refactor and behaviour
  hasn't changed.
- **Tautological:** the expected value is computed the way the code computes
  it (`expect(add(a, b)).toBe(a + b)`), so it passes by construction. Take
  expected values from an independent source: a known literal, a worked
  example, the spec.
- **Unfalsifiable:** it can't fail when the defect it targets is present. The
  red step proves this for a test written first; for a test written after the
  code, break the code it covers and watch the test go red before trusting
  it.
