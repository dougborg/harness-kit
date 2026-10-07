---
name: prototype
description: >-
  Builds throwaway code that answers one design question: a single-file HTML
  demo to push a state model or business logic through hard cases, or several
  structurally different UI variants on one route, switchable in the browser.
  Use when the user wants to check whether logic or a state model feels right,
  explore what a screen should look like before committing, or settle a
  wayfinder prototype ticket with something runnable.
---

# Prototype

A prototype is **throwaway code that answers a question**. The question
decides its shape.

## Pick a branch

Name the question from the user's prompt and the surrounding code. If that
doesn't settle it and the user is around, ask: through `AskUserQuestion` on
Claude Code, as a plain question on Codex.

- **"Does this logic or state model feel right?"** Read
  [LOGIC.md](LOGIC.md). You build one shareable HTML file, with free-play
  buttons and tabbed guided walkthroughs, that pushes the state model through
  cases that are hard to reason about on paper, and that a non-developer can
  drive.
- **"What should this look like?"** Read [UI.md](UI.md). You build several
  radically different variants on one route, switched by a URL search param
  and a floating bottom bar.

The two branches produce very different artifacts, so a wrong pick wastes
the whole prototype. If the question stays ambiguous and the user isn't
reachable, take the branch that matches the surrounding code (a backend
module means logic; a page or component means UI) and state the assumption
at the top of the prototype.

Done when the question is written down in one sentence and the branch is
chosen.

## Rules for both branches

1. **Throwaway, and visibly so.** Put the prototype next to the module or
   page it is for, so the context is obvious, and name it so a casual reader
   sees it is a prototype. A throwaway UI route follows the project's
   existing routing convention; don't invent a new top-level structure.
2. **Trivial to run.** A UI prototype starts with one command from the
   project's task runner (`pnpm <name>`, `python <path>`, `bun <path>`). A
   logic demo is one HTML file the user double-clicks.
3. **No persistence by default.** State lives in memory: persistence is what
   a prototype might be checking, never something it depends on. If the
   question is about storage, use a scratch database or a local file named
   so it is obviously disposable ("PROTOTYPE, wipe me").
4. **Skip the polish.** No tests, no error handling beyond what keeps it
   running, no abstractions. The point is to learn fast; the
   `minimal-change` ladder doesn't apply here, since none of this ships.
5. **Surface the state.** After every action (logic) or variant switch (UI),
   render the full relevant state so the user sees what changed.
6. **Capture it when done.** Fold the validated decision into the real code.
   Commit the prototype itself to a throwaway branch, never main, and link
   that branch from the issue it served, along with the verdict and the
   question it settled. Main keeps only the decision.

Done when the user has given a verdict, the decision is in the real code or
on its issue, and the prototype lives on its throwaway branch rather than
main.
